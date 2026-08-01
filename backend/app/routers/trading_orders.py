from fastapi import APIRouter, HTTPException, Query, Depends
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel
from app.routers.auth import verify_credentials
import logging
import json


router = APIRouter(prefix="/api", tags=["trading-orders"], dependencies=[Depends(verify_credentials)])
logger = logging.getLogger("app.trading_orders")

DB_NAME = "StockDB_US"

ALLOWED_SIDES = {"B", "S"}
ALLOWED_ORDER_SOURCE_TYPES = {"MANUAL", "SIGNAL"}
ALLOWED_ENTRY_TYPES = {"LIMIT", "MARKET", "LIMIT_MID"}
ALLOWED_STATUSES = {"PENDING", "PLACED", "OPEN", "CLOSED", "CANCELLED"}
ALLOWED_MODES = {"live", "backtest", "all"}


class TradingOrderCreate(BaseModel):
    strategy_id: int
    stock_code: str
    side: str
    order_source_type: str
    signal_type: Optional[str] = None
    time_frame: str
    entry_type: str
    entry_price: Optional[float] = None
    quantity: int
    profit_target_price: Optional[float] = None
    stop_loss_price: Optional[float] = None
    stop_loss_mode: Optional[str] = "BAR_CLOSE"
    status: Optional[str] = "PENDING"
    backtest_run_id: Optional[str] = None


class TradingOrderUpdate(TradingOrderCreate):
    pass


def _normalize_stock_code(symbol: str) -> str:
    s = (symbol or "").strip().upper()
    if not s:
        return s
    if "." in s:
        return s
    return f"{s}.US"


def _normalize_order_inputs(order: TradingOrderCreate) -> Dict[str, Any]:
    side = (order.side or "").strip().upper()
    order_source_type = (order.order_source_type or "").strip().upper()
    entry_type = (order.entry_type or "").strip().upper()
    status = (order.status or "PENDING").strip().upper()

    if side not in ALLOWED_SIDES:
        raise HTTPException(status_code=400, detail="Side must be 'B' or 'S'.")
    if order_source_type not in ALLOWED_ORDER_SOURCE_TYPES:
        raise HTTPException(status_code=400, detail="OrderSourceType must be 'MANUAL' or 'SIGNAL'.")
    if entry_type not in ALLOWED_ENTRY_TYPES:
        raise HTTPException(status_code=400, detail="EntryType must be 'LIMIT', 'LIMIT_MID', or 'MARKET'.")
    if status not in ALLOWED_STATUSES:
        raise HTTPException(status_code=400, detail="Invalid Status value.")

    signal_type = (order.signal_type or "").strip().upper() or None
    if order_source_type == "MANUAL":
        signal_type = None
    if order_source_type == "SIGNAL" and not signal_type:
        raise HTTPException(status_code=400, detail="SignalType is required for SIGNAL orders.")

    stock_code = _normalize_stock_code(order.stock_code)
    if not stock_code:
        raise HTTPException(status_code=400, detail="StockCode is required.")

    time_frame = (order.time_frame or "").strip().upper()
    if not time_frame:
        raise HTTPException(status_code=400, detail="TimeFrame is required.")

    stop_loss_mode = (order.stop_loss_mode or "BAR_CLOSE").strip().upper()
    entry_price = None if entry_type in {"MARKET", "LIMIT_MID"} else order.entry_price
    meta: Dict[str, Any] = {}
    if entry_type == "LIMIT_MID":
        meta["EntryPriceMode"] = "MID"
    if signal_type == "SMA_CROSS":
        meta.update(
            {
                "SignalDescription": "Simple moving average cross",
                "SmaPeriod": 10,
                "SmaTimeFrame": time_frame,
            }
        )

    return {
        "strategy_id": order.strategy_id,
        "stock_code": stock_code,
        "side": side,
        "order_source_type": order_source_type,
        "signal_type": signal_type,
        "time_frame": time_frame,
        "entry_type": entry_type,
        "entry_price": entry_price,
        "quantity": order.quantity,
        "profit_target_price": order.profit_target_price,
        "stop_loss_price": order.stop_loss_price,
        "stop_loss_mode": stop_loss_mode,
        "status": status,
        "backtest_run_id": order.backtest_run_id,
        "meta_json": json.dumps(meta) if meta else None,
    }


def _load_order_signal_audits(model: SQLServerModel, order_ids: List[Any]) -> Dict[Any, List[Dict[str, Any]]]:
    clean_order_ids = [order_id for order_id in order_ids if order_id is not None]
    if not clean_order_ids:
        return {}

    placeholders = ",".join(["?"] * len(clean_order_ids))
    rows = model.execute_read_query(
        f"""
        SELECT
            OrderSignalAuditId,
            OrderId,
            StrategyId,
            StockCode,
            Side,
            TimeFrame,
            IntendedAction,
            SignalType,
            SignalKey,
            TriggeredAt,
            ValidationStatus,
            ValidationResult,
            ValidationDecision,
            ValidationJobId,
            RequestPayloadJson,
            ResponsePayloadJson
        FROM Trading.OrderSignalAudit
        WHERE OrderId IN ({placeholders})
        ORDER BY TriggeredAt DESC, OrderSignalAuditId DESC
        """,
        tuple(clean_order_ids),
    ) or []

    audits_by_order: Dict[Any, List[Dict[str, Any]]] = {}
    for r in rows:
        order_id = r.get("OrderId")
        audits_by_order.setdefault(order_id, []).append(
            {
                "order_signal_audit_id": r.get("OrderSignalAuditId"),
                "order_id": order_id,
                "strategy_id": r.get("StrategyId"),
                "stock_code": r.get("StockCode"),
                "side": r.get("Side"),
                "time_frame": r.get("TimeFrame"),
                "intended_action": r.get("IntendedAction"),
                "signal_type": r.get("SignalType"),
                "signal_key": r.get("SignalKey"),
                "triggered_at": r.get("TriggeredAt"),
                "validation_status": r.get("ValidationStatus"),
                "validation_result": r.get("ValidationResult"),
                "validation_decision": r.get("ValidationDecision"),
                "validation_job_id": r.get("ValidationJobId"),
                "request_payload_json": r.get("RequestPayloadJson"),
                "response_payload_json": r.get("ResponsePayloadJson"),
            }
        )
    return audits_by_order


def _load_order_fill_summaries(model: SQLServerModel, order_ids: List[Any]) -> Dict[Any, Dict[str, Any]]:
    clean_order_ids = [order_id for order_id in order_ids if order_id is not None]
    if not clean_order_ids:
        return {}

    placeholders = ",".join(["?"] * len(clean_order_ids))
    rows = model.execute_read_query(
        f"""
        SELECT
            FillId,
            OrderId,
            FillTime,
            FillPrice,
            FillQty,
            FillType,
            Reason
        FROM Trading.OrderFills
        WHERE OrderId IN ({placeholders})
        ORDER BY FillTime ASC, FillId ASC
        """,
        tuple(clean_order_ids),
    ) or []

    def fill_bucket(fill_type: Any, reason: Any) -> Optional[str]:
        normalized_type = str(fill_type or "").strip().upper().replace(" ", "_")
        normalized_reason = str(reason or "").strip().upper().replace(" ", "_")

        if normalized_type == "ENTRY":
            return "entry"
        if normalized_type in {"STOPLOSS", "STOP_LOSS", "SL"}:
            return "stoploss"
        if normalized_type == "EXIT" and "STOP" in normalized_reason:
            return "stoploss"
        if normalized_type == "EXIT":
            return "exit"
        return None

    fills_by_order: Dict[Any, Dict[str, Any]] = {}
    for r in rows:
        order_id = r.get("OrderId")
        bucket = fill_bucket(r.get("FillType"), r.get("Reason"))
        if order_id is None or bucket is None:
            continue

        summary = fills_by_order.setdefault(order_id, {}).setdefault(
            bucket,
            {
                "fill_time": None,
                "fill_price": None,
                "fill_qty": 0,
                "fill_count": 0,
                "_notional": 0.0,
            },
        )
        fill_qty = int(r.get("FillQty") or 0)
        fill_price = float(r.get("FillPrice") or 0)
        summary["fill_qty"] += fill_qty
        summary["fill_count"] += 1
        summary["_notional"] += fill_price * fill_qty
        summary["fill_time"] = r.get("FillTime")

    for summaries in fills_by_order.values():
        for summary in summaries.values():
            fill_qty = summary.get("fill_qty") or 0
            if fill_qty:
                summary["fill_price"] = summary["_notional"] / fill_qty
            summary.pop("_notional", None)

    return fills_by_order


@router.get("/trading-orders/strategies")
def get_strategies() -> List[Dict[str, Any]]:
    model = SQLServerModel(database=DB_NAME)
    rows = model.execute_read_query(
        """
        SELECT StrategyId, StrategyCode, IsActive
        FROM Trading.Strategy
        WHERE IsActive = 1
        ORDER BY StrategyCode
        """,
        ()
    ) or []
    return [
        {
            "strategy_id": r.get("StrategyId"),
            "strategy_code": r.get("StrategyCode"),
            "is_active": r.get("IsActive"),
        }
        for r in rows
    ]


@router.get("/trading-orders/signal-types")
def get_signal_types() -> List[Dict[str, Any]]:
    model = SQLServerModel(database=DB_NAME)
    rows = model.execute_read_query(
        """
        SELECT SignalType, Description, IsActive
        FROM Trading.SignalType
        WHERE IsActive = 1
        ORDER BY SignalType
        """,
        ()
    ) or []
    signal_types = [
        {
            "signal_type": r.get("SignalType"),
            "description": r.get("Description"),
            "is_active": r.get("IsActive"),
        }
        for r in rows
    ]
    if not any((s.get("signal_type") or "").upper() == "SMA_CROSS" for s in signal_types):
        signal_types.append(
            {
                "signal_type": "SMA_CROSS",
                "description": "Simple moving average cross",
                "is_active": True,
            }
        )
    return signal_types


@router.get("/trading-orders/backtest-runs")
def get_backtest_runs(limit: int = Query(100, ge=1, le=1000)) -> List[Dict[str, Any]]:
    model = SQLServerModel(database=DB_NAME)
    rows = model.execute_read_query(
        f"""
        SELECT TOP ({int(limit)})
            BacktestRunId, StartedAt, EndedAt, StrategyCode, StockCode, TimeFrame, OrderSourceMode
        FROM Trading.BacktestRuns
        ORDER BY StartedAt DESC
        """,
        ()
    ) or []
    return [
        {
            "backtest_run_id": r.get("BacktestRunId"),
            "started_at": r.get("StartedAt"),
            "ended_at": r.get("EndedAt"),
            "strategy_code": r.get("StrategyCode"),
            "stock_code": r.get("StockCode"),
            "time_frame": r.get("TimeFrame"),
            "order_source_mode": r.get("OrderSourceMode"),
        }
        for r in rows
    ]


@router.get("/trading-orders")
def get_trading_orders(
    mode: str = Query("live", description="live, backtest, or all"),
    status: Optional[str] = Query(None, description="Comma-separated statuses, or ACTIVE for PENDING/PLACED/OPEN"),
    stock_code: Optional[str] = Query(None),
    backtest_run_id: Optional[str] = Query(None),
    limit: int = Query(200, ge=1, le=1000),
) -> List[Dict[str, Any]]:
    mode = (mode or "live").strip().lower()
    if mode not in ALLOWED_MODES:
        raise HTTPException(status_code=400, detail="Invalid mode. Use live, backtest, or all.")

    where_clauses = ["1=1"]
    params: List[Any] = []

    if mode == "live":
        where_clauses.append("o.BacktestRunId IS NULL")
    elif mode == "backtest":
        where_clauses.append("o.BacktestRunId IS NOT NULL")

    if backtest_run_id:
        where_clauses.append("o.BacktestRunId = ?")
        params.append(backtest_run_id)

    if stock_code:
        where_clauses.append("o.StockCode = convert(varchar(20), ?)")
        params.append(_normalize_stock_code(stock_code))

    if status:
        raw = [s.strip().upper() for s in status.split(",") if s.strip()]
        if "ACTIVE" in raw:
            raw = ["PENDING", "PLACED", "OPEN"]
        invalid = [s for s in raw if s not in ALLOWED_STATUSES]
        if invalid:
            raise HTTPException(status_code=400, detail=f"Invalid Status values: {', '.join(invalid)}")
        if raw:
            placeholders = ",".join(["?"] * len(raw))
            where_clauses.append(f"o.Status IN ({placeholders})")
            params.extend(raw)

    query = f"""
    SELECT TOP ({int(limit)})
        o.OrderId,
        o.StrategyId,
        s.StrategyCode,
        o.StockCode,
        o.Side,
        o.OrderSourceType,
        o.SignalType,
        o.TimeFrame,
        o.EntryType,
        o.EntryPrice,
        o.Quantity,
        o.ProfitTargetPrice,
        o.StopLossPrice,
        o.StopLossMode,
        o.Status,
        o.EntryPlacedAt,
        o.EntryFilledAt,
        o.ExitPlacedAt,
        o.ExitFilledAt,
        o.StoplossPlacedAt,
        o.StoplossFilledAt,
        o.BacktestRunId,
        o.CreatedAt,
        o.UpdatedAt
    FROM Trading.Orders o
    LEFT JOIN Trading.Strategy s ON s.StrategyId = o.StrategyId
    WHERE {" AND ".join(where_clauses)}
    ORDER BY o.CreatedAt DESC
    """

    model = SQLServerModel(database=DB_NAME)
    rows = model.execute_read_query(query, tuple(params)) or []
    order_ids = [r.get("OrderId") for r in rows]
    audits_by_order = _load_order_signal_audits(model, order_ids)
    fills_by_order = _load_order_fill_summaries(model, order_ids)
    return [
        {
            "order_id": r.get("OrderId"),
            "strategy_id": r.get("StrategyId"),
            "strategy_code": r.get("StrategyCode"),
            "stock_code": r.get("StockCode"),
            "side": r.get("Side"),
            "order_source_type": r.get("OrderSourceType"),
            "signal_type": r.get("SignalType"),
            "time_frame": r.get("TimeFrame"),
            "entry_type": r.get("EntryType"),
            "entry_price": r.get("EntryPrice"),
            "quantity": r.get("Quantity"),
            "profit_target_price": r.get("ProfitTargetPrice"),
            "stop_loss_price": r.get("StopLossPrice"),
            "stop_loss_mode": r.get("StopLossMode"),
            "status": r.get("Status"),
            "backtest_run_id": r.get("BacktestRunId"),
            "entry_placed_at": r.get("EntryPlacedAt"),
            "entry_filled_at": (fills_by_order.get(r.get("OrderId"), {}).get("entry") or {}).get("fill_time") or r.get("EntryFilledAt"),
            "entry_fill_price": (fills_by_order.get(r.get("OrderId"), {}).get("entry") or {}).get("fill_price"),
            "entry_fill_qty": (fills_by_order.get(r.get("OrderId"), {}).get("entry") or {}).get("fill_qty"),
            "exit_placed_at": r.get("ExitPlacedAt"),
            "exit_filled_at": (fills_by_order.get(r.get("OrderId"), {}).get("exit") or {}).get("fill_time") or r.get("ExitFilledAt"),
            "exit_fill_price": (fills_by_order.get(r.get("OrderId"), {}).get("exit") or {}).get("fill_price"),
            "exit_fill_qty": (fills_by_order.get(r.get("OrderId"), {}).get("exit") or {}).get("fill_qty"),
            "stoploss_placed_at": r.get("StoplossPlacedAt"),
            "stoploss_filled_at": (fills_by_order.get(r.get("OrderId"), {}).get("stoploss") or {}).get("fill_time") or r.get("StoplossFilledAt"),
            "stoploss_fill_price": (fills_by_order.get(r.get("OrderId"), {}).get("stoploss") or {}).get("fill_price"),
            "stoploss_fill_qty": (fills_by_order.get(r.get("OrderId"), {}).get("stoploss") or {}).get("fill_qty"),
            "created_at": r.get("CreatedAt"),
            "updated_at": r.get("UpdatedAt"),
            "signal_audits": audits_by_order.get(r.get("OrderId"), []),
        }
        for r in rows
    ]


@router.post("/trading-orders")
def create_trading_order(order: TradingOrderCreate) -> Dict[str, Any]:
    normalized = _normalize_order_inputs(order)
    logger.info(
        "Pegasus order create request: strategy_id=%s stock_code=%s side=%s time_frame=%s entry_type=%s entry_price=%s qty=%s tp=%s sl=%s status=%s backtest_run_id=%s",
        normalized["strategy_id"],
        normalized["stock_code"],
        normalized["side"],
        normalized["time_frame"],
        normalized["entry_type"],
        normalized["entry_price"],
        normalized["quantity"],
        normalized["profit_target_price"],
        normalized["stop_loss_price"],
        normalized["status"],
        normalized["backtest_run_id"],
    )
    model = SQLServerModel(database=DB_NAME)
    params = (
        normalized["strategy_id"],
        normalized["stock_code"],
        normalized["side"],
        normalized["order_source_type"],
        normalized["signal_type"],
        normalized["time_frame"],
        normalized["entry_type"],
        normalized["entry_price"],
        normalized["quantity"],
        normalized["profit_target_price"],
        normalized["stop_loss_price"],
        normalized["stop_loss_mode"],
        normalized["status"],
        normalized["backtest_run_id"],
        normalized["meta_json"],
    )
    try:
        model.execute_update_usp(
            """
            INSERT INTO Trading.Orders
                (StrategyId, StockCode, Side, OrderSourceType, SignalType, TimeFrame, EntryType, EntryPrice, Quantity,
                 ProfitTargetPrice, StopLossPrice, StopLossMode, Status, BacktestRunId, MetaJson, CreatedAt, UpdatedAt)
            VALUES
                (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, GETDATE(), GETDATE());
            """,
            params,
        )
    except Exception:
        logger.exception(
            "Pegasus order create failed: strategy_id=%s stock_code=%s side=%s",
            normalized["strategy_id"],
            normalized["stock_code"],
            normalized["side"],
        )
        raise
    return {"message": f"Order for {normalized['stock_code']} created successfully."}


@router.put("/trading-orders/{order_id}")
def update_trading_order(order_id: int, order: TradingOrderUpdate) -> Dict[str, Any]:
    normalized = _normalize_order_inputs(order)
    model = SQLServerModel(database=DB_NAME)
    params = (
        normalized["strategy_id"],
        normalized["stock_code"],
        normalized["side"],
        normalized["order_source_type"],
        normalized["signal_type"],
        normalized["time_frame"],
        normalized["entry_type"],
        normalized["entry_price"],
        normalized["quantity"],
        normalized["profit_target_price"],
        normalized["stop_loss_price"],
        normalized["stop_loss_mode"],
        normalized["status"],
        normalized["backtest_run_id"],
        normalized["meta_json"],
        order_id,
    )
    model.execute_update_usp(
        """
        UPDATE Trading.Orders
        SET StrategyId = ?,
            StockCode = ?,
            Side = ?,
            OrderSourceType = ?,
            SignalType = ?,
            TimeFrame = ?,
            EntryType = ?,
            EntryPrice = ?,
            Quantity = ?,
            ProfitTargetPrice = ?,
            StopLossPrice = ?,
            StopLossMode = ?,
            Status = ?,
            BacktestRunId = ?,
            MetaJson = ?,
            UpdatedAt = GETDATE()
        WHERE OrderId = ?
          AND Status IN ('PENDING', 'PLACED');
        """,
        params,
    )
    return {"message": "Order updated successfully."}


@router.delete("/trading-orders/{order_id}")
def cancel_trading_order(order_id: int) -> Dict[str, Any]:
    model = SQLServerModel(database=DB_NAME)
    model.execute_update_usp(
        """
        UPDATE Trading.Orders
        SET Status = 'CANCELLED',
            UpdatedAt = GETDATE()
        WHERE OrderId = ?
          AND Status IN ('PENDING', 'PLACED');
        """,
        (order_id,),
    )
    return {"message": "Order cancelled successfully."}
