from datetime import date
from typing import Any, Dict, List

from fastapi import APIRouter, Depends, HTTPException, Query

from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel
from app.routers.auth import verify_credentials


router = APIRouter(prefix="/api", tags=["option-recommendations"])
DB_NAME = "StockDB_US"


@router.get("/option-recommendations/dates")
def get_option_recommendation_dates(
    limit: int = Query(180, ge=1, le=1000),
    username: str = Depends(verify_credentials),
) -> List[str]:
    query = f"""
    SELECT DISTINCT TOP ({int(limit)}) TradingDate
    FROM [Analysis].[v_CSPPriceLadder]
    WHERE TradingDate IS NOT NULL
    ORDER BY TradingDate DESC
    """

    try:
        model = SQLServerModel(database=DB_NAME)
        rows = model.execute_read_query(query, ()) or []
        return [
            row["TradingDate"].isoformat()
            for row in rows
            if row.get("TradingDate") is not None
        ]
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.get("/option-recommendations")
def get_option_recommendations(
    trading_date: date = Query(..., alias="trading_date", description="Trading date filter in YYYY-MM-DD format"),
    username: str = Depends(verify_credentials),
) -> List[Dict[str, Any]]:
    query = """
    SELECT
        *
    FROM [Analysis].[v_CSPPriceLadder]
    WHERE TradingDate = ?
    ORDER BY Rank, Priority
    """

    try:
        model = SQLServerModel(database=DB_NAME)
        return model.execute_read_query(query, (trading_date,)) or []
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))
