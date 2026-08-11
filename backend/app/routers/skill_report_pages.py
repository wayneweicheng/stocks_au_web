from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Set
import json
import threading

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.routers.auth import verify_credentials
from app.services.skill_runner_client import (
    call_skill_runner,
    extract_report_content,
    extract_report_items,
    get_first_value,
    get_job_report,
    list_reports,
)


router = APIRouter(prefix="/api", tags=["skill-report-pages"])
DELETED_REPORTS_PATH = Path(__file__).resolve().parents[2] / "data" / "deleted_skill_reports.json"
_DELETED_REPORTS_LOCK = threading.Lock()

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

    summaries = _list_skill_reports(job_type).items
    summary = next((item for item in summaries if item.job_id == job_id), None)
    data = get_job_report(job_id)

    if summary is None:
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
