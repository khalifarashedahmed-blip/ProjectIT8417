-- Flow 1, part 2 (Transform): bronze -> staging
-- Staging is TYPED (real dates/numbers), CLEANSED (duplicates and bad values fixed)
-- and RECONCILED (both PostgreSQL schemas merged into one structure).
-- Note: no semicolons inside comments - the runner splits this file on them.

CREATE SCHEMA IF NOT EXISTS workspace.staging;


-- 1) CUSTOMER MAP: gives every source customer ONE customer_key.
--    * a partner guest with the same email as a citywide attendee is the SAME person -> C-<attendee_id>
--    * a guest registered twice (same name, email, mobile) -> both rows get P-<first guest_no>
CREATE OR REPLACE TABLE workspace.staging.stg_customer_map AS
WITH att AS (
    SELECT CAST(attendee_id AS INT) AS attendee_id, lower(trim(email)) AS email
    FROM workspace.bronze.citywide_events_attendee
),
g AS (
    SELECT CAST(guest_no AS INT) AS guest_no, lower(trim(email)) AS email,
           MIN(CAST(guest_no AS INT)) OVER (PARTITION BY upper(trim(full_name)), lower(trim(email)), mobile) AS first_guest_no
    FROM workspace.bronze.partner_venue_guest
)
SELECT 'citywide' AS source_system, attendee_id AS source_customer_id, concat('C-', attendee_id) AS customer_key
FROM att
UNION ALL
SELECT 'partner', g.guest_no,
       CASE WHEN att.attendee_id IS NOT NULL THEN concat('C-', att.attendee_id)
            ELSE concat('P-', g.first_guest_no) END
FROM g LEFT JOIN att ON att.email = g.email;


-- 2) CUSTOMERS: one clean row per customer_key.
--    Dropped: phone, marketing_opt_in, created_at (attendee) and mobile, referral_code (guest).
CREATE OR REPLACE TABLE workspace.staging.stg_customer AS
WITH partner AS (
    SELECT m.customer_key,
           initcap(trim(g.full_name))            AS full_name,     -- fixes ALL CAPS names
           lower(trim(g.email))                  AS email,         -- fixes UPPER case emails
           g.loyalty_tier,
           ROW_NUMBER() OVER (PARTITION BY m.customer_key ORDER BY CAST(g.guest_no AS INT)) AS rn
    FROM workspace.bronze.partner_venue_guest g
    JOIN workspace.staging.stg_customer_map m
      ON m.source_system = 'partner' AND m.source_customer_id = CAST(g.guest_no AS INT)
)
SELECT concat('C-', a.attendee_id)                        AS customer_key,
       initcap(trim(concat(a.first_name, ' ', a.last_name))) AS full_name,  -- first + last -> one field
       lower(trim(a.email))                               AS email,
       coalesce(initcap(trim(a.city)), 'Unknown')         AS city,          -- missing city -> 'Unknown'
       coalesce(p.loyalty_tier, 'None')                   AS loyalty_tier,  -- tier only exists in partner_venue
       CASE WHEN p.customer_key IS NULL THEN 'citywide only' ELSE 'both' END AS bought_from
FROM workspace.bronze.citywide_events_attendee a
LEFT JOIN partner p ON p.customer_key = concat('C-', a.attendee_id) AND p.rn = 1
UNION ALL
SELECT customer_key, full_name,
       coalesce(email, 'not provided'),                   -- missing email
       'Unknown',                                         -- partner_venue has no city column
       coalesce(loyalty_tier, 'None'),
       'partner only'
FROM partner
WHERE customer_key LIKE 'P-%' AND rn = 1;


-- 3) EVENT MAP: a partner show that is the same event as a citywide event
--    (same title ignoring case/spaces, same date) gets that event's key E-<event_id>.
CREATE OR REPLACE TABLE workspace.staging.stg_event_map AS
SELECT 'citywide' AS source_system, event_id AS source_event_id, concat('E-', event_id) AS event_key
FROM workspace.bronze.citywide_events_event
UNION ALL
SELECT 'partner', s.show_code, coalesce(concat('E-', e.event_id), concat('S-', s.show_code))
FROM workspace.bronze.partner_venue_show s
LEFT JOIN workspace.bronze.citywide_events_event e
  ON lower(trim(s.show_title)) = lower(trim(e.event_name))
 AND CAST(s.show_datetime AS DATE) = CAST(e.event_date AS DATE);


-- 4) EVENTS: citywide events + partner-only shows, in one structure.
--    Dropped: poster_url, internal_notes (event), promoter_notes, banner_image (show),
--    manager_contact, parking_notes, seating_capacity (venue).
CREATE OR REPLACE TABLE workspace.staging.stg_event AS
SELECT concat('E-', event_id)          AS event_key,
       trim(event_name)                AS event_name,
       initcap(trim(category))         AS category,
       description,
       trim(venue_name)                AS venue_name,
       initcap(trim(city))             AS city,
       CAST(event_date AS DATE)        AS event_date
FROM workspace.bronze.citywide_events_event
UNION ALL
SELECT m.event_key,
       trim(s.show_title),
       initcap(trim(s.genre)),                                   -- 'comedy' -> 'Comedy'
       coalesce(s.blurb, 'No description provided'),             -- missing description
       trim(v.venue_name),
       initcap(trim(v.city)),                                    -- 'MANAMA' -> 'Manama'
       CAST(s.show_datetime AS DATE)                             -- timestamp -> date, like citywide
FROM workspace.bronze.partner_venue_show s
JOIN workspace.staging.stg_event_map m ON m.source_system = 'partner' AND m.source_event_id = s.show_code
JOIN workspace.bronze.partner_venue_venue v ON v.venue_code = s.venue_code
WHERE m.event_key LIKE 'S-%';


-- 5) TICKET SALES: one row per order (citywide) or purchase (partner), same columns for both.
--    Dropped: payment_method, box_office_terminal_id, payment_reference (order_header),
--    print_template_code, sales_rep_code, capacity (ticket_type),
--    show_name, comp_code, till_receipt_no (purchase).
CREATE OR REPLACE TABLE workspace.staging.stg_ticket_sale AS
WITH cw AS (
    SELECT concat('CW-', o.order_id)            AS sale_id,
           'citywide'                           AS source_system,
           concat('C-', o.attendee_id)          AS customer_key,
           concat('E-', t.event_id)             AS event_key,
           t.type_name                          AS ticket_class,
           CAST(o.quantity AS INT)              AS quantity,
           CAST(t.price AS DECIMAL(8,2))        AS unit_price,     -- normalised: price comes from ticket_type
           CAST(o.order_date AS DATE)           AS sale_date
    FROM workspace.bronze.citywide_events_order_header o
    JOIN workspace.bronze.citywide_events_ticket_type t ON t.ticket_type_id = o.ticket_type_id
),
pv AS (
    SELECT p.*,
           -- the same purchase saved twice gets rn = 2 and is removed below
           ROW_NUMBER() OVER (PARTITION BY guest_no, show_code, seat_class, seat_price, qty, purchased_on, till_receipt_no
                              ORDER BY CAST(purchase_no AS INT)) AS rn,
           -- 7 spellings of the seat type -> 3 clean classes that match citywide ticket_type names
           CASE WHEN lower(replace(trim(seat_class), '.', '')) = 'vip' THEN 'VIP'
                WHEN lower(trim(seat_class)) = 'student'               THEN 'Student'
                ELSE 'General' END AS ticket_class                    -- general, General Admission, GA, missing
    FROM workspace.bronze.partner_venue_purchase p
),
pv_clean AS (
    SELECT concat('PV-', p.purchase_no) AS sale_id,
           'partner'                    AS source_system,
           cm.customer_key,
           em.event_key,
           p.ticket_class,
           CAST(p.qty AS INT)           AS quantity,
           -- missing price: 1) citywide ticket_type price for the same event + class,
           --                2) average price of that show + class, 3) average price of that show
           coalesce(CAST(p.seat_price AS DECIMAL(8,2)),
                    CAST(t.price AS DECIMAL(8,2)),
                    CAST(AVG(CAST(p.seat_price AS DECIMAL(8,2))) OVER (PARTITION BY p.show_code, p.ticket_class) AS DECIMAL(8,2)),
                    CAST(AVG(CAST(p.seat_price AS DECIMAL(8,2))) OVER (PARTITION BY p.show_code) AS DECIMAL(8,2))) AS unit_price,
           CAST(p.purchased_on AS DATE) AS sale_date
    FROM pv p
    JOIN workspace.staging.stg_customer_map cm
      ON cm.source_system = 'partner' AND cm.source_customer_id = CAST(p.guest_no AS INT)
    JOIN workspace.staging.stg_event_map em
      ON em.source_system = 'partner' AND em.source_event_id = p.show_code
    LEFT JOIN workspace.bronze.citywide_events_ticket_type t
      ON concat('E-', t.event_id) = em.event_key AND t.type_name = p.ticket_class
    WHERE p.rn = 1
)
SELECT *, quantity * unit_price AS amount FROM cw
UNION ALL
SELECT *, quantity * unit_price AS amount FROM pv_clean;


-- 6) CLEANING REPORT: before/after row counts (the brief asks for this)
CREATE OR REPLACE TABLE workspace.staging.etl_cleaning_report AS
SELECT 'customers' AS entity,
       (SELECT COUNT(*) FROM workspace.bronze.citywide_events_attendee)
     + (SELECT COUNT(*) FROM workspace.bronze.partner_venue_guest)       AS rows_before,
       (SELECT COUNT(*) FROM workspace.staging.stg_customer)             AS rows_after,
       'same person in both schemas (matched on email) and duplicate guest registrations merged' AS what_changed
UNION ALL
SELECT 'events',
       (SELECT COUNT(*) FROM workspace.bronze.citywide_events_event)
     + (SELECT COUNT(*) FROM workspace.bronze.partner_venue_show),
       (SELECT COUNT(*) FROM workspace.staging.stg_event),
       'partner shows that are the same event as a citywide event (title + date) merged'
UNION ALL
SELECT 'ticket sales',
       (SELECT COUNT(*) FROM workspace.bronze.citywide_events_order_header)
     + (SELECT COUNT(*) FROM workspace.bronze.partner_venue_purchase),
       (SELECT COUNT(*) FROM workspace.staging.stg_ticket_sale),
       'purchases saved twice by the till removed'
