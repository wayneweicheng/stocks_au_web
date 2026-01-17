from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, field_validator
from typing import List, Dict, Any, Optional
from .auth import verify_credentials
from app.core.config import settings
import math
import random
import time
import logging
import asyncio

try:
    from ib_insync import IB, Stock, LimitOrder, StopOrder  # type: ignore
except Exception:  # pragma: no cover
    IB = None  # type: ignore
    Stock = None  # type: ignore
    LimitOrder = None  # type: ignore
    StopOrder = None  # type: ignore


router = APIRouter(prefix="/api/ib", tags=["ib-orders"], dependencies=[Depends(verify_credentials)])
logger = logging.getLogger("app")


def _normalize_us_symbol(symbol: str) -> str:
    s = (symbol or "").strip().upper()
    if not s:
        return s
    if "." in s:
        return s
    return f"{s}.US"


class PlaceOrderRequest(BaseModel):
    stock_code: str
    stock_dollar_amount: float
    buy_sell: str  # BUY | SELL

    @field_validator("buy_sell")
    @classmethod
    def validate_side(cls, v: str) -> str:
        vv = (v or "").strip().upper()
        if vv not in ("BUY", "SELL"):
            raise ValueError("buy_sell must be BUY or SELL")
        return vv

    @field_validator("stock_dollar_amount")
    @classmethod
    def validate_amount(cls, v: float) -> float:
        if v is None or v <= 0:
            raise ValueError("stock_dollar_amount must be > 0")
        return float(v)


class PlaceOrdersBatchRequest(BaseModel):
    orders: List[PlaceOrderRequest]

    @field_validator("orders")
    @classmethod
    def validate_orders(cls, v: List[PlaceOrderRequest]) -> List[PlaceOrderRequest]:
        if not v:
            raise ValueError("orders must not be empty")
        return v


class PlaceOrderAtPriceRequest(BaseModel):
    stock_code: str
    stock_dollar_amount: float
    buy_sell: str  # BUY | SELL
    limit_price: float
    place_day: bool = True
    place_overnight: bool = False

    @field_validator("buy_sell")
    @classmethod
    def validate_side(cls, v: str) -> str:
        vv = (v or "").strip().upper()
        if vv not in ("BUY", "SELL"):
            raise ValueError("buy_sell must be BUY or SELL")
        return vv

    @field_validator("stock_dollar_amount")
    @classmethod
    def validate_amount(cls, v: float) -> float:
        if v is None or v <= 0:
            raise ValueError("stock_dollar_amount must be > 0")
        return float(v)

    @field_validator("limit_price")
    @classmethod
    def validate_limit_price(cls, v: float) -> float:
        if v is None or v <= 0:
            raise ValueError("limit_price must be > 0")
        return float(v)


class BracketOrderConfig(BaseModel):
    """Configuration for bracket orders with take-profit and stop-loss."""
    enabled: bool = False
    take_profit_offset: float = 0.0  # Dollar amount offset for take-profit
    stop_loss_offset: float = 0.0    # Dollar amount offset for stop-loss

    @field_validator("take_profit_offset", "stop_loss_offset")
    @classmethod
    def validate_offsets(cls, v: float) -> float:
        if v < 0:
            raise ValueError("Offset must be >= 0")
        return float(v)


class PlaceOrdersAtPriceBatchRequest(BaseModel):
    orders: List[PlaceOrderAtPriceRequest]
    place_day: bool = True
    place_overnight: bool = False
    bracket_config: Optional[BracketOrderConfig] = None  # Optional bracket order settings

    @field_validator("orders")
    @classmethod
    def validate_orders(cls, v: List[PlaceOrderAtPriceRequest]) -> List[PlaceOrderAtPriceRequest]:
        if not v:
            raise ValueError("orders must not be empty")
        return v

def _connect_ib() -> "tuple[IB, asyncio.AbstractEventLoop]":
    if IB is None:
        raise HTTPException(status_code=500, detail="ib_insync is not installed on the backend")
    # Ensure an event loop exists in this worker thread
    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
    ib = IB()
    host = (settings.ibg_api_host or "127.0.0.1").strip() or "127.0.0.1"
    port_cfg = int(settings.ibg_api_port or 0)
    # Prefer IB Gateway defaults first (4002 live, 4001 paper), then TWS (7496/7497)
    candidate_ports = [port_cfg] if port_cfg > 0 else [4002, 4001, 7496, 7497]
    last_err: Exception | None = None
    # Use a fixed client ID so we can cancel orders placed by this same client
    fixed_client_id = 12345
    for p in candidate_ports:
        try:
            ib.connect(host, p, clientId=fixed_client_id)
            logger.info("IB: connected to %s:%s with clientId=%s", host, p, fixed_client_id)
            return ib, loop
        except Exception as e:
            last_err = e
            logger.warning("IB: failed connect to %s:%s - %s", host, p, e)
            continue
    raise HTTPException(status_code=502, detail=f"Failed to connect to IB API at {host}:{candidate_ports} ({last_err})")


def _build_contract(stock_code: str, overnight: bool = False):
    sym = (stock_code or "").strip().upper()
    if "." in sym:
        symbol_part, suffix = sym.split(".", 1)
        if suffix == "US":
            exchange = "OVERNIGHT" if overnight else "SMART"
            return Stock(symbol_part, exchange, "USD")
        if suffix == "AX":
            return Stock(symbol_part, "ASX", "AUD")
        # Default for unknown suffix
        exchange = "OVERNIGHT" if overnight else "SMART"
        return Stock(symbol_part, exchange, "USD")
    # Assume US if no suffix
    exchange = "OVERNIGHT" if overnight else "SMART"
    return Stock(sym, exchange, "USD")


def _round_price_for_market(price: float, stock_code: str) -> float:
    # Simple tick rounding: default to 0.01 for equities; adjust by market if needed
    tick = 0.01
    sc = (stock_code or "").upper()
    if sc.endswith(".AX"):
        tick = 0.01
    return round(max(0.0, float(price)), 2 if tick == 0.01 else 4)


def _create_bracket_orders(
    ib: "IB",
    action: str,
    qty: int,
    entry_price: float,
    tp_offset: float,
    sl_offset: float,
    stock_code: str
) -> tuple:
    """
    Create a bracket order with parent entry, take-profit, and stop-loss orders.

    For BUY: TP is above entry (sell higher), SL is below entry (sell lower)
    For SELL: TP is below entry (buy lower to cover), SL is above entry (buy higher to stop out)

    Returns: (parent_order, tp_order, sl_order)
    """
    action_upper = action.upper()
    exit_action = "SELL" if action_upper == "BUY" else "BUY"

    # Calculate TP and SL prices based on direction
    if action_upper == "BUY":
        tp_price = _round_price_for_market(entry_price + tp_offset, stock_code)
        sl_price = _round_price_for_market(entry_price - sl_offset, stock_code)
    else:  # SELL (short)
        tp_price = _round_price_for_market(entry_price - tp_offset, stock_code)
        sl_price = _round_price_for_market(entry_price + sl_offset, stock_code)

    # Parent order (entry limit order)
    parent = LimitOrder(action_upper, qty, lmtPrice=entry_price)
    parent.orderId = ib.client.getReqId()
    parent.transmit = False  # Don't transmit until all orders are ready
    parent.outsideRth = True
    try:
        parent.tif = "DAY"
    except Exception:
        pass
    parent.eTradeOnly = None
    parent.firmQuoteOnly = None

    # Take-profit order (limit order at target price)
    tp = LimitOrder(exit_action, qty, lmtPrice=tp_price)
    tp.parentId = parent.orderId
    tp.ocaGroup = f"bracket_{parent.orderId}"
    tp.ocaType = 2  # Cancel all remaining when one fills
    tp.transmit = False
    tp.outsideRth = True
    try:
        tp.tif = "DAY"
    except Exception:
        pass
    tp.eTradeOnly = None
    tp.firmQuoteOnly = None

    # Stop-loss order (stop order at stop price)
    sl = StopOrder(exit_action, qty, auxPrice=sl_price)
    sl.parentId = parent.orderId
    sl.ocaGroup = f"bracket_{parent.orderId}"
    sl.ocaType = 2  # Cancel all remaining when one fills
    sl.transmit = True  # Last order triggers transmission of all
    sl.outsideRth = True
    try:
        sl.tif = "DAY"
    except Exception:
        pass
    sl.eTradeOnly = None
    sl.firmQuoteOnly = None

    return parent, tp, sl, tp_price, sl_price


@router.post("/place-order")
def place_order(order: PlaceOrderRequest) -> Dict[str, Any]:
    ib, loop = _connect_ib()
    try:
        code = _normalize_us_symbol(order.stock_code)
        contract = _build_contract(code)
        ib.qualifyContracts(contract)

        # Request market data and wait briefly for bid/ask
        ticker = ib.reqMktData(contract, "221,225,294,295", False, False)
        start = time.time()
        bid = getattr(ticker, "bid", float("nan"))
        ask = getattr(ticker, "ask", float("nan"))
        while (math.isnan(bid) or math.isnan(ask)) and (time.time() - start < 5.0):
            ib.sleep(0.25)
            bid = getattr(ticker, "bid", float("nan"))
            ask = getattr(ticker, "ask", float("nan"))

        # Choose limit price from side; fallback to mid if needed
        mid = (bid + ask) / 2 if not math.isnan(bid) and not math.isnan(ask) else float("nan")
        px = None
        if order.buy_sell.upper() == "BUY":
            px = ask if not math.isnan(ask) else mid
        else:
            px = bid if not math.isnan(bid) else mid
        if px is None or math.isnan(px):
            raise HTTPException(status_code=503, detail="Market data not available (bid/ask missing)")
        price = _round_price_for_market(px, code)

        # Compute quantity (do not exceed dollar amount)
        qty = int(math.ceil(float(order.stock_dollar_amount) / price))
        if qty <= 0:
            raise HTTPException(status_code=400, detail="Dollar amount too small for 1 share at current price")

        lo = LimitOrder(order.buy_sell.upper(), qty, lmtPrice=price)
        lo.outsideRth = True
        # Time in force: DAY (as requested)
        try:
            lo.tif = "DAY"
        except Exception:
            pass
        lo.eTradeOnly = None
        lo.firmQuoteOnly = None
        trade = ib.placeOrder(contract, lo)

        return {
            "message": f"Placed {order.buy_sell.upper()} {qty} {code} @ {price}",
            "order": {
                "stock_code": code,
                "qty": qty,
                "limit_price": price,
                "side": order.buy_sell.upper(),
            },
            "ib_order_id": getattr(trade, "order", None).orderId if getattr(trade, "order", None) else None,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("IB place_order unexpected error for %s: %s", order.stock_code, e)
        raise HTTPException(status_code=500, detail=f"Unexpected IB error: {e}")
    finally:
        try:
            ib.disconnect()
        except Exception:
            pass


@router.post("/place-order-at-price")
def place_order_at_price(order: PlaceOrderAtPriceRequest) -> Dict[str, Any]:
    ib, loop = _connect_ib()
    try:
        code = _normalize_us_symbol(order.stock_code)
        price = float(order.limit_price)
        if price <= 0:
            raise HTTPException(status_code=400, detail="limit_price must be > 0")

        qty = int(math.ceil(float(order.stock_dollar_amount) / price))
        if qty <= 0:
            raise HTTPException(status_code=400, detail="Dollar amount too small for 1 share at provided price")

        # Validate at least one exchange is selected
        if not order.place_day and not order.place_overnight:
            raise HTTPException(status_code=400, detail="At least one of place_day or place_overnight must be true")

        orders_placed = []

        # Place SMART exchange order if requested
        if order.place_day:
            contract = _build_contract(code, overnight=False)
            ib.qualifyContracts(contract)
            lo = LimitOrder(order.buy_sell.upper(), qty, lmtPrice=price)
            lo.outsideRth = True
            try:
                lo.tif = "DAY"
            except Exception:
                pass
            lo.eTradeOnly = None
            lo.firmQuoteOnly = None
            trade = ib.placeOrder(contract, lo)
            orders_placed.append({
                "exchange": "SMART",
                "stock_code": code,
                "qty": qty,
                "limit_price": price,
                "side": order.buy_sell.upper(),
                "ib_order_id": getattr(trade, "order", None).orderId if getattr(trade, "order", None) else None,
            })

        # Place OVERNIGHT exchange order if requested
        if order.place_overnight:
            if order.place_day:
                ib.sleep(0.2)  # Pause between orders to avoid rate limiting
            contract_overnight = _build_contract(code, overnight=True)
            ib.qualifyContracts(contract_overnight)
            lo_overnight = LimitOrder(order.buy_sell.upper(), qty, lmtPrice=price)
            lo_overnight.outsideRth = True
            try:
                lo_overnight.tif = "DAY"
            except Exception:
                pass
            lo_overnight.eTradeOnly = None
            lo_overnight.firmQuoteOnly = None
            trade_overnight = ib.placeOrder(contract_overnight, lo_overnight)
            orders_placed.append({
                "exchange": "OVERNIGHT",
                "stock_code": code,
                "qty": qty,
                "limit_price": price,
                "side": order.buy_sell.upper(),
                "ib_order_id": getattr(trade_overnight, "order", None).orderId if getattr(trade_overnight, "order", None) else None,
            })

        # Build message based on what was placed
        exchanges = []
        if order.place_day:
            exchanges.append("SMART")
        if order.place_overnight:
            exchanges.append("OVERNIGHT")
        message = f"Placed {order.buy_sell.upper()} {qty} {code} @ {price}"
        if len(exchanges) > 1:
            message += f" ({' + '.join(exchanges)})"
        elif len(exchanges) == 1:
            message += f" ({exchanges[0]})"

        return {
            "message": message,
            "orders": orders_placed,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("IB place_order_at_price unexpected error for %s: %s", order.stock_code, e)
        raise HTTPException(status_code=500, detail=f"Unexpected IB error: {e}")
    finally:
        try:
            ib.disconnect()
        except Exception:
            pass


@router.post("/place-orders")
def place_orders(batch: PlaceOrdersBatchRequest) -> Dict[str, Any]:
    ib, loop = _connect_ib()
    results: List[Dict[str, Any]] = []
    try:
        for i, o in enumerate(batch.orders, start=1):
            code = _normalize_us_symbol(o.stock_code)
            contract = _build_contract(code)
            ib.qualifyContracts(contract)
            ticker = ib.reqMktData(contract, "221,225,294,295", False, False)
            start = time.time()
            bid = getattr(ticker, "bid", float("nan"))
            ask = getattr(ticker, "ask", float("nan"))
            while (math.isnan(bid) or math.isnan(ask)) and (time.time() - start < 5.0):
                ib.sleep(0.25)
                bid = getattr(ticker, "bid", float("nan"))
                ask = getattr(ticker, "ask", float("nan"))
            mid = (bid + ask) / 2 if not math.isnan(bid) and not math.isnan(ask) else float("nan")
            px = ask if o.buy_sell.upper() == "BUY" else bid
            if px is None or math.isnan(px):
                px = mid
            if px is None or math.isnan(px):
                results.append({"index": i, "request": {"stock_code": code}, "ok": False, "error": "No market data"})
                continue
            price = _round_price_for_market(px, code)
            qty = int(math.floor(float(o.stock_dollar_amount) / price))
            if qty <= 0:
                results.append({"index": i, "request": {"stock_code": code}, "ok": False, "error": "Dollar amount too small"})
                continue
            lo = LimitOrder(o.buy_sell.upper(), qty, lmtPrice=price)
            lo.outsideRth = True
            lo.eTradeOnly = None
            lo.firmQuoteOnly = None
            trade = ib.placeOrder(contract, lo)
            results.append({
                "index": i,
                "ok": True,
                "order": {"stock_code": code, "qty": qty, "limit_price": price, "side": o.buy_sell.upper()},
                "ib_order_id": getattr(trade, "order", None).orderId if getattr(trade, "order", None) else None,
            })
            # Space out placements to avoid pacing or throttle issues
            ib.sleep(0.5)
        ok = all(bool(r.get("ok")) for r in results)
        return {"ok": ok, "results": results}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("IB place_orders unexpected error: %s", e)
        raise HTTPException(status_code=500, detail=f"Unexpected IB error: {e}")
    finally:
        try:
            ib.disconnect()
        except Exception:
            pass


@router.post("/place-orders-at-price")
def place_orders_at_price(batch: PlaceOrdersAtPriceBatchRequest) -> Dict[str, Any]:
    ib, loop = _connect_ib()
    results: List[Dict[str, Any]] = []

    # Validate at least one exchange is selected
    if not batch.place_day and not batch.place_overnight:
        raise HTTPException(status_code=400, detail="At least one of place_day or place_overnight must be true")

    try:
        for i, o in enumerate(batch.orders, start=1):
            code = _normalize_us_symbol(o.stock_code)
            price = float(o.limit_price)
            if price <= 0:
                results.append({"index": i, "request": {"stock_code": code}, "ok": False, "error": "Invalid limit_price"})
                continue

            qty = int(math.ceil(float(o.stock_dollar_amount) / price))
            if qty <= 0:
                results.append({"index": i, "request": {"stock_code": code}, "ok": False, "error": "Dollar amount too small"})
                continue

            orders_placed = []

            # Place SMART exchange order if requested
            if batch.place_day:
                try:
                    contract = _build_contract(code, overnight=False)
                    ib.qualifyContracts(contract)

                    # Check if bracket orders are enabled
                    use_bracket = (
                        batch.bracket_config is not None
                        and batch.bracket_config.enabled
                        and batch.bracket_config.take_profit_offset > 0
                        and batch.bracket_config.stop_loss_offset > 0
                    )

                    if use_bracket:
                        # Create and place bracket order (parent + TP + SL)
                        parent, tp_order, sl_order, tp_price, sl_price = _create_bracket_orders(
                            ib=ib,
                            action=o.buy_sell.upper(),
                            qty=qty,
                            entry_price=price,
                            tp_offset=batch.bracket_config.take_profit_offset,
                            sl_offset=batch.bracket_config.stop_loss_offset,
                            stock_code=code
                        )

                        # Place all three orders
                        parent_trade = ib.placeOrder(contract, parent)
                        tp_trade = ib.placeOrder(contract, tp_order)
                        sl_trade = ib.placeOrder(contract, sl_order)

                        exit_side = "SELL" if o.buy_sell.upper() == "BUY" else "BUY"
                        orders_placed.append({
                            "exchange": "SMART",
                            "order_type": "bracket",
                            "stock_code": code,
                            "parent": {
                                "ib_order_id": getattr(parent_trade, "order", None).orderId if getattr(parent_trade, "order", None) else None,
                                "side": o.buy_sell.upper(),
                                "qty": qty,
                                "limit_price": price,
                            },
                            "take_profit": {
                                "ib_order_id": getattr(tp_trade, "order", None).orderId if getattr(tp_trade, "order", None) else None,
                                "side": exit_side,
                                "qty": qty,
                                "limit_price": tp_price,
                            },
                            "stop_loss": {
                                "ib_order_id": getattr(sl_trade, "order", None).orderId if getattr(sl_trade, "order", None) else None,
                                "side": exit_side,
                                "qty": qty,
                                "stop_price": sl_price,
                            },
                        })
                    else:
                        # Place simple limit order (existing behavior)
                        lo = LimitOrder(o.buy_sell.upper(), qty, lmtPrice=price)
                        lo.outsideRth = True
                        try:
                            lo.tif = "DAY"
                        except Exception:
                            pass
                        lo.eTradeOnly = None
                        lo.firmQuoteOnly = None
                        trade = ib.placeOrder(contract, lo)
                        orders_placed.append({
                            "exchange": "SMART",
                            "stock_code": code,
                            "qty": qty,
                            "limit_price": price,
                            "side": o.buy_sell.upper(),
                            "ib_order_id": getattr(trade, "order", None).orderId if getattr(trade, "order", None) else None,
                        })
                except Exception as e:
                    logger.warning("Failed to place SMART order for %s: %s", code, e)
                    # Don't fail entire batch if day order fails, add error to this order
                    orders_placed.append({
                        "exchange": "SMART",
                        "stock_code": code,
                        "error": f"Failed: {e}"
                    })
                    # If day order fails and we're only placing day orders, mark this result as failed
                    if not batch.place_overnight:
                        results.append({"index": i, "request": {"stock_code": code}, "ok": False, "error": f"SMART order failed: {e}"})
                        continue

            # Place OVERNIGHT exchange order if requested
            if batch.place_overnight:
                try:
                    contract_overnight = _build_contract(code, overnight=True)
                    ib.qualifyContracts(contract_overnight)
                    lo_overnight = LimitOrder(o.buy_sell.upper(), qty, lmtPrice=price)
                    lo_overnight.outsideRth = True
                    try:
                        lo_overnight.tif = "DAY"
                    except Exception:
                        pass
                    lo_overnight.eTradeOnly = None
                    lo_overnight.firmQuoteOnly = None
                    trade_overnight = ib.placeOrder(contract_overnight, lo_overnight)
                    orders_placed.append({
                        "exchange": "OVERNIGHT",
                        "stock_code": code,
                        "qty": qty,
                        "limit_price": price,
                        "side": o.buy_sell.upper(),
                        "ib_order_id": getattr(trade_overnight, "order", None).orderId if getattr(trade_overnight, "order", None) else None,
                    })
                except Exception as e:
                    logger.warning("Failed to place OVERNIGHT order for %s: %s", code, e)
                    # Don't fail the entire operation if overnight order fails
                    orders_placed.append({
                        "exchange": "OVERNIGHT",
                        "stock_code": code,
                        "error": f"Failed: {e}"
                    })

            results.append({
                "index": i,
                "ok": True,
                "orders": orders_placed,
                "request": {"stock_code": code, "limit_price": price, "buy_sell": o.buy_sell.upper()},
            })

        ok = all(bool(r.get("ok")) for r in results)
        return {"ok": ok, "results": results}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("IB place_orders_at_price unexpected error: %s", e)
        raise HTTPException(status_code=500, detail=f"Unexpected IB error: {e}")
    finally:
        try:
            ib.disconnect()
        except Exception:
            pass


@router.get("/quote")
def get_quote(stock_code: str) -> Dict[str, Any]:
    """
    Return lightweight quote fields for a symbol. Does not raise on data gaps.
    Response: { ok, stock_code, last, close, bid, ask, mid }
    """
    code = _normalize_us_symbol(stock_code)
    try:
        ib, loop = _connect_ib()
        try:
            contract = _build_contract(code)
            ib.qualifyContracts(contract)
            # Request common generic ticks (221 Mark Price, 225 RT Volume, 294/295 Last/Auction)
            ticker = ib.reqMktData(contract, "221,225,294,295", False, False)
            start = time.time()
            # Wait briefly for any fields
            last = getattr(ticker, "last", float("nan"))
            close = getattr(ticker, "close", float("nan"))
            bid = getattr(ticker, "bid", float("nan"))
            ask = getattr(ticker, "ask", float("nan"))
            while (
                (math.isnan(last) and math.isnan(close) and math.isnan(bid) and math.isnan(ask))
                and (time.time() - start < 3.0)
            ):
                ib.sleep(0.2)
                last = getattr(ticker, "last", float("nan"))
                close = getattr(ticker, "close", float("nan"))
                bid = getattr(ticker, "bid", float("nan"))
                ask = getattr(ticker, "ask", float("nan"))

            def clean(x: float) -> float | None:
                return None if x is None or (isinstance(x, float) and (math.isnan(x) or math.isinf(x))) else float(x)

            last_c = clean(last)
            close_c = clean(close)
            bid_c = clean(bid)
            ask_c = clean(ask)
            mid_c = None
            if bid_c is not None and ask_c is not None:
                mid_c = round((bid_c + ask_c) / 2.0, 4)

            def r2(v: float | None) -> float | None:
                return None if v is None else round(v, 4)

            return {
                "ok": True,
                "stock_code": code,
                "last": r2(last_c),
                "close": r2(close_c),
                "bid": r2(bid_c),
                "ask": r2(ask_c),
                "mid": r2(mid_c),
            }
        finally:
            try:
                ib.disconnect()
            except Exception:
                pass
    except Exception as e:
        logger.warning("IB get_quote failed for %s: %s", code, e)
        return {"ok": False, "stock_code": code, "error": str(e), "last": None, "close": None, "bid": None, "ask": None, "mid": None}


@router.get("/position")
def get_position(stock_code: str) -> Dict[str, Any]:
    """
    Get the current position for a symbol from the IB account.
    Returns position size (positive for long, negative for short), average cost, and market value.
    """
    code = _normalize_us_symbol(stock_code)
    symbol_without_suffix = code.split(".")[0] if "." in code else code

    try:
        ib, loop = _connect_ib()
        try:
            # Request portfolio positions
            ib.reqPositions()
            # Give IB time to send positions
            ib.sleep(1.0)

            positions = ib.positions()
            logger.info("Found %d total positions in account", len(positions))

            # Find position for the requested symbol
            matching_position = None
            for pos in positions:
                pos_symbol = getattr(pos.contract, "symbol", "").upper()
                if pos_symbol == symbol_without_suffix.upper():
                    matching_position = pos
                    break

            if matching_position is None:
                return {
                    "ok": True,
                    "stock_code": code,
                    "position": 0,
                    "avg_cost": None,
                    "market_value": None,
                    "unrealized_pnl": None,
                    "message": f"No position found for {code}",
                }

            # Extract position details
            position_size = float(matching_position.position)  # Positive for long, negative for short
            avg_cost = float(matching_position.avgCost) if matching_position.avgCost else None

            # Try to get market value from portfolio items
            market_value = None
            unrealized_pnl = None
            try:
                portfolio = ib.portfolio()
                for item in portfolio:
                    item_symbol = getattr(item.contract, "symbol", "").upper()
                    if item_symbol == symbol_without_suffix.upper():
                        market_value = float(item.marketValue) if item.marketValue else None
                        unrealized_pnl = float(item.unrealizedPNL) if item.unrealizedPNL else None
                        break
            except Exception as e:
                logger.warning("Failed to get portfolio details for %s: %s", code, e)

            return {
                "ok": True,
                "stock_code": code,
                "position": position_size,
                "avg_cost": avg_cost,
                "market_value": market_value,
                "unrealized_pnl": unrealized_pnl,
                "position_type": "long" if position_size > 0 else "short" if position_size < 0 else "flat",
            }
        finally:
            try:
                ib.disconnect()
            except Exception:
                pass
    except Exception as e:
        logger.warning("IB get_position failed for %s: %s", code, e)
        return {"ok": False, "stock_code": code, "error": str(e), "position": None}


@router.get("/ping")
def ping() -> Dict[str, Any]:
    """Attempt to connect to IB using configured host/port(s) and report result quickly."""
    host = (settings.ibg_api_host or "127.0.0.1").strip() or "127.0.0.1"
    port_cfg = int(settings.ibg_api_port or 0)
    candidate_ports = [port_cfg] if port_cfg > 0 else [4002, 4001, 7497, 7496]
    details: List[Dict[str, Any]] = []

    # First, try raw TCP reachability to distinguish network vs API handshake
    import socket

    if IB is None:
        details_list: List[Dict[str, Any]] = []
        for p in candidate_ports:
            details_list.append({"port": p, "tcp_ok": _try_tcp(host, p)})
        return {
            "ok": False,
            "error": "ib_insync not installed",
            "host": host,
            "ports_tried": candidate_ports,
            "details": details_list,
        }

    def tcp_check(h: str, p: int) -> bool:
        try:
            with socket.create_connection((h, p), timeout=3.0):
                return True
        except Exception as e:
            logger.warning("IB: TCP connect failed to %s:%s - %s", h, p, e)
            return False

    any_ok = False
    for p in candidate_ports:
        tcp_ok = tcp_check(host, p)
        ib_ok = False
        error: str | None = None
        if tcp_ok:
            # Create a fresh loop per attempt in this thread
            try:
                loop = asyncio.get_event_loop()
            except RuntimeError:
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
            ib = IB()
            try:
                ib.connect(host, p, clientId=random.randint(10000, 50000), timeout=10)
                ib_ok = True
                any_ok = True
            except Exception as e:
                error = f"{type(e).__name__}: {e}"
                logger.warning("IB: API connect failed to %s:%s - %s", host, p, error)
            finally:
                try:
                    ib.disconnect()
                except Exception:
                    pass
        details.append({"port": p, "tcp_ok": tcp_ok, "ib_ok": ib_ok, "error": error})
        if ib_ok:
            break

    return {
        "ok": any_ok,
        "host": host,
        "ports_tried": [d["port"] for d in details],
        "details": details,
    }


def _try_tcp(host: str, port: int) -> bool:
    import socket as _socket
    try:
        with _socket.create_connection((host, port), timeout=2.0):
            return True
    except Exception:
        return False


@router.post("/cancel-all-orders-for-stock")
def cancel_all_orders_for_stock(stock_code: str, side: str = None) -> Dict[str, Any]:
    """
    Cancel all open orders (SMART and OVERNIGHT) for a given stock symbol.
    Optionally filter by side (BUY or SELL).
    """
    logger.info("Cancel request: stock_code=%s, side=%s", stock_code, side)
    ib, loop = _connect_ib()
    try:
        code = _normalize_us_symbol(stock_code)

        # Validate side parameter if provided
        if side:
            side_upper = side.strip().upper()
            if side_upper not in ("BUY", "SELL"):
                raise HTTPException(status_code=400, detail="side must be BUY or SELL")
        else:
            side_upper = None

        # Get all open trades with timeout protection
        logger.info("Fetching open trades...")
        try:
            # Request open orders from this client (we can only cancel our own orders)
            # Note: We use a fixed clientId=12345, so this will only return orders placed with that clientId
            ib.reqOpenOrders()
            # Give IB time to send the open orders
            ib.sleep(1.0)
            open_trades = ib.openTrades()
            logger.info("Found %d open trades total", len(open_trades))
        except Exception as e:
            logger.error("Failed to fetch open trades: %s", e)
            raise HTTPException(status_code=500, detail=f"Failed to fetch open trades: {e}")

        # Filter trades for this stock (check both SMART and OVERNIGHT exchanges)
        symbol_without_suffix = code.split(".")[0] if "." in code else code
        logger.info("Filtering for symbol: %s", symbol_without_suffix)

        # Debug: log all open trade symbols
        for t in open_trades:
            if hasattr(t.contract, "symbol"):
                logger.info("Open trade symbol: %s (exchange: %s, action: %s)",
                           t.contract.symbol,
                           getattr(t.contract, "exchange", "?"),
                           getattr(t.order, "action", "?") if hasattr(t, "order") else "?")

        matching_trades = [
            t for t in open_trades
            if hasattr(t.contract, "symbol") and t.contract.symbol.upper() == symbol_without_suffix.upper()
        ]
        logger.info("Found %d trades for %s", len(matching_trades), symbol_without_suffix)

        # Further filter by side if specified
        if side_upper:
            matching_trades = [
                t for t in matching_trades
                if hasattr(t.order, "action") and t.order.action.upper() == side_upper
            ]
            logger.info("After filtering by %s: %d trades", side_upper, len(matching_trades))

        if not matching_trades:
            side_msg = f" {side_upper}" if side_upper else ""
            # Debug info: include all open trade symbols in the response
            debug_trades = [
                {
                    "symbol": t.contract.symbol if hasattr(t.contract, "symbol") else "?",
                    "exchange": getattr(t.contract, "exchange", "?"),
                    "action": getattr(t.order, "action", "?") if hasattr(t, "order") else "?"
                }
                for t in open_trades[:10]  # Limit to first 10 for brevity
            ]
            return {
                "ok": True,
                "message": f"No open{side_msg} orders found for {code}",
                "cancelled_count": 0,
                "orders": [],
                "debug": {
                    "total_open_trades": len(open_trades),
                    "searched_for": symbol_without_suffix,
                    "side_filter": side_upper,
                    "sample_trades": debug_trades
                }
            }

        # Cancel each matching order
        cancelled_orders = []
        for trade in matching_trades:
            try:
                logger.info("Cancelling order ID %s for %s", trade.order.orderId, code)
                ib.cancelOrder(trade.order)
                # Wait for cancellation to be processed
                ib.sleep(0.1)
                cancelled_orders.append({
                    "order_id": trade.order.orderId,
                    "symbol": trade.contract.symbol,
                    "exchange": trade.contract.exchange,
                    "side": trade.order.action,
                    "qty": trade.order.totalQuantity,
                    "limit_price": getattr(trade.order, "lmtPrice", None),
                    "status": "cancelled"
                })
            except Exception as e:
                logger.warning("Failed to cancel order %s for %s: %s", trade.order.orderId, code, e)
                cancelled_orders.append({
                    "order_id": trade.order.orderId,
                    "symbol": trade.contract.symbol,
                    "exchange": trade.contract.exchange,
                    "status": "failed",
                    "error": str(e)
                })

        side_msg = f" {side_upper}" if side_upper else ""
        return {
            "ok": True,
            "message": f"Cancelled {len(cancelled_orders)}{side_msg} orders for {code}",
            "cancelled_count": len(cancelled_orders),
            "orders": cancelled_orders
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("IB cancel_all_orders_for_stock unexpected error for %s: %s", stock_code, e)
        raise HTTPException(status_code=500, detail=f"Unexpected IB error: {e}")
    finally:
        try:
            ib.disconnect()
        except Exception:
            pass


