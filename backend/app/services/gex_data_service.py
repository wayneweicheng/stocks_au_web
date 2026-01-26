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
