from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from app.core.db import get_db_connection


connection = get_db_connection("StockDB_US")
try:
    cursor = connection.cursor()
    cursor.execute(
        """
        SELECT TOP (1) *
        FROM StockData.v_DailyMarketSnapshot_Latest
        WHERE ASXCode = ?
        """,
        ("ORCL.US",),
    )
    print([column[0] for column in cursor.description])
    print(cursor.fetchone())
finally:
    connection.close()
