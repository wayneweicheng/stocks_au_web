from datetime import date
from typing import Any, Dict

from fastapi import APIRouter, Depends, Query

from app.routers.auth import verify_credentials
from app.services.market_command_service import MarketCommandService


router = APIRouter(
    prefix="/api/market-command",
    tags=["market-command"],
    dependencies=[Depends(verify_credentials)],
)


@router.get("/summary")
def get_market_command_summary(
    observation_date: date = Query(default_factory=date.today),
    limit: int = Query(20, ge=1, le=100),
) -> Dict[str, Any]:
    return MarketCommandService().get_summary(observation_date, limit)


@router.get("/regime")
def get_market_regime(
    market: str = Query("US", pattern="^(ASX|US)$"),
    observation_date: date = Query(default_factory=date.today),
) -> Dict[str, Any]:
    return MarketCommandService().get_regime(observation_date, market)


@router.get("/opportunities")
def get_market_opportunities(
    market: str = Query("ASX", pattern="^(ASX|US)$"),
    observation_date: date = Query(default_factory=date.today),
    limit: int = Query(20, ge=1, le=100),
) -> Dict[str, Any]:
    service = MarketCommandService()
    regime = service.get_regime(observation_date, market)
    return {
        "market": market,
        "requested_date": observation_date.isoformat(),
        "regime": regime,
        "items": service.get_opportunities(observation_date, market, regime, limit),
    }
