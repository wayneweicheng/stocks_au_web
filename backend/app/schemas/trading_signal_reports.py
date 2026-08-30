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
    signal_classification: Optional[str] = None
    revision_no: int
    generated_utc: datetime
    run_scheduled_utc: datetime
    supersedes_public_report_id: Optional[str] = None
    is_current: bool = True
    html_url: str


class TradingSignalReportPage(BaseModel):
    items: List[TradingSignalReportItem]
    next_cursor: Optional[str] = None
    limit: int = Field(ge=1)


class TradingSignalOverviewSignal(BaseModel):
    public_report_id: str
    report_date: date
    tradable_date: date
    end_date: Optional[date] = None
    end_at: Optional[datetime] = None
    strategy_code: str
    strategy_version_code: str
    instrument_code: str
    direction: str
    action_code: str
    holding_period: str
    signal_classification: str
    title: str
    html_url: str
    historical_win_rate_pct: float
    historical_instances: int
    historical_resolved_instances: int
    historical_profit_factor: Optional[float] = None
    historical_average_return_pct: Optional[float] = None


class TradingSignalOverviewDataError(BaseModel):
    public_report_id: str
    report_date: date
    observation_date: Optional[date] = None
    strategy_code: str
    strategy_version_code: str
    deployment_key: str
    environment: str
    instrument_code: str
    signal_classification: str
    title: str
    reason: str
    html_url: str


class TradingSignalOverviewItem(BaseModel):
    instrument_code: str
    verdict: str
    signal_count: int
    long_count: int
    short_count: int
    latest_report_date: date
    signals: List[TradingSignalOverviewSignal]


class TradingSignalOverview(BaseModel):
    as_of: date
    items: List[TradingSignalOverviewItem]
    data_errors: List[TradingSignalOverviewDataError] = Field(default_factory=list)
