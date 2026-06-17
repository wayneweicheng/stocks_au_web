from typing import List, Dict, Any, Optional
from datetime import date
from decimal import Decimal, InvalidOperation
from app.core.db import get_db_connection
import logging
import re

logger = logging.getLogger(__name__)


class SignalStrengthDBService:
    """Service for managing signal strength data in the database."""

    # Signal strength data is stored in StockDB_US database (where GEX data resides)
    DATABASE = "StockDB_US"
    # Use Analysis schema to match other GEX tables
    SCHEMA = "Analysis"
    TABLE = "SignalStrength"

    @staticmethod
    def _format_price(value: Decimal) -> str:
        return f"${value.quantize(Decimal('0.01')):,.2f}"

    @staticmethod
    def _offset_price_range(price_range: Optional[str], avg_change: Optional[Any], multiplier: int) -> Optional[str]:
        if not price_range or avg_change is None:
            return None

        if "not recommended" in price_range.lower():
            return None

        try:
            change = Decimal(str(avg_change))
        except (InvalidOperation, ValueError):
            return None

        # Keep the extraction focused on the stated price range, not percentage notes in parentheses.
        range_text = price_range.split("(", 1)[0]
        values = re.findall(r"\$?\s*([0-9]+(?:,[0-9]{3})*(?:\.\d+)?)", range_text)
        if not values:
            return None

        try:
            prices = [Decimal(value.replace(",", "")) for value in values[:2]]
        except InvalidOperation:
            return None

        offset_prices = [price + (change * multiplier) for price in prices]
        if len(offset_prices) == 1:
            return SignalStrengthDBService._format_price(offset_prices[0])

        low, high = sorted(offset_prices)
        return f"{SignalStrengthDBService._format_price(low)} - {SignalStrengthDBService._format_price(high)}"

    @staticmethod
    def upsert_signal_strength(
        stock_code: str,
        observation_date: date,
        signal_strength_level: str,
        source_type: str = "GEX",
        buy_dip_range: Optional[str] = None,
        sell_rip_range: Optional[str] = None,
    ) -> bool:
        """
        Insert or update signal strength record for a stock on a given date.

        Uses SQL Server MERGE statement for atomic upsert operation.

        Args:
            stock_code: Stock code (e.g., "NVDA", "SPY")
            observation_date: Observation date
            signal_strength_level: One of STRONGLY_BULLISH, MILDLY_BULLISH, NEUTRAL, MILDLY_BEARISH, STRONGLY_BEARISH, NOT_DETERMINED
            source_type: Source of signal - "GEX" (Market Flow Signals) or "BREAKOUT" (Breakout Analysis). Defaults to "GEX"

        Returns:
            True if successful, False otherwise
        """
        try:
            # Connect to StockDB_US where signal strength data is stored
            conn = get_db_connection(database=SignalStrengthDBService.DATABASE)
            cursor = conn.cursor()

            # Use MERGE for upsert (insert if not exists, update if exists)
            merge_query = f"""
                MERGE INTO {SignalStrengthDBService.SCHEMA}.{SignalStrengthDBService.TABLE} AS target
                USING (
                    SELECT
                        ? AS ObservationDate,
                        ? AS StockCode,
                        ? AS SignalStrengthLevel,
                        ? AS SourceType,
                        ? AS BuyDipRange,
                        ? AS SellRipRange
                ) AS source
                ON (target.ObservationDate = source.ObservationDate AND target.StockCode = source.StockCode AND target.SourceType = source.SourceType)
                WHEN MATCHED THEN
                    UPDATE SET SignalStrengthLevel = source.SignalStrengthLevel,
                               BuyDipRange = source.BuyDipRange,
                               SellRipRange = source.SellRipRange,
                               UpdatedAt = GETDATE()
                WHEN NOT MATCHED THEN
                    INSERT (ObservationDate, StockCode, SignalStrengthLevel, SourceType, BuyDipRange, SellRipRange, CreatedAt, UpdatedAt)
                    VALUES (source.ObservationDate, source.StockCode, source.SignalStrengthLevel, source.SourceType, source.BuyDipRange, source.SellRipRange, GETDATE(), GETDATE());
            """

            try:
                cursor.execute(merge_query, (observation_date, stock_code, signal_strength_level, source_type, buy_dip_range, sell_rip_range))
            except Exception as e:
                # Fallback for legacy schema without Buy/Sell range columns
                logger.warning(f"Upsert with ranges failed, falling back to legacy schema: {e}")
                legacy_merge = f"""
                    MERGE INTO {SignalStrengthDBService.SCHEMA}.{SignalStrengthDBService.TABLE} AS target
                    USING (SELECT ? AS ObservationDate, ? AS StockCode, ? AS SignalStrengthLevel, ? AS SourceType) AS source
                    ON (target.ObservationDate = source.ObservationDate AND target.StockCode = source.StockCode AND target.SourceType = source.SourceType)
                    WHEN MATCHED THEN
                        UPDATE SET SignalStrengthLevel = source.SignalStrengthLevel,
                                   UpdatedAt = GETDATE()
                    WHEN NOT MATCHED THEN
                        INSERT (ObservationDate, StockCode, SignalStrengthLevel, SourceType, CreatedAt, UpdatedAt)
                        VALUES (source.ObservationDate, source.StockCode, source.SignalStrengthLevel, source.SourceType, GETDATE(), GETDATE());
                """
                cursor.execute(legacy_merge, (observation_date, stock_code, signal_strength_level, source_type))
            conn.commit()

            logger.info(
                f"Upserted signal strength: {stock_code} on {observation_date} -> {signal_strength_level} (source: {source_type})"
            )
            return True

        except Exception as e:
            logger.error(f"Failed to upsert signal strength for {stock_code}: {e}")
            return False
        finally:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()

    @staticmethod
    def get_signal_strengths_by_date(observation_date: date, source_type: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        Get all signal strength records for a given observation date.

        Args:
            observation_date: Observation date
            source_type: Optional filter by source type ("GEX" or "BREAKOUT"). If None, returns all.

        Returns:
            List of dictionaries with keys: stock_code, signal_strength_level, source_type, created_at, updated_at
        """
        try:
            # Connect to StockDB_US where signal strength data is stored
            conn = get_db_connection(database=SignalStrengthDBService.DATABASE)
            cursor = conn.cursor()

            if source_type:
                try:
                    query = f"""
                        SELECT
                            s.StockCode,
                            s.SignalStrengthLevel,
                            s.SourceType,
                            s.BuyDipRange,
                            s.SellRipRange,
                            price_range.AvgChange,
                            s.CreatedAt,
                            s.UpdatedAt
                        FROM {SignalStrengthDBService.SCHEMA}.{SignalStrengthDBService.TABLE} s
                        LEFT JOIN (
                            SELECT
                                ph10.ASXCode,
                                AVG(CAST((ph10.[High] - ph10.[Low]) * 0.618 AS DECIMAL(20, 4))) AS AvgChange
                            FROM (
                                SELECT ph.ASXCode, ph.[High], ph.[Low]
                                FROM StockDB_US.Transform.PriceHistory24Month ph
                                WHERE ph.ObservationDate < ?
                                  AND ph.ObservationDate > DATEADD(day, -20, ?)
                            ) ph10
                            GROUP BY ph10.ASXCode
                        ) price_range ON s.StockCode + '.US' = price_range.ASXCode
                        WHERE s.ObservationDate = ? AND s.SourceType = ?
                        ORDER BY s.StockCode
                    """
                    cursor.execute(query, (observation_date, observation_date, observation_date, source_type))
                except Exception as e:
                    logger.warning(f"Select with ranges failed, falling back to legacy schema: {e}")
                    # Fallback without range columns
                    cursor = conn.cursor()
                    query = f"""
                        SELECT StockCode, SignalStrengthLevel, SourceType, CreatedAt, UpdatedAt
                        FROM {SignalStrengthDBService.SCHEMA}.{SignalStrengthDBService.TABLE}
                        WHERE ObservationDate = ? AND SourceType = ?
                        ORDER BY StockCode
                    """
                    cursor.execute(query, (observation_date, source_type))
            else:
                try:
                    query = f"""
                        SELECT
                            s.StockCode,
                            s.SignalStrengthLevel,
                            s.SourceType,
                            s.BuyDipRange,
                            s.SellRipRange,
                            price_range.AvgChange,
                            s.CreatedAt,
                            s.UpdatedAt
                        FROM {SignalStrengthDBService.SCHEMA}.{SignalStrengthDBService.TABLE} s
                        LEFT JOIN (
                            SELECT
                                ph10.ASXCode,
                                AVG(CAST((ph10.[High] - ph10.[Low]) * 0.618 AS DECIMAL(20, 4))) AS AvgChange
                            FROM (
                                SELECT ph.ASXCode, ph.[High], ph.[Low]
                                FROM StockDB_US.Transform.PriceHistory24Month ph
                                WHERE ph.ObservationDate < ?
                                  AND ph.ObservationDate > DATEADD(day, -20, ?)
                            ) ph10
                            GROUP BY ph10.ASXCode
                        ) price_range ON s.StockCode + '.US' = price_range.ASXCode
                        WHERE s.ObservationDate = ?
                        ORDER BY s.StockCode
                    """
                    cursor.execute(query, (observation_date, observation_date, observation_date))
                except Exception as e:
                    logger.warning(f"Select with ranges failed, falling back to legacy schema: {e}")
                    # Fallback without range columns
                    cursor = conn.cursor()
                    query = f"""
                        SELECT StockCode, SignalStrengthLevel, SourceType, CreatedAt, UpdatedAt
                        FROM {SignalStrengthDBService.SCHEMA}.{SignalStrengthDBService.TABLE}
                        WHERE ObservationDate = ?
                        ORDER BY StockCode
                    """
                    cursor.execute(query, (observation_date,))

            rows = cursor.fetchall()

            results = []
            # Detect shape based on column count
            for row in rows:
                if len(row) >= 8:
                    avg_change = row[5]
                    results.append({
                        "stock_code": row[0],
                        "signal_strength_level": row[1],
                        "source_type": row[2],
                        "buy_dip_range": row[3],
                        "sell_rip_range": row[4],
                        "intraday_sell_range": SignalStrengthDBService._offset_price_range(row[3], avg_change, 1),
                        "intraday_buy_range": SignalStrengthDBService._offset_price_range(row[4], avg_change, -1),
                        "created_at": row[6].isoformat() if row[6] else None,
                        "updated_at": row[7].isoformat() if row[7] else None
                    })
                elif len(row) >= 7:
                    results.append({
                        "stock_code": row[0],
                        "signal_strength_level": row[1],
                        "source_type": row[2],
                        "buy_dip_range": row[3],
                        "sell_rip_range": row[4],
                        "intraday_sell_range": None,
                        "intraday_buy_range": None,
                        "created_at": row[5].isoformat() if row[5] else None,
                        "updated_at": row[6].isoformat() if row[6] else None
                    })
                else:
                    # Legacy schema without ranges
                    results.append({
                        "stock_code": row[0],
                        "signal_strength_level": row[1],
                        "source_type": row[2],
                        "buy_dip_range": None,
                        "sell_rip_range": None,
                        "intraday_sell_range": None,
                        "intraday_buy_range": None,
                        "created_at": row[3].isoformat() if row[3] else None,
                        "updated_at": row[4].isoformat() if row[4] else None
                    })

            logger.info(f"Retrieved {len(results)} signal strength records for {observation_date}" +
                       (f" (source: {source_type})" if source_type else ""))
            return results

        except Exception as e:
            logger.error(f"Failed to retrieve signal strengths for {observation_date}: {e}")
            return []
        finally:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()

    @staticmethod
    def get_signal_strength(stock_code: str, observation_date: date, source_type: str = "GEX") -> Optional[str]:
        """
        Get signal strength for a specific stock and date.

        Args:
            stock_code: Stock code
            observation_date: Observation date
            source_type: Source type to query - "GEX" or "BREAKOUT". Defaults to "GEX"

        Returns:
            Signal strength level or None if not found
        """
        try:
            # Connect to StockDB_US where signal strength data is stored
            conn = get_db_connection(database=SignalStrengthDBService.DATABASE)
            cursor = conn.cursor()

            query = f"""
                SELECT SignalStrengthLevel
                FROM {SignalStrengthDBService.SCHEMA}.{SignalStrengthDBService.TABLE}
                WHERE ObservationDate = ? AND StockCode = ? AND SourceType = ?
            """

            cursor.execute(query, (observation_date, stock_code, source_type))
            row = cursor.fetchone()

            if row:
                logger.info(f"Retrieved signal strength for {stock_code} on {observation_date} (source: {source_type}): {row[0]}")
                return row[0]
            else:
                logger.info(f"No signal strength found for {stock_code} on {observation_date} (source: {source_type})")
                return None

        except Exception as e:
            logger.error(f"Failed to retrieve signal strength for {stock_code}: {e}")
            return None
        finally:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()

    @staticmethod
    def delete_signal_strength(stock_code: str, observation_date: date, source_type: str = "GEX") -> bool:
        """
        Delete signal strength record for a specific stock and date.

        Args:
            stock_code: Stock code
            observation_date: Observation date
            source_type: Source type - "GEX" or "BREAKOUT". Defaults to "GEX"

        Returns:
            True if successful, False otherwise
        """
        try:
            # Connect to StockDB_US where signal strength data is stored
            conn = get_db_connection(database=SignalStrengthDBService.DATABASE)
            cursor = conn.cursor()

            delete_query = f"""
                DELETE FROM {SignalStrengthDBService.SCHEMA}.{SignalStrengthDBService.TABLE}
                WHERE ObservationDate = ? AND StockCode = ? AND SourceType = ?
            """

            cursor.execute(delete_query, (observation_date, stock_code, source_type))
            conn.commit()

            logger.info(f"Deleted signal strength for {stock_code} on {observation_date} (source: {source_type})")
            return True

        except Exception as e:
            logger.error(f"Failed to delete signal strength for {stock_code}: {e}")
            return False
        finally:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()
