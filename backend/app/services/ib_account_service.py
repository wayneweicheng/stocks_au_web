from __future__ import annotations

import asyncio
import logging
import math
import random
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from app.core.config import settings

try:
    from ib_insync import IB  # type: ignore
except Exception:  # pragma: no cover
    IB = None  # type: ignore


logger = logging.getLogger("app.ib_account_service")

ACCOUNT_TAGS = [
    "NetLiquidation",
    "TotalCashValue",
    "AvailableFunds",
    "ExcessLiquidity",
    "BuyingPower",
    "GrossPositionValue",
    "InitMarginReq",
    "MaintMarginReq",
    "SMA",
    "Cushion",
]

CAPACITY_TARGETS = [1.0, 1.25, 1.5, 2.0]


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _to_float(value: Any) -> Optional[float]:
    try:
        if value is None:
            return None
        if isinstance(value, str) and value.strip() == "":
            return None
        n = float(value)
        if not math.isfinite(n):
            return None
        return n
    except Exception:
        return None


def _round_money(value: Optional[float]) -> Optional[float]:
    return None if value is None else round(float(value), 2)


def _round_ratio(value: Optional[float]) -> Optional[float]:
    return None if value is None else round(float(value), 4)


def _connect_ib() -> "tuple[IB, asyncio.AbstractEventLoop]":
    if IB is None:
        raise RuntimeError("ib_insync is not installed on the backend")

    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)

    ib = IB()
    host = (settings.ibg_api_host or "127.0.0.1").strip() or "127.0.0.1"
    port_cfg = int(settings.ibg_api_port or 0)
    candidate_ports: List[int] = []
    if port_cfg > 0:
        candidate_ports.append(port_cfg)
    for port in [4002, 4001, 7496, 7497]:
        if port not in candidate_ports:
            candidate_ports.append(port)

    last_err: Exception | None = None
    client_id = random.randint(65001, 70000)
    for port in candidate_ports:
        try:
            ib.connect(host, port, clientId=client_id, timeout=10)
            logger.info("IB account risk: connected to %s:%s with clientId=%s", host, port, client_id)
            return ib, loop
        except Exception as exc:
            last_err = exc
            logger.warning("IB account risk: failed connect to %s:%s - %s", host, port, exc)

    raise RuntimeError(f"Failed to connect to IB API at {host}:{candidate_ports} ({last_err})")


def _select_account_values(summary: List[Any], account: Optional[str]) -> tuple[str | None, Dict[str, Dict[str, Any]]]:
    accounts = sorted({str(getattr(item, "account", "") or "") for item in summary if getattr(item, "account", "")})
    real_accounts = [acct for acct in accounts if acct.lower() != "all"]
    selected_account = (account or "").strip() or (real_accounts[0] if real_accounts else (accounts[0] if accounts else None))
    values: Dict[str, Dict[str, Any]] = {}

    for item in summary:
        item_account = str(getattr(item, "account", "") or "")
        if selected_account and item_account and item_account != selected_account:
            continue
        tag = str(getattr(item, "tag", "") or "")
        if tag not in ACCOUNT_TAGS:
            continue
        currency = str(getattr(item, "currency", "") or "")
        values[tag] = {
            "value": _to_float(getattr(item, "value", None)),
            "currency": currency or None,
            "raw_value": getattr(item, "value", None),
        }

    return selected_account, values


def _metric(values: Dict[str, Dict[str, Any]], tag: str) -> Optional[float]:
    item = values.get(tag) or {}
    return _to_float(item.get("value"))


def _currency(values: Dict[str, Dict[str, Any]], tag: str = "NetLiquidation") -> Optional[str]:
    item = values.get(tag) or {}
    return item.get("currency") or None


def _capacity_rows(net_liquidation: Optional[float], gross_position_value: Optional[float]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    if net_liquidation is None or gross_position_value is None:
        return rows
    for target in CAPACITY_TARGETS:
        max_gross = target * net_liquidation
        room = max_gross - gross_position_value
        rows.append(
            {
                "target_leverage": target,
                "max_gross_exposure": _round_money(max_gross),
                "room": _round_money(max(0.0, room)),
                "over_by": _round_money(abs(room)) if room < 0 else 0.0,
            }
        )
    return rows


def _position_rows(portfolio_items: List[Any], account: Optional[str]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for item in portfolio_items:
        item_account = str(getattr(item, "account", "") or "")
        if account and item_account and item_account != account:
            continue
        contract = getattr(item, "contract", None)
        symbol = getattr(contract, "symbol", None) or getattr(contract, "localSymbol", None) or ""
        sec_type = getattr(contract, "secType", None) or ""
        currency = getattr(contract, "currency", None) or ""
        exchange = getattr(contract, "exchange", None) or ""
        position = _to_float(getattr(item, "position", None))
        market_value = _to_float(getattr(item, "marketValue", None))
        rows.append(
            {
                "account": item_account or None,
                "symbol": symbol,
                "sec_type": sec_type,
                "currency": currency,
                "exchange": exchange,
                "position": position,
                "market_price": _round_money(_to_float(getattr(item, "marketPrice", None))),
                "market_value": _round_money(market_value),
                "average_cost": _round_money(_to_float(getattr(item, "averageCost", None))),
                "unrealized_pnl": _round_money(_to_float(getattr(item, "unrealizedPNL", None))),
                "realized_pnl": _round_money(_to_float(getattr(item, "realizedPNL", None))),
            }
        )
    return sorted(rows, key=lambda row: abs(row.get("market_value") or 0), reverse=True)


def _open_order_rows(ib: "IB", account: Optional[str]) -> List[Dict[str, Any]]:
    try:
        ib.reqAllOpenOrders()
        ib.sleep(0.5)
    except Exception:
        try:
            ib.reqOpenOrders()
            ib.sleep(0.5)
        except Exception:
            pass

    rows: List[Dict[str, Any]] = []
    for trade in ib.openTrades():
        order = getattr(trade, "order", None)
        contract = getattr(trade, "contract", None)
        order_status = getattr(trade, "orderStatus", None)
        if order is None or contract is None:
            continue
        item_account = str(getattr(order, "account", "") or "")
        if account and item_account and item_account != account:
            continue
        qty = _to_float(getattr(order, "totalQuantity", None)) or 0.0
        limit_price = _to_float(getattr(order, "lmtPrice", None))
        notional = abs(qty * limit_price) if limit_price is not None else None
        rows.append(
            {
                "account": item_account or None,
                "symbol": getattr(contract, "symbol", None) or getattr(contract, "localSymbol", None) or "",
                "sec_type": getattr(contract, "secType", None) or "",
                "action": getattr(order, "action", None),
                "order_type": getattr(order, "orderType", None),
                "status": getattr(order_status, "status", None),
                "quantity": qty,
                "limit_price": _round_money(limit_price),
                "estimated_notional": _round_money(notional),
                "order_id": getattr(order, "orderId", None),
            }
        )
    return rows


def get_account_risk(account: Optional[str] = None) -> Dict[str, Any]:
    ib, _loop = _connect_ib()
    try:
        summary = ib.accountSummary()
        selected_account, values = _select_account_values(summary, account)

        net_liquidation = _metric(values, "NetLiquidation")
        gross_position_value = _metric(values, "GrossPositionValue")
        init_margin = _metric(values, "InitMarginReq")
        maint_margin = _metric(values, "MaintMarginReq")
        excess_liquidity = _metric(values, "ExcessLiquidity")

        current_leverage = (
            abs(gross_position_value) / net_liquidation
            if net_liquidation and gross_position_value is not None and net_liquidation > 0
            else None
        )
        init_margin_ratio = init_margin / net_liquidation if net_liquidation and init_margin is not None else None
        maint_margin_ratio = maint_margin / net_liquidation if net_liquidation and maint_margin is not None else None
        excess_liquidity_ratio = (
            excess_liquidity / net_liquidation if net_liquidation and excess_liquidity is not None else None
        )

        portfolio_items = ib.portfolio()
        positions = _position_rows(portfolio_items, selected_account)
        open_orders = _open_order_rows(ib, selected_account)
        buy_order_notional = sum(
            row.get("estimated_notional") or 0
            for row in open_orders
            if str(row.get("action") or "").upper() == "BUY"
        )

        return {
            "ok": True,
            "as_of": _utc_now_iso(),
            "account": selected_account,
            "currency": _currency(values),
            "metrics": {
                "net_liquidation": _round_money(net_liquidation),
                "cash": _round_money(_metric(values, "TotalCashValue")),
                "available_funds": _round_money(_metric(values, "AvailableFunds")),
                "excess_liquidity": _round_money(excess_liquidity),
                "buying_power": _round_money(_metric(values, "BuyingPower")),
                "gross_position_value": _round_money(gross_position_value),
                "init_margin_req": _round_money(init_margin),
                "maint_margin_req": _round_money(maint_margin),
                "sma": _round_money(_metric(values, "SMA")),
                "cushion": _round_ratio(_metric(values, "Cushion")),
                "current_leverage": _round_ratio(current_leverage),
                "init_margin_ratio": _round_ratio(init_margin_ratio),
                "maint_margin_ratio": _round_ratio(maint_margin_ratio),
                "excess_liquidity_ratio": _round_ratio(excess_liquidity_ratio),
                "open_buy_order_notional": _round_money(buy_order_notional),
            },
            "capacity": _capacity_rows(net_liquidation, gross_position_value),
            "positions": positions,
            "open_orders": open_orders,
            "raw_account_summary": values,
        }
    finally:
        try:
            ib.disconnect()
        except Exception:
            pass
