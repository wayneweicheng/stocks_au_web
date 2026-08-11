from __future__ import annotations

import math
from datetime import date, datetime, time, timedelta
from pathlib import Path
from typing import Any, Sequence

from . import STRATEGY_VERSION
from .calendar import USCashCalendar
from .data import FileMarketDataRepository, SqlServerMarketDataRepository
from .features import classify_observations, nq_daily_closes
from .models import DailyGexObservation, Direction, MarketBar, SignalClassification
from .simulation import first_touch, simulate_normal_green, simulate_reversal_green


def _bar_exact(bars, timestamp: datetime):
    return next((bar for bar in bars if bar.timestamp == timestamp), None)


def _bars_between(bars, start: datetime, end: datetime | None = None):
    return [bar for bar in bars if bar.timestamp >= start and (end is None or bar.timestamp <= end)]


def _quarterly_roll_dates(start: date, end: date) -> list[datetime]:
    """Return the collector's quarterly NQ roll boundary at 09:30 New York."""
    calendar = USCashCalendar()
    roll_dates: list[datetime] = []
    for year in range(start.year - 1, end.year + 2):
        for month in (3, 6, 9, 12):
            first = date(year, month, 1)
            first_friday = first + timedelta(days=(4 - first.weekday()) % 7)
            expiry_friday = first_friday + timedelta(days=14)
            roll_date = expiry_friday - timedelta(days=8)
            if start <= roll_date <= end:
                roll_dates.append(datetime.combine(roll_date, time(9, 30), tzinfo=calendar.timezone))
    return sorted(roll_dates)


def neutralize_nq_roll_gaps(
    bars: Sequence[MarketBar],
) -> tuple[list[MarketBar], list[dict[str, Any]]]:
    """Back-adjust quarterly contract jumps in the stitched NQ source.

    The collector stitches actual quarterly contracts at the Thursday
    09:30 New York boundary. Preserve each contract's percentage path while
    removing the discontinuity so a roll cannot trigger a simulated TP/SL.
    """
    ordered = sorted(bars, key=lambda bar: bar.timestamp)
    if not ordered:
        return [], []
    roll_dates = _quarterly_roll_dates(
        ordered[0].timestamp.date(), ordered[-1].timestamp.date()
    )
    changes: list[tuple[int, float, dict[str, Any]]] = []
    for roll_at in roll_dates:
        index = next((i for i, bar in enumerate(ordered) if bar.timestamp >= roll_at), None)
        if index is None or index == 0:
            continue
        previous = ordered[index - 1]
        current = ordered[index]
        if previous.close <= 0 or current.open <= 0:
            continue
        factor = previous.close / current.open
        if not math.isfinite(factor) or factor <= 0:
            continue
        changes.append(
            (
                index,
                factor,
                {
                    "roll_at": roll_at.isoformat(),
                    "bar_timestamp": current.timestamp.isoformat(),
                    "raw_gap_pct": current.open / previous.close - 1.0,
                    "adjustment_factor": factor,
                },
            )
        )

    adjusted: list[MarketBar] = []
    metadata: list[dict[str, Any]] = []
    next_change = 0
    cumulative = 1.0
    for index, bar in enumerate(ordered):
        while next_change < len(changes) and changes[next_change][0] == index:
            _, factor, change = changes[next_change]
            cumulative *= factor
            metadata.append(change)
            next_change += 1
        adjusted.append(
            MarketBar(
                timestamp=bar.timestamp,
                open=bar.open * cumulative,
                high=bar.high * cumulative,
                low=bar.low * cumulative,
                close=bar.close * cumulative,
                symbol=bar.symbol,
            )
        )
    return adjusted, metadata


def run_backtest(
    gex_path: str | Path,
    nq_path: str | Path,
    start: date,
    end: date,
    initial_capital: float = 100_000.0,
    exposure_factor: float = 1.0,
) -> dict[str, Any]:
    repository = FileMarketDataRepository(gex_path, nq_path)
    return run_backtest_from_data(
        repository.gex_observations(),
        repository.nq_bars(),
        start,
        end,
        initial_capital,
        exposure_factor,
    )


def run_sql_backtest(
    source_database: str,
    start: date,
    end: date,
    initial_capital: float = 100_000.0,
    exposure_factor: float = 1.0,
) -> dict[str, Any]:
    calendar = USCashCalendar()
    repository = SqlServerMarketDataRepository(source_database=source_database, nq_symbol="NQMAIN.US")
    query_start = calendar.session_offset(start, -70)
    price_end = calendar.session_offset(end, 7)
    return run_backtest_from_data(
        repository.gex_observations(query_start, end),
        repository.nq_bars(query_start, price_end, calendar.timezone_name),
        start,
        end,
        initial_capital,
        exposure_factor,
    )


def run_backtest_from_data(
    observations: Sequence[DailyGexObservation],
    bars: Sequence[MarketBar],
    start: date,
    end: date,
    initial_capital: float = 100_000.0,
    exposure_factor: float = 1.0,
) -> dict[str, Any]:
    calendar = USCashCalendar()
    bars, roll_adjustments = neutralize_nq_roll_gaps(bars)
    closes = nq_daily_closes(bars, calendar)
    evaluations = classify_observations(observations, calendar, closes)
    bars = sorted(bars, key=lambda bar: bar.timestamp)
    scoped_evaluations = [
        evaluation
        for evaluation in evaluations
        if start <= evaluation.observation.observation_date <= end
    ]
    classification_counts = {
        classification.value: sum(
            evaluation.classification == classification for evaluation in scoped_evaluations
        )
        for classification in SignalClassification
    }
    tracked_classifications = (
        SignalClassification.STRONG_YELLOW,
        SignalClassification.RELIABLE_YELLOW,
        SignalClassification.REVERSAL_GREEN,
        SignalClassification.NORMAL_GREEN,
    )
    category_breakdown = {
        classification.value: {
            "candidate_signals": 0,
            "skipped_existing_position": 0,
            "other_skipped": 0,
            "actual_trades": 0,
            "wins": 0,
            "losses": 0,
            "average_return": 0.0,
            "profit_factor": None,
            "total_pnl": 0.0,
        }
        for classification in tracked_classifications
    }
    category_returns: dict[str, list[float]] = {
        classification.value: [] for classification in tracked_classifications
    }

    nav = float(initial_capital)
    active_until: datetime | None = None
    trades: list[dict[str, Any]] = []
    skipped_conflicts = 0
    unresolved_yellow: dict[str, Any] | None = None
    equity = [nav]

    for evaluation in scoped_evaluations:
        category = evaluation.classification.value
        stats = category_breakdown.get(category)
        if stats is not None:
            stats["candidate_signals"] += 1
        observation_date = evaluation.observation.observation_date
        if not evaluation.trade_allowed:
            continue
        if active_until is not None and evaluation.actionable_at and evaluation.actionable_at <= active_until:
            skipped_conflicts += 1
            if stats is not None:
                stats["skipped_existing_position"] += 1
            continue
        classification = evaluation.classification
        entry_price = None
        entry_time = None
        outcome: dict[str, Any] | None = None
        if classification in {SignalClassification.STRONG_YELLOW, SignalClassification.RELIABLE_YELLOW}:
            entry_bar = _bar_exact(bars, evaluation.actionable_at)
            if entry_bar is None:
                if stats is not None:
                    stats["other_skipped"] += 1
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
                if stats is not None:
                    stats["other_skipped"] += 1
                active_until = None
                break
            outcome = {
                "status": "CLOSED",
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
            reference_bar = _bar_exact(bars, entry_time)
            if reference_bar is None:
                if stats is not None:
                    stats["other_skipped"] += 1
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
            entry_bar = _bar_exact(bars, entry_time)
            if entry_bar is None:
                if stats is not None:
                    stats["other_skipped"] += 1
                continue
            outcome = simulate_normal_green(
                entry_time=entry_time,
                entry_price=entry_bar.open,
                tp_pct=0.025,
                cash_close=calendar.cash_close(d5),
                bars=bars,
            )
        if not outcome or outcome.get("status") != "CLOSED":
            if stats is not None:
                stats["other_skipped"] += 1
            continue
        entry_price = float(outcome["entry_price"])
        exit_price = float(outcome["exit_price"])
        direction = Direction.SHORT if classification in {SignalClassification.STRONG_YELLOW, SignalClassification.RELIABLE_YELLOW} else Direction.LONG
        quantity = math.floor(nav * exposure_factor / entry_price)
        if quantity < 1:
            if stats is not None:
                stats["other_skipped"] += 1
            continue
        notional = quantity * entry_price
        pnl = notional * float(outcome["return_pct"])
        nav_before = nav
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
                "nav_before": nav_before,
                "nav_after": nav,
                "mfe_pct": outcome.get("mfe_pct"),
                "mae_pct": outcome.get("mae_pct"),
                "ambiguous": bool(outcome.get("ambiguous", False)),
                "price_source": "NQ_PROXY",
            }
        )
        if stats is not None:
            return_pct = float(outcome["return_pct"])
            stats["actual_trades"] += 1
            stats["wins"] += int(return_pct > 0)
            stats["losses"] += int(return_pct <= 0)
            stats["total_pnl"] += pnl
            category_returns[category].append(return_pct)
        equity.append(nav)

    peak = initial_capital
    max_drawdown = 0.0
    for value in equity:
        peak = max(peak, value)
        max_drawdown = max(max_drawdown, (peak - value) / peak if peak else 0.0)
    wins = sum(float(trade["return_pct"]) > 0 for trade in trades)
    gross_profit = sum(trade["pnl_usd"] for trade in trades if trade["pnl_usd"] > 0)
    gross_loss = abs(sum(trade["pnl_usd"] for trade in trades if trade["pnl_usd"] < 0))
    monthly_pnl: dict[str, float] = {}
    for trade in trades:
        exit_time = trade.get("exit_time")
        if exit_time is None:
            continue
        month = exit_time.strftime("%Y-%m")
        monthly_pnl[month] = monthly_pnl.get(month, 0.0) + float(trade["pnl_usd"])

    final_month_date = end
    exit_dates = [trade["exit_time"].date() for trade in trades if trade.get("exit_time")]
    if exit_dates:
        final_month_date = max(final_month_date, max(exit_dates))
    month_cursor = date(start.year, start.month, 1)
    final_month = date(final_month_date.year, final_month_date.month, 1)
    monthly_returns: dict[str, float] = {}
    monthly_nav = float(initial_capital)
    while month_cursor <= final_month:
        month_key = month_cursor.strftime("%Y-%m")
        pnl = monthly_pnl.get(month_key, 0.0)
        monthly_returns[month_key] = pnl / monthly_nav if monthly_nav else 0.0
        monthly_nav += pnl
        month_cursor = (
            date(month_cursor.year + 1, 1, 1)
            if month_cursor.month == 12
            else date(month_cursor.year, month_cursor.month + 1, 1)
        )
    for category, stats in category_breakdown.items():
        returns = category_returns[category]
        stats["average_return"] = sum(returns) / len(returns) if returns else 0.0
        gross_profit = sum(
            trade["pnl_usd"]
            for trade in trades
            if trade["signal_type"] == category and trade["pnl_usd"] > 0
        )
        gross_loss = abs(
            sum(
                trade["pnl_usd"]
                for trade in trades
                if trade["signal_type"] == category and trade["pnl_usd"] < 0
            )
        )
        stats["profit_factor"] = gross_profit / gross_loss if gross_loss else None
    return {
        "strategy_version": STRATEGY_VERSION,
        "start": start.isoformat(),
        "end": end.isoformat(),
        "initial_capital": initial_capital,
        "ending_nav": nav,
        "total_return": nav / initial_capital - 1.0,
        "trade_count": len(trades),
        "win_rate": wins / len(trades) if trades else 0.0,
        "profit_factor": gross_profit / gross_loss if gross_loss else None,
        "max_drawdown": max_drawdown,
        "classification_counts": classification_counts,
        "category_breakdown": category_breakdown,
        "monthly_returns": monthly_returns,
        "skipped_conflicts": skipped_conflicts,
        "unresolved_yellow": unresolved_yellow,
        "yellow_exit_assumption": "TP_SL_ONLY_UNRESOLVED_REMAINS_ACTIVE",
        "nq_roll_gaps_neutralized": True,
        "nq_roll_adjustments": roll_adjustments,
        "trades": trades,
    }
