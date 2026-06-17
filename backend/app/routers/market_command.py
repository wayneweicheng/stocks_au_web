from datetime import date
from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, Query

from app.routers.auth import verify_credentials
from app.services.market_command_service import MarketCommandService
from app.services.aaii_sentiment_service import AAIISentimentService
from app.services.fear_greed_service import FearGreedService


router = APIRouter(
    prefix="/api/market-command",
    tags=["market-command"],
    dependencies=[Depends(verify_credentials)],
)


@router.get("/summary")
def get_market_command_summary(
    observation_date: date = Query(default_factory=date.today),
    limit: int = Query(20, ge=1, le=100),
    market: Optional[str] = Query(None, pattern="^(ASX|US)$"),
) -> Dict[str, Any]:
    return MarketCommandService().get_summary(observation_date, limit, market)


@router.get("/regime")
def get_market_regime(
    market: str = Query("US", pattern="^(ASX|US)$"),
    observation_date: date = Query(default_factory=date.today),
) -> Dict[str, Any]:
    return MarketCommandService().get_regime(observation_date, market)


@router.get("/sentiment")
def get_market_sentiment(
    observation_date: date = Query(default_factory=date.today),
) -> Dict[str, Any]:
    return AAIISentimentService().get_insight(observation_date)


@router.get("/fear-greed")
def get_fear_greed(
    observation_date: date = Query(default_factory=date.today),
) -> Dict[str, Any]:
    return FearGreedService().get_insight(observation_date)


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
