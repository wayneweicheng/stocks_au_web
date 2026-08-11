from __future__ import annotations

import hashlib
import json
import math
from datetime import datetime
from typing import Any

from .calendar import USCashCalendar
from .models import (
    Direction,
    EnvironmentType,
    PortfolioSnapshot,
    PortfolioState,
    SignalClassification,
    SignalEvaluation,
    TradePlan,
)
from .storage import StrategyStore


class PortfolioManager:
    def __init__(
        self,
        store: StrategyStore,
        calendar: USCashCalendar,
        strategy_version: str,
        initial_capital: float = 100_000.0,
        exposure_factor: float = 1.0,
        environment_type: EnvironmentType = EnvironmentType.FORWARD_PAPER,
    ) -> None:
        if initial_capital <= 0 or exposure_factor <= 0:
            raise ValueError("initial_capital and exposure_factor must be positive")
        self.store = store
        self.calendar = calendar
        self.strategy_version = strategy_version
        self.environment_type = environment_type
        self.store.ensure_portfolio(initial_capital, exposure_factor)

    @property
    def snapshot(self) -> PortfolioSnapshot:
        return self.store.snapshot()

    def conflict_reason(self, classification: SignalClassification, at: datetime | None = None) -> str | None:
        snapshot = self.snapshot
        if snapshot.state != PortfolioState.FLAT:
            return f"EXISTING_POSITION_PRIORITY_CURRENT_STATE_{snapshot.state.value}"
        if self.store.open_plans(as_of=at):
            return "EXISTING_POSITION_PRIORITY_OPEN_PLAN"
        return None

    def build_plan(self, evaluation: SignalEvaluation, reference_price: float | None = None) -> TradePlan:
        if not evaluation.action_date or not evaluation.actionable_at:
            raise ValueError("A trade plan requires an actionable date and time")
        classification = evaluation.classification
        d1 = evaluation.action_date
        d5 = self.calendar.session_offset(evaluation.observation.observation_date, 5)
        if classification == SignalClassification.STRONG_YELLOW:
            return TradePlan(
                signal_id="",
                classification=classification,
                observation_date=evaluation.observation.observation_date,
                action_date=d1,
                first_action_at=evaluation.actionable_at,
                direction=Direction.SHORT,
                entry_type="D1_MARKET",
                tp_pct=0.008,
                sl_pct=0.010,
                reference_price=reference_price,
                planned_exit_at=None,
                metadata={"action": "SHORT QQQ", "price_source": "NQ_PROXY"},
            )
        if classification == SignalClassification.RELIABLE_YELLOW:
            return TradePlan(
                signal_id="",
                classification=classification,
                observation_date=evaluation.observation.observation_date,
                action_date=d1,
                first_action_at=evaluation.actionable_at,
                direction=Direction.SHORT,
                entry_type="D1_MARKET",
                tp_pct=0.004,
                sl_pct=0.008,
                reference_price=reference_price,
                metadata={"action": "SHORT QQQ", "price_source": "NQ_PROXY"},
            )
        if classification == SignalClassification.REVERSAL_GREEN:
            dip_reference = reference_price
            d3 = self.calendar.session_offset(evaluation.observation.observation_date, 3)
            return TradePlan(
                signal_id="",
                classification=classification,
                observation_date=evaluation.observation.observation_date,
                action_date=d1,
                first_action_at=evaluation.actionable_at,
                direction=Direction.LONG,
                entry_type="DIP_LIMIT",
                reference_price=dip_reference,
                dip_price=dip_reference * 0.99 if dip_reference else None,
                planned_exit_at=self.calendar.cash_close(d5),
                metadata={
                    "dip_pct": 0.010,
                    "dip_expire_at": self.calendar.actionable_at(d3),
                    "fallback_at": self.calendar.actionable_at(d3),
                    "exit_day": d5.isoformat(),
                    "price_source": "NQ_PROXY",
                },
            )
        if classification == SignalClassification.NORMAL_GREEN:
            d3 = self.calendar.session_offset(evaluation.observation.observation_date, 3)
            return TradePlan(
                signal_id="",
                classification=classification,
                observation_date=evaluation.observation.observation_date,
                action_date=d3,
                first_action_at=self.calendar.actionable_at(d3),
                direction=Direction.LONG,
                entry_type="D3_MARKET",
                tp_pct=0.025,
                planned_exit_at=self.calendar.cash_close(d5),
                metadata={"action": "BUY QQQ", "exit_day": d5.isoformat(), "price_source": "NQ_PROXY"},
            )
        raise ValueError(f"Cannot build plan for {classification.value}")

    def reserve_plan(self, evaluation: SignalEvaluation, signal_id: str, reference_price: float | None = None) -> tuple[str | None, str | None]:
        reason = self.conflict_reason(evaluation.classification, at=evaluation.actionable_at)
        if reason:
            return None, reason
        plan = self.build_plan(evaluation, reference_price=reference_price)
        plan.signal_id = signal_id
        plan_id = self.store.save_plan(plan)
        snapshot = self.snapshot
        snapshot.pending_plan_id = plan_id
        self.store.update_portfolio(snapshot)
        return plan_id, None

    def _trade_id(self, signal_id: str) -> str:
        return hashlib.sha256(f"trade|{signal_id}".encode("utf-8")).hexdigest()[:32]

    def open_trade(
        self,
        plan_id: str,
        entry_price: float,
        entry_time: datetime,
        entry_type: str | None = None,
        quote_price: float | None = None,
    ) -> str:
        if entry_price <= 0:
            raise ValueError("entry_price must be positive")
        plan = self.store.plan(plan_id)
        if plan is None:
            raise ValueError(f"Unknown plan {plan_id}")
        snapshot = self.snapshot
        if snapshot.active_trade_id:
            raise ValueError("Cannot open a second active shadow trade")
        plan_metadata = json.loads(plan["metadata_json"] or "{}")
        qqq_entry_price = float(quote_price or plan_metadata.get("qqq_reference_price") or 0.0)
        if quote_price is not None or plan_metadata.get("qqq_reference_price") is not None:
            if qqq_entry_price <= 0:
                raise ValueError("A live QQQ quote is required for QQQ sizing")
            quantity = math.floor((snapshot.shadow_nav * snapshot.exposure_factor) / qqq_entry_price)
        else:
            # Historical/offline paper mode deliberately remains an NQ
            # percentage-path proxy and is not a live QQQ order.
            quantity = math.floor((snapshot.shadow_nav * snapshot.exposure_factor) / entry_price)
        if quantity < 1:
            raise ValueError("Shadow NAV/exposure produces zero shares")
        trade_id = self._trade_id(plan["signal_id"])
        nav_before = snapshot.shadow_nav
        direction = Direction(plan["direction"])
        plan_metadata = json.loads(plan["metadata_json"] or "{}")
        position_notional = quantity * (qqq_entry_price if qqq_entry_price > 0 else entry_price)
        if direction == Direction.LONG:
            snapshot.state = PortfolioState.LONG_GREEN
        else:
            snapshot.state = PortfolioState.SHORT_YELLOW
        snapshot.cash -= position_notional if direction == Direction.LONG else -position_notional
        snapshot.active_trade_id = trade_id
        snapshot.pending_plan_id = None
        snapshot.pending_dip_plan_id = None
        snapshot.position = {
            "trade_id": trade_id,
            "plan_id": plan_id,
            "direction": direction.value,
            "entry_price": entry_price,
            "qqq_entry_price": qqq_entry_price if qqq_entry_price > 0 else None,
            "proxy_entry_price": entry_price,
            "entry_timestamp": entry_time.isoformat(),
            "quantity": quantity,
            "position_notional": position_notional,
            "tp_price": plan["tp_price"],
            "sl_price": plan["sl_price"],
            "tp_pct": plan["tp_pct"],
            "sl_pct": plan["sl_pct"],
            "planned_exit_at": plan["planned_exit_at"],
        }
        self.store.update_portfolio(snapshot)
        self.store.update_plan(
            plan_id,
            status="ACTIVE",
            entry_price=entry_price,
            trade_id=trade_id,
            metadata_json=plan["metadata_json"],
        )
        tp_pct = plan["tp_pct"]
        sl_pct = plan["sl_pct"]
        tp_price = None
        sl_price = None
        price_basis = qqq_entry_price if qqq_entry_price > 0 else entry_price
        if direction == Direction.SHORT:
            tp_price = price_basis * (1.0 - (tp_pct or 0.0)) if tp_pct is not None else None
            sl_price = price_basis * (1.0 + (sl_pct or 0.0)) if sl_pct is not None else None
        else:
            tp_price = price_basis * (1.0 + (tp_pct or 0.0)) if tp_pct is not None else None
            sl_price = price_basis * (1.0 - (sl_pct or 0.0)) if sl_pct is not None else None
        snapshot.position["tp_price"] = tp_price
        snapshot.position["sl_price"] = sl_price
        self.store.update_portfolio(snapshot)
        self.store.update_plan(plan_id, tp_price=tp_price, sl_price=sl_price)
        self.store.insert_trade(
            {
                "trade_id": trade_id,
                "signal_id": plan["signal_id"],
                "plan_id": plan_id,
                "signal_type": plan["classification"],
                "observation_date": plan["observation_date"],
                "action_date": plan["action_date"],
                "entry_timestamp": entry_time.isoformat(),
                "entry_price": entry_price,
                "entry_type": entry_type or plan["entry_type"],
                "direction": direction.value,
                "quantity": quantity,
                "position_notional": position_notional,
                "tp_pct": tp_pct,
                "tp_price": tp_price,
                "sl_pct": sl_pct,
                "sl_price": sl_price,
                "planned_exit_date": plan["planned_exit_at"],
                "nav_before": nav_before,
                "nav_after": nav_before,
                "price_source": "IB_QQQ_LIVE" if qqq_entry_price > 0 else "NQ_PROXY",
                "strategy_version": self.strategy_version,
                "environment_type": self.environment_type.value,
                "git_commit": plan_metadata.get("git_commit"),
                "config_hash": plan_metadata.get("config_hash"),
                "data_hash": plan_metadata.get("data_hash"),
                "base_signal_source_mode": plan_metadata.get("base_signal_source_mode", "CAUSAL_COMPLETE"),
                "status": "OPEN",
                "created_at": datetime.utcnow().isoformat() + "Z",
                "updated_at": datetime.utcnow().isoformat() + "Z",
            }
        )
        return trade_id

    def activate_reversal_dip(
        self,
        plan_id: str,
        entry_price: float,
        entry_time: datetime,
        quote_price: float | None = None,
    ) -> str:
        return self.open_trade(plan_id, entry_price, entry_time, entry_type="DIP_LIMIT", quote_price=quote_price)

    def set_pending_dip(self, plan_id: str, reference_price: float) -> None:
        if reference_price <= 0:
            raise ValueError("reference_price must be positive")
        snapshot = self.snapshot
        if snapshot.state != PortfolioState.FLAT or snapshot.active_trade_id:
            raise ValueError("Cannot create a dip order while portfolio is occupied")
        dip_price = reference_price * 0.99
        snapshot.state = PortfolioState.PENDING_GREEN_DIP
        snapshot.pending_plan_id = None
        snapshot.pending_dip_plan_id = plan_id
        self.store.update_portfolio(snapshot)
        self.store.update_plan(plan_id, status="PENDING_GREEN_DIP", reference_price=reference_price, dip_price=dip_price)

    def close_trade(
        self,
        exit_price: float,
        exit_time: datetime,
        exit_reason: str,
        mfe_pct: float | None = None,
        mae_pct: float | None = None,
        bars_held: int | None = None,
        ambiguous: bool = False,
        return_pct_override: float | None = None,
    ) -> dict[str, Any]:
        if exit_price <= 0:
            raise ValueError("exit_price must be positive")
        snapshot = self.snapshot
        if not snapshot.active_trade_id or not snapshot.position:
            raise ValueError("No active shadow trade")
        position = snapshot.position
        direction = Direction(position["direction"])
        entry_price = float(position["entry_price"])
        quantity = float(position["quantity"])
        price_return = (
            float(return_pct_override)
            if return_pct_override is not None
            else (exit_price / entry_price - 1.0) * (1.0 if direction == Direction.LONG else -1.0)
        )
        pnl = quantity * entry_price * price_return
        snapshot.cash += quantity * exit_price if direction == Direction.LONG else -quantity * exit_price
        snapshot.shadow_nav = snapshot.cash
        snapshot.state = PortfolioState.FLAT
        snapshot.active_trade_id = None
        snapshot.position = None
        trade_id = str(position["trade_id"])
        self.store.update_portfolio(snapshot)
        self.store.update_trade(
            trade_id,
            exit_timestamp=exit_time.isoformat(),
            exit_price=exit_price,
            exit_reason=exit_reason,
            return_pct=price_return,
            pnl_usd=pnl,
            nav_after=snapshot.shadow_nav,
            mfe_pct=mfe_pct,
            mae_pct=mae_pct,
            bars_held=bars_held,
            same_bar_ambiguity=int(ambiguous),
            status="CLOSED",
        )
        plan_id = position.get("plan_id")
        if plan_id:
            self.store.update_plan(plan_id, status="CLOSED")
        return {
            "trade_id": trade_id,
            "entry_price": entry_price,
            "exit_price": exit_price,
            "return_pct": price_return,
            "pnl_usd": pnl,
            "shadow_nav": snapshot.shadow_nav,
            "exit_reason": exit_reason,
            "ambiguous": ambiguous,
        }
