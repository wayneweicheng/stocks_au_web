from __future__ import annotations

import asyncio
import logging
import math
import random
import time
from dataclasses import dataclass
from datetime import date, datetime
from math import erf, exp, log, sqrt
from typing import Any, Dict, List, Optional

from app.core.config import settings

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


def _dte(expiry: str) -> int:
    return max((_expiry_date(expiry) - date.today()).days, 0)


def _quote_underlying(ib: "IB", symbol: str) -> Dict[str, Any]:
    contract = _stock_contract(symbol)
    qualified = ib.qualifyContracts(contract)
    if qualified:
        contract = qualified[0]
    try:
        ib.reqMarketDataType(1)
    except Exception:
        pass
    ticker = ib.reqMktData(contract, "221,225,294,295", False, False)
    start = time.time()
    bid = ask = last = close = None
    while time.time() - start < 4.0:
        ib.sleep(0.2)
        bid = _clean(getattr(ticker, "bid", None))
        ask = _clean(getattr(ticker, "ask", None))
        last = _clean(getattr(ticker, "last", None))
        close = _clean(getattr(ticker, "close", None))
        if bid is not None or ask is not None or last is not None or close is not None:
            break
    mid = (bid + ask) / 2 if bid is not None and ask is not None else None
    reference = mid or last or close or bid or ask
    return {
        "symbol": _base_symbol(symbol),
        "con_id": getattr(contract, "conId", None),
        "bid": _round(bid),
        "ask": _round(ask),
        "last": _round(last),
        "close": _round(close),
        "mid": _round(mid),
        "reference_price": _round(reference),
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
        return OptionQuote(None, None, None, None, None, None, None, None, None, None)
    contract = qualified[0]

    for market_data_type in [1, 3]:
        try:
            ib.reqMarketDataType(market_data_type)
        except Exception:
            pass
        ticker = ib.reqMktData(contract, "106", False, False)
        start = time.time()
        while time.time() - start < 1.5:
            ib.sleep(0.25)
            bid = _clean(getattr(ticker, "bid", None))
            ask = _clean(getattr(ticker, "ask", None))
            last = _clean(getattr(ticker, "last", None))
            close = _clean(getattr(ticker, "close", None))
            iv = _option_greek(ticker, "impliedVol")
            if bid is not None or ask is not None or last is not None or close is not None or iv is not None:
                mid = (bid + ask) / 2 if bid is not None and ask is not None else None
                return OptionQuote(
                    bid=bid,
                    ask=ask,
                    last=last,
                    close=close,
                    mid=mid,
                    iv=iv,
                    delta=_option_greek(ticker, "delta"),
                    gamma=_option_greek(ticker, "gamma"),
                    theta=_option_greek(ticker, "theta"),
                    vega=_option_greek(ticker, "vega"),
                )

    return OptionQuote(None, None, None, None, None, None, None, None, None, None)


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
        reference_price = _clean(underlying.get("reference_price"))
        if not underlying.get("con_id"):
            raise RuntimeError(f"Unable to qualify underlying contract for {symbol}")

        chains = ib.reqSecDefOptParams(_base_symbol(symbol), "", "STK", int(underlying["con_id"]))
        chain = next((c for c in chains if str(getattr(c, "exchange", "")).upper() == "SMART"), chains[0] if chains else None)
        if chain is None:
            raise RuntimeError(f"No option chain returned by IB for {symbol}")

        today = date.today()
        all_expirations = sorted(
            expiry for expiry in getattr(chain, "expirations", []) if len(str(expiry)) >= 8 and _expiry_date(str(expiry)) >= today
        )
        if expiry:
            expiry_value = str(expiry).strip()
            if expiry_value not in all_expirations:
                raise RuntimeError(f"Expiry {expiry_value} is not available for {symbol}")
            expirations = [expiry_value]
        else:
            expirations = all_expirations[: max(1, min(int(max_expiries), 24))]
        strikes = sorted(float(strike) for strike in getattr(chain, "strikes", []) if _clean(strike) is not None and float(strike) > 0)
        if reference_price and strike_window_pct > 0:
            low = reference_price * (1 - min(max(strike_window_pct, 0.01), 2.0))
            high = reference_price * (1 + min(max(strike_window_pct, 0.01), 2.0))
            strikes = [strike for strike in strikes if low <= strike <= high]

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
        rows: List[Dict[str, Any]] = []
        for row in candidate_rows:
            key = (row["expiry"], round(float(row["strike"]), 4), row["right"])
            contract = valid_keys.get(key)
            if contract is None:
                continue
            next_row = dict(row)
            next_row["con_id"] = getattr(contract, "conId", None)
            next_row["local_symbol"] = getattr(contract, "localSymbol", None)
            rows.append(next_row)

        return {
            "ok": True,
            "symbol": _base_symbol(symbol),
            "underlying": underlying,
            "expirations": [str(expiry) for expiry in expirations],
            "strikes": [round(strike, 4) for strike in strikes],
            "rows": rows,
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
        if not underlying.get("con_id"):
            raise RuntimeError(f"Unable to qualify underlying contract for {symbol}")

        chains = ib.reqSecDefOptParams(_base_symbol(symbol), "", "STK", int(underlying["con_id"]))
        chain = next((c for c in chains if str(getattr(c, "exchange", "")).upper() == "SMART"), chains[0] if chains else None)
        if chain is None:
            raise RuntimeError(f"No option chain returned by IB for {symbol}")

        today = date.today()
        expirations = sorted(
            str(expiry)
            for expiry in getattr(chain, "expirations", [])
            if len(str(expiry)) >= 8 and _expiry_date(str(expiry)) >= today
        )
        return {
            "ok": True,
            "symbol": _base_symbol(symbol),
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
        current_price = _clean(underlying.get("reference_price"))
        if current_price is None or current_price <= 0:
            raise RuntimeError("IB did not return a usable underlying price")

        warnings: List[str] = []
        selected_quote = _quote_with_iv(ib, symbol, expiry, strike, right, current_price)

        chains = ib.reqSecDefOptParams(_base_symbol(symbol), "", "STK", int(underlying["con_id"]))
        chain = next((c for c in chains if str(getattr(c, "exchange", "")).upper() == "SMART"), chains[0] if chains else None)
        all_strikes = sorted(float(s) for s in getattr(chain, "strikes", []) if _clean(s) is not None and float(s) > 0)
        nearest_index = min(range(len(all_strikes)), key=lambda index: abs(all_strikes[index] - strike)) if all_strikes else 0
        nearby_strikes = all_strikes[max(0, nearest_index - 2): min(len(all_strikes), nearest_index + 3)]

        skew_points: List[tuple[float, float]] = []
        for nearby_strike in nearby_strikes:
            quote = selected_quote if abs(nearby_strike - strike) < 0.0001 else _quote_with_iv(
                ib,
                symbol,
                expiry,
                nearby_strike,
                right,
                current_price,
            )
            if quote.iv is not None and quote.iv > 0:
                skew_points.append((nearby_strike, quote.iv))

        pricing_iv = selected_quote.iv
        if pricing_iv is None or pricing_iv <= 0:
            if skew_points:
                nearest_iv_point = min(skew_points, key=lambda point: abs(point[0] - strike))
                pricing_iv = nearest_iv_point[1]
                warnings.append(
                    "IB did not return IV/price for the selected contract; used nearest available strike IV."
                )
            else:
                pricing_iv = DEFAULT_FALLBACK_IV
                warnings.append(
                    f"IB did not return option IV or price data; used fallback IV {DEFAULT_FALLBACK_IV:.0%}."
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

        return {
            "ok": True,
            "symbol": _base_symbol(symbol),
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
            },
            "warnings": warnings,
            "estimated_price": round(conservative, 2),
            "base_case": round(base_case, 4),
            "optimistic": round(optimistic, 4),
            "conservative": round(conservative, 4),
            "adjusted_iv": round(adjusted_iv, 6),
            "contract_iv": round(pricing_iv, 6),
            "skew_adjustment": round(iv_skew_adjustment, 6),
            "directional_iv_adjustment": round(iv_directional, 6),
            "total_iv_shift": round(total_iv_shift, 6),
        }
    finally:
        try:
            ib.disconnect()
        except Exception:
            pass
