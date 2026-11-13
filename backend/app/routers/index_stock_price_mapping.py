from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo
import logging
import math
import re
from threading import Lock
from time import monotonic
from typing import Any, Dict, List

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel

from app.core.config import settings
from app.routers.auth import verify_credentials
from app.spx_gex_strategy.calendar import USCashCalendar
from app.services.live_stock_price_service import (
    get_live_futures_closes,
    get_live_futures_prices,
    get_live_index_price,
    get_live_stock_prices,
)
from app.services.market_aware_stock_price_service import market_aware_stock_prices


router = APIRouter(prefix="/api", tags=["index-stock-price-mapping"])
logger = logging.getLogger("app.index_stock_price_mapping")

DATABASE = "StockDB_US"
# Expanded, on-demand stocks on the SPX mapped-levels page. Preserve user
# symbols exactly; an unrecognised ticker must surface as unavailable.
SPX_MAP_EXTRA_STOCKS = (
    "NVDA", "MSFT", "META", "AMZN", "AAPL", "GOOG", "TSM", "SPCX",
    "SQQQ", "MU", "SKHY", "SOXL", "SOXX", "AMD", "AVGO",
)
CACHE_TTL_SECONDS = 90
# Live prices are optional for this report. Keep an unavailable IB Gateway from
# holding the historical mapping request open long enough for the proxy to fail.
LIVE_CONNECT_TIMEOUT_SECONDS = 0.5
# The quote-only socket can briefly contend with another request (stock vs ES).
# It does not synchronize account/portfolio state; allow a bounded handshake.
QUOTE_CONNECT_TIMEOUT_SECONDS = 1.5
# The support/resistance Stock Map fetches a single quote asynchronously; allow
# slower IB Gateway handshakes and market-data ticks without delaying report load.
STOCK_MAP_LIVE_PRICE_WAIT_SECONDS = 5.0
STOCK_MAP_LIVE_PRICE_CONNECT_TIMEOUT_SECONDS = 3.0

_cache_lock = Lock()
_cache_rows: List[Dict[str, Any]] = []
_cache_loaded_at = 0.0
_cache_timestamp: datetime | None = None


def _load_price_mapping() -> List[Dict[str, Any]]:
    model = SQLServerModel(database=DATABASE)
    rows = model.execute_read_usp(
        "EXEC [Report].[usp_GetIndexStockPriceMapping] @pbitDebug = ?",
        (0,),
    )
    return rows or []


def _load_effective_intraday_bar(as_of_et: datetime, symbol: str, timeframe: str) -> Dict[str, Any] | None:
    """Return the latest valid, completed start-labelled bar at a report as-of.

    PriceHistoryTimeFrame timestamps are naive America/New_York wall times. The
    source has no verified availability timestamp, so a configurable finalization
    grace is applied and historical point-in-time availability is reported unknown.
    """
    duration_by_frame = {"5M": 5, "15M": 15, "30M": 30}
    duration_minutes = duration_by_frame.get(timeframe)
    if duration_minutes is None:
        raise ValueError(f"Unsupported effective-price timeframe: {timeframe}")
    eastern = ZoneInfo("America/New_York")
    if as_of_et.tzinfo is None:
        as_of_aware = as_of_et.replace(tzinfo=eastern)
    else:
        as_of_aware = as_of_et.astimezone(eastern)
    as_of_local = as_of_aware.replace(tzinfo=None)
    finalization_delay = max(0, int(settings.spx_effective_bar_finalization_delay_seconds))

    model = SQLServerModel(database=DATABASE)
    rows = model.execute_read_query(
        """
        SELECT TOP (1000) p.*,
            DATEADD(minute, ?, p.TimeIntervalStart) AS CalculatedBarEnd
        FROM [StockDB_US].[StockData].[PriceHistoryTimeFrame] AS p WITH (NOLOCK)
        WHERE p.ASXCode = CONVERT(varchar(10), ?)
          AND p.TimeFrame = CONVERT(varchar(10), ?)
          AND p.ObservationDate <= CONVERT(date, ?)
          AND p.TimeIntervalStart <= DATEADD(minute, -?, CONVERT(datetime, ?))
        ORDER BY p.TimeIntervalStart DESC
        """,
        (duration_minutes, symbol, timeframe, as_of_local.date(), duration_minutes, as_of_local),
    ) or []

    def as_et(raw: Any) -> datetime | None:
        if not isinstance(raw, datetime):
            return None
        if raw.tzinfo is not None:
            return raw.astimezone(eastern)
        first = raw.replace(tzinfo=eastern, fold=0)
        second = raw.replace(tzinfo=eastern, fold=1)
        if first.utcoffset() != second.utcoffset():
            # The database does not store a UTC offset/fold. Refuse ambiguous
            # fall-back wall times rather than inventing an absolute instant.
            return None
        return first

    def trustworthy_available_at(row: Dict[str, Any]) -> tuple[datetime | None, str | None]:
        # Accept explicit availability/ingestion fields only. Generic CreatedAt
        # timestamps are not assumed to mean source availability.
        trusted_names = {
            "availableatutc", "ingestedatutc", "ingestiontimestamputc", "availabilitytimestamputc",
            "sourceavailableatutc", "availableatet", "sourceavailableatet", "ingestedatet",
            "availableat", "ingestedat", "ingestiontimestamp",
        }
        for key, value in row.items():
            normalized = "".join(character for character in str(key).lower() if character.isalnum())
            if normalized not in trusted_names or value is None:
                continue
            if isinstance(value, datetime):
                if value.tzinfo is not None:
                    return value.astimezone(eastern), str(key)
                if normalized.endswith("utc"):
                    return value.replace(tzinfo=timezone.utc).astimezone(eastern), str(key)
                if normalized.endswith("et"):
                    first = value.replace(tzinfo=eastern, fold=0)
                    second = value.replace(tzinfo=eastern, fold=1)
                    if first.utcoffset() == second.utcoffset():
                        return first, str(key)
                continue
            if isinstance(value, str):
                try:
                    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
                except ValueError:
                    continue
                if parsed.tzinfo is not None:
                    return parsed.astimezone(eastern), str(key)
                if normalized.endswith("utc"):
                    return parsed.replace(tzinfo=timezone.utc).astimezone(eastern), str(key)
                if normalized.endswith("et"):
                    first = parsed.replace(tzinfo=eastern, fold=0)
                    second = parsed.replace(tzinfo=eastern, fold=1)
                    if first.utcoffset() == second.utcoffset():
                        return first, str(key)
        return None, None

    xnys_session_date = USCashCalendar("America/New_York").is_session(as_of_aware.date())
    session_calendar_status = "XNYS_SESSION_DATE" if xnys_session_date else "NON_XNYS_SESSION_DATE; futures availability not implied"
    for row in rows:
        raw_start = row.get("TimeIntervalStart")
        bar_start = as_et(raw_start)
        if bar_start is None:
            continue
        bar_end = bar_start + timedelta(minutes=duration_minutes)
        source_available_at, source_available_at_field = trustworthy_available_at(row)
        if source_available_at is not None and source_available_at.astimezone(timezone.utc) > as_of_aware.astimezone(timezone.utc):
            continue
        source_bar_end = row.get("CalculatedBarEnd") or row.get("BarCloseTime")
        if source_bar_end is not None:
            normalized_source_end = as_et(source_bar_end)
            if normalized_source_end is None or normalized_source_end.astimezone(timezone.utc) != bar_end.astimezone(timezone.utc):
                continue
        completion_cutoff = as_of_aware if source_available_at is not None else as_of_aware - timedelta(seconds=finalization_delay)
        if bar_end.astimezone(timezone.utc) > completion_cutoff.astimezone(timezone.utc):
            continue
        bar_age_seconds = max(0, int((as_of_aware.astimezone(timezone.utc) - bar_end.astimezone(timezone.utc)).total_seconds()))
        try:
            close_value = row.get("Price", row.get("Close"))
            ohlc = [float(row[key]) for key in ("Open", "High", "Low")] + [float(close_value)]
        except (KeyError, TypeError, ValueError):
            continue
        open_price, high, low, close = ohlc
        if not all(math.isfinite(value) and value > 0 for value in ohlc):
            continue
        if high < max(open_price, close, low) or low > min(open_price, close):
            continue
        return {
            "price": round(close, 4),
            "open": round(open_price, 4), "high": round(high, 4), "low": round(low, 4),
            "symbol": symbol, "timeframe": timeframe,
            "raw_time_interval_start": raw_start.isoformat(),
            "corrected_bar_start_et": bar_start.isoformat(),
            "bar_end_et": bar_end.isoformat(),
            "source_bar_end_timestamp_consistent": True,
            "timestamp": bar_start.isoformat(), "bar_close_at": bar_end.isoformat(),
            "source_available_at_et": source_available_at.isoformat() if source_available_at else None,
            "source_available_at_field": source_available_at_field,
            "as_of_et": as_of_aware.isoformat(),
            "timestamp_correction_applied": False,
            "bar_completion_valid": True,
            "point_in_time_availability_validated": source_available_at is not None,
            "availability_status": "VALIDATED_AVAILABLE_AT" if source_available_at is not None else "UNKNOWN_NO_TRUSTED_AVAILABLE_AT_SELECTED",
            "finalization_delay_seconds": finalization_delay,
            "bar_age_seconds": bar_age_seconds,
            "freshness_status": "FRESH" if bar_age_seconds <= 900 else "STALE",
            "session_calendar_status": session_calendar_status,
            "observation_date": row.get("ObservationDate"),
            "source": "StockDB_US.StockData.PriceHistoryTimeFrame; naive New York wall time",
        }
    return None


def _load_effective_market_bar(as_of_et: datetime, symbol: str) -> Dict[str, Any] | None:
    """Effective prices use only completed 5M bars; structure may use 15M/30M separately."""
    return _load_effective_intraday_bar(as_of_et, symbol, "5M")


def _load_effective_spx_prices(
    as_of_et: datetime,
    historical_closes: Dict[str, float],
    close_dates: Dict[str, str] | None = None,
    close_times: Dict[str, Dict[str, Any]] | None = None,
) -> Dict[str, Any]:
    """Map report-time bars to SPX/SPY and populate same-time QQQ/TQQQ/ES prices."""
    es_bar = _load_effective_market_bar(as_of_et, "ESMain.US")
    spy_bar = _load_effective_market_bar(as_of_et, "SPY.US")
    qqq_bar = _load_effective_market_bar(as_of_et, "QQQ.US")
    tqqq_bar = _load_effective_market_bar(as_of_et, "TQQQ.US")
    nq_bar = _load_effective_market_bar(as_of_et, "NQMain.US")
    spxl_bar = _load_effective_market_bar(as_of_et, "SPXL.US")
    soxl_bar = _load_effective_market_bar(as_of_et, "SOXL.US")
    soxx_bar = _load_effective_market_bar(as_of_et, "SOXX.US")
    aligned_bars = {"QQQ": qqq_bar, "TQQQ": tqqq_bar, "NQMain": nq_bar, "SPXL": spxl_bar, "SOXL": soxl_bar, "SOXX": soxx_bar}
    aligned_prices = {symbol: bar["price"] if bar else None for symbol, bar in aligned_bars.items()}
    aligned_timestamps = {
        **{symbol: bar.get("bar_close_at") if bar else None for symbol, bar in aligned_bars.items()},
        "ESMain": es_bar.get("bar_close_at") if es_bar else None,
    }
    aligned_sources = {
        symbol: f"{bar.get('symbol') or symbol + '.US'} completed {bar.get('timeframe') or '30M'} historical bar" if bar else None
        for symbol, bar in aligned_bars.items()
    }
    aligned_sources["ESMain"] = f"ESMain completed {es_bar.get('timeframe', '30M')} historical bar" if es_bar else None

    spx_close = historical_closes.get("SPX")
    spy_close = historical_closes.get("SPY")
    es_close = historical_closes.get("ESMain")
    same_date = lambda symbol: (
        close_dates is not None
        and close_dates.get(symbol) is not None
        and close_dates.get("SPX") is not None
        and close_dates.get(symbol) == close_dates.get("SPX")
    )
    es_basis = es_close - spx_close if es_close is not None and spx_close is not None and same_date("ESMain") else None
    basis_date = close_dates.get("ESMain") if close_dates and close_dates.get("ESMain") == close_dates.get("SPX") else None
    as_of_local_date = as_of_et.astimezone(ZoneInfo("America/New_York")).date() if as_of_et.tzinfo else as_of_et.date()
    basis_age_days = (as_of_local_date - date.fromisoformat(str(basis_date)[:10])).days if basis_date else None
    basis_quality = "DATE_MATCHED_SINGLE_CLOSE_PAIR; HISTORICAL_AVAILABILITY_UNKNOWN" if es_basis is not None else "UNAVAILABLE_NOT_DATE_MATCHED"
    spy_spx_ratio = spy_close / spx_close if spy_close is not None and spx_close and same_date("SPY") else None
    spy_spx_ratio_date = close_dates.get("SPY") if close_dates and same_date("SPY") else None
    spy_spx_ratio_quality = "MATCHED_CASH_CLOSE_DATE" if spy_spx_ratio is not None else "UNAVAILABLE_NOT_DATE_MATCHED"

    if es_bar is not None and es_basis is not None:
        effective_spx = es_bar["price"] - es_basis
        effective_spy = effective_spx * spy_spx_ratio if spy_spx_ratio is not None else None
        return {
            "effective_prices": {"SPX": round(effective_spx, 4), "SPY": round(effective_spy, 4) if effective_spy is not None else None, "ESMain": es_bar["price"], **aligned_prices},
            "effective_price_source": f"ESMain completed {es_bar.get('timeframe', '30M')} bar; SPX translated using selected-report cash-close ES−SPX basis; SPY translated using selected-report close ratio",
            "effective_price_timestamp": es_bar.get("bar_close_at"),
            "effective_price_timestamps": {**aligned_timestamps, "SPY": es_bar.get("bar_close_at")},
            "effective_price_sources": {**aligned_sources, "SPX": "ESMain as-of price translated with selected-report cash-close basis", "SPY": "SPX equivalent translated with selected-report SPY/SPX close ratio"},
            "effective_price_bar_start": es_bar.get("corrected_bar_start_et"),
            "effective_price_basis": es_basis,
            "basis_observation_date": basis_date,
            "basis_component_timestamps": {key: (close_times or {}).get(key) for key in ("SPX", "ESMain")},
            "basis_age_days": basis_age_days,
            "basis_quality": basis_quality,
            "basis_dispersion_points": None,
            "basis_dispersion_status": "not calculated; one matched cash-close pair",
            "spy_spx_close_ratio": spy_spx_ratio,
            "spy_spx_ratio_date": spy_spx_ratio_date,
            "spy_spx_ratio_quality": spy_spx_ratio_quality,
            "effective_price_bars": {"ESMain": es_bar, "SPY": spy_bar},
            "effective_price_fallback": False,
        }

    if spy_bar is not None and spy_spx_ratio is not None:
        effective_spx = spy_bar["price"] / spy_spx_ratio
        return {
            "effective_prices": {"SPX": round(effective_spx, 4), "SPY": spy_bar["price"], "ESMain": es_bar["price"] if es_bar is not None else None, **aligned_prices},
            "effective_price_source": f"SPY completed {spy_bar['timeframe']} bar fallback; SPX translated using selected-report close ratio; any unavailable ES quote remains unavailable",
            "effective_price_timestamp": spy_bar.get("bar_close_at"),
            "effective_price_timestamps": {**aligned_timestamps, "SPY": spy_bar.get("bar_close_at")},
            "effective_price_sources": {**aligned_sources, "SPX": "SPY as-of price translated with selected-report SPY/SPX close ratio", "SPY": f"SPY completed {spy_bar['timeframe']} historical bar"},
            "effective_price_bar_start": spy_bar.get("corrected_bar_start_et"),
            "effective_price_basis": es_basis,
            "basis_observation_date": basis_date,
            "basis_component_timestamps": {key: (close_times or {}).get(key) for key in ("SPX", "ESMain")},
            "basis_age_days": basis_age_days,
            "basis_quality": basis_quality,
            "basis_dispersion_points": None,
            "basis_dispersion_status": "not calculated; one matched cash-close pair" if es_basis is not None else "unavailable",
            "spy_spx_close_ratio": spy_spx_ratio,
            "spy_spx_ratio_date": spy_spx_ratio_date,
            "spy_spx_ratio_quality": spy_spx_ratio_quality,
            "effective_price_bars": {"ESMain": es_bar, "SPY": spy_bar},
            "effective_price_fallback": True,
        }

    return {
        "effective_prices": {"SPX": None, "SPY": spy_bar.get("price") if spy_bar else None, "ESMain": es_bar.get("price") if es_bar else None, **aligned_prices},
        "effective_price_source": "Unavailable: no report-time proxy could be translated with the selected-report close anchors",
        "effective_price_timestamp": None,
        "effective_price_timestamps": {**aligned_timestamps, "SPY": spy_bar.get("bar_close_at") if spy_bar else None},
        "effective_price_sources": {**aligned_sources, "SPX": None, "SPY": f"SPY completed {spy_bar['timeframe']} historical bar" if spy_bar else None},
        "effective_price_bar_start": None,
        "effective_price_basis": es_basis,
        "basis_observation_date": basis_date,
        "basis_component_timestamps": {key: (close_times or {}).get(key) for key in ("SPX", "ESMain")},
        "basis_age_days": basis_age_days,
        "basis_quality": basis_quality,
        "basis_dispersion_points": None,
        "basis_dispersion_status": "not calculated; one matched cash-close pair" if es_basis is not None else "unavailable",
        "spy_spx_close_ratio": spy_spx_ratio,
        "spy_spx_ratio_date": spy_spx_ratio_date,
        "spy_spx_ratio_quality": spy_spx_ratio_quality,
        "effective_price_bars": {"ESMain": es_bar, "SPY": spy_bar},
        "effective_price_fallback": True,
    }


def _load_latest_spx_30m_price() -> Dict[str, Any] | None:
    """Return a completed SPXW 30M cash bar; its source label is one hour behind ET."""
    eastern = ZoneInfo("America/New_York")
    as_of = datetime.now(eastern)
    source_as_of = as_of.replace(tzinfo=None) - timedelta(hours=1)
    finalization_delay = max(0, int(settings.spx_effective_bar_finalization_delay_seconds))
    eligible_as_of = source_as_of - timedelta(seconds=finalization_delay)
    model = SQLServerModel(database=DATABASE)
    rows = model.execute_read_query(
        """
        SELECT TOP (1000) [Open], [High], [Low], [Close] AS Price,
            TimeIntervalStart, DATEADD(minute, 30, TimeIntervalStart) AS RawBarEnd
        FROM [StockDB_US].[StockData].[PriceHistoryTimeFrame] WITH (NOLOCK)
        WHERE ASXCode = CONVERT(varchar(10), ?)
          AND TimeFrame = CONVERT(varchar(10), ?)
          AND TimeIntervalStart <= DATEADD(minute, -30, CONVERT(datetime, ?))
        ORDER BY TimeIntervalStart DESC
        """,
        ("SPXW.US", "30M", eligible_as_of),
    ) or []
    for row in rows:
        try:
            open_price, high, low, price = [float(row[key]) for key in ("Open", "High", "Low", "Price")]
        except (KeyError, TypeError, ValueError):
            continue
        if not all(math.isfinite(value) and value > 0 for value in (open_price, high, low, price)):
            continue
        if high < max(open_price, price, low) or low > min(open_price, price):
            continue
        raw_start = row.get("TimeIntervalStart")
        if not isinstance(raw_start, datetime):
            continue
        raw_end = row.get("RawBarEnd")
        if isinstance(raw_end, datetime) and raw_end != raw_start + timedelta(minutes=30):
            continue
        corrected_wall_start = raw_start + timedelta(hours=1)
        corrected_start = corrected_wall_start.replace(tzinfo=eastern, fold=0)
        alternate_fold = corrected_wall_start.replace(tzinfo=eastern, fold=1)
        if corrected_start.utcoffset() != alternate_fold.utcoffset():
            continue
        corrected_end = corrected_start + timedelta(minutes=30)
        return {
            "price": round(price, 4),
            "source": "database_completed_30m_close_estimate",
            "raw_time_interval_start": raw_start.isoformat(),
            "timestamp": corrected_start.isoformat(),
            "bar_end_et": corrected_end.isoformat(),
            "timestamp_correction_applied": True,
            "bar_completion_valid": True,
            "source_available_at_et": None,
            "point_in_time_availability_validated": False,
        }
    return None


def _stock_map_prior_close_cutoff(observation_date: date | None, as_of_et: datetime | None) -> date | None:
    """Return the last XNYS session whose cash close was complete at report as-of."""
    calendar = USCashCalendar("America/New_York")
    if as_of_et is not None:
        local_as_of = as_of_et
        if local_as_of.tzinfo is not None:
            local_as_of = local_as_of.astimezone(calendar.timezone).replace(tzinfo=None)
        as_of_date = local_as_of.date()
        if calendar.is_session(as_of_date) and local_as_of >= calendar.cash_close(as_of_date).replace(tzinfo=None):
            return as_of_date
        return calendar.previous_session(as_of_date)
    # With date-only provenance, exclude that date rather than risk using a
    # close that may have occurred after the report was generated. The report
    # as-of timestamp, when supplied, is authoritative over ambiguous observation_date.
    return calendar.previous_session(observation_date) if observation_date is not None else None


def _stock_map_code_candidates(stock_code: str) -> List[str]:
    code = (stock_code or "").strip().upper()
    if code.endswith(".US"):
        base_code = code[:-3]
    elif code.endswith(".AX"):
        base_code = code[:-3]
    else:
        base_code = code
    return list(dict.fromkeys([code, base_code, f"{base_code}.US"]))


def _load_stock_atr_14d(
    model: SQLServerModel,
    candidates: List[str],
    observation_date: date | None,
) -> float | None:
    placeholders = ", ".join("convert(varchar(40), ? )" for _ in candidates)
    date_clause = ""
    values: List[Any] = [*candidates]
    if observation_date:
        date_clause = "AND ObservationDate <= convert(date, ?)"
        values.append(observation_date.isoformat())
    rows = model.execute_read_query(
        f"""
        SELECT TOP (15)
            ObservationDate,
            [High],
            [Low],
            [Close]
        FROM [StockDB_US].[StockData].[PriceHistory] WITH (NOLOCK)
        WHERE ASXCode IN ({placeholders})
          {date_clause}
        ORDER BY ObservationDate DESC
        """,
        tuple(values),
    ) or []

    bars = []
    for row in reversed(rows):
        try:
            high = float(row.get("High"))
            low = float(row.get("Low"))
            close = float(row.get("Close"))
        except (TypeError, ValueError):
            continue
        if all(math.isfinite(value) for value in (high, low, close)) and close > 0:
            bars.append({"high": high, "low": low, "close": close})

    if len(bars) < 15:
        return None

    true_ranges = [
        max(
            bars[index]["high"] - bars[index]["low"],
            abs(bars[index]["high"] - bars[index - 1]["close"]),
            abs(bars[index]["low"] - bars[index - 1]["close"]),
        )
        for index in range(1, len(bars))
    ]
    if len(true_ranges) < 14:
        return None

    atr = sum(true_ranges[:14]) / 14
    for true_range in true_ranges[14:]:
        atr = ((atr * 13) + true_range) / 14
    return round(atr, 4) if math.isfinite(atr) and atr > 0 else None


def _load_snapshot_closes(
    observation_date: date | None,
    close_dates: Dict[str, str] | None = None,
    close_times: Dict[str, Dict[str, Any]] | None = None,
) -> Dict[str, float]:
    """Load report-date cash-close anchors (30M SPX/ES, 5M stocks/NQ).

    The requested date is treated as an upper bound so weekends, holidays, or
    a map generated just after midnight still resolve to the most recent
    trading-date bar rather than returning an empty snapshot.
    """
    time_rules = {
        "SPX": ("SPXW.US", "30M", "14:30:00"),
        "SPY": ("SPY.US", "5M", "15:55:00"),
        "ESMain": ("ESMain.US", "30M", "15:30:00"),
        "NQMain": ("NQMain.US", "5M", "15:55:00"),
        "QQQ": ("QQQ.US", "5M", "15:55:00"),
        "SPXL": ("SPXL.US", "5M", "15:55:00"),
        "TQQQ": ("TQQQ.US", "5M", "15:55:00"),
    }
    model = SQLServerModel(database=DATABASE)
    closes: Dict[str, float] = {}
    for symbol, (code, timeframe, time_value) in time_rules.items():
        # SPXW 30M 14:30 and ESMain 30M 15:30 are their respective
        # final cash-close bars; other instruments retain their 5M closes.
        # The PK begins (TimeFrame, ASXCode, TimeIntervalStart). Constrain all
        # three before testing the bar's clock time; filtering ObservationDate
        # and CAST(time) alone scans years of intraday history seven times.
        date_clause = ""
        values: List[Any] = [timeframe, code]
        if observation_date:
            date_clause = "AND TimeIntervalStart >= CONVERT(datetime, ?) AND TimeIntervalStart < DATEADD(day, 1, CONVERT(datetime, ?))"
            values.extend([(observation_date - timedelta(days=14)).isoformat(), observation_date.isoformat()])
        values.append(time_value)
        rows = model.execute_read_query(
            f"""
            SELECT TOP (1) ASXCode, [Close], ObservationDate, TimeIntervalStart
            FROM [StockDB_US].[StockData].[PriceHistoryTimeFrame] WITH (NOLOCK)
            WHERE TimeFrame = CONVERT(varchar(10), ?)
              AND ASXCode = CONVERT(varchar(10), ?)
              {date_clause}
              AND CAST(TimeIntervalStart AS time) = CONVERT(time, ?)
            ORDER BY TimeIntervalStart DESC
            """,
            tuple(values),
        ) or []
        if not rows:
            continue
        try:
            close = float(rows[0].get("Close"))
        except (TypeError, ValueError):
            continue
        if math.isfinite(close) and close > 0:
            closes[symbol] = close
            if close_dates is not None and rows[0].get("ObservationDate") is not None:
                close_dates[symbol] = str(rows[0]["ObservationDate"])[:10]
            if close_times is not None and isinstance(rows[0].get("TimeIntervalStart"), datetime):
                raw_time = rows[0]["TimeIntervalStart"]
                correction = timedelta(hours=1) if symbol == "SPX" else timedelta(0)
                close_times[symbol] = {
                    "raw_time_interval_start": raw_time.isoformat(),
                    "corrected_bar_start_et": (raw_time + correction).replace(tzinfo=ZoneInfo("America/New_York")).isoformat(),
                    "bar_end_et": (raw_time + correction + timedelta(minutes=30)).replace(tzinfo=ZoneInfo("America/New_York")).isoformat(),
                    "timeframe": timeframe,
                }
    return closes


def _close_anchor_date_for_asof(observation_date: date | None, as_of_et: datetime | None) -> date | None:
    """Use the latest fully completed cash-close session before this report timestamp."""
    if as_of_et is None:
        return observation_date
    local_as_of = as_of_et
    if local_as_of.tzinfo is not None:
        local_as_of = local_as_of.astimezone(ZoneInfo("America/New_York")).replace(tzinfo=None)
    anchor_date = local_as_of.date() if local_as_of.time() >= time(16, 0) else local_as_of.date() - timedelta(days=1)
    return min(anchor_date, observation_date) if observation_date is not None else anchor_date


def _load_latest_snapshot_date() -> date | None:
    model = SQLServerModel(database=DATABASE)
    rows = model.execute_read_query(
        """
        SELECT MAX(ObservationDate) AS ObservationDate
        FROM [StockDB_US].[StockData].[PriceHistoryTimeFrame] WITH (NOLOCK)
        WHERE ASXCode = 'SPXW.US' AND TimeFrame = '30M'
          AND CAST(TimeIntervalStart AS time) = CONVERT(time, '14:30:00')
        """,
        (),
    ) or []
    if not rows or rows[0].get("ObservationDate") is None:
        return None
    value = rows[0]["ObservationDate"]
    return value if isinstance(value, date) else date.fromisoformat(str(value)[:10])


def _load_mapped_live_prices() -> Dict[str, float]:
    live_prices: Dict[str, float] = {}
    try:
        spx_quote = get_live_index_price(
            "SPX",
            connect_timeout=LIVE_CONNECT_TIMEOUT_SECONDS,
        )
        if spx_quote:
            live_prices["SPX"] = float(spx_quote["price"])
    except Exception:
        logger.warning("Unable to load live SPX price", exc_info=True)

    stock_symbols = ["SPY", "QQQ", "SPXL", "TQQQ"]
    batch_lookup_succeeded = True
    try:
        live_stock_prices = get_live_stock_prices(
            stock_symbols,
            connect_timeout=LIVE_CONNECT_TIMEOUT_SECONDS,
        )
    except Exception:
        logger.warning("Batch live stock price lookup failed; skipping individual retries", exc_info=True)
        live_stock_prices = {}
        batch_lookup_succeeded = False
    for symbol in stock_symbols:
        if not batch_lookup_succeeded:
            continue
        quote = live_stock_prices.get(symbol) or {}
        price = quote.get("price")
        if not (isinstance(price, (int, float)) and math.isfinite(price) and price > 0):
            try:
                quote = get_live_stock_prices(
                    [symbol],
                    connect_timeout=LIVE_CONNECT_TIMEOUT_SECONDS,
                ).get(symbol) or {}
                price = quote.get("price")
            except Exception:
                price = None
        if isinstance(price, (int, float)) and math.isfinite(price) and price > 0:
            live_prices[symbol] = float(price)

    try:
        live_futures = get_live_futures_closes(
            ["ES"],
            connect_timeout=LIVE_CONNECT_TIMEOUT_SECONDS,
        )
        if live_futures.get("ES", {}).get("price"):
            live_prices["ESMain"] = float(live_futures["ES"]["price"])
    except Exception:
        logger.warning("Unable to load live ES price", exc_info=True)
    return live_prices


@router.get("/stock-map-prices")
def get_stock_map_prices(
    stock_code: str = Query(..., min_length=1, max_length=40),
    observation_date: date | None = Query(default=None),
    as_of_et: datetime | None = Query(default=None),
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    """Return the previous completed daily close at report as-of plus a separate live IB price."""
    candidates = _stock_map_code_candidates(stock_code)
    if not candidates or not candidates[0]:
        raise HTTPException(status_code=400, detail="stock_code is required")

    try:
        model = SQLServerModel(database=DATABASE)
        placeholders = ", ".join("convert(varchar(40), ? )" for _ in candidates)
        date_clause = ""
        values: List[Any] = [*candidates]
        close_cutoff = _stock_map_prior_close_cutoff(observation_date, as_of_et)
        if close_cutoff:
            date_clause = "AND ObservationDate <= convert(date, ?)"
            values.append(close_cutoff.isoformat())
        rows = model.execute_read_query(
            f"""
            SELECT TOP (1)
                ASXCode,
                [Close] AS LastClose,
                ObservationDate AS LastCloseObservationDate
            FROM [StockDB_US].[StockData].[PriceHistory] WITH (NOLOCK)
            WHERE ASXCode IN ({placeholders})
              {date_clause}
            ORDER BY ObservationDate DESC
            """,
            tuple(values),
        ) or []

        last_close = None
        last_close_timestamp = None
        if rows:
            try:
                candidate_close = float(rows[0].get("LastClose"))
                if math.isfinite(candidate_close) and candidate_close > 0:
                    last_close = round(candidate_close, 4)
                    last_close_timestamp = rows[0].get("LastCloseObservationDate")
            except (TypeError, ValueError):
                pass

        base_code = (stock_code or "").strip().upper()
        if base_code.endswith((".US", ".AX")):
            base_code = base_code[:-3]
        try:
            atr_14d = _load_stock_atr_14d(model, candidates, close_cutoff)
        except Exception:
            logger.warning("Unable to load 14-day ATR for stock map %s", base_code, exc_info=True)
            atr_14d = None

        live_price = None
        live_price_source = None
        try:
            live_quote = get_live_stock_prices([base_code]).get(base_code) or {}
            candidate_live_price = live_quote.get("price")
            if isinstance(candidate_live_price, (int, float)) and math.isfinite(candidate_live_price) and candidate_live_price > 0:
                live_price = round(float(candidate_live_price), 4)
                live_price_source = str(live_quote.get("source") or "ib")
        except Exception:
            logger.warning("Unable to load IB live price for stock map %s", base_code, exc_info=True)

        return {
            "stock_code": base_code,
            "last_close": last_close,
            "last_close_source": "last_completed_daily_close" if last_close is not None else None,
            "last_close_timestamp": last_close_timestamp,
            "last_close_observation_date": str(last_close_timestamp)[:10] if last_close_timestamp is not None else None,
            "atr_14d": atr_14d,
            "atr_source": "daily_price_history" if atr_14d is not None else None,
            "live_price": live_price,
            "live_price_source": live_price_source,
            "observation_date": observation_date,
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Failed to load stock mapped prices for %s", stock_code)
        raise HTTPException(status_code=500, detail="Unable to load stock mapped prices") from exc


class StockMapLivePricesRequest(BaseModel):
    symbols: List[str] = Field(..., min_length=1, max_length=40)


@router.post("/stock-map-live-prices")
def get_stock_map_live_prices(
    payload: StockMapLivePricesRequest,
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    """Batched IB real-time stock quotes for the overview; never use delayed/close prices."""
    symbols = list(dict.fromkeys(symbol.strip().upper() for symbol in payload.symbols))
    if any(not re.fullmatch(r"[A-Z][A-Z0-9.-]{0,14}", symbol) for symbol in symbols):
        raise HTTPException(status_code=400, detail="Invalid stock symbol")
    try:
        snapshot = market_aware_stock_prices.get_prices(symbols)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return snapshot.as_dict()


@router.get("/stock-map-live-price")
def get_stock_map_live_price(
    stock_code: str = Query(..., min_length=1, max_length=40),
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    """Return a quote-only live price; translate SPX from live ES using a matched cash-close basis."""
    requested_code = stock_code.strip().upper()
    base_code = requested_code.removesuffix(".US").removesuffix(".AX")
    is_spx_derived = base_code.endswith("_D")
    quote_code = base_code[:-2] if is_spx_derived else base_code
    live_price = None
    source = None
    es_live_price = None
    es_spx_basis = None
    basis_date = None
    price_source = None
    price_time = None
    market_mode = None
    price_exchange = None

    try:
        if quote_code in {"SPX", "ESMAIN"}:
            futures = get_live_futures_prices(
                ["ES"], wait_seconds=STOCK_MAP_LIVE_PRICE_WAIT_SECONDS,
                connect_timeout=STOCK_MAP_LIVE_PRICE_CONNECT_TIMEOUT_SECONDS, quote_only=True,
            )
            es_quote = futures.get("ES") or {}
            raw_es_price = es_quote.get("price")
            if isinstance(raw_es_price, (int, float)) and math.isfinite(raw_es_price) and raw_es_price > 0:
                es_live_price = float(raw_es_price)
                if quote_code == "ESMAIN":
                    live_price = es_live_price
                    source = str(es_quote.get("source") or "ib_live")
                else:
                    close_dates: Dict[str, str] = {}
                    latest_date = _load_latest_snapshot_date()
                    closes = _load_snapshot_closes(latest_date, close_dates) if latest_date else {}
                    spx_close = closes.get("SPX")
                    es_close = closes.get("ESMain")
                    if (spx_close is not None and es_close is not None
                            and close_dates.get("SPX")
                            and close_dates.get("SPX") == close_dates.get("ESMain")):
                        es_spx_basis = round(es_close - spx_close, 4)
                        basis_date = close_dates["SPX"]
                        candidate_spx = es_live_price - es_spx_basis
                        if math.isfinite(candidate_spx) and candidate_spx > 0:
                            live_price = candidate_spx
                            source = f"{es_quote.get('source') or 'IB ES quote'} less matched ES−SPX cash-close basis ({basis_date})"
        else:
            snapshot = market_aware_stock_prices.get_prices(
                [quote_code], wait_seconds=STOCK_MAP_LIVE_PRICE_WAIT_SECONDS,
                connect_timeout=STOCK_MAP_LIVE_PRICE_CONNECT_TIMEOUT_SECONDS,
            )
            live_price = snapshot.prices.get(quote_code)
            price_source = snapshot.price_sources.get(quote_code)
            price_time = snapshot.price_times.get(quote_code)
            market_mode = snapshot.market_mode
            price_exchange = snapshot.exchange
            source = f"{price_source} ({price_exchange})" if price_source and price_exchange else price_source
    except Exception:
        logger.warning("Unable to load live Stock Map price for %s", requested_code, exc_info=True)

    return {
        "stock_code": requested_code,
        "live_price": round(live_price, 4) if live_price is not None else None,
        "source": source,
        "price_time": price_time,
        "market_mode": market_mode,
        "exchange": price_exchange,
        "es_live_price": round(es_live_price, 4) if es_live_price is not None else None,
        "es_spx_basis": es_spx_basis,
        "basis_date": basis_date,
        "fetched_at_utc": datetime.now(timezone.utc).isoformat(),
    }


@router.get("/spx-map-prices")
def get_spx_map_prices(
    observation_date: date | None = Query(default=None),
    as_of_et: datetime | None = Query(default=None, description="Report as-of timestamp; selects the latest fully completed proxy bar"),
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    try:
        if not isinstance(as_of_et, datetime):
            as_of_et = None
        resolved_date = observation_date or _load_latest_snapshot_date()
        close_dates: Dict[str, str] = {}
        close_times: Dict[str, Dict[str, Any]] = {}
        anchor_date = _close_anchor_date_for_asof(resolved_date, as_of_et)
        historical_closes = _load_snapshot_closes(anchor_date, close_dates, close_times)
        effective = _load_effective_spx_prices(as_of_et, historical_closes, close_dates, close_times) if as_of_et is not None else {
            "report_as_of_et": None,
            "effective_prices": {"SPX": None, "SPY": None, "ESMain": None},
            "effective_price_source": "Report as-of timestamp unavailable",
            "effective_price_timestamp": None,
            "effective_price_bar_start": None,
            "effective_price_basis": None,
            "effective_price_fallback": True,
        }
        # Never calibrate an old report with today's IB quotes.
        latest_date = resolved_date
        if observation_date is not None:
            try:
                latest_date = _load_latest_snapshot_date()
            except Exception:
                logger.warning("Latest SPX close date unavailable; live calibration disabled", exc_info=True)
                latest_date = None
        historical_close_date = date.fromisoformat(close_dates["SPX"]) if close_dates.get("SPX") else anchor_date or resolved_date
        price_differences: Dict[str, float] = {}
        spx_close = historical_closes.get("SPX")
        if spx_close is not None:
            for symbol in ("SPY", "ESMain"):
                close = historical_closes.get(symbol)
                # A stale previous-day ES bar cannot be paired with today's SPX.
                if close is not None and close_dates.get("SPX") is not None and close_dates.get(symbol) == close_dates["SPX"]:
                    price_differences[symbol] = round(close - spx_close, 4)
        return {
            "historical_closes": historical_closes,
            "historical_close_date": historical_close_date,
            "report_as_of_et": as_of_et,
            "historical_close_dates": close_dates,
            "historical_close_timestamps": close_times,
            "effective_price_retrieved_at_utc": datetime.now(timezone.utc).isoformat(),
            "calibration_eligible": resolved_date is not None and resolved_date == latest_date,
            "price_differences": price_differences,
            # IB account synchronization and sequential quote lookups can take
            # tens of seconds. These optional *current* quotes must not block
            # a historical report or cause the Next.js proxy to reset.
            "live_prices": {},
            "live_prices_status": "not_requested_for_historical_mapping",
            **effective,
        }
    except Exception as exc:
        logger.exception("Failed to load SPX mapped-level prices")
        raise HTTPException(status_code=500, detail="Unable to load SPX mapped-level prices") from exc


@router.get("/spx-map-live-prices")
def get_spx_map_live_prices(
    username: str = Depends(verify_credentials), symbol: str | None = None,
) -> Dict[str, Any]:
    """Initial IB batch or one explicitly requested primary stock quote."""
    allowed = ("SPY", "QQQ", "SPXL", "TQQQ")
    if symbol is not None and symbol.upper() not in allowed:
        raise HTTPException(status_code=400, detail="Unsupported SPX mapped stock symbol")
    symbols = [symbol.upper()] if symbol else list(allowed)
    try:
        quotes = get_live_stock_prices(
            symbols,
            wait_seconds=2.0,
            connect_timeout=QUOTE_CONNECT_TIMEOUT_SECONDS,
            allow_close_fallback=False,
            quote_only=True,
        )
    except Exception as exc:
        logger.warning("SPX mapped stock quotes unavailable (%s)", type(exc).__name__)
        quotes = {}

    prices: Dict[str, float] = {}
    sources: Dict[str, str] = {}
    for symbol in symbols:
        quote = quotes.get(symbol) or {}
        price = quote.get("price")
        if isinstance(price, (int, float)) and math.isfinite(price) and price > 0:
            prices[symbol] = float(price)
            sources[symbol] = str(quote.get("source") or "ib_unverified")
    status = "available" if len(prices) == len(symbols) else "partial" if prices else "unavailable"
    logger.info("SPX mapped IB stock quotes: %s (%d/%d symbols)", status, len(prices), len(symbols))
    return {
        "live_prices": prices,
        "sources": sources,
        "status": status,
        "fetched_at_utc": datetime.now(timezone.utc).isoformat(),
    }


@router.get("/spx-map-live-futures")
def get_spx_map_live_futures(
    username: str = Depends(verify_credentials), symbol: str | None = None,
) -> Dict[str, Any]:
    """Initial ES/NQ batch or one explicitly requested futures quote."""
    codes_by_label = {"ESMAIN": "ES", "NQMAIN": "NQ"}
    if symbol is not None and symbol.upper() not in codes_by_label:
        raise HTTPException(status_code=400, detail="Unsupported SPX mapped futures symbol")
    codes = [codes_by_label[symbol.upper()]] if symbol else ["ES", "NQ"]
    try:
        quotes = get_live_futures_prices(
            codes,
            wait_seconds=2.0,
            connect_timeout=QUOTE_CONNECT_TIMEOUT_SECONDS,
            quote_only=True,
        )
    except Exception as exc:
        logger.warning("SPX mapped futures quotes unavailable (%s)", type(exc).__name__)
        quotes = {}
    prices: Dict[str, float] = {}
    sources: Dict[str, str] = {}
    for code, label in (("ES", "ESMain"), ("NQ", "NQMain")):
        if code not in codes:
            continue
        quote = quotes.get(code) or {}
        value = quote.get("price")
        if isinstance(value, (int, float)) and math.isfinite(value) and value > 0:
            prices[label] = float(value)
            sources[label] = str(quote.get("source") or "ib_unverified")
    status = "available" if len(prices) == len(codes) else "partial" if prices else "unavailable"
    logger.info("SPX mapped IB futures quotes: %s (%d/%d symbols)", status, len(prices), len(codes))
    return {
        "live_prices": prices,
        "sources": sources,
        "status": status,
        "fetched_at_utc": datetime.now(timezone.utc).isoformat(),
    }


@router.get("/spx-map-extra-prices")
def get_spx_map_extra_prices(
    observation_date: date = Query(...),
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    """Most recent regular-session 30M closes through the selected date."""
    try:
        model = SQLServerModel(database=DATABASE)
        codes = tuple(f"{symbol}.US" for symbol in SPX_MAP_EXTRA_STOCKS)
        placeholders = ", ".join("CONVERT(varchar(10), ?)" for _ in codes)
        rows = model.execute_read_query(
            f"""
            WITH LatestBars AS (
                SELECT ASXCode, [Close], TimeIntervalStart,
                    ROW_NUMBER() OVER (PARTITION BY ASXCode ORDER BY TimeIntervalStart DESC) AS RowNumber
                FROM [StockDB_US].[StockData].[PriceHistoryTimeFrame] WITH (NOLOCK)
                WHERE TimeFrame = '30M'
                  AND ASXCode IN ({placeholders})
                  AND TimeIntervalStart >= CONVERT(datetime, ?)
                  AND TimeIntervalStart < DATEADD(day, 1, CONVERT(datetime, ?))
                  AND CAST(TimeIntervalStart AS time) BETWEEN CONVERT(time, '09:30:00') AND CONVERT(time, '15:30:00')
                  AND [Close] > 0
            )
            SELECT ASXCode, [Close], TimeIntervalStart
            FROM LatestBars WHERE RowNumber = 1
            """,
            (*codes, (observation_date - timedelta(days=14)).isoformat(), observation_date.isoformat()),
        ) or []
        closes: Dict[str, float] = {}
        close_dates: Dict[str, str] = {}
        for row in rows:
            code = str(row.get("ASXCode") or "").upper()
            symbol = code.removesuffix(".US")
            value = row.get("Close")
            try:
                close = float(value)
            except (TypeError, ValueError):
                continue
            bar_time = row.get("TimeIntervalStart")
            if symbol in SPX_MAP_EXTRA_STOCKS and math.isfinite(close) and close > 0 and bar_time is not None:
                bar_date = str(bar_time)[:10]
                if bar_date <= observation_date.isoformat():
                    closes[symbol] = close
                    close_dates[symbol] = bar_date
        return {
            "historical_closes": closes,
            "historical_close_dates": close_dates,
            "historical_close_date": observation_date.isoformat(),
            "historical_close_source": "30m_regular_session",
        }
    except Exception as exc:
        logger.exception("Failed to load SPX extra stock closes")
        raise HTTPException(status_code=500, detail="Unable to load SPX extra stock closes") from exc


@router.get("/spx-map-live-extra-prices")
def get_spx_map_live_extra_prices(
    symbol: str = Query(..., min_length=1), username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    """One explicitly requested extra stock tick (never a prior-close fallback)."""
    code = symbol.upper()
    if code not in SPX_MAP_EXTRA_STOCKS:
        raise HTTPException(status_code=400, detail="Unsupported SPX extra stock symbol")
    try:
        quotes = get_live_stock_prices(
            [code],
            wait_seconds=2.0,
            connect_timeout=QUOTE_CONNECT_TIMEOUT_SECONDS,
            allow_close_fallback=False,
            quote_only=True,
        )
    except Exception as exc:
        logger.warning("SPX extra stock IB quotes unavailable (%s)", type(exc).__name__)
        quotes = {}
    prices: Dict[str, float] = {}
    value = (quotes.get(code) or {}).get("price")
    if isinstance(value, (int, float)) and math.isfinite(value) and value > 0:
        prices[code] = float(value)
    return {
        "live_prices": prices,
        "status": "available" if prices else "unavailable",
        "fetched_at_utc": datetime.now(timezone.utc).isoformat(),
    }


def _load_latest_closes() -> Dict[str, float]:
    # MES/MNQ are the mapping columns used for the ESMain/NQMain display
    # aliases. Only use exact instrument codes to avoid ticker collisions.
    symbol_candidates = {
        "SPY": ["SPY.US", "SPY"],
        "QQQ": ["QQQ.US", "QQQ"],
        "TQQQ": ["TQQQ.US", "TQQQ"],
        "MES": ["MES.US", "MES"],
        "MNQ": ["MNQ.US", "MNQ"],
    }
    database_codes = [code for candidates in symbol_candidates.values() for code in candidates]
    model = SQLServerModel(database=DATABASE)
    placeholders = ", ".join("?" for _ in database_codes)
    rows = model.execute_read_query(
        f"""
        WITH LatestCloses AS (
            SELECT
                ASXCode,
                [Close],
                ROW_NUMBER() OVER (
                    PARTITION BY ASXCode
                    ORDER BY ObservationDate DESC
                ) AS RowNumber
            FROM [StockDB_US].[StockData].[PriceHistory] WITH (NOLOCK)
            WHERE ASXCode IN ({placeholders})
        )
        SELECT ASXCode, [Close]
        FROM LatestCloses
        WHERE RowNumber = 1
        """,
        tuple(database_codes),
    ) or []

    closes_by_code: Dict[str, float] = {}
    for row in rows:
        code = str(row.get("ASXCode") or "").strip().upper()
        try:
            close = float(row.get("Close"))
        except (TypeError, ValueError):
            continue
        if math.isfinite(close) and close > 0:
            closes_by_code[code] = close

    closes: Dict[str, float] = {}
    for source, candidates in symbol_candidates.items():
        for code in candidates:
            if code in closes_by_code:
                closes[source] = closes_by_code[code]
                break

    missing_futures = [source for source in ("MES", "MNQ") if source not in closes]
    if missing_futures:
        try:
            futures = get_live_futures_closes(missing_futures)
            for source, quote in futures.items():
                price = quote.get("price")
                if isinstance(price, (int, float)) and math.isfinite(price) and price > 0:
                    closes[source] = float(price)
        except Exception:
            logger.warning("Unable to load latest futures closes", exc_info=True)
    return closes


def _get_price_mapping(force_refresh: bool = False) -> tuple[List[Dict[str, Any]], datetime, bool]:
    global _cache_rows, _cache_loaded_at, _cache_timestamp

    now = monotonic()
    with _cache_lock:
        cache_is_fresh = (
            _cache_timestamp is not None
            and now - _cache_loaded_at < CACHE_TTL_SECONDS
        )
        if cache_is_fresh and not force_refresh:
            return _cache_rows, _cache_timestamp, True

        rows = _load_price_mapping()
        loaded_at = datetime.now(timezone.utc)
        _cache_rows = rows
        _cache_loaded_at = monotonic()
        _cache_timestamp = loaded_at
        return rows, loaded_at, False


@router.get("/index-stock-price-mapping")
def get_index_stock_price_mapping(
    observation_date: date | None = Query(
        default=None,
        description="Trading date for the mapped-levels historical close snapshot",
    ),
    refresh: bool = Query(False, description="Bypass the 90-second server cache"),
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    try:
        rows, loaded_at, cached = _get_price_mapping(force_refresh=refresh)
        columns = list(rows[0].keys()) if rows else []
        try:
            spx_quote = get_live_index_price(
                "SPX",
                connect_timeout=LIVE_CONNECT_TIMEOUT_SECONDS,
            )
        except Exception:
            logger.warning("Unable to load the current SPX index price", exc_info=True)
            spx_quote = None
        if spx_quote is None:
            try:
                spx_quote = _load_latest_spx_30m_price()
            except Exception:
                logger.warning("Unable to load the latest SPX 30-minute price", exc_info=True)
                spx_quote = None
        logger.info(
            "Returned %s index price mapping rows (cached=%s, user=%s)",
            len(rows),
            cached,
            username,
        )
        try:
            last_closes = _load_latest_closes()
        except Exception:
            logger.warning("Unable to load latest instrument closes", exc_info=True)
            last_closes = {}
        try:
            historical_closes = _load_snapshot_closes(observation_date)
        except Exception:
            logger.warning("Unable to load mapped-level historical closes", exc_info=True)
            historical_closes = {}

        live_prices = _load_mapped_live_prices()

        price_differences: Dict[str, float] = {}
        if historical_closes.get("SPX") is not None:
            for symbol in ("SPY", "ESMain"):
                if historical_closes.get(symbol) is not None:
                    price_differences[symbol] = round(
                        historical_closes[symbol] - historical_closes["SPX"],
                        4,
                    )
        return {
            "rows": rows,
            "columns": columns,
            "row_count": len(rows),
            "last_closes": last_closes,
            "historical_closes": historical_closes,
            "historical_close_date": observation_date,
            "price_differences": price_differences,
            "live_prices": live_prices,
            "loaded_at": loaded_at,
            "cached": cached,
            "cache_ttl_seconds": CACHE_TTL_SECONDS,
            "spx_current_price": spx_quote["price"] if spx_quote else None,
            "spx_price_source": spx_quote["source"] if spx_quote else None,
        }
    except Exception as exc:
        logger.exception("Failed to load index stock price mapping")
        raise HTTPException(
            status_code=500,
            detail="Unable to load index stock price mapping data",
        ) from exc
