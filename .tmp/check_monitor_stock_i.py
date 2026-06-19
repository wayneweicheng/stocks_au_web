import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from app.core.db import get_db_connection

conn = get_db_connection(database="StockDB_US")
try:
    cursor = conn.cursor()
    cursor.execute(
        """
        EXEC StockDB_US.StockData.usp_GetMonitorStock
            @pvchMonitorStockTypeID = ?
        """,
        ("I",),
    )
    columns = [column[0] for column in cursor.description]
    rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
finally:
    if "cursor" in locals():
        cursor.close()
    conn.close()

print("count", len(rows))
for row in rows:
    if str(row.get("ASXCode", "")).upper() in {"HOOD.US", "SMCI.US"}:
        print(row)
