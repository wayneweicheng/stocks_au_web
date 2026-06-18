from __future__ import annotations

import asyncio
import logging
import math
import random
import time
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from math import erf, exp, log, sqrt
from typing import Any, Dict, List, Optional

from app.core.config import settings
from app.core.db import get_sql_model

try:
    from ib_insync import IB, Stock, Option  # type: ignore
except Exception:  # pragma: no cover
    IB = None  # type: ignore
    Stock = None  # type: ignore
    Option = None  # type: ignore


logger = logging.getLogger("app.option_orders_service")

RISK_FREE_RATE = 0.045
DOWN_MOVE_IV_EXPANSION = 0.02
UP_MOVE_IV_CRUSH = -0.01
MAX_IV_SHIFT = 0.10
MAX_UNDERLYING_IV_ADJUSTMENT = 0.03
UNDERLYING_IV_ADJUSTMENT_WEIGHT = 0.25
DEFAULT_FALLBACK_IV = 0.35


@dataclass
class OptionQuote:
    bid: Optional[float]
    ask: Optional[float]
    last: Optional[float]
    close: Optional[float]
    mid: Optional[float]
    iv: Optional[float]
    delta: Optional[float]
    gamma: Optional[float]
    theta: Optional[float]
    vega: Optional[float]
    market_data_type: Optional[int] = None
    volume: Optional[int] = None


def _normalize_iv(value: Any) -> Optional[float]:
    iv = _clean(value)
    if iv is None or iv <= 0:
        return None
    normalized = iv / 100.0 if iv > 3 else iv
    return normalized if 0.01 <= normalized <= 5.0 else None


def _spread_pct(bid: Optional[float], ask: Optional[float]) -> Optional[float]:
    if bid is None or ask is None or bid <= 0 or ask < bid:
        return None
    return round((ask - bid) * 100.0 / bid, 2)


def _nth_weekday(year: int, month: int, weekday: int, n: int) -> date:
    current = date(year, month, 1)
    offset = (weekday - current.weekday()) % 7
    return current + timedelta(days=offset + (n - 1) * 7)


def _us_eastern_offset_hours(moment_utc: datetime) -> int:
    dst_start = _nth_weekday(moment_utc.year, 3, 6, 2)
    dst_end = _nth_weekday(moment_utc.year, 11, 6, 1)
    current_day = moment_utc.date()
    return -4 if dst_start <= current_day < dst_end else -5


def _now_us_eastern(now: Optional[datetime] = None) -> datetime:
    current = now or datetime.utcnow().replace(tzinfo=timezone.utc)
    if current.tzinfo is None:
        current = current.replace(tzinfo=timezone.utc)
    current_utc = current.astimezone(timezone.utc)
    offset = timezone(timedelta(hours=_us_eastern_offset_hours(current_utc)))
    return current_utc.astimezone(offset)


def _today_us_market_date(now: Optional[datetime] = None) -> date:
    return _now_us_eastern(now).date()


def _market_status_from_context(
    market_data_type: Optional[int],
    now: Optional[datetime] = None,
) -> Dict[str, Any]:
    eastern_now = _now_us_eastern(now)
    minutes_since_midnight = eastern_now.hour * 60 + eastern_now.minute
    regular_open = 9 * 60 + 30
    regular_close = 16 * 60
    in_regular_session = (
        eastern_now.weekday() < 5
        and regular_open <= minutes_since_midnight < regular_close
    )
    realtime = market_data_type == 1
    is_live_market = bool(in_regular_session and realtime)

    if is_live_market:
        detail = "IB is returning real-time quotes during regular US market hours."
    elif not in_regular_session:
        detail = "Outside regular US market hours; using delayed/database quotes where live bid/ask is unavailable."
    elif market_data_type is None:
        detail = "IB market data type is unavailable; using delayed/database quotes where live bid/ask is unavailable."
    else:
        detail = "IB is not returning real-time market data; using delayed/database quotes where live bid/ask is unavailable."

    return {
        "label": "Live Market" if is_live_market else "Market Not Live",
        "is_live_market": is_live_market,
        "detail": detail,
        "market_data_type": market_data_type,
        "regular_session": in_regular_session,
        "checked_at": eastern_now.isoformat(),
        "timezone": "America/New_York",
    }


def _option_quote_to_payload(quote: Optional[OptionQuote]) -> Optional[Dict[str, Any]]:
    if quote is None:
        return None
    bid = _round(quote.bid)
    ask = _round(quote.ask)
    mid = _round(quote.mid if quote.mid is not None else ((quote.bid + quote.ask) / 2.0 if quote.bid is not None and quote.ask is not None else None))
    if bid is None and ask is None and mid is None and quote.iv is None and quote.volume is None:
        return None
    return {
        "bid": bid,
        "ask": ask,
        "mid": mid,
        "spread_pct": _spread_pct(quote.bid, quote.ask),
        "volume": quote.volume,
        "iv": _round(quote.iv, 6),
        "observation_date": "",
        "source": "live" if quote.market_data_type == 1 else "ib",
        "market_data_type": quote.market_data_type,
    }


def _merge_option_quote(
    delayed_quote: Optional[Dict[str, Any]],
    live_quote: Optional[OptionQuote],
    prefer_live: bool,
) -> Optional[Dict[str, Any]]:
    database_payload = dict(delayed_quote or {})
    if database_payload and "source" not in database_payload:
        database_payload["source"] = "database"

    live_payload = _option_quote_to_payload(live_quote)
    if not prefer_live or live_payload is None:
        return database_payload or live_payload

    merged = dict(database_payload)
    for key in ("bid", "ask", "mid", "spread_pct", "iv"):
        value = live_payload.get(key)
        if value is not None:
            merged[key] = value
    if live_payload.get("volume") is not None:
        merged["volume"] = live_payload["volume"]
    elif "volume" not in merged:
        merged["volume"] = None
    live_price_present = any(live_payload.get(key) is not None for key in ("bid", "ask", "mid"))
    if live_price_present:
        merged["source"] = "live"
        merged["market_data_type"] = live_payload.get("market_data_type")
    elif database_payload:
        merged["source"] = database_payload.get("source", "database")
        merged["market_data_type"] = database_payload.get("market_data_type")
    return merged


def _latest_delayed_quotes(symbol: str, expiry: str) -> Dict[str, Dict[str, Any]]:
    model = get_sql_model()
    db_symbol = f"{_base_symbol(symbol)}.US"
    expiry_date = _expiry_date(expiry).isoformat()
    rows = model.execute_read_query(
        """
        WITH LatestQuotes AS (
            SELECT
                OptionSymbol,
                ObservationDate,
                Bid,
                Ask,
                Volume,
                IV,
                ROW_NUMBER() OVER (
                    PARTITION BY OptionSymbol
                    ORDER BY ObservationDate DESC
                ) AS RowNumber
            FROM StockDB_US.StockData.v_OptionDelayedQuote_V2
            WHERE ASXCode = ?
              AND ExpiryDate = ?
        )
        SELECT OptionSymbol, ObservationDate, Bid, Ask, Volume, IV
        FROM LatestQuotes
        WHERE RowNumber = 1
        """,
        (db_symbol, expiry_date),
    ) or []

    quotes: Dict[str, Dict[str, Any]] = {}
    for row in rows:
        option_symbol = str(row.get("OptionSymbol") or "").strip().upper()
        if not option_symbol:
            continue
        bid = _clean(row.get("Bid"))
        ask = _clean(row.get("Ask"))
        volume = _clean(row.get("Volume"))
        iv = _normalize_iv(row.get("IV"))
        observation_date = row.get("ObservationDate")
        quotes[option_symbol] = {
            "bid": _round(bid),
            "ask": _round(ask),
            "mid": _round((bid + ask) / 2.0) if bid is not None and ask is not None else None,
            "spread_pct": _spread_pct(bid, ask),
            "volume": int(volume) if volume is not None else None,
            "iv": _round(iv, 6),
            "observation_date": (
                observation_date.isoformat()
                if hasattr(observation_date, "isoformat")
                else str(observation_date or "")
            ),
        }
    return quotes


def _latest_delayed_chain_rows(
    symbol: str,
    expiry: str,
    right: str,
    low_strike: Optional[float] = None,
    high_strike: Optional[float] = None,
) -> List[Dict[str, Any]]:
    model = get_sql_model()
    db_symbol = f"{_base_symbol(symbol)}.US"
    expiry_date = _expiry_date(expiry).isoformat()
    rights = ["P", "C"] if right.upper() == "ALL" else [right.upper()]
    placeholders = ", ".join("?" for _ in rights)
    params: List[Any] = [db_symbol, expiry_date, *rights]
    strike_filter = ""
    if low_strike is not None and high_strike is not None:
        strike_filter = " AND Strike BETWEEN ? AND ?"
        params.extend([float(low_strike), float(high_strike)])

    rows = model.execute_read_query(
        f"""
        WITH LatestQuotes AS (
            SELECT
                OptionSymbol,
                ObservationDate,
                ExpiryDate,
                PorC,
                Strike,
                Bid,
                Ask,
                Volume,
                IV,
                ROW_NUMBER() OVER (
                    PARTITION BY OptionSymbol
                    ORDER BY ObservationDate DESC
                ) AS RowNumber
            FROM StockDB_US.StockData.v_OptionDelayedQuote_V2
            WHERE ASXCode = ?
              AND ExpiryDate = ?
              AND PorC IN ({placeholders})
              {strike_filter}
        )
        SELECT OptionSymbol, ObservationDate, ExpiryDate, PorC, Strike, Bid, Ask, Volume, IV
        FROM LatestQuotes
        WHERE RowNumber = 1
        ORDER BY Strike, PorC
        """,
        tuple(params),
    ) or []

    chain_rows: List[Dict[str, Any]] = []
    for row in rows:
        option_symbol = str(row.get("OptionSymbol") or "").strip().upper()
        row_right = str(row.get("PorC") or "").strip().upper()
        strike = _clean(row.get("Strike"))
        if not option_symbol or row_right not in {"P", "C"} or strike is None:
            continue
        bid = _clean(row.get("Bid"))
        ask = _clean(row.get("Ask"))
        volume = _clean(row.get("Volume"))
        iv = _normalize_iv(row.get("IV"))
        observation_date = row.get("ObservationDate")
        quote = {
            "bid": _round(bid),
            "ask": _round(ask),
            "mid": _round((bid + ask) / 2.0) if bid is not None and ask is not None else None,
            "spread_pct": _spread_pct(bid, ask),
            "volume": int(volume) if volume is not None else None,
            "iv": _round(iv, 6),
            "observation_date": (
                observation_date.isoformat()
                if hasattr(observation_date, "isoformat")
                else str(observation_date or "")
            ),
            "source": "database",
            "market_data_type": None,
        }
        chain_rows.append(
            {
                "symbol": _base_symbol(symbol),
                "option_symbol": option_symbol,
                "expiry": expiry,
                "expiry_date": _expiry_date(expiry).isoformat(),
                "dte": _dte(expiry),
                "right": row_right,
                "strike": round(float(strike), 4),
                "con_id": None,
                "local_symbol": None,
                "delayed_quote": quote,
                "quote": quote,
            }
        )
    return chain_rows


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
    client_id = random.randint(70001, 76000)
    for port in candidate_ports:
        try:
            ib.connect(host, port, clientId=client_id, timeout=10)
            logger.info("Option orders: connected to %s:%s with clientId=%s", host, port, client_id)
            return ib, loop
        except Exception as exc:
            last_err = exc
            logger.warning("Option orders: failed connect to %s:%s - %s", host, port, exc)

    raise RuntimeError(f"Failed to connect to IB API at {host}:{candidate_ports} ({last_err})")


def _base_symbol(symbol: str) -> str:
    raw = (symbol or "").strip().upper()
    return raw.split(".", 1)[0] if "." in raw else raw


def _stock_contract(symbol: str):
    if Stock is None:
        raise RuntimeError("ib_insync Stock support not available")
    return Stock(_base_symbol(symbol), "SMART", "USD")


def _option_contract(symbol: str, expiry: str, strike: float, right: str):
    if Option is None:
        raise RuntimeError("ib_insync Option support not available")
    return Option(_base_symbol(symbol), expiry, float(strike), right.upper(), "SMART", currency="USD")


def _select_option_chain(chains: Any, symbol: str) -> Any:
    chain_list = list(chains or [])
    if not chain_list:
        return None

    base_symbol = _base_symbol(symbol)

    def score(chain: Any) -> tuple[int, int, int]:
        exchange = str(getattr(chain, "exchange", "") or "").upper()
        trading_class = str(getattr(chain, "tradingClass", "") or "").upper()
        expirations = getattr(chain, "expirations", []) or []
        return (
            1 if exchange == "SMART" else 0,
            1 if trading_class == base_symbol else 0,
            len(expirations),
        )

    return max(chain_list, key=score)


def _contract_key(contract: Any) -> tuple[str, float, str]:
    return (
        str(getattr(contract, "lastTradeDateOrContractMonth", "") or "")[:8],
        round(float(getattr(contract, "strike", 0.0) or 0.0), 4),
        str(getattr(contract, "right", "") or "").upper(),
    )


def _clean(value: Any) -> Optional[float]:
    try:
        if value is None:
            return None
        number = float(value)
        if not math.isfinite(number) or number < -1e20:
            return None
        return number
    except Exception:
        return None


def _round(value: Optional[float], digits: int = 4) -> Optional[float]:
    return None if value is None else round(float(value), digits)

def _positive_price(value: Any) -> Optional[float]:
    price = _clean(value)
    return price if price is not None and price > 0 else None


def _normal_cdf(value: float) -> float:
    return 0.5 * (1 + erf(value / sqrt(2)))


def _price_option(right: str, strike: float, spot: float, iv: float, dte: int) -> float:
    if strike <= 0 or spot <= 0 or iv <= 0 or dte <= 0:
        return 0.0

    time_to_expiry_years = dte / 365.0
    sqrt_time = sqrt(time_to_expiry_years)
    d1 = (log(spot / strike) + (RISK_FREE_RATE + 0.5 * iv**2) * time_to_expiry_years) / (iv * sqrt_time)
    d2 = d1 - iv * sqrt_time
    if right.upper() == "C":
        return max(spot * _normal_cdf(d1) - strike * exp(-RISK_FREE_RATE * time_to_expiry_years) * _normal_cdf(d2), 0.0)
    return max(strike * exp(-RISK_FREE_RATE * time_to_expiry_years) * _normal_cdf(-d2) - spot * _normal_cdf(-d1), 0.0)


def _implied_vol_from_price(right: str, strike: float, spot: float, dte: int, option_price: Optional[float]) -> Optional[float]:
    if option_price is None or option_price <= 0 or strike <= 0 or spot <= 0 or dte <= 0:
        return None

    low = 0.01
    high = 5.0
    for _ in range(80):
        mid = (low + high) / 2.0
        priced = _price_option(right, strike, spot, mid, dte)
        if priced > option_price:
            high = mid
        else:
            low = mid
    result = (low + high) / 2.0
    return result if math.isfinite(result) and result > 0 else None


def _occ_symbol(symbol: str, expiry: str, right: str, strike: float) -> str:
    yy_mm_dd = expiry[2:8]
    strike_int = int(round(float(strike) * 1000))
    return f"{_base_symbol(symbol)}{yy_mm_dd}{right.upper()}{strike_int:08d}"


def _expiry_date(expiry: str) -> date:
    return datetime.strptime(expiry[:8], "%Y%m%d").date()


def _dte(expiry: str, today: Optional[date] = None) -> int:
    market_date = today or _today_us_market_date()
    return max((_expiry_date(expiry) - market_date).days, 0)


def _quote_underlying(ib: "IB", symbol: str) -> Dict[str, Any]:
    contract = _stock_contract(symbol)
    qualified = ib.qualifyContracts(contract)
    if qualified:
        contract = qualified[0]
    try:
        ib.reqMarketDataType(1)
    except Exception:
        pass
    ticker = ib.reqMktData(contract, "104,106,221,225,294,295", False, False)
    start = time.time()
    bid = ask = last = close = implied_volatility = historical_volatility = None
    while time.time() - start < 4.0:
        ib.sleep(0.2)
        bid = _positive_price(getattr(ticker, "bid", None))
        ask = _positive_price(getattr(ticker, "ask", None))
        last = _positive_price(getattr(ticker, "last", None))
        close = _positive_price(getattr(ticker, "close", None))
        implied_volatility = _normalize_iv(getattr(ticker, "impliedVolatility", None))
        historical_volatility = _normalize_iv(getattr(ticker, "histVolatility", None))
        has_price = bid is not None or ask is not None or last is not None or close is not None
        if has_price and (implied_volatility is not None or historical_volatility is not None):
            break
    mid = (bid + ask) / 2 if bid is not None and ask is not None else None
    reference = mid or last or close or bid or ask
    market_data_type = getattr(ticker, "marketDataType", None)
    return {
        "symbol": _base_symbol(symbol),
        "con_id": getattr(contract, "conId", None),
        "bid": _round(bid),
        "ask": _round(ask),
        "last": _round(last),
        "close": _round(close),
        "mid": _round(mid),
        "reference_price": _round(reference),
        "implied_volatility": _round(implied_volatility, 6),
        "historical_volatility": _round(historical_volatility, 6),
        "market_data_type": int(market_data_type) if market_data_type in {1, 2, 3, 4} else None,
    }


def _option_greek(ticker: Any, field: str) -> Optional[float]:
    for name in ["modelGreeks", "bidGreeks", "askGreeks", "lastGreeks"]:
        greeks = getattr(ticker, name, None)
        value = _clean(getattr(greeks, field, None)) if greeks is not None else None
        if value is not None and value > -10:
            return value
    return None


def _quote_option(ib: "IB", symbol: str, expiry: str, strike: float, right: str) -> OptionQuote:
    contract = _option_contract(symbol, expiry, strike, right)
    qualified = ib.qualifyContracts(contract)
    if not qualified:
        return OptionQuote(None, None, None, None, None, None, None, None, None, None, None)
    contract = qualified[0]

    best_quote: OptionQuote | None = None
    for market_data_type in [1, 3]:
        try:
            ib.reqMarketDataType(market_data_type)
        except Exception:
            pass
        ticker = ib.reqMktData(contract, "", False, False)
        start = time.time()
        timeout = 6.0 if market_data_type == 1 else 2.0
        while time.time() - start < timeout:
            ib.sleep(0.25)
            bid = _positive_price(getattr(ticker, "bid", None))
            ask = _positive_price(getattr(ticker, "ask", None))
            last = _positive_price(getattr(ticker, "last", None))
            close = _positive_price(getattr(ticker, "close", None))
            iv = _option_greek(ticker, "impliedVol")
            volume = _clean(getattr(ticker, "volume", None))
            current_quote = OptionQuote(
                bid=bid,
                ask=ask,
                last=last,
                close=close,
                mid=(bid + ask) / 2 if bid is not None and ask is not None else None,
                iv=iv,
                delta=_option_greek(ticker, "delta"),
                gamma=_option_greek(ticker, "gamma"),
                theta=_option_greek(ticker, "theta"),
                vega=_option_greek(ticker, "vega"),
                market_data_type=(
                    int(getattr(ticker, "marketDataType", market_data_type))
                    if getattr(ticker, "marketDataType", market_data_type) in {1, 2, 3, 4}
                    else market_data_type
                ),
                volume=int(volume) if volume is not None else None,
            )
            has_price = bid is not None and ask is not None
            has_option_model = any(
                value is not None
                for value in (iv, current_quote.delta, current_quote.gamma, current_quote.theta, current_quote.vega)
            )
            if has_price and has_option_model:
                try:
                    ib.cancelMktData(contract)
                except Exception:
                    pass
                return current_quote
            if any(
                value is not None
                for value in (bid, ask, last, close, iv, current_quote.delta, current_quote.gamma, current_quote.theta, current_quote.vega, current_quote.volume)
            ):
                if (
                    best_quote is None
                    or (
                        has_price
                        and not (best_quote.bid is not None and best_quote.ask is not None)
                    )
                    or (
                        has_price
                        and has_option_model
                        and not any(value is not None for value in (best_quote.iv, best_quote.delta, best_quote.gamma, best_quote.theta, best_quote.vega))
                    )
                ):
                    best_quote = current_quote
        try:
            ib.cancelMktData(contract)
        except Exception:
            pass
        if market_data_type == 1 and best_quote is not None and best_quote.market_data_type == 1:
            return best_quote

    return best_quote or OptionQuote(None, None, None, None, None, None, None, None, None, None, None)


def _quote_option_contracts(ib: "IB", contracts: List[Any]) -> Dict[tuple[str, float, str], OptionQuote]:
    quotes: Dict[tuple[str, float, str], OptionQuote] = {}
    if not contracts:
        return quotes

    try:
        ib.reqMarketDataType(1)
    except Exception:
        pass

    for start in range(0, len(contracts), 50):
        chunk = contracts[start:start + 50]
        try:
            tickers = ib.reqTickers(*chunk)
        except Exception as exc:
            logger.warning("Option orders: failed live quote chunk: %s", exc)
            continue

        for ticker in tickers:
            contract = getattr(ticker, "contract", None)
            if contract is None:
                continue
            bid = _positive_price(getattr(ticker, "bid", None))
            ask = _positive_price(getattr(ticker, "ask", None))
            last = _positive_price(getattr(ticker, "last", None))
            close = _positive_price(getattr(ticker, "close", None))
            mid = (bid + ask) / 2.0 if bid is not None and ask is not None else None
            volume = _clean(getattr(ticker, "volume", None))
            market_data_type = getattr(ticker, "marketDataType", 1)
            quotes[_contract_key(contract)] = OptionQuote(
                bid=bid,
                ask=ask,
                last=last,
                close=close,
                mid=mid,
                iv=_option_greek(ticker, "impliedVol"),
                delta=_option_greek(ticker, "delta"),
                gamma=_option_greek(ticker, "gamma"),
                theta=_option_greek(ticker, "theta"),
                vega=_option_greek(ticker, "vega"),
                market_data_type=(
                    int(market_data_type)
                    if market_data_type in {1, 2, 3, 4}
                    else 1
                ),
                volume=int(volume) if volume is not None else None,
            )
    return quotes


def _quote_with_iv(
    ib: "IB",
    symbol: str,
    expiry: str,
    strike: float,
    right: str,
    spot: float,
) -> OptionQuote:
    quote = _quote_option(ib, symbol, expiry, strike, right)
    if quote.iv is not None and quote.iv > 0:
        return quote

    dte = _dte(expiry)
    reference_price = quote.mid or quote.last or quote.close
    fallback_iv = _implied_vol_from_price(right, strike, spot, dte, reference_price)
    if fallback_iv is None:
        return quote

    return OptionQuote(
        bid=quote.bid,
        ask=quote.ask,
        last=quote.last,
        close=quote.close,
        mid=quote.mid,
        iv=fallback_iv,
        delta=quote.delta,
        gamma=quote.gamma,
        theta=quote.theta,
        vega=quote.vega,
        market_data_type=quote.market_data_type,
    )


def get_option_chain(
    symbol: str,
    right: str = "P",
    max_expiries: int = 8,
    strike_window_pct: float = 0.25,
    expiry: Optional[str] = None,
) -> Dict[str, Any]:
    ib, _loop = _connect_ib()
    try:
        underlying = _quote_underlying(ib, symbol)
        market_status = _market_status_from_context(underlying.get("market_data_type"))
        reference_price = _clean(underlying.get("reference_price"))
        if not underlying.get("con_id"):
            raise RuntimeError(f"Unable to qualify underlying contract for {symbol}")

        requested_expiry = str(expiry).strip() if expiry else None
        low_strike = high_strike = None
        if reference_price and strike_window_pct > 0:
            window = min(max(strike_window_pct, 0.01), 2.0)
            low_strike = reference_price * (1 - window)
            high_strike = reference_price * (1 + window)

        if requested_expiry:
            try:
                rows = _latest_delayed_chain_rows(symbol, requested_expiry, right, low_strike, high_strike)
            except Exception as exc:
                logger.warning("Option orders: failed to load delayed chain rows for %s %s: %s", symbol, requested_expiry, exc)
                rows = []
            if rows:
                return {
                    "ok": True,
                    "symbol": _base_symbol(symbol),
                    "market_status": market_status,
                    "underlying": underlying,
                    "expirations": [requested_expiry],
                    "strikes": sorted({round(float(row["strike"]), 4) for row in rows}),
                    "rows": rows,
                    "chain_source": "database",
                }

        chains = ib.reqSecDefOptParams(_base_symbol(symbol), "", "STK", int(underlying["con_id"]))
        chain = _select_option_chain(chains, symbol)
        if chain is None:
            raise RuntimeError(f"No option chain returned by IB for {symbol}")

        today = _today_us_market_date()
        all_expirations = sorted(
            expiry for expiry in getattr(chain, "expirations", []) if len(str(expiry)) >= 8 and _expiry_date(str(expiry)) >= today
        )
        if requested_expiry:
            expiry_value = requested_expiry
            if expiry_value not in all_expirations:
                raise RuntimeError(f"Expiry {expiry_value} is not available for {symbol}")
            expirations = [expiry_value]
        else:
            expirations = all_expirations[: max(1, min(int(max_expiries), 24))]
        strikes = sorted(float(strike) for strike in getattr(chain, "strikes", []) if _clean(strike) is not None and float(strike) > 0)
        if low_strike is not None and high_strike is not None:
            strikes = [strike for strike in strikes if low_strike <= strike <= high_strike]

        rights = ["P", "C"] if right.upper() == "ALL" else [right.upper()]
        candidate_rows: List[Dict[str, Any]] = []
        candidate_contracts: List[Any] = []
        for expiry in expirations:
            for strike in strikes:
                for row_right in rights:
                    candidate_rows.append(
                        {
                            "symbol": _base_symbol(symbol),
                            "option_symbol": _occ_symbol(symbol, str(expiry), row_right, strike),
                            "expiry": str(expiry),
                            "expiry_date": _expiry_date(str(expiry)).isoformat(),
                            "dte": _dte(str(expiry)),
                            "right": row_right,
                            "strike": round(strike, 4),
                        }
                    )
                    candidate_contracts.append(_option_contract(symbol, str(expiry), strike, row_right))

        valid_contracts: List[Any] = []
        for start in range(0, len(candidate_contracts), 100):
            chunk = candidate_contracts[start:start + 100]
            try:
                valid_contracts.extend(ib.qualifyContracts(*chunk))
            except Exception as exc:
                logger.warning("Option orders: failed to qualify chain chunk for %s: %s", symbol, exc)

        valid_keys = {_contract_key(contract): contract for contract in valid_contracts}
        delayed_quotes = _latest_delayed_quotes(symbol, expirations[0]) if len(expirations) == 1 else {}
        live_quotes = _quote_option_contracts(ib, valid_contracts) if market_status["is_live_market"] else {}
        rows: List[Dict[str, Any]] = []
        for row in candidate_rows:
            key = (row["expiry"], round(float(row["strike"]), 4), row["right"])
            contract = valid_keys.get(key)
            if contract is None:
                continue
            next_row = dict(row)
            delayed_quote = delayed_quotes.get(str(row["option_symbol"]).upper())
            live_quote = live_quotes.get(key)
            next_row["con_id"] = getattr(contract, "conId", None)
            next_row["local_symbol"] = getattr(contract, "localSymbol", None)
            next_row["delayed_quote"] = delayed_quote
            next_row["quote"] = _merge_option_quote(
                delayed_quote,
                live_quote,
                prefer_live=market_status["is_live_market"],
            )
            rows.append(next_row)

        return {
            "ok": True,
            "symbol": _base_symbol(symbol),
            "market_status": market_status,
            "underlying": underlying,
            "expirations": [str(expiry) for expiry in expirations],
            "strikes": [round(strike, 4) for strike in strikes],
            "rows": rows,
            "chain_source": "ib",
        }
    finally:
        try:
            ib.disconnect()
        except Exception:
            pass


def get_option_expirations(symbol: str) -> Dict[str, Any]:
    ib, _loop = _connect_ib()
    try:
        underlying = _quote_underlying(ib, symbol)
        market_status = _market_status_from_context(underlying.get("market_data_type"))
        if not underlying.get("con_id"):
            raise RuntimeError(f"Unable to qualify underlying contract for {symbol}")

        chains = ib.reqSecDefOptParams(_base_symbol(symbol), "", "STK", int(underlying["con_id"]))
        chain = _select_option_chain(chains, symbol)
        if chain is None:
            raise RuntimeError(f"No option chain returned by IB for {symbol}")

        today = _today_us_market_date()
        expirations = sorted(
            str(expiry)
            for expiry in getattr(chain, "expirations", [])
            if len(str(expiry)) >= 8 and _expiry_date(str(expiry)) >= today
        )
        return {
            "ok": True,
            "symbol": _base_symbol(symbol),
            "market_status": market_status,
            "underlying": underlying,
            "expirations": [
                {
                    "expiry": expiry,
                    "expiry_date": _expiry_date(expiry).isoformat(),
                    "dte": _dte(expiry),
                }
                for expiry in expirations
            ],
        }
    finally:
        try:
            ib.disconnect()
        except Exception:
            pass


def _skew_slope(points: List[tuple[float, float]]) -> float:
    if len(points) < 2:
        return 0.0
    x_mean = sum(strike for strike, _ in points) / len(points)
    y_mean = sum(iv for _, iv in points) / len(points)
    numerator = sum((strike - x_mean) * (iv - y_mean) for strike, iv in points)
    denominator = sum((strike - x_mean) ** 2 for strike, _ in points)
    return 0.0 if abs(denominator) < 1e-10 else numerator / denominator


def estimate_option_price(
    symbol: str,
    expiry: str,
    strike: float,
    right: str,
    target_underlying_price: float,
) -> Dict[str, Any]:
    ib, _loop = _connect_ib()
    try:
        underlying = _quote_underlying(ib, symbol)
        market_status = _market_status_from_context(underlying.get("market_data_type"))
        current_price = _clean(underlying.get("reference_price"))
        if current_price is None or current_price <= 0:
            raise RuntimeError("IB did not return a usable underlying price")

        warnings: List[str] = []
        selected_quote = _quote_option(ib, symbol, expiry, strike, right)
        delayed_quotes = _latest_delayed_quotes(symbol, expiry)
        delayed_quote = delayed_quotes.get(_occ_symbol(symbol, expiry, right, strike).upper())

        chains = ib.reqSecDefOptParams(_base_symbol(symbol), "", "STK", int(underlying["con_id"]))
        chain = _select_option_chain(chains, symbol)
        all_strikes = sorted(float(s) for s in getattr(chain, "strikes", []) if _clean(s) is not None and float(s) > 0)
        nearest_index = min(range(len(all_strikes)), key=lambda index: abs(all_strikes[index] - strike)) if all_strikes else 0
        nearby_strikes = all_strikes[max(0, nearest_index - 2): min(len(all_strikes), nearest_index + 3)]

        skew_by_strike: Dict[float, float] = {}
        for nearby_strike in nearby_strikes:
            database_quote = delayed_quotes.get(
                _occ_symbol(symbol, expiry, right, nearby_strike).upper()
            )
            database_iv = _normalize_iv((database_quote or {}).get("iv"))
            if database_iv is not None:
                skew_by_strike[nearby_strike] = database_iv

        selected_ib_iv = _normalize_iv(selected_quote.iv)
        selected_live_ib_iv = selected_ib_iv if market_status["is_live_market"] and selected_quote.market_data_type == 1 else None
        selected_delayed_ib_iv = selected_ib_iv if selected_quote.market_data_type in {2, 3, 4} else None
        selected_database_iv = _normalize_iv((delayed_quote or {}).get("iv"))
        live_timestamps_match = (
            market_status["is_live_market"]
            and selected_quote.market_data_type == 1
            and underlying.get("market_data_type") == 1
        )
        live_option_price = (
            _positive_price(selected_quote.mid)
            or _positive_price(selected_quote.last)
        )
        selected_market_implied_iv = (
            _implied_vol_from_price(
                right,
                strike,
                current_price,
                _dte(expiry),
                live_option_price,
            )
            if live_timestamps_match
            else None
        )
        underlying_implied_iv = _normalize_iv(underlying.get("implied_volatility"))
        underlying_historical_iv = _normalize_iv(underlying.get("historical_volatility"))

        if selected_live_ib_iv is not None:
            skew_by_strike[strike] = selected_live_ib_iv

        if len(skew_by_strike) < 2:
            for nearby_strike in nearby_strikes:
                if nearby_strike in skew_by_strike:
                    continue
                quote = selected_quote if abs(nearby_strike - strike) < 0.0001 else _quote_with_iv(
                    ib,
                    symbol,
                    expiry,
                    nearby_strike,
                    right,
                    current_price,
                )
                quote_iv = _normalize_iv(quote.iv)
                if quote_iv is not None:
                    skew_by_strike[nearby_strike] = quote_iv

        skew_points = sorted(skew_by_strike.items())
        nearest_surface_iv = (
            min(skew_points, key=lambda point: abs(point[0] - strike))[1]
            if skew_points
            else None
        )
        delayed_atm_iv = (
            min(skew_points, key=lambda point: abs(point[0] - current_price))[1]
            if skew_points
            else None
        )

        iv_candidates = [
            ("live IB selected contract IV", selected_live_ib_iv),
            ("live contract midpoint-implied IV", selected_market_implied_iv),
            ("latest delayed quote IV", selected_database_iv),
            ("IB delayed contract IV", selected_delayed_ib_iv),
            ("nearby same-expiry contract IV", nearest_surface_iv),
            ("IB underlying implied volatility proxy", underlying_implied_iv),
            ("IB underlying historical volatility", underlying_historical_iv),
            ("35% hard fallback", DEFAULT_FALLBACK_IV),
        ]
        iv_source, pricing_iv = next(
            (source, value)
            for source, value in iv_candidates
            if value is not None and value > 0
        )
        if iv_source != "live IB selected contract IV":
            warnings.append(f"Live selected-contract IV was unavailable; used {iv_source}.")
        if iv_source == "35% hard fallback":
            warnings.append("No contract, nearby-strike, or underlying volatility evidence was available.")

        underlying_iv_adjustment = 0.0
        if (
            iv_source in {
                "latest delayed quote IV",
                "IB delayed contract IV",
                "nearby same-expiry contract IV",
            }
            and underlying_implied_iv is not None
            and delayed_atm_iv is not None
        ):
            raw_underlying_adjustment = (
                underlying_implied_iv - delayed_atm_iv
            ) * UNDERLYING_IV_ADJUSTMENT_WEIGHT
            underlying_iv_adjustment = max(
                min(raw_underlying_adjustment, MAX_UNDERLYING_IV_ADJUSTMENT),
                -MAX_UNDERLYING_IV_ADJUSTMENT,
            )
            pricing_iv = max(pricing_iv + underlying_iv_adjustment, 0.05)
            if abs(underlying_iv_adjustment) >= 0.0001:
                warnings.append(
                    "Adjusted delayed contract IV by "
                    f"{underlying_iv_adjustment:+.2%} using the current underlying-IV regime "
                    f"(capped at +/-{MAX_UNDERLYING_IV_ADJUSTMENT:.0%})."
                )

        price_move_pct = (target_underlying_price - current_price) / current_price
        slope = _skew_slope(skew_points)
        target_moneyness_ratio = strike / target_underlying_price
        effective_strike = target_moneyness_ratio * current_price
        strike_equivalent_shift = effective_strike - strike
        iv_skew_adjustment = slope * strike_equivalent_shift
        if price_move_pct < 0:
            iv_directional = DOWN_MOVE_IV_EXPANSION * abs(price_move_pct) / 0.05
        else:
            iv_directional = UP_MOVE_IV_CRUSH * price_move_pct / 0.05

        total_iv_shift = max(min(iv_skew_adjustment + iv_directional, MAX_IV_SHIFT), -MAX_IV_SHIFT)
        adjusted_iv = max(pricing_iv + total_iv_shift, 0.05)
        dte = _dte(expiry)

        base_case = _price_option(right, strike, target_underlying_price, adjusted_iv, dte)
        optimistic = _price_option(right, strike, target_underlying_price, max(adjusted_iv - 0.02, 0.05), dte)
        conservative = _price_option(right, strike, target_underlying_price, adjusted_iv + 0.02, dte)
        selected_live_quote_payload = _option_quote_to_payload(selected_quote)

        return {
            "ok": True,
            "symbol": _base_symbol(symbol),
            "market_status": market_status,
            "option_symbol": _occ_symbol(symbol, expiry, right, strike),
            "expiry": expiry,
            "expiry_date": _expiry_date(expiry).isoformat(),
            "dte": dte,
            "right": right.upper(),
            "strike": round(float(strike), 4),
            "underlying": underlying,
            "current_underlying_price": _round(current_price),
            "target_underlying_price": _round(target_underlying_price),
            "quote": {
                "bid": _round(selected_quote.bid),
                "ask": _round(selected_quote.ask),
                "last": _round(selected_quote.last),
                "close": _round(selected_quote.close),
                "mid": _round(selected_quote.mid),
                "iv": _round(selected_quote.iv, 6),
                "delta": _round(selected_quote.delta, 6),
                "gamma": _round(selected_quote.gamma, 6),
                "theta": _round(selected_quote.theta, 6),
                "vega": _round(selected_quote.vega, 6),
                "market_data_type": selected_quote.market_data_type,
                "volume": selected_quote.volume,
                "source": "live" if selected_quote.market_data_type == 1 else "ib",
                "spread_pct": _spread_pct(selected_quote.bid, selected_quote.ask),
            },
            "selected_live_quote": selected_live_quote_payload,
            "effective_quote": _merge_option_quote(
                delayed_quote,
                selected_quote,
                prefer_live=market_status["is_live_market"],
            ),
            "delayed_quote": delayed_quote,
            "warnings": warnings,
            "estimated_price": round(conservative, 2),
            "base_case": round(base_case, 4),
            "optimistic": round(optimistic, 4),
            "conservative": round(conservative, 4),
            "adjusted_iv": round(adjusted_iv, 6),
            "contract_iv": round(pricing_iv, 6),
            "iv_source": iv_source,
            "iv_clues": {
                "ib_contract_iv": _round(selected_ib_iv, 6),
                "ib_contract_market_data_type": selected_quote.market_data_type,
                "delayed_quote_iv": _round(selected_database_iv, 6),
                "market_implied_iv": _round(selected_market_implied_iv, 6),
                "nearby_contract_iv": _round(nearest_surface_iv, 6),
                "delayed_atm_iv": _round(delayed_atm_iv, 6),
                "underlying_implied_iv": _round(underlying_implied_iv, 6),
                "underlying_historical_iv": _round(underlying_historical_iv, 6),
                "underlying_iv_adjustment": _round(underlying_iv_adjustment, 6),
                "timestamps_match_for_market_iv": live_timestamps_match,
            },
            "skew_adjustment": round(iv_skew_adjustment, 6),
            "directional_iv_adjustment": round(iv_directional, 6),
            "total_iv_shift": round(total_iv_shift, 6),
        }
    finally:
        try:
            ib.disconnect()
        except Exception:
            pass
