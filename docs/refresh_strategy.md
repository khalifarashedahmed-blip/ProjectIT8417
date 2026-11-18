# Warehouse Refresh Strategy

## What is refreshed
The whole pipeline: PostgreSQL (`citywide_events` + `partner_venue`) → `bronze` → `staging` → `gold` in Databricks.
One command runs all of it: `python etl/run_etl.py` (the same `run_etl()` function behind the dashboard's **Sync now** button).

## How: full refresh
Every run rebuilds every table with `CREATE OR REPLACE TABLE`:

| Layer | Refresh method |
|---|---|
| bronze | Full reload of all 8 source tables from PostgreSQL |
| staging | Rebuilt from bronze (cleansing, deduplication, reconciliation re-applied) |
| gold | Rebuilt from staging (dimensions first, then the fact table) |

**Why full refresh:** the source data is small (under 1,000 rows per table), so a full rebuild takes well under a minute.
It is also the simplest correct option: deletes and updates in PostgreSQL are picked up automatically, and running it twice gives the same result (idempotent).

## When
- **On demand:** the dashboard's **Sync now** button, showing fact-table row count and revenue before and after.
- **Scheduled (recommended in production):** once a day outside business hours (e.g. 02:00), using Windows Task Scheduler or cron to run `python etl/run_etl.py`.
  A Databricks Job is not used because the extract step connects to Supabase from outside Databricks.

## Checks after each refresh
- `staging.etl_cleaning_report` records before/after row counts for customers, events and ticket sales.
- The dashboard compares fact rows and revenue before and after the sync.

## When to change strategy
If the data grew to millions of rows, full reloads would become slow. The upgrade path is an **incremental load**:
extract only rows with `order_date` / `purchased_on` later than the last successful run (a "watermark"),
and use Delta Lake `MERGE INTO` to insert new rows and update changed ones instead of replacing whole tables.
