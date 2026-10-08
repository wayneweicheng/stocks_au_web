from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Any, Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field, field_validator, model_validator

from app.core.scheduler import trigger_job_now
from app.routers.auth import verify_credentials
from app.services.volatility_options_alerts import VolatilityOptionsAlertService
from app.services.skill_runner_client import call_skill_runner
from app.services.volatility_options_historical import build_historical_dataset, HistoricalDatasetError
from app.services.volatility_options_monitor import monitor_open_positions, portfolio_risk_snapshot
from app.services.volatility_options_persistence import VolatilityOptionsStore

router = APIRouter(prefix="/api/volatility-options", tags=["volatility-options"])


class ManualPositionCreate(BaseModel):
    run_id: str | None = Field(default=None, max_length=100)
    candidate_id: int | None = Field(default=None, gt=0)
    symbol: str = Field(..., min_length=1, max_length=20)
    strategy: Literal["short_put", "bull_put_spread"]
    short_option: str = Field(..., min_length=1, max_length=100)
    long_option: str | None = Field(default=None, max_length=100)
    expiration: date
    short_strike: float = Field(..., gt=0)
    long_strike: float | None = Field(default=None, gt=0)
    quantity: int = Field(default=1, gt=0, le=1000)
    entry_credit: float = Field(..., ge=0)
    entry_spot: float | None = Field(default=None, gt=0)
    profit_capture_target: float = Field(default=0.60, gt=0, lt=1)
    time_exit_dte: int = Field(default=14, ge=0, le=60)
    risk_delta_exit: float = Field(default=0.45, gt=0, le=1)
    notes: str | None = Field(default=None, max_length=2000)

    @field_validator("symbol")
    @classmethod
    def normalize_symbol(cls, value: str) -> str:
        return value.strip().upper().removesuffix(".US")

    @model_validator(mode="after")
    def validate_structure(self) -> "ManualPositionCreate":
        if self.strategy == "bull_put_spread" and (not self.long_option or self.long_strike is None):
            raise ValueError("bull_put_spread requires long_option and long_strike")
        if self.strategy == "bull_put_spread" and self.long_strike >= self.short_strike:
            raise ValueError("long_strike must be below short_strike")
        return self


class HistoricalBacktestCreate(BaseModel):
    symbols: str = Field(..., min_length=1, max_length=200)
    start_date: date
    end_date: date
    account_equity: float = Field(..., gt=0)
    event_clear_symbols: str = Field(default="", max_length=200)
    top_n: int = Field(default=3, ge=1, le=10)
    dte_min: int = Field(default=30, ge=21, le=60)
    dte_max: int = Field(default=55, ge=21, le=60)
    min_vol_edge: float = Field(default=0.02, ge=0, le=1)
    risk_budget_pct: float = Field(default=0.02, gt=0, le=0.10)
    max_assignment_exposure_pct: float = Field(default=0.75, gt=0, le=3)

    @model_validator(mode="after")
    def validate_dates(self) -> "HistoricalBacktestCreate":
        if self.end_date < self.start_date:
            raise ValueError("end_date must be on or after start_date")
        if (self.end_date - self.start_date).days > 370:
            raise ValueError("historical range cannot exceed 370 days")
        return self


class KillSwitchUpdate(BaseModel):
    active: bool
    reason: str = Field(..., min_length=1, max_length=2000)


class ScheduleUpdate(BaseModel):
    enabled: bool = False
    symbols: str = Field(..., min_length=1, max_length=1000)
    event_clear_symbols: str = Field(default="", max_length=1000)
    account_equity: float = Field(..., gt=0)
    assignment_exposure: float = Field(default=0, ge=0)
    top_n: int = Field(default=10, ge=1, le=25)
    dte_min: int = Field(default=30, ge=21, le=60)
    dte_max: int = Field(default=55, ge=21, le=60)
    min_vol_edge: float = Field(default=0.02, ge=0, le=1)
    risk_budget_pct: float = Field(default=0.02, gt=0, le=0.10)
    max_assignment_exposure_pct: float = Field(default=0.75, gt=0, le=3)
    timezone: str = Field(default="America/New_York", max_length=80)

    @model_validator(mode="after")
    def validate_dte(self) -> "ScheduleUpdate":
        if self.dte_min > self.dte_max:
            raise ValueError("dte_min must be on or before dte_max")
        return self


def _serialize_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result = []
    for row in rows:
        result.append({key: value.isoformat() if hasattr(value, "isoformat") else value for key, value in row.items()})
    return result


@router.post("/historical-dataset-backtest")
def create_historical_dataset_backtest(
    payload: HistoricalBacktestCreate,
    username: str = Depends(verify_credentials),
) -> dict[str, Any]:
    try:
        dataset = build_historical_dataset(
            symbols=payload.symbols,
            start_date=payload.start_date.isoformat(),
            end_date=payload.end_date.isoformat(),
            account_equity=payload.account_equity,
            event_clear_symbols=payload.event_clear_symbols,
            top_n=payload.top_n,
            dte_min=payload.dte_min,
            dte_max=payload.dte_max,
            min_vol_edge=payload.min_vol_edge,
            risk_budget_pct=payload.risk_budget_pct,
            max_assignment_exposure_pct=payload.max_assignment_exposure_pct,
        )
        import uuid
        run_id = f"vso-dataset-{uuid.uuid4().hex}"
        VolatilityOptionsStore().save_backtest_dataset(dataset, run_id)
        job = call_skill_runner(
            "POST",
            "/api/jobs/volatility-selective-backtest",
            {"dataset": dataset},
        )
        return {"run_id": run_id, "job": job, "coverage": dataset.get("coverage"), "snapshot_count": len(dataset.get("snapshots") or [])}
    except HistoricalDatasetError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Historical dataset/backtest preparation failed: {exc}") from exc


@router.get("/scans")
def list_scans(limit: int = Query(50, ge=1, le=500), username: str = Depends(verify_credentials)) -> dict[str, Any]:
    return {"items": _serialize_rows(VolatilityOptionsStore().list_scans(limit))}


@router.get("/candidates")
def list_candidates(
    run_id: str | None = Query(default=None, max_length=100),
    limit: int = Query(100, ge=1, le=500),
    username: str = Depends(verify_credentials),
) -> dict[str, Any]:
    return {"items": _serialize_rows(VolatilityOptionsStore().list_candidates(run_id, limit))}


@router.get("/positions")
def list_positions(
    status: str | None = Query(default="OPEN", max_length=20),
    username: str = Depends(verify_credentials),
) -> dict[str, Any]:
    return {"items": _serialize_rows(VolatilityOptionsStore().list_manual_positions(status))}


@router.post("/positions")
def create_position(payload: ManualPositionCreate, username: str = Depends(verify_credentials)) -> dict[str, Any]:
    # This endpoint records a position entered manually by the operator. It does
    # not call IB order APIs and cannot submit, cancel, or modify an order.
    store = VolatilityOptionsStore()
    position_id = store.create_manual_position(payload.model_dump())
    return {"position_id": position_id, "status": "OPEN", "broker_action": "none"}


@router.post("/positions/{position_id}/close")
def close_position(position_id: int, username: str = Depends(verify_credentials)) -> dict[str, Any]:
    store = VolatilityOptionsStore()
    store.update_manual_position(
        position_id,
        {
            "status": "CLOSED",
            "closed_at": datetime.now(timezone.utc),
            "close_reason": "Manually marked closed in the dashboard",
            "exit_recommendation": "CLOSED_MANUALLY",
        },
    )
    return {"position_id": position_id, "status": "CLOSED", "broker_action": "none"}


@router.post("/monitor")
def monitor_positions(username: str = Depends(verify_credentials)) -> dict[str, Any]:
    return monitor_open_positions()


@router.get("/risk")
def portfolio_risk(username: str = Depends(verify_credentials)) -> dict[str, Any]:
    return portfolio_risk_snapshot()


@router.get("/alerts")
def list_alerts(limit: int = Query(100, ge=1, le=500), username: str = Depends(verify_credentials)) -> dict[str, Any]:
    return {"items": _serialize_rows(VolatilityOptionsAlertService().list_alerts(limit))}


@router.get("/safety")
def get_safety(username: str = Depends(verify_credentials)) -> dict[str, Any]:
    store = VolatilityOptionsStore()
    return {key: value.isoformat() if hasattr(value, "isoformat") else value for key, value in store.get_safety_state().items()}


@router.post("/safety/kill-switch")
def update_kill_switch(payload: KillSwitchUpdate, username: str = Depends(verify_credentials)) -> dict[str, Any]:
    try:
        result = VolatilityOptionsStore().set_kill_switch(payload.active, payload.reason, username)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to update the safety state; execute the supplied DDL first: {exc}") from exc
    return {key: value.isoformat() if hasattr(value, "isoformat") else value for key, value in result.items()}


@router.get("/schedule")
def get_schedule(username: str = Depends(verify_credentials)) -> dict[str, Any]:
    schedule = VolatilityOptionsStore().get_schedule() or {
        "ScheduleName": "default",
        "Enabled": False,
        "Symbols": "SPY,QQQ,IWM",
        "EventClearSymbols": "SPY,QQQ,IWM",
        "AccountEquity": None,
    }
    return {key: value.isoformat() if hasattr(value, "isoformat") else value for key, value in schedule.items()}


@router.put("/schedule")
def update_schedule(payload: ScheduleUpdate, username: str = Depends(verify_credentials)) -> dict[str, Any]:
    try:
        schedule = VolatilityOptionsStore().upsert_schedule(payload.model_dump())
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to persist schedule; execute the supplied DDL first: {exc}") from exc
    return {key: value.isoformat() if hasattr(value, "isoformat") else value for key, value in schedule.items()}


@router.post("/schedule/run-now")
def run_schedule_now(username: str = Depends(verify_credentials)) -> dict[str, Any]:
    if not trigger_job_now("volatility_selective_scan"):
        raise HTTPException(status_code=404, detail="Volatility-selective scheduler job is not registered")
    return {"triggered": True, "job_id": "volatility_selective_scan"}
