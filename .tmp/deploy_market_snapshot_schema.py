from pathlib import Path
import sys

REPO_ROOT = Path(__file__).resolve().parents[1]
BACKEND_ROOT = REPO_ROOT / "backend"
sys.path.insert(0, str(BACKEND_ROOT))

from app.core.db import get_db_connection


FILES = [
    (
        "StockData.UnderlyingVolatilityHistory",
        REPO_ROOT / "DatabaseSchema/StockDB_US/Tables/StockData/UnderlyingVolatilityHistory.sql",
    ),
    (
        "StockData.DailyMarketSnapshot",
        REPO_ROOT / "DatabaseSchema/StockDB_US/Tables/StockData/DailyMarketSnapshot.sql",
    ),
    (
        None,
        REPO_ROOT
        / "DatabaseSchema/StockDB_US/StoredProcedures/StockData/usp_GetDailyMarketSnapshotUniverse.sql",
    ),
    (
        None,
        REPO_ROOT
        / "DatabaseSchema/StockDB_US/StoredProcedures/StockData/usp_UpsertUnderlyingVolatilityHistory.sql",
    ),
    (
        None,
        REPO_ROOT
        / "DatabaseSchema/StockDB_US/StoredProcedures/StockData/usp_UpsertUnderlyingVolatilityHistoryBatch.sql",
    ),
    (
        None,
        REPO_ROOT
        / "DatabaseSchema/StockDB_US/StoredProcedures/StockData/usp_UpsertDailyMarketSnapshot.sql",
    ),
]


def main() -> None:
    connection = get_db_connection("StockDB_US")
    try:
        cursor = connection.cursor()
        for object_name, path in FILES:
            if object_name:
                cursor.execute("SELECT OBJECT_ID(?, 'U')", object_name)
                if cursor.fetchone()[0] is not None:
                    print(f"Exists: {object_name}")
                    continue
            cursor.execute(path.read_text(encoding="utf-8"))
            connection.commit()
            print(f"Applied: {path.name}")
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


if __name__ == "__main__":
    main()
