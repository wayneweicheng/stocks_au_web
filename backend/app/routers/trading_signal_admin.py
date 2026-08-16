from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.repositories.trading_signal_admin import ProductionDeploymentNotFound, TradingSignalAdminRepository
from app.routers.auth import verify_admin
from app.schemas.trading_signal_admin import AdminDeployment, AdminStrategyPage, ProductionToggleRequest


router = APIRouter(
    prefix="/api/trading-signal-reports/admin",
    tags=["trading-signal-admin"],
    dependencies=[Depends(verify_admin)],
)


@router.get("/strategies", response_model=AdminStrategyPage)
def list_admin_strategies() -> AdminStrategyPage:
    return AdminStrategyPage(**TradingSignalAdminRepository().list_strategies())


@router.patch("/deployments/{deployment_id}/production-toggle", response_model=AdminDeployment)
def set_production_toggle(deployment_id: int, request: ProductionToggleRequest, username: str = Depends(verify_admin)) -> AdminDeployment:
    try:
        row = TradingSignalAdminRepository().set_production_enabled(deployment_id, request.enabled, username)
    except ProductionDeploymentNotFound as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return AdminDeployment(**row)

