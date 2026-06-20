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


router = APIRouter(prefix="/api", tags=["us-equity-analysis-reports"])


class UsEquityAnalysisReportSummary(BaseModel):
    job_id: str
    title: str
    created_at: Optional[str] = None
    stock_code: Optional[str] = None
    status: Optional[str] = None
    raw: Dict[str, Any] = Field(default_factory=dict)


class UsEquityAnalysisReportDetail(UsEquityAnalysisReportSummary):
    content: str


class UsEquityAnalysisReportPage(BaseModel):
    items: List[UsEquityAnalysisReportSummary]


class UsEquityAnalysisJobCreate(BaseModel):
    stock_code: str = Field(..., min_length=1, max_length=20)
    report_detail: str = Field(default="normal", min_length=1, max_length=50)


class UsEquityAnalysisJobResponse(BaseModel):
    data: Any


def _default_title(item: Dict[str, Any], job_id: str) -> str:
    title = get_first_value(item, ["title", "report_title", "name"])
    if title:
        return str(title)

    stock_code = get_first_value(item, ["stock_code", "symbol", "ticker"])
    if stock_code:
        return f"{str(stock_code).upper()} US Equity Analysis"

    return f"US Equity Analysis {job_id}"


def _normalize_report_summary(item: Dict[str, Any]) -> Optional[UsEquityAnalysisReportSummary]:
    job_id = get_first_value(item, ["job_id", "id", "jobId"])
    if job_id is None:
        return None

    stock_code = get_first_value(item, ["stock_code", "symbol", "ticker"])
    created_at = get_first_value(item, ["created_at", "completed_at", "updated_at", "createdAt", "completedAt"])
    status = get_first_value(item, ["status", "state"])
    normalized_job_id = str(job_id)

    return UsEquityAnalysisReportSummary(
        job_id=normalized_job_id,
        title=_default_title(item, normalized_job_id),
        created_at=str(created_at) if created_at is not None else None,
        stock_code=str(stock_code).upper() if stock_code is not None else None,
        status=str(status) if status is not None else None,
        raw=item,
    )

@router.get("/us-equity-analysis-reports", response_model=UsEquityAnalysisReportPage)
def list_us_equity_analysis_reports(
    username: str = Depends(verify_credentials),
) -> UsEquityAnalysisReportPage:
    data = list_reports("us-equity-analysis")
    summaries = [
        summary
        for summary in (_normalize_report_summary(item) for item in extract_report_items(data))
        if summary is not None
    ]
    summaries.sort(key=lambda item: item.created_at or "", reverse=True)
    return UsEquityAnalysisReportPage(items=summaries)


@router.get("/us-equity-analysis-reports/{job_id}", response_model=UsEquityAnalysisReportDetail)
def get_us_equity_analysis_report(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> UsEquityAnalysisReportDetail:
    summaries = list_us_equity_analysis_reports(username=username).items
    summary = next((item for item in summaries if item.job_id == job_id), None)
    data = get_job_report(job_id)

    if summary is None:
        summary = UsEquityAnalysisReportSummary(
            job_id=job_id,
            title=f"US Equity Analysis {job_id}",
            created_at=datetime.now(timezone.utc).isoformat(),
        )

    return UsEquityAnalysisReportDetail(**summary.model_dump(), content=extract_report_content(data))


@router.post("/us-equity-analysis/jobs", response_model=UsEquityAnalysisJobResponse)
def create_us_equity_analysis_job(
    payload: UsEquityAnalysisJobCreate,
    username: str = Depends(verify_credentials),
) -> UsEquityAnalysisJobResponse:
    stock_code = payload.stock_code.strip().upper()
    if not stock_code:
        raise HTTPException(status_code=400, detail="stock_code is required")

    data = call_skill_runner(
        "POST",
        "/api/jobs/us-equity-analysis",
        {
            "stock_code": stock_code,
            "report_detail": payload.report_detail.strip() or "normal",
        },
    )
    return UsEquityAnalysisJobResponse(data=data)


@router.get("/us-equity-analysis/jobs/{job_id}", response_model=UsEquityAnalysisJobResponse)
def get_us_equity_analysis_job(
    job_id: str,
    username: str = Depends(verify_credentials),
) -> UsEquityAnalysisJobResponse:
    data = call_skill_runner("GET", f"/api/jobs/{job_id}")
    return UsEquityAnalysisJobResponse(data=data)
