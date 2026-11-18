-- Analytical queries on the gold star schema (run these in the Databricks SQL Editor).
-- Each one joins the fact table to dimensions - that is what a star schema is built for.

-- Query 1: monthly revenue per source system (citywide vs partner)
SELECT d.year, d.month, d.month_name, s.source_name,
       SUM(f.quantity) AS tickets_sold,
       SUM(f.amount)   AS revenue_bhd
FROM workspace.gold.fact_ticket_sale f
JOIN workspace.gold.dim_date d         ON d.date_key = f.date_key
JOIN workspace.gold.dim_venue_source s ON s.source_key = f.source_key
GROUP BY d.year, d.month, d.month_name, s.source_name
ORDER BY d.year, d.month, s.source_name;


-- Query 2: ticket sales by venue, split by source (the dashboard's main chart)
SELECT e.venue_name, e.city, s.source_name,
       SUM(f.quantity) AS tickets_sold,
       SUM(f.amount)   AS revenue_bhd
FROM workspace.gold.fact_ticket_sale f
JOIN workspace.gold.dim_event e        ON e.event_key = f.event_key
JOIN workspace.gold.dim_venue_source s ON s.source_key = f.source_key
GROUP BY e.venue_name, e.city, s.source_name
ORDER BY revenue_bhd DESC;


-- Query 3: category performance - revenue, VIP share and weekend share
SELECT e.category,
       SUM(f.amount) AS revenue_bhd,
       ROUND(100 * SUM(CASE WHEN f.ticket_class = 'VIP' THEN f.amount ELSE 0 END) / SUM(f.amount), 1) AS vip_revenue_pct,
       ROUND(100 * SUM(CASE WHEN d.is_weekend THEN f.quantity ELSE 0 END) / SUM(f.quantity), 1)        AS weekend_tickets_pct
FROM workspace.gold.fact_ticket_sale f
JOIN workspace.gold.dim_event e ON e.event_key = f.event_key
JOIN workspace.gold.dim_date d  ON d.date_key = f.date_key
GROUP BY e.category
ORDER BY revenue_bhd DESC;


-- Query 4: do customers who buy from BOTH systems spend more?
SELECT a.bought_from,
       COUNT(DISTINCT a.attendee_key)                                  AS customers,
       SUM(f.amount)                                                   AS revenue_bhd,
       ROUND(SUM(f.amount) / COUNT(DISTINCT a.attendee_key), 2)        AS revenue_per_customer
FROM workspace.gold.fact_ticket_sale f
JOIN workspace.gold.dim_attendee a ON a.attendee_key = f.attendee_key
GROUP BY a.bought_from
ORDER BY revenue_per_customer DESC;
