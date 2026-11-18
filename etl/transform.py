"""Flow 1, part 2 (Transform): run the SQL files that build the staging
and gold layers inside Databricks, in order."""
from pathlib import Path

from extract_load import databricks_connection

SQL_DIR = Path(__file__).resolve().parent / "sql"
STEPS = ["staging.sql", "gold.sql"]


def statements(path):
    """Split a .sql file into single statements, skipping comment-only lines."""
    for chunk in path.read_text(encoding="utf-8").split(";"):
        code = "\n".join(line for line in chunk.splitlines()
                         if not line.strip().startswith("--")).strip()
        if code:
            yield code


def transform():
    with databricks_connection() as db, db.cursor() as cur:
        for step in STEPS:
            for statement in statements(SQL_DIR / step):
                cur.execute(statement)
        cur.execute("SELECT entity, rows_before, rows_after FROM workspace.staging.etl_cleaning_report")
        return cur.fetchall()


if __name__ == "__main__":
    for entity, before, after in transform():
        print(f"{entity}: {before} rows before -> {after} rows after cleaning")
