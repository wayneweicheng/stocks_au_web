from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from enum import Enum
from typing import Any, Optional


class SignalClassification(str, Enum):
    NO_SIGNAL = "NO_SIGNAL"
    INSUFFICIENT_HISTORY = "INSUFFICIENT_HISTORY"
    STRONG_YELLOW = "STRONG_YELLOW"
    RELIABLE_YELLOW = "RELIABLE_YELLOW"
    WEAK_YELLOW = "WEAK_YELLOW"
    MIXED_YELLOW = "MIXED_YELLOW"
    REVERSAL_GREEN = "REVERSAL_GREEN"
    NORMAL_GREEN = "NORMAL_GREEN"


class PortfolioState(str, Enum):
    FLAT = "FLAT"
    PENDING_GREEN_DIP = "PENDING_GREEN_DIP"
    LONG_GREEN = "LONG_GREEN"
    SHORT_YELLOW = "SHORT_YELLOW"


class Direction(str, Enum):
    LONG = "LONG"
    SHORT = "SHORT"


class EnvironmentType(str, Enum):
    BACKTEST = "BACKTEST"
    FORWARD_PAPER = "FORWARD_PAPER"
    LIVE_MANUAL = "LIVE_MANUAL"


@dataclass(frozen=True)
class MarketBar:
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    symbol: str = "NQMAIN"


@dataclass(frozen=True)
class RawGexRow:
    observation_date: date
    capital_type: str
    gex_delta: float
    close: Optional[float] = None
    vwap: Optional[float] = None
    gex: Optional[float] = None
    ticker: str = "SPXW"
    signal: Optional[str] = None


@dataclass
class DailyGexObservation:
    observation_date: date
    bc_gex_delta: float
    bp_gex_delta: float
    sc_gex_delta: float
    sp_gex_delta: float
    total_abs_gex_delta: float
    close: Optional[float]
    vwap: Optional[float]
    put_call_ratio: Optional[float]
    close_change_pct: Optional[float]
    pcr_change_pct: Optional[float]
    signal_raw: Optional[str]
    source_rows: int = 4
    derived: dict[str, Any] = field(default_factory=dict)

    @property
    def sp_delta_share(self) -> Optional[float]:
        if self.total_abs_gex_delta <= 0:
            return None
        return abs(self.sp_gex_delta) / self.total_abs_gex_delta


@dataclass
class SignalEvaluation:
    observation: DailyGexObservation
    classification: SignalClassification
    actionable_at: Optional[datetime]
    action_date: Optional[date]
    trade_allowed: bool
    skip_reason: Optional[str]
    sc_rolling_median_60: Optional[float] = None
    sc_percentile_60: Optional[float] = None
    sp_share_p75_60: Optional[float] = None
    sp_share_percentile_60: Optional[float] = None
    prior_5d_nq_return: Optional[float] = None


@dataclass
class TradePlan:
    signal_id: str
    classification: SignalClassification
    observation_date: date
    action_date: date
    first_action_at: datetime
    direction: Direction
    entry_type: str
    tp_pct: Optional[float] = None
    sl_pct: Optional[float] = None
    tp_price: Optional[float] = None
    sl_price: Optional[float] = None
    reference_price: Optional[float] = None
    dip_price: Optional[float] = None
    planned_exit_at: Optional[datetime] = None
    entry_price: Optional[float] = None
    status: str = "PLANNED"
    trade_id: Optional[str] = None
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass
class PortfolioSnapshot:
    state: PortfolioState
    shadow_nav: float
    cash: float
    exposure_factor: float
    active_trade_id: Optional[str] = None
    pending_plan_id: Optional[str] = None
    pending_dip_plan_id: Optional[str] = None
    position: Optional[dict[str, Any]] = None

