from datetime import date
from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from app.routers.auth import verify_credentials
from app.services.price_levels_30m_service import (
    MAX_ZONE_DISTANCE_ATR,
    MIN_ZONE_DISTANCE_ATR,
    get_30m_support_resistance,
)


router = APIRouter(
    prefix="/api/price-levels-30m",
    tags=["price-levels-30m"],
    dependencies=[Depends(verify_credentials)],
)


@router.get("")
def price_levels_30m(
    observation_date: Optional[date] = Query(default=None),
    lookback_days: int = Query(default=10, ge=3, le=30),
    minimum_distance_atr: float = Query(
        default=MIN_ZONE_DISTANCE_ATR,
        ge=0,
        le=10,
    ),
    maximum_distance_atr: float = Query(
        default=MAX_ZONE_DISTANCE_ATR,
        ge=0,
        le=10,
    ),
) -> Dict[str, Any]:
    if minimum_distance_atr > maximum_distance_atr:
        raise HTTPException(
            status_code=422,
            detail="Minimum ATR distance cannot exceed maximum ATR distance",
        )
    try:
        return get_30m_support_resistance(
            observation_date=observation_date,
            lookback_days=lookback_days,
            minimum_distance_atr=minimum_distance_atr,
            maximum_distance_atr=maximum_distance_atr,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to calculate 30-minute price levels: {exc}")
