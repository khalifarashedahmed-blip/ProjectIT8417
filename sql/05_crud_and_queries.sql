-- CRUD examples + non-trivial queries for the operational PostgreSQL databases.
-- Run ONE block at a time: highlight it in the Supabase SQL Editor and press Ctrl+Enter.

-- ============ CRUD on citywide_events.attendee ============

-- C: Create a new attendee
INSERT INTO citywide_events.attendee (first_name, last_name, email, city)
VALUES ('Test', 'User', 'test.user@example.com', 'Manama')
RETURNING *;

-- R: Read it back
SELECT * FROM citywide_events.attendee WHERE email = 'test.user@example.com';

-- U: Update their city
UPDATE citywide_events.attendee SET city = 'Riffa'
WHERE email = 'test.user@example.com'
RETURNING *;

-- D: Delete them (leaves the data as it was before)
DELETE FROM citywide_events.attendee WHERE email = 'test.user@example.com'
RETURNING *;


-- ============ Query 1: revenue per event, ranked inside its category ============
-- Joins 3 tables, calculates revenue from the price stored on ticket_type,
-- and uses a window function (RANK) to rank events within each category.
SELECT e.category,
       e.event_name,
       SUM(o.quantity)           AS tickets_sold,
       SUM(o.quantity * t.price) AS revenue_bhd,
       RANK() OVER (PARTITION BY e.category ORDER BY SUM(o.quantity * t.price) DESC) AS rank_in_category
FROM citywide_events.order_header o
JOIN citywide_events.ticket_type t ON t.ticket_type_id = o.ticket_type_id
JOIN citywide_events.event e       ON e.event_id = t.event_id
GROUP BY e.category, e.event_name
ORDER BY e.category, rank_in_category;


-- ============ Query 2: customers who bought from BOTH systems ============
-- Matches people across the two schemas by email (ignoring upper/lower case).
-- This is the duplicate-customer problem the warehouse ETL must solve.
SELECT a.first_name || ' ' || a.last_name AS customer,
       a.email,
       cw.orders    AS citywide_orders,
       pv.purchases AS partner_purchases
FROM citywide_events.attendee a
JOIN (SELECT attendee_id, COUNT(*) AS orders
      FROM citywide_events.order_header GROUP BY attendee_id) cw ON cw.attendee_id = a.attendee_id
JOIN (SELECT lower(g.email) AS email, COUNT(*) AS purchases
      FROM partner_venue.guest g
      JOIN partner_venue.purchase p ON p.guest_no = g.guest_no
      GROUP BY lower(g.email)) pv ON pv.email = lower(a.email)
ORDER BY cw.orders + pv.purchases DESC;


-- ============ Query 3: monthly revenue with a running total ============
-- A CTE (WITH) groups revenue by month, then a window SUM adds it up over time.
WITH monthly AS (
    SELECT date_trunc('month', o.order_date)::date AS month,
           SUM(o.quantity * t.price)               AS revenue_bhd
    FROM citywide_events.order_header o
    JOIN citywide_events.ticket_type t ON t.ticket_type_id = o.ticket_type_id
    GROUP BY 1
)
SELECT month,
       revenue_bhd,
       SUM(revenue_bhd) OVER (ORDER BY month) AS running_total_bhd
FROM monthly
ORDER BY month;
