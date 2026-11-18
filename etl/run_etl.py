"""Flow 1 end to end (PostgreSQL -> bronze -> staging -> gold).
This is the function the dashboard's "Sync now" button calls."""
import time

from extract_load import databricks_connection, extract_load
from transform import transform


def fact_summary():
    """Row count and total revenue in the fact table - shown before and after a sync."""
    with databricks_connection() as db, db.cursor() as cur:
        cur.execute("SELECT COUNT(*), COALESCE(SUM(amount), 0) FROM workspace.gold.fact_ticket_sale")
        rows, revenue = cur.fetchone()
        return {"fact_rows": rows, "revenue_bhd": float(revenue)}


def run_etl():
    start = time.time()
    before = fact_summary()
    bronze_counts = extract_load()
    cleaning_report = transform()
    after = fact_summary()
    return {"before": before, "after": after, "bronze": bronze_counts,
            "cleaning": cleaning_report, "seconds": round(time.time() - start, 1)}


if __name__ == "__main__":
    result = run_etl()
    print("Before:", result["before"])
    print("After: ", result["after"])
    print("Took", result["seconds"], "seconds")
