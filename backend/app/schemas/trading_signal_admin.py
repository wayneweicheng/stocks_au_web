from __future__ import annotations

from datetime import date, datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class AdminPerformanceStats(BaseModel):
    instances: int = 0
    wins: int = 0
    losses: int = 0
    win_rate_pct: Optional[float] = None
    profit_factor: Optional[float] = None
    gross_profit_pct: Optional[float] = None
    gross_loss_pct: Optional[float] = None
    source: Optional[str] = None
    source_reference: Optional[str] = None


class AdminExecution(BaseModel):
    trade_plan_id: Optional[int] = None
    signal_id: int
    strategy_version_id: int
    strategy_version_code: str
    deployment_key: str
    market_date: Optional[date] = None
    classification: Optional[str] = None
    direction: Optional[str] = None
    execution_instrument_code: Optional[str] = None
    plan_status: str = "NOT_ENTERED"
    planned_entry_utc: Optional[datetime] = None
    planned_exit_utc: Optional[datetime] = None
    actual_entry_utc: Optional[datetime] = None
    actual_entry_price: Optional[float] = None
    actual_exit_utc: Optional[datetime] = None
    actual_exit_price: Optional[float] = None
    exit_reason: Optional[str] = None
    actual_return_pct: Optional[float] = None
    calculated_entry_price: Optional[float] = None
    calculated_exit_price: Optional[float] = None
    calculated_exit_reason: Optional[str] = None
    outcome_status: str = "WAITING_MARKET_DATA"
    outcome_horizon: Optional[str] = None
    outcome_finalized_utc: Optional[datetime] = None
    execution_mode: str = "SIMULATED_MARKET_OUTCOME"


class AdminExitCondition(BaseModel):
    kind: str
    description: str
    horizon: Optional[str] = None


class AdminHistoricalPerformance(BaseModel):
    status: str
    instances: int = 0
    sample_start: Optional[str] = None
    sample_end: Optional[str] = None
    measurement_horizon: str
    win_rate_pct: Optional[float] = None
    profit_factor: Optional[float] = None
    source_reference: str
    as_of_utc: str
    notes: str


class AdminSignalDefinition(BaseModel):
    signal_code: str
    display_name: str
    strategy_definition: str
    trigger_condition: str
    direction: str
    confidence: str
    action: str
    notification_level: str
    entry_policy: str
    holding_period: str
    exit_conditions: List[AdminExitCondition] = Field(default_factory=list)
    historical_performance: AdminHistoricalPerformance


class AdminHistoricalTrade(BaseModel):
    signal_code: str
    market_date: str
    direction: str
    entry_timestamp: Optional[str] = None
    entry_price: Optional[float] = None
    exit_timestamp: Optional[str] = None
    exit_price: Optional[float] = None
    exit_reason: str = ""
    gross_return_pct: Optional[float] = None
    return_pct: Optional[float] = None
    mfe_pct: Optional[float] = None
    mae_pct: Optional[float] = None
    bars_held: Optional[int] = None
    same_bar_ambiguity: bool = False
    status: str = ""
    features: Dict[str, Any] = Field(default_factory=dict)


class AdminDeployment(BaseModel):
    strategy_deployment_id: int
    deployment_key: str
    environment: str
    is_enabled: bool
    notification_enabled: bool
    execution_enabled: bool = False
    is_production: bool = False
    notification_only: bool = True
    production_stats: AdminPerformanceStats = Field(default_factory=AdminPerformanceStats)
    executions: List[AdminExecution] = Field(default_factory=list)


class AdminStrategyVersion(BaseModel):
    strategy_version_id: int
    strategy_code: str
    display_name: str
    version_code: str
    implementation_key: Optional[str] = None
    status: str
    created_utc: Optional[datetime] = None
    strategy_definition: str
    trigger_conditions: List[str] = Field(default_factory=list)
    exit_conditions: List[str] = Field(default_factory=list)
    signal_names: List[str] = Field(default_factory=list)
    signals: List[AdminSignalDefinition] = Field(default_factory=list)
    directions: List[str] = Field(default_factory=list)
    configuration: Dict[str, Any] = Field(default_factory=dict)
    historical_stats: AdminPerformanceStats = Field(default_factory=AdminPerformanceStats)
    historical_trades: List[AdminHistoricalTrade] = Field(default_factory=list)
    deployments: List[AdminDeployment] = Field(default_factory=list)


class AdminStockGroup(BaseModel):
    stock_code: str
    strategies: List[AdminStrategyVersion] = Field(default_factory=list)


class AdminStrategyPage(BaseModel):
    generated_utc: datetime
    stocks: List[AdminStockGroup] = Field(default_factory=list)
    strategy_count: int = 0
    production_deployment_count: int = 0
    enabled_production_deployment_count: int = 0


class ProductionToggleRequest(BaseModel):
    enabled: bool
