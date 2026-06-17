from typing import Any, Dict, Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field, field_validator

from app.routers.auth import verify_credentials
from app.services.option_orders_service import estimate_option_price, get_option_chain, get_option_expirations


router = APIRouter(prefix="/api/option-orders", tags=["option-orders"], dependencies=[Depends(verify_credentials)])


class EstimateOptionRequest(BaseModel):
    symbol: str = Field(..., min_length=1)
    expiry: str = Field(..., min_length=8, max_length=8)
    strike: float = Field(..., gt=0)
    right: Literal["P", "C"]
    target_underlying_price: float = Field(..., gt=0)

    @field_validator("symbol")
    @classmethod
    def normalize_symbol(cls, value: str) -> str:
        return value.strip().upper()

    @field_validator("right")
    @classmethod
    def normalize_right(cls, value: str) -> str:
        return value.upper()


@router.get("/expirations")
def option_expirations(symbol: str = Query(..., min_length=1)) -> Dict[str, Any]:
    try:
        return get_option_expirations(symbol=symbol)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to load IB option expirations: {exc}")


@router.get("/chain")
def option_chain(
    symbol: str = Query(..., min_length=1),
    right: Literal["P", "C", "ALL"] = Query("P"),
    max_expiries: int = Query(8, ge=1, le=24),
    strike_window_pct: float = Query(0.25, ge=0.01, le=2.0),
    expiry: str | None = Query(default=None, min_length=8, max_length=8),
) -> Dict[str, Any]:
    try:
        return get_option_chain(
            symbol=symbol,
            right=right,
            max_expiries=max_expiries,
            strike_window_pct=strike_window_pct,
            expiry=expiry,
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to load IB option chain: {exc}")


@router.post("/estimate")
def estimate_option(payload: EstimateOptionRequest) -> Dict[str, Any]:
    try:
        return estimate_option_price(
            symbol=payload.symbol,
            expiry=payload.expiry,
            strike=payload.strike,
            right=payload.right,
            target_underlying_price=payload.target_underlying_price,
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to estimate option price: {exc}")
