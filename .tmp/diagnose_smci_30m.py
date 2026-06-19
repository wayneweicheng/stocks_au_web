import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from app.core.db import get_db_connection


def show(name, sql, params):
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
    for row in rows[:25]:
        print(row)


show(
    "exact_30m",
    """
    SELECT TOP 20
        ASXCode, TimeFrame, TimeIntervalStart, ObservationDate,
        [Open], [High], [Low], [Close], Volume
    FROM StockDB_US.StockData.PriceHistoryTimeFrame
    WHERE ASXCode = ?
      AND TimeFrame = '30M'
    ORDER BY TimeIntervalStart DESC
    """,
    ("SMCI.US",),
)

show(
    "like_codes_timeframes",
    """
    SELECT
        ASXCode, TimeFrame, COUNT(*) AS Cnt,
        MIN(TimeIntervalStart) AS MinTime,
        MAX(TimeIntervalStart) AS MaxTime
    FROM StockDB_US.StockData.PriceHistoryTimeFrame
    WHERE ASXCode LIKE ?
    GROUP BY ASXCode, TimeFrame
    ORDER BY ASXCode, TimeFrame
    """,
    ("SMCI%",),
)

show(
    "stocks_to_check",
    """
    SELECT ASXCode, StockGroupType, CreateDate
    FROM StockDB_US.LookupRef.StocksToCheck
    WHERE ASXCode LIKE ?
    ORDER BY ASXCode, StockGroupType
    """,
    ("SMCI%",),
)

show(
    "stocks_to_check_group_type_counts",
    """
    SELECT StockGroupType, COUNT(*) AS Cnt
    FROM StockDB_US.LookupRef.StocksToCheck
    GROUP BY StockGroupType
    ORDER BY StockGroupType
    """,
    (),
)

show(
    "trade_stocks_sample",
    """
    SELECT TOP 30 ASXCode, StockGroupType, CreateDate
    FROM StockDB_US.LookupRef.StocksToCheck
    WHERE StockGroupType = 'TRADE'
    ORDER BY ASXCode
    """,
    (),
)

show(
    "price_level_group_members",
    """
    SELECT
        g.GroupID, g.Name, g.IsDefault, g.IsActive, m.ASXCode
    FROM StockDB_US.Configuration.PriceLevelStockGroupMember m
    INNER JOIN StockDB_US.Configuration.PriceLevelStockGroup g
        ON g.GroupID = m.GroupID
    WHERE m.ASXCode LIKE ?
    ORDER BY g.Name
    """,
    ("SMCI%",),
)

show(
    "active_group_members_missing_trade_watchlist",
    """
    SELECT
        g.GroupID,
        g.Name,
        g.IsDefault,
        m.ASXCode,
        m.CreatedAt
    FROM StockDB_US.Configuration.PriceLevelStockGroupMember m
    INNER JOIN StockDB_US.Configuration.PriceLevelStockGroup g
        ON g.GroupID = m.GroupID
    WHERE g.IsActive = 1
      AND NOT EXISTS (
          SELECT 1
          FROM StockDB_US.LookupRef.StocksToCheck s
          WHERE s.ASXCode = m.ASXCode
            AND s.StockGroupType = 'TRADE'
      )
    ORDER BY g.Name, m.ASXCode
    """,
    (),
)

show(
    "daily_history",
    """
    SELECT TOP 10
        ASXCode, ObservationDate, [Open], [High], [Low], [Close], Volume
    FROM StockDB_US.StockData.PriceHistory
    WHERE ASXCode LIKE ?
    ORDER BY ObservationDate DESC
    """,
    ("SMCI%",),
)

show(
    "summary_today",
    """
    SELECT TOP 10
        ASXCode, DateFrom, [Open], [High], [Low], [Close],
        VolumeDelta, ValueDelta, VWAP
    FROM StockDB_US.StockData.PriceSummaryToday
    WHERE ASXCode LIKE ?
    ORDER BY DateFrom DESC
    """,
    ("SMCI%",),
)

show(
    "price_summary",
    """
    SELECT TOP 10
        ASXCode, DateFrom, [Open], [High], [Low], [Close],
        VolumeDelta, ValueDelta, VWAP
    FROM StockDB_US.StockData.PriceSummary
    WHERE ASXCode LIKE ?
    ORDER BY DateFrom DESC
    """,
    ("SMCI%",),
)
