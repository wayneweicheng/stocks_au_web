from __future__ import annotations

import asyncio
from concurrent.futures import ThreadPoolExecutor
import logging
from threading import Lock
from datetime import date
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from pydantic import BaseModel, Field

from app.routers.auth import verify_credentials
from app.services.stock_analysis.analysis_service import (
    DEFAULT_STOCK_ANALYSIS_MODEL,
    create_processing_record,
    get_active_processing,
    get_processing_status,
    get_report,
    list_tipped_stocks_for_analysis,
    normalize_stock_code,
    run_stock_analysis,
)

router = APIRouter(prefix="/api/stock-analysis", tags=["stock-analysis"])
logger = logging.getLogger("app.stock_analysis.router")
_stock_analysis_executor = ThreadPoolExecutor(max_workers=4, thread_name_prefix="stock-analysis")
_submitted_processing_ids: set[int] = set()
_submission_lock = Lock()


class StockAnalysisTippedStock(BaseModel):
    stock_code: str
    total_ratings: int
    bullish_count: int
    latest_rating_date: Optional[str] = None
    avg_trade_value_5d: Optional[float] = None
    latest_analysis_date: Optional[str] = None
    overall_score: Optional[int] = None
    overall_rating: Optional[str] = None
    processing_status: Optional[str] = None
    processing_id: Optional[int] = None


class StockAnalysisTippedStocksResponse(BaseModel):
    items: List[StockAnalysisTippedStock]


class StockAnalysisProcessRequest(BaseModel):
    stock_code: str = Field(..., min_length=1)
    observation_date: date
    model: str = DEFAULT_STOCK_ANALYSIS_MODEL


class StockAnalysisProcessResponse(BaseModel):
    processing_id: int
    status: str
    stock_code: str
    observation_date: str
    model: str
    report_available: bool = False


class StockAnalysisStatusResponse(BaseModel):
    processing_id: int
    stock_code: str
    observation_date: Optional[str] = None
    status: str
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    error_message: Optional[str] = None
    requested_by: Optional[str] = None
    model: Optional[str] = None
    report_available: bool = False


class StockAnalysisReportResponse(BaseModel):
    report_id: int
    stock_code: str
    observation_date: Optional[str] = None
    report_markdown: Optional[str] = None
    report_json: Optional[Dict[str, Any]] = None
    model: Optional[str] = None
    status: Optional[str] = None
    processed_at: Optional[str] = None
    processed_by: Optional[str] = None
    tokens_used: Optional[int] = None
    processing_time_seconds: Optional[float] = None


class StockAnalysisBulkProcessRequest(BaseModel):
    stock_codes: List[str] = Field(..., min_length=1)
    observation_date: date
    model: str = DEFAULT_STOCK_ANALYSIS_MODEL


class StockAnalysisBulkProcessResponse(BaseModel):
    total_submitted: int
    processing_ids: List[int]
    stock_codes: List[str]


def _run_stock_analysis_task(
    processing_id: int,
    stock_code: str,
    observation_date: date,
    model: str,
    requested_by: Optional[str],
) -> None:
    asyncio.run(
        run_stock_analysis(
            processing_id=processing_id,
            stock_code=stock_code,
            observation_date=observation_date,
            model=model,
            requested_by=requested_by,
        )
    )


def _run_stock_analysis_task_and_release(
    processing_id: int,
    stock_code: str,
    observation_date: date,
    model: str,
    requested_by: Optional[str],
) -> None:
    try:
        _run_stock_analysis_task(
            processing_id=processing_id,
            stock_code=stock_code,
            observation_date=observation_date,
            model=model,
            requested_by=requested_by,
        )
    finally:
        with _submission_lock:
            _submitted_processing_ids.discard(processing_id)


def submit_stock_analysis_task(
    processing_id: int,
    stock_code: str,
    observation_date: date,
    model: str,
    requested_by: Optional[str],
) -> bool:
    """
    Submit processing work to the in-process executor.

    Returns True when a task was newly submitted, False when the processing_id
    is already queued/running in this backend process.
    """
    with _submission_lock:
        if processing_id in _submitted_processing_ids:
            return False
        _submitted_processing_ids.add(processing_id)

    _stock_analysis_executor.submit(
        _run_stock_analysis_task_and_release,
        processing_id,
        stock_code,
        observation_date,
        model,
        requested_by,
    )
    return True


@router.get("/tipped-stocks", response_model=StockAnalysisTippedStocksResponse)
def tipped_stocks(
    observation_date: Optional[date] = None,
    username: str = Depends(verify_credentials)
) -> StockAnalysisTippedStocksResponse:
    del username
    try:
        logger.info("Fetching tipped stocks for observation_date=%s", observation_date)
        items = list_tipped_stocks_for_analysis(observation_date)
        logger.info("Found %d tipped stocks", len(items))
        return StockAnalysisTippedStocksResponse(items=items)
    except Exception as exc:
        logger.exception("Failed to list stock-analysis tipped stocks for date %s", observation_date)
        raise HTTPException(status_code=500, detail=f"Failed to list tipped stocks: {exc}")


@router.post("/process", response_model=StockAnalysisProcessResponse)
def process_stock_analysis(
    payload: StockAnalysisProcessRequest,
    background_tasks: BackgroundTasks,
    username: str = Depends(verify_credentials),
) -> StockAnalysisProcessResponse:
    del background_tasks
    normalized_code = normalize_stock_code(payload.stock_code)
    if not normalized_code:
        raise HTTPException(status_code=400, detail="stock_code is required")

    try:
        active = get_active_processing(normalized_code, payload.observation_date)
        if active:
            submit_stock_analysis_task(
                processing_id=int(active["processing_id"]),
                stock_code=str(active["stock_code"]),
                observation_date=active["observation_date"],
                model=str(active.get("model") or payload.model),
                requested_by=str(active.get("requested_by") or username),
            )
            existing_report = get_report(normalized_code, payload.observation_date)
            return StockAnalysisProcessResponse(
                processing_id=int(active["processing_id"]),
                status=str(active["status"]),
                stock_code=str(active["stock_code"]),
                observation_date=str(active["observation_date"]),
                model=str(active.get("model") or payload.model),
                report_available=existing_report is not None,
            )

        processing_id = create_processing_record(
            stock_code=normalized_code,
            observation_date=payload.observation_date,
            requested_by=username,
            model=payload.model,
        )
        submit_stock_analysis_task(
            processing_id,
            normalized_code,
            payload.observation_date,
            payload.model,
            username,
        )
        existing_report = get_report(normalized_code, payload.observation_date)
        return StockAnalysisProcessResponse(
            processing_id=processing_id,
            status="Pending",
            stock_code=normalized_code,
            observation_date=payload.observation_date.isoformat(),
            model=payload.model,
            report_available=existing_report is not None,
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Failed to queue stock analysis")
        raise HTTPException(status_code=500, detail=f"Failed to queue stock analysis: {exc}")


@router.get("/status/{processing_id}", response_model=StockAnalysisStatusResponse)
def stock_analysis_status(
    processing_id: int,
    username: str = Depends(verify_credentials),
) -> StockAnalysisStatusResponse:
    del username
    row = get_processing_status(processing_id)
    if not row:
        raise HTTPException(status_code=404, detail="Processing record not found")
    return StockAnalysisStatusResponse(**row)


@router.get("/report/{stock_code}/{observation_date}", response_model=StockAnalysisReportResponse)
def stock_analysis_report(
    stock_code: str,
    observation_date: date,
    username: str = Depends(verify_credentials),
) -> StockAnalysisReportResponse:
    del username
    row = get_report(stock_code, observation_date)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    return StockAnalysisReportResponse(**row)


@router.post("/process-bulk", response_model=StockAnalysisBulkProcessResponse)
def process_bulk_stock_analysis(
    payload: StockAnalysisBulkProcessRequest,
    background_tasks: BackgroundTasks,
    username: str = Depends(verify_credentials),
) -> StockAnalysisBulkProcessResponse:
    del background_tasks
    if not payload.stock_codes:
        raise HTTPException(status_code=400, detail="At least one stock code is required")

    processing_ids = []
    submitted_codes = []

    for stock_code in payload.stock_codes:
        normalized_code = normalize_stock_code(stock_code)
        if not normalized_code:
            logger.warning("Skipping invalid stock code: %s", stock_code)
            continue

        try:
            active = get_active_processing(normalized_code, payload.observation_date)
            if active:
                submit_stock_analysis_task(
                    processing_id=int(active["processing_id"]),
                    stock_code=str(active["stock_code"]),
                    observation_date=active["observation_date"],
                    model=str(active.get("model") or payload.model),
                    requested_by=str(active.get("requested_by") or username),
                )
                processing_ids.append(int(active["processing_id"]))
                submitted_codes.append(normalized_code)
                continue

            processing_id = create_processing_record(
                stock_code=normalized_code,
                observation_date=payload.observation_date,
                requested_by=username,
                model=payload.model,
            )
            submit_stock_analysis_task(
                processing_id,
                normalized_code,
                payload.observation_date,
                payload.model,
                username,
            )
            processing_ids.append(processing_id)
            submitted_codes.append(normalized_code)
        except Exception as exc:
            logger.exception("Failed to queue stock analysis for %s", normalized_code)

    if not processing_ids:
        raise HTTPException(status_code=400, detail="No valid stocks could be queued for processing")

    return StockAnalysisBulkProcessResponse(
        total_submitted=len(processing_ids),
        processing_ids=processing_ids,
        stock_codes=submitted_codes,
    )
