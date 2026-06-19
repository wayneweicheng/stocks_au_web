import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from app.core.db import get_db_connection


def show(name, sql, params=()):
    print(f"---{name}---")
    conn = get_db_connection(database="StockDB_US")
    try:
        cursor = conn.cursor()
        cursor.execute(sql, params)
        columns = [column[0] for column in cursor.description]
        rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
    finally:
        if "cursor" in locals():
            cursor.close()
        conn.close()
    print("count", len(rows))
    for row in rows[:50]:
        print(row)


show(
    "smci_30m_summary",
    """
    SELECT
        ASXCode,
        TimeFrame,
        COUNT(*) AS BarCount,
        MIN(TimeIntervalStart) AS MinTime,
        MAX(TimeIntervalStart) AS MaxTime,
        MIN(ObservationDate) AS MinObservationDate,
        MAX(ObservationDate) AS MaxObservationDate
    FROM StockDB_US.StockData.PriceHistoryTimeFrame
    WHERE ASXCode = 'SMCI.US'
      AND TimeFrame = '30M'
    GROUP BY ASXCode, TimeFrame
    """,
)

show(
    "smci_30m_recent",
    """
    SELECT TOP 20 ASXCode, TimeIntervalStart, ObservationDate, [High], [Low], [Close], Volume
    FROM StockDB_US.StockData.PriceHistoryTimeFrame
    WHERE ASXCode = 'SMCI.US'
      AND TimeFrame = '30M'
    ORDER BY TimeIntervalStart DESC
    """,
)

show(
    "smci_daily_summary",
    """
    SELECT
        ASXCode,
        COUNT(*) AS DailyCount,
        MIN(ObservationDate) AS MinObservationDate,
        MAX(ObservationDate) AS MaxObservationDate
    FROM StockDB_US.StockData.PriceHistory
    WHERE ASXCode = 'SMCI.US'
    GROUP BY ASXCode
    """,
)

show(
    "smci_daily_recent",
    """
    SELECT TOP 20 ASXCode, ObservationDate, [High], [Low], [Close], Volume
    FROM StockDB_US.StockData.PriceHistory
    WHERE ASXCode = 'SMCI.US'
    ORDER BY ObservationDate DESC
    """,
)

show(
    "smci_snapshot",
    """
    SELECT ASXCode, ObservationDate, CollectionStatus, ImpliedVolatility, HistoricalVolatility,
           IVRank252, IVPercentile252, TrailingPE, ForwardPE
    FROM StockDB_US.StockData.v_DailyMarketSnapshot_Latest
    WHERE ASXCode = 'SMCI.US'
    """,
)

show(
    "smci_option_walls_today",
    """
    SELECT TOP 20 ASXCode, ObservationDate, PorC, Strike,
           SUM(COALESCE(OpenInterest, 0)) AS OpenInterest,
           MIN(ExpiryDate) AS NearestExpiry
    FROM StockDB_US.StockData.v_OptionDelayedQuote_V2
    WHERE ASXCode = 'SMCI.US'
      AND ObservationDate = '2026-06-18'
      AND ExpiryDate >= '2026-06-18'
      AND ExpiryDate <= DATEADD(day, 30, '2026-06-18')
      AND PorC IN ('P', 'C')
      AND OpenInterest > 0
    GROUP BY ASXCode, ObservationDate, PorC, Strike
    ORDER BY OpenInterest DESC
    """,
)
