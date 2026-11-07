from datetime import date, datetime
from threading import BoundedSemaphore
from typing import Literal, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.config import settings
from app.routers.auth import verify_credentials
from app.services.price_levels_30m_service import (
    MAX_ZONE_DISTANCE_ATR,
    MIN_ZONE_DISTANCE_ATR,
    SupportResistanceDatabaseError,
    get_30m_support_resistance_for_stock,
)
from app.services.saved_price_levels_service import (
    SavedPriceLevelsDatabaseError,
    get_recorded_support_resistance_hours,
    get_saved_support_resistance,
)
from app.services.stock_map_chart_service import get_stock_map_chart_bars
from app.services.relative_performance_service import get_relative_performance_bars, get_relative_performance_live_quotes
from app.services.stock_map_option_snapshot import load_d1_option_rows


class RelativePerformanceLiveQuoteRequest(BaseModel):
    symbols: list[str] = Field(..., min_length=1, max_length=40)


router = APIRouter(
    prefix="/api/support-resistance",
    tags=["support-resistance"],
    dependencies=[Depends(verify_credentials)],
)
_support_resistance_slots = BoundedSemaphore(
    settings.support_resistance_max_concurrent_requests
)


@router.get("/database-hours")
def saved_support_resistance_hours(
    stock_code: str = Query(..., description="US stock/ETF symbol"),
) -> dict:
    try:
        return {
            "stock_code": stock_code.strip().upper(),
            "hours": get_recorded_support_resistance_hours(stock_code),
        }
    except SavedPriceLevelsDatabaseError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))


@router.get("/database")
def saved_support_resistance(
    stock_code: str = Query(..., description="US stock/ETF symbol"),
    recorded_hour: Optional[datetime] = Query(
        default=None,
        description="Recorded database hour to load; omitted loads the latest recorded hour",
    ),
) -> dict:
    try:
        return get_saved_support_resistance(
            stock_code=stock_code,
            observation_datetime=recorded_hour,
        )
    except SavedPriceLevelsDatabaseError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))


@router.get("/chart-bars")
def support_resistance_chart_bars(
    stock_code: str = Query(..., min_length=1, max_length=40),
    timeframe: Literal["30M", "5M"] = Query(default="5M"),
    observation_date: Optional[date] = Query(default=None),
    observation_datetime: Optional[datetime] = Query(default=None),
    lookback_days: int = Query(default=10, ge=1, le=60),
    end_inclusive: bool = Query(default=False),
) -> dict:
    """Candles for the chart only; 30M calculations and saved levels remain unchanged."""
    try:
        return get_stock_map_chart_bars(
            stock_code, observation_date, timeframe=timeframe,
            observation_datetime=observation_datetime, lookback_days=lookback_days,
            end_inclusive=end_inclusive,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except SavedPriceLevelsDatabaseError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.get("/relative-performance")
def relative_performance_bars(
    symbols: list[str] = Query(..., description="Symbols to compare; repeat symbols query parameter"),
    timeframe: Literal["5M", "30M"] = Query(default="5M"),
    lookback_days: int = Query(default=5, ge=1, le=30),
    start_date: Optional[date] = Query(default=None, description="First calendar date, inclusive"),
    end_date: Optional[date] = Query(default=None, description="Last calendar date, inclusive"),
) -> dict:
    try:
        return get_relative_performance_bars(
            symbols, timeframe=timeframe, lookback_days=lookback_days,
            start_date=start_date, end_date=end_date,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except SavedPriceLevelsDatabaseError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.post("/relative-performance/live-quotes")
def relative_performance_live_quotes(payload: RelativePerformanceLiveQuoteRequest) -> dict:
    try:
        return get_relative_performance_live_quotes(payload.symbols)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.get("/spx-map-options")
def spx_map_option_context(
    observation_date: date = Query(..., description="SPX Map US as-of observation date"),
    reference_price: float = Query(..., gt=0, le=100000, description="SPX report reference, for nearest-strike selection"),
) -> dict:
    """Read-only SPXW option pair by ObservationDate; never a live quote."""
    return load_d1_option_rows("SPXW", observation_date, observation_date, reference_price)


@router.get("/stock-map-bars")
def stock_map_chart_bars(
    stock_code: str = Query(..., min_length=1, max_length=40),
    observation_date: Optional[date] = Query(default=None),
) -> dict:
    """30M candles for report as-at classification; chart view is selected separately."""
    try:
        return get_stock_map_chart_bars(stock_code, observation_date)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except SavedPriceLevelsDatabaseError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.get("")
def support_resistance(
    stock_code: str = Query(..., description="Stock code to analyze"),
    observation_date: Optional[date] = Query(default=None, description="Optional observation date"),
    observation_datetime: Optional[datetime] = Query(
        default=None,
        description="Optional as-at datetime; limits 30-minute bars to this timestamp",
    ),
    lookback_days: int = Query(default=10, ge=3, le=30, description="Number of days of 30-minute bars"),
    minimum_distance_atr: float = Query(default=MIN_ZONE_DISTANCE_ATR, ge=0, le=10),
    maximum_distance_atr: float = Query(default=MAX_ZONE_DISTANCE_ATR, ge=0, le=10),
    max_levels: int = Query(default=5, ge=1, le=10),
    enable_live_prices: bool = Query(default=True),
) -> dict:
    if observation_date is not None and observation_datetime is not None:
        raise HTTPException(
            status_code=422,
            detail="Use either observation_date or observation_datetime, not both",
        )
    if minimum_distance_atr > maximum_distance_atr:
        raise HTTPException(
            status_code=422,
            detail="Minimum ATR distance cannot exceed maximum ATR distance",
        )
    if not _support_resistance_slots.acquire(blocking=False):
        raise HTTPException(
            status_code=503,
            detail="Support/resistance is already loading another request. Please try again shortly.",
        )
    try:
        return get_30m_support_resistance_for_stock(
            stock_code=stock_code,
            observation_date=observation_date,
            observation_datetime=observation_datetime,
            lookback_days=lookback_days,
            minimum_distance_atr=minimum_distance_atr,
            maximum_distance_atr=maximum_distance_atr,
            max_levels=max_levels,
            enable_live_prices=enable_live_prices,
        )
    except SupportResistanceDatabaseError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to calculate support/resistance: {exc}")
    finally:
        _support_resistance_slots.release()
