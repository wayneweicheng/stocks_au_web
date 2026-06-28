from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

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

SKILLS = {
    "shiso-leaf-stock-hunter": {
        "title": "Shiso Leaf Stock Hunter",
        "route": "shiso-leaf-stock-hunter",
    },
    "stock-social-sentiment": {
        "title": "Stock Social Sentiment",
        "route": "stock-social-sentiment",
    },
}


class SkillReportSummary(BaseModel):
    job_id: str
    title: str
    created_at: Optional[str] = None
    stock_code: Optional[str] = None
    status: Optional[str] = None
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


class SkillJobResponse(BaseModel):
    data: Any


def _skill_config(job_type: str) -> Dict[str, str]:
    config = SKILLS.get(job_type)
    if not config:
        raise HTTPException(status_code=404, detail="Unknown skill report type")
    return config


def _default_title(job_type: str, item: Dict[str, Any], job_id: str) -> str:
    title = get_first_value(item, ["title", "report_title", "name"])
    if title:
        return str(title)

    stock_code = get_first_value(item, ["stock_code", "symbol", "ticker"])
    if stock_code:
        return f"{str(stock_code).upper()} {_skill_config(job_type)['title']}"

    return f"{_skill_config(job_type)['title']} {job_id}"


def _normalize_report_summary(job_type: str, item: Dict[str, Any]) -> Optional[SkillReportSummary]:
    job_id = get_first_value(item, ["job_id", "id", "jobId"])
    if job_id is None:
        return None

    stock_code = get_first_value(item, ["stock_code", "symbol", "ticker"])
    created_at = get_first_value(item, ["created_at", "completed_at", "updated_at", "createdAt", "completedAt"])
    status = get_first_value(item, ["status", "state"])
    normalized_job_id = str(job_id)

    return SkillReportSummary(
        job_id=normalized_job_id,
        title=_default_title(job_type, item, normalized_job_id),
        created_at=str(created_at) if created_at is not None else None,
        stock_code=str(stock_code).upper() if stock_code is not None else None,
        status=str(status) if status is not None else None,
        raw=item,
    )


def _list_skill_reports(job_type: str) -> SkillReportPage:
    data = list_reports(job_type)
    summaries = [
        summary
        for summary in (_normalize_report_summary(job_type, item) for item in extract_report_items(data))
        if summary is not None
    ]
    summaries.sort(key=lambda item: item.created_at or "", reverse=True)
    return SkillReportPage(items=summaries)


def _get_skill_report(job_type: str, job_id: str) -> SkillReportDetail:
    summaries = _list_skill_reports(job_type).items
    summary = next((item for item in summaries if item.job_id == job_id), None)
    data = get_job_report(job_id)

    if summary is None:
        summary = SkillReportSummary(
            job_id=job_id,
            title=f"{_skill_config(job_type)['title']} {job_id}",
            created_at=datetime.now(timezone.utc).isoformat(),
        )

    return SkillReportDetail(**summary.model_dump(), content=extract_report_content(data))


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
