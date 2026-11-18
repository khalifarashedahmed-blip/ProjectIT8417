"""Flow 1, part 1 (Extract + Load): copy every PostgreSQL source table into the
Databricks bronze layer exactly as it is. Every column is stored as STRING:
bronze is the raw copy, and the typing/cleaning happens later in staging."""
import tomllib
from pathlib import Path

import psycopg
from databricks import sql

ROOT = Path(__file__).resolve().parent.parent
SECRETS = tomllib.load(open(ROOT / ".streamlit" / "secrets.toml", "rb"))

SOURCE_TABLES = {
    "citywide_events": ["attendee", "event", "ticket_type", "order_header"],
    "partner_venue": ["venue", "guest", "show", "purchase"],
}


def databricks_connection():
    d = SECRETS["databricks"]
    return sql.connect(server_hostname=d["server_hostname"],
                       http_path=d["http_path"],
                       access_token=d["access_token"])


def literal(value):
    """Turn a Python value into a safe SQL string literal (or NULL)."""
    if value is None:
        return "NULL"
    return "'" + str(value).replace("\\", "\\\\").replace("'", "\\'") + "'"


def extract_load():
    counts = {}
    with psycopg.connect(SECRETS["postgres"]["url"]) as pg, \
         databricks_connection() as db, db.cursor() as cur:
        cur.execute("CREATE SCHEMA IF NOT EXISTS workspace.bronze")
        for schema, tables in SOURCE_TABLES.items():
            for table in tables:
                # Extract: read the whole table from PostgreSQL
                src = pg.execute(f"SELECT * FROM {schema}.{table}")
                columns = [c.name for c in src.description]
                rows = src.fetchall()

                # Load: full refresh, so the bronze table always mirrors the source
                target = f"workspace.bronze.{schema}_{table}"
                col_defs = ", ".join(f"`{c}` STRING" for c in columns)
                cur.execute(f"CREATE OR REPLACE TABLE {target} ({col_defs}, _ingested_at TIMESTAMP)")
                for i in range(0, len(rows), 500):  # send rows in batches of 500
                    values = ",".join(
                        "(" + ",".join(literal(v) for v in row) + ", current_timestamp())"
                        for row in rows[i:i + 500])
                    cur.execute(f"INSERT INTO {target} VALUES {values}")
                counts[target] = len(rows)
    return counts


if __name__ == "__main__":
    for table, n in extract_load().items():
        print(f"{table}: {n} rows")
