from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query

from app.repositories.trading_signal_admin import ProductionDeploymentNotFound, TradingSignalAdminRepository
from app.routers.auth import verify_admin
from app.schemas.trading_signal_admin import AdminDeployment, AdminStrategyPage, ProductionToggleRequest


router = APIRouter(
    prefix="/api/trading-signal-reports/admin",
    tags=["trading-signal-admin"],
    dependencies=[Depends(verify_admin)],
)


@router.get("/strategies", response_model=AdminStrategyPage)
def list_admin_strategies(
    stock_code: str | None = Query(default=None),
    signal_code: str | None = Query(default=None),
) -> AdminStrategyPage:
    return AdminStrategyPage(**TradingSignalAdminRepository().list_strategies(stock_code=stock_code, signal_code=signal_code))


@router.patch("/deployments/{deployment_id}/production-toggle", response_model=AdminDeployment)
def set_production_toggle(deployment_id: int, request: ProductionToggleRequest, username: str = Depends(verify_admin)) -> AdminDeployment:
    try:
        row = TradingSignalAdminRepository().set_production_enabled(deployment_id, request.enabled, username)
    except ProductionDeploymentNotFound as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return AdminDeployment(**row)

