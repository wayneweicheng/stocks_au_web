from typing import List, Dict, Any, Optional
from datetime import date
from app.core.db import get_sql_model
import logging
import json

logger = logging.getLogger(__name__)

DB_NAME = "StockDB_US"
TABLE_SCHEMA = "Analysis"
TABLE_NAME = "GEX_Features"


class GEXDataService:
    """Service for querying GEX features data from SQL Server."""

    def __init__(self):
        self.db_name = DB_NAME
        self.schema = TABLE_SCHEMA
        self.table = TABLE_NAME

    def normalize_stock_code(self, stock_code: str) -> str:
        """
        Normalize stock code by stripping .US suffix if present.

        Args:
            stock_code: Stock code (e.g., "BAC" or "BAC.US")

        Returns:
            Base stock code without .US suffix (e.g., "BAC")
        """
        return stock_code.replace(".US", "").replace(".us", "").upper()

    def get_recent_features(
        self,
        stock_code: str,
        observation_date: date,
        days: int = 30
    ) -> List[Dict[str, Any]]:
        """
        Query last N rows of GEX features on or before observation_date for given stock.

        Args:
            stock_code: Stock code (with or without .US suffix)
            observation_date: Observation date to query up to
            days: Number of recent rows to retrieve (default: 30)

        Returns:
            List of dictionaries containing GEX features, ordered by ObservationDate ASC

        Raises:
            Exception: If database query fails
        """
        try:
            # Normalize stock code and append .US for database query
            base_code = self.normalize_stock_code(stock_code)
            db_stock_code = f"{base_code}.US"

            model = get_sql_model()

            # Query: Get top N rows DESC, then reverse to ASC
            sql = f"""
            SELECT * FROM (
                SELECT TOP ({days}) *
                FROM [{self.db_name}].[{self.schema}].[{self.table}]
                WHERE ASXCode = ?
                AND CAST(ObservationDate AS date) <= ?
                ORDER BY ObservationDate DESC
            ) AS LatestRecords
            ORDER BY ObservationDate ASC
            """

            params = (db_stock_code, observation_date.isoformat())
            logger.info(f"Querying GEX features for {db_stock_code} up to {observation_date}")

            rows = model.execute_read_query(sql, params) or []
            logger.info(f"Retrieved {len(rows)} rows for {db_stock_code}")

            return rows

        except Exception as e:
            logger.error(f"Failed to query GEX features for {stock_code}: {e}")
            raise

    def get_latest_observation_date(
        self,
        stock_code: str,
        as_of_date: date
    ) -> Optional[date]:
        """
        Get the most recent ObservationDate (cast to date) on or before as_of_date for a stock.

        Args:
            stock_code: Stock code (with or without .US suffix)
            as_of_date: Upper bound date (inclusive)

        Returns:
            date if found, otherwise None
        """
        try:
            base_code = self.normalize_stock_code(stock_code)
            db_stock_code = f"{base_code}.US"
            model = get_sql_model()

            sql = f"""
            SELECT TOP (1) CAST(ObservationDate AS date) AS ObservationDate
            FROM [{self.db_name}].[{self.schema}].[{self.table}]
            WHERE ASXCode = ?
              AND CAST(ObservationDate AS date) <= ?
            ORDER BY ObservationDate DESC
            """
            params = (db_stock_code, as_of_date.isoformat())
            logger.info(f"Querying latest ObservationDate for {db_stock_code} up to {as_of_date}")
            rows = model.execute_read_query(sql, params) or []
            if not rows:
                return None
            latest = rows[0].get("ObservationDate")
            # rows already cast to date by SQL; still normalize to date object if needed
            return latest if isinstance(latest, date) else date.fromisoformat(str(latest)[:10])
        except Exception as e:
            logger.error(f"Failed to get latest ObservationDate for {stock_code}: {e}")
            return None

    def format_as_tab_delimited(self, rows: List[Dict[str, Any]], essential_columns_only: bool = True) -> str:
        """
        Convert query results to tab-delimited string format for LLM consumption.

        Args:
            rows: List of dictionaries from database query
            essential_columns_only: If True, only include key columns referenced in prompts

        Returns:
            Tab-delimited string with header row and data rows
        """
        if not rows:
            return ""

        # Define essential columns that are actually used in the prediction logic
        essential_cols = [
            "ObservationDate", "Close", "TodayChange",
            "VIX", "RSI", "GEX", "Prev1GEX", "GEXChange", "GEX_ZScore",
            "Stock_DarkPoolBuySellRatio", "MACD_Positive", "MACD_Line",
            "Golden_Setup", "Setup_Trend_Dip", "Is_Swing_Down", "Is_Swing_Up",
            "GEX_Turned_Negative", "GEX_Turned_Positive",
            "SwingIndicator", "PotentialSwingIndicator",
            "GEX_ZScore_VeryLow", "GEX_ZScore_Low", "GEX_ZScore_High", "GEX_ZScore_VeryHigh",
            "Pot_Swing_Up_AND_Neg_GEXChange", "Low_GEX_Z_AND_Pot_Swing_Up",
            "VIX_Very_High", "Negative_GEX_AND_High_VIX",
            "BB_PercentB", "Price_Above_SMA20", "Price_Above_SMA50"
        ]

        # Get available columns from first row
        all_columns = list(rows[0].keys())

        # Use essential columns if requested and available, otherwise use all
        if essential_columns_only:
            columns = [col for col in essential_cols if col in all_columns]
            # If no essential columns found, fall back to all columns
            if not columns:
                columns = all_columns
                logger.warning("No essential columns found, using all columns")
        else:
            columns = all_columns

        # Create header row
        header = "\t".join(columns)

        # Create data rows
        data_rows = []
        for row in rows:
            # Convert each value to string, handling None
            # Round floats to 2 decimal places for readability
            values = []
            for col in columns:
                val = row.get(col)
                if val is None:
                    values.append("")
                elif isinstance(val, float):
                    # Round to 2 decimal places to avoid confusion
                    values.append(f"{val:.2f}")
                else:
                    values.append(str(val))
            data_rows.append("\t".join(values))

        # Combine header and data
        result = header + "\n" + "\n".join(data_rows)

        logger.info(f"Formatted {len(rows)} rows x {len(columns)} columns into tab-delimited format ({len(result)} characters)")

        return result

    def format_as_json(
        self,
        rows: List[Dict[str, Any]],
        essential_columns_only: bool = True
    ) -> str:
        """
        Format GEX features as JSON array.

        Args:
            rows: List of database row dictionaries
            essential_columns_only: If True, only include essential columns for analysis

        Returns:
            JSON string with array of row objects, rounded floats for readability
        """
        if not rows:
            logger.warning("format_as_json called with empty rows")
            return "[]"

        # Define essential columns for analysis (same as tab-delimited)
        essential_cols = [
            "ObservationDate", "Close", "TodayChange",
            "VIX", "RSI", "GEX", "Prev1GEX", "GEXChange", "GEX_ZScore",
            "Stock_DarkPoolBuySellRatio", "MACD_Positive", "MACD_Line",
            "Golden_Setup", "Setup_Trend_Dip", "Is_Swing_Down", "Is_Swing_Up",
            "GEX_Turned_Negative", "GEX_Turned_Positive",
            "SwingIndicator", "PotentialSwingIndicator",
            "GEX_ZScore_VeryLow", "GEX_ZScore_Low", "GEX_ZScore_High", "GEX_ZScore_VeryHigh",
            "Pot_Swing_Up_AND_Neg_GEXChange", "Low_GEX_Z_AND_Pot_Swing_Up",
            "VIX_Very_High", "Negative_GEX_AND_High_VIX",
            "BB_PercentB", "Price_Above_SMA20", "Price_Above_SMA50"
        ]

        # Get available columns from first row
        all_columns = list(rows[0].keys())

        # Use essential columns if requested and available, otherwise use all
        if essential_columns_only:
            columns = [col for col in essential_cols if col in all_columns]
            # If no essential columns found, fall back to all columns
            if not columns:
                columns = all_columns
                logger.warning("No essential columns found, using all columns")
        else:
            columns = all_columns

        # Create cleaned row objects
        cleaned_rows = []
        for row in rows:
            cleaned_row = {}
            for col in columns:
                val = row.get(col)
                if val is None:
                    cleaned_row[col] = None
                elif isinstance(val, float):
                    # Round to 2 decimal places for readability
                    cleaned_row[col] = round(val, 2)
                else:
                    cleaned_row[col] = val
            cleaned_rows.append(cleaned_row)

        # Convert to JSON with nice formatting
        result = json.dumps(cleaned_rows, indent=2, default=str)

        logger.info(f"Formatted {len(rows)} rows x {len(columns)} columns into JSON format ({len(result)} characters)")

        return result

    def get_option_trades(
        self,
        stock_code: str,
        observation_date: date
    ) -> List[Dict[str, Any]]:
        """
        Query large option trades (size > 300) for a stock on an observation date.

        Args:
            stock_code: Stock code (with or without .US suffix)
            observation_date: Observation date to query

        Returns:
            List of dictionaries containing option trade data, ordered by SaleTime
        """
        try:
            base_code = self.normalize_stock_code(stock_code)
            db_stock_code = f"{base_code}.US"
            model = get_sql_model()

            sql = """
            SELECT Underlying, OptionSymbol, SaleTime, ExpiryDate, Strike,
                   PorC AS PutOrCall, Price, Size, Exchange, SpecialConditions
            FROM StockDB_US.[StockData].[v_OptionTrade]
            WHERE ObservationDate = ?
            AND ASXCode = ?
            AND Size > 300
            ORDER BY SaleTime
            """

            params = (observation_date.isoformat(), db_stock_code)
            logger.info(f"Querying option trades for {db_stock_code} on {observation_date}")

            rows = model.execute_read_query(sql, params) or []
            logger.info(f"Retrieved {len(rows)} option trades for {db_stock_code}")

            return rows

        except Exception as e:
            logger.error(f"Failed to query option trades for {stock_code}: {e}")
            raise

    def get_price_bars_30m(
        self,
        stock_code: str,
        observation_date: date,
        lookback_days: int = 5
    ) -> List[Dict[str, Any]]:
        """
        Query 30-minute price bars for a stock over the last N days.

        Args:
            stock_code: Stock code (with or without .US suffix)
            observation_date: End date for the lookback window
            lookback_days: Number of days to look back (default: 5)

        Returns:
            List of dictionaries containing 30-min OHLCV bar data, ordered by TimeIntervalStart
        """
        try:
            base_code = self.normalize_stock_code(stock_code)
            db_stock_code = f"{base_code}.US"
            model = get_sql_model()

            sql = """
            SELECT TimeIntervalStart, [Open], [High], [Low], [Close], Volume, NumOfSale, VWAP
            FROM StockDB_US.[StockData].[PriceHistoryTimeFrame]
            WHERE TimeIntervalStart >= DATEADD(day, -?, ?)
            AND TimeIntervalStart <= DATEADD(hour, 23, CAST(? AS datetime))
            AND ASXCode = ?
            AND TimeFrame = '30M'
            ORDER BY TimeIntervalStart
            """

            params = (lookback_days, observation_date.isoformat(), observation_date.isoformat(), db_stock_code)
            logger.info(f"Querying 30M price bars for {db_stock_code} (last {lookback_days} days up to {observation_date})")

            rows = model.execute_read_query(sql, params) or []
            logger.info(f"Retrieved {len(rows)} 30M bars for {db_stock_code}")

            return rows

        except Exception as e:
            logger.error(f"Failed to query 30M price bars for {stock_code}: {e}")
            raise

    def get_price_bars_5m(
        self,
        stock_code: str,
        observation_date: date
    ) -> List[Dict[str, Any]]:
        """
        Query 5-minute price bars for a stock on the observation date.

        Args:
            stock_code: Stock code (with or without .US suffix)
            observation_date: Observation date to query

        Returns:
            List of dictionaries containing 5-min OHLCV bar data, ordered by TimeIntervalStart
        """
        try:
            base_code = self.normalize_stock_code(stock_code)
            db_stock_code = f"{base_code}.US"
            model = get_sql_model()

            sql = """
            SELECT TimeIntervalStart, [Open], [High], [Low], [Close], Volume, NumOfSale, VWAP
            FROM StockDB_US.[StockData].[PriceHistoryTimeFrame]
            WHERE ObservationDate = ?
            AND ASXCode = ?
            AND TimeFrame = '5M'
            ORDER BY TimeIntervalStart
            """

            params = (observation_date.isoformat(), db_stock_code)
            logger.info(f"Querying 5M price bars for {db_stock_code} on {observation_date}")

            rows = model.execute_read_query(sql, params) or []
            logger.info(f"Retrieved {len(rows)} 5M bars for {db_stock_code}")

            return rows

        except Exception as e:
            logger.error(f"Failed to query 5M price bars for {stock_code}: {e}")
            raise

    def format_option_trades_as_pipe_delimited(self, rows: List[Dict[str, Any]]) -> str:
        """
        Format option trade data as pipe-delimited format for LLM consumption.

        Args:
            rows: List of option trade dictionaries

        Returns:
            Pipe-delimited string or descriptive message if no data
        """
        if not rows:
            return "No large option trades (size > 300) recorded for this date."

        # Get columns from first row
        columns = list(rows[0].keys())

        # Create header row
        header = "|".join(columns)

        # Create data rows
        data_rows = []
        for row in rows:
            values = []
            for col in columns:
                val = row.get(col)
                if val is None:
                    values.append("")
                elif isinstance(val, float):
                    values.append(f"{val:.2f}")
                else:
                    values.append(str(val))
            data_rows.append("|".join(values))

        result = header + "\n" + "\n".join(data_rows)
        logger.info(f"Formatted {len(rows)} option trades into pipe-delimited format ({len(result)} characters)")
        return result

    def format_price_bars_as_pipe_delimited(self, rows: List[Dict[str, Any]]) -> str:
        """
        Format 30-minute price bar data as pipe-delimited format for LLM consumption.

        Args:
            rows: List of price bar dictionaries

        Returns:
            Pipe-delimited string or descriptive message if no data
        """
        if not rows:
            return "No 30-minute bar data available for the lookback period."

        # Get columns from first row
        columns = list(rows[0].keys())

        # Create header row
        header = "|".join(columns)

        # Create data rows
        data_rows = []
        for row in rows:
            values = []
            for col in columns:
                val = row.get(col)
                if val is None:
                    values.append("")
                elif isinstance(val, float):
                    values.append(f"{val:.2f}")
                else:
                    values.append(str(val))
            data_rows.append("|".join(values))

        result = header + "\n" + "\n".join(data_rows)
        logger.info(f"Formatted {len(rows)} price bars into pipe-delimited format ({len(result)} characters)")
        return result

    def get_option_oi_changes(
        self,
        stock_code: str,
        observation_date: date
    ) -> List[Dict[str, Any]]:
        """
        Query option OI changes between observation_date and previous business day.
        Returns options where OI changed by more than 300 contracts, ordered by absolute change descending.

        Args:
            stock_code: Stock code (with or without .US suffix)
            observation_date: Current observation date

        Returns:
            List of dictionaries containing option OI change data
        """
        try:
            base_code = self.normalize_stock_code(stock_code)
            db_stock_code = f"{base_code}.US"
            model = get_sql_model()

            sql = """
            SELECT
                x.OpenInterest - y.OpenInterest as OIChanges,
                x.*,
                y.OpenInterest as PrevOpenInterest,
                y.LastTradePrice as PrevLastTradePrice
            FROM
            (
                SELECT *
                FROM StockDB_US.StockData.v_OptionDelayedQuote_V2
                WHERE ObservationDate = ?
                AND ASXCode = ?
            ) as x
            INNER JOIN
            (
                SELECT *
                FROM StockDB_US.StockData.v_OptionDelayedQuote_V2
                WHERE ObservationDate = Common.DateAddBusinessDay_Plus(-1, ?)
                AND ASXCode = ?
            ) as y
            ON x.OptionSymbol = y.OptionSymbol
            WHERE x.OpenInterest != y.OpenInterest
            AND ABS(x.OpenInterest - y.OpenInterest) > 300
            ORDER BY ABS(x.OpenInterest - y.OpenInterest) DESC
            """

            params = (
                observation_date.isoformat(),
                db_stock_code,
                observation_date.isoformat(),
                db_stock_code
            )
            logger.info(f"Querying option OI changes for {db_stock_code} on {observation_date}")

            rows = model.execute_read_query(sql, params) or []
            logger.info(f"Retrieved {len(rows)} option OI changes for {db_stock_code}")

            return rows

        except Exception as e:
            logger.error(f"Failed to query option OI changes for {stock_code}: {e}")
            raise

    def format_option_oi_changes_as_pipe_delimited(
        self,
        rows: List[Dict[str, Any]],
        max_rows: Optional[int] = None,
    ) -> str:
        """
        Format option OI change data as pipe-delimited format for LLM consumption.

        The SQL query that populates rows already orders by ABS(OIChanges) DESC,
        so applying max_rows keeps the most significant OI changes and discards
        the tail — the best subset for LLM analysis while staying within provider
        context limits.

        Args:
            rows: List of option OI change dictionaries (pre-sorted by abs change desc)
            max_rows: If set, truncate to this many rows (keeps highest-impact changes)

        Returns:
            Pipe-delimited string or descriptive message if no data
        """
        if not rows:
            return "No significant option OI changes (abs change > 300) for this date."

        total = len(rows)
        if max_rows is not None and total > max_rows:
            rows = rows[:max_rows]
            logger.info(
                f"Truncated OI changes from {total} to {max_rows} rows (keeping largest abs changes)"
            )

        # Get columns from first row
        columns = list(rows[0].keys())

        # Create header row
        header = "|".join(columns)

        # Create data rows
        data_rows = []
        for row in rows:
            values = []
            for col in columns:
                val = row.get(col)
                if val is None:
                    values.append("")
                elif isinstance(val, float):
                    values.append(f"{val:.2f}")
                else:
                    values.append(str(val))
            data_rows.append("|".join(values))

        result = header + "\n" + "\n".join(data_rows)
        logger.info(f"Formatted {len(rows)} option OI changes into pipe-delimited format ({len(result)} characters)")
        return result

    def get_top_options_by_oi(
        self,
        stock_code: str,
        observation_date: date,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """
        Query top N options by open interest, filtered to options expiring within 90 days.

        Args:
            stock_code: Stock code (with or without .US suffix)
            observation_date: Observation date to query
            limit: Number of top options to return (default: 50)

        Returns:
            List of dictionaries containing option data, ordered by OpenInterest descending
        """
        try:
            base_code = self.normalize_stock_code(stock_code)
            db_stock_code = f"{base_code}.US"
            model = get_sql_model()

            sql = f"""
            SELECT TOP ({limit}) *
            FROM StockDB_US.StockData.v_OptionDelayedQuote_V2
            WHERE ObservationDate = ?
            AND ASXCode = ?
            AND DATEADD(day, 90, ?) > ExpiryDate
            ORDER BY OpenInterest DESC
            """

            params = (
                observation_date.isoformat(),
                db_stock_code,
                observation_date.isoformat()
            )
            logger.info(f"Querying top {limit} options by OI for {db_stock_code} on {observation_date}")

            rows = model.execute_read_query(sql, params) or []
            logger.info(f"Retrieved {len(rows)} options by OI for {db_stock_code}")

            return rows

        except Exception as e:
            logger.error(f"Failed to query top options by OI for {stock_code}: {e}")
            raise

    def format_top_options_by_oi_as_pipe_delimited(self, rows: List[Dict[str, Any]]) -> str:
        """
        Format top options by OI data as pipe-delimited format for LLM consumption.

        Args:
            rows: List of option dictionaries

        Returns:
            Pipe-delimited string or descriptive message if no data
        """
        if not rows:
            return "No option data available for this date."

        # Get columns from first row
        columns = list(rows[0].keys())

        # Create header row
        header = "|".join(columns)

        # Create data rows
        data_rows = []
        for row in rows:
            values = []
            for col in columns:
                val = row.get(col)
                if val is None:
                    values.append("")
                elif isinstance(val, float):
                    values.append(f"{val:.2f}")
                else:
                    values.append(str(val))
            data_rows.append("|".join(values))

        result = header + "\n" + "\n".join(data_rows)
        logger.info(f"Formatted {len(rows)} top options by OI into pipe-delimited format ({len(result)} characters)")
        return result

    def get_discord_messages(
        self,
        observation_date: date
    ) -> List[Dict[str, Any]]:
        """
        Query Discord messages for a specific observation date.

        Args:
            observation_date: Date to query Discord messages for

        Returns:
            List of dictionaries containing Discord message data, ordered by TimeStamp descending
        """
        try:
            model = get_sql_model()

            sql = """
            SELECT MessageId, ChannelId,
                   CAST(TimeStamp AS datetime) as TimeStamp_Sydney,
                   UserName, Content, CreateDate,
                   CAST(TimeStamp_USEst AS datetime) as TimeStamp_USEst
            FROM StockDB_US.Discord.v_DiscordMessages
            WHERE CAST(TimeStamp AS date) = CAST(? AS date)
            ORDER BY TimeStamp DESC
            """

            params = (observation_date.isoformat(),)
            logger.info(f"Querying Discord messages for {observation_date}")

            rows = model.execute_read_query(sql, params) or []
            logger.info(f"Retrieved {len(rows)} Discord messages for {observation_date}")

            return rows

        except Exception as e:
            logger.error(f"Failed to query Discord messages for {observation_date}: {e}")
            raise

    def get_discord_messages_by_users(
        self,
        observation_date: date,
        usernames: List[str]
    ) -> List[Dict[str, Any]]:
        """
        Query Discord messages for a specific observation date and a set of usernames.

        Args:
            observation_date: Date to query Discord messages for
            usernames: List of Discord usernames to filter by

        Returns:
            List of dictionaries containing Discord message data, ordered by TimeStamp descending
        """
        if not usernames:
            return []

        try:
            model = get_sql_model()

            placeholders = ", ".join(["?"] * len(usernames))
            sql = f"""
            SELECT MessageId, ChannelId,
                   CAST(TimeStamp AS datetime) as TimeStamp_Sydney,
                   UserName, Content, CreateDate,
                   CAST(TimeStamp_USEst AS datetime) as TimeStamp_USEst
            FROM StockDB_US.Discord.v_DiscordMessages
            WHERE CAST(TimeStamp AS date) = CAST(? AS date)
              AND UserName IN ({placeholders})
            ORDER BY TimeStamp DESC
            """

            params = [observation_date.isoformat(), *usernames]
            logger.info(f"Querying Discord messages for {observation_date} (users: {len(usernames)})")

            rows = model.execute_read_query(sql, params) or []
            logger.info(f"Retrieved {len(rows)} Discord messages for {observation_date} (filtered)")

            return rows

        except Exception as e:
            logger.error(f"Failed to query Discord messages by users for {observation_date}: {e}")
            raise

    def format_discord_messages_as_pipe_delimited(self, rows: List[Dict[str, Any]]) -> str:
        """
        Format Discord message data as pipe-delimited format for LLM consumption.

        Args:
            rows: List of Discord message dictionaries

        Returns:
            Pipe-delimited string or descriptive message if no data
        """
        if not rows:
            return "No Discord messages found for this date."

        # Get columns from first row
        columns = list(rows[0].keys())

        # Create header row
        header = "|".join(columns)

        # Create data rows
        data_rows = []
        for row in rows:
            values = []
            for col in columns:
                val = row.get(col)
                if val is None:
                    values.append("")
                elif isinstance(val, float):
                    values.append(f"{val:.2f}")
                else:
                    values.append(str(val))
            data_rows.append("|".join(values))

        result = header + "\n" + "\n".join(data_rows)
        logger.info(f"Formatted {len(rows)} Discord messages into pipe-delimited format ({len(result)} characters)")
        return result
