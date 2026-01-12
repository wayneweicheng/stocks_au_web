from typing import List, Dict, Any
from datetime import date
from app.core.db import get_sql_model
import logging

logger = logging.getLogger(__name__)

DB_NAME = "StockDB"


class BreakoutDataService:
    """Service for querying breakout consolidation analysis data from SQL Server."""

    def __init__(self):
        self.db_name = DB_NAME

    def normalize_stock_code(self, stock_code: str) -> str:
        """
        Normalize stock code by converting to uppercase.

        Args:
            stock_code: Stock code (e.g., "SKK.AX")

        Returns:
            Uppercase stock code (e.g., "SKK.AX")
        """
        return stock_code.upper()

    def get_consolidation_stock_codes(
        self,
        observation_date: date
    ) -> List[Dict[str, Any]]:
        """
        Get list of stock codes with CONSOLIDATION pattern for given observation date.

        Args:
            observation_date: Observation date to query

        Returns:
            List of dictionaries containing ASXCode, BreakoutDate, and other relevant fields

        Raises:
            Exception: If database query fails
        """
        try:
            model = get_sql_model()

            sql = f"""
            SELECT DISTINCT ASXCode, ObservationDate, Pattern, BreakoutDate
            FROM [{self.db_name}].[Transform].[BreakoutWatchlist]
            WHERE ObservationDate = ?
            AND Pattern = 'CONSOLIDATION'
            ORDER BY ASXCode
            """

            params = (observation_date.isoformat(),)
            logger.info(f"Querying consolidation stock codes for {observation_date}")

            rows = model.execute_read_query(sql, params) or []
            logger.info(f"Retrieved {len(rows)} consolidation stock codes for {observation_date}")

            return rows

        except Exception as e:
            logger.error(f"Failed to query consolidation stock codes for {observation_date}: {e}")
            raise

    def get_breakout_date(
        self,
        stock_code: str,
        observation_date: date
    ) -> date:
        """
        Get the BreakoutDate for a specific stock and observation date.

        Args:
            stock_code: Stock code (e.g., 'SKK.AX')
            observation_date: Observation date

        Returns:
            BreakoutDate as a date object

        Raises:
            Exception: If database query fails or no breakout date found
        """
        try:
            model = get_sql_model()

            sql = f"""
            SELECT TOP 1 BreakoutDate
            FROM [{self.db_name}].[Transform].[BreakoutWatchlist]
            WHERE ObservationDate = ?
            AND ASXCode = ?
            AND Pattern = 'CONSOLIDATION'
            """

            params = (observation_date.isoformat(), stock_code)
            logger.info(f"Querying BreakoutDate for {stock_code} on {observation_date}")

            rows = model.execute_read_query(sql, params) or []

            if not rows or not rows[0].get('BreakoutDate'):
                raise ValueError(
                    f"No BreakoutDate found for {stock_code} on {observation_date}. "
                    f"Make sure this stock has a CONSOLIDATION pattern entry."
                )

            breakout_date_value = rows[0]['BreakoutDate']

            # Convert to date if needed
            if isinstance(breakout_date_value, str):
                from datetime import datetime
                breakout_date = datetime.strptime(breakout_date_value[:10], '%Y-%m-%d').date()
            elif hasattr(breakout_date_value, 'date'):
                breakout_date = breakout_date_value.date() if callable(breakout_date_value.date) else breakout_date_value
            else:
                breakout_date = breakout_date_value

            logger.info(f"Found BreakoutDate: {breakout_date} for {stock_code}")
            return breakout_date

        except ValueError:
            # Re-raise ValueError with our custom message
            raise
        except Exception as e:
            logger.error(f"Failed to query BreakoutDate for {stock_code}: {e}")
            raise

    def get_price_history(
        self,
        stock_code: str,
        observation_date: date
    ) -> List[Dict[str, Any]]:
        """
        Query 60 business days of price history for given stock and observation date.

        Args:
            stock_code: Stock code (e.g., 'SKK.AX')
            observation_date: Observation date

        Returns:
            List of dictionaries containing price history data, ordered by ObservationDate ASC

        Raises:
            Exception: If database query fails
        """
        try:
            model = get_sql_model()

            sql = f"""
            SELECT [ASXCode]
                ,[ObservationDate]
                ,[Close]
                ,[Open]
                ,[Low]
                ,[High]
                ,[Volume]
                ,[Value]
                ,[Trades]
                ,CASE WHEN volume > 0 THEN CAST([Value]*1.0/Volume AS DECIMAL(10, 4)) ELSE NULL END AS [VWAP]
                ,[PrevClose]
                ,[PriceChangeVsPrevClose]
                ,[PriceChangeVsOpen]
                ,[Spread]
            FROM [{self.db_name}].[Transform].[PriceHistory]
            WHERE ASXCode = ?
            AND ObservationDate BETWEEN Common.DateAddBusinessDay_Plus(-60, ?) AND ?
            ORDER BY ObservationDate
            """

            params = (stock_code, observation_date.isoformat(), observation_date.isoformat())
            logger.info(f"Querying price history for {stock_code} up to {observation_date} (60 business days)")

            rows = model.execute_read_query(sql, params) or []
            logger.info(f"Retrieved {len(rows)} rows of price history for {stock_code}")

            return rows

        except Exception as e:
            logger.error(f"Failed to query price history for {stock_code}: {e}")
            raise

    def get_broker_transactions(
        self,
        stock_code: str,
        observation_date: date
    ) -> List[Dict[str, Any]]:
        """
        Query broker transaction data grouped by Buyer/Seller for given stock and date.

        Args:
            stock_code: Stock code (e.g., 'SKK.AX')
            observation_date: Observation date

        Returns:
            List of dictionaries containing broker transaction data, ordered by TotalVolume DESC

        Raises:
            Exception: If database query fails
            HTTPException: If result exceeds 2000 rows
        """
        try:
            model = get_sql_model()

            sql = f"""
            SELECT
                ObservationDate,
                ASXCode,
                Buyer,
                Seller,
                SUM(Volume) AS TotalVolume,
                SUM([Value]) AS TotalValue,
                CAST(SUM([Value])/SUM(Volume) AS DECIMAL(10, 4)) AS AveragePrice
            FROM [{self.db_name}].[StockData].[BrokerTradeTransaction]
            WHERE ObservationDate = ?
            AND ASXCode = ?
            GROUP BY
                ObservationDate,
                ASXCode,
                Buyer,
                Seller
            ORDER BY TotalVolume DESC
            """

            params = (observation_date.isoformat(), stock_code)
            logger.info(f"Querying broker transactions for {stock_code} on {observation_date}")

            rows = model.execute_read_query(sql, params) or []
            logger.info(f"Retrieved {len(rows)} rows of broker transaction data for {stock_code}")

            # Check row count limit
            if len(rows) > 2000:
                error_msg = (
                    f"Broker transaction data exceeds 2000 rows ({len(rows)} rows returned) for {stock_code} "
                    f"on {observation_date}. This is unusual and may indicate a data quality issue. "
                    f"Please contact support or try a different stock/date."
                )
                logger.error(error_msg)
                raise ValueError(error_msg)

            return rows

        except ValueError:
            # Re-raise ValueError (our custom 2000 row limit error)
            raise
        except Exception as e:
            logger.error(f"Failed to query broker transactions for {stock_code}: {e}")
            raise

    def format_as_tab_delimited(self, rows: List[Dict[str, Any]], title: str = "") -> str:
        """
        Convert query results to tab-delimited string format for LLM consumption.

        Args:
            rows: List of dictionaries from database query
            title: Optional title to prepend to the data

        Returns:
            Tab-delimited string with optional title, header row, and data rows
        """
        if not rows:
            return f"{title}\n(No data available)" if title else "(No data available)"

        # Get all columns from first row
        columns = list(rows[0].keys())

        # Create header row
        header = "\t".join(columns)

        # Create data rows
        data_rows = []
        for row in rows:
            # Convert each value to string, handling None
            values = []
            for col in columns:
                val = row.get(col)
                if val is None:
                    values.append("")
                elif isinstance(val, float):
                    # Round to 4 decimal places for readability
                    values.append(f"{val:.4f}")
                else:
                    values.append(str(val))
            data_rows.append("\t".join(values))

        # Combine title (if provided), header, and data
        result_parts = []
        if title:
            result_parts.append(title)
        result_parts.append(header)
        result_parts.extend(data_rows)

        result = "\n".join(result_parts)

        logger.info(
            f"Formatted {len(rows)} rows x {len(columns)} columns into tab-delimited format "
            f"({len(result)} characters)"
        )

        return result
