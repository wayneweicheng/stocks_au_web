from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from app.routers.auth import verify_credentials
from app.services.price_levels_30m_service import (
    MAX_ZONE_DISTANCE_ATR,
    MIN_ZONE_DISTANCE_ATR,
    get_30m_support_resistance_for_stock,
)


router = APIRouter(
    prefix="/api/support-resistance",
    tags=["support-resistance"],
    dependencies=[Depends(verify_credentials)],
)


@router.get("")
def support_resistance(
    stock_code: str = Query(..., description="Stock code to analyze"),
    observation_date: Optional[date] = Query(default=None, description="Optional observation date"),
    lookback_days: int = Query(default=10, ge=3, le=30, description="Number of days of 30-minute bars"),
    minimum_distance_atr: float = Query(default=MIN_ZONE_DISTANCE_ATR, ge=0, le=10),
    maximum_distance_atr: float = Query(default=MAX_ZONE_DISTANCE_ATR, ge=0, le=10),
    max_levels: int = Query(default=5, ge=1, le=10),
    enable_live_prices: bool = Query(default=False),
) -> dict:
    if minimum_distance_atr > maximum_distance_atr:
        raise HTTPException(
            status_code=422,
            detail="Minimum ATR distance cannot exceed maximum ATR distance",
        )
    try:
        return get_30m_support_resistance_for_stock(
            stock_code=stock_code,
            observation_date=observation_date,
            lookback_days=lookback_days,
            minimum_distance_atr=minimum_distance_atr,
            maximum_distance_atr=maximum_distance_atr,
            max_levels=max_levels,
            enable_live_prices=enable_live_prices,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to calculate support/resistance: {exc}")
