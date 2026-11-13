from fastapi import APIRouter, HTTPException, Query, Depends, Header
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel
from app.routers.auth import verify_credentials
import logging
import os
import json
import hashlib
from datetime import datetime
from zoneinfo import ZoneInfo
import math
import re
import uuid
from decimal import Decimal, ROUND_CEILING, ROUND_FLOOR, ROUND_HALF_UP


router = APIRouter(prefix="/api", tags=["trading-orders"], dependencies=[Depends(verify_credentials)])
logger = logging.getLogger("app.trading_orders")

DB_NAME = "StockDB_US"

ALLOWED_SIDES = {"B", "S"}
ALLOWED_ORDER_SOURCE_TYPES = {"MANUAL", "SIGNAL"}
ALLOWED_ENTRY_TYPES = {"LIMIT", "MARKET", "LIMIT_MID"}
ALLOWED_STATUSES = {"PENDING", "PLACED", "OPEN", "CLOSED", "CANCELLED"}
ALLOWED_MODES = {"live", "backtest", "all"}


class ProxyActivationCreate(BaseModel):
    instrument_code: str = "ESMAIN.US"
    lower_price: float
    upper_price: float
    trigger_price: Optional[float] = None
    target_price_offset_pct: float = 0.0
    expires_at: Optional[datetime] = None


class ConditionalRiskSpec(BaseModel):
    unit: str
    value: float


class ConditionalEntryRisk(BaseModel):
    profit_target: Optional[ConditionalRiskSpec] = None
    stop_loss: Optional[ConditionalRiskSpec] = None


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
    notional_amount: Optional[float] = None
    profit_target_price: Optional[float] = None
    stop_loss_price: Optional[float] = None
    stop_loss_mode: Optional[str] = "BAR_CLOSE"
    status: Optional[str] = "PENDING"
    backtest_run_id: Optional[str] = None
    activation: Optional[ProxyActivationCreate] = None
    entry_risk: Optional[ConditionalEntryRisk] = None


class TradingOrderBatchCreate(BaseModel):
    orders: List[TradingOrderCreate]


class ConditionalPriceCreate(BaseModel):
    operator: str
    threshold: float
    confirmation_mode: str = "IMMEDIATE"


class ConditionalTriggerPriceCreate(ConditionalPriceCreate):
    instrument_code: str = "ESMAIN.US"


class ConditionalPositionCreate(BaseModel):
    operator: str
    shares: int


class ConditionalTimeWindowCreate(BaseModel):
    timezone_name: str
    start: str
    end: str
    mode: str = "INCLUDE"


class ConditionalEntryOrderCreate(BaseModel):
    strategy_id: int
    stock_code: str
    side: str
    quantity: int
    target_price: Optional[ConditionalPriceCreate] = None
    trigger_price: Optional[ConditionalTriggerPriceCreate] = None
    position_condition: Optional[ConditionalPositionCreate] = None
    maximum_margin_capacity_used: Optional[float] = None
    account_id: Optional[str] = None
    time_window: Optional[ConditionalTimeWindowCreate] = None


class ConditionalEntryBatchCreate(BaseModel):
    orders: List[ConditionalEntryOrderCreate]


class TradingOrderUpdate(TradingOrderCreate):
    pass


class TradingOrderExitFill(BaseModel):
    fill_price: float
    fill_time: datetime


def _normalize_stock_code(symbol: str) -> str:
    s = (symbol or "").strip().upper()
    if not s:
        return s
    if "." in s:
        return s
    return f"{s}.US"


def _conditional_target_tiers(low: float, high: float, side: str, count: int) -> List[float]:
    """Rebuild the browser ladder from its submitted range endpoints server-side."""
    lo, hi = Decimal(str(low)), Decimal(str(high))
    if count <= 0 or hi < lo:
        raise HTTPException(status_code=400, detail="Target-price ladder range is invalid.")
    if count == 1:
        return [float(hi if side == "B" else lo)]
    step_count = Decimal(count - 1)
    tiers = []
    for index in range(count):
        fraction = Decimal(index) / step_count
        exact = hi - (hi - lo) * fraction if side == "B" else lo + (hi - lo) * fraction
        tiers.append(float(exact.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)))
    if len(set(tiers)) != count:
        raise HTTPException(status_code=400, detail="Target-price range must provide distinct tiers for every order.")
    return tiers


def _es_trigger_prices(low: float, high: float, side: str, count: int) -> List[float]:
    """Tick-aligned ES tiers, inclusive, with no duplicate target tranches."""
    lo, hi, tick = Decimal(str(low)), Decimal(str(high)), Decimal('0.25')
    levels = []
    for index in range(count):
        exact = hi - (hi - lo) * index / (count - 1) if side == 'B' and count > 1 else (
            lo + (hi - lo) * index / (count - 1) if count > 1 else (hi if side == 'B' else lo)
        )
        mode = ROUND_FLOOR if side == 'B' else ROUND_CEILING
        level = (exact / tick).to_integral_value(rounding=mode) * tick
        if level < lo or level > hi or (levels and level == levels[-1]):
            raise HTTPException(status_code=400, detail='ESMain range must provide distinct 0.25-point tiers for every order.')
        levels.append(float(level))
    return levels


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
    if order.quantity <= 0:
        raise HTTPException(status_code=400, detail="Quantity must be a positive integer.")

    time_frame = (order.time_frame or "").strip().upper()
    if not time_frame:
        raise HTTPException(status_code=400, detail="TimeFrame is required.")

    stop_loss_mode = (order.stop_loss_mode or "BAR_CLOSE").strip().upper()
    entry_price = None if entry_type in {"MARKET", "LIMIT_MID"} else order.entry_price
    activation = order.activation
    entry_risk = order.entry_risk
    activation_values = None
    if activation is None and entry_risk is not None:
        raise HTTPException(status_code=400, detail="Conditional entry-risk rules require an ESMain activation.")
    if activation is not None:
        proxy_code = _normalize_stock_code(activation.instrument_code)
        if proxy_code != "ESMAIN.US":
            raise HTTPException(status_code=400, detail="Conditional orders must use ESMAIN.US as the proxy.")
        if not re.fullmatch(r"[A-Z][A-Z0-9.-]{0,13}\.US", stock_code):
            raise HTTPException(status_code=400, detail="Conditional target must be a supported US stock symbol.")
        if not math.isfinite(activation.lower_price) or not math.isfinite(activation.upper_price):
            raise HTTPException(status_code=400, detail="ESMain trigger prices must be finite.")
        if activation.lower_price <= 0 or activation.upper_price < activation.lower_price:
            raise HTTPException(status_code=400, detail="ESMain trigger range must be positive and ordered.")
        if order_source_type != "MANUAL" or order.backtest_run_id is not None or status != "PENDING":
            raise HTTPException(status_code=400, detail="Proxy activation requires a live, pending MANUAL Trade Intent.")
        if entry_type not in {"LIMIT", "LIMIT_MID"} or order.entry_price is not None:
            raise HTTPException(status_code=400, detail="Proxy activation requires a target limit order with an activation-time price.")
        if entry_risk is not None and entry_risk.profit_target is None and entry_risk.stop_loss is None:
            raise HTTPException(status_code=400, detail="Conditional entry-risk must include a take-profit or stop-loss rule.")
        if order.notional_amount is not None and (not math.isfinite(order.notional_amount) or order.notional_amount <= 0):
            raise HTTPException(status_code=400, detail="Optional proxy indicative notional must be positive when supplied.")
        if not math.isfinite(activation.target_price_offset_pct) or activation.target_price_offset_pct <= -100:
            raise HTTPException(status_code=400, detail="Target price offset percentage must be finite and greater than -100%.")
        if entry_risk is not None:
            for spec in (entry_risk.profit_target, entry_risk.stop_loss):
                if spec is not None and (spec.unit.strip().upper() not in {"PERCENT", "DOLLAR"} or not math.isfinite(spec.value) or spec.value <= 0):
                    raise HTTPException(status_code=400, detail="Conditional risk values must be positive PERCENT or DOLLAR amounts.")
        # Expiry is derived from Trading.Orders.CreatedAt by the live runner.
        # ExpiresAt is retained only as a nullable legacy compatibility field.
        expires_at = None
        if activation.trigger_price is not None and (not math.isfinite(activation.trigger_price)
                or activation.trigger_price < activation.lower_price
                or activation.trigger_price > activation.upper_price):
            raise HTTPException(status_code=400, detail='ESMain trigger price must be within its entered range.')
        activation_values = {
            "proxy_stock_code": "ESMAIN.US",
            "trigger_price": _es_trigger_prices(activation.lower_price, activation.upper_price, side, 1)[0],
            "lower_price": activation.lower_price,
            "upper_price": activation.upper_price,
            "expires_at": expires_at,
        }

    meta: Dict[str, Any] = {}
    if activation is not None or entry_risk is not None:
        conditional_entry: Dict[str, Any] = {
            "schema_version": 3 if activation is not None else 1,
            "batch_id": uuid.uuid4().hex,
            "quantity_mode": "FIXED" if activation is not None and order.notional_amount is None else "NOTIONAL",
            "target_price_offset_pct": activation.target_price_offset_pct if activation is not None else 0.0,
        }
        if entry_risk is not None:
            if entry_risk.profit_target is not None:
                conditional_entry["profit_target"] = {"unit": entry_risk.profit_target.unit.strip().upper(), "value": entry_risk.profit_target.value}
            if entry_risk.stop_loss is not None:
                conditional_entry["stop_loss"] = {"unit": entry_risk.stop_loss.unit.strip().upper(), "value": entry_risk.stop_loss.value}
        if order.notional_amount is not None:
            conditional_entry["notional_amount"] = order.notional_amount
        meta["conditional_entry"] = conditional_entry
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
        "activation": activation_values,
    }


def _normalize_conditional_entry_order(order: ConditionalEntryOrderCreate) -> Dict[str, Any]:
    """Validate one new conditional intent without touching legacy activation rules."""
    side = (order.side or "").strip().upper()
    if side not in ALLOWED_SIDES:
        raise HTTPException(status_code=400, detail="Side must be 'B' or 'S'.")
    if order.quantity <= 0:
        raise HTTPException(status_code=400, detail="Quantity must be a positive integer.")
    stock_code = _normalize_stock_code(order.stock_code)
    if not re.fullmatch(r"[A-Z][A-Z0-9.-]{0,13}\.US", stock_code):
        raise HTTPException(status_code=400, detail="Conditional target must be a supported US stock symbol.")
    if order.target_price is not None and order.trigger_price is not None:
        raise HTTPException(status_code=400, detail="Select either a target-stock price condition or a reference-stock trigger condition, not both.")
    if order.target_price is None and order.trigger_price is None:
        raise HTTPException(status_code=400, detail="At least one price activation condition is required.")

    def normalized_price(spec: ConditionalPriceCreate, *, field: str, tick_size: float) -> Dict[str, Any]:
        operator = spec.operator.strip().upper()
        expected_operator = "AT_OR_BELOW" if side == "B" else "AT_OR_ABOVE"
        if operator != expected_operator:
            raise HTTPException(status_code=400, detail=f"{field} must use the side-aware {expected_operator} operator.")
        if not math.isfinite(spec.threshold) or spec.threshold <= 0:
            raise HTTPException(status_code=400, detail=f"{field} threshold must be finite and positive.")
        if field == "Target price" and spec.threshold < 1:
            raise HTTPException(status_code=400, detail="One-tick target-stock reversal requires a price of at least $1.00.")
        tick_multiple = Decimal(str(spec.threshold)) / Decimal(str(tick_size))
        if tick_multiple != tick_multiple.to_integral_value():
            raise HTTPException(status_code=400, detail=f"{field} threshold must align to its {tick_size:g} price tick.")
        return {
            "operator": operator,
            "threshold": float(spec.threshold),
            "activation_mode": "TOUCH_THEN_RETRACE",
            "tick_size": tick_size,
        }

    target = normalized_price(order.target_price, field="Target price", tick_size=0.01) if order.target_price else None
    trigger = None
    if order.trigger_price:
        instrument_code = _normalize_stock_code(order.trigger_price.instrument_code)
        if instrument_code != "ESMAIN.US":
            raise HTTPException(status_code=400, detail="The only supported trigger stock is ESMAIN.US.")
        trigger = normalized_price(order.trigger_price, field="ESMain trigger price", tick_size=0.25)

    position = None
    if order.position_condition:
        operator = order.position_condition.operator.strip().upper()
        allowed_position_operators = {
            "LESS_THAN", "LESS_THAN_OR_EQUAL", "GREATER_THAN",
            "GREATER_THAN_OR_EQUAL", "EQUAL", "NOT_EQUAL",
        }
        if operator not in allowed_position_operators or order.position_condition.shares < 0:
            raise HTTPException(status_code=400, detail="Invalid position operator or share threshold.")
        position = {"operator": operator, "shares": order.position_condition.shares}

    margin = order.maximum_margin_capacity_used
    if margin is not None and (not math.isfinite(margin) or margin < 0 or margin > 1):
        raise HTTPException(status_code=400, detail="Maximum margin capacity used must be between 0 and 1.")
    account_id = (order.account_id or "").strip() or None
    if (position is not None or margin is not None) and account_id is None:
        raise HTTPException(status_code=400, detail="account_id is required for position or margin conditions.")

    time_window = None
    if order.time_window:
        window = order.time_window
        try:
            ZoneInfo(window.timezone_name)
            start = datetime.strptime(window.start, "%H:%M").time()
            end = datetime.strptime(window.end, "%H:%M").time()
        except (ValueError, KeyError) as exc:
            raise HTTPException(status_code=400, detail="Time window requires a valid timezone and HH:MM bounds.") from exc
        mode = window.mode.strip().upper()
        if start == end or mode not in {"INCLUDE", "EXCLUDE"}:
            raise HTTPException(status_code=400, detail="Time window bounds must differ and mode must be INCLUDE or EXCLUDE.")
        time_window = {
            "timezone_name": window.timezone_name,
            "start": start.strftime("%H:%M"),
            "end": end.strftime("%H:%M"),
            "mode": mode,
        }

    return {
        "order_kind": "CONDITIONAL_ENTRY",
        "strategy_id": order.strategy_id,
        "stock_code": stock_code,
        "side": side,
        "order_source_type": "MANUAL",
        "signal_type": None,
        "time_frame": "5M",
        "entry_type": "LIMIT",
        "entry_price": None,
        "quantity": order.quantity,
        "profit_target_price": None,
        "stop_loss_price": None,
        "stop_loss_mode": "BAR_CLOSE",
        "status": "PENDING",
        "backtest_run_id": None,
        "condition": {
            "target_price_operator": target["operator"] if target else None,
            "target_price_threshold": target["threshold"] if target else None,
            "target_price_activation_mode": target["activation_mode"] if target else None,
            "target_price_tick_size": target["tick_size"] if target else None,
            "trigger_stock_code": "ESMAIN.US" if trigger else None,
            "trigger_price_operator": trigger["operator"] if trigger else None,
            "trigger_price_threshold": trigger["threshold"] if trigger else None,
            "trigger_price_activation_mode": trigger["activation_mode"] if trigger else None,
            "trigger_price_tick_size": trigger["tick_size"] if trigger else None,
            "account_id": account_id,
            "position_stock_code": stock_code if position else None,
            "position_operator": position["operator"] if position else None,
            "position_shares": position["shares"] if position else None,
            "maximum_margin_capacity_used": margin,
            "time_zone_name": time_window["timezone_name"] if time_window else None,
            "time_window_start": time_window["start"] if time_window else None,
            "time_window_end": time_window["end"] if time_window else None,
            "time_window_mode": time_window["mode"] if time_window else None,
        },
    }


def _load_order_proxy_activations(model: SQLServerModel, order_ids: List[Any]) -> Dict[Any, Dict[str, Any]]:
    clean_order_ids = [order_id for order_id in order_ids if order_id is not None]
    if not clean_order_ids:
        return {}
    placeholders = ",".join(["?"] * len(clean_order_ids))
    rows = model.execute_read_query(
        f"""
        SELECT OrderId, ProxyStockCode, LowerPrice, UpperPrice, TriggerPrice, SessionStart, SessionEnd,
               ExpiresAt, State, ObservedPrice, ObservedAt, ActivatedAt, TargetEntryPrice, BrokerOrderId,
               ErrorCode, ErrorMessage
        FROM Trading.OrderActivation
        WHERE OrderId IN ({placeholders})
        """,
        tuple(clean_order_ids),
    ) or []
    return {
        row.get("OrderId"): {
            "proxy_stock_code": row.get("ProxyStockCode"),
            "lower_price": row.get("LowerPrice"),
            "upper_price": row.get("UpperPrice"),
            "trigger_price": row.get("TriggerPrice"),
            "session_start": str(row.get("SessionStart") or "04:00"),
            "session_end": str(row.get("SessionEnd") or "20:00"),
            "expires_at": row.get("ExpiresAt"),
            "state": row.get("State"),
            "observed_price": row.get("ObservedPrice"),
            "observed_at": row.get("ObservedAt"),
            "activated_at": row.get("ActivatedAt"),
            "target_entry_price": row.get("TargetEntryPrice"),
            "broker_order_id": row.get("BrokerOrderId"),
            "error_code": row.get("ErrorCode"),
            "error_message": row.get("ErrorMessage"),
        }
        for row in rows
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
    activations_by_order = _load_order_proxy_activations(model, order_ids)
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
            "activation": activations_by_order.get(r.get("OrderId")),
        }
        for r in rows
    ]


@router.post("/trading-orders")
def create_trading_order(order: TradingOrderCreate) -> Dict[str, Any]:
    normalized = _normalize_order_inputs(order)
    if (order.activation is not None and order.activation.trigger_price is not None
            and abs(order.activation.trigger_price - normalized['activation']['trigger_price']) > 0.00001):
        raise HTTPException(status_code=400, detail='Single ESMain trigger must equal the side-specific edge of its range.')
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
        if normalized["activation"] is None:
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
        else:
            activation_values = normalized["activation"]
            model.execute_update_usp(
                """
                SET XACT_ABORT ON;
                BEGIN TRY
                    BEGIN TRANSACTION;
                    INSERT INTO Trading.Orders
                        (StrategyId, StockCode, Side, OrderSourceType, SignalType, TimeFrame, EntryType, EntryPrice, Quantity,
                         ProfitTargetPrice, StopLossPrice, StopLossMode, Status, BacktestRunId, MetaJson, CreatedAt, UpdatedAt)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, GETDATE(), GETDATE());
                    DECLARE @OrderId BIGINT = SCOPE_IDENTITY();
                    INSERT INTO Trading.OrderActivation
                        (OrderId, ProxyStockCode, LowerPrice, UpperPrice, TriggerPrice, SessionStart, SessionEnd, ExpiresAt, State, CreatedAt, UpdatedAt)
                    VALUES (@OrderId, 'ESMAIN.US', ?, ?, ?, '04:00', '20:00', NULL, 'ARMED', GETDATE(), GETDATE());
                    COMMIT TRANSACTION;
                END TRY
                BEGIN CATCH
                    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                    THROW;
                END CATCH;
                """,
                (*params, activation_values["lower_price"], activation_values["upper_price"], activation_values["trigger_price"]),
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


@router.post("/trading-orders/conditional-batch")
def create_conditional_order_batch(batch: TradingOrderBatchCreate) -> Dict[str, Any]:
    if not batch.orders or len(batch.orders) > 100:
        raise HTTPException(status_code=400, detail="Conditional batch must contain between 1 and 100 orders.")
    normalized_orders = [_normalize_order_inputs(order) for order in batch.orders]
    if any(item["activation"] is None for item in normalized_orders):
        raise HTTPException(status_code=400, detail="Every order in a conditional batch must use an ESMain activation.")
    first = normalized_orders[0]
    low, high = first['activation']['lower_price'], first['activation']['upper_price']
    if any(item['side'] != first['side'] or item['stock_code'] != first['stock_code']
           or item['strategy_id'] != first['strategy_id']
           or item['activation']['lower_price'] != low or item['activation']['upper_price'] != high
           for item in normalized_orders):
        raise HTTPException(status_code=400, detail='Conditional batch must have one target, side, strategy, and ESMain range.')
    tiers = _es_trigger_prices(low, high, first['side'], len(normalized_orders))
    batch_id = uuid.uuid4().hex
    for source, item, tier in zip(batch.orders, normalized_orders, tiers):
        if source.activation.trigger_price is not None and abs(source.activation.trigger_price - tier) > 0.00001:
            raise HTTPException(status_code=400, detail='ESMain trigger tiers differ from the server-calculated ladder.')
        item['activation']['trigger_price'] = tier
        meta = json.loads(item["meta_json"] or "{}")
        meta["conditional_entry"]["batch_id"] = batch_id
        item["meta_json"] = json.dumps(meta)

    statements = ["SET XACT_ABORT ON;", "BEGIN TRY", "BEGIN TRANSACTION;", "DECLARE @OrderId BIGINT;"]
    params: list[Any] = []
    for item in normalized_orders:
        statements.append(
            """INSERT INTO Trading.Orders
                (StrategyId, StockCode, Side, OrderSourceType, SignalType, TimeFrame, EntryType, EntryPrice, Quantity,
                 ProfitTargetPrice, StopLossPrice, StopLossMode, Status, BacktestRunId, MetaJson, CreatedAt, UpdatedAt)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, GETDATE(), GETDATE());
               SET @OrderId = SCOPE_IDENTITY();
               INSERT INTO Trading.OrderActivation
                   (OrderId, ProxyStockCode, LowerPrice, UpperPrice, TriggerPrice, SessionStart, SessionEnd, ExpiresAt, State, CreatedAt, UpdatedAt)
               VALUES (@OrderId, 'ESMAIN.US', ?, ?, ?, '04:00', '20:00', NULL, 'ARMED', GETDATE(), GETDATE());"""
        )
        params.extend((
            item["strategy_id"], item["stock_code"], item["side"], item["order_source_type"],
            item["signal_type"], item["time_frame"], item["entry_type"], item["entry_price"],
            item["quantity"], item["profit_target_price"], item["stop_loss_price"], item["stop_loss_mode"],
            item["status"], item["backtest_run_id"], item["meta_json"],
            item["activation"]["lower_price"], item["activation"]["upper_price"],
            item["activation"]["trigger_price"],
        ))
    statements.extend(["COMMIT TRANSACTION;", "END TRY", "BEGIN CATCH", "IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;", "THROW;", "END CATCH;"])
    model = SQLServerModel(database=DB_NAME)
    model.execute_update_usp("\n".join(statements), tuple(params))
    return {"message": f"Created {len(normalized_orders)} ESMain-triggered Trade Intents.", "count": len(normalized_orders)}


def _conditional_entry_runtime_enabled() -> bool:
    """Require schema/evaluator gates; DB-only capture does not need Pub/Sub."""
    base_flags = (
        "PEGASUS_CONDITIONAL_ENTRY_API_ENABLED",
        "PEGASUS_CONDITIONAL_ENTRY_SCHEMA_READY",
        "PEGASUS_CONDITIONAL_ENTRY_EVALUATOR_READY",
    )
    base_ready = all(os.getenv(name, "false").strip().lower() == "true" for name in base_flags)
    db_only = os.getenv("PEGASUS_CONDITIONAL_ENTRY_DB_ONLY_ENABLED", "false").strip().lower() == "true"
    publisher_ready = os.getenv("PEGASUS_CONDITIONAL_ENTRY_PUBLISHER_READY", "false").strip().lower() == "true"
    executor_enabled = os.getenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_ENABLED", "false").strip().lower() == "true"
    executor_ready = os.getenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_READY", "false").strip().lower() == "true"
    execution_schema_ready = os.getenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTION_SCHEMA_READY", "false").strip().lower() == "true"
    if db_only:
        return base_ready and not executor_enabled
    return base_ready and publisher_ready and (
        not executor_enabled or (executor_ready and execution_schema_ready)
    )


def _conditional_entry_execution_enabled() -> bool:
    return (
        _conditional_entry_runtime_enabled()
        and os.getenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_ENABLED", "false").strip().lower() == "true"
        and os.getenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_READY", "false").strip().lower() == "true"
        and os.getenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTION_SCHEMA_READY", "false").strip().lower() == "true"
    )


def _validate_conditional_entry_batch(orders: List[ConditionalEntryOrderCreate]) -> List[Dict[str, Any]]:
    if not orders or len(orders) > 100:
        raise HTTPException(status_code=400, detail="Conditional-entry batch must contain between 1 and 100 orders.")
    normalized = [_normalize_conditional_entry_order(order) for order in orders]
    first = normalized[0]
    for item in normalized[1:]:
        if any(item[key] != first[key] for key in ("strategy_id", "stock_code", "side")):
            raise HTTPException(status_code=400, detail="Batch must use one strategy, target stock and side.")
        if any(item["condition"][key] != first["condition"][key] for key in (
            "position_stock_code", "position_operator", "position_shares", "account_id",
            "maximum_margin_capacity_used", "time_zone_name", "time_window_start",
            "time_window_end", "time_window_mode",
        )):
            raise HTTPException(status_code=400, detail="Optional constraints must be identical across the batch.")
        for source_key in ("target_price_threshold", "trigger_price_threshold"):
            if (item["condition"][source_key] is None) != (first["condition"][source_key] is None):
                raise HTTPException(status_code=400, detail="Every tranche must select the same price activation sources.")
        for threshold_key, metadata_keys in (
            ("target_price_threshold", ("target_price_activation_mode", "target_price_tick_size")),
            ("trigger_price_threshold", ("trigger_price_activation_mode", "trigger_price_tick_size")),
        ):
            if first["condition"][threshold_key] is not None and any(
                item["condition"][key] != first["condition"][key] for key in metadata_keys
            ):
                raise HTTPException(status_code=400, detail="Price-source reversal mode and tick must be identical across the batch.")

    for threshold_key in ("target_price_threshold", "trigger_price_threshold"):
        tiers = [item["condition"][threshold_key] for item in normalized]
        if tiers[0] is None:
            continue
        low, high = min(tiers), max(tiers)
        if threshold_key == "target_price_threshold":
            expected = _conditional_target_tiers(low, high, first["side"], len(normalized))
        else:
            expected = _es_trigger_prices(low, high, first["side"], len(normalized))
        if tiers != expected:
            raise HTTPException(
                status_code=400,
                detail=f"{threshold_key} tiers differ from the server-calculated ladder.",
            )
        for item, tier in zip(normalized, expected):
            item["condition"][threshold_key] = tier

    return normalized


@router.get("/trading-orders/conditional-entry/status")
def get_conditional_entry_status() -> Dict[str, Any]:
    enabled = _conditional_entry_runtime_enabled()
    execution_enabled = _conditional_entry_execution_enabled()
    db_only = os.getenv("PEGASUS_CONDITIONAL_ENTRY_DB_ONLY_ENABLED", "false").strip().lower() == "true"
    return {
        "enabled": enabled,
        "execution_enabled": execution_enabled,
        "mode": "DB_ONLY" if enabled and db_only else ("EXECUTION_ENABLED" if execution_enabled else "PUBLISH_ONLY"),
        "dry_run": os.getenv("PEGASUS_CONDITIONAL_ENTRY_DRY_RUN", "false").strip().lower() == "true",
        "order_kind": "CONDITIONAL_ENTRY",
    }


@router.post("/trading-orders/conditional-entry-batch")
def create_conditional_entry_batch(
    batch: ConditionalEntryBatchCreate,
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
) -> Dict[str, Any]:
    """Persist a batch once per client key and immutable version-1 conditions atomically."""
    if not _conditional_entry_runtime_enabled():
        raise HTTPException(status_code=503, detail="Pegasus Conditional Entries are not enabled yet.")
    if not idempotency_key:
        raise HTTPException(status_code=400, detail="Idempotency-Key header is required.")
    try:
        request_id = str(uuid.UUID(idempotency_key))
    except (ValueError, TypeError, AttributeError) as exc:
        raise HTTPException(status_code=400, detail="Idempotency-Key must be a UUID.") from exc
    normalized_orders = _validate_conditional_entry_batch(batch.orders)
    request_body = json.dumps(normalized_orders, sort_keys=True, separators=(",", ":"))
    request_hash = hashlib.sha256(request_body.encode("utf-8")).hexdigest()
    model = SQLServerModel(database=DB_NAME)

    def replay_if_present() -> Dict[str, Any] | None:
        rows = model.execute_read_query(
            "SELECT RequestHash, OrderCount FROM Trading.ConditionalEntryBatchRequest WHERE RequestId = ?",
            (request_id,),
        ) or []
        if not rows:
            return None
        if str(rows[0]["RequestHash"]).strip() != request_hash:
            raise HTTPException(status_code=409, detail="Idempotency-Key was already used with a different batch.")
        return {
            "message": f"Created {int(rows[0]['OrderCount'])} Pegasus Conditional Entry Trade Intents.",
            "count": int(rows[0]["OrderCount"]),
            "order_kind": "CONDITIONAL_ENTRY",
            "request_id": request_id,
            "replayed": True,
        }

    replay = replay_if_present()
    if replay is not None:
        return replay
    statements = [
        "SET XACT_ABORT ON;", "BEGIN TRY", "BEGIN TRANSACTION;",
        "INSERT INTO Trading.ConditionalEntryBatchRequest (RequestId, RequestHash, OrderCount) VALUES (?, ?, ?);",
        "DECLARE @OrderId BIGINT;",
        "IF NOT EXISTS (SELECT 1 FROM Trading.Strategy WHERE StrategyId = ? AND StrategyCode = 'CONDITIONAL_ENTRY')",
        "    THROW 51020, 'StrategyId must refer to CONDITIONAL_ENTRY.', 1;",
    ]
    params: list[Any] = [request_id, request_hash, len(normalized_orders), normalized_orders[0]["strategy_id"]]
    for item in normalized_orders:
        condition = item["condition"]
        canonical = json.dumps(condition, sort_keys=True, separators=(",", ":"))
        condition_hash = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
        statements.append(
            """INSERT INTO Trading.Orders
                (StrategyId, StockCode, Side, OrderSourceType, SignalType, TimeFrame, EntryType, EntryPrice,
                 Quantity, ProfitTargetPrice, StopLossPrice, StopLossMode, Status, BacktestRunId, MetaJson,
                 OrderKind, CreatedAt, UpdatedAt)
               VALUES (?, ?, ?, 'MANUAL', NULL, '5M', 'LIMIT', NULL, ?, NULL, NULL, 'BAR_CLOSE',
                       'PENDING', NULL, NULL, 'CONDITIONAL_ENTRY', GETDATE(), GETDATE());
               SET @OrderId = SCOPE_IDENTITY();
               INSERT INTO Trading.ConditionalEntryCondition
                   (OrderId, ConditionVersion, SchemaVersion, ConditionHash,
                    TargetPriceOperator, TargetPriceThreshold, TargetPriceActivationMode,
                    TargetPriceTickSize, TriggerStockCode, TriggerPriceOperator,
                    TriggerPriceThreshold, TriggerPriceActivationMode, TriggerPriceTickSize, AccountId,
                    PositionStockCode, PositionOperator, PositionShares,
                    MaximumMarginCapacityUsed, TimeZoneName, TimeWindowStart, TimeWindowEnd,
                    TimeWindowMode, ExpiresAtUtc)
               VALUES (@OrderId, 1, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL);"""
        )
        params.extend((
            item["strategy_id"], item["stock_code"], item["side"], item["quantity"],
            condition_hash,
            condition["target_price_operator"], condition["target_price_threshold"],
            condition["target_price_activation_mode"], condition["target_price_tick_size"],
            condition["trigger_stock_code"], condition["trigger_price_operator"],
            condition["trigger_price_threshold"], condition["trigger_price_activation_mode"],
            condition["trigger_price_tick_size"], condition["account_id"],
            condition["position_stock_code"], condition["position_operator"],
            condition["position_shares"], condition["maximum_margin_capacity_used"],
            condition["time_zone_name"], condition["time_window_start"],
            condition["time_window_end"], condition["time_window_mode"],
        ))
    statements.extend(["COMMIT TRANSACTION;", "END TRY", "BEGIN CATCH",
                       "IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;", "THROW;", "END CATCH;"])
    try:
        model.execute_update_usp("\n".join(statements), tuple(params))
    except Exception:
        # A concurrent retry may win the unique RequestId insert, or the SQL
        # commit may succeed while its response is lost. Reconcile by key/hash.
        replay = replay_if_present()
        if replay is not None:
            return replay
        raise
    return {
        "message": f"Created {len(normalized_orders)} Pegasus Conditional Entry Trade Intents.",
        "count": len(normalized_orders),
        "order_kind": "CONDITIONAL_ENTRY",
        "request_id": request_id,
        "replayed": False,
    }


@router.get("/trading-orders/conditional-entry")
def list_conditional_entry_orders(
    limit: int = Query(100, ge=1, le=500),
    status: Optional[str] = Query(None),
) -> List[Dict[str, Any]]:
    """Read Conditional Entry condition, audit, outbox and submission state."""
    if not os.getenv("PEGASUS_CONDITIONAL_ENTRY_SCHEMA_READY", "false").strip().lower() == "true":
        raise HTTPException(status_code=503, detail="Conditional Entry schema is not ready.")
    valid_statuses = {"PENDING", "PLACED", "OPEN", "CLOSED", "CANCELLED"}
    normalized_status = (status or "").strip().upper() or None
    if normalized_status and normalized_status not in valid_statuses:
        raise HTTPException(status_code=400, detail="Invalid Conditional Entry status.")
    status_clause = " AND o.Status = ?" if normalized_status else ""
    params: tuple[Any, ...] = (int(limit), normalized_status) if normalized_status else (int(limit),)
    rows = SQLServerModel(database=DB_NAME).execute_read_query(
        f"""
        SELECT TOP (?) o.OrderId, o.StockCode, o.Side, o.Quantity, o.EntryType, o.Status,
               o.CreatedAt, o.UpdatedAt, c.ConditionVersion, c.ConditionHash,
               c.TargetPriceOperator, c.TargetPriceThreshold, c.TargetPriceActivationMode,
               c.TargetPriceTickSize, c.TriggerStockCode, c.TriggerPriceOperator,
               c.TriggerPriceThreshold, c.TriggerPriceActivationMode, c.TriggerPriceTickSize, c.ExpiresAtUtc,
               target_cursor.Region AS TargetCursorRegion,
               target_cursor.TouchPrice AS TargetTouchPrice,
               target_cursor.TouchObservedAtUtc AS TargetTouchObservedAtUtc,
               trigger_cursor.Region AS TriggerCursorRegion,
               trigger_cursor.TouchPrice AS TriggerTouchPrice,
               trigger_cursor.TouchObservedAtUtc AS TriggerTouchObservedAtUtc,
               latest.AttemptId, latest.AttemptState, latest.EventSourceCode,
               latest.ObservationId, latest.ObservedAtUtc, latest.ObservedPrice, latest.ClauseResultsJson,
               submission.SubmissionState, submission.BrokerOrderId,
               outbox.PublishedAtUtc, outbox.LastPublishError,
               JSON_VALUE(outbox.PayloadJson, '$.evaluator_mode') AS EvaluatorMode,
               outbox.DeploymentEpoch
          FROM Trading.Orders AS o
          JOIN Trading.ConditionalEntryCondition AS c
            ON c.OrderId = o.OrderId
           AND c.ConditionVersion = (SELECT MAX(v.ConditionVersion)
                                       FROM Trading.ConditionalEntryCondition AS v
                                      WHERE v.OrderId = o.OrderId)
          LEFT JOIN Trading.ConditionalEntryCursor AS target_cursor
            ON target_cursor.OrderId = o.OrderId
           AND target_cursor.ConditionVersion = c.ConditionVersion
           AND target_cursor.SourceCode = o.StockCode
          LEFT JOIN Trading.ConditionalEntryCursor AS trigger_cursor
            ON trigger_cursor.OrderId = o.OrderId
           AND trigger_cursor.ConditionVersion = c.ConditionVersion
           AND trigger_cursor.SourceCode = c.TriggerStockCode
          OUTER APPLY (SELECT TOP 1 a.AttemptId, a.AttemptState, a.EventSourceCode,
                              a.ObservationId, a.ObservedAtUtc, a.ObservedPrice, a.ClauseResultsJson
                         FROM Trading.ConditionalEntryAttempt AS a
                        WHERE a.OrderId = o.OrderId AND a.ConditionVersion = c.ConditionVersion
                        ORDER BY a.CreatedAtUtc DESC, a.AttemptId DESC) AS latest
          LEFT JOIN Trading.ConditionalEntrySubmission AS submission ON submission.AttemptId = latest.AttemptId
          LEFT JOIN Trading.ExecutionOutbox AS outbox ON outbox.AttemptId = latest.AttemptId
         WHERE o.OrderKind = 'CONDITIONAL_ENTRY' AND o.BacktestRunId IS NULL{status_clause}
         ORDER BY o.CreatedAt DESC, o.OrderId DESC
        """,
        params,
    ) or []
    return [dict(row) for row in rows]


@router.post("/trading-orders/conditional-entry/{order_id}/cancel")
def cancel_conditional_entry(order_id: int) -> Dict[str, Any]:
    """Compare-and-set cancellation; never delete the Trade Intent or audit."""
    if not _conditional_entry_runtime_enabled():
        raise HTTPException(status_code=503, detail="Pegasus Conditional Entries are not enabled yet.")
    model = SQLServerModel(database=DB_NAME)
    current = model.execute_read_query(
        """SELECT Status, EntryPlacedAt, EntryFilledAt FROM Trading.Orders
            WHERE OrderId = ? AND OrderKind = 'CONDITIONAL_ENTRY' AND BacktestRunId IS NULL""",
        (order_id,),
    ) or []
    if not current:
        raise HTTPException(status_code=404, detail="Conditional Entry Trade Intent not found.")
    if str(current[0].get("Status", "")).upper() == "CANCELLED":
        return {"order_id": order_id, "status": "CANCELLED", "already_cancelled": True}
    if str(current[0].get("Status", "")).upper() != "PENDING" or current[0].get("EntryFilledAt"):
        raise HTTPException(status_code=409, detail="Trade Intent is no longer safely cancellable; reconcile broker state first.")
    try:
        model.execute_update_usp(
            """SET XACT_ABORT ON;
               BEGIN TRY
                 BEGIN TRANSACTION;
                 IF EXISTS (SELECT 1 FROM Trading.ConditionalEntrySubmission WITH (UPDLOCK, HOLDLOCK)
                             WHERE OrderId = ? AND SubmissionState IN ('SUBMITTING','ACCEPTED','UNCERTAIN'))
                     THROW 51031, 'Submission requires broker reconciliation.', 1;
                 UPDATE Trading.Orders WITH (UPDLOCK)
                    SET Status = 'CANCELLED', UpdatedAt = GETDATE()
                  WHERE OrderId = ? AND OrderKind = 'CONDITIONAL_ENTRY' AND Status = 'PENDING'
                    AND EntryFilledAt IS NULL;
                 IF @@ROWCOUNT <> 1 THROW 51032, 'Trade Intent changed before cancellation.', 1;
                 UPDATE Trading.ConditionalEntrySubmission
                    SET SubmissionState = 'CANCELLED', UpdatedAtUtc = SYSUTCDATETIME()
                  WHERE OrderId = ? AND SubmissionState = 'CLAIMED';
                 UPDATE a SET AttemptState = 'CANCELLED', UpdatedAtUtc = SYSUTCDATETIME()
                   FROM Trading.ConditionalEntryAttempt AS a
                   JOIN Trading.ConditionalEntrySubmission AS s ON s.AttemptId = a.AttemptId
                  WHERE s.OrderId = ? AND a.AttemptState = 'CLAIMED';
                 COMMIT TRANSACTION;
               END TRY
               BEGIN CATCH
                 IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                 THROW;
               END CATCH;""",
            (order_id, order_id, order_id, order_id),
        )
    except Exception as exc:
        raise HTTPException(status_code=409, detail="Trade Intent changed or requires broker reconciliation; refresh before retrying.") from exc
    return {"order_id": order_id, "status": "CANCELLED", "already_cancelled": False}


@router.put("/trading-orders/{order_id}")
def update_trading_order(order_id: int, order: TradingOrderUpdate) -> Dict[str, Any]:
    normalized = _normalize_order_inputs(order)
    model = SQLServerModel(database=DB_NAME)
    conditional_rows = model.execute_read_query(
        "SELECT OrderKind FROM Trading.Orders WHERE OrderId = ?",
        (order_id,),
    ) or []
    if conditional_rows and str(conditional_rows[0].get("OrderKind", "")).upper() == "CONDITIONAL_ENTRY":
        raise HTTPException(status_code=409, detail="Cancel and recreate a Conditional Entry Trade Intent to change its terms.")
    if model.execute_read_query(
        "SELECT TOP 1 ActivationId FROM Trading.OrderActivation WHERE OrderId = ?",
        (order_id,),
    ):
        raise HTTPException(status_code=409, detail="Cancel and recreate a conditional Trade Intent to change its terms.")
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
    order_kind_rows = model.execute_read_query(
        "SELECT OrderKind FROM Trading.Orders WHERE OrderId = ?",
        (order_id,),
    ) or []
    if order_kind_rows and str(order_kind_rows[0].get("OrderKind", "LEGACY")).upper() == "CONDITIONAL_ENTRY":
        raise HTTPException(status_code=409, detail="Use the Conditional Entry cancellation endpoint for this Trade Intent.")
    try:
        model.execute_update_usp(
        """
        SET XACT_ABORT ON;
        BEGIN TRY
            BEGIN TRANSACTION;
            IF EXISTS (
                SELECT 1 FROM Trading.OrderActivation WITH (UPDLOCK, HOLDLOCK)
                WHERE OrderId = ? AND State = 'CLAIMED'
            )
                THROW 51001, 'Conditional activation is being submitted; retry cancellation after reconciliation.', 1;
            UPDATE Trading.Orders
            SET Status = 'CANCELLED', UpdatedAt = GETDATE()
            WHERE OrderId = ? AND Status IN ('PENDING', 'PLACED');
            UPDATE Trading.OrderActivation
            SET State = 'CANCELLED', UpdatedAt = GETDATE()
            WHERE OrderId = ? AND State = 'ARMED';
            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            THROW;
        END CATCH;
        """,
            (order_id, order_id, order_id),
        )
    except Exception as exc:
        if "51001" in str(exc):
            raise HTTPException(status_code=409, detail="Activation is being submitted; retry cancellation after it is reconciled.") from exc
        raise
    return {"message": "Order cancelled successfully."}


@router.post("/trading-orders/{order_id}/exit-fill")
def record_trading_order_exit_fill(order_id: int, fill: TradingOrderExitFill) -> Dict[str, Any]:
    if fill.fill_price <= 0:
        raise HTTPException(status_code=400, detail="Exit fill price must be greater than zero.")

    model = SQLServerModel(database=DB_NAME)
    order_rows = model.execute_read_query(
        """
        SELECT o.Status, o.ExitFilledAt, o.Quantity, o.OrderKind,
               COALESCE(SUM(CASE WHEN UPPER(f.FillType) = 'ENTRY' THEN f.FillQty ELSE 0 END), 0) AS EntryFilledQuantity
        FROM Trading.Orders AS o
        LEFT JOIN Trading.OrderFills AS f ON f.OrderId = o.OrderId
        WHERE o.OrderId = ?
        GROUP BY o.Status, o.ExitFilledAt, o.Quantity, o.OrderKind
        """,
        (order_id,),
    ) or []
    if not order_rows:
        raise HTTPException(status_code=404, detail="Trading order not found.")

    order_row = order_rows[0]
    status = str(order_row.get("Status") or "").strip().upper()
    if status != "OPEN":
        raise HTTPException(status_code=409, detail="Only OPEN orders can have a manual exit fill recorded.")
    if order_row.get("ExitFilledAt") is not None:
        raise HTTPException(status_code=409, detail="This order already has an exit fill time.")

    existing_exit_fills = model.execute_read_query(
        """
        SELECT TOP 1 FillId
        FROM Trading.OrderFills
        WHERE OrderId = ?
          AND UPPER(FillType) = 'EXIT'
          AND (Reason IS NULL OR UPPER(Reason) NOT LIKE '%STOP%')
        """,
        (order_id,),
    ) or []
    if existing_exit_fills:
        raise HTTPException(status_code=409, detail="This order already has an exit fill.")

    fill_time = fill.fill_time.replace(tzinfo=None)
    if str(order_row.get("OrderKind") or "LEGACY").upper() == "CONDITIONAL_ENTRY":
        fill_quantity = int(order_row.get("EntryFilledQuantity") or 0)
        if fill_quantity <= 0:
            raise HTTPException(status_code=409, detail="No durable entry fill is recorded for this Conditional Entry.")
    else:
        fill_quantity = int(order_row.get("Quantity") or 0)
    model.execute_update_usp(
        """
        SET XACT_ABORT ON;
        BEGIN TRANSACTION;

        UPDATE Trading.Orders
        SET ExitFilledAt = ?,
            Status = 'CLOSED',
            UpdatedAt = GETDATE()
        WHERE OrderId = ?
          AND Status = 'OPEN'
          AND ExitFilledAt IS NULL;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR ('Order is no longer OPEN or already has an exit fill.', 16, 1);
            RETURN;
        END;

        INSERT INTO Trading.OrderFills
            (OrderId, FillTime, FillPrice, FillQty, FillType, Reason)
        VALUES
            (?, ?, ?, ?, 'EXIT', 'MANUAL');

        COMMIT TRANSACTION;
        """,
        (fill_time, order_id, order_id, fill_time, fill.fill_price, fill_quantity),
    )
    return {
        "message": "Manual exit fill recorded successfully.",
        "order_id": order_id,
        "status": "CLOSED",
        "exit_filled_at": fill_time,
        "exit_fill_price": fill.fill_price,
        "exit_fill_qty": fill_quantity,
    }
