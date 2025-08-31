from fastapi import APIRouter, HTTPException, Query
from typing import List, Dict, Any
from datetime import date
from app.core.db import get_sql_model


router = APIRouter(prefix="/api", tags=["ta-scan"])


def rows_to_dicts(cursor) -> List[Dict[str, Any]]:
    columns = [col[0] for col in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


@router.get("/ta-scan")
def get_ta_scan(
    observation_date: date = Query(..., alias="date", description="Observation date, e.g. 2025-01-31"),
    sort_by: str = Query("Price Changes", description="Sort choice"),
) -> List[Dict[str, Any]]:
    sql = (
        "exec [Report].[usp_GetStockScanResult_By_Date] "
        "@pvchSortBy = ?, @pdtObservationDate = ?"
    )
    try:
        model = get_sql_model()
        data = model.execute_read_query(sql, (sort_by, observation_date))
        return data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


