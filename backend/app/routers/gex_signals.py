from fastapi import APIRouter, HTTPException, Query, Depends
from typing import List, Dict, Any, Optional
from datetime import date
from app.core.db import get_sql_model
from app.routers.auth import verify_credentials
import logging


router = APIRouter(prefix="/api", tags=["gex-signals"])
logger = logging.getLogger("app.gex_signals")

DB_NAME = "StockDB_US"
TABLE_SCHEMA = "Analysis"
TABLE_NAME = "GEX_Features"

# Column candidates to be resilient to schema variations
DATE_CANDIDATES = [
    "ObservationDate",
    "Date",
    "AsOfDate",
    "BusinessDate",
    "CalcDate",
    "TradeDate",
]
CODE_CANDIDATES = [
    "StockCode",
    "ASXCode",
    "Ticker",
    "Symbol",
    "Code",
    "Underlying",
    "Instrument",
    "Stock",
]


def find_existing_column(candidates: List[str]) -> Optional[str]:
    try:
        model = get_sql_model()
        placeholders = ",".join(["?"] * len(candidates))
        sql = (
            f"SELECT COLUMN_NAME AS name "
            f"FROM [{DB_NAME}].INFORMATION_SCHEMA.COLUMNS "
            f"WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME IN ({placeholders})"
        )
        params = (TABLE_SCHEMA, TABLE_NAME, *candidates)
        rows = model.execute_read_query(sql, params) or []
        found_names = {row.get("name") for row in rows if isinstance(row, dict)}
        for col in candidates:
            if col in found_names:
                return col
    except Exception as e:
        logger.warning(f"Failed to inspect columns for {TABLE_SCHEMA}.{TABLE_NAME}: {e}")
    return None


def table_exists() -> bool:
    try:
        model = get_sql_model()
        sql = (
            "SELECT 1 "
            f"FROM [{DB_NAME}].INFORMATION_SCHEMA.TABLES "
            "WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?"
        )
        rows = model.execute_read_query(sql, (TABLE_SCHEMA, TABLE_NAME)) or []
        return len(rows) > 0
    except Exception as e:
        logger.warning(f"Failed to check table existence for {TABLE_SCHEMA}.{TABLE_NAME}: {e}")
        return False


@router.get("/gex-signals")
def get_gex_signals_for_day(
    observation_date: date = Query(..., alias="observation_date", description="Observation date, e.g. 2025-11-21"),
    stock_code: str = Query("SPXW", min_length=1, description="Stock code/symbol, e.g. SPXW, QQQ"),
    username: str = Depends(verify_credentials),
) -> List[Dict[str, Any]]:
    """
    Returns GEX features row(s) for a given observation date and (optionally) stock code.
    If no exact match on date, falls back to the latest row on or before the date.
    """
    try:
        model = get_sql_model()

        if not table_exists():
            raise HTTPException(status_code=404, detail=f"Table [{TABLE_SCHEMA}].[{TABLE_NAME}] not found in database")

        date_col = find_existing_column(DATE_CANDIDATES) or "ObservationDate"
        code_col = find_existing_column(CODE_CANDIDATES)

        where_exact = [f"CAST([{date_col}] AS date) = ?"]
        params_exact: List[Any] = [observation_date]
        if code_col:
            where_exact.append(f"UPPER([{code_col}]) = UPPER(?)")
            params_exact.append(stock_code)

        order_sql = f" ORDER BY [{date_col}] DESC"
        sql_exact = f"SELECT TOP (100) * FROM [{DB_NAME}].[{TABLE_SCHEMA}].[{TABLE_NAME}] WHERE {' AND '.join(where_exact)}{order_sql}"
        logger.info("GEX exact query: %s params=%s", sql_exact, params_exact)
        # Cast date param to str to avoid driver-specific typing issues
        params_exact_safe = list(params_exact)
        if isinstance(params_exact_safe[0], date):
            params_exact_safe[0] = params_exact_safe[0].isoformat()
        data = model.execute_read_query(sql_exact, tuple(params_exact_safe)) or []
        if data:
            return data

        # Fallback: latest on or before the requested date with exact code
        where_fallback = [f"CAST([{date_col}] AS date) <= ?"]
        params_fallback: List[Any] = [observation_date]
        if code_col:
            where_fallback.append(f"UPPER([{code_col}]) = UPPER(?)")
            params_fallback.append(stock_code)
        sql_fallback = f"SELECT TOP (1) * FROM [{DB_NAME}].[{TABLE_SCHEMA}].[{TABLE_NAME}] WHERE {' AND '.join(where_fallback)}{order_sql}"
        logger.info("GEX fallback query: %s params=%s", sql_fallback, params_fallback)
        params_fallback_safe = list(params_fallback)
        if isinstance(params_fallback_safe[0], date):
            params_fallback_safe[0] = params_fallback_safe[0].isoformat()
        data_fb = model.execute_read_query(sql_fallback, tuple(params_fallback_safe)) or []
        if data_fb:
            return data_fb

        # Additional heuristic fallbacks if code_col exists: try LIKE match with code as substring
        if code_col:
            like_token = f"%{stock_code}%"
            where_like_exact_date = [f"CAST([{date_col}] AS date) = ?", f"UPPER([{code_col}]) LIKE UPPER(?)"]
            params_like_exact_date: List[Any] = [observation_date, like_token]
            sql_like_exact_date = (
                f"SELECT TOP (100) * FROM [{DB_NAME}].[{TABLE_SCHEMA}].[{TABLE_NAME}] "
                f"WHERE {' AND '.join(where_like_exact_date)}{order_sql}"
            )
            logger.info("GEX like exact-date query: %s params=%s", sql_like_exact_date, params_like_exact_date)
            params_like_exact_date_safe = list(params_like_exact_date)
            if isinstance(params_like_exact_date_safe[0], date):
                params_like_exact_date_safe[0] = params_like_exact_date_safe[0].isoformat()
            data_like_exact = model.execute_read_query(sql_like_exact_date, tuple(params_like_exact_date_safe)) or []
            if data_like_exact:
                return data_like_exact

            where_like_fallback_date = [f"CAST([{date_col}] AS date) <= ?", f"UPPER([{code_col}]) LIKE UPPER(?)"]
            params_like_fallback_date: List[Any] = [observation_date, like_token]
            sql_like_fallback_date = (
                f"SELECT TOP (1) * FROM [{DB_NAME}].[{TABLE_SCHEMA}].[{TABLE_NAME}] "
                f"WHERE {' AND '.join(where_like_fallback_date)}{order_sql}"
            )
            logger.info("GEX like <=-date query: %s params=%s", sql_like_fallback_date, params_like_fallback_date)
            params_like_fallback_date_safe = list(params_like_fallback_date)
            if isinstance(params_like_fallback_date_safe[0], date):
                params_like_fallback_date_safe[0] = params_like_fallback_date_safe[0].isoformat()
            data_like_fb = model.execute_read_query(sql_like_fallback_date, tuple(params_like_fallback_date_safe)) or []
            if data_like_fb:
                return data_like_fb

        # Last resort: ignore code filter; return most recent row on or before date
        sql_last_resort = (
            f"SELECT TOP (1) * FROM [{DB_NAME}].[{TABLE_SCHEMA}].[{TABLE_NAME}] "
            f"WHERE CAST([{date_col}] AS date) <= ?{order_sql}"
        )
        logger.info("GEX last-resort query (no code filter): %s params=%s", sql_last_resort, [observation_date])
        data_any = model.execute_read_query(sql_last_resort, (observation_date.isoformat(),)) or []
        return data_any
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


