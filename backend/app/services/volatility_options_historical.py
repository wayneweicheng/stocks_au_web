from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from typing import Any, Iterable, Mapping, Sequence

from app.core.db import get_sql_model
from app.services.volatility_options_service import DEFAULT_ETFS, normalize_symbols


class HistoricalDatasetError(ValueError):
    pass


def _number(value: Any) -> float | None:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if number == number else None


def _iso(value: Any) -> str:
    if hasattr(value, "isoformat"):
        return value.isoformat()[:10]
    return str(value or "")[:10]


def _date(value: Any) -> date:
    return date.fromisoformat(str(value)[:10])


def _placeholders(values: Sequence[str]) -> str:
    return ", ".join("convert(varchar(20), ?)" for _ in values)


def build_historical_dataset(
    *,
    symbols: str | Sequence[str],
    start_date: str,
    end_date: str,
    account_equity: float,
    event_clear_symbols: str | Sequence[str] = "",
    top_n: int = 3,
    dte_min: int = 30,
    dte_max: int = 55,
    min_vol_edge: float = 0.02,
    risk_budget_pct: float = 0.02,
    max_assignment_exposure_pct: float = 0.75,
    max_options_per_snapshot: int = 1200,
    model: Any | None = None,
) -> dict[str, Any]:
    selected = normalize_symbols(symbols)
    start = _date(start_date)
    end = _date(end_date)
    if end < start:
        raise HistoricalDatasetError("end_date must be on or after start_date")
    if (end - start).days > 370:
        raise HistoricalDatasetError("historical dataset range is limited to 370 calendar days per request")
    if account_equity <= 0:
        raise HistoricalDatasetError("account_equity must be positive")
    db = model or get_sql_model()
    params_symbols = tuple(f"{symbol}.US" for symbol in selected)
    price_start = start - timedelta(days=220)
    price_end = end + timedelta(days=max(60, dte_max + 10))
    price_rows = db.execute_read_query(
        f"""
        SELECT ASXCode, ObservationDate, [Open], High, Low, [Close], Volume
        FROM StockDB_US.StockData.v_PriceHistory WITH (NOLOCK)
        WHERE ASXCode IN ({_placeholders(params_symbols)})
          AND ObservationDate BETWEEN ? AND ?
        ORDER BY ASXCode, ObservationDate
        """,
        (*params_symbols, price_start.isoformat(), price_end.isoformat()),
    ) or []
    prices: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in price_rows:
        symbol = str(row.get("ASXCode") or "").upper().removesuffix(".US")
        observed = _iso(row.get("ObservationDate"))
        close = _number(row.get("Close"))
        if symbol not in selected or not observed or close is None or close <= 0:
            continue
        item: dict[str, Any] = {"date": observed, "close": close}
        for output_key, source_key in (("open", "Open"), ("high", "High"), ("low", "Low"), ("volume", "Volume")):
            value = _number(row.get(source_key))
            if value is not None:
                item[output_key] = value
        prices[symbol].append(item)
    option_rows = db.execute_read_query(
        f"""
        SELECT ASXCode, ObservationDate, OptionSymbol, ExpiryDate, Strike, PorC,
               Bid, Ask, IV, OpenInterest, Volume, Delta, Gamma, Theta, Vega
        FROM StockDB_US.StockData.v_OptionDelayedQuoteHistory_V2 WITH (NOLOCK)
        WHERE ASXCode IN ({_placeholders(params_symbols)})
          AND ObservationDate BETWEEN ? AND ?
          AND ExpiryDate BETWEEN ? AND ?
          AND PorC = 'P'
        ORDER BY ASXCode, ObservationDate, ExpiryDate, Strike
        """,
        (*params_symbols, start.isoformat(), end.isoformat(),
         (start + timedelta(days=dte_min)).isoformat(), (end + timedelta(days=dte_max)).isoformat()),
    ) or []
    options_by_day: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in option_rows:
        symbol = str(row.get("ASXCode") or "").upper().removesuffix(".US")
        observed_text = _iso(row.get("ObservationDate"))
        if symbol not in selected or not observed_text:
            continue
        try:
            observed = _date(observed_text)
            expiry = _date(row.get("ExpiryDate"))
        except (TypeError, ValueError):
            continue
        dte = (expiry - observed).days
        if not dte_min <= dte <= dte_max:
            continue
        bid = _number(row.get("Bid"))
        ask = _number(row.get("Ask"))
        iv = _number(row.get("IV"))
        strike = _number(row.get("Strike"))
        if bid is None or ask is None or ask < bid or iv is None or iv <= 0 or strike is None:
            continue
        if iv > 3:
            iv /= 100
        options_by_day[(symbol, observed_text)].append({
            "option_symbol": row.get("OptionSymbol"),
            "expiry": expiry.isoformat(),
            "strike": strike,
            "right": "P",
            "bid": bid,
            "ask": ask,
            "iv": iv,
            "delta": _number(row.get("Delta")),
            "gamma": _number(row.get("Gamma")),
            "theta": _number(row.get("Theta")),
            "vega": _number(row.get("Vega")),
            "volume": int(_number(row.get("Volume")) or 0),
            "open_interest": int(_number(row.get("OpenInterest")) or 0),
            "multiplier": 100,
            "observation_date": observed_text,
            "quote_source": "historical_database",
        })
    clear_symbols = set(normalize_symbols(event_clear_symbols)) if event_clear_symbols else set()
    snapshots: list[dict[str, Any]] = []
    coverage: list[dict[str, Any]] = []
    for symbol in selected:
        symbol_prices = prices.get(symbol, [])
        price_by_date = {str(item["date"]): item for item in symbol_prices}
        for observed in sorted(
            _date(value) for (key_symbol, value) in options_by_day if key_symbol == symbol and start <= _date(value) <= end
        ):
            observed_text = observed.isoformat()
            same_day = price_by_date.get(observed_text)
            if not same_day:
                continue
            rows = sorted(options_by_day[(symbol, observed_text)], key=lambda item: (-(item.get("volume") or 0), item["strike"]))
            rows = rows[:max(1, min(max_options_per_snapshot, 5000))]
            forward = [
                {"date": item["date"], "spot": item["close"]}
                for item in symbol_prices
                if observed < _date(item["date"]) <= observed + timedelta(days=dte_max + 10)
            ]
            history = [item for item in symbol_prices if _date(item["date"]) <= observed][-140:]
            if len(history) < 20:
                continue
            event_status = "clear" if symbol in clear_symbols or symbol in DEFAULT_ETFS else "unknown"
            snapshots.append({
                "as_at": f"{observed_text}T16:00:00+00:00",
                "account_equity": account_equity,
                "portfolio": {"assignment_exposure": 0},
                "config": {
                    "top_n": top_n,
                    "dte_min": dte_min,
                    "dte_max": dte_max,
                    "min_vol_edge": min_vol_edge,
                    "risk_budget_pct": risk_budget_pct,
                    "max_assignment_exposure_pct": max_assignment_exposure_pct,
                },
                "underlyings": [{
                    "symbol": symbol,
                    "asset_type": "ETF" if symbol in DEFAULT_ETFS else "STOCK",
                    "sector": "index_etf" if symbol in DEFAULT_ETFS else "unclassified",
                    "spot": same_day["close"],
                    "event_status": event_status,
                    "event_dates": [],
                    "price_history": history,
                    "options": rows,
                }],
                "forward_market": forward,
            })
        coverage.append({"symbol": symbol, "price_rows": len(symbol_prices), "option_rows": sum(len(rows) for (key_symbol, _), rows in options_by_day.items() if key_symbol == symbol)})
    if not snapshots:
        raise HistoricalDatasetError("No reproducible snapshots met the exact-date, price-history, and option-quote requirements")
    snapshots.sort(key=lambda item: (str(item["as_at"]), str(item["underlyings"][0]["symbol"])))
    return {
        "dataset_name": f"vso-{start.isoformat()}-{end.isoformat()}",
        "initial_capital": account_equity,
        "monte_carlo_iterations": 2000,
        "config": {"profit_capture": 0.60, "time_exit_dte": 14, "risk_delta_exit": 0.45},
        "snapshots": snapshots,
        "coverage": coverage,
        "source": {
            "price_history": "StockDB_US.StockData.v_PriceHistory",
            "option_history": "StockDB_US.StockData.v_OptionDelayedQuoteHistory_V2",
            "point_in_time": True,
            "lookahead_policy": "same-date underlying; forward_market is used only after entry",
        },
    }
