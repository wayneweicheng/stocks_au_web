from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Set
import json
import threading

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, model_validator

from app.routers.auth import verify_credentials
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

    summary = next(
        (item for item in _list_option_flow_analysis_reports().items if item.job_id == job_id),
        None,
    )
    data = get_job_report(job_id)

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
