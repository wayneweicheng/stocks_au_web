from fastapi import APIRouter, HTTPException, Query, Depends
from typing import List, Dict, Any, Optional
from datetime import date
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel
from app.core.db import get_sql_model
from app.routers.auth import verify_credentials
import logging


router = APIRouter(prefix="/api", tags=["pllrs-scanner"])
logger = logging.getLogger("app.pllrs")

TABLE_SCHEMA = "Analysis"
TABLE_NAME = "PLLRSScannerResults"


def execute_query(sql: str, params: tuple) -> List[Dict[str, Any]]:
    try:
        model: SQLServerModel = get_sql_model()
        logger.info(f"SQL exec: {sql} params={params}")
        data = model.execute_read_usp(sql, params)
        return data or []
    except Exception as e:
        logger.exception(f"SQL error executing PLLRS query: {e}")
        raise HTTPException(status_code=500, detail="Database query failed")


@router.get("/pllrs-scanner")
def get_pllrs_scanner_results(
    observation_date: Optional[date] = Query(None, description="ObservationDate (YYYY-MM-DD)"),
    max_today_change: Optional[float] = Query(None, description="Return only if TodayPriceChange <= this value"),
    entry_price: Optional[float] = Query(None),
    target_price: Optional[float] = Query(None),
    stop_price: Optional[float] = Query(None),
    limit: int = Query(200, ge=1, le=2000, description="Max rows to return"),
    username: str = Depends(verify_credentials),
) -> List[Dict[str, Any]]:
    where: List[str] = ["[MeetsCriteria] = 1"]
    params: List[Any] = []  # type: ignore[name-defined]

    if observation_date is not None:
        where.append("[ObservationDate] = ?")
        params.append(observation_date)

    if max_today_change is not None:
        where.append("[TodayPriceChange] <= ?")
        params.append(max_today_change)

    # Optional exact matches; you can expand to ranges if needed
    if entry_price is not None:
        where.append("[EntryPrice] = ?")
        params.append(entry_price)
    if target_price is not None:
        where.append("[TargetPrice] = ?")
        params.append(target_price)
    if stop_price is not None:
        where.append("[StopPrice] = ?")
        params.append(stop_price)

    where_sql = (" WHERE " + " AND ".join(where)) if where else ""

    sql = (
        f"SELECT TOP (?) * FROM [{TABLE_SCHEMA}].[{TABLE_NAME}]" +
        where_sql +
        " ORDER BY [ObservationDate] DESC, [ASXCode] ASC"
    )

    final_params = [limit] + params
    return execute_query(sql, tuple(final_params))


