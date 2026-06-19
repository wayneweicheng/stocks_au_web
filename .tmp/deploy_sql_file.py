import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from app.core.db import get_db_connection


def split_batches(sql_text):
    return [
        batch.strip()
        for batch in re.split(r"(?im)^\s*GO\s*$", sql_text)
        if batch.strip()
    ]


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: deploy_sql_file.py <sql-file>")

    sql_path = Path(sys.argv[1]).resolve()
    sql_text = sql_path.read_text(encoding="utf-8")
    batches = split_batches(sql_text)

    conn = get_db_connection(database="StockDB_US")
    try:
        cursor = conn.cursor()
        for index, batch in enumerate(batches, start=1):
            print(f"Executing batch {index}/{len(batches)}")
            cursor.execute(batch)
            while cursor.nextset():
                pass
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        if "cursor" in locals():
            cursor.close()
        conn.close()

    print(f"Deployed {sql_path}")


if __name__ == "__main__":
    main()
