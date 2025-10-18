from fastapi import APIRouter, HTTPException, Query, Depends
from typing import List, Dict, Any, Optional
from datetime import date
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel
from app.core.db import get_sql_model
from app.routers.auth import verify_credentials
import logging


router = APIRouter(prefix="/api", tags=["pattern-predictions"])
logger = logging.getLogger("app.pattern_predictions")

TABLE_SCHEMA = "Analysis"
TABLE_NAME = "PatternPredictionResults"

ORDER_CANDIDATES = [
    # Prefer high-resolution timestamp, then created date, then ID
    "PredictionTimestamp",
    "CreatedDate",
    "ID",
]

DATE_CANDIDATES = [
    # Prefer logical business date, then created date
    "PredictionDate",
    "CreatedDate",
]


def execute_query(sql: str, params: tuple) -> List[Dict[str, Any]]:
    try:
        model = get_sql_model()
        logger.info(f"SQL exec: {sql} params={params}")
        data = model.execute_read_usp(sql, params)
        return data or []
    except Exception as e:
        logger.exception(f"SQL error executing query: {e}")
        # Never use fallback data; surface error upstream
        raise HTTPException(status_code=500, detail="Database query failed")


def find_existing_column(candidates: List[str]) -> Optional[str]:
    try:
        model = get_sql_model()
        placeholders = ",".join(["?"] * len(candidates))
        sql = (
            f"SELECT name FROM sys.columns WHERE object_id = OBJECT_ID('[{TABLE_SCHEMA}].[{TABLE_NAME}]') "
            f"AND name IN ({placeholders})"
        )
        found = model.execute_read_usp(sql, tuple(candidates)) or []
        found_names = {row.get('name') for row in found if isinstance(row, dict)}
        for col in candidates:
            if col in found_names:
                return col
    except Exception as e:
        logger.warning(f"Failed to inspect columns for {TABLE_SCHEMA}.{TABLE_NAME}: {e}")
    return None


@router.get("/pattern-predictions/sample")
def get_pattern_predictions_sample(
    min_confidence: float = Query(0.85, ge=0.0, le=1.0, description="Minimum ConfidenceScore (0..1)"),
    limit: int = Query(50, ge=1, le=500, description="Max rows to return"),
    username: str = Depends(verify_credentials),
) -> List[Dict[str, Any]]:
    # Rank by PredictionDate DESC as requested
    order_col = "PredictionDate"
    logger.info(f"Using order column: {order_col} for /pattern-predictions/sample")
    order_sql = f" ORDER BY [{order_col}] DESC"
    sql = (
        f"SELECT TOP (?) * FROM [{TABLE_SCHEMA}].[{TABLE_NAME}] "
        f"WHERE ConfidenceScore >= ?{order_sql}"
    )
    return execute_query(sql, (limit, min_confidence))


@router.get("/pattern-predictions")
def get_pattern_predictions(
    min_confidence: float = Query(0.85, ge=0.0, le=1.0, description="Minimum ConfidenceScore (0..1)"),
    codes: Optional[str] = Query(None, description="Comma-separated ASX codes, e.g., LRV,BOB"),
    prediction_date: Optional[date] = Query(None, description="Prediction date (YYYY-MM-DD)"),
    limit: int = Query(100, ge=1, le=2000, description="Max rows to return"),
    username: str = Depends(verify_credentials),
) -> List[Dict[str, Any]]:
    where_clauses = ["ConfidenceScore >= ?"]
    params: list = [min_confidence]

    if prediction_date is not None:
        date_col = find_existing_column(DATE_CANDIDATES)
        if not date_col:
            raise HTTPException(status_code=400, detail="No date column found to filter on")
        logger.info(f"Using date column: {date_col} for filter in /pattern-predictions")
        where_clauses.append(f"CAST([{date_col}] AS date) = ?")
        params.append(prediction_date)

    code_list: Optional[List[str]] = None
    if codes:
        code_list = [c.strip().upper() for c in codes.split(',') if c.strip()]
        if code_list:
            placeholders = ",".join(["?"] * len(code_list))
            where_clauses.append(f"UPPER(ASXCode) IN ({placeholders})")
            params.extend(code_list)

    where_sql = " AND ".join(where_clauses) if where_clauses else "1=1"

    # Rank by PredictionDate DESC as requested
    order_col = "PredictionDate"
    order_sql = f" ORDER BY [{order_col}] DESC"
    logger.info(f"Using order column: {order_col} for /pattern-predictions")
    sql = (
        f"SELECT TOP (?) * FROM [{TABLE_SCHEMA}].[{TABLE_NAME}] "
        f"WHERE {where_sql}{order_sql}"
    )

    # Put TOP(?) first param for execute order
    final_params = [limit] + params
    try:
        return execute_query(sql, tuple(final_params))
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"Unexpected error in /pattern-predictions: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")


