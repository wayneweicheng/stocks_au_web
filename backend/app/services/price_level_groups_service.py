from __future__ import annotations

from typing import Any, Dict, List, Optional

from app.core.db import get_db_connection

DATABASE = "StockDB_US"
SCHEMA = "Configuration"
GROUP_TABLE = "PriceLevelStockGroup"
MEMBER_TABLE = "PriceLevelStockGroupMember"
STOCKS_TO_CHECK_SCHEMA = "LookupRef"
STOCKS_TO_CHECK_TABLE = "StocksToCheck"
TRADE_STOCK_GROUP_TYPE = "TRADE"


def normalize_stock_code(stock_code: str) -> str:
    code = (stock_code or "").strip().upper()
    if not code:
        return ""
    return code if code.endswith(".US") else f"{code}.US"


def display_stock_code(stock_code: str) -> str:
    code = (stock_code or "").strip().upper()
    return code[:-3] if code.endswith(".US") else code


class PriceLevelGroupsService:
    def __init__(self) -> None:
        self._ensure_schema()
        self.sync_trade_stocks_to_check()

    def _ensure_schema(self) -> None:
        conn = get_db_connection(database=DATABASE)
        try:
            cursor = conn.cursor()
            cursor.execute(
                f"""
                IF SCHEMA_ID('{SCHEMA}') IS NULL
                    EXEC('CREATE SCHEMA [{SCHEMA}]');

                IF OBJECT_ID('[{SCHEMA}].[{GROUP_TABLE}]', 'U') IS NULL
                BEGIN
                    CREATE TABLE [{SCHEMA}].[{GROUP_TABLE}] (
                        GroupID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
                        Name nvarchar(100) NOT NULL,
                        Description nvarchar(1000) NULL,
                        IsDefault bit NOT NULL CONSTRAINT DF_{GROUP_TABLE}_IsDefault DEFAULT (0),
                        IsActive bit NOT NULL CONSTRAINT DF_{GROUP_TABLE}_IsActive DEFAULT (1),
                        CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_{GROUP_TABLE}_CreatedAt DEFAULT (SYSUTCDATETIME()),
                        UpdatedAt datetime2(0) NOT NULL CONSTRAINT DF_{GROUP_TABLE}_UpdatedAt DEFAULT (SYSUTCDATETIME()),
                        CONSTRAINT UQ_{GROUP_TABLE}_Name UNIQUE (Name)
                    );
                END;

                IF OBJECT_ID('[{SCHEMA}].[{MEMBER_TABLE}]', 'U') IS NULL
                BEGIN
                    CREATE TABLE [{SCHEMA}].[{MEMBER_TABLE}] (
                        GroupMemberID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
                        GroupID int NOT NULL,
                        ASXCode varchar(32) NOT NULL,
                        CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_{MEMBER_TABLE}_CreatedAt DEFAULT (SYSUTCDATETIME()),
                        CONSTRAINT FK_{MEMBER_TABLE}_{GROUP_TABLE}
                            FOREIGN KEY (GroupID) REFERENCES [{SCHEMA}].[{GROUP_TABLE}](GroupID) ON DELETE CASCADE,
                        CONSTRAINT UQ_{MEMBER_TABLE}_GroupCode UNIQUE (GroupID, ASXCode)
                    );
                END;
                """
            )
            conn.commit()
        finally:
            if "cursor" in locals():
                cursor.close()
            conn.close()

    def _sync_trade_stocks_to_check(self, cursor: Any) -> None:
        cursor.execute(
            f"""
            INSERT INTO [{STOCKS_TO_CHECK_SCHEMA}].[{STOCKS_TO_CHECK_TABLE}] (ASXCode, StockGroupType)
            SELECT DISTINCT m.ASXCode, ?
            FROM [{SCHEMA}].[{MEMBER_TABLE}] m
            INNER JOIN [{SCHEMA}].[{GROUP_TABLE}] g ON g.GroupID = m.GroupID
            WHERE g.IsActive = 1
              AND NOT EXISTS (
                  SELECT 1
                  FROM [{STOCKS_TO_CHECK_SCHEMA}].[{STOCKS_TO_CHECK_TABLE}] s
                  WHERE s.ASXCode = m.ASXCode
                    AND s.StockGroupType = ?
              );

            DELETE s
            FROM [{STOCKS_TO_CHECK_SCHEMA}].[{STOCKS_TO_CHECK_TABLE}] s
            WHERE s.StockGroupType = ?
              AND NOT EXISTS (
                  SELECT 1
                  FROM [{SCHEMA}].[{MEMBER_TABLE}] m
                  INNER JOIN [{SCHEMA}].[{GROUP_TABLE}] g ON g.GroupID = m.GroupID
                  WHERE g.IsActive = 1
                    AND m.ASXCode = s.ASXCode
              );
            """,
            (
                TRADE_STOCK_GROUP_TYPE,
                TRADE_STOCK_GROUP_TYPE,
                TRADE_STOCK_GROUP_TYPE,
            ),
        )

    def sync_trade_stocks_to_check(self) -> None:
        conn = get_db_connection(database=DATABASE)
        try:
            cursor = conn.cursor()
            self._sync_trade_stocks_to_check(cursor)
            conn.commit()
        finally:
            if "cursor" in locals():
                cursor.close()
            conn.close()

    def _format_group(self, row: Dict[str, Any], stock_codes: List[str]) -> Dict[str, Any]:
        return {
            "id": int(row["GroupID"]),
            "name": str(row["Name"]),
            "description": row.get("Description"),
            "is_default": bool(row.get("IsDefault")),
            "is_active": bool(row.get("IsActive", True)),
            "stock_codes": [display_stock_code(code) for code in stock_codes],
            "database_codes": stock_codes,
            "stock_count": len(stock_codes),
        }

    def list_groups(self, include_inactive: bool = False) -> List[Dict[str, Any]]:
        conn = get_db_connection(database=DATABASE)
        try:
            cursor = conn.cursor()
            where = "" if include_inactive else "WHERE IsActive = 1"
            cursor.execute(
                f"""
                SELECT GroupID, Name, Description, IsDefault, IsActive
                FROM [{SCHEMA}].[{GROUP_TABLE}]
                {where}
                ORDER BY IsDefault DESC, Name ASC
                """
            )
            columns = [column[0] for column in cursor.description]
            groups = [dict(zip(columns, row)) for row in cursor.fetchall()]

            cursor.execute(
                f"""
                SELECT m.GroupID, m.ASXCode
                FROM [{SCHEMA}].[{MEMBER_TABLE}] m
                INNER JOIN [{SCHEMA}].[{GROUP_TABLE}] g ON g.GroupID = m.GroupID
                {where.replace('IsActive', 'g.IsActive')}
                ORDER BY m.ASXCode
                """
            )
            memberships: Dict[int, List[str]] = {}
            for group_id, stock_code in cursor.fetchall():
                memberships.setdefault(int(group_id), []).append(str(stock_code))

            return [
                self._format_group(group, memberships.get(int(group["GroupID"]), []))
                for group in groups
            ]
        finally:
            if "cursor" in locals():
                cursor.close()
            conn.close()

    def get_group(self, group_id: int) -> Optional[Dict[str, Any]]:
        groups = self.list_groups(include_inactive=True)
        return next((group for group in groups if group["id"] == group_id), None)

    def get_default_group(self) -> Optional[Dict[str, Any]]:
        groups = self.list_groups(include_inactive=False)
        return next((group for group in groups if group["is_default"]), groups[0] if groups else None)

    def get_group_stock_codes(self, group_id: int) -> List[str]:
        group = self.get_group(group_id)
        if not group or not group["is_active"]:
            return []
        return [normalize_stock_code(code) for code in group["database_codes"]]

    def upsert_group(
        self,
        name: str,
        description: Optional[str],
        is_default: bool,
        stock_codes: List[str],
        group_id: Optional[int] = None,
    ) -> Dict[str, Any]:
        clean_name = name.strip()
        if not clean_name:
            raise ValueError("Group name is required")
        clean_codes = sorted({code for code in (normalize_stock_code(item) for item in stock_codes) if code})

        conn = get_db_connection(database=DATABASE)
        try:
            cursor = conn.cursor()
            if is_default:
                cursor.execute(f"UPDATE [{SCHEMA}].[{GROUP_TABLE}] SET IsDefault = 0")

            if group_id is None:
                cursor.execute(
                    f"""
                    INSERT INTO [{SCHEMA}].[{GROUP_TABLE}] (Name, Description, IsDefault, IsActive)
                    OUTPUT INSERTED.GroupID
                    VALUES (?, ?, ?, 1)
                    """,
                    (clean_name, description, 1 if is_default else 0),
                )
                group_id = int(cursor.fetchone()[0])
            else:
                cursor.execute(
                    f"""
                    UPDATE [{SCHEMA}].[{GROUP_TABLE}]
                    SET Name = ?, Description = ?, IsDefault = ?, IsActive = 1, UpdatedAt = SYSUTCDATETIME()
                    WHERE GroupID = ?
                    """,
                    (clean_name, description, 1 if is_default else 0, group_id),
                )
                if cursor.rowcount == 0:
                    raise LookupError("Group not found")

            cursor.execute(
                f"DELETE FROM [{SCHEMA}].[{MEMBER_TABLE}] WHERE GroupID = ?",
                (group_id,),
            )
            for code in clean_codes:
                cursor.execute(
                    f"INSERT INTO [{SCHEMA}].[{MEMBER_TABLE}] (GroupID, ASXCode) VALUES (?, ?)",
                    (group_id, code),
                )

            self._sync_trade_stocks_to_check(cursor)
            conn.commit()
            group = self.get_group(group_id)
            if not group:
                raise LookupError("Group not found after save")
            return group
        except Exception:
            conn.rollback()
            raise
        finally:
            if "cursor" in locals():
                cursor.close()
            conn.close()

    def delete_group(self, group_id: int) -> bool:
        conn = get_db_connection(database=DATABASE)
        try:
            cursor = conn.cursor()
            cursor.execute(
                f"UPDATE [{SCHEMA}].[{GROUP_TABLE}] SET IsActive = 0, IsDefault = 0, UpdatedAt = SYSUTCDATETIME() WHERE GroupID = ?",
                (group_id,),
            )
            deleted = cursor.rowcount > 0
            if deleted:
                self._sync_trade_stocks_to_check(cursor)
            conn.commit()
            return deleted
        finally:
            if "cursor" in locals():
                cursor.close()
            conn.close()

    def list_available_stocks(self) -> List[Dict[str, str]]:
        conn = get_db_connection(database=DATABASE)
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                SELECT ASXCode, MAX(TimeIntervalStart) AS LatestBarTime
                FROM StockDB_US.StockData.PriceHistoryTimeFrame
                WHERE TimeFrame = '30M'
                GROUP BY ASXCode
                ORDER BY ASXCode
                """
            )
            columns = [column[0] for column in cursor.description]
            rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
            return [
                {
                    "stock_code": display_stock_code(str(row["ASXCode"])),
                    "database_code": str(row["ASXCode"]),
                    "latest_bar_time": row["LatestBarTime"].isoformat()
                    if hasattr(row["LatestBarTime"], "isoformat")
                    else str(row["LatestBarTime"]),
                }
                for row in rows
            ]
        finally:
            if "cursor" in locals():
                cursor.close()
            conn.close()
