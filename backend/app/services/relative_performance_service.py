"""Bulk historical bars for relative-performance comparisons."""
from datetime import date, datetime, time, timedelta, timezone
import logging
import math
import re
from typing import Any

from app.core.config import settings
from app.services.saved_price_levels_service import (
    _close_saved_price_levels_model,
    _execute_saved_price_levels_query,
    _open_saved_price_levels_model,
    _stock_code_aliases,
)
from app.services.live_stock_price_service import get_live_futures_prices, get_live_index_price
from app.services.market_aware_stock_price_service import market_aware_stock_prices

logger = logging.getLogger("app.relative_performance")
SPECIAL_CODES = {"ESMAIN": "ESMain.US", "SPX": "SPXW.US", "DJI": "DIA.US"}
MAX_SYMBOLS = 40


def _normalize_symbols(symbols: list[str]) -> list[str]:
    normalized = list(dict.fromkeys(symbol.strip().upper().removesuffix(".US") for symbol in symbols if symbol.strip()))
    if not normalized:
        raise ValueError("At least one symbol is required")
    if len(normalized) > MAX_SYMBOLS:
        raise ValueError(f"A maximum of {MAX_SYMBOLS} symbols can be compared")
    return ["ESMain" if symbol == "ESMAIN" else symbol for symbol in normalized]


def get_relative_performance_bars(
    symbols: list[str], *, timeframe: str = "5M", lookback_days: int = 5,
    start_date: date | None = None, end_date: date | None = None,
) -> dict[str, Any]:
    if timeframe not in {"5M", "30M"}:
        raise ValueError("timeframe must be 5M or 30M")
    if (start_date is None) != (end_date is None):
        raise ValueError("Select both start and end dates")
    if start_date is not None and end_date is not None:
        if end_date < start_date:
            raise ValueError("End date must be on or after start date")
        if (end_date - start_date).days >= 30:
            raise ValueError("Select at most 30 calendar days")
        if end_date == date.max:
            raise ValueError("End date is out of range")
    elif not 1 <= lookback_days <= 30:
        raise ValueError("lookback_days must be between 1 and 30")

    normalized = _normalize_symbols(symbols)
    aliases_by_symbol: dict[str, list[str]] = {}
    symbol_by_alias: dict[str, str] = {}
    for symbol in normalized:
        aliases = [SPECIAL_CODES[symbol.upper()]] if symbol.upper() in SPECIAL_CODES else _stock_code_aliases(symbol)
        aliases_by_symbol[symbol] = aliases
        for alias in aliases:
            symbol_by_alias.setdefault(alias.upper(), symbol)

    aliases = list(dict.fromkeys(alias for values in aliases_by_symbol.values() for alias in values))
    placeholders = ", ".join("CONVERT(varchar(40), ?)" for _ in aliases)
    frame_values = ("5M", "5min") if timeframe == "5M" else ("30M",)
    frame_clause = ", ".join("CONVERT(varchar(10), ?)" for _ in frame_values)
    model = _open_saved_price_levels_model(query_timeout=settings.support_resistance_chart_db_query_timeout)
    try:
        bars_by_symbol: dict[str, list[dict[str, Any]]] = {symbol: [] for symbol in normalized}
        if start_date is not None and end_date is not None:
            start_time = datetime.combine(start_date, time.min)
            end_time = datetime.combine(end_date + timedelta(days=1), time.min)
            end_operator = "<"
        else:
            latest_rows = _execute_saved_price_levels_query(
                model,
                f"""SELECT MAX(TimeIntervalStart) AS LatestTime
                    FROM StockDB_US.StockData.PriceHistoryTimeFrame WITH (NOLOCK)
                    WHERE ASXCode IN ({placeholders}) AND TimeFrame IN ({frame_clause})""",
                (*aliases, *frame_values),
            )
            latest_time = latest_rows[0].get("LatestTime") if latest_rows else None
            if latest_time is None:
                return {"timeframe": timeframe, "lookback_days": lookback_days, "symbols": normalized, "bars_by_symbol": bars_by_symbol}
            if not isinstance(latest_time, datetime):
                latest_time = datetime.fromisoformat(str(latest_time))
            start_time = latest_time - timedelta(days=lookback_days)
            end_time = latest_time
            end_operator = "<="
        rows = _execute_saved_price_levels_query(
            model,
            f"""SELECT ASXCode, TimeIntervalStart, [Open], [High], [Low], [Close], Volume, TimeFrame
                FROM StockDB_US.StockData.PriceHistoryTimeFrame WITH (NOLOCK)
                WHERE ASXCode IN ({placeholders}) AND TimeFrame IN ({frame_clause})
                  AND TimeIntervalStart >= ? AND TimeIntervalStart {end_operator} ?
                ORDER BY TimeIntervalStart, CASE WHEN TimeFrame = '5M' THEN 0 ELSE 1 END""",
            (*aliases, *frame_values, start_time, end_time),
        )
        seen: set[tuple[str, Any]] = set()
        for row in rows:
            symbol = symbol_by_alias.get(str(row.get("ASXCode") or "").strip().upper())
            timestamp = row.get("TimeIntervalStart")
            if symbol is None or timestamp is None or (symbol, timestamp) in seen:
                continue
            try:
                prices = [float(row[key]) for key in ("Open", "High", "Low", "Close")]
                volume = float(row.get("Volume") or 0)
            except (TypeError, ValueError, KeyError):
                continue
            if not all(math.isfinite(price) and price > 0 for price in prices):
                continue
            bars_by_symbol[symbol].append({
                "time": timestamp.isoformat() if isinstance(timestamp, datetime) else str(timestamp),
                "open": prices[0], "high": prices[1], "low": prices[2], "close": prices[3],
                "volume": volume if math.isfinite(volume) else 0,
            })
            seen.add((symbol, timestamp))
        return {"timeframe": timeframe, "lookback_days": lookback_days, "symbols": normalized, "bars_by_symbol": bars_by_symbol}
    finally:
        _close_saved_price_levels_model(model)


def get_relative_performance_live_quotes(symbols: list[str]) -> dict[str, Any]:
    normalized = _normalize_symbols(symbols)
    for symbol in normalized:
        if not re.fullmatch(r"[A-Z][A-Z0-9.^-]{0,19}", symbol.upper()):
            raise ValueError(f"Invalid symbol: {symbol}")

    stock_symbol_by_label = {
        symbol: "DIA" if symbol.upper() == "DJI" else symbol
        for symbol in normalized if symbol.upper() not in {"ESMAIN", "SPX"}
    }
    stock_symbols = list(dict.fromkeys(stock_symbol_by_label.values()))
    quotes: dict[str, dict[str, Any]] = {}

    if stock_symbols:
        try:
            snapshot = market_aware_stock_prices.get_prices(stock_symbols)
            for label, stock_symbol in stock_symbol_by_label.items():
                value = snapshot.prices.get(stock_symbol)
                if isinstance(value, (int, float)) and math.isfinite(value) and value > 0:
                    source = snapshot.price_sources.get(stock_symbol, "unknown")
                    if label.upper() == "DJI":
                        source = f"{source} (DIA ETF proxy)"
                    quotes[label] = {
                        "price": float(value), "source": source,
                        "fetched_at_utc": snapshot.fetched_at_utc,
                        "price_time": snapshot.price_times.get(stock_symbol),
                    }
        except Exception as exc:
            logger.warning("Stock price batch unavailable (%s)", type(exc).__name__)

    if any(symbol.upper() == "ESMAIN" for symbol in normalized):
        try:
            futures = get_live_futures_prices(["ES"], wait_seconds=1.5, connect_timeout=1.5, quote_only=True)
            quote = futures.get("ES") or {}
            value = quote.get("price")
            if isinstance(value, (int, float)) and math.isfinite(value) and value > 0:
                quotes["ESMain"] = {"price": float(value), "source": str(quote.get("source") or "ib_live")}
        except Exception as exc:
            logger.warning("ESMain live quote unavailable (%s)", type(exc).__name__)

    if any(symbol.upper() == "SPX" for symbol in normalized):
        try:
            quote = get_live_index_price("SPX", exchange="CBOE", wait_seconds=1.5, connect_timeout=1.5) or {}
            value = quote.get("price")
            if isinstance(value, (int, float)) and math.isfinite(value) and value > 0:
                quotes["SPX"] = {"price": float(value), "source": str(quote.get("source") or "ib_live")}
        except Exception as exc:
            logger.warning("SPX live quote unavailable (%s)", type(exc).__name__)

    return {
        "quotes": quotes,
        "unavailable": [symbol for symbol in normalized if symbol not in quotes],
        "fetched_at_utc": datetime.now(timezone.utc).isoformat(),
    }
