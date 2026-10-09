from datetime import date, datetime, timezone
import logging
import math
from threading import Lock
from time import monotonic
from typing import Any, Dict, List

from fastapi import APIRouter, Depends, HTTPException, Query
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel

from app.routers.auth import verify_credentials
from app.services.live_stock_price_service import (
    get_live_futures_closes,
    get_live_index_price,
    get_live_stock_prices,
)


router = APIRouter(prefix="/api", tags=["index-stock-price-mapping"])
logger = logging.getLogger("app.index_stock_price_mapping")

DATABASE = "StockDB_US"
CACHE_TTL_SECONDS = 90
# Live prices are optional for this report. Keep an unavailable IB Gateway from
# holding the historical mapping request open long enough for the proxy to fail.
LIVE_CONNECT_TIMEOUT_SECONDS = 0.5

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


def _load_latest_spx_30m_price() -> Dict[str, Any] | None:
    model = SQLServerModel(database=DATABASE)
    rows = model.execute_read_query(
        """
        SELECT TOP (1)
            [Close] AS Price,
            TimeIntervalStart
        FROM [StockDB_US].[StockData].[PriceHistoryTimeFrame]
        WHERE ASXCode = convert(varchar(10), ?)
          AND TimeFrame = convert(varchar(10), ?)
        ORDER BY TimeIntervalStart DESC
        """,
        ("SPXW.US", "30M"),
    ) or []
    if not rows:
        return None

    try:
        price = float(rows[0]["Price"])
    except (KeyError, TypeError, ValueError):
        return None
    if not math.isfinite(price) or price <= 0:
        return None

    return {
        "price": round(price, 4),
        "source": "database_30m_close",
        "timestamp": rows[0].get("TimeIntervalStart"),
    }


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


def _load_snapshot_closes(observation_date: date | None) -> Dict[str, float]:
    """Load one end-of-session 30-minute close per instrument.

    The requested date is treated as an upper bound so weekends, holidays, or
    a map generated just after midnight still resolve to the most recent
    trading-date bar rather than returning an empty snapshot.
    """
    time_rules = {
        "SPX": ("SPXW.US", "14:55:00"),
        "SPY": ("SPY.US", "15:55:00"),
        "ESMain": ("ESMain.US", "15:55:00"),
        "QQQ": ("QQQ.US", "15:55:00"),
        "SPXL": ("SPXL.US", "15:55:00"),
        "TQQQ": ("TQQQ.US", "15:55:00"),
    }
    model = SQLServerModel(database=DATABASE)
    closes: Dict[str, float] = {}
    for symbol, (code, time_value) in time_rules.items():
        date_clause = "AND ObservationDate <= CONVERT(date, ?)" if observation_date else ""
        values: List[Any] = [code, time_value]
        if observation_date:
            values.append(observation_date.isoformat())
        rows = model.execute_read_query(
            f"""
            SELECT TOP (1) ASXCode, [Close], ObservationDate, TimeIntervalStart
            FROM [StockDB_US].[StockData].[PriceHistoryTimeFrame] WITH (NOLOCK)
            WHERE ASXCode = ?
              AND CAST(TimeIntervalStart AS time) = CONVERT(time, ?)
              {date_clause}
            ORDER BY ObservationDate DESC, TimeIntervalStart DESC
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
    return closes


def _load_latest_snapshot_date() -> date | None:
    model = SQLServerModel(database=DATABASE)
    rows = model.execute_read_query(
        """
        SELECT MAX(ObservationDate) AS ObservationDate
        FROM [StockDB_US].[StockData].[PriceHistoryTimeFrame] WITH (NOLOCK)
        WHERE ASXCode IN ('SPXW.US', 'SPY.US', 'ESMain.US', 'QQQ.US', 'SPXL.US', 'TQQQ.US')
          AND CAST(TimeIntervalStart AS time) IN (CONVERT(time, '14:55:00'), CONVERT(time, '15:55:00'))
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
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    """Return the stock-map anchor prices: latest 30M close and IB price."""
    candidates = _stock_map_code_candidates(stock_code)
    if not candidates or not candidates[0]:
        raise HTTPException(status_code=400, detail="stock_code is required")

    try:
        model = SQLServerModel(database=DATABASE)
        placeholders = ", ".join("convert(varchar(40), ? )" for _ in candidates)
        date_clause = ""
        values: List[Any] = [*candidates]
        if observation_date:
            date_clause = "AND TimeIntervalStart < DATEADD(day, 1, convert(datetime, ?))"
            values.append(observation_date.isoformat())
        rows = model.execute_read_query(
            f"""
            SELECT TOP (1)
                ASXCode,
                [Close] AS LastClose,
                TimeIntervalStart
            FROM [StockDB_US].[StockData].[PriceHistoryTimeFrame] WITH (NOLOCK)
            WHERE ASXCode IN ({placeholders})
              AND TimeFrame = '30M'
              {date_clause}
            ORDER BY TimeIntervalStart DESC
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
                    last_close_timestamp = rows[0].get("TimeIntervalStart")
            except (TypeError, ValueError):
                pass

        base_code = (stock_code or "").strip().upper()
        if base_code.endswith((".US", ".AX")):
            base_code = base_code[:-3]
        try:
            atr_14d = _load_stock_atr_14d(model, candidates, observation_date)
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
            "last_close_source": "30m_close" if last_close is not None else None,
            "last_close_timestamp": last_close_timestamp,
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


@router.get("/spx-map-prices")
def get_spx_map_prices(
    observation_date: date | None = Query(default=None),
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    try:
        resolved_date = observation_date or _load_latest_snapshot_date()
        historical_closes = _load_snapshot_closes(observation_date)
        price_differences: Dict[str, float] = {}
        spx_close = historical_closes.get("SPX")
        if spx_close is not None:
            for symbol in ("SPY", "ESMain"):
                close = historical_closes.get(symbol)
                if close is not None:
                    price_differences[symbol] = round(close - spx_close, 4)
        return {
            "historical_closes": historical_closes,
            "historical_close_date": resolved_date,
            "price_differences": price_differences,
            "live_prices": _load_mapped_live_prices(),
        }
    except Exception as exc:
        logger.exception("Failed to load SPX mapped-level prices")
        raise HTTPException(status_code=500, detail="Unable to load SPX mapped-level prices") from exc


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
