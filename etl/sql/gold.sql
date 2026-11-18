-- Flow 1, part 3 (Transform): staging -> gold STAR SCHEMA
-- 1 fact table (fact_ticket_sale) surrounded by 4 dimension tables.
-- Fact grain: ONE ROW PER TICKET ORDER LINE (a citywide order or a partner purchase).
-- Note: no semicolons inside comments - the runner splits this file on them.

CREATE SCHEMA IF NOT EXISTS workspace.gold;


-- DIMENSION: date. One row per day, covering every full year that has sales or events.
-- Bahrain's weekend is Friday + Saturday (dayofweek: 1 = Sunday ... 6 = Friday, 7 = Saturday).
CREATE OR REPLACE TABLE workspace.gold.dim_date AS
SELECT CAST(date_format(d, 'yyyyMMdd') AS INT) AS date_key,      -- e.g. 20251122
       d                                     AS full_date,
       year(d)                               AS year,
       quarter(d)                            AS quarter,
       month(d)                              AS month,
       date_format(d, 'MMMM')                AS month_name,
       date_format(d, 'EEEE')                AS day_name,
       dayofweek(d) IN (6, 7)                AS is_weekend
FROM (
    SELECT explode(sequence(
        make_date((SELECT year(min(sale_date)) FROM workspace.staging.stg_ticket_sale), 1, 1),
        make_date((SELECT year(max(event_date)) FROM workspace.staging.stg_event), 12, 31),
        INTERVAL 1 DAY)) AS d
);


-- DIMENSION: attendee (merged customers from both schemas)
CREATE OR REPLACE TABLE workspace.gold.dim_attendee AS
SELECT customer_key AS attendee_key, full_name, email, city, loyalty_tier, bought_from
FROM workspace.staging.stg_customer;


-- DIMENSION: event (merged events and partner-only shows).
-- description is left out: long free text is not used for analysis (pgvector handles it).
CREATE OR REPLACE TABLE workspace.gold.dim_event AS
SELECT event_key, event_name, category, venue_name, city, event_date
FROM workspace.staging.stg_event;


-- DIMENSION: venue source (which operational system the sale came from).
-- This is what the dashboard's citywide-only / partner-only / combined filter uses.
CREATE OR REPLACE TABLE workspace.gold.dim_venue_source AS
SELECT * FROM VALUES
    ('citywide', 'Citywide Events', 'Main ticketing system (normalised)'),
    ('partner',  'Partner Venue',   'Partner legacy system (denormalised)')
AS t(source_key, source_name, description);


-- FACT: ticket sales. Keys point to the 4 dimensions, numbers are the measures.
-- ticket_class stays on the fact as a "degenerate dimension" (only 3 values, no extra attributes).
CREATE OR REPLACE TABLE workspace.gold.fact_ticket_sale AS
SELECT sale_id,
       CAST(date_format(sale_date, 'yyyyMMdd') AS INT) AS date_key,
       customer_key  AS attendee_key,
       event_key,
       source_system AS source_key,
       ticket_class,
       quantity,                       -- measure
       unit_price,                     -- measure
       amount                          -- measure (quantity x unit_price)
FROM workspace.staging.stg_ticket_sale
