from datetime import datetime
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator

from app.routers.auth import verify_credentials
from app.services.bet_odds_monitor_service import (
    BetOddsMonitorService,
    discover_markets,
    parse_tab_match_url,
)


router = APIRouter(
    prefix="/api/bet-odds-monitors",
    tags=["bet-odds-monitors"],
    dependencies=[Depends(verify_credentials)],
)


class MarketDiscoveryRequest(BaseModel):
    source_url: str = Field(min_length=10, max_length=1000)

    @field_validator("source_url")
    @classmethod
    def validate_source_url(cls, value: str) -> str:
        parse_tab_match_url(value)
        return value.strip()


class CriterionPayload(BaseModel):
    market_name: str = Field(min_length=1, max_length=250)
    selection_name: str = Field(min_length=1, max_length=250)
    proposition_id: str | None = Field(default=None, max_length=100)
    comparison_operator: Literal[">=", ">", "<=", "<", "="] = ">="
    target_odds: float = Field(gt=0, le=100000)


class MonitorPayload(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    source_url: str = Field(min_length=10, max_length=1000)
    target_user_id: int = Field(gt=0)
    scan_interval_minutes: int = Field(default=10, ge=1, le=1440)
    expires_at_sydney: datetime
    alert_once: bool = True
    is_active: bool = True
    criteria: list[CriterionPayload] = Field(min_length=1, max_length=50)

    @field_validator("source_url")
    @classmethod
    def validate_source_url(cls, value: str) -> str:
        parse_tab_match_url(value)
        return value.strip()


def _service() -> BetOddsMonitorService:
    return BetOddsMonitorService()


@router.get("")
def list_monitors():
    return _service().list_monitors()


@router.post("/discover")
def discover(payload: MarketDiscoveryRequest):
    try:
        return discover_markets(payload.source_url)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.post("")
def create_monitor(payload: MonitorPayload):
    try:
        return _service().create_monitor(payload.model_dump())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.put("/{monitor_id}")
def update_monitor(monitor_id: int, payload: MonitorPayload):
    try:
        return _service().update_monitor(monitor_id, payload.model_dump())
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.delete("/{monitor_id}", status_code=204)
def delete_monitor(monitor_id: int):
    try:
        _service().delete_monitor(monitor_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/{monitor_id}/scan")
def scan_monitor(monitor_id: int):
    try:
        return _service().scan_monitor(monitor_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

