from __future__ import annotations

import asyncio
import logging
import math
import random
import time
from typing import Any, Dict, Iterable, List, Optional

from app.core.config import settings

try:
    from ib_insync import IB, Index, Stock  # type: ignore
except Exception:  # pragma: no cover
    IB = None  # type: ignore
    Index = None  # type: ignore
    Stock = None  # type: ignore


logger = logging.getLogger("app.live_stock_price_service")


def _positive_price(value: Any) -> Optional[float]:
    try:
        price = float(value)
    except (TypeError, ValueError):
        return None
    if not math.isfinite(price) or price <= 0:
        return None
    return price


def _volatility(value: Any) -> Optional[float]:
    try:
        volatility = float(value)
    except (TypeError, ValueError):
        return None
    if not math.isfinite(volatility) or volatility <= 0:
        return None
    return volatility


def _base_symbol(symbol: str) -> str:
    return (symbol or "").strip().upper().split(".", 1)[0]


def _connect_ib() -> "IB":
    if IB is None:
        raise RuntimeError("ib_insync is not installed on the backend")

    try:
        asyncio.get_event_loop()
    except RuntimeError:
        asyncio.set_event_loop(asyncio.new_event_loop())

    ib = IB()
    host = (settings.ibg_api_host or "127.0.0.1").strip() or "127.0.0.1"
    configured_port = int(settings.ibg_api_port or 0)
    ports: List[int] = []
    if configured_port > 0:
        ports.append(configured_port)
    for port in [4002, 4001, 7496, 7497]:
        if port not in ports:
            ports.append(port)

    last_error: Optional[Exception] = None
    client_id = random.randint(76001, 79000)
    for port in ports:
        try:
            ib.connect(host, port, clientId=client_id, timeout=3)
            return ib
        except Exception as exc:
            last_error = exc
            logger.warning("Live prices: failed to connect to %s:%s - %s", host, port, exc)

    raise RuntimeError(f"Failed to connect to IB API at {host}:{ports} ({last_error})")


def _ticker_price(ticker: Any) -> Optional[float]:
    last = _positive_price(getattr(ticker, "last", None))
    if last is not None:
        return last

    bid = _positive_price(getattr(ticker, "bid", None))
    ask = _positive_price(getattr(ticker, "ask", None))
    if bid is not None and ask is not None and ask >= bid:
        return (bid + ask) / 2.0
    if bid is not None or ask is not None:
        return bid or ask

    close = _positive_price(getattr(ticker, "close", None))
    return close


def get_live_index_price(
    symbol: str,
    exchange: str = "CBOE",
    currency: str = "USD",
    wait_seconds: float = 3.0,
) -> Optional[Dict[str, Any]]:
    if Index is None:
        raise RuntimeError("ib_insync index contracts are unavailable on the backend")

    ib = _connect_ib()
    contract = None
    try:
        contract = Index(symbol.strip().upper(), exchange, currency)
        qualified = ib.qualifyContracts(contract)
        if not qualified:
            return None
        contract = qualified[0]

        for market_data_type, source in [(1, "ib_live"), (3, "ib_delayed")]:
            try:
                ib.reqMarketDataType(market_data_type)
            except Exception:
                pass

            ticker = ib.reqMktData(contract, "221,225", False, False)
            deadline = time.time() + wait_seconds
            while time.time() < deadline:
                ib.sleep(0.2)
                if _ticker_price(ticker) is not None:
                    break

            price = _ticker_price(ticker)
            try:
                ib.cancelMktData(contract)
            except Exception:
                pass
            contract = None
            if price is None:
                continue

            actual_type = getattr(ticker, "marketDataType", None)
            return {
                "price": round(price, 4),
                "source": "ib_live" if actual_type == 1 else (
                    "ib_delayed" if actual_type in {2, 3, 4} else source
                ),
                "market_data_type": (
                    int(actual_type) if actual_type in {1, 2, 3, 4} else market_data_type
                ),
            }
        return None
    finally:
        if contract is not None:
            try:
                ib.cancelMktData(contract)
            except Exception:
                pass
        try:
            ib.disconnect()
        except Exception:
            pass


def get_live_stock_prices(stock_codes: Iterable[str], wait_seconds: float = 3.0) -> Dict[str, Dict[str, Any]]:
    codes = list(dict.fromkeys(str(code).strip().upper() for code in stock_codes if str(code).strip()))
    if not codes:
        return {}

    ib = _connect_ib()
    subscriptions: List[Any] = []
    try:
        contracts = [Stock(_base_symbol(code), "SMART", "USD") for code in codes]
        qualified = ib.qualifyContracts(*contracts)
        contracts_by_symbol = {
            _base_symbol(getattr(contract, "symbol", "")): contract
            for contract in qualified
            if _base_symbol(getattr(contract, "symbol", ""))
        }

        results: Dict[str, Dict[str, Any]] = {}
        remaining = set(codes)
        for market_data_type, source in [(1, "ib_live"), (3, "ib_delayed")]:
            if not remaining:
                break
            try:
                ib.reqMarketDataType(market_data_type)
            except Exception:
                pass

            active: Dict[str, Any] = {}
            for code in remaining:
                contract = contracts_by_symbol.get(_base_symbol(code))
                if contract is None:
                    continue
                ticker = ib.reqMktData(contract, "104,106,221,225,294,295", False, False)
                subscriptions.append(contract)
                active[code] = ticker

            deadline = time.time() + wait_seconds
            while time.time() < deadline:
                ib.sleep(0.2)
                if active and all(
                    _ticker_price(ticker) is not None
                    and (
                        _volatility(getattr(ticker, "impliedVolatility", None)) is not None
                        or _volatility(getattr(ticker, "histVolatility", None)) is not None
                    )
                    for ticker in active.values()
                ):
                    break

            for code, ticker in active.items():
                price = _ticker_price(ticker)
                if price is None:
                    continue
                actual_type = getattr(ticker, "marketDataType", None)
                results[code] = {
                    "price": round(price, 4),
                    "source": "ib_live" if actual_type == 1 else (
                        "ib_delayed" if actual_type in {2, 3, 4} else source
                    ),
                    "market_data_type": int(actual_type) if actual_type in {1, 2, 3, 4} else market_data_type,
                    "implied_volatility": _volatility(
                        getattr(ticker, "impliedVolatility", None)
                    ),
                    "historical_volatility": _volatility(
                        getattr(ticker, "histVolatility", None)
                    ),
                }
                remaining.discard(code)

        return results
    finally:
        for contract in subscriptions:
            try:
                ib.cancelMktData(contract)
            except Exception:
                pass
        try:
            ib.disconnect()
        except Exception:
            pass
