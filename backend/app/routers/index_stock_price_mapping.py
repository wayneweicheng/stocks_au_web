from datetime import datetime, timezone
import logging
import math
from threading import Lock
from time import monotonic
from typing import Any, Dict, List

from fastapi import APIRouter, Depends, HTTPException, Query
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel

from app.routers.auth import verify_credentials
from app.services.live_stock_price_service import get_live_index_price


router = APIRouter(prefix="/api", tags=["index-stock-price-mapping"])
logger = logging.getLogger("app.index_stock_price_mapping")

DATABASE = "StockDB_US"
CACHE_TTL_SECONDS = 90

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
    refresh: bool = Query(False, description="Bypass the 90-second server cache"),
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    try:
        rows, loaded_at, cached = _get_price_mapping(force_refresh=refresh)
        columns = list(rows[0].keys()) if rows else []
        try:
            spx_quote = get_live_index_price("SPX")
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
        return {
            "rows": rows,
            "columns": columns,
            "row_count": len(rows),
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
