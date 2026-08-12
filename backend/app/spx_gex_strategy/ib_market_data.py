from __future__ import annotations

import asyncio
import logging
import math
import os
import random
import time
from datetime import date, datetime, timezone
from typing import Any, Optional
from zoneinfo import ZoneInfo

from .calendar import NEW_YORK

try:
    from ib_insync import ContFuture, IB, Stock  # type: ignore
except Exception:  # pragma: no cover - IB is optional for offline backtests.
    ContFuture = None  # type: ignore
    IB = None  # type: ignore
    Stock = None  # type: ignore

logger = logging.getLogger("app.spx_gex_strategy.ib_market_data")


def _positive(value: Any) -> float | None:
    try:
        result = float(value)
    except (TypeError, ValueError):
        return None
    return result if math.isfinite(result) and result > 0 else None


def _connect_ib() -> IB:
    if IB is None:
        raise RuntimeError("ib_insync is not installed on the backend")
    try:
        asyncio.get_event_loop()
    except RuntimeError:
        asyncio.set_event_loop(asyncio.new_event_loop())

    host = (getattr(_settings(), "ibg_api_host", None) or os.getenv("IB_SERVER") or "127.0.0.1").strip()
    configured_port = int(getattr(_settings(), "ibg_api_port", None) or os.getenv("PORT_NUMBER") or 0)
    ports = [configured_port] if configured_port > 0 else []
    for port in (4002, 4001, 7496, 7497):
        if port not in ports:
            ports.append(port)
    last_error: Exception | None = None
    ib = IB()
    for port in ports:
        try:
            ib.connect(
                host,
                port,
                clientId=int(os.getenv("IB_CLIENT_ID", random.randint(70001, 73000))),
                timeout=float(os.getenv("IB_REQUEST_TIMEOUT", "10")),
                readonly=True,
            )
            logger.info("SPX GEX NQ: connected to IB at %s:%s", host, port)
            return ib
        except Exception as exc:
            last_error = exc
    raise RuntimeError(f"Unable to connect to IB at {host}:{ports}: {last_error}")


def _settings() -> Any:
    from app.core.config import settings

    return settings


def _ticker_price(ticker: Any) -> float | None:
    last = _positive(getattr(ticker, "last", None))
    if last is not None:
        return last
    bid = _positive(getattr(ticker, "bid", None))
    ask = _positive(getattr(ticker, "ask", None))
    if bid is not None and ask is not None and ask >= bid:
        return (bid + ask) / 2.0
    return bid or ask or _positive(getattr(ticker, "close", None))


def _bar_local_date(value: Any) -> date | None:
    if isinstance(value, datetime):
        timestamp = value
    else:
        try:
            timestamp = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        except (TypeError, ValueError):
            return None
    if timestamp.tzinfo is None:
        timestamp = timestamp.replace(tzinfo=NEW_YORK)
    return timestamp.astimezone(NEW_YORK).date()


def _bar_timestamp(value: Any) -> datetime | None:
    """Parse the timestamp formats returned by IB historical bars."""
    if isinstance(value, datetime):
        timestamp = value
    else:
        text = str(value or "").strip()
        timestamp = None
        for candidate in (text.replace("Z", "+00:00"),):
            try:
                timestamp = datetime.fromisoformat(candidate)
                break
            except ValueError:
                pass
        if timestamp is None:
            for fmt in ("%Y%m%d %H:%M:%S", "%Y-%m-%d %H:%M:%S"):
                try:
                    timestamp = datetime.strptime(text, fmt)
                    break
                except ValueError:
                    pass
        if timestamp is None:
            return None
    if timestamp.tzinfo is None:
        timestamp = timestamp.replace(tzinfo=NEW_YORK)
    return timestamp.astimezone(NEW_YORK)


def get_live_nq_snapshot(wait_seconds: float = 3.0) -> dict[str, Any]:
    """Get IB's rolling NQ front contract and move versus yesterday's close.

    NQMAIN is a database name, not an IB contract. The collector used by this
    repo resolves it with IB's CONTFUT contract, so this adapter does the same.
    """
    if ContFuture is None:
        raise RuntimeError("ib_insync ContFuture is unavailable on the backend")

    settings = _settings()
    symbol = str(getattr(settings, "ib_nq_symbol", None) or "NQ").strip().upper()
    exchange = str(getattr(settings, "ib_nq_exchange", None) or "CME").strip().upper()
    currency = str(getattr(settings, "ib_nq_currency", None) or "USD").strip().upper()
    market_data_type = int(getattr(settings, "ib_market_data_type", None) or os.getenv("MARKET_DATA_TYPE", "1"))
    ib = _connect_ib()
    contract = None
    try:
        contract = ContFuture(symbol=symbol, exchange=exchange, currency=currency)
        qualified = ib.qualifyContracts(contract)
        if not qualified:
            raise RuntimeError(f"IB could not qualify continuous {symbol} future on {exchange}")
        contract = qualified[0]
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
        current_price = _ticker_price(ticker)
        if current_price is None:
            raise RuntimeError("IB returned no usable NQ price")

        previous_close = None
        history = ib.reqHistoricalData(
            contract,
            endDateTime="",
            durationStr="3 D",
            barSizeSetting="1 day",
            whatToShow="TRADES",
            useRTH=False,
            formatDate=2,
            keepUpToDate=False,
        )
        today = datetime.now(NEW_YORK).date()
        completed = [
            bar for bar in history
            if (_bar_local_date(getattr(bar, "date", None)) or today) < today
            and _positive(getattr(bar, "close", None)) is not None
        ]
        if completed:
            previous_close = _positive(getattr(completed[-1], "close", None))
        if previous_close is None:
            previous_close = _positive(getattr(ticker, "close", None))
        if previous_close is None:
            raise RuntimeError("IB returned no usable prior NQ session close")

        move_fraction = current_price / previous_close - 1.0
        actual_data_type = getattr(ticker, "marketDataType", None)
        return {
            "symbol": "NQMAIN",
            "ib_symbol": symbol,
            "contract": getattr(contract, "localSymbol", None) or getattr(contract, "symbol", symbol),
            "exchange": exchange,
            "price": round(current_price, 4),
            "previous_close": round(previous_close, 4),
            "move_fraction": move_fraction,
            "move_pct": move_fraction * 100.0,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "source": "ib_live" if actual_data_type == 1 else "ib_delayed",
            "market_data_type": actual_data_type if actual_data_type in {1, 2, 3, 4} else market_data_type,
        }
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


def get_live_qqq_snapshot(wait_seconds: float = 3.0) -> dict[str, Any]:
    """Get an actual QQQ quote for live sizing and order levels.

    NQMAIN is intentionally not used here. The historical strategy can use
    NQ's percentage path as a proxy, but a live QQQ notification must size and
    price the QQQ order from the QQQ quote itself.
    """
    if Stock is None:
        raise RuntimeError("ib_insync Stock is unavailable on the backend")

    settings = _settings()
    market_data_type = int(getattr(settings, "ib_market_data_type", None) or os.getenv("MARKET_DATA_TYPE", "1"))
    ib = _connect_ib()
    contract = None
    try:
        contract = Stock("QQQ", "SMART", "USD")
        qualified = ib.qualifyContracts(contract)
        if not qualified:
            raise RuntimeError("IB could not qualify QQQ on SMART/USD")
        contract = qualified[0]
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
        current_price = _ticker_price(ticker)
        if current_price is None:
            raise RuntimeError("IB returned no usable QQQ price")

        previous_close = _positive(getattr(ticker, "close", None))
        history = ib.reqHistoricalData(
            contract,
            endDateTime="",
            durationStr="3 D",
            barSizeSetting="1 day",
            whatToShow="TRADES",
            useRTH=True,
            formatDate=2,
            keepUpToDate=False,
        )
        today = datetime.now(NEW_YORK).date()
        completed = [
            bar for bar in history
            if (_bar_local_date(getattr(bar, "date", None)) or today) < today
            and _positive(getattr(bar, "close", None)) is not None
        ]
        if completed:
            previous_close = _positive(getattr(completed[-1], "close", None))
        move_fraction = current_price / previous_close - 1.0 if previous_close else None
        actual_data_type = getattr(ticker, "marketDataType", None)
        return {
            "symbol": "QQQ",
            "price": round(current_price, 4),
            "previous_close": round(previous_close, 4) if previous_close else None,
            "move_fraction": move_fraction,
            "move_pct": move_fraction * 100.0 if move_fraction is not None else None,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "source": "ib_live" if actual_data_type == 1 else "ib_delayed",
            "market_data_type": actual_data_type if actual_data_type in {1, 2, 3, 4} else market_data_type,
        }
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


def get_qqq_reference_snapshot(
    actionable_at: datetime,
    now: datetime | None = None,
    wait_seconds: float = 3.0,
) -> dict[str, Any]:
    """Return the QQQ price appropriate for a signal's 03:30 ET boundary.

    Before the boundary, the current IB quote is the only actionable price.
    At or after the boundary, deliberately request the exact 03:30 one-minute
    historical bar instead of using a later quote.  A caller can treat an
    exception or a missing bar as an unavailable reference and display N/A.
    """
    boundary = actionable_at
    if boundary.tzinfo is None:
        boundary = boundary.replace(tzinfo=NEW_YORK)
    boundary = boundary.astimezone(NEW_YORK)
    current_time = (now or datetime.now(NEW_YORK))
    if current_time.tzinfo is None:
        current_time = current_time.replace(tzinfo=NEW_YORK)
    current_time = current_time.astimezone(NEW_YORK)

    if current_time < boundary:
        snapshot = get_live_qqq_snapshot(wait_seconds)
        price = _positive(snapshot.get("price"))
        if price is None:
            raise RuntimeError("IB returned no usable QQQ reference price")
        return {
            **snapshot,
            "reference_price": round(price, 4),
            "reference_timestamp": snapshot.get("timestamp"),
            "reference_source": "IB_LIVE_BEFORE_03:30",
            "reference_rule": "Current IB QQQ quote captured before the 03:30 New York action boundary",
        }

    if Stock is None:
        raise RuntimeError("ib_insync Stock is unavailable on the backend")

    settings = _settings()
    market_data_type = int(getattr(settings, "ib_market_data_type", None) or os.getenv("MARKET_DATA_TYPE", "1"))
    ib = _connect_ib()
    contract = None
    try:
        contract = Stock("QQQ", "SMART", "USD")
        qualified = ib.qualifyContracts(contract)
        if not qualified:
            raise RuntimeError("IB could not qualify QQQ on SMART/USD")
        contract = qualified[0]
        try:
            ib.reqMarketDataType(market_data_type)
        except Exception:
            pass
        bars = ib.reqHistoricalData(
            contract,
            endDateTime=boundary.strftime("%Y%m%d %H:%M:%S US/Eastern"),
            durationStr="1 D",
            barSizeSetting="1 min",
            whatToShow="TRADES",
            useRTH=False,
            formatDate=2,
            keepUpToDate=False,
        )
        target = None
        for bar in bars:
            timestamp = _bar_timestamp(getattr(bar, "date", None))
            if timestamp is None or timestamp != boundary.replace(second=0, microsecond=0):
                continue
            target = bar
            break
        if target is None:
            raise RuntimeError(f"IB returned no QQQ bar at {boundary.isoformat()}")
        price = _positive(getattr(target, "open", None))
        if price is None:
            raise RuntimeError(f"IB returned no usable QQQ open at {boundary.isoformat()}")
        return {
            "symbol": "QQQ",
            "price": round(price, 4),
            "reference_price": round(price, 4),
            "reference_timestamp": boundary.isoformat(),
            "reference_source": "IB_HISTORICAL_03:30",
            "reference_rule": "Exact QQQ 03:30 New York one-minute bar open",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "source": "ib_historical",
            "market_data_type": market_data_type,
        }
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
