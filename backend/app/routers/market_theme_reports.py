from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends
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


router = APIRouter(prefix="/api", tags=["market-theme-reports"])


class MarketThemeReportSummary(BaseModel):
    job_id: str
    title: str
    created_at: Optional[str] = None
    status: Optional[str] = None
    raw: Dict[str, Any] = Field(default_factory=dict)


class MarketThemeReportDetail(MarketThemeReportSummary):
    content: str


class MarketThemeReportPage(BaseModel):
    items: List[MarketThemeReportSummary]


class MarketThemeJobResponse(BaseModel):
    data: Any


def _default_title(item: Dict[str, Any], job_id: str) -> str:
    title = get_first_value(item, ["title", "report_title", "name"])
    if title:
        return str(title)
    return f"Market Theme Radar {job_id}"


def _normalize_report_summary(item: Dict[str, Any]) -> Optional[MarketThemeReportSummary]:
    job_id = get_first_value(item, ["job_id", "id", "jobId"])
    if job_id is None:
        return None

    created_at = get_first_value(item, ["created_at", "completed_at", "updated_at", "createdAt", "completedAt"])
    status = get_first_value(item, ["status", "state"])
    normalized_job_id = str(job_id)

    return MarketThemeReportSummary(
        job_id=normalized_job_id,
        title=_default_title(item, normalized_job_id),
        created_at=str(created_at) if created_at is not None else None,
        status=str(status) if status is not None else None,
        raw=item,
    )


@router.get("/market-theme-reports", response_model=MarketThemeReportPage)
def list_market_theme_reports(username: str = Depends(verify_credentials)) -> MarketThemeReportPage:
    data = list_reports("market-theme-radar")
    summaries = [
        summary
        for summary in (_normalize_report_summary(item) for item in extract_report_items(data))
        if summary is not None
    ]
    summaries.sort(key=lambda item: item.created_at or "", reverse=True)
    return MarketThemeReportPage(items=summaries)


@router.get("/market-theme-reports/{job_id}", response_model=MarketThemeReportDetail)
def get_market_theme_report(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> MarketThemeReportDetail:
    summaries = list_market_theme_reports(username=username).items
    summary = next((item for item in summaries if item.job_id == job_id), None)
    data = get_job_report(job_id)

    if summary is None:
        summary = MarketThemeReportSummary(
            job_id=job_id,
            title=f"Market Theme Radar {job_id}",
            created_at=datetime.now(timezone.utc).isoformat(),
        )

    return MarketThemeReportDetail(**summary.model_dump(), content=extract_report_content(data))


@router.post("/market-theme-radar/jobs", response_model=MarketThemeJobResponse)
def create_market_theme_radar_job(username: str = Depends(verify_credentials)) -> MarketThemeJobResponse:
    data = call_skill_runner("POST", "/api/jobs/market-theme-radar", {})
    return MarketThemeJobResponse(data=data)


@router.get("/market-theme-radar/jobs/{job_id}", response_model=MarketThemeJobResponse)
def get_market_theme_radar_job(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> MarketThemeJobResponse:
    data = call_skill_runner("GET", f"/api/jobs/{job_id}")
    return MarketThemeJobResponse(data=data)
