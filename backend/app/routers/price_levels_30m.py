from datetime import date
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel

from app.routers.auth import verify_credentials
from app.services.price_level_groups_service import PriceLevelGroupsService
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


class PriceLevelGroupPayload(BaseModel):
    name: str
    description: Optional[str] = None
    is_default: bool = False
    stock_codes: List[str] = []


@router.get("")
def price_levels_30m(
    observation_date: Optional[date] = Query(default=None),
    group_id: Optional[int] = Query(default=None, ge=1),
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
        group_service = PriceLevelGroupsService()
        group = group_service.get_group(group_id) if group_id else group_service.get_default_group()
        if group_id and (not group or not group["is_active"]):
            raise HTTPException(status_code=404, detail="Price level group not found")
        stock_codes = group_service.get_group_stock_codes(group["id"]) if group else None
        return get_30m_support_resistance(
            observation_date=observation_date,
            lookback_days=lookback_days,
            minimum_distance_atr=minimum_distance_atr,
            maximum_distance_atr=maximum_distance_atr,
            stock_codes=stock_codes,
            group=group,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to calculate 30-minute price levels: {exc}")


@router.get("/groups")
def list_price_level_groups() -> Dict[str, Any]:
    try:
        groups = PriceLevelGroupsService().list_groups()
        return {"groups": groups, "count": len(groups)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to list price level groups: {exc}")


@router.post("/groups")
def create_price_level_group(payload: PriceLevelGroupPayload) -> Dict[str, Any]:
    try:
        group = PriceLevelGroupsService().upsert_group(
            name=payload.name,
            description=payload.description,
            is_default=payload.is_default,
            stock_codes=payload.stock_codes,
        )
        return {"group": group}
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to create price level group: {exc}")


@router.put("/groups/{group_id}")
def update_price_level_group(group_id: int, payload: PriceLevelGroupPayload) -> Dict[str, Any]:
    try:
        group = PriceLevelGroupsService().upsert_group(
            group_id=group_id,
            name=payload.name,
            description=payload.description,
            is_default=payload.is_default,
            stock_codes=payload.stock_codes,
        )
        return {"group": group}
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to update price level group: {exc}")


@router.delete("/groups/{group_id}")
def delete_price_level_group(group_id: int) -> Dict[str, Any]:
    try:
        deleted = PriceLevelGroupsService().delete_group(group_id)
        if not deleted:
            raise HTTPException(status_code=404, detail="Group not found")
        return {"deleted": True}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to delete price level group: {exc}")


@router.get("/available-stocks")
def list_price_level_available_stocks() -> Dict[str, Any]:
    try:
        stocks = PriceLevelGroupsService().list_available_stocks()
        return {"stocks": stocks, "count": len(stocks)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to list available stocks: {exc}")
