from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from app.core.db import get_db_connection


connection = get_db_connection("StockDB_US")
try:
    cursor = connection.cursor()
    cursor.execute(
        """
        SELECT TOP (1)
            ASXCode, ObservationDate,
            ImpliedVolatility, HistoricalVolatility,
            IVRank252, IVPercentile252, IVHistoryCount,
            Low52Week, High52Week, AverageVolume90Day,
            CollectionStatus
        FROM StockData.DailyMarketSnapshot
        ORDER BY CaptureDateTime DESC
        """
    )
    columns = [column[0] for column in cursor.description]
    print(dict(zip(columns, cursor.fetchone())))
finally:
    connection.close()
