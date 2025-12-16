from typing import List, Dict, Any, Optional
from datetime import date
from app.core.db import get_db_connection
import logging

logger = logging.getLogger(__name__)


class SignalStrengthDBService:
    """Service for managing signal strength data in the database."""

    # Signal strength data is stored in StockDB_US database (where GEX data resides)
    DATABASE = "StockDB_US"
    # Use Analysis schema to match other GEX tables
    SCHEMA = "Analysis"
    TABLE = "SignalStrength"

    @staticmethod
    def upsert_signal_strength(
        stock_code: str,
        observation_date: date,
        signal_strength_level: str
    ) -> bool:
        """
        Insert or update signal strength record for a stock on a given date.

        Uses SQL Server MERGE statement for atomic upsert operation.

        Args:
            stock_code: Stock code (e.g., "NVDA", "SPY")
            observation_date: Observation date
            signal_strength_level: One of STRONGLY_BULLISH, MILDLY_BULLISH, NEUTRAL, MILDLY_BEARISH, STRONGLY_BEARISH

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
                USING (SELECT ? AS ObservationDate, ? AS StockCode, ? AS SignalStrengthLevel) AS source
                ON (target.ObservationDate = source.ObservationDate AND target.StockCode = source.StockCode)
                WHEN MATCHED THEN
                    UPDATE SET SignalStrengthLevel = source.SignalStrengthLevel,
                               UpdatedAt = GETDATE()
                WHEN NOT MATCHED THEN
                    INSERT (ObservationDate, StockCode, SignalStrengthLevel, CreatedAt, UpdatedAt)
                    VALUES (source.ObservationDate, source.StockCode, source.SignalStrengthLevel, GETDATE(), GETDATE());
            """

            cursor.execute(merge_query, (observation_date, stock_code, signal_strength_level))
            conn.commit()

            logger.info(
                f"Upserted signal strength: {stock_code} on {observation_date} -> {signal_strength_level}"
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
    def get_signal_strengths_by_date(observation_date: date) -> List[Dict[str, Any]]:
        """
        Get all signal strength records for a given observation date.

        Args:
            observation_date: Observation date

        Returns:
            List of dictionaries with keys: stock_code, signal_strength_level, created_at, updated_at
        """
        try:
            # Connect to StockDB_US where signal strength data is stored
            conn = get_db_connection(database=SignalStrengthDBService.DATABASE)
            cursor = conn.cursor()

            query = f"""
                SELECT StockCode, SignalStrengthLevel, CreatedAt, UpdatedAt
                FROM {SignalStrengthDBService.SCHEMA}.{SignalStrengthDBService.TABLE}
                WHERE ObservationDate = ?
                ORDER BY StockCode
            """

            cursor.execute(query, (observation_date,))
            rows = cursor.fetchall()

            results = []
            for row in rows:
                results.append({
                    "stock_code": row[0],
                    "signal_strength_level": row[1],
                    "created_at": row[2].isoformat() if row[2] else None,
                    "updated_at": row[3].isoformat() if row[3] else None
                })

            logger.info(f"Retrieved {len(results)} signal strength records for {observation_date}")
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
    def get_signal_strength(stock_code: str, observation_date: date) -> Optional[str]:
        """
        Get signal strength for a specific stock and date.

        Args:
            stock_code: Stock code
            observation_date: Observation date

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
                WHERE ObservationDate = ? AND StockCode = ?
            """

            cursor.execute(query, (observation_date, stock_code))
            row = cursor.fetchone()

            if row:
                logger.info(f"Retrieved signal strength for {stock_code} on {observation_date}: {row[0]}")
                return row[0]
            else:
                logger.info(f"No signal strength found for {stock_code} on {observation_date}")
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
    def delete_signal_strength(stock_code: str, observation_date: date) -> bool:
        """
        Delete signal strength record for a specific stock and date.

        Args:
            stock_code: Stock code
            observation_date: Observation date

        Returns:
            True if successful, False otherwise
        """
        try:
            # Connect to StockDB_US where signal strength data is stored
            conn = get_db_connection(database=SignalStrengthDBService.DATABASE)
            cursor = conn.cursor()

            delete_query = f"""
                DELETE FROM {SignalStrengthDBService.SCHEMA}.{SignalStrengthDBService.TABLE}
                WHERE ObservationDate = ? AND StockCode = ?
            """

            cursor.execute(delete_query, (observation_date, stock_code))
            conn.commit()

            logger.info(f"Deleted signal strength for {stock_code} on {observation_date}")
            return True

        except Exception as e:
            logger.error(f"Failed to delete signal strength for {stock_code}: {e}")
            return False
        finally:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()
