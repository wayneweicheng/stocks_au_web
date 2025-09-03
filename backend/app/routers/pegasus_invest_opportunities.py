from fastapi import APIRouter, HTTPException, Query, Depends
from typing import List, Dict, Any
from datetime import date
from app.core.db import get_sql_model
from app.routers.auth import verify_credentials


router = APIRouter(prefix="/api", tags=["pegasus-invest-opportunities"])


def rows_to_dicts(cursor) -> List[Dict[str, Any]]:
    columns = [col[0] for col in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


@router.get("/pegasus-invest-opportunities")
def get_pegasus_invest_opportunities(
    observation_date: date = Query(..., alias="observation_date", description="Observation date, e.g. 2025-09-03"),
    tier: str = Query(..., description="Pegasus Group tier"),
    username: str = Depends(verify_credentials)
) -> List[Dict[str, Any]]:
    sql = (
        "exec [StockAI].[usp_Get_BRWeeklyInvesthStrategy_Delta] "
        "@pdtObservationDate = ?, @pvchTier = ?"
    )
    try:
        model = get_sql_model()
        data = model.execute_read_query(sql, (observation_date, tier))
        return data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))