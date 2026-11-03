"""ObservationDate-matched D1 option evidence; never a timestamped live quote."""
from __future__ import annotations

from datetime import date
import math
from typing import Any

from fastapi import HTTPException

from app.core.db import get_timed_sql_model

SOURCE = "StockDB_US.StockData.v_OptionDelayedQuote_V2"


def _positive(value: Any) -> float | None:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return round(number, 4) if math.isfinite(number) and number > 0 else None


def _day(value: Any) -> str:
    return str(value.isoformat() if hasattr(value, "isoformat") else value or "")[:10]


def load_d1_option_rows(stock_code: str, d1: date, observation_date: date, reference: float | None) -> dict:
    """Pick a call and put at the same expiry/strike, near D1's own reference.

    D1 may be the current pre-market observation date. Only ObservationDate
    selects SQL rows; it does not establish availability at the map as-of time.
    ExpiryDate limits contracts to those still open on the selected date; no
    CreateDate, LastTradeTime, or retrieval time filters the observation.
    """
    result = {
        "source": SOURCE, "observation_date": d1.isoformat(),
        "spot_reference_from_d1": reference, "status": "no_valid_pair", "option_rows": [],
    }
    anchor = _positive(reference)
    if anchor is None:
        result["status"] = "missing_d1_reference"
        return result

    model = None
    try:
        model = get_timed_sql_model(database="StockDB_US", connection_timeout=5, query_timeout=60)
        rows = model.execute_read_query(
            f"""
            SELECT TOP (400) ASXCode, ObservationDate, ExpiryDate, Strike, PorC,
                   Bid, Ask, LastTradePrice
            FROM {SOURCE} WITH (NOLOCK)
            WHERE ASXCode IN (CONVERT(varchar(20), ?), CONVERT(varchar(20), ?))
              AND ObservationDate = CONVERT(date, ?)
              AND ExpiryDate >= CONVERT(date, ?)
              AND Strike BETWEEN ? AND ?
              AND PorC IN ('C', 'P')
            ORDER BY ABS(Strike - CONVERT(decimal(18,4), ?)), ExpiryDate, Strike, PorC
            """,
            (f"{stock_code}.US", stock_code, d1.isoformat(), observation_date.isoformat(),
             max(0, anchor * 0.95), anchor * 1.05, anchor),
        ) or []
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"D1 option evidence unavailable for {stock_code} on {d1}. No comparison job submitted.") from exc
    finally:
        if model is not None:
            model.close()

    pairs: dict[tuple[str, str, float], dict[str, dict]] = {}
    for row in rows:
        if not isinstance(row, dict) or _day(row.get("ObservationDate")) != d1.isoformat():
            continue
        symbol = str(row.get("ASXCode") or f"{stock_code}.US").upper()
        if symbol not in {stock_code, f"{stock_code}.US"}:
            continue
        expiry = _day(row.get("ExpiryDate"))
        if not expiry or expiry < observation_date.isoformat():
            continue
        strike = _positive(row.get("Strike"))
        right = str(row.get("PorC") or "").upper()
        if strike is None or right not in {"C", "P"}:
            continue
        bid, ask, last = (_positive(row.get(key)) for key in ("Bid", "Ask", "LastTradePrice"))
        if bid is not None and ask is not None and ask >= bid:
            price, price_source = round((bid + ask) / 2, 4), "bid_ask_mid"
        elif last is not None:
            price, price_source = last, "last"
        else:
            continue
        quote = {"symbol": stock_code, "observation_date": d1.isoformat(),
                 "expiry": expiry, "strike": strike, "right": right,
                 "bid": bid, "ask": ask, "last": last,
                 "price": price, "price_source": price_source, "source": SOURCE}
        entry = pairs.setdefault((symbol, expiry, strike), {})
        existing = entry.get(right)
        if existing is None or (price_source == "bid_ask_mid" and existing["price_source"] == "last"):
            entry[right] = quote

    candidates = [(key, legs) for key, legs in pairs.items() if "C" in legs and "P" in legs]
    if candidates:
        _, legs = min(candidates, key=lambda item: (abs(item[0][2] - anchor), item[0][1],
                                                   item[0][0] != f"{stock_code}.US", item[0][2]))
        result["status"] = "available_historical_d1"
        result["option_rows"] = [legs["C"], legs["P"]]
    return result
