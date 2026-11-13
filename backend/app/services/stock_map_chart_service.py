"""5M, 15M or 30M candles for support/resistance chart display.

Chart timeframe never changes how levels or a Stock Map's as-at 30M close are calculated.
"""
from datetime import date, datetime, timedelta
import math

from app.core.config import settings
from app.services.saved_price_levels_service import (
    _close_saved_price_levels_model,
    _execute_saved_price_levels_query,
    _open_saved_price_levels_model,
    _stock_code_aliases,
)


def get_stock_map_chart_bars(
    stock_code: str,
    observation_date: date | None = None,
    *,
    timeframe: str = "30M",
    observation_datetime: datetime | None = None,
    lookback_days: int = 10,
    end_inclusive: bool = False,
) -> dict:
    if timeframe not in {"5M", "15M", "30M"}:
        raise ValueError("timeframe must be 5M, 15M or 30M")
    if observation_date is not None and observation_datetime is not None:
        raise ValueError("Use observation_date or observation_datetime, not both")
    if not 1 <= lookback_days <= 60:
        raise ValueError("lookback_days must be between 1 and 60")
    # SPX Map chart labels are not SQL symbols. Each derived instrument reads
    # its own candles, while its level projection comes from the SPX report.
    mapped_codes = {
        "SPX": "SPXW.US", "ESMAIN": "ESMain.US", "SPY_D": "SPY.US",
        "QQQ_D": "QQQ.US", "SPXL_D": "SPXL.US", "TQQQ_D": "TQQQ.US",
        "SOXL_D": "SOXL.US", "SOXX_D": "SOXX.US",
    }
    mapped = mapped_codes.get(stock_code.strip().upper())
    aliases = [mapped] if mapped else _stock_code_aliases(stock_code)
    if not aliases:
        raise ValueError("stock_code is required")
    # pyodbc binds Python strings as NVARCHAR. Convert the *parameters* to
    # VARCHAR so SQL Server can seek on the (TimeFrame, ASXCode, TimeIntervalStart)
    # primary key instead of converting indexed columns to NVARCHAR.
    placeholders = ", ".join("CONVERT(varchar(10), ?)" for _ in aliases)
    # Most StockDB_US rows use '5M'; accept the requested '5min' spelling too.
    frame_values = ("5M", "5min") if timeframe == "5M" else (timeframe,)
    frame_clause = ", ".join("CONVERT(varchar(10), ?)" for _ in frame_values)
    model = _open_saved_price_levels_model(query_timeout=settings.support_resistance_chart_db_query_timeout)
    try:
        # For historical maps, end on the report's observation date, not today.
        # For current maps, use the most recent stored candle as the cutoff.
        if observation_datetime is not None:
            cutoff = observation_datetime.replace(tzinfo=None)
        elif observation_date is not None:
            cutoff = datetime.combine(observation_date + timedelta(days=1), datetime.min.time())
        else:
            latest = _execute_saved_price_levels_query(
                model,
                f"""SELECT TOP (1) TimeIntervalStart
                    FROM StockDB_US.StockData.PriceHistoryTimeFrame WITH (NOLOCK)
                    WHERE ASXCode IN ({placeholders}) AND TimeFrame IN ({frame_clause})
                    ORDER BY TimeIntervalStart DESC""",
                (*aliases, *frame_values),
            )
            cutoff = latest[0]["TimeIntervalStart"] + timedelta(seconds=1) if latest else None
        if cutoff is None:
            return {"stock_code": stock_code.strip().upper(), "bars": []}
        rows = _execute_saved_price_levels_query(
            model,
            f"""SELECT TimeIntervalStart, [Open], [High], [Low], [Close], Volume
                FROM StockDB_US.StockData.PriceHistoryTimeFrame WITH (NOLOCK)
                WHERE ASXCode IN ({placeholders}) AND TimeFrame IN ({frame_clause})
                  AND TimeIntervalStart >= ? AND TimeIntervalStart {"<=" if end_inclusive else "<"} ?
                ORDER BY TimeIntervalStart, CASE WHEN TimeFrame = '5M' THEN 0 ELSE 1 END""",
            (*aliases, *frame_values, cutoff - timedelta(days=lookback_days), cutoff),
        )
        bars = []
        seen = set()
        for row in rows:
            time = row.get("TimeIntervalStart")
            if time is None or time in seen:
                continue  # base and .US aliases may both exist for the same candle
            try:
                prices = [float(row[key]) for key in ("Open", "High", "Low", "Close")]
                if not all(math.isfinite(value) for value in prices):
                    continue
                volume = float(row.get("Volume") or 0)
                bars.append({"time": time.isoformat() if isinstance(time, datetime) else str(time),
                             "open": prices[0], "high": prices[1], "low": prices[2],
                             "close": prices[3], "volume": volume if math.isfinite(volume) else 0})
                seen.add(time)
            except (TypeError, ValueError, KeyError):
                continue
        return {"stock_code": stock_code.strip().upper(), "bars": bars}
    finally:
        _close_saved_price_levels_model(model)
