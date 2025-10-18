from fastapi import APIRouter, HTTPException, Query, Depends
from typing import List, Dict, Any, Optional
from datetime import date
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel
from app.routers.auth import verify_credentials


router = APIRouter(prefix="/api", tags=["pattern-predictions"])


def execute_query(sql: str, params: tuple) -> List[Dict[str, Any]]:
    try:
        model = SQLServerModel(database='StockDB')
        data = model.execute_read_usp(sql, params)
        return data or []
    except Exception as e:
        # Never use fallback data; surface error upstream
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/pattern-predictions/sample")
def get_pattern_predictions_sample(
    min_confidence: float = Query(0.85, ge=0.0, le=1.0, description="Minimum ConfidenceScore (0..1)"),
    limit: int = Query(50, ge=1, le=500, description="Max rows to return"),
    username: str = Depends(verify_credentials),
) -> List[Dict[str, Any]]:
    sql = (
        "SELECT TOP (?) * FROM [Analysis].[PatternPredictionResults] "
        "WHERE ConfidenceScore >= ? ORDER BY CreateDate DESC"
    )
    # Order of params must match placeholders
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
        # Assume column name is CreateDate or PredictionDate; prefer CreateDate as per sample
        where_clauses.append("CAST(CreateDate AS date) = ?")
        params.append(prediction_date)

    code_list: Optional[List[str]] = None
    if codes:
        code_list = [c.strip().upper() for c in codes.split(',') if c.strip()]
        if code_list:
            placeholders = ",".join(["?"] * len(code_list))
            where_clauses.append(f"UPPER(ASXCode) IN ({placeholders})")
            params.extend(code_list)

    where_sql = " AND ".join(where_clauses) if where_clauses else "1=1"

    sql = (
        f"SELECT TOP (?) * FROM [Analysis].[PatternPredictionResults] "
        f"WHERE {where_sql} "
        f"ORDER BY CreateDate DESC"
    )

    # Put TOP(?) first param for execute order
    final_params = [limit] + params
    return execute_query(sql, tuple(final_params))


