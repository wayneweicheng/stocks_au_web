from fastapi import APIRouter, HTTPException, Path, Body
from typing import List, Dict, Any, Optional
from app.core.db import get_sql_model


router = APIRouter(prefix="/api/monitor-stocks", tags=["monitor-stocks"])


def exec_read(sql: str, params: tuple = ()) -> List[Dict[str, Any]]:
    try:
        model = get_sql_model()
        data = model.execute_read_query(sql, params)
        return data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


def exec_update(sql: str, params: tuple = ()) -> Dict[str, Any]:
    try:
        model = get_sql_model()
        model.execute_update_usp(sql, params)
        return {"ok": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("")
def get_monitor_stock_list() -> List[Dict[str, Any]]:
    return exec_read("exec [StockData].[usp_GetMonitorStockList]")


# COS list exists in legacy but is not required for this migration


@router.get("/{code}")
def get_monitor_stock(
    code: str = Path(..., description="ASX code, e.g. 14D.AX"),
) -> List[Dict[str, Any]]:
    return exec_read("exec [StockData].[usp_GetMonitorStock] @pvchStockCode = ?", (code,))


@router.post("")
def add_monitor_stock(
    code: str = Body(..., embed=True, description="ASX code"),
):
    # Legacy SP requires @pvchMessage output param. Provide placeholder to satisfy driver.
    return exec_update(
        "exec [StockData].[usp_AddMonitorStock] @pvchStockCode = ?, @pvchMessage = ?",
        (code, ""),
    )


@router.post("/from-report")
def add_monitor_stock_from_report(
    code: str = Body(..., embed=True),
    priorityLevel: int = Body(..., embed=True),
    smsAlert: int = Body(0, embed=True),
):
    return exec_update(
        "exec [StockData].[usp_AddMonitorStockFromReport] @pvchStockCode = ?, @pintPriorityLevel = ?, @pintSMSAlert = ?",
        (code, priorityLevel, smsAlert),
    )


@router.delete("/{code}")
def delete_monitor_stock(
    code: str = Path(...),
):
    return exec_update("exec [StockData].[usp_DeleteMonitorStock] @pvchStockCode = ?", (code,))


@router.put("/{code}")
def update_monitor_stock(
    code: str = Path(..., description="Existing ASX code"),
    codeNew: Optional[str] = Body(None, embed=True),
    priorityLevel: Optional[int] = Body(None, embed=True),
    notes: Optional[str] = Body(None, embed=True),
):
    # Fill defaults to satisfy required params
    pvchStockCodeNew = codeNew or code
    pintPriorityLevel = 0 if priorityLevel is None else priorityLevel
    pvchNotes = notes or ""
    return exec_update(
        "exec [StockData].[usp_UpdateMonitorStock] "
        "@pvchStockCode = ?, @pvchStockCodeNew = ?, @pintPriorityLevel = ?, @pvchNotes = ?, @pvchMessage = ?",
        (code, pvchStockCodeNew, pintPriorityLevel, pvchNotes, ""),
    )


