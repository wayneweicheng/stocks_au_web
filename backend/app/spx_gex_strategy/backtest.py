from __future__ import annotations

import math
from datetime import date, datetime
from pathlib import Path
from typing import Any

from .calendar import USCashCalendar
from .data import FileMarketDataRepository
from .features import classify_observations, nq_daily_closes
from .models import Direction, SignalClassification
from .simulation import first_touch, simulate_normal_green, simulate_reversal_green


def _bar_at_or_after(bars, timestamp: datetime):
    return next((bar for bar in bars if bar.timestamp >= timestamp), None)


def _bars_between(bars, start: datetime, end: datetime | None = None):
    return [bar for bar in bars if bar.timestamp >= start and (end is None or bar.timestamp <= end)]


def run_backtest(
    gex_path: str | Path,
    nq_path: str | Path,
    start: date,
    end: date,
    initial_capital: float = 100_000.0,
    exposure_factor: float = 1.0,
) -> dict[str, Any]:
    calendar = USCashCalendar()
    repository = FileMarketDataRepository(gex_path, nq_path)
    observations = repository.gex_observations()
    bars = repository.nq_bars()
    closes = nq_daily_closes(bars, calendar)
    evaluations = classify_observations(observations, calendar, closes)
    bars = sorted(bars, key=lambda bar: bar.timestamp)

    nav = float(initial_capital)
    active_until: datetime | None = None
    trades: list[dict[str, Any]] = []
    skipped_conflicts = 0
    unresolved_yellow: dict[str, Any] | None = None
    equity = [nav]

    for evaluation in evaluations:
        observation_date = evaluation.observation.observation_date
        if observation_date < start or observation_date > end:
            continue
        if not evaluation.trade_allowed:
            continue
        if active_until is not None and evaluation.actionable_at and evaluation.actionable_at <= active_until:
            skipped_conflicts += 1
            continue
        classification = evaluation.classification
        entry_price = None
        entry_time = None
        outcome: dict[str, Any] | None = None
        if classification in {SignalClassification.STRONG_YELLOW, SignalClassification.RELIABLE_YELLOW}:
            entry_bar = _bar_at_or_after(bars, evaluation.actionable_at)
            if entry_bar is None:
                continue
            entry_price, entry_time = entry_bar.open, entry_bar.timestamp
            tp_pct = 0.008 if classification == SignalClassification.STRONG_YELLOW else 0.004
            sl_pct = 0.010 if classification == SignalClassification.STRONG_YELLOW else 0.008
            touch = first_touch(
                entry_price,
                Direction.SHORT,
                entry_price * (1.0 - tp_pct),
                entry_price * (1.0 + sl_pct),
                _bars_between(bars, entry_time),
            )
            if touch.exit_price is None:
                # The PRD does not define a Yellow time exit. Preserve the
                # active position rather than fabricating one for the curve.
                unresolved_yellow = {
                    "observation_date": observation_date.isoformat(),
                    "classification": classification.value,
                    "entry_time": entry_time.isoformat(),
                }
                active_until = None
                break
            outcome = {
                "entry_price": entry_price,
                "entry_time": entry_time,
                "exit_price": touch.exit_price,
                "exit_time": touch.exit_time,
                "exit_reason": touch.exit_reason,
                "return_pct": (entry_price - touch.exit_price) / entry_price,
                "mfe_pct": touch.mfe_pct,
                "mae_pct": touch.mae_pct,
                "bars_held": touch.bars_held,
                "ambiguous": touch.ambiguous,
            }
        elif classification == SignalClassification.REVERSAL_GREEN:
            entry_time = evaluation.actionable_at
            reference_bar = _bar_at_or_after(bars, entry_time)
            if reference_bar is None:
                continue
            d3 = calendar.session_offset(observation_date, 3)
            d5 = calendar.session_offset(observation_date, 5)
            outcome = simulate_reversal_green(
                reference_time=entry_time,
                reference_price=reference_bar.open,
                dip_pct=0.010,
                dip_expiry=calendar.actionable_at(d3),
                fallback_time=calendar.actionable_at(d3),
                cash_close=calendar.cash_close(d5),
                bars=bars,
            )
        elif classification == SignalClassification.NORMAL_GREEN:
            d3 = calendar.session_offset(observation_date, 3)
            d5 = calendar.session_offset(observation_date, 5)
            entry_time = calendar.actionable_at(d3)
            entry_bar = _bar_at_or_after(bars, entry_time)
            if entry_bar is None:
                continue
            outcome = simulate_normal_green(
                entry_time=entry_time,
                entry_price=entry_bar.open,
                tp_pct=0.025,
                cash_close=calendar.cash_close(d5),
                bars=bars,
            )
        if not outcome or outcome.get("status") != "CLOSED":
            continue
        entry_price = float(outcome["entry_price"])
        exit_price = float(outcome["exit_price"])
        direction = Direction.SHORT if classification in {SignalClassification.STRONG_YELLOW, SignalClassification.RELIABLE_YELLOW} else Direction.LONG
        quantity = math.floor(nav * exposure_factor / entry_price)
        if quantity < 1:
            continue
        notional = quantity * entry_price
        pnl = notional * float(outcome["return_pct"])
        nav += pnl
        active_until = outcome.get("exit_time")
        trades.append(
            {
                "signal_type": classification.value,
                "observation_date": observation_date.isoformat(),
                "entry_time": outcome.get("entry_time"),
                "entry_price": entry_price,
                "exit_time": outcome.get("exit_time"),
                "exit_price": exit_price,
                "exit_reason": outcome.get("exit_reason"),
                "quantity": quantity,
                "return_pct": float(outcome["return_pct"]),
                "pnl_usd": pnl,
                "mfe_pct": outcome.get("mfe_pct"),
                "mae_pct": outcome.get("mae_pct"),
                "ambiguous": bool(outcome.get("ambiguous", False)),
                "price_source": "NQ_PROXY",
            }
        )
        equity.append(nav)

    peak = initial_capital
    max_drawdown = 0.0
    for value in equity:
        peak = max(peak, value)
        max_drawdown = max(max_drawdown, (peak - value) / peak if peak else 0.0)
    wins = sum(float(trade["return_pct"]) > 0 for trade in trades)
    gross_profit = sum(trade["pnl_usd"] for trade in trades if trade["pnl_usd"] > 0)
    gross_loss = abs(sum(trade["pnl_usd"] for trade in trades if trade["pnl_usd"] < 0))
    return {
        "strategy_version": "v1.0.0",
        "start": start.isoformat(),
        "end": end.isoformat(),
        "initial_capital": initial_capital,
        "ending_nav": nav,
        "total_return": nav / initial_capital - 1.0,
        "trade_count": len(trades),
        "win_rate": wins / len(trades) if trades else 0.0,
        "profit_factor": gross_profit / gross_loss if gross_loss else None,
        "max_drawdown": max_drawdown,
        "skipped_conflicts": skipped_conflicts,
        "unresolved_yellow": unresolved_yellow,
        "yellow_exit_assumption": "TP_SL_ONLY_UNRESOLVED_REMAINS_ACTIVE",
        "trades": trades,
    }
