from fastapi import APIRouter, HTTPException, Query
from typing import List, Dict, Any
from datetime import date
from app.core.db import get_sql_model


router = APIRouter(prefix="/api", tags=["order-book"])


def rows_to_dicts(cursor) -> List[Dict[str, Any]]:
    columns = [col[0] for col in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


@router.get("/stocks")
def get_stocks() -> List[Dict[str, Any]]:
    """Returns ASX stock list used by the Order Book page."""
    sql = "exec [StockData].[usp_GetFirstBuySellStockList]"
    try:
        model = get_sql_model()
        data = model.execute_read_query(sql, ())
        return data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/transactions")
def get_transactions(
    date_from: date = Query(..., description="Observation date, e.g. 2025-01-31"),
    code: str = Query(..., description="ASX code, e.g. MEK.AX"),
) -> List[Dict[str, Any]]:
    """Returns transaction history for a given date and stock code."""
    sql = (
        "exec [StockData].[usp_GetFirstBuySell] "
        "@pdtObservationDate = ?, @pvchStockCode = ?"
    )
    try:
        model = get_sql_model()
        data = model.execute_read_query(sql, (date_from, code))
        return data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


