from datetime import date, datetime, time, timedelta, timezone
from concurrent.futures import ThreadPoolExecutor
from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, List, Optional, Set
from zoneinfo import ZoneInfo
import json
import logging
import threading

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field, model_validator

from app.routers.auth import verify_credentials
from app.routers.index_stock_price_mapping import get_stock_map_prices
from app.services.index_bottom_state_timeline import (
    calculate_returns as calculate_index_bottom_returns,
    load_price_rows as load_index_bottom_price_rows,
    parse_as_at as parse_index_bottom_as_at,
    parse_report_state as parse_index_bottom_state,
    report_as_at as report_index_bottom_as_at,
)
from app.services.stock_map_comparison_service import (
    SYMBOL, build_comparison_payload, build_comparison_prompt, runner_comparison_payload,
)
from app.services.stock_map_option_snapshot import load_d1_option_rows
from app.spx_gex_strategy.calendar import USCashCalendar
from app.services.skill_runner_client import (
    call_skill_runner,
    extract_report_content,
    extract_report_items,
    get_first_value,
    get_job_json,
    get_job_report,
    list_reports,
)
from app.services.volatility_options_service import build_scan_snapshot


router = APIRouter(prefix="/api", tags=["skill-report-pages"])
DELETED_REPORTS_PATH = Path(__file__).resolve().parents[2] / "data" / "deleted_skill_reports.json"
_DELETED_REPORTS_LOCK = threading.Lock()
_REPORT_SUMMARY_CACHE: Dict[tuple[str, str], "SkillReportSummary"] = {}
_REPORT_SUMMARY_CACHE_LOCK = threading.Lock()
logger = logging.getLogger(__name__)

SKILLS = {
    "shiso-leaf-stock-hunter": {
        "title": "Shiso Leaf Stock Hunter",
        "route": "shiso-leaf-stock-hunter",
    },
    "stock-social-sentiment": {
        "title": "Stock Social Sentiment",
        "route": "stock-social-sentiment",
    },
    "analyze-option-flow": {
        "title": "Option Flow Analysis",
        "route": "analyze-option-flow",
    },
    "analyze-option-flow-range": {
        "title": "Option Flow Analysis",
        "route": "analyze-option-flow-range",
    },
    "find-index-bottoms": {
        "title": "Find Index Bottoms",
        "route": "find-index-bottoms",
    },
    "ride-bullish-momentum": {
        "title": "Ride Bullish Momentum",
        "route": "ride-bullish-momentum",
    },
    "spx-map": {
        "title": "SPX Map",
        "route": "spx-map",
    },
    "asx-microstructure-accumulation": {
        "title": "ASX Microstructure Accumulation",
        "route": "asx-microstructure-accumulation",
    },
    "stock-map": {
        "title": "Stock Map",
        "route": "stock-map",
    },
    "stock-map-comparison": {
        "title": "Stock Map Two-Day Order Analysis",
        "route": "stock-map-comparison",
    },
    "find-bullish-call-opportunities": {
        "title": "Bullish Call Opportunities",
        "route": "find-bullish-call-opportunities",
    },
    "find-cash-secured-put-opportunities": {
        "title": "Cash-Secured Put Opportunities",
        "route": "find-cash-secured-put-opportunities",
    },
    "volatility-selective-options": {
        "title": "Volatility-Selective Options",
        "route": "volatility-selective-options",
    },
    "volatility-selective-backtest": {
        "title": "Volatility-Selective Backtest",
        "route": "volatility-selective-options/backtest",
    },
}


class SkillReportSummary(BaseModel):
    job_id: str
    title: str
    created_at: Optional[str] = None
    stock_code: Optional[str] = None
    status: Optional[str] = None
    file_name: Optional[str] = None
    file_type: Optional[str] = None
    raw: Dict[str, Any] = Field(default_factory=dict)


class SkillReportDetail(SkillReportSummary):
    content: str


class SkillReportPage(BaseModel):
    items: List[SkillReportSummary]


class ShisoLeafStockHunterJobCreate(BaseModel):
    input_text: str = Field(..., min_length=1)
    timeout_minutes: int = Field(default=90, ge=1, le=240)


class StockSocialSentimentJobCreate(BaseModel):
    stock_code: str = Field(..., min_length=1, max_length=20)
    company_name: str = Field(default="", max_length=200)
    focus: str = Field(default="", max_length=1000)
    sources: str = Field(default="reddit,xueqiu", max_length=200)
    timeout_minutes: int = Field(default=75, ge=1, le=240)


class OptionFlowAnalysisJobCreate(BaseModel):
    observation_date: str = Field(..., min_length=10, max_length=10)
    ticker: Optional[str] = Field(default=None, max_length=20)
    top_n: int = Field(default=10, ge=1, le=100)
    timeout_minutes: int = Field(default=90, ge=1, le=240)
    model: Optional[str] = Field(default=None, max_length=200)


class OptionFlowAnalysisRangeJobCreate(BaseModel):
    ticker: str = Field(..., min_length=1, max_length=20)
    start_date: str = Field(..., min_length=10, max_length=10)
    end_date: str = Field(..., min_length=10, max_length=10)
    top_n: int = Field(default=30, ge=1, le=100)


class FindIndexBottomsJobCreate(BaseModel):
    as_at: Optional[str] = Field(default=None, max_length=80)
    timeout_minutes: int = Field(default=90, ge=1, le=240)
    model: Optional[str] = Field(default=None, max_length=200)


class RideBullishMomentumJobCreate(BaseModel):
    as_at: Optional[str] = Field(default=None, max_length=80)
    timeout_minutes: int = Field(default=90, ge=1, le=240)
    model: Optional[str] = Field(default=None, max_length=200)


class SpxMapJobCreate(BaseModel):
    as_at: Optional[str] = Field(default=None, max_length=80)
    timeout_minutes: int = Field(default=120, ge=1, le=240)
    model: Optional[str] = Field(default=None, max_length=200)


class StockMapJobCreate(BaseModel):
    stock_code: str = Field(..., min_length=1, max_length=16)
    as_at: Optional[str] = Field(default=None, max_length=80)
    timeout_minutes: int = Field(default=120, ge=1, le=240)
    model: Optional[str] = Field(default=None, max_length=200)


class StockMapComparisonJobCreate(BaseModel):
    stock_code: str = Field(..., min_length=1, max_length=23)
    observation_date: date
    timeout_minutes: int = Field(default=120, ge=1, le=240)


class AsxMicrostructureAccumulationJobCreate(BaseModel):
    observation_date: Optional[str] = Field(default=None, min_length=10, max_length=10)
    stock_code: Optional[str] = Field(default=None, min_length=1, max_length=20)
    start_date: Optional[str] = Field(default=None, min_length=10, max_length=10)
    end_date: Optional[str] = Field(default=None, min_length=10, max_length=10)
    timeout_minutes: int = Field(default=90, ge=1, le=240)

    @model_validator(mode="after")
    def validate_request_mode(self) -> "AsxMicrostructureAccumulationJobCreate":
        has_observation_date = bool((self.observation_date or "").strip())
        has_stock_code = bool((self.stock_code or "").strip())
        has_start_date = bool((self.start_date or "").strip())
        has_end_date = bool((self.end_date or "").strip())
        has_range = has_start_date or has_end_date

        if has_observation_date and has_range:
            raise ValueError("use observation_date or start_date/end_date, not both")
        if has_range and (not has_stock_code or not has_start_date or not has_end_date):
            raise ValueError("stock_code, start_date, and end_date are required for range mode")
        if not has_observation_date and not has_range:
            raise ValueError("observation_date or stock_code with start_date/end_date is required")
        return self


class BullishCallOpportunitiesJobCreate(BaseModel):
    observation_date: str = Field(..., min_length=10, max_length=10)
    option_data_date: str = Field(..., min_length=10, max_length=10)
    proposed_order_date: str = Field(..., min_length=10, max_length=10)
    ticker: str = Field(..., min_length=1, max_length=20)
    top_n: int = Field(default=5, ge=1, le=100)
    constraints: str = Field(default="", max_length=2000)
    model: str = Field(default="gpt-5.6-luna", min_length=1, max_length=200)
    timeout_minutes: int = Field(default=180, ge=1, le=240)


class CashSecuredPutOpportunitiesJobCreate(BaseModel):
    observation_date: str = Field(..., min_length=10, max_length=10)
    option_data_date: str = Field(..., min_length=10, max_length=10)
    order_date: str = Field(..., min_length=10, max_length=10)
    ticker: str = Field(..., min_length=1, max_length=20)
    top_n: int = Field(default=5, ge=1, le=100)
    constraints: str = Field(default="", max_length=2000)
    model: str = Field(default="gpt-5.6-luna", min_length=1, max_length=200)
    timeout_minutes: int = Field(default=180, ge=1, le=240)


class VolatilitySelectiveBacktestJobCreate(BaseModel):
    dataset_json: str = Field(..., min_length=2, max_length=10_000_000)
    timeout_minutes: int = Field(default=30, ge=1, le=120)


class VolatilitySelectiveOptionsJobCreate(BaseModel):
    symbols: str = Field(default="SPY,QQQ,IWM", min_length=1, max_length=200)
    account_equity: float = Field(..., gt=0)
    assignment_exposure: float = Field(default=0, ge=0)
    event_clear_symbols: str = Field(
        default="SPY,QQQ,IWM",
        max_length=200,
        description="Symbols whose event calendars were independently checked. ETFs are cleared automatically.",
    )
    top_n: int = Field(default=10, ge=1, le=25)
    dte_min: int = Field(default=30, ge=21, le=60)
    dte_max: int = Field(default=55, ge=21, le=60)
    min_vol_edge: float = Field(default=0.02, ge=0, le=1)
    risk_budget_pct: float = Field(default=0.02, gt=0, le=0.10)
    max_assignment_exposure_pct: float = Field(default=0.75, gt=0, le=3.0)

    @model_validator(mode="after")
    def validate_dte_range(self) -> "VolatilitySelectiveOptionsJobCreate":
        if self.dte_min > self.dte_max:
            raise ValueError("dte_min must be on or before dte_max")
        return self


class SkillJobResponse(BaseModel):
    data: Any


class DeleteReportResponse(BaseModel):
    deleted: bool
    job_id: str
    data: Any = Field(default_factory=dict)


def _load_deleted_report_data() -> Dict[str, List[str]]:
    if not DELETED_REPORTS_PATH.exists():
        return {}

    try:
        with DELETED_REPORTS_PATH.open("r", encoding="utf-8") as file:
            data = json.load(file)
    except (OSError, json.JSONDecodeError):
        return {}

    if not isinstance(data, dict):
        return {}

    normalized: Dict[str, List[str]] = {}
    for job_type, job_ids in data.items():
        if not isinstance(job_type, str) or not isinstance(job_ids, list):
            continue
        normalized[job_type] = [str(job_id) for job_id in job_ids if job_id is not None]
    return normalized


def _save_deleted_report_data(data: Dict[str, List[str]]) -> None:
    DELETED_REPORTS_PATH.parent.mkdir(parents=True, exist_ok=True)
    temp_path = DELETED_REPORTS_PATH.with_suffix(".tmp")
    with temp_path.open("w", encoding="utf-8") as file:
        json.dump(data, file, indent=2, sort_keys=True)
    temp_path.replace(DELETED_REPORTS_PATH)


def _deleted_report_ids(job_type: str) -> Set[str]:
    return set(_load_deleted_report_data().get(job_type, []))


def _is_skill_report_deleted(job_type: str, job_id: str) -> bool:
    return job_id in _deleted_report_ids(job_type)


def _mark_skill_report_deleted(job_type: str, job_id: str) -> None:
    with _DELETED_REPORTS_LOCK:
        data = _load_deleted_report_data()
        ids = set(data.get(job_type, []))
        ids.add(job_id)
        data[job_type] = sorted(ids)
        _save_deleted_report_data(data)


def _skill_config(job_type: str) -> Dict[str, str]:
    config = SKILLS.get(job_type)
    if not config:
        raise HTTPException(status_code=404, detail="Unknown skill report type")
    return config


def _default_title(job_type: str, item: Dict[str, Any], job_id: str) -> str:
    title = get_first_value(item, ["title", "report_title", "name", "label"])
    if title:
        return str(title)

    stock_code = get_first_value(item, ["stock_code", "symbol", "ticker"])
    if stock_code:
        return f"{str(stock_code).upper()} {_skill_config(job_type)['title']}"

    return f"{_skill_config(job_type)['title']} {job_id}"


def _report_file_name(item: Dict[str, Any]) -> Optional[str]:
    value = get_first_value(
        item,
        [
            "file_name",
            "filename",
            "report_file",
            "report_filename",
            "report_path",
            "relative_path",
            "path",
            "file",
            "name",
            "report",
        ],
    )
    return str(value) if isinstance(value, (str, int, float)) else None


def _report_file_type(item: Dict[str, Any], file_name: Optional[str]) -> Optional[str]:
    value = get_first_value(
        item,
        [
            "file_type",
            "report_type",
            "format",
            "extension",
            "mime_type",
            "content_type",
            "mime",
            "type",
            "job_type",
            "jobType",
            "route",
        ],
    )
    source = " ".join(str(part) for part in (value, file_name) if part is not None).lower()
    if (
        "text/html" in source
        or ".html" in source
        or ".htm" in source
        or "html" in source
        or "analyze-option-flow-range" in source
    ):
        return "html"
    if "markdown" in source or ".md" in source or ".markdown" in source:
        return "markdown"
    return None


def _normalize_report_summary(job_type: str, item: Dict[str, Any]) -> Optional[SkillReportSummary]:
    job_id = get_first_value(item, ["job_id", "id", "jobId"])
    if job_id is None:
        return None

    stock_code = get_first_value(item, ["stock_code", "symbol", "ticker"])
    created_at = get_first_value(item, ["created_at", "completed_at", "updated_at", "createdAt", "completedAt"])
    status = get_first_value(item, ["status", "state"])
    normalized_job_id = str(job_id)
    file_name = _report_file_name(item)

    return SkillReportSummary(
        job_id=normalized_job_id,
        title=_default_title(job_type, item, normalized_job_id),
        created_at=str(created_at) if created_at is not None else None,
        stock_code=str(stock_code).upper() if stock_code is not None else None,
        status=str(status) if status is not None else None,
        file_name=file_name,
        file_type=_report_file_type(item, file_name),
        raw=item,
    )


def _list_skill_reports(job_type: str) -> SkillReportPage:
    data = list_reports(job_type)
    deleted_ids = _deleted_report_ids(job_type)
    summaries = [
        summary
        for summary in (_normalize_report_summary(job_type, item) for item in extract_report_items(data))
        if summary is not None and summary.job_id not in deleted_ids
    ]
    summaries.sort(key=lambda item: item.created_at or "", reverse=True)
    with _REPORT_SUMMARY_CACHE_LOCK:
        _REPORT_SUMMARY_CACHE.update({(job_type, item.job_id): item for item in summaries})
    return SkillReportPage(items=summaries)


OPTION_FLOW_REPORT_TYPES = ("analyze-option-flow", "analyze-option-flow-range")


def _list_option_flow_analysis_reports() -> SkillReportPage:
    reports_by_job_id: Dict[str, SkillReportSummary] = {}
    for job_type in OPTION_FLOW_REPORT_TYPES:
        try:
            page = _list_skill_reports(job_type)
        except HTTPException as exc:
            if job_type != "analyze-option-flow-range" or exc.status_code != 404:
                raise
            continue

        for item in page.items:
            current = reports_by_job_id.get(item.job_id)
            if current is None or (item.file_type and not current.file_type):
                reports_by_job_id[item.job_id] = item

    items = sorted(reports_by_job_id.values(), key=lambda item: item.created_at or "", reverse=True)
    return SkillReportPage(items=items)


def _get_skill_report(job_type: str, job_id: str) -> SkillReportDetail:
    if _is_skill_report_deleted(job_type, job_id):
        raise HTTPException(status_code=404, detail="Report has been deleted")

    # The report-list endpoint is backed by the skill runner and can be very slow.
    # A detail request already has the job id, so do not relist every report before
    # fetching the requested snapshot. Use metadata cached by a previous list call
    # when available; the report payload remains the source of truth for content.
    with _REPORT_SUMMARY_CACHE_LOCK:
        summary = _REPORT_SUMMARY_CACHE.get((job_type, job_id))
    data = get_job_report(job_id)
    payload_summary = _normalize_report_summary(job_type, data) if isinstance(data, dict) else None
    if summary is None and payload_summary is not None and payload_summary.job_id == job_id:
        summary = payload_summary

    if summary is None or summary.job_id != job_id:
        summary = SkillReportSummary(
            job_id=job_id,
            title=f"{_skill_config(job_type)['title']} {job_id}",
            created_at=datetime.now(timezone.utc).isoformat(),
        )

    return SkillReportDetail(
        **summary.model_dump(),
        content=extract_report_content(data, preferred_format=summary.file_type),
    )


def _get_option_flow_analysis_report(job_id: str) -> SkillReportDetail:
    if any(_is_skill_report_deleted(job_type, job_id) for job_type in OPTION_FLOW_REPORT_TYPES):
        raise HTTPException(status_code=404, detail="Report has been deleted")

    # The list endpoint can take longer than the frontend proxy timeout. A
    # detail request already has the job id, so fetch only that report and use
    # metadata from an earlier listing when available.
    with _REPORT_SUMMARY_CACHE_LOCK:
        cached = [_REPORT_SUMMARY_CACHE.get((job_type, job_id)) for job_type in OPTION_FLOW_REPORT_TYPES]
    summary = next((item for item in cached if item is not None and item.file_type), None)
    if summary is None:
        summary = next((item for item in cached if item is not None), None)

    data = get_job_report(job_id)
    if summary is None and isinstance(data, dict):
        payload_summary = _normalize_report_summary("analyze-option-flow", data)
        if payload_summary is not None and payload_summary.job_id == job_id:
            summary = payload_summary

    if summary is None:
        summary = SkillReportSummary(
            job_id=job_id,
            title=f"{SKILLS['analyze-option-flow']['title']} {job_id}",
            created_at=datetime.now(timezone.utc).isoformat(),
        )

    return SkillReportDetail(
        **summary.model_dump(),
        content=extract_report_content(data, preferred_format=summary.file_type),
    )


@router.get("/shiso-leaf-stock-hunter-reports", response_model=SkillReportPage)
def list_shiso_leaf_stock_hunter_reports(username: str = Depends(verify_credentials)) -> SkillReportPage:
    return _list_skill_reports("shiso-leaf-stock-hunter")


@router.get("/shiso-leaf-stock-hunter-reports/{job_id}", response_model=SkillReportDetail)
def get_shiso_leaf_stock_hunter_report(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillReportDetail:
    return _get_skill_report("shiso-leaf-stock-hunter", job_id)


@router.post("/shiso-leaf-stock-hunter/jobs", response_model=SkillJobResponse)
def create_shiso_leaf_stock_hunter_job(
    payload: ShisoLeafStockHunterJobCreate,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    data = call_skill_runner(
        "POST",
        "/api/jobs/shiso-leaf-stock-hunter",
        {
            "input_text": payload.input_text,
            "timeout_minutes": payload.timeout_minutes,
        },
    )
    return SkillJobResponse(data=data)


@router.get("/shiso-leaf-stock-hunter/jobs/{job_id}", response_model=SkillJobResponse)
def get_shiso_leaf_stock_hunter_job(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    data = call_skill_runner("GET", f"/api/jobs/{job_id}")
    return SkillJobResponse(data=data)


@router.get("/stock-social-sentiment-reports", response_model=SkillReportPage)
def list_stock_social_sentiment_reports(username: str = Depends(verify_credentials)) -> SkillReportPage:
    return _list_skill_reports("stock-social-sentiment")


@router.get("/stock-social-sentiment-reports/{job_id}", response_model=SkillReportDetail)
def get_stock_social_sentiment_report(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillReportDetail:
    return _get_skill_report("stock-social-sentiment", job_id)


@router.post("/stock-social-sentiment/jobs", response_model=SkillJobResponse)
def create_stock_social_sentiment_job(
    payload: StockSocialSentimentJobCreate,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    stock_code = payload.stock_code.strip().upper()
    if not stock_code:
        raise HTTPException(status_code=400, detail="stock_code is required")

    data = call_skill_runner(
        "POST",
        "/api/jobs/stock-social-sentiment",
        {
            "stock_code": stock_code,
            "company_name": payload.company_name.strip(),
            "focus": payload.focus.strip(),
            "sources": payload.sources.strip() or "reddit,xueqiu",
            "timeout_minutes": payload.timeout_minutes,
        },
    )
    return SkillJobResponse(data=data)


@router.get("/stock-social-sentiment/jobs/{job_id}", response_model=SkillJobResponse)
def get_stock_social_sentiment_job(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    data = call_skill_runner("GET", f"/api/jobs/{job_id}")
    return SkillJobResponse(data=data)


@router.get("/option-flow-analysis-reports", response_model=SkillReportPage)
def list_option_flow_analysis_reports(username: str = Depends(verify_credentials)) -> SkillReportPage:
    return _list_option_flow_analysis_reports()


@router.get("/option-flow-analysis-reports/{job_id}", response_model=SkillReportDetail)
def get_option_flow_analysis_report(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillReportDetail:
    return _get_option_flow_analysis_report(job_id)


@router.delete("/option-flow-analysis-reports/{job_id}", response_model=DeleteReportResponse)
def delete_option_flow_analysis_report(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> DeleteReportResponse:
    for job_type in OPTION_FLOW_REPORT_TYPES:
        _mark_skill_report_deleted(job_type, job_id)
    return DeleteReportResponse(deleted=True, job_id=job_id)


@router.post("/option-flow-analysis/jobs", response_model=SkillJobResponse)
def create_option_flow_analysis_job(
    payload: OptionFlowAnalysisJobCreate,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    observation_date = payload.observation_date.strip()
    if not observation_date:
        raise HTTPException(status_code=400, detail="observation_date is required")

    runner_payload: Dict[str, Any] = {
        "observation_date": observation_date,
        "top_n": payload.top_n,
        "timeout_minutes": payload.timeout_minutes,
    }
    ticker = (payload.ticker or "").strip().upper()
    if ticker:
        runner_payload["ticker"] = ticker
    model = (payload.model or "").strip()
    if model:
        runner_payload["model"] = model

    data = call_skill_runner("POST", "/api/jobs/analyze-option-flow", runner_payload)
    return SkillJobResponse(data=data)


@router.get("/option-flow-analysis/jobs/{job_id}", response_model=SkillJobResponse)
def get_option_flow_analysis_job(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    data = call_skill_runner("GET", f"/api/jobs/{job_id}")
    return SkillJobResponse(data=data)


@router.post("/option-flow-analysis-range/jobs", response_model=SkillJobResponse)
def create_option_flow_analysis_range_job(
    payload: OptionFlowAnalysisRangeJobCreate,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    ticker = payload.ticker.strip().upper()
    start_date = payload.start_date.strip()
    end_date = payload.end_date.strip()
    if not ticker:
        raise HTTPException(status_code=400, detail="ticker is required")
    if not start_date or not end_date:
        raise HTTPException(status_code=400, detail="start_date and end_date are required")

    data = call_skill_runner(
        "POST",
        "/api/jobs/analyze-option-flow-range",
        {
            "ticker": ticker,
            "start_date": start_date,
            "end_date": end_date,
            "top_n": payload.top_n,
        },
    )
    return SkillJobResponse(data=data)


@router.get("/option-flow-analysis-range/jobs/{job_id}", response_model=SkillJobResponse)
def get_option_flow_analysis_range_job(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    data = call_skill_runner("GET", f"/api/jobs/{job_id}")
    return SkillJobResponse(data=data)


@router.get("/ride-bullish-momentum-reports", response_model=SkillReportPage)
def list_ride_bullish_momentum_reports(username: str = Depends(verify_credentials)) -> SkillReportPage:
    return _list_skill_reports("ride-bullish-momentum")


@router.get("/ride-bullish-momentum-reports/{job_id}", response_model=SkillReportDetail)
def get_ride_bullish_momentum_report(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillReportDetail:
    return _get_skill_report("ride-bullish-momentum", job_id)


@router.post("/ride-bullish-momentum/jobs", response_model=SkillJobResponse)
def create_ride_bullish_momentum_job(
    payload: RideBullishMomentumJobCreate,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    runner_payload: Dict[str, Any] = {
        "timeout_minutes": payload.timeout_minutes,
    }
    as_at = (payload.as_at or "").strip()
    if as_at:
        runner_payload["as_at"] = as_at
    model = (payload.model or "").strip()
    if model:
        runner_payload["model"] = model

    data = call_skill_runner("POST", "/api/jobs/ride-bullish-momentum", runner_payload)
    return SkillJobResponse(data=data)


@router.get("/ride-bullish-momentum/jobs/{job_id}", response_model=SkillJobResponse)
def get_ride_bullish_momentum_job(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    return SkillJobResponse(data=call_skill_runner("GET", f"/api/jobs/{job_id}"))


def _legacy_skill_runner_status() -> Dict[str, Any]:
    """Compatibility snapshot for runners predating /api/system/status.

    Only fetch active jobs; /api/jobs without a status filter can contain thousands
    of historical records. Memory belongs to the remote host and cannot be
    inferred from this backend, so unavailable metrics stay null.
    """
    with ThreadPoolExecutor(max_workers=3) as pool:
        health_task = pool.submit(call_skill_runner, "GET", "/health", timeout_seconds=10)
        running_task = pool.submit(call_skill_runner, "GET", "/api/jobs?status=running", timeout_seconds=10)
        queued_task = pool.submit(call_skill_runner, "GET", "/api/jobs?status=queued", timeout_seconds=10)
        health, running, queued = health_task.result(), running_task.result(), queued_task.result()

    capacity = health.get("skill_runner_capacity") if isinstance(health, dict) else None
    if not isinstance(capacity, dict) or not isinstance(running, list) or not isinstance(queued, list):
        raise HTTPException(status_code=502, detail="Skill runner returned an invalid compatibility status response")
    if health.get("status") != "ok":
        raise HTTPException(status_code=503, detail="Skill runner health check failed")
    max_outstanding = capacity.get("max_outstanding")
    max_concurrent = capacity.get("max_concurrent")
    if not isinstance(max_outstanding, int) or not isinstance(max_concurrent, int):
        raise HTTPException(status_code=502, detail="Skill runner did not report job capacity")

    by_type: Dict[str, Dict[str, int]] = {}
    def public_jobs(items: List[Any], state: str) -> List[Dict[str, Any]]:
        result = []
        for item in items:
            if not isinstance(item, dict) or item.get("status") != state:
                raise HTTPException(status_code=502, detail="Skill runner returned invalid active jobs")
            job_type = str(item.get("job_type") or "unknown")
            counts = by_type.setdefault(job_type, {"running": 0, "queued": 0})
            counts[state] += 1
            result.append({key: item.get(key) for key in (
                "job_id", "job_type", "label", "stock_code", "status", "created_at", "updated_at"
            )} | {"name": item.get("label") or item.get("stock_code")})
        return result

    running_jobs = public_jobs(running, "running")
    queued_jobs = public_jobs(queued, "queued")
    return {
        "as_of": datetime.now(timezone.utc).isoformat(),
        "source": "compatibility",
        "skill_runner": {
            "running": len(running_jobs), "queued": len(queued_jobs),
            "outstanding": len(running_jobs) + len(queued_jobs),
            "max_outstanding": max_outstanding, "max_concurrent": max_concurrent,
            "by_job_type": by_type, "running_jobs": running_jobs, "queued_jobs": queued_jobs,
        },
        "memory": {key: None for key in (
            "process_rss_bytes", "system_total_bytes", "system_available_bytes",
            "system_used_bytes", "swap_total_bytes", "swap_used_bytes"
        )},
    }


@router.get("/skill-runner/system-status")
def get_skill_runner_system_status(username: str = Depends(verify_credentials)) -> Dict[str, Any]:
    """Authenticated proxy; never expose the runner Bearer token to browsers."""
    try:
        data = call_skill_runner("GET", "/api/system/status", timeout_seconds=10, expected_not_found=True)
    except HTTPException as exc:
        if exc.status_code != 404:
            raise
        return _legacy_skill_runner_status()
    if not isinstance(data, dict) or not isinstance(data.get("skill_runner"), dict):
        raise HTTPException(status_code=502, detail="Skill runner returned an invalid system status response")
    return data


@router.get("/spx-map-reports", response_model=SkillReportPage)
def list_spx_map_reports(username: str = Depends(verify_credentials)) -> SkillReportPage:
    return _list_skill_reports("spx-map")


@router.get("/spx-map-reports/{job_id}/json", response_model=SkillJobResponse)
def get_spx_map_json(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    return SkillJobResponse(data=get_job_json(job_id))


@router.get("/spx-map-reports/{job_id}", response_model=SkillReportDetail)
def get_spx_map_report(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillReportDetail:
    return _get_skill_report("spx-map", job_id)


@router.post("/spx-map/jobs", response_model=SkillJobResponse)
def create_spx_map_job(
    payload: SpxMapJobCreate,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    runner_payload: Dict[str, Any] = {
        "timeout_minutes": payload.timeout_minutes,
    }
    as_at = (payload.as_at or "").strip()
    if as_at:
        runner_payload["as_at"] = as_at
    model = (payload.model or "").strip()
    if model:
        runner_payload["model"] = model

    data = call_skill_runner("POST", "/api/jobs/spx-map", runner_payload)
    return SkillJobResponse(data=data)


@router.get("/spx-map/jobs/{job_id}", response_model=SkillJobResponse)
def get_spx_map_job(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    data = call_skill_runner("GET", f"/api/jobs/{job_id}")
    return SkillJobResponse(data=data)


@router.get("/asx-microstructure-accumulation-reports", response_model=SkillReportPage)
def list_asx_microstructure_accumulation_reports(
    username: str = Depends(verify_credentials),
) -> SkillReportPage:
    return _list_skill_reports("asx-microstructure-accumulation")


@router.get("/asx-microstructure-accumulation-reports/{job_id}", response_model=SkillReportDetail)
def get_asx_microstructure_accumulation_report(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillReportDetail:
    return _get_skill_report("asx-microstructure-accumulation", job_id)


@router.post("/asx-microstructure-accumulation/jobs", response_model=SkillJobResponse)
def create_asx_microstructure_accumulation_job(
    payload: AsxMicrostructureAccumulationJobCreate,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    runner_payload = _build_asx_microstructure_accumulation_payload(payload)
    data = call_skill_runner(
        "POST",
        "/api/jobs/asx-microstructure-accumulation",
        runner_payload,
    )
    return SkillJobResponse(data=data)


@router.post("/asx-microstructure-accumulation", response_model=SkillJobResponse)
def create_asx_microstructure_accumulation_compatibility_job(
    payload: AsxMicrostructureAccumulationJobCreate,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    runner_payload = _build_asx_microstructure_accumulation_payload(payload)
    data = call_skill_runner(
        "POST",
        "/api/asx-microstructure-accumulation",
        runner_payload,
    )
    return SkillJobResponse(data=data)


@router.get("/asx-microstructure-accumulation/jobs/{job_id}", response_model=SkillJobResponse)
def get_asx_microstructure_accumulation_job(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    return SkillJobResponse(data=call_skill_runner("GET", f"/api/jobs/{job_id}"))


@router.get("/stock-map-reports", response_model=SkillReportPage)
def list_stock_map_reports(username: str = Depends(verify_credentials)) -> SkillReportPage:
    return _list_skill_reports("stock-map")


@router.get("/stock-map-reports/{job_id}/json", response_model=SkillJobResponse)
def get_stock_map_json(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    return SkillJobResponse(data=get_job_json(job_id))


@router.get("/stock-map-reports/{job_id}", response_model=SkillReportDetail)
def get_stock_map_report(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillReportDetail:
    return _get_skill_report("stock-map", job_id)


@router.post("/stock-map/jobs", response_model=SkillJobResponse)
def create_stock_map_job(
    payload: StockMapJobCreate,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    stock_code = payload.stock_code.strip().upper()
    if stock_code.endswith(".US"):
        stock_code = stock_code[:-3]
    if not stock_code:
        raise HTTPException(status_code=400, detail="stock_code is required")

    runner_payload: Dict[str, Any] = {
        "stock_code": stock_code,
        "timeout_minutes": payload.timeout_minutes,
    }
    as_at = (payload.as_at or "").strip()
    if as_at:
        runner_payload["as_at"] = as_at
    model = (payload.model or "").strip()
    if model:
        runner_payload["model"] = model

    data = call_skill_runner("POST", "/api/jobs/stock-map", runner_payload)
    return SkillJobResponse(data=data)


@router.get("/stock-map/jobs/{job_id}", response_model=SkillJobResponse)
def get_stock_map_job(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    return SkillJobResponse(data=call_skill_runner("GET", f"/api/jobs/{job_id}"))


@router.get("/stock-map-comparison-reports", response_model=SkillReportPage)
def list_stock_map_comparison_reports(username: str = Depends(verify_credentials)) -> SkillReportPage:
    return _list_skill_reports("stock-map-comparison")


@router.get("/stock-map-comparison-reports/{job_id}", response_model=SkillReportDetail)
def get_stock_map_comparison_report(job_id: str, username: str = Depends(verify_credentials)) -> SkillReportDetail:
    return _get_skill_report("stock-map-comparison", job_id)


def _comparison_payload(stock_code: str, observation_date: date, timeout_minutes: int, username: str, *, require_live_price: bool = True) -> dict:
    code = stock_code.strip().upper().removesuffix(".US")
    if not SYMBOL.fullmatch(code):
        raise HTTPException(status_code=422, detail="Valid US stock code is required")
    calendar = USCashCalendar()
    if not calendar.is_session(observation_date):
        raise HTTPException(status_code=422, detail=f"{observation_date} is not a US trading session. No job submitted.")
    d2_date = calendar.previous_session(observation_date)
    reports = list_reports(
        "stock-map", stock_code=code,
        start_date=d2_date.isoformat(), end_date=observation_date.isoformat(),
    )
    return build_comparison_payload(
        code, observation_date, timeout_minutes,
        extract_report_items(reports), get_job_json,
        lambda symbol: get_stock_map_prices(stock_code=symbol, observation_date=None, as_of_et=None, username=username),
        load_d1_options=load_d1_option_rows,
        require_live_price=require_live_price,
    )


@router.get("/stock-map-comparison/preview")
def preview_stock_map_comparison(
    stock_code: str,
    observation_date: date,
    username: str = Depends(verify_credentials),
) -> dict:
    """Read-only snapshot of the exact evidence the comparison job will receive."""
    return _comparison_payload(stock_code, observation_date, 120, username, require_live_price=False)


@router.get("/stock-map-comparison/prompt")
def get_stock_map_comparison_prompt(
    stock_code: str,
    observation_date: date,
    username: str = Depends(verify_credentials),
) -> dict:
    """Read-only, copyable ChatGPT prompt from the same runner input assembly."""
    snapshot = _comparison_payload(stock_code, observation_date, 120, username, require_live_price=False)
    return {"prompt": build_comparison_prompt(runner_comparison_payload(snapshot))}


@router.post("/stock-map-comparison/jobs", response_model=SkillJobResponse)
def create_stock_map_comparison_job(
    payload: StockMapComparisonJobCreate,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    snapshot = _comparison_payload(payload.stock_code, payload.observation_date, payload.timeout_minutes, username)
    runner_payload = runner_comparison_payload(snapshot)
    try:
        data = call_skill_runner("POST", "/api/jobs/stock-map-comparison", runner_payload)
    except HTTPException as exc:
        if exc.status_code == 404:
            raise HTTPException(status_code=503, detail="Stock Map comparison skill is not installed on the skill runner yet. No job submitted.") from exc
        raise
    return SkillJobResponse(data=data)


@router.get("/stock-map-comparison/jobs/{job_id}", response_model=SkillJobResponse)
def get_stock_map_comparison_job(job_id: str, username: str = Depends(verify_credentials)) -> SkillJobResponse:
    return SkillJobResponse(data=call_skill_runner("GET", f"/api/jobs/{job_id}"))


def _build_asx_microstructure_accumulation_payload(
    payload: AsxMicrostructureAccumulationJobCreate,
) -> Dict[str, Any]:
    runner_payload: Dict[str, Any] = {"timeout_minutes": payload.timeout_minutes}

    observation_date = (payload.observation_date or "").strip()
    if observation_date:
        runner_payload["observation_date"] = observation_date

    stock_code = (payload.stock_code or "").strip().upper()
    if stock_code:
        runner_payload["stock_code"] = stock_code if stock_code.endswith(".AX") else f"{stock_code}.AX"

    start_date = (payload.start_date or "").strip()
    if start_date:
        runner_payload["start_date"] = start_date

    end_date = (payload.end_date or "").strip()
    if end_date:
        runner_payload["end_date"] = end_date

    return runner_payload


@router.get("/find-bullish-call-opportunities-reports", response_model=SkillReportPage)
def list_find_bullish_call_opportunity_reports(username: str = Depends(verify_credentials)) -> SkillReportPage:
    return _list_skill_reports("find-bullish-call-opportunities")


@router.get("/find-bullish-call-opportunities-reports/{job_id}", response_model=SkillReportDetail)
def get_find_bullish_call_opportunity_report(job_id: str, username: str = Depends(verify_credentials)) -> SkillReportDetail:
    return _get_skill_report("find-bullish-call-opportunities", job_id)


@router.post("/find-bullish-call-opportunities/jobs", response_model=SkillJobResponse)
def create_find_bullish_call_opportunity_job(
    payload: BullishCallOpportunitiesJobCreate,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    data = call_skill_runner(
        "POST",
        "/api/jobs/find-bullish-call-opportunities",
        payload.model_dump(),
    )
    return SkillJobResponse(data=data)


@router.get("/find-bullish-call-opportunities/jobs/{job_id}", response_model=SkillJobResponse)
def get_find_bullish_call_opportunity_job(job_id: str, username: str = Depends(verify_credentials)) -> SkillJobResponse:
    return SkillJobResponse(data=call_skill_runner("GET", f"/api/jobs/{job_id}"))


@router.get("/find-cash-secured-put-opportunities-reports", response_model=SkillReportPage)
def list_find_cash_secured_put_opportunity_reports(username: str = Depends(verify_credentials)) -> SkillReportPage:
    return _list_skill_reports("find-cash-secured-put-opportunities")


@router.get("/find-cash-secured-put-opportunities-reports/{job_id}", response_model=SkillReportDetail)
def get_find_cash_secured_put_opportunity_report(job_id: str, username: str = Depends(verify_credentials)) -> SkillReportDetail:
    return _get_skill_report("find-cash-secured-put-opportunities", job_id)


@router.post("/find-cash-secured-put-opportunities/jobs", response_model=SkillJobResponse)
def create_find_cash_secured_put_opportunity_job(
    payload: CashSecuredPutOpportunitiesJobCreate,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    data = call_skill_runner(
        "POST",
        "/api/jobs/find-cash-secured-put-opportunities",
        payload.model_dump(),
    )
    return SkillJobResponse(data=data)


@router.get("/find-cash-secured-put-opportunities/jobs/{job_id}", response_model=SkillJobResponse)
def get_find_cash_secured_put_opportunity_job(job_id: str, username: str = Depends(verify_credentials)) -> SkillJobResponse:
    return SkillJobResponse(data=call_skill_runner("GET", f"/api/jobs/{job_id}"))


@router.get("/volatility-selective-backtest-reports", response_model=SkillReportPage)
def list_volatility_selective_backtest_reports(
    username: str = Depends(verify_credentials),
) -> SkillReportPage:
    return _list_skill_reports("volatility-selective-backtest")


@router.get("/volatility-selective-backtest-reports/{job_id}/json", response_model=SkillJobResponse)
def get_volatility_selective_backtest_json(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    return SkillJobResponse(data=get_job_json(job_id))


@router.get("/volatility-selective-backtest-reports/{job_id}", response_model=SkillReportDetail)
def get_volatility_selective_backtest_report(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillReportDetail:
    return _get_skill_report("volatility-selective-backtest", job_id)


@router.post("/volatility-selective-backtest/jobs", response_model=SkillJobResponse)
def create_volatility_selective_backtest_job(
    payload: VolatilitySelectiveBacktestJobCreate,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    try:
        dataset = json.loads(payload.dataset_json)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail=f"dataset_json must be valid JSON: {exc}") from exc
    if not isinstance(dataset, dict):
        raise HTTPException(status_code=400, detail="dataset_json must contain a JSON object")
    data = call_skill_runner(
        "POST",
        "/api/jobs/volatility-selective-backtest",
        {"dataset": dataset, "timeout_minutes": payload.timeout_minutes},
    )
    return SkillJobResponse(data=data)


@router.get("/volatility-selective-backtest/jobs/{job_id}", response_model=SkillJobResponse)
def get_volatility_selective_backtest_job(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    return SkillJobResponse(data=call_skill_runner("GET", f"/api/jobs/{job_id}"))


@router.get("/volatility-selective-options-reports", response_model=SkillReportPage)
def list_volatility_selective_options_reports(
    username: str = Depends(verify_credentials),
) -> SkillReportPage:
    return _list_skill_reports("volatility-selective-options")


@router.get("/volatility-selective-options-reports/{job_id}/json", response_model=SkillJobResponse)
def get_volatility_selective_options_json(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    return SkillJobResponse(data=get_job_json(job_id))


@router.get("/volatility-selective-options-reports/{job_id}", response_model=SkillReportDetail)
def get_volatility_selective_options_report(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillReportDetail:
    return _get_skill_report("volatility-selective-options", job_id)


@router.post("/volatility-selective-options/jobs", response_model=SkillJobResponse)
def create_volatility_selective_options_job(
    payload: VolatilitySelectiveOptionsJobCreate,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    try:
        snapshot = build_scan_snapshot(
            symbols=payload.symbols,
            account_equity=payload.account_equity,
            assignment_exposure=payload.assignment_exposure,
            event_clear_symbols=payload.event_clear_symbols,
            top_n=payload.top_n,
            dte_min=payload.dte_min,
            dte_max=payload.dte_max,
            min_vol_edge=payload.min_vol_edge,
            risk_budget_pct=payload.risk_budget_pct,
            max_assignment_exposure_pct=payload.max_assignment_exposure_pct,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to assemble the IBKR/StockDB snapshot: {exc}") from exc
    data = call_skill_runner(
        "POST",
        "/api/jobs/volatility-selective-options",
        {"snapshot": snapshot},
    )
    # Persist the completed audit and send candidate alerts asynchronously so
    # the UI receives the job id immediately while the deterministic report is
    # still generated by the skill runner.
    if isinstance(data, dict) and data.get("job_id"):
        from app.core.scheduler import _persist_volatility_runner_job

        threading.Thread(
            target=_persist_volatility_runner_job,
            args=(data,),
            daemon=True,
            name=f"vso-persist-{data['job_id']}",
        ).start()
    return SkillJobResponse(data=data)


@router.get("/volatility-selective-options/jobs/{job_id}", response_model=SkillJobResponse)
def get_volatility_selective_options_job(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    return SkillJobResponse(data=call_skill_runner("GET", f"/api/jobs/{job_id}"))


@router.get("/find-index-bottoms-reports", response_model=SkillReportPage)
def list_find_index_bottoms_reports(username: str = Depends(verify_credentials)) -> SkillReportPage:
    return _list_skill_reports("find-index-bottoms")


@lru_cache(maxsize=1024)
def _index_bottom_report_content(job_id: str) -> str:
    # Job artifacts are immutable; page changes only request new job IDs.
    return extract_report_content(get_job_report(job_id), preferred_format="markdown")


@router.get("/find-index-bottoms-reports/states")
def list_find_index_bottoms_states(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=50),
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    """Paginated historical report states; forward prices are recomputed from stored candles."""
    reports = [item for item in _list_skill_reports("find-index-bottoms").items
               if (item.status or "").lower() in {"succeeded", "completed", "complete", "success", "done"}]
    def report_order(item: SkillReportSummary) -> tuple[str, str, str]:
        as_at = parse_index_bottom_as_at(str(item.raw.get("label") or ""))
        return (as_at.isoformat() if as_at else "", item.created_at or "", item.job_id)
    reports.sort(key=report_order, reverse=True)
    selected = reports[(page - 1) * page_size: page * page_size]
    def load(item: SkillReportSummary) -> Dict[str, Any]:
        try:
            content = _index_bottom_report_content(item.job_id)
            as_at = report_index_bottom_as_at(str(item.raw.get("label") or ""), content)
            return {"job_id": item.job_id, "title": item.title,
                    "as_of_et": as_at.isoformat() if as_at else None,
                    **parse_index_bottom_state(content)}
        except HTTPException:
            logger.warning("Index-bottom report %s could not be read", item.job_id, exc_info=True)
            return {"job_id": item.job_id, "title": item.title, "as_of_et": None,
                    "state": "Report unavailable — review original job", "description": "", "score": None}
    with ThreadPoolExecutor(max_workers=6) as pool:
        items = list(pool.map(load, selected))
    as_of_values = [parse_index_bottom_as_at(item["as_of_et"]) for item in items if item["as_of_et"]]
    price_error = None
    try:
        prices = load_index_bottom_price_rows(as_of_values)
    except Exception:
        logger.warning("Unable to price index-bottom timeline page", exc_info=True)
        prices = []
        price_error = "SPY/QQQ history is temporarily unavailable; returns cannot be calculated."
    for item in items:
        as_at = parse_index_bottom_as_at(item["as_of_et"]) if item["as_of_et"] else None
        item["prices"] = calculate_index_bottom_returns(as_at, prices) if as_at else None
    return {"items": items, "page": page, "page_size": page_size,
            "total": len(reports), "price_error": price_error}


@router.get("/find-index-bottoms-reports/{job_id}", response_model=SkillReportDetail)
def get_find_index_bottoms_report(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillReportDetail:
    return _get_skill_report("find-index-bottoms", job_id)


@router.post("/find-index-bottoms/jobs", response_model=SkillJobResponse)
def create_find_index_bottoms_job(
    payload: FindIndexBottomsJobCreate,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    runner_payload: Dict[str, Any] = {
        "timeout_minutes": payload.timeout_minutes,
    }
    as_at = (payload.as_at or "").strip()
    if as_at:
        runner_payload["as_at"] = as_at
    model = (payload.model or "").strip()
    if model:
        runner_payload["model"] = model

    data = call_skill_runner("POST", "/api/jobs/find-index-bottoms", runner_payload)
    return SkillJobResponse(data=data)


@router.get("/find-index-bottoms/jobs/{job_id}", response_model=SkillJobResponse)
def get_find_index_bottoms_job(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> SkillJobResponse:
    data = call_skill_runner("GET", f"/api/jobs/{job_id}")
    return SkillJobResponse(data=data)


@router.get("/spx-map-comparison/reports")
def list_spx_map_comparison_reports(
    username: str = Depends(verify_credentials),
) -> Any:
    return call_skill_runner("GET", "/api/spx-map-comparison/reports")


@router.post("/spx-map-comparison/preview")
def preview_spx_map_comparison(
    payload: Dict[str, Any],
    username: str = Depends(verify_credentials),
) -> Any:
    return call_skill_runner("POST", "/api/spx-map-comparison/preview", payload)


SPX_COMPARISON_TRADING_PLAN_PROMPT = """\n\n## Required analysis and conditional trading plan\nUse the supplied D1 and D2 SPX Map evidence to produce a complete, actionable-for-human-review analysis and conditional trading plan—not merely a report-to-report change summary. Ground every level and conclusion in the supplied reports. Do not invent prices, indicators, confirmation, or market data. If a value or evidence source is missing, say unavailable and explain the limitation. Distinguish observed evidence from modelled/convention-based estimates.\n\n## As-of price and level classification rules (mandatory)\nTreat each report's own as_of_et as the controlling timestamp; D1 and D2 must be analyzed independently at their respective timestamps. Use the supplied D1/D2 effective-price context below. It is based on the latest fully completed ESMain 30-minute bar at or before that report timestamp, translated to SPX using that report's date-matched ES−SPX close basis; if unavailable it uses the closest completed SPY bar as proxy. Do not substitute current quotes, the other day's price, or a session close for an as-of value. If the context is missing/unavailable, state that and do not invent a reference price.\nFor EACH day's zones, classify a zone as support when its supplied center/anchor is at or below that day's effective SPX price, and resistance when its center/anchor is above it. Re-rank supports nearest-first (highest center first) and resistances nearest-first (lowest center first). Do not preserve source ranks as the display/priority order after reclassification; retain original report rank only for provenance/details. Compare D1 and D2 on their own effective-price frames, and state the as-of timestamps and prices used. Never compare or sort levels across days without labeling their separate as-of frames.\n\nOrganize the response with these sections:\n1. Executive forecast: identify market phase and the preferred price path for the coming cash session; distinguish a countertrend rebound from a larger-trend reversal; identify a likely intermediate turning point, explain confidence and invalidation, and derive the preferred conditional trade. Mention next-few-session direction/terminal objectives only when evidence supports them.\n2. D1 vs D2 changes: meaningful changes to support/resistance, anchors, scores/confidence, price/option freshness, and optional positioning intelligence. Identify newly added, removed, strengthened/weakened levels only when the input supports that conclusion.\n3. Coming-session conditional trade plan (the primary deliverable): provide a table with setup, entry SPX range/trigger, stop SPX, target(s) SPX, priority, and confirmation required. Generate conditional bullish rebound, bullish continuation, bearish rejection, and bearish breakdown scenarios where evidence supports them. Rank these by consistency with the primary market-path forecast rather than implicitly preferring a short setup. A price classified as resistance does not automatically warrant a short; include no-trade conditions. These are mutually conditional ideas, not orders to activate simultaneously. Explain each setup, invalidation, risk/reward limitations, and whether the entry requires a prior test/rejection/reclaim.\n4. ES equivalents: calculate only when a valid report-provided ES−SPX basis is supplied. State the basis and that it must be revalidated. Otherwise mark ES equivalents unavailable; never assume a basis. Keep SPX and ES values clearly labeled.\n5. Levels that matter first: order the nearest overhead resistance and downside support zones relative to the supplied reference/market price, with conditional implications. Any acceleration path is a risk scenario, not a guaranteed move.\n6. Validation before trading: list data/date alignment issues, stale or missing quotes, missing confirmation, and positioning/flow caveats. Treat positioning_intelligence as optional; signed GEX and Gamma Flip are modelled/convention-based, not observed dealer positioning; wall qualifications join by level_id; flow does not establish customer/dealer identity or opening/closing activity.\n7. Final decision: state the preferred conditional setup, alternatives, what would invalidate the bias, and explicit no-trade criteria. Keep it advisory and retrospective when appropriate.\n\nDo not claim these ideas are executable orders. Never route, submit, or enable orders. Require revalidation against live cash-session prices and applicable market conditions before a human considers any setup.\n"""

SPX_COMPARISON_FORWARD_FORECAST_PROMPT = """\n\n## Additional mandatory analysis: forward-looking market path and turning-point forecast
Act as a market-structure and price-path forecasting analyst, not merely a support/resistance classifier. The report's primary purpose remains a useful conditional trade plan for the coming cash session. First form a time-bounded, evidence-driven, falsifiable hypothesis for that session; highlight a likely path over the next few sessions only when the supplied evidence supports it, and keep that broader view secondary. The report must make a clear best-estimate directional call (bullish, bearish, or range-bound) when the evidence offers a defensible edge, even if confidence is LOW. Lead with the favored path, expected first destination and likely reaction; do not let a menu of symmetric if/then branches substitute for a forecast. Use NOT_DETERMINED only when evidence is genuinely insufficient or balanced, and explain why. Be explicit about uncertainty. Never imitate a forecaster's claimed accuracy or invent probabilities.

### Market phase and primary directional hypothesis
Diagnose one phase where evidence permits: bullish/bearish trend continuation, countertrend bullish rebound/bearish pullback, selling/buying climax or potential exhaustion, failed breakout/breakdown, consolidation/range, or transition/undetermined. Use chronological price observations, confirmed swing highs/lows, gap behavior, ATR, momentum, VIX, breadth and positioning only where supplied. Explain the previous 3–5 sessions, whether price is trending/correcting/exhausting/reversing, whether the latest move appears early/mid/late in a larger move, unusual extension versus ATR, and whether a rebound/decline may be unfinished. Do not infer N/V/W patterns from level snapshots alone. If evidence is absent, say the phase is not confidently established.
Choose ONE preferred base-case hypothesis for the coming session: BULLISH_REBOUND, BULLISH_CONTINUATION, BEARISH_PULLBACK, BEARISH_CONTINUATION, RANGE_BOUND, or—only when genuinely warranted—NOT_DETERMINED. A low-confidence directional lean is still more useful than withholding a view when evidence modestly favors one path. Distinguish a rebound inside a larger bearish trend from a trend reversal. State the favored sequence, likely first destination, horizon, evidence for/against, qualitative confidence (HIGH/MEDIUM/LOW), and invalidation. Do not default bearish after a down session or bullish because price is above a prior close. Give numerical probabilities only with documented calibration/statistical evidence. Conditional break/reclaim triggers should validate, weaken, or invalidate the base case; they must not replace stating it.

### Forecast horizons and required path
Prioritize (A) the next cash session: opening bias, first meaningful destination, intraday turning-point zones, gap response, confirmation and invalidation. Then assess (B) the next 1–2 sessions and (C) the remainder of the week only when chronological/volatility/context evidence supports a defensible extension; otherwise mark those horizons NOT_DETERMINED or unavailable and do not pad the report. Any broader context is secondary to the coming-session plan. Do not claim an intraday map predicts a monthly terminal high/low without evidence.
Give the PRIMARY PATH for the coming session as 3–6 ordered SPX zones where supplied levels support it: Reference -> first test -> reaction/pullback -> secondary test -> session objective -> possible reversal zone. If fewer defensible zones exist, use fewer and say why. For every step state zone, expected direction, horizon, why it matters, confirmation for progression and invalidation. Distinguish first-touch targets, pauses, reversal candidates, breakout/acceleration levels and terminal objectives. Resistance need not end a rebound; support need not end a decline; a pause can precede continuation. A secondary multi-session path may follow only if evidence supports it. Do not imply the exact sequence is known or invent prices.

### Turning points, scenarios and trade responses
Evaluate N-shaped advance/decline, V rebound, W base, lower-high rejection, higher-low continuation, failed breakdown/reclaim, or breakout/retest/continuation only with chronological evidence. Identify completed legs, possible unfinished leg, next inflection zone, invalidation and momentum/cross-asset support; label unsupported patterns HYPOTHETICAL. Assess whether nearest resistance is a minor pause, partial-profit area, major reversal candidate, breakout/acceleration threshold or undetermined; examine the full resistance cluster above effective price. Similarly distinguish minor support from a major swing-low candidate. Higher-level reversal needs confirmation.
For the coming session, present a clearly favored SCENARIO A as the base case, then a materially different SCENARIO B and SCENARIO C only when useful and evidence-grounded; rank them by evidence quality and do not give alternatives equal weight by default. For each supplied scenario include hypothesis, trigger, ordered targets, horizon, confirmation, invalidation, evidence for/against and qualitative confidence. The base case must state what you expect most, not merely what could happen. Do not manufacture a tail scenario or force a directional call when evidence is genuinely balanced; then say NOT_DETERMINED and prioritize no-trade. Multi-session scenarios are optional and secondary.
Only after the forecast, derive supported conditional responses: buy-the-dip, rebound continuation long, rebound profit-taking/position reduction, resistance-rejection short, breakdown/retest short, or no-trade/hold-cash. Distinguish reducing a long from opening a short. For supported ideas give entry trigger/zone, stop/invalidation, first/extended targets, reward/risk only if calculable, confirmation, horizon/session, management and rationale. Do not invent trades to fill scenarios. These are human-reviewed conditional ideas, never executable or automatically submitted. Label prices SPX/ES; convert to ES only with valid supplied basis, revalidated.

### Confirmation and historical safeguards
Use the supplied market_path_evidence only within its D1/D2 as_of_et frame. SPXW 30M raw SQL labels are corrected +1 hour to ET bar time under the documented source convention; both raw and corrected timestamps are retained. Its 30M bars are filtered to fully completed bars after correction; daily aggregates may be partial and are labeled. Swing candidates use the documented two-bars-each-side convention, not an objective or universally validated pivot. Historical-bar availability timestamps are not supplied; do not claim those bars were known to a past decision-maker at the report time. State observations that increase/decrease confidence using only available completed SPX 5m/15m/30m candles, SPY, QQQ relative strength, VIX, ES, volume/flow and options-derived GEX/walls. Separate observed facts, modelled estimates, inference/hypotheses, missing confirmation and forecasts. Signed GEX is not observed dealer inventory; Gamma Flip is not a guaranteed turning point; flow does not prove customer/dealer identity or opening/closing activity. Do not present 5m/15m triggers as historically validated absent backtesting; call them operational conventions.
Forecast D1 only from information available at D1's own as_of_et, and D2 only from its own as_of_et; do not use later realized movement or D2 evidence to justify D1. Any combined/current outlook must use whichever report has the latest valid as_of_et as the primary forecast source; never assume D1 or D2 is latest from its label. Third-party confidence is not independent validation.

### Mandatory chronology, data-quality and forecast-state checks
Determine the latest report by valid as_of_et timestamps (using selected_trading_date/trading_date only as secondary metadata), not by D1/D2 labels. The chronologically latest report is the primary coming-session forecast and supplies the final JSON as_of_et; the earlier report is comparison evidence. Earlier evidence may inform the latest forecast only if it was available by the latest as-of. Never use newer information to reconstruct the earlier report's forecast. If labels conflict with timestamps, timestamps win.
Before forecasting, classify overall evidence VALIDATED, PARTIAL, MIXED_SNAPSHOT or INSUFFICIENT. Compare report as_of_et with actual report/source snapshot times, effective-price timestamp/source and calculation, ES quote and basis timestamps, report versus effective price values, option observation time, completed-bar status, timestamp-label convention, volume availability, revised-historical-data caveat, and cross-asset freshness. Explicitly flag inherited/fallback snapshot warnings and identify stale components. A mixed or stale snapshot must lower confidence and may make the forecast insufficient. An ES-derived SPX value is an estimated proxy, not an observed cash quote or execution-quality live price. If contemporaneous ES quotes/bases conflict, ES execution equivalents are unavailable until reconciled. Market-path bar labels are raw/unverified unless the payload documents a correction; do not use ambiguous timestamps for precise intraday timing. Zero/unavailable volume means no volume confirmation. Historical data retrieved now may have been revised; its original availability time is unknown unless supplied.
Give a directional evidence scorecard before selecting the base case: recent multi-session trend; latest swing structure; distance from recent high/low in ATR; overnight/premarket direction and gap; daily/weekly/monthly CPR location; VIX; QQQ/SPY relative strength; options GEX regime/walls; evidence freshness/reliability. Mark each BULLISH, BEARISH, MIXED or UNAVAILABLE, identify the most decision-relevant evidence, and avoid double-counting correlated measures. Do not invent numerical weights or probabilities.
For every path zone classify its role as FIRST_TARGET, INTERMEDIATE_PAUSE, CONTINUATION_TRIGGER, MAJOR_REVERSAL_CANDIDATE, TERMINAL_OBJECTIVE or NOT_DETERMINED. Explain why a bullish path may continue beyond first resistance, or a bearish path beyond first support; no level alone guarantees a turn. Keep FORECAST (favored path), CONFIRMATION (observations validating it), TRADE TRIGGER (event permitting human consideration of an entry), and INVALIDATION (evidence that defeats the forecast) explicitly separate.

### Required executive forecast (place before the conditional order table)
MARKET PHASE; PRIMARY DIRECTIONAL HYPOTHESIS FOR THE COMING SESSION; CONFIDENCE; NEXT SESSION FORECAST (primary); PRIMARY PRICE PATH [Start] -> [Target 1] -> [Reaction] -> [Target 2] -> [Session objective]; FIRST MAJOR TURNING POINT; POTENTIAL TERMINAL TARGET (only if defensible); KEY INVALIDATION; ALTERNATIVE PATH; NO-TRADE CONDITIONS; NEXT 1–2 SESSION PATH (only if supported, otherwise NOT_DETERMINED); WEEKLY CONTEXT (brief and only if supported).
End the report with a machine-readable JSON forecast contract for the chronologically latest report (earlier forecast records, if any, must retain their own as_of_et): {"forecast_for_session": null, "as_of_et": null, "effective_spx_price": null, "effective_price_source": null, "data_quality": "VALIDATED|PARTIAL|MIXED_SNAPSHOT|INSUFFICIENT", "market_phase": null, "primary_direction": "BULLISH|BEARISH|RANGE_BOUND|NOT_DETERMINED", "forecast_confidence": "HIGH|MEDIUM|LOW|NOT_DETERMINED", "primary_path": [{"price_zone": [null, null], "role": "FIRST_TARGET|INTERMEDIATE_PAUSE|CONTINUATION_TRIGGER|MAJOR_REVERSAL_CANDIDATE|TERMINAL_OBJECTIVE|NOT_DETERMINED", "expected_direction": "UP|DOWN|RANGE|NOT_DETERMINED", "confirmation": null, "invalidation": null, "time_horizon": "NEXT_SESSION|NEXT_2_SESSIONS|WEEK"}], "first_major_turning_zone": null, "potential_terminal_zone": null, "primary_invalidation_condition": null, "alternative_direction": null, "preferred_conditional_strategy": null, "calibrated_probability": null}. Use null for unknowns, never invent precision, and keep primary_path levels as supplied SPX prices. calibrated_probability stays null absent validated calibration.

Put the executive forecast first with the coming-session outlook clearly dominant; then provide the original D1/D2 comparison and the primary conditional trade plan for the coming cash session. Add a clearly secondary next-few-sessions outlook only if supported, followed by remaining validation/final decision sections. State which as-of frame each forecast describes; give separate D1/D2 forecasts where information sets differ. If forecast cannot be justified, say so. Final check: coherent path, why first target may not end move, rebound vs reversal, timing and price, fair scenario ranking, forecast/trade alignment, failure conditions, and no fabricated probabilities or unsupported precision.\n"""


def _compact_spx_positioning(value: Any) -> Any:
    if not isinstance(value, dict):
        return value
    fields = (
        "available", "schema_version", "recognized_schema", "absolute_gex", "convention_signed_gex",
        "gamma_regime", "gex_status", "gex_units", "gex_assumption", "gamma_flip", "estimated_dealer_gex",
        "flow_confirmation", "source_orders_omitted", "omission_note",
    )
    compact = {key: value[key] for key in fields if key in value}
    walls = value.get("wall_qualification")
    if isinstance(walls, list):
        wall_fields = ("level_id", "map_level", "side", "classification", "qualification_status", "qualification_reason",
                       "previous_classification", "wall_change", "price_confirmation")
        compact["wall_qualification"] = [
            {key: wall[key] for key in wall_fields if key in wall}
            for wall in walls[:10] if isinstance(wall, dict)
        ]
        compact["wall_qualification_truncated_count"] = max(0, len(walls) - 10)
    changes = value.get("day_over_day_positioning_changes")
    if isinstance(changes, dict):
        compact["day_over_day_positioning_changes"] = {
            key: changes[key] for key in (
                "status", "omitted_change_count", "new_contracts_in_current_snapshot",
                "contracts_absent_from_current_snapshot", "contracts_expired_between_snapshots",
                "unmatched_contracts_are_not_position_closures",
            ) if key in changes
        }
        detailed_changes = changes.get("same_contract_changes")
        if isinstance(detailed_changes, list):
            compact["day_over_day_positioning_changes"]["same_contract_changes_summary_count"] = len(detailed_changes)
    return compact


def _spx_comparison_asof_utc(value: Any) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        parsed = datetime.fromisoformat(value)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=ZoneInfo("America/New_York"))
        return parsed.astimezone(timezone.utc)
    except (TypeError, ValueError):
        return None


def _load_spx_comparison_market_path_evidence(comparison_input: Dict[str, Any]) -> Dict[str, Any]:
    """Load a bounded, as-of-filtered SPX 30M history sample for each day."""
    from app.services.stock_map_chart_service import get_stock_map_chart_bars

    evidence: Dict[str, Any] = {}
    retrieved_at = datetime.now(timezone.utc).isoformat()
    for day in ("D1", "D2"):
        snapshot = comparison_input.get(day)
        source = snapshot.get("source") if isinstance(snapshot, dict) and isinstance(snapshot.get("source"), dict) else {}
        as_of_value = source.get("as_of_et")
        report = snapshot.get("report") if isinstance(snapshot, dict) and isinstance(snapshot.get("report"), dict) else {}
        report_as_of = report.get("as_of_et")
        warning_text = json.dumps(snapshot, ensure_ascii=False, default=str).lower()
        reconstruction_warning = any(term in warning_text for term in ("live database reconstruction warning", "could not be refreshed", "fallback preserves", "inherited snapshot"))
        day_evidence: Dict[str, Any] = {
            "as_of_et": as_of_value,
            "report_as_of_et": report_as_of,
            "price_observation_date": source.get("price_observation_date"),
            "option_observation_date": source.get("option_observation_date"),
            "option_availability_timestamp": "not supplied; cannot independently establish when option snapshot was available",
            "report_source_timestamp_status": "MISMATCH" if report_as_of and as_of_value and _spx_comparison_asof_utc(report_as_of) != _spx_comparison_asof_utc(as_of_value) else "MATCHED_OR_NOT_SEPARATELY_SUPPLIED",
            "inherited_or_fallback_snapshot_warning_detected": reconstruction_warning,
            "source": "StockDB_US.StockData.PriceHistoryTimeFrame; SPXW.US 30M",
            "retrieved_at_utc": retrieved_at,
            "source_availability_timestamp": "not supplied by the historical bar source",
            "historical_revision_status": "unknown; historical rows may have been revised since the report timestamp",
            "timestamp_label_status": "SPXW SQL TimeIntervalStart corrected +1 hour to ET bar time using the documented source-label convention; raw label retained per bar",
            "observed_or_estimated": "observed OHLC bars; derived swings/ATR labeled by method",
        }
        try:
            if not isinstance(as_of_value, str) or not as_of_value:
                raise ValueError("report as_of_et unavailable")
            as_of = datetime.fromisoformat(as_of_value)
            if as_of.tzinfo is not None:
                as_of = as_of.astimezone(ZoneInfo("America/New_York")).replace(tzinfo=None)
            result = get_stock_map_chart_bars(
                "SPX", observation_datetime=as_of, timeframe="30M", lookback_days=45,
            )
            bars = []
            for item in result.get("bars", []):
                try:
                    source_start = datetime.fromisoformat(item["time"])
                    # SPXW 30M SQL labels are one hour behind the documented ET bar time.
                    start = source_start + timedelta(hours=1)
                    if start + timedelta(minutes=30) <= as_of:
                        bars.append({**item, "source_time_raw": source_start.isoformat(), "time": start.isoformat()})
                except (KeyError, TypeError, ValueError):
                    continue
            bars.sort(key=lambda item: item["time"])
            if not bars:
                raise ValueError("no completed SPX 30M bars available at this as_of_et")

            daily: Dict[str, Dict[str, Any]] = {}
            for bar in bars:
                session_date = bar["time"][:10]
                session = daily.setdefault(session_date, {
                    "date": session_date, "open": bar["open"], "high": bar["high"],
                    "low": bar["low"], "close": bar["close"],
                    "first_bar_et": bar["time"], "last_bar_et": bar["time"],
                })
                session["high"] = max(session["high"], bar["high"])
                session["low"] = min(session["low"], bar["low"])
                session["close"] = bar["close"]
                session["last_bar_et"] = bar["time"]
            daily_bars = list(daily.values())
            for item in daily_bars:
                item["partial_session_at_as_of"] = item["date"] == as_of.date().isoformat() and as_of.time() < time(16, 0)

            swings = []
            for index in range(2, len(bars) - 2):
                window_before, pivot, window_after = bars[index - 2:index], bars[index], bars[index + 1:index + 3]
                if pivot["high"] > max(bar["high"] for bar in window_before) and pivot["high"] >= max(bar["high"] for bar in window_after):
                    swings.append({"type": "candidate_swing_high", "price": pivot["high"], "pivot_bar_et": pivot["time"], "confirmed_by_bar_et": window_after[-1]["time"], "method": "2 completed bars on each side"})
                if pivot["low"] < min(bar["low"] for bar in window_before) and pivot["low"] <= min(bar["low"] for bar in window_after):
                    swings.append({"type": "candidate_swing_low", "price": pivot["low"], "pivot_bar_et": pivot["time"], "confirmed_by_bar_et": window_after[-1]["time"], "method": "2 completed bars on each side"})

            full_sessions = [item for item in daily_bars if not item["partial_session_at_as_of"]]
            true_ranges = []
            for index in range(1, len(full_sessions)):
                current, previous = full_sessions[index], full_sessions[index - 1]
                true_ranges.append(max(current["high"] - current["low"], abs(current["high"] - previous["close"]), abs(current["low"] - previous["close"])))
            atr14 = round(sum(true_ranges[-14:]) / 14, 4) if len(true_ranges) >= 14 else None
            latest_completed_close = bars[-1]["close"]
            for swing in swings:
                distance_points = latest_completed_close - swing["price"]
                swing["latest_close_minus_swing_points"] = round(distance_points, 4)
                swing["absolute_distance_atr"] = round(abs(distance_points) / atr14, 4) if atr14 else None
            directional_context = {}
            for sessions in (5, 10, 20):
                if len(full_sessions) > sessions:
                    prior_close = full_sessions[-sessions - 1]["close"]
                    latest_close = full_sessions[-1]["close"]
                    directional_context[f"{sessions}_session"] = {
                        "points": round(latest_close - prior_close, 4),
                        "percent": round((latest_close / prior_close - 1) * 100, 4) if prior_close else None,
                        "start_date": full_sessions[-sessions - 1]["date"],
                        "end_date": full_sessions[-1]["date"],
                    }
                else:
                    directional_context[f"{sessions}_session"] = None
            latest_session = daily_bars[-1]
            session_range = latest_session["high"] - latest_session["low"]
            session_range_location = {
                "date": latest_session["date"], "high": latest_session["high"],
                "low": latest_session["low"], "latest_close": latest_session["close"],
                "close_location_pct": round((latest_session["close"] - latest_session["low"]) / session_range * 100, 2) if session_range > 0 else None,
                "partial_session_at_as_of": latest_session["partial_session_at_as_of"],
            }
            nonzero_volume_count = sum(1 for bar in bars if bar.get("volume", 0) > 0)
            day_evidence.update({
                "status": "available",
                "volume_status": "available" if nonzero_volume_count == len(bars) else "PARTIAL_OR_ZERO; no volume confirmation from zero-volume bars",
                "nonzero_volume_bar_count": nonzero_volume_count,
                "timeframe": "30M",
                "completed_30m_bars": bars[-40:],
                "completed_30m_bars_truncated_count": max(0, len(bars) - 40),
                "daily_ohlc_last_10_sessions": daily_bars[-10:],
                "confirmed_swing_candidates": swings[-20:],
                "swing_method": "two completed bars on each side; candidate is confirmed only after the right-side bars complete",
                "atr14_daily_simple_mean": atr14,
                "atr_method": "mean of the last 14 daily true ranges; unavailable when fewer than 14 ranges exist",
                "directional_context": directional_context,
                "latest_session_range_location": session_range_location,
                "vwap": "unavailable; no validated VWAP source supplied",
                "prior_forecast_outcomes": "unavailable; no linked forecast/outcome archive supplied",
            })
        except Exception as exc:
            reason = str(exc) if isinstance(exc, ValueError) else f"historical query failed ({type(exc).__name__})"
            day_evidence.update({"status": "unavailable", "reason": reason, "completed_30m_bars": [], "daily_ohlc_last_10_sessions": [], "confirmed_swing_candidates": [], "atr14_daily_simple_mean": None})
        evidence[day] = day_evidence
    return evidence


def _build_spx_comparison_prompt(
    preview: Any,
    market_path_evidence: Optional[Dict[str, Any]] = None,
    effective_price_context: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    """Build a bounded copyable prompt from preview evidence, dropping bulky optional metadata."""
    if not isinstance(preview, dict):
        raise HTTPException(status_code=502, detail="Comparison preview returned an invalid payload")
    data = preview.get("data") if isinstance(preview.get("data"), dict) else preview
    comparison_input = data.get("comparison_input") if isinstance(data, dict) else None
    if not isinstance(comparison_input, dict):
        raise HTTPException(status_code=502, detail="Comparison preview has no canonical D1/D2 input")

    compact_input: Dict[str, Any] = {
        key: comparison_input[key]
        for key in ("schema_version", "selected_trading_date", "previous_xnys_session", "analysis_only", "orders_executable", "evidence_scope")
        if key in comparison_input
    }
    for day in ("D1", "D2"):
        snapshot = comparison_input.get(day)
        if not isinstance(snapshot, dict):
            compact_input[day] = None
            continue
        source = snapshot.get("source") if isinstance(snapshot.get("source"), dict) else {}
        report = snapshot.get("report") if isinstance(snapshot.get("report"), dict) else {}
        compact_source = {
            key: source[key]
            for key in ("job_id", "job_type", "trading_date", "price_observation_date", "option_observation_date", "as_of_et", "method_version")
            if key in source
        }
        compact_report = {
            key: _compact_spx_positioning(value) if key == "positioning_intelligence" else value
            for key, value in report.items()
        }
        compact_input[day] = {"source": compact_source, "report": compact_report}

    chronology = []
    for day in ("D1", "D2"):
        snapshot = comparison_input.get(day) if isinstance(comparison_input.get(day), dict) else {}
        source = snapshot.get("source") if isinstance(snapshot.get("source"), dict) else {}
        report = snapshot.get("report") if isinstance(snapshot.get("report"), dict) else {}
        asof = source.get("as_of_et") or report.get("as_of_et")
        parsed = _spx_comparison_asof_utc(asof)
        if parsed is not None:
            chronology.append((parsed, day, asof, source.get("trading_date") or report.get("observation_date")))
    chronology.sort(key=lambda item: item[0], reverse=True)
    tied_latest = len(chronology) > 1 and chronology[0][0] == chronology[1][0]
    compact_input["chronological_roles"] = {
        "primary_forecast_day": chronology[0][1] if chronology and not tied_latest else None,
        "latest_timestamp_tie": tied_latest,
        "previous_comparison_day": chronology[1][1] if len(chronology) > 1 else None,
        "ordered_days_latest_first": [item[1] for item in chronology],
        "as_of_et": {item[1]: item[2] for item in chronology},
        "trading_date": {item[1]: item[3] for item in chronology},
        "selection_rule": "latest valid as_of_et; labels D1/D2 do not determine chronology; tied latest timestamps are unresolved",
    }
    if market_path_evidence is not None:
        compact_input["market_path_evidence"] = market_path_evidence
    if effective_price_context is not None:
        compact_input["effective_price_context"] = effective_price_context

    data_quality = {}
    effective_by_day = {item.get("day"): item for item in effective_price_context or [] if isinstance(item, dict)}
    for day in ("D1", "D2"):
        snapshot = comparison_input.get(day) if isinstance(comparison_input.get(day), dict) else {}
        report = snapshot.get("report") if isinstance(snapshot.get("report"), dict) else {}
        source = snapshot.get("source") if isinstance(snapshot.get("source"), dict) else {}
        market = (market_path_evidence or {}).get(day, {})
        effective = effective_by_day.get(day, {})
        issues = []
        if market.get("status") != "available":
            issues.append("market-path evidence unavailable")
        if market.get("inherited_or_fallback_snapshot_warning_detected"):
            issues.append("report contains inherited/fallback reconstruction warning")
        if market.get("report_source_timestamp_status") == "MISMATCH":
            issues.append("report and source as_of_et differ")
        if effective.get("unavailable_reason") or not effective.get("effective_prices"):
            issues.append("effective-price context unavailable")
        report_asof = source.get("as_of_et") or report.get("as_of_et")
        effective_asof = effective.get("as_of_et")
        if report_asof and effective_asof and _spx_comparison_asof_utc(report_asof) != _spx_comparison_asof_utc(effective_asof):
            issues.append("effective-price context as_of_et differs from report source timestamp")
        prices = effective.get("effective_prices") if isinstance(effective.get("effective_prices"), dict) else {}
        basis = effective.get("es_spx_basis")
        es_price = prices.get("ESMain")
        spx_price = prices.get("SPX")
        if isinstance(basis, (int, float)) and isinstance(es_price, (int, float)) and isinstance(spx_price, (int, float)) and str(effective.get("source", "")).startswith("ESMain"):
            if abs((es_price - spx_price) - basis) > 0.05:
                issues.append("effective ES/SPX/basis arithmetic is inconsistent")
        basis_date = effective.get("basis_observation_date")
        asof_utc_for_basis = _spx_comparison_asof_utc(effective.get("as_of_et"))
        if basis_date and asof_utc_for_basis and str(basis_date)[:10] > asof_utc_for_basis.astimezone(ZoneInfo("America/New_York")).date().isoformat():
            issues.append("ES-SPX basis date is later than report as_of_et")

        report_es_candidates = []
        report_spx_candidates = []
        report_basis_candidates = []
        def collect_price_candidates(value: Any, path: str = "report") -> None:
            if isinstance(value, dict):
                for key, child in value.items():
                    normalized = "".join(character for character in str(key).lower() if character.isalnum())
                    next_path = f"{path}.{key}"
                    quote_context = any(term in path.lower() for term in ("price", "quote", "market", "underlying", "effective", "reference", "spot", "asof"))
                    es_quote_key = normalized in {"esprice", "esmainprice", "esquote", "esmainquote", "effectiveesprice", "espriceatasof", "esmainpriceatasof"} or (quote_context and normalized in {"es", "esmain"})
                    spx_quote_key = normalized in {"spxprice", "spxquote", "effectivespxprice", "spxpriceatasof", "spxspot", "spxreferenceprice", "referenceprice", "effectiveprice"} or (quote_context and normalized == "spx")
                    if isinstance(child, (int, float)) and es_quote_key:
                        report_es_candidates.append({"field": next_path, "value": float(child)})
                    if isinstance(child, (int, float)) and spx_quote_key:
                        report_spx_candidates.append({"field": next_path, "value": float(child)})
                    if isinstance(child, (int, float)) and normalized in {"esspxbasis", "esspxcashclosebasis", "cashcloseesspxbasis", "effectivepricebasis", "effectiveesspxbasis"}:
                        report_basis_candidates.append({"field": next_path, "value": float(child)})
                    collect_price_candidates(child, next_path)
            elif isinstance(value, list):
                for index, child in enumerate(value):
                    collect_price_candidates(child, f"{path}[{index}]")
        collect_price_candidates(snapshot)
        quote_conflicts = [
            {**candidate, "effective_context_esmain": es_price, "difference_points": round(candidate["value"] - es_price, 4)}
            for candidate in report_es_candidates if isinstance(es_price, (int, float)) and abs(candidate["value"] - es_price) > 0.25
        ]
        effective_spx = prices.get("SPX")
        spx_conflicts = [
            {**candidate, "effective_context_spx": effective_spx, "difference_points": round(candidate["value"] - effective_spx, 4)}
            for candidate in report_spx_candidates if isinstance(effective_spx, (int, float)) and abs(candidate["value"] - effective_spx) > 0.5
        ]
        basis_conflicts = [
            {**candidate, "effective_context_basis": basis, "difference_points": round(candidate["value"] - basis, 4)}
            for candidate in report_basis_candidates if isinstance(basis, (int, float)) and abs(candidate["value"] - basis) > 0.05
        ]
        if quote_conflicts or basis_conflicts or spx_conflicts:
            issues.append("report SPX/ES quote or ES-SPX basis conflicts with effective-price context; ES execution equivalents blocked")
        option_date = source.get("option_observation_date")
        if option_date:
            issues.append("option availability timestamp not supplied; as-of availability cannot be confirmed")
        asof_utc = _spx_comparison_asof_utc(source.get("as_of_et"))
        if option_date and asof_utc and str(option_date)[:10] > asof_utc.astimezone(ZoneInfo("America/New_York")).date().isoformat():
            issues.append("option observation date is later than report as_of_et")
        effective_times = [effective.get("timestamp"), *(effective.get("timestamps", {}) or {}).values()]
        asof_time = _spx_comparison_asof_utc(effective.get("as_of_et"))
        if asof_time and any((_spx_comparison_asof_utc(value) and _spx_comparison_asof_utc(value) > asof_time) for value in effective_times):
            issues.append("effective-price timestamp is later than report as_of_et")
        if market.get("volume_status", "").startswith("PARTIAL_OR_ZERO"):
            issues.append("volume unavailable or zero in some/all market-path bars")
        if not market.get("timestamp_label_status", "").startswith("SPXW SQL TimeIntervalStart corrected +1 hour"):
            issues.append("intraday source timestamp convention unverified")
        status = "MIXED_SNAPSHOT" if any(any(term in item for term in ("fallback", "differ", "conflict", "inconsistent")) for item in issues) else "INSUFFICIENT" if any("unavailable" in item or "later than" in item for item in issues) else "PARTIAL"
        data_quality[day] = {
            "status": status,
            "issues": issues or ["no automated discrepancy detected; source revisions/timestamp convention still require validation"],
            "comparison_tolerances_points": {"report_vs_effective_es": 0.25, "report_vs_effective_spx": 0.5, "basis": 0.05, "status": "engineering reconciliation tolerances; not forecast calibration"},
            "report_es_quote_candidates": report_es_candidates,
            "report_spx_quote_candidates": report_spx_candidates,
            "report_es_spx_basis_candidates": report_basis_candidates,
            "spx_quote_conflicts": spx_conflicts,
            "es_quote_conflicts": quote_conflicts,
            "es_basis_conflicts": basis_conflicts,
            "es_execution_equivalents": "UNAVAILABLE_RECONCILIATION_REQUIRED" if quote_conflicts or basis_conflicts or spx_conflicts or "effective ES/SPX/basis arithmetic is inconsistent" in issues else "UNAVAILABLE_DATA_QUALITY" if status in {"MIXED_SNAPSHOT", "INSUFFICIENT"} else "requires revalidation; proxy is not an execution quote",
        }
    compact_input["data_quality_checks"] = data_quality

    canonical_json = json.dumps(compact_input, ensure_ascii=False, separators=(",", ":"))
    prompt = (
        "Analyze the following two SPX Map reports. Their source timestamps and report data are kept separate by day.\n"
        + SPX_COMPARISON_TRADING_PLAN_PROMPT
        + SPX_COMPARISON_FORWARD_FORECAST_PROMPT
        + "\n\n## Compact canonical D1/D2 evidence (JSON)\n"
        + canonical_json
        + "\n\nNote: detailed contract-level positioning changes and bulky source metadata were omitted to keep this prompt compact. Positioning summaries and a bounded wall sample are retained where supplied; do not infer omitted details.\n"
    )
    if len(prompt.encode("utf-8")) >= 150 * 1024:
        raise HTTPException(status_code=413, detail="D1/D2 SPX evidence remains too large after removing optional positioning data")
    return {"input_id": data.get("input_id") or preview.get("input_id"), "prompt": prompt,
            "prompt_chars": len(prompt), "submitted": False}



@router.post("/spx-map-comparison/prompt")
def prompt_spx_map_comparison(
    payload: Dict[str, Any],
    username: str = Depends(verify_credentials),
) -> Any:
    effective_price_context = payload.get("effective_price_context")
    preview = payload.get("preview")
    if not isinstance(preview, dict):
        runner_payload = {key: value for key, value in payload.items() if key != "effective_price_context"}
        preview = call_skill_runner("POST", "/api/spx-map-comparison/preview", runner_payload)
    data = preview.get("data") if isinstance(preview, dict) and isinstance(preview.get("data"), dict) else preview
    comparison_input = data.get("comparison_input") if isinstance(data, dict) else None
    market_path_evidence = _load_spx_comparison_market_path_evidence(comparison_input) if isinstance(comparison_input, dict) else None
    return _build_spx_comparison_prompt(
        preview, market_path_evidence=market_path_evidence,
        effective_price_context=effective_price_context if isinstance(effective_price_context, list) else None,
    )


@router.post("/jobs/spx-map-comparison")
def create_spx_map_comparison_job(
    payload: Dict[str, Any],
    username: str = Depends(verify_credentials),
) -> Any:
    return call_skill_runner("POST", "/api/jobs/spx-map-comparison", payload)


@router.get("/spx-map-comparison/jobs/{job_id}")
def get_spx_map_comparison_job(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> Any:
    return call_skill_runner("GET", f"/api/jobs/{job_id}")


@router.get("/spx-map-comparison/jobs/{job_id}/report")
def get_spx_map_comparison_report(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> Any:
    return call_skill_runner("GET", f"/api/jobs/{job_id}/report")
