"""
GEX Auto Insight Router

API endpoints for managing automatic GEX insight processing.
"""

from fastapi import APIRouter, HTTPException, Query, Depends
from pydantic import BaseModel
from typing import Dict, Any, Optional, List
from datetime import date, datetime
from app.routers.auth import verify_credentials
from app.services.gex_auto_insight_service import GEXAutoInsightService
import logging

router = APIRouter(prefix="/api/gex-auto-insight", tags=["gex-auto-insight"])
logger = logging.getLogger("app.gex_auto_insight")


class StockConfigCreate(BaseModel):
    """Request model for creating/updating stock configuration."""
    stock_code: str
    display_name: Optional[str] = None
    is_active: bool = True
    priority: int = 0
    llm_model: Optional[str] = None


class StockConfigUpdate(BaseModel):
    """Request model for updating stock configuration."""
    display_name: Optional[str] = None
    is_active: Optional[bool] = None
    priority: Optional[int] = None
    llm_model: Optional[str] = None


# ============================================================================
# Stock Configuration Endpoints
# ============================================================================

@router.get("/stocks")
def list_configured_stocks(
    active_only: bool = Query(True, description="Only return active stocks"),
    username: str = Depends(verify_credentials)
) -> Dict[str, Any]:
    """
    Get the list of stocks configured for automatic GEX insight processing.
    """
    service = GEXAutoInsightService()
    stocks = service.get_configured_stocks(active_only=active_only)

    return {
        "stocks": stocks,
        "count": len(stocks),
        "active_only": active_only
    }


@router.post("/stocks")
def add_stock(
    payload: StockConfigCreate,
    username: str = Depends(verify_credentials)
) -> Dict[str, Any]:
    """
    Add or update a stock in the auto-insight configuration.
    """
    service = GEXAutoInsightService()
    result = service.upsert_stock(
        stock_code=payload.stock_code,
        display_name=payload.display_name,
        is_active=payload.is_active,
        priority=payload.priority,
        llm_model=payload.llm_model
    )

    if not result:
        raise HTTPException(status_code=500, detail="Failed to add/update stock configuration")

    return {
        "message": "Stock configuration saved",
        "stock": result
    }


@router.put("/stocks/{stock_code}")
def update_stock(
    stock_code: str,
    payload: StockConfigUpdate,
    username: str = Depends(verify_credentials)
) -> Dict[str, Any]:
    """
    Update a stock's configuration.
    """
    service = GEXAutoInsightService()

    # Get existing config first
    stocks = service.get_configured_stocks(active_only=False)
    existing = next((s for s in stocks if s["StockCode"].upper() == stock_code.upper()), None)

    if not existing:
        raise HTTPException(status_code=404, detail=f"Stock {stock_code} not found in configuration")

    # Merge with existing values
    result = service.upsert_stock(
        stock_code=stock_code,
        display_name=payload.display_name if payload.display_name is not None else existing.get("DisplayName"),
        is_active=payload.is_active if payload.is_active is not None else existing.get("IsActive", True),
        priority=payload.priority if payload.priority is not None else existing.get("Priority", 0),
        llm_model=payload.llm_model if payload.llm_model is not None else existing.get("LLMModel")
    )

    if not result:
        raise HTTPException(status_code=500, detail="Failed to update stock configuration")

    return {
        "message": "Stock configuration updated",
        "stock": result
    }


@router.delete("/stocks/{stock_code}")
def delete_stock(
    stock_code: str,
    username: str = Depends(verify_credentials)
) -> Dict[str, Any]:
    """
    Remove a stock from the auto-insight configuration.
    """
    service = GEXAutoInsightService()
    deleted = service.delete_stock(stock_code)

    if not deleted:
        raise HTTPException(status_code=404, detail=f"Stock {stock_code} not found or could not be deleted")

    return {
        "message": f"Stock {stock_code} removed from configuration",
        "deleted": True
    }


# ============================================================================
# Processing Status Endpoints
# ============================================================================

@router.get("/status")
def get_processing_status(
    target_date: Optional[date] = Query(None, description="Date to check status for (defaults to today)"),
    username: str = Depends(verify_credentials)
) -> Dict[str, Any]:
    """
    Get the processing status for all configured stocks on a given date.

    Returns which stocks have GEX data available, which have been processed,
    and which are pending processing.
    """
    if target_date is None:
        target_date = date.today()

    service = GEXAutoInsightService()
    status = service.get_processing_status(target_date)

    return status


# ============================================================================
# Processing Endpoints
# ============================================================================

@router.post("/process")
def process_pending_stocks(
    target_date: Optional[date] = Query(None, description="Date to process (defaults to today)"),
    dry_run: bool = Query(False, description="Preview what would be processed without actually processing"),
    username: str = Depends(verify_credentials)
) -> Dict[str, Any]:
    """
    Process all pending stocks that have GEX data available.

    This is the main endpoint called by the scheduler every 5 minutes.
    It checks which configured stocks have new GEX data and generates
    LLM predictions for those that haven't been processed yet.
    """
    if target_date is None:
        target_date = date.today()

    logger.info(f"Process request for {target_date} (dry_run={dry_run}) by {username}")

    service = GEXAutoInsightService()
    result = service.process_all_pending(target_date, dry_run=dry_run)

    return result


@router.post("/process/{stock_code}")
def process_single_stock(
    stock_code: str,
    target_date: Optional[date] = Query(None, description="Date to process (defaults to today)"),
    force: bool = Query(False, description="Force regeneration even if already processed"),
    model: Optional[str] = Query(None, description="LLM model to use (overrides stock config)"),
    username: str = Depends(verify_credentials)
) -> Dict[str, Any]:
    """
    Process a single stock for GEX insight generation.

    Useful for manual processing or reprocessing a specific stock.
    """
    if target_date is None:
        target_date = date.today()

    logger.info(f"Process single stock {stock_code} for {target_date} (force={force}) by {username}")

    service = GEXAutoInsightService()
    result = service.process_stock(
        stock_code=stock_code,
        target_date=target_date,
        model=model,
        force_regenerate=force
    )

    if not result["success"] and not result.get("cached"):
        raise HTTPException(
            status_code=400 if "No GEX data" in str(result.get("error", "")) else 500,
            detail=result.get("error", "Processing failed")
        )

    return result
