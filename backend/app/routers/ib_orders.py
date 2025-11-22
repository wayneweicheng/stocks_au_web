from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, field_validator
from typing import List, Dict, Any
from .auth import verify_credentials
from app.core.config import settings
import math
import random
import time
import logging
import asyncio

try:
    from ib_insync import IB, Stock, LimitOrder  # type: ignore
except Exception:  # pragma: no cover
    IB = None  # type: ignore
    Stock = None  # type: ignore
    LimitOrder = None  # type: ignore


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


class PlaceOrdersAtPriceBatchRequest(BaseModel):
    orders: List[PlaceOrderAtPriceRequest]

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
    for p in candidate_ports:
        try:
            ib.connect(host, p, clientId=random.randint(10000, 50000), timeout=30)
            logger.info("IB: connected to %s:%s", host, p)
            return ib, loop
        except Exception as e:
            last_err = e
            logger.warning("IB: failed connect to %s:%s - %s", host, p, e)
            continue
    raise HTTPException(status_code=502, detail=f"Failed to connect to IB API at {host}:{candidate_ports} ({last_err})")


def _build_contract(stock_code: str):
    sym = (stock_code or "").strip().upper()
    if "." in sym:
        symbol_part, suffix = sym.split(".", 1)
        if suffix == "US":
            return Stock(symbol_part, "SMART", "USD")
        if suffix == "AX":
            return Stock(symbol_part, "ASX", "AUD")
        # Default for unknown suffix
        return Stock(symbol_part, "SMART", "USD")
    # Assume US if no suffix
    return Stock(sym, "SMART", "USD")


def _round_price_for_market(price: float, stock_code: str) -> float:
    # Simple tick rounding: default to 0.01 for equities; adjust by market if needed
    tick = 0.01
    sc = (stock_code or "").upper()
    if sc.endswith(".AX"):
        tick = 0.01
    return round(max(0.0, float(price)), 2 if tick == 0.01 else 4)


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
        qty = int(math.floor(float(order.stock_dollar_amount) / price))
        if qty <= 0:
            raise HTTPException(status_code=400, detail="Dollar amount too small for 1 share at current price")

        lo = LimitOrder(order.buy_sell.upper(), qty, lmtPrice=price)
        lo.outsideRth = True
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
        contract = _build_contract(code)
        ib.qualifyContracts(contract)

        price = float(order.limit_price)
        if price <= 0:
            raise HTTPException(status_code=400, detail="limit_price must be > 0")

        qty = int(math.floor(float(order.stock_dollar_amount) / price))
        if qty <= 0:
            raise HTTPException(status_code=400, detail="Dollar amount too small for 1 share at provided price")

        lo = LimitOrder(order.buy_sell.upper(), qty, lmtPrice=price)
        lo.outsideRth = True
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
            ib.sleep(0.05)
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
    try:
        for i, o in enumerate(batch.orders, start=1):
            code = _normalize_us_symbol(o.stock_code)
            contract = _build_contract(code)
            ib.qualifyContracts(contract)

            price = float(o.limit_price)
            if price <= 0:
                results.append({"index": i, "request": {"stock_code": code}, "ok": False, "error": "Invalid limit_price"})
                continue

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
            ib.sleep(0.05)
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
@router.get("/ping")
def ping() -> Dict[str, Any]:
    """Attempt to connect to IB using configured host/port(s) and report result quickly."""
    host = (settings.ibg_api_host or "127.0.0.1").strip() or "127.0.0.1"
    port_cfg = int(settings.ibg_api_port or 0)
    candidate_ports = [port_cfg] if port_cfg > 0 else [4002, 4001, 7497, 7496]
    details: list[Dict[str, Any]] = []

    # First, try raw TCP reachability to distinguish network vs API handshake
    import socket

    if IB is None:
        details_list: list[Dict[str, Any]] = []
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


