from __future__ import annotations

from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel, Field


class TradingSignalReportItem(BaseModel):
    public_report_id: str
    report_kind: str
    report_date: date
    observation_date: Optional[date] = None
    strategy_code: str
    strategy_version_code: str
    deployment_key: str
    environment: str
    subject_instrument_code: Optional[str] = None
    execution_instrument_code: Optional[str] = None
    title: str
    summary: Optional[str] = None
    file_name: Optional[str] = None
    revision_no: int
    generated_utc: datetime
    supersedes_public_report_id: Optional[str] = None
    is_current: bool = True
    html_url: str


class TradingSignalReportPage(BaseModel):
    items: List[TradingSignalReportItem]
    next_cursor: Optional[str] = None
    limit: int = Field(ge=1)
