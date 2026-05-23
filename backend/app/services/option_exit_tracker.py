from __future__ import annotations

from datetime import datetime, time, timezone
from pathlib import Path
from threading import Lock
from typing import Any, Dict, List, Optional
import json
import logging
import math
import random
import asyncio
from zoneinfo import ZoneInfo

from app.core.config import settings

try:
    from ib_insync import IB, Option, LimitOrder, ExecutionFilter  # type: ignore
except Exception:  # pragma: no cover
    IB = None  # type: ignore
    Option = None  # type: ignore
    LimitOrder = None  # type: ignore
    ExecutionFilter = None  # type: ignore


logger = logging.getLogger("app.option_exit_tracker")

_STORE_PATH = Path(__file__).resolve().parents[2] / "data" / "option_exit_tracker.json"
_LOCK = Lock()
_US_EASTERN = ZoneInfo("America/New_York")
_US_OPTIONS_MANAGED_EXIT_CUTOFF = time(16, 0)


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _is_after_us_options_cutoff(now: Optional[datetime] = None) -> bool:
    eastern_now = (now or datetime.now(timezone.utc)).astimezone(_US_EASTERN)
    return eastern_now.time() >= _US_OPTIONS_MANAGED_EXIT_CUTOFF


def _is_stale_trading_day(item: Dict[str, Any], now: Optional[datetime] = None) -> bool:
    created_at_raw = item.get("created_at")
    if not created_at_raw:
        return False
    try:
        created_at = datetime.fromisoformat(str(created_at_raw))
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=timezone.utc)
    except Exception:
        return False

    eastern_created = created_at.astimezone(_US_EASTERN)
    eastern_now = (now or datetime.now(timezone.utc)).astimezone(_US_EASTERN)
    return eastern_created.date() < eastern_now.date()


def _expire_active_item(item: Dict[str, Any], reason: str) -> None:
    item["status"] = "expired_no_exit"
    item["updated_at"] = _utc_now_iso()
    item["last_message"] = reason


def _load_items() -> List[Dict[str, Any]]:
    with _LOCK:
        if not _STORE_PATH.exists():
            return []
        try:
            data = json.loads(_STORE_PATH.read_text(encoding="utf-8"))
            return data if isinstance(data, list) else []
        except Exception as exc:
            logger.warning("Failed to read option exit tracker store: %s", exc)
            return []


def _save_items(items: List[Dict[str, Any]]) -> None:
    with _LOCK:
        _STORE_PATH.parent.mkdir(parents=True, exist_ok=True)
        tmp_path = _STORE_PATH.with_suffix(".tmp")
        tmp_path.write_text(json.dumps(items, indent=2, sort_keys=True), encoding="utf-8")
        tmp_path.replace(_STORE_PATH)


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
    for port in candidate_ports:
        try:
            client_id = random.randint(50001, 65000)
            ib.connect(host, port, clientId=client_id, timeout=10)
            logger.info("IB tracker: connected to %s:%s with clientId=%s", host, port, client_id)
            return ib, loop
        except Exception as exc:
            last_err = exc
            logger.warning("IB tracker: failed connect to %s:%s - %s", host, port, exc)

    raise RuntimeError(f"Failed to connect to IB API at {host}:{candidate_ports} ({last_err})")


def _parse_option_symbol(option_symbol: str) -> tuple[str, str, float, str] | None:
    try:
        s = option_symbol.strip().upper()
        i = 0
        while i < len(s) and s[i].isalpha():
            i += 1
        if i == 0:
            return None

        underlying = s[:i]
        remainder = s[i:]
        if len(remainder) < 15:
            return None

        date_part = remainder[:6]
        if not date_part.isdigit():
            return None
        expiry = f"20{date_part[:2]}{date_part[2:4]}{date_part[4:6]}"

        right = remainder[6]
        if right not in ("C", "P"):
            return None

        strike_part = remainder[7:15]
        if not strike_part.isdigit():
            return None

        return underlying, expiry, float(strike_part) / 1000.0, right
    except Exception:
        return None


def _build_option_contract(option_symbol: str):
    if Option is None:
        raise RuntimeError("ib_insync Option support not available")
    parsed = _parse_option_symbol(option_symbol)
    if not parsed:
        raise RuntimeError(f"Invalid option symbol format: {option_symbol}")
    underlying, expiry, strike, right = parsed
    return Option(
        symbol=underlying,
        lastTradeDateOrContractMonth=expiry,
        strike=strike,
        right=right,
        exchange="SMART",
        currency="USD",
    )


def _same_option_contract(contract: Any, option_symbol: str) -> bool:
    parsed = _parse_option_symbol(option_symbol)
    if not parsed:
        return False
    underlying, expiry, strike, right = parsed
    return (
        getattr(contract, "symbol", "").upper() == underlying
        and str(getattr(contract, "lastTradeDateOrContractMonth", "")) == expiry
        and getattr(contract, "right", "").upper() == right
        and abs(float(getattr(contract, "strike", 0.0)) - strike) < 0.0001
    )


def register_option_exit(
    *,
    option_symbol: str,
    entry_order_id: Optional[int],
    entry_client_id: Optional[int],
    entry_perm_id: Optional[int],
    quantity: int,
    entry_price: float,
    exit_price: float,
    exit_tif: str = "GTC",
) -> Dict[str, Any]:
    item = {
        "tracker_id": f"{option_symbol}-{entry_order_id or 'pending'}-{int(datetime.now(timezone.utc).timestamp() * 1000)}",
        "option_symbol": option_symbol,
        "entry_order_id": entry_order_id,
        "entry_client_id": entry_client_id,
        "entry_perm_id": entry_perm_id,
        "quantity": int(quantity),
        "entry_price": round(float(entry_price), 2),
        "exit_price": round(float(exit_price), 2),
        "exit_tif": exit_tif.upper(),
        "status": "watching_entry",
        "filled_quantity": 0,
        "fill_avg_price": None,
        "fill_exec_ids": [],
        "exit_order_id": None,
        "exit_perm_id": None,
        "created_at": _utc_now_iso(),
        "updated_at": _utc_now_iso(),
        "last_message": "Waiting for entry fill before placing exit.",
    }
    items = _load_items()
    items.append(item)
    _save_items(items)
    return item


def get_tracked_option_exits(limit: int = 200) -> List[Dict[str, Any]]:
    return _load_items()[-limit:]


def _fill_matches_item(fill: Any, item: Dict[str, Any]) -> bool:
    execution = getattr(fill, "execution", None)
    contract = getattr(fill, "contract", None)
    if execution is None or contract is None:
        return False
    if not _same_option_contract(contract, str(item["option_symbol"])):
        return False
    if str(getattr(execution, "side", "")).upper() not in ("SLD", "SELL"):
        return False

    entry_perm_id = item.get("entry_perm_id")
    if entry_perm_id and int(getattr(execution, "permId", 0) or 0) == int(entry_perm_id):
        return True

    entry_order_id = item.get("entry_order_id")
    entry_client_id = item.get("entry_client_id")
    return bool(
        entry_order_id
        and entry_client_id
        and int(getattr(execution, "orderId", 0) or 0) == int(entry_order_id)
        and int(getattr(execution, "clientId", 0) or 0) == int(entry_client_id)
    )


def _open_sell_entries_exist(
    ib: "IB",
    option_symbol: str,
    ignored_order_id: Optional[int],
    ignored_client_id: Optional[int],
) -> bool:
    try:
        ib.reqAllOpenOrders()
        ib.sleep(0.5)
    except Exception:
        try:
            ib.reqOpenOrders()
            ib.sleep(0.5)
        except Exception:
            pass

    for trade in ib.openTrades():
        order = getattr(trade, "order", None)
        contract = getattr(trade, "contract", None)
        status = getattr(getattr(trade, "orderStatus", None), "status", "")
        if order is None or contract is None:
            continue
        if (
            ignored_order_id
            and ignored_client_id
            and int(getattr(order, "orderId", 0) or 0) == int(ignored_order_id)
            and int(getattr(order, "clientId", 0) or 0) == int(ignored_client_id)
        ):
            continue
        if status in {"Cancelled", "Filled", "Inactive"}:
            continue
        if getattr(order, "action", "").upper() == "SELL" and _same_option_contract(contract, option_symbol):
            return True
    return False


def process_option_exit_tracker() -> Dict[str, Any]:
    items = _load_items()
    active_items = [item for item in items if item.get("status") in {"watching_entry", "entry_filled_waiting_for_clear"}]
    if not active_items:
        return {"processed": 0, "placed": 0, "waiting": 0, "message": "No active option exit trackers."}

    now = datetime.now(timezone.utc)
    if _is_after_us_options_cutoff(now) or any(_is_stale_trading_day(item, now) for item in active_items):
        expired = 0
        for item in active_items:
            if _is_after_us_options_cutoff(now) or _is_stale_trading_day(item, now):
                _expire_active_item(
                    item,
                    "Managed exit expired after the US options session cutoff; no BUY exit was placed.",
                )
                expired += 1
        _save_items(items)
        return {"processed": len(active_items), "placed": 0, "waiting": 0, "expired": expired}

    ib, _loop = _connect_ib()
    placed = 0
    waiting = 0
    try:
        fills = ib.reqExecutions(ExecutionFilter() if ExecutionFilter is not None else None)
        for item in active_items:
            matched_fills = [fill for fill in fills if _fill_matches_item(fill, item)]
            if not matched_fills:
                continue

            seen_exec_ids = set(item.get("fill_exec_ids") or [])
            new_fills = [
                fill for fill in matched_fills
                if getattr(getattr(fill, "execution", None), "execId", "") not in seen_exec_ids
            ]
            if new_fills:
                all_relevant = matched_fills
                total_qty = sum(float(getattr(fill.execution, "shares", 0.0) or 0.0) for fill in all_relevant)
                weighted_value = sum(
                    float(getattr(fill.execution, "shares", 0.0) or 0.0)
                    * float(getattr(fill.execution, "price", 0.0) or 0.0)
                    for fill in all_relevant
                )
                item["filled_quantity"] = int(math.floor(total_qty))
                item["fill_avg_price"] = round(weighted_value / total_qty, 4) if total_qty > 0 else None
                item["fill_exec_ids"] = [
                    getattr(fill.execution, "execId", "")
                    for fill in all_relevant
                    if getattr(fill.execution, "execId", "")
                ]

            if int(item.get("filled_quantity") or 0) < int(item.get("quantity") or 0):
                item["status"] = "watching_entry"
                item["last_message"] = "Entry is partially filled; waiting for full fill."
                item["updated_at"] = _utc_now_iso()
                continue

            if _open_sell_entries_exist(
                ib,
                str(item["option_symbol"]),
                item.get("entry_order_id"),
                item.get("entry_client_id"),
            ):
                item["status"] = "entry_filled_waiting_for_clear"
                item["last_message"] = (
                    "Entry filled, but another SELL entry is still open for this option. "
                    "Waiting before placing BUY exit to satisfy IB same-contract side restrictions."
                )
                item["updated_at"] = _utc_now_iso()
                waiting += 1
                continue

            contract = _build_option_contract(str(item["option_symbol"]))
            ib.qualifyContracts(contract)
            exit_order = LimitOrder("BUY", int(item["quantity"]), lmtPrice=float(item["exit_price"]))
            exit_order.outsideRth = True
            try:
                exit_order.tif = str(item.get("exit_tif") or "GTC").upper()
            except Exception:
                pass
            exit_order.eTradeOnly = None
            exit_order.firmQuoteOnly = None
            trade = ib.placeOrder(contract, exit_order)
            ib.sleep(0.5)

            item["status"] = "exit_placed"
            item["exit_order_id"] = getattr(trade.order, "orderId", None) if trade.order else None
            item["exit_perm_id"] = getattr(trade.order, "permId", None) if trade.order else None
            item["updated_at"] = _utc_now_iso()
            item["last_message"] = f"Placed BUY exit at ${float(item['exit_price']):.2f}."
            placed += 1

        _save_items(items)
        return {"processed": len(active_items), "placed": placed, "waiting": waiting}
    except Exception as exc:
        logger.exception("Option exit tracker failed: %s", exc)
        raise
    finally:
        try:
            ib.disconnect()
        except Exception:
            pass
