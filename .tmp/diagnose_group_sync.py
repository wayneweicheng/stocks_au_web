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


for code in ("HOOD.US", "SMCI.US"):
    show(
        f"{code}_group_membership",
        """
        SELECT g.GroupID, g.Name, g.IsDefault, g.IsActive, m.ASXCode, m.CreatedAt
        FROM StockDB_US.Configuration.PriceLevelStockGroupMember m
        INNER JOIN StockDB_US.Configuration.PriceLevelStockGroup g
            ON g.GroupID = m.GroupID
        WHERE m.ASXCode = ?
        ORDER BY g.Name
        """,
        (code,),
    )
    show(
        f"{code}_stocks_to_check",
        """
        SELECT ASXCode, StockGroupType, CreateDate
        FROM StockDB_US.LookupRef.StocksToCheck
        WHERE ASXCode = ?
        ORDER BY StockGroupType
        """,
        (code,),
    )

show(
    "active_group_members_missing_trade_watchlist",
    """
    SELECT g.GroupID, g.Name, m.ASXCode, m.CreatedAt
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
)

show(
    "orphan_trade_watchlist_rows",
    """
    SELECT s.ASXCode, s.StockGroupType, s.CreateDate
    FROM StockDB_US.LookupRef.StocksToCheck s
    WHERE s.StockGroupType = 'TRADE'
      AND NOT EXISTS (
          SELECT 1
          FROM StockDB_US.Configuration.PriceLevelStockGroupMember m
          INNER JOIN StockDB_US.Configuration.PriceLevelStockGroup g
              ON g.GroupID = m.GroupID
          WHERE g.IsActive = 1
            AND m.ASXCode = s.ASXCode
      )
    ORDER BY s.ASXCode
    """,
)
