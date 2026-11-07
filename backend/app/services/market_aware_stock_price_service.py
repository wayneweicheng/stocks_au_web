"""Consistent session-aware stock price selection for UI snapshots.

Call ``market_aware_stock_prices.get_prices(symbols)`` when a caller wants the
application's current-stock policy: weekend database 30M close, overnight IB
OVERNIGHT quote, otherwise IB SMART quote. Missing prices are represented as
``None`` and are never backfilled from an unrelated session/source.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime, time, timezone
import logging
import math
import re
from typing import Any, Callable
from zoneinfo import ZoneInfo

from app.services.live_stock_price_service import get_live_stock_prices
from app.services.saved_price_levels_service import (
    _close_saved_price_levels_model,
    _execute_saved_price_levels_query,
    _open_saved_price_levels_model,
    _stock_code_aliases,
)

logger = logging.getLogger("app.market_aware_stock_price")
EASTERN = ZoneInfo("America/New_York")
QUOTE_CONNECT_TIMEOUT_SECONDS = 1.5


@dataclass(frozen=True)
class StockPriceSnapshot:
    prices: dict[str, float | None]
    price_sources: dict[str, str]
    price_times: dict[str, str]
    market_mode: str
    exchange: str | None
    fetched_at_utc: str

    def as_dict(self) -> dict[str, Any]:
        return asdict(self)


def market_price_mode(now_et: datetime) -> str:
    """Return weekend_30m, overnight, or smart for a timestamp in Eastern time."""
    local = now_et.astimezone(EASTERN) if now_et.tzinfo is not None else now_et
    weekday = local.weekday()
    local_time = local.time().replace(tzinfo=None)

    # This user-defined weekend window takes priority over the general overnight
    # window (notably Friday evening): Friday 08:00 through Sunday 20:00 ET.
    if (
        (weekday == 4 and local_time >= time(8, 0))
        or weekday == 5
        or (weekday == 6 and local_time < time(20, 0))
    ):
        return "weekend_30m"

    # Includes Sunday 20:00 through Monday 04:00, and weekday 20:00–04:00.
    if (weekday == 6 and local_time >= time(20, 0)) or (
        weekday <= 4 and (local_time >= time(20, 0) or local_time < time(4, 0))
    ):
        return "overnight"
    return "smart"


def _load_latest_30m_prices(symbols: list[str]) -> tuple[dict[str, float], dict[str, str]]:
    aliases_by_symbol = {symbol: _stock_code_aliases(symbol) for symbol in symbols}
    aliases = list(dict.fromkeys(alias for values in aliases_by_symbol.values() for alias in values))
    if not aliases:
        return {}, {}

    placeholders = ", ".join("CONVERT(varchar(20), ?)" for _ in aliases)
    model = _open_saved_price_levels_model()
    try:
        rows = _execute_saved_price_levels_query(
            model,
            f"""WITH Latest AS (
                    SELECT ASXCode, [Close], TimeIntervalStart,
                           ROW_NUMBER() OVER (PARTITION BY ASXCode ORDER BY TimeIntervalStart DESC) AS rn
                    FROM StockDB_US.StockData.PriceHistoryTimeFrame WITH (NOLOCK)
                    WHERE TimeFrame = CONVERT(varchar(10), ?) AND ASXCode IN ({placeholders})
                      AND [Close] IS NOT NULL
                )
                SELECT ASXCode, [Close], TimeIntervalStart FROM Latest WHERE rn = 1""",
            ("30M", *aliases),
        )
    finally:
        _close_saved_price_levels_model(model)

    by_alias: dict[str, tuple[float, datetime | str]] = {}
    for row in rows:
        try:
            value = float(row.get("Close"))
            stamp = row.get("TimeIntervalStart")
            if math.isfinite(value) and value > 0 and stamp is not None:
                by_alias[str(row.get("ASXCode") or "").strip().upper()] = (value, stamp)
        except (TypeError, ValueError):
            continue

    prices: dict[str, float] = {}
    price_times: dict[str, str] = {}
    for symbol, symbol_aliases in aliases_by_symbol.items():
        candidates = [by_alias[alias.upper()] for alias in symbol_aliases if alias.upper() in by_alias]
        if not candidates:
            continue
        value, stamp = max(candidates, key=lambda item: item[1])
        prices[symbol] = round(value, 4)
        price_times[symbol] = stamp.isoformat() if isinstance(stamp, datetime) else str(stamp)
    return prices, price_times


class MarketAwareStockPriceService:
    """One reusable interface for current stock prices across app pages."""

    def __init__(
        self,
        *,
        live_quote_loader: Callable[..., dict[str, dict[str, Any]]] | None = None,
        history_loader: Callable[[list[str]], tuple[dict[str, float], dict[str, str]]] | None = None,
        clock: Callable[[], datetime] | None = None,
    ) -> None:
        self._live_quote_loader = live_quote_loader or get_live_stock_prices
        self._history_loader = history_loader or _load_latest_30m_prices
        self._clock = clock or (lambda: datetime.now(EASTERN))

    def get_prices(self, symbols: list[str]) -> StockPriceSnapshot:
        normalized = list(dict.fromkeys(symbol.strip().upper() for symbol in symbols if symbol.strip()))
        if not normalized:
            raise ValueError("At least one stock symbol is required")
        if any(not re.fullmatch(r"[A-Z][A-Z0-9.-]{0,14}", symbol) for symbol in normalized):
            raise ValueError("Invalid stock symbol")

        mode = market_price_mode(self._clock())
        exchange = "OVERNIGHT" if mode == "overnight" else "SMART" if mode == "smart" else None
        prices: dict[str, float | None] = {symbol: None for symbol in normalized}
        sources: dict[str, str] = {}
        price_times: dict[str, str] = {}

        if mode == "weekend_30m":
            try:
                history, history_times = self._history_loader(normalized)
                for symbol in normalized:
                    value = history.get(symbol)
                    if isinstance(value, (int, float)) and math.isfinite(value) and value > 0:
                        prices[symbol] = round(float(value), 4)
                        sources[symbol] = "database_30m"
                        if history_times.get(symbol):
                            price_times[symbol] = history_times[symbol]
            except Exception:
                logger.warning("Weekend 30-minute stock prices unavailable", exc_info=True)
        else:
            try:
                quotes = self._live_quote_loader(
                    normalized,
                    wait_seconds=2.0,
                    connect_timeout=QUOTE_CONNECT_TIMEOUT_SECONDS,
                    allow_close_fallback=False,
                    quote_only=True,
                    exchange=exchange,
                )
            except Exception:
                logger.warning("IB stock prices unavailable on %s", exchange, exc_info=True)
                quotes = {}
            for symbol in normalized:
                quote = quotes.get(symbol) or {}
                value = quote.get("price")
                if (quote.get("source") == "ib_live" and isinstance(value, (int, float))
                        and not isinstance(value, bool) and math.isfinite(value) and value > 0):
                    prices[symbol] = round(float(value), 4)
                    sources[symbol] = "ib_live"

        return StockPriceSnapshot(
            prices=prices,
            price_sources=sources,
            price_times=price_times,
            market_mode=mode,
            exchange=exchange,
            fetched_at_utc=datetime.now(timezone.utc).isoformat(),
        )


market_aware_stock_prices = MarketAwareStockPriceService()
