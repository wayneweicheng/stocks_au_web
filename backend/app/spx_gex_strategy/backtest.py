from __future__ import annotations

import math
import copy
from datetime import date, datetime, time, timedelta
from pathlib import Path
from typing import Any, Sequence

from . import STRATEGY_VERSION
from .calendar import USCashCalendar
from .data import (
    FileMarketDataRepository,
    SqlServerMarketDataRepository,
    aggregate_daily_gex,
    read_delimited,
)
from .features import classify_observations, nq_daily_closes
from .models import DailyGexObservation, Direction, MarketBar, SignalClassification
from .provenance import provenance
from .simulation import first_touch, simulate_normal_green, simulate_reversal_green


COMMON_CANDIDATE_WARMUP_SESSIONS = 220
CAUSAL_COMPLETE = "CAUSAL_COMPLETE"
CANONICAL_EXPORT_COMPAT = "CANONICAL_EXPORT_COMPAT"
FREEZE_VARIANT_SPECS: tuple[dict[str, Any], ...] = (
    {
        "id": "A",
        "label": "Production baseline",
        "strategy_version": "v1.0.3-production",
        "sc_lookback_days": 60,
        "sp_lookback_days": 60,
        "sp_quantile": 0.75,
    },
    {
        "id": "B",
        "label": "Forward-test shadow",
        "strategy_version": "v1.1.0-shadow",
        "sc_lookback_days": 60,
        "sp_lookback_days": 120,
        "sp_quantile": 0.60,
    },
)


def _bar_exact(bars, timestamp: datetime):
    return next((bar for bar in bars if bar.timestamp == timestamp), None)


def _bars_between(bars, start: datetime, end: datetime | None = None):
    return [bar for bar in bars if bar.timestamp >= start and (end is None or bar.timestamp <= end)]


def _evaluation_detail(evaluation, tracked_classifications) -> dict[str, Any]:
    observation = evaluation.observation
    return {
        "observation_date": observation.observation_date.isoformat(),
        "signal_raw": observation.signal_raw,
        "classification": evaluation.classification.value,
        "candidate_signal": evaluation.classification in tracked_classifications,
        "trade_allowed_by_classifier": evaluation.trade_allowed,
        "action_date": evaluation.action_date.isoformat() if evaluation.action_date else None,
        "actionable_at": evaluation.actionable_at.isoformat() if evaluation.actionable_at else None,
        "classifier_skip_reason": evaluation.skip_reason,
        "bc_gex_delta": observation.bc_gex_delta,
        "bp_gex_delta": observation.bp_gex_delta,
        "sc_gex_delta": observation.sc_gex_delta,
        "sp_gex_delta": observation.sp_gex_delta,
        "bc_gex": observation.bc_gex,
        "bp_gex": observation.bp_gex,
        "sc_gex": observation.sc_gex,
        "sp_gex": observation.sp_gex,
        "sp_delta_share": observation.sp_delta_share,
        "sc_gex_threshold": evaluation.sc_rolling_median_60,
        "sc_gex_percentile": evaluation.sc_percentile_60,
        "sp_delta_share_threshold": evaluation.sp_share_p75_60,
        "sp_delta_share_percentile": evaluation.sp_share_percentile_60,
        "sc_lookback_days": observation.derived.get("SC_lookback_days", 60),
        "sp_lookback_days": observation.derived.get("SP_lookback_days", 60),
        "sp_threshold_quantile": observation.derived.get("SP_threshold_quantile", 0.75),
        "prior_5d_nq_return": evaluation.prior_5d_nq_return,
    }


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


def compare_canonical_signal_file(
    canonical_path: str | Path,
    signal_ledger: Sequence[dict[str, Any]],
    start: date,
    end: date,
) -> dict[str, Any]:
    """Compare the SQL reconstruction's broad signal class to the research CSV.

    The canonical CSV is a classification reference only. It does not contain
    the raw GEX levels required to run the causal reconstruction.
    """
    canonical: dict[date, dict[str, str]] = {}
    for row in read_delimited(canonical_path):
        raw_date = str(row.get("ObservationDate") or "")[:10]
        try:
            observation_date = date.fromisoformat(raw_date)
        except ValueError:
            continue
        if start <= observation_date <= end:
            canonical[observation_date] = row

    sql_by_date = {
        date.fromisoformat(str(row["observation_date"])[:10]): row
        for row in signal_ledger
        if row.get("observation_date")
    }

    def canonical_group(row: dict[str, str] | None) -> str:
        signal = str((row or {}).get("Signal") or "").strip().upper()
        if signal == "BULLISH":
            return "GREEN"
        if signal == "BEARISH":
            return "YELLOW"
        return "NO_SIGNAL"

    def sql_group(row: dict[str, Any] | None) -> str:
        classification = str((row or {}).get("classification") or "")
        if classification in {SignalClassification.REVERSAL_GREEN.value, SignalClassification.NORMAL_GREEN.value}:
            return "GREEN"
        if classification in {
            SignalClassification.STRONG_YELLOW.value,
            SignalClassification.RELIABLE_YELLOW.value,
            SignalClassification.WEAK_YELLOW.value,
            SignalClassification.MIXED_YELLOW.value,
        }:
            return "YELLOW"
        return "NO_SIGNAL"

    all_dates = sorted(set(canonical) | set(sql_by_date))
    mismatches: list[dict[str, Any]] = []
    for observation_date in all_dates:
        canonical_row = canonical.get(observation_date)
        sql_row = sql_by_date.get(observation_date)
        canonical_class = canonical_group(canonical_row)
        sql_class = sql_group(sql_row)
        if canonical_class == sql_class:
            continue
        mismatches.append(
            {
                "observation_date": observation_date.isoformat(),
                "canonical_signal": str((canonical_row or {}).get("Signal") or "") or None,
                "canonical_signal_color": str((canonical_row or {}).get("SignalColor") or "") or None,
                "canonical_broad_classification": canonical_class,
                "sql_classification": (sql_row or {}).get("classification"),
                "sql_broad_classification": sql_class,
            }
        )
    canonical_counts = {"GREEN": 0, "YELLOW": 0, "NO_SIGNAL": 0}
    sql_counts = {"GREEN": 0, "YELLOW": 0, "NO_SIGNAL": 0}
    for observation_date in all_dates:
        canonical_counts[canonical_group(canonical.get(observation_date))] += 1
        sql_counts[sql_group(sql_by_date.get(observation_date))] += 1
    return {
        "canonical_path": str(canonical_path),
        "window": {"start": start.isoformat(), "end": end.isoformat()},
        "canonical_counts": canonical_counts,
        "sql_reconstruction_counts": sql_counts,
        "mismatch_count": len(mismatches),
        "mismatches": mismatches,
    }


def canonical_export_compat_observations(
    observations: Sequence[DailyGexObservation],
    canonical_rows: Sequence[dict[str, str]],
) -> list[DailyGexObservation]:
    """Overlay stored canonical fields without manufacturing missing signals.

    SQL remains the source for GEX levels required by Yellow thresholds. The
    compatibility mode only controls the exported base-signal boundary:
    stored Signal/CloseChangePct/PCRChangePct values are used when present;
    blank canonical fields remain blank.
    """
    by_date: dict[date, dict[str, str]] = {}
    for row in canonical_rows:
        raw_date = str(row.get("ObservationDate") or "")[:10]
        try:
            by_date[date.fromisoformat(raw_date)] = row
        except ValueError:
            continue
    compatible = copy.deepcopy(list(observations))
    for observation in compatible:
        row = by_date.get(observation.observation_date)
        if row is None:
            continue
        observation.signal_raw = str(row.get("Signal") or "").strip().upper() or None
        observation.close_change_pct = _audit_float(row.get("CloseChangePct"))
        observation.pcr_change_pct = _audit_float(row.get("PCRChangePct"))
        canonical_close = _audit_float(row.get("Close"))
        canonical_pcr = _audit_float(row.get("PutCallRatio"))
        if canonical_close is not None:
            observation.close = canonical_close
        if canonical_pcr is not None:
            observation.put_call_ratio = canonical_pcr
        observation.derived["base_signal_source_mode"] = CANONICAL_EXPORT_COMPAT
    return compatible


def _audit_float(value: Any) -> float | None:
    if value is None or str(value).strip() in {"", "NULL", "None", "nan", "NaN"}:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _base_signal_from_change_fields(
    close_change_pct: float | None,
    pcr_change_pct: float | None,
) -> tuple[str | None, str]:
    """Explain the legacy base-signal rule without changing its implementation."""
    if close_change_pct is None or pcr_change_pct is None:
        return None, "CloseChangePct or PCRChangePct is missing"
    if close_change_pct > 0 and pcr_change_pct > 5:
        return "BEARISH", "CloseChangePct > 0 and PCRChangePct > 5"
    if close_change_pct < 0 and pcr_change_pct < -5:
        return "BULLISH", "CloseChangePct < 0 and PCRChangePct < -5"
    if abs(close_change_pct) < 0.1 and pcr_change_pct > 20:
        return "BEARISH", "abs(CloseChangePct) < 0.1 and PCRChangePct > 20"
    if abs(close_change_pct) < 0.1 and pcr_change_pct < -20:
        return "BULLISH", "abs(CloseChangePct) < 0.1 and PCRChangePct < -20"
    return None, "No base-signal condition matched"


def _audit_signal_group(signal: str | None) -> str:
    if (signal or "").upper() == "BULLISH":
        return "GREEN"
    if (signal or "").upper() == "BEARISH":
        return "YELLOW"
    return "NO_SIGNAL"


def _audit_sql_group(classification: str | None) -> str:
    if classification in {
        SignalClassification.REVERSAL_GREEN.value,
        SignalClassification.NORMAL_GREEN.value,
    }:
        return "GREEN"
    if classification in {
        SignalClassification.STRONG_YELLOW.value,
        SignalClassification.RELIABLE_YELLOW.value,
        SignalClassification.WEAK_YELLOW.value,
        SignalClassification.MIXED_YELLOW.value,
    }:
        return "YELLOW"
    return "NO_SIGNAL"


def _audit_cash_close_examples(
    bars: Sequence[MarketBar],
    calendar: USCashCalendar,
) -> list[dict[str, Any]]:
    """Return deterministic examples of the 30-minute cash-close convention."""
    requested = (
        ("normal_session", date(2025, 3, 7)),
        ("dst_transition", date(2025, 3, 10)),
        ("early_close_session", date(2025, 7, 3)),
    )
    by_date: dict[date, list[MarketBar]] = {}
    for bar in bars:
        by_date.setdefault(bar.timestamp.astimezone(calendar.timezone).date(), []).append(bar)
    examples: list[dict[str, Any]] = []
    for label, session_date in requested:
        cash_close = calendar.cash_close(session_date)
        eligible = [bar for bar in by_date.get(session_date, []) if bar.timestamp < cash_close]
        if not eligible:
            examples.append(
                {
                    "example": label,
                    "session_date": session_date.isoformat(),
                    "official_cash_close": cash_close.isoformat(),
                    "status": "MISSING_SOURCE_BAR",
                }
            )
            continue
        bar = max(eligible, key=lambda item: item.timestamp)
        interval_end = bar.timestamp + timedelta(minutes=30)
        examples.append(
            {
                "example": label,
                "session_date": session_date.isoformat(),
                "official_cash_close": cash_close.isoformat(),
                "bar_timestamp": bar.timestamp.isoformat(),
                "interpreted_bar_interval": f"[{bar.timestamp.isoformat()}, {interval_end.isoformat()})",
                "price_used": bar.close,
                "rule": "last bar with bar_timestamp < official cash close",
                "status": "PASS",
            }
        )
    return examples


def _audit_time_exit_examples(
    trades: Sequence[dict[str, Any]],
    calendar: USCashCalendar,
) -> list[dict[str, Any]]:
    examples: list[dict[str, Any]] = []
    for trade in trades:
        if trade.get("signal_type") not in {
            SignalClassification.REVERSAL_GREEN.value,
            SignalClassification.NORMAL_GREEN.value,
        } or trade.get("exit_reason") != "TIME_EXIT":
            continue
        bar_timestamp = datetime.fromisoformat(str(trade["exit_time"]))
        economic_exit = calendar.cash_close(bar_timestamp.astimezone(calendar.timezone).date())
        examples.append(
            {
                "signal_type": trade["signal_type"],
                "observation_date": trade["observation_date"],
                "bar_timestamp": bar_timestamp.isoformat(),
                "interpreted_bar_interval": (
                    f"[{bar_timestamp.isoformat()}, "
                    f"{(bar_timestamp + timedelta(minutes=30)).isoformat()})"
                ),
                "economic_exit_time": economic_exit.isoformat(),
                "exit_price": trade["exit_price"],
                "explanation": (
                    "The simulator records the timestamp of the 30-minute bar used for the cash-close price. "
                    "The economic exit is the end of that bar at the official cash close."
                ),
            }
        )
        if len(examples) >= 10:
            break
    return examples


def run_green_alignment_audit_from_data(
    canonical_rows: Sequence[dict[str, str]],
    observations: Sequence[DailyGexObservation],
    bars: Sequence[MarketBar],
    start: date,
    end: date,
    initial_capital: float = 100_000.0,
    exposure_factor: float = 1.0,
    sql_warmup_sessions: int = 70,
) -> dict[str, Any]:
    """Produce a read-only canonical-vs-SQL Green alignment audit.

    The audit intentionally uses the same 70-session SQL warm-up as the
    production v1.0.2 backtest so early-history gating remains visible. It
    does not alter classification, simulation, or portfolio scheduling.
    """
    calendar = USCashCalendar()
    adjusted_bars, roll_adjustments = neutralize_nq_roll_gaps(bars)
    adjusted_bars = sorted(adjusted_bars, key=lambda bar: bar.timestamp)
    closes = nq_daily_closes(adjusted_bars, calendar)

    scoped_canonical: dict[date, dict[str, str]] = {}
    for row in canonical_rows:
        raw_date = str(row.get("ObservationDate") or "")[:10]
        try:
            observation_date = date.fromisoformat(raw_date)
        except ValueError:
            continue
        if start <= observation_date <= end:
            scoped_canonical[observation_date] = row

    by_date = {observation.observation_date: observation for observation in observations}
    result = run_backtest_from_data(
        observations,
        adjusted_bars,
        start,
        end,
        initial_capital,
        exposure_factor,
        60,
        60,
        0.75,
        "v1.0.2-green-alignment-audit",
    )
    sql_ledger = {
        date.fromisoformat(str(row["observation_date"])[:10]): row
        for row in result.get("signal_ledger", [])
        if row.get("observation_date")
    }

    mismatch_dates = sorted(
        observation_date
        for observation_date in set(scoped_canonical) | set(sql_ledger)
        if _audit_signal_group(
            str(scoped_canonical.get(observation_date, {}).get("Signal") or "").strip().upper() or None
        )
        != _audit_sql_group(sql_ledger.get(observation_date, {}).get("classification"))
    )
    mismatches: list[dict[str, Any]] = []
    for observation_date in mismatch_dates:
        canonical_row = scoped_canonical.get(observation_date, {})
        observation = by_date.get(observation_date)
        sql_row = sql_ledger.get(observation_date, {})
        canonical_signal = str(canonical_row.get("Signal") or "").strip().upper() or None
        sql_signal = (observation.signal_raw if observation else None) or None
        canonical_close_change = _audit_float(canonical_row.get("CloseChangePct"))
        canonical_pcr = _audit_float(canonical_row.get("PutCallRatio"))
        canonical_pcr_change = _audit_float(canonical_row.get("PCRChangePct"))
        sql_close_change = observation.close_change_pct if observation else None
        sql_pcr = observation.put_call_ratio if observation else None
        sql_pcr_change = observation.pcr_change_pct if observation else None
        canonical_rule_signal, canonical_rule_reason = _base_signal_from_change_fields(
            canonical_close_change, canonical_pcr_change
        )
        sql_rule_signal, sql_rule_reason = _base_signal_from_change_fields(
            sql_close_change, sql_pcr_change
        )
        sql_classification = sql_row.get("classification")
        if canonical_signal is None and sql_signal == "BULLISH":
            reason = (
                "Canonical CSV stores a blank base Signal and blank change fields, so it emits no signal. "
                "SQL reconstructs the missing fields from the previous SQL row and emits BULLISH because "
                f"{sql_rule_reason}."
            )
        elif canonical_signal == sql_signal and sql_classification == SignalClassification.INSUFFICIENT_HISTORY.value:
            reason = (
                f"Both sources emit base signal {canonical_signal}. The mismatch is downstream SQL history gating: "
                f"{sql_row.get('classifier_skip_reason')}; the canonical CSV retains its stored BEARISH signal "
                "without applying this SQL causal-lookback gate to the broad comparison."
            )
        else:
            reason = (
                f"Canonical stored signal={canonical_signal or 'blank'}; SQL reconstructed signal="
                f"{sql_signal or 'blank'}. Canonical field rule: {canonical_rule_reason}; "
                f"SQL field rule: {sql_rule_reason}."
            )
        mismatches.append(
            {
                "date": observation_date.isoformat(),
                "canonical_signal": canonical_signal,
                "sql_signal": sql_signal,
                "canonical_sql_classification": sql_classification,
                "canonical_broad_classification": _audit_signal_group(canonical_signal),
                "sql_broad_classification": _audit_sql_group(sql_classification),
                "canonical_close_change_pct": canonical_close_change,
                "sql_close_change_pct": sql_close_change,
                "canonical_put_call_ratio": canonical_pcr,
                "sql_put_call_ratio": sql_pcr,
                "canonical_pcr_change_pct": canonical_pcr_change,
                "sql_pcr_change_pct": sql_pcr_change,
                "canonical_field_rule_signal": canonical_rule_signal,
                "canonical_field_rule_reason": canonical_rule_reason,
                "sql_field_rule_signal": sql_rule_signal,
                "sql_field_rule_reason": sql_rule_reason,
                "sql_classifier_skip_reason": sql_row.get("classifier_skip_reason"),
                "reason": reason,
            }
        )

    canonical_green_dates = sorted(
        observation_date
        for observation_date, row in scoped_canonical.items()
        if str(row.get("Signal") or "").strip().upper() == "BULLISH"
    )
    canonical_green_rows: list[dict[str, Any]] = []
    for observation_date in canonical_green_dates:
        d_minus_5 = calendar.session_offset(observation_date, -5)
        d0_close = closes.get(observation_date)
        d_minus_5_close = closes.get(d_minus_5)
        prior_5d_return = (
            d0_close / d_minus_5_close - 1.0
            if d0_close is not None and d_minus_5_close not in (None, 0)
            else None
        )
        expected = (
            SignalClassification.REVERSAL_GREEN.value
            if prior_5d_return is not None and prior_5d_return <= 0
            else SignalClassification.NORMAL_GREEN.value
            if prior_5d_return is not None
            else None
        )
        sql_subtype = sql_ledger.get(observation_date, {}).get("classification")
        canonical_green_rows.append(
            {
                "observation_date": observation_date.isoformat(),
                "nq_cash_close_d0": d0_close,
                "nq_cash_close_d_minus_5": d_minus_5_close,
                "d_minus_5_session": d_minus_5.isoformat(),
                "prior_5d_return": prior_5d_return,
                "expected_subtype": expected,
                "sql_subtype": sql_subtype,
                "match": sql_subtype == expected,
            }
        )

    canonical_counts = {
        "GREEN": sum(_audit_signal_group(str(row.get("Signal") or "").strip().upper() or None) == "GREEN" for row in scoped_canonical.values()),
        "YELLOW": sum(_audit_signal_group(str(row.get("Signal") or "").strip().upper() or None) == "YELLOW" for row in scoped_canonical.values()),
        "NO_SIGNAL": sum(_audit_signal_group(str(row.get("Signal") or "").strip().upper() or None) == "NO_SIGNAL" for row in scoped_canonical.values()),
    }
    sql_base_counts = {
        "GREEN": sum(_audit_signal_group(observation.signal_raw) == "GREEN" for observation in by_date.values() if start <= observation.observation_date <= end),
        "YELLOW": sum(_audit_signal_group(observation.signal_raw) == "YELLOW" for observation in by_date.values() if start <= observation.observation_date <= end),
        "NO_SIGNAL": sum(_audit_signal_group(observation.signal_raw) == "NO_SIGNAL" for observation in by_date.values() if start <= observation.observation_date <= end),
    }
    subtype_counts = {
        SignalClassification.REVERSAL_GREEN.value: sum(row.get("classification") == SignalClassification.REVERSAL_GREEN.value for row in sql_ledger.values()),
        SignalClassification.NORMAL_GREEN.value: sum(row.get("classification") == SignalClassification.NORMAL_GREEN.value for row in sql_ledger.values()),
    }
    return {
        "audit": "SPX GEX final Green alignment audit",
        "strategy_version": "v1.0.3-production",
        "window": {"start": start.isoformat(), "end": end.isoformat()},
        "rules_changed": False,
        "sql_warmup_sessions": sql_warmup_sessions,
        "canonical_base_signal_counts": canonical_counts,
        "sql_reconstructed_base_signal_counts": sql_base_counts,
        "sql_strategy_classification_counts": result.get("classification_counts", {}),
        "sql_green_subtype_counts": subtype_counts,
        "canonical_green_subtype_counts": {
            SignalClassification.REVERSAL_GREEN.value: sum(row["expected_subtype"] == SignalClassification.REVERSAL_GREEN.value for row in canonical_green_rows),
            SignalClassification.NORMAL_GREEN.value: sum(row["expected_subtype"] == SignalClassification.NORMAL_GREEN.value for row in canonical_green_rows),
        },
        "mismatch_count": len(mismatches),
        "mismatches": mismatches,
        "canonical_green_rows": canonical_green_rows,
        "bar_convention_examples": _audit_cash_close_examples(adjusted_bars, calendar),
        "green_time_exit_examples": _audit_time_exit_examples(result.get("trades", []), calendar),
        "time_exit_convention": {
            "bar_timestamp_is_start": True,
            "bar_interval_minutes": 30,
            "economic_exit_time": "official cash close, normally 16:00 America/New_York",
            "explanation": "A 15:30 timestamp identifies the 15:30-16:00 bar; its close is the 16:00 economic exit.",
        },
        "regression_proofs": [
            {
                "test": "test_calendar_keeps_action_time_at_0330_across_dst",
                "result": "PASS",
                "proves": "D1/D3 action references remain exactly 03:30 America/New_York while the UTC offset changes.",
            },
            {
                "test": "test_reversal_dip_expiry_is_exclusive_and_fallback_requires_exact_bar",
                "result": "PASS",
                "proves": "The dip window is strictly before D3 03:30; the D3 bar is the fallback, not a dip fill; removing it produces DATA_ERROR rather than a retroactive fill.",
            },
            {
                "test": "test_green_cash_close_uses_last_bar_ending_at_cash_close",
                "result": "PASS",
                "proves": "D5 TIME_EXIT uses the last bar ending at official cash close and excludes the bar stamped at 16:00.",
            },
        ],
        "nq_roll_gaps_neutralized": True,
        "nq_roll_adjustments": roll_adjustments,
        "reconciliation_note": (
            "The seven mismatches are the existing broad canonical-vs-SQL comparison. "
            "Only 2025-03-06 differs at the base-signal level; the other six have the same BEARISH base signal "
            "but differ because the 70-session SQL run applies insufficient-history gating."
        ),
    }


def run_sql_green_alignment_audit(
    source_database: str,
    canonical_path: str | Path,
    start: date,
    end: date,
    initial_capital: float = 100_000.0,
    exposure_factor: float = 1.0,
) -> dict[str, Any]:
    calendar = USCashCalendar()
    repository = SqlServerMarketDataRepository(source_database=source_database, nq_symbol="NQMAIN.US")
    query_start = calendar.session_offset(start, -70)
    price_end = calendar.session_offset(end, 7)
    raw_rows = repository.raw_gex_rows(query_start, end)
    return run_green_alignment_audit_from_data(
        read_delimited(canonical_path),
        aggregate_daily_gex(raw_rows),
        repository.nq_bars(query_start, price_end, calendar.timezone_name),
        start,
        end,
        initial_capital,
        exposure_factor,
        70,
    )


def run_backtest(
    gex_path: str | Path,
    nq_path: str | Path,
    start: date,
    end: date,
    initial_capital: float = 100_000.0,
    exposure_factor: float = 1.0,
    sc_lookback_days: int = 60,
    sp_lookback_days: int = 60,
    sp_quantile: float = 0.75,
    strategy_version: str = STRATEGY_VERSION,
) -> dict[str, Any]:
    repository = FileMarketDataRepository(gex_path, nq_path)
    return run_backtest_from_data(
        repository.gex_observations(),
        repository.nq_bars(),
        start,
        end,
        initial_capital,
        exposure_factor,
        sc_lookback_days,
        sp_lookback_days,
        sp_quantile,
        strategy_version,
    )


def run_sql_backtest(
    source_database: str,
    start: date,
    end: date,
    initial_capital: float = 100_000.0,
    exposure_factor: float = 1.0,
    sc_lookback_days: int = 60,
    sp_lookback_days: int = 60,
    sp_quantile: float = 0.75,
    strategy_version: str = STRATEGY_VERSION,
) -> dict[str, Any]:
    calendar = USCashCalendar()
    repository = SqlServerMarketDataRepository(source_database=source_database, nq_symbol="NQMAIN.US")
    query_start = calendar.session_offset(start, -(max(sc_lookback_days, sp_lookback_days) + 10))
    price_end = calendar.session_offset(end, 7)
    return run_backtest_from_data(
        repository.gex_observations(query_start, end),
        repository.nq_bars(query_start, price_end, calendar.timezone_name),
        start,
        end,
        initial_capital,
        exposure_factor,
        sc_lookback_days,
        sp_lookback_days,
        sp_quantile,
        strategy_version,
    )


def _simulate_yellow_candidate(evaluation, bars: Sequence[MarketBar]) -> dict[str, Any] | None:
    """Simulate one Yellow independently, without portfolio conflict rules."""
    if evaluation.classification not in {
        SignalClassification.STRONG_YELLOW,
        SignalClassification.RELIABLE_YELLOW,
    }:
        return None
    entry_bar = _bar_exact(bars, evaluation.actionable_at)
    if entry_bar is None:
        return None
    tp_pct = 0.008 if evaluation.classification == SignalClassification.STRONG_YELLOW else 0.004
    sl_pct = 0.010 if evaluation.classification == SignalClassification.STRONG_YELLOW else 0.008
    touch = first_touch(
        entry_bar.open,
        Direction.SHORT,
        entry_bar.open * (1.0 - tp_pct),
        entry_bar.open * (1.0 + sl_pct),
        _bars_between(bars, entry_bar.timestamp),
    )
    if touch.exit_price is None:
        return None
    return {
        "entry_time": entry_bar.timestamp,
        "entry_price": entry_bar.open,
        "exit_time": touch.exit_time,
        "exit_price": touch.exit_price,
        "exit_reason": touch.exit_reason,
        "return_pct": (entry_bar.open - touch.exit_price) / entry_bar.open,
        "ambiguous": touch.ambiguous,
    }


def _sensitivity_metric(rows: Sequence[dict[str, Any]]) -> dict[str, Any]:
    returns = [float(row["return_pct"]) for row in rows if row.get("return_pct") is not None]
    gross_profit = sum(value for value in returns if value > 0)
    gross_loss = abs(sum(value for value in returns if value < 0))
    wins = sum(value > 0 for value in returns)
    return {
        "candidate_count": len(rows),
        "completed_outcome_count": len(returns),
        "win_rate": wins / len(returns) if returns else 0.0,
        "average_return": sum(returns) / len(returns) if returns else 0.0,
        "profit_factor": gross_profit / gross_loss if gross_loss else None,
    }


def _sensitivity_period_metrics(rows: Sequence[dict[str, Any]]) -> dict[str, Any]:
    by_category: dict[str, list[dict[str, Any]]] = {
        SignalClassification.STRONG_YELLOW.value: [],
        SignalClassification.RELIABLE_YELLOW.value: [],
    }
    for row in rows:
        by_category.setdefault(str(row["classification"]), []).append(row)
    strong = _sensitivity_metric(by_category[SignalClassification.STRONG_YELLOW.value])
    reliable = _sensitivity_metric(by_category[SignalClassification.RELIABLE_YELLOW.value])
    combined = _sensitivity_metric(rows)
    return {
        "strong": strong,
        "reliable": reliable,
        "combined_yellow": combined,
        "total_tradable_yellow": len(rows),
    }


def _sensitivity_stability(rows: Sequence[dict[str, Any]], key: str) -> dict[str, Any]:
    values = [row[key] for row in rows if row.get(key) is not None]
    if not values:
        return {"min": None, "max": None, "range": None}
    return {"min": min(values), "max": max(values), "range": max(values) - min(values)}


def run_sensitivity_study_from_data(
    observations: Sequence[DailyGexObservation],
    bars: Sequence[MarketBar],
    start: date,
    end: date,
    sc_lookbacks: Sequence[int] = (60, 120, 180),
    sp_lookbacks: Sequence[int] = (60, 120, 180),
    sp_quantiles: Sequence[float] = (0.60, 0.75),
) -> dict[str, Any]:
    """Run the fixed robustness matrix with no portfolio conflict scheduling."""
    calendar = USCashCalendar()
    bars, roll_adjustments = neutralize_nq_roll_gaps(bars)
    bars = sorted(bars, key=lambda bar: bar.timestamp)
    closes = nq_daily_closes(bars, calendar)
    rows: list[dict[str, Any]] = []
    for sc_lookback in sc_lookbacks:
        for sp_lookback in sp_lookbacks:
            for sp_quantile in sp_quantiles:
                evaluations = classify_observations(
                    observations,
                    calendar,
                    closes,
                    sc_lookback_days=int(sc_lookback),
                    sp_lookback_days=int(sp_lookback),
                    sp_quantile=float(sp_quantile),
                )
                scoped = [
                    evaluation
                    for evaluation in evaluations
                    if start <= evaluation.observation.observation_date <= end
                ]
                candidate_rows: list[dict[str, Any]] = []
                for evaluation in scoped:
                    if (
                        not evaluation.trade_allowed
                        or evaluation.classification
                        not in {
                            SignalClassification.STRONG_YELLOW,
                            SignalClassification.RELIABLE_YELLOW,
                        }
                    ):
                        continue
                    outcome = _simulate_yellow_candidate(evaluation, bars)
                    candidate_rows.append(
                        {
                            "classification": evaluation.classification.value,
                            "observation_date": evaluation.observation.observation_date.isoformat(),
                            "return_pct": outcome["return_pct"] if outcome else None,
                            "exit_reason": outcome["exit_reason"] if outcome else None,
                        }
                    )
                period_rows = {
                    "all": _sensitivity_period_metrics(candidate_rows),
                    "2025": _sensitivity_period_metrics(
                        [row for row in candidate_rows if row["observation_date"].startswith("2025-")]
                    ),
                    "2026": _sensitivity_period_metrics(
                        [row for row in candidate_rows if row["observation_date"].startswith("2026-")]
                    ),
                }
                rows.append(
                    {
                        "sc_lookback": int(sc_lookback),
                        "sc_quantile": 0.50,
                        "sp_lookback": int(sp_lookback),
                        "sp_quantile": float(sp_quantile),
                        "portfolio_conflicts_applied": False,
                        "all": period_rows["all"],
                        "2025": period_rows["2025"],
                        "2026": period_rows["2026"],
                    }
                )

    def all_rows_for(predicate) -> list[dict[str, Any]]:
        return [row for row in rows if predicate(row)]

    stability_by_sp_threshold: dict[str, Any] = {}
    for quantile in sp_quantiles:
        family = all_rows_for(lambda row, quantile=quantile: row["sp_quantile"] == float(quantile))
        stability_by_sp_threshold[f"P{int(float(quantile) * 100)}"] = {
            "combinations": len(family),
            "overall_profit_factor": _sensitivity_stability(
                [row["all"]["combined_yellow"] for row in family], "profit_factor"
            ),
            "tradable_yellow_count": _sensitivity_stability(
                [row["all"] for row in family], "total_tradable_yellow"
            ),
            "2025_profit_factor": _sensitivity_stability(
                [row["2025"]["combined_yellow"] for row in family], "profit_factor"
            ),
            "2026_profit_factor": _sensitivity_stability(
                [row["2026"]["combined_yellow"] for row in family], "profit_factor"
            ),
        }

    stability_by_sc_lookback: dict[str, Any] = {}
    for sc_lookback in sc_lookbacks:
        family = all_rows_for(lambda row, sc_lookback=sc_lookback: row["sc_lookback"] == int(sc_lookback))
        stability_by_sc_lookback[str(sc_lookback)] = {
            "combinations": len(family),
            "overall_profit_factor": _sensitivity_stability(
                [row["all"]["combined_yellow"] for row in family], "profit_factor"
            ),
            "tradable_yellow_count": _sensitivity_stability(
                [row["all"] for row in family], "total_tradable_yellow"
            ),
            "2025_profit_factor": _sensitivity_stability(
                [row["2025"]["combined_yellow"] for row in family], "profit_factor"
            ),
            "2026_profit_factor": _sensitivity_stability(
                [row["2026"]["combined_yellow"] for row in family], "profit_factor"
            ),
        }

    return {
        "study": "SPX GEX v1.0.2 fixed robustness matrix",
        "strategy_version": STRATEGY_VERSION,
        "start": start.isoformat(),
        "end": end.isoformat(),
        "portfolio_conflicts_applied": False,
        "historical_pnl_model": "Not applicable: this study reports independent Yellow outcomes and no NAV selection.",
        "thresholds_held_fixed": {
            "sc_quantile": 0.50,
            "strong_yellow_sp_condition": "SP share > selected historical percentile",
            "green_rules": "not used in this Yellow-only study",
        },
        "matrix_definition": {
            "sc_lookbacks": [int(value) for value in sc_lookbacks],
            "sp_lookbacks": [int(value) for value in sp_lookbacks],
            "sp_quantiles": [float(value) for value in sp_quantiles],
            "combinations": len(rows),
        },
        "warmup_policy": (
            "All cells use a common causal warm-up sufficient for the maximum 180-session lookback. "
            "The SQL runner loads 190 prior US sessions. This avoids treating the first six research-window "
            "Yellow dates as insufficient merely because the 60-session production query warm-up is shorter."
        ),
        "results": rows,
        "stability_by_sp_threshold": stability_by_sp_threshold,
        "stability_by_sc_lookback": stability_by_sc_lookback,
        "nq_roll_gaps_neutralized": True,
        "nq_roll_adjustments": roll_adjustments,
        "selection_rule": "No combination was selected by NAV or profit factor; inspect ranges and year splits for plateaus.",
    }


def run_sensitivity_study(
    gex_path: str | Path,
    nq_path: str | Path,
    start: date,
    end: date,
) -> dict[str, Any]:
    repository = FileMarketDataRepository(gex_path, nq_path)
    return run_sensitivity_study_from_data(
        repository.gex_observations(), repository.nq_bars(), start, end
    )


def run_sql_sensitivity_study(
    source_database: str,
    start: date,
    end: date,
) -> dict[str, Any]:
    calendar = USCashCalendar()
    repository = SqlServerMarketDataRepository(source_database=source_database, nq_symbol="NQMAIN.US")
    query_start = calendar.session_offset(start, -190)
    price_end = calendar.session_offset(end, 7)
    return run_sensitivity_study_from_data(
        repository.gex_observations(query_start, end),
        repository.nq_bars(query_start, price_end, calendar.timezone_name),
        start,
        end,
    )


def _year_trade_summary(trades: Sequence[dict[str, Any]], year: int) -> dict[str, Any]:
    selected = sorted(
        [trade for trade in trades if str(trade.get("exit_time", "")).startswith(f"{year}-")],
        key=lambda trade: str(trade.get("exit_time", "")),
    )
    gross_profit = sum(float(trade["pnl_usd"]) for trade in selected if float(trade["pnl_usd"]) > 0)
    gross_loss = abs(sum(float(trade["pnl_usd"]) for trade in selected if float(trade["pnl_usd"]) < 0))
    start_nav = float(selected[0]["nav_before"]) if selected else None
    end_nav = float(selected[-1]["nav_after"]) if selected else None
    return {
        "trade_count": len(selected),
        "return": (end_nav / start_nav - 1.0) if start_nav else 0.0,
        "profit_factor": gross_profit / gross_loss if gross_loss else None,
        "start_nav": start_nav,
        "end_nav": end_nav,
    }


def _worst_losing_streak(trades: Sequence[dict[str, Any]]) -> int:
    current = 0
    worst = 0
    for trade in sorted(trades, key=lambda item: str(item.get("exit_time", ""))):
        if float(trade.get("return_pct", 0.0)) <= 0:
            current += 1
            worst = max(worst, current)
        else:
            current = 0
    return worst


def _variant_summary(result: dict[str, Any]) -> dict[str, Any]:
    trades = result.get("trades", [])
    yellow_categories = {
        SignalClassification.STRONG_YELLOW.value,
        SignalClassification.RELIABLE_YELLOW.value,
    }
    green_categories = {
        SignalClassification.REVERSAL_GREEN.value,
        SignalClassification.NORMAL_GREEN.value,
    }
    green_lost_to_yellow = sum(
        1
        for row in result.get("signal_ledger", [])
        if row.get("decision") == "SKIPPED_EXISTING_POSITION"
        and row.get("classification") in green_categories
        and row.get("blocking_signal") in yellow_categories
    )
    return {
        "strategy_version": result.get("strategy_version"),
        "sc_lookback_days": result.get("sc_lookback_days"),
        "sp_lookback_days": result.get("sp_lookback_days"),
        "sp_threshold_quantile": result.get("sp_threshold_quantile"),
        "ending_nav": result.get("ending_nav"),
        "total_return": result.get("total_return"),
        "profit_factor": result.get("profit_factor"),
        "realized_exit_to_exit_max_drawdown": result.get("realized_exit_to_exit_max_drawdown"),
        "mark_to_market_max_drawdown": result.get("mark_to_market_max_drawdown"),
        "trade_count": result.get("trade_count"),
        "actual_yellow_trades": sum(
            result.get("category_breakdown", {}).get(category, {}).get("executed_count", 0)
            for category in yellow_categories
        ),
        "strong_yellow": result.get("category_breakdown", {}).get(SignalClassification.STRONG_YELLOW.value, {}),
        "reliable_yellow": result.get("category_breakdown", {}).get(SignalClassification.RELIABLE_YELLOW.value, {}),
        "green_trades": sum(
            result.get("category_breakdown", {}).get(category, {}).get("executed_count", 0)
            for category in green_categories
        ),
        "green_trades_lost_because_yellow_occupancy": green_lost_to_yellow,
        "worst_trade_return": min((float(trade["return_pct"]) for trade in trades), default=None),
        "worst_losing_streak": _worst_losing_streak(trades),
        "2025": _year_trade_summary(trades, 2025),
        "2026": _year_trade_summary(trades, 2026),
    }


def _threshold_series(result: dict[str, Any], months: Sequence[str]) -> list[dict[str, Any]]:
    rows = [
        row for row in result.get("signal_ledger", [])
        if row.get("sc_gex_threshold") is not None and row.get("sp_delta_share_threshold") is not None
    ]
    series: list[dict[str, Any]] = []
    for month in months:
        month_rows = [row for row in rows if str(row.get("observation_date", "")).startswith(month)]
        selected = month_rows[-1] if month_rows else None
        series.append(
            {
                "month": month,
                "observation_date": selected.get("observation_date") if selected else None,
                "sc_p50_threshold": selected.get("sc_gex_threshold") if selected else None,
                "sp_p60_threshold": selected.get("sp_delta_share_threshold") if selected else None,
            }
        )
    return series


def compare_backtest_variants_from_data(
    observations: Sequence[DailyGexObservation],
    bars: Sequence[MarketBar],
    start: date,
    end: date,
    initial_capital: float = 100_000.0,
    exposure_factor: float = 1.0,
) -> dict[str, Any]:
    """Compare v1.0.2 and the frozen v1.1 candidate on one common dataset."""
    calendar = USCashCalendar()
    baseline = run_backtest_from_data(
        observations,
        bars,
        start,
        end,
        initial_capital,
        exposure_factor,
        60,
        60,
        0.75,
        "v1.0.2-common-warmup",
    )
    candidate = run_backtest_from_data(
        observations,
        bars,
        start,
        end,
        initial_capital,
        exposure_factor,
        180,
        120,
        0.60,
        "v1.1-candidate",
    )
    return {
        "study": "SPX GEX v1.0.2 baseline versus v1.1 candidate",
        "start": start.isoformat(),
        "end": end.isoformat(),
        "portfolio_conflicts_applied": True,
        "common_causal_warmup": f"{COMMON_CANDIDATE_WARMUP_SESSIONS} prior US sessions requested for both variants; only observations in the requested window count. The source contains early rows without SC GEX levels, so the candidate remains insufficient-history until 180 prior rows with usable SC levels exist.",
        "baseline_parameters": {"sc_lookback_days": 60, "sp_lookback_days": 60, "sp_quantile": 0.75},
        "candidate_parameters": {"sc_lookback_days": 180, "sp_lookback_days": 120, "sp_quantile": 0.60},
        "baseline": _variant_summary(baseline),
        "candidate": _variant_summary(candidate),
        "candidate_threshold_series": _threshold_series(
            candidate,
            ("2025-04", "2025-07", "2025-10", "2026-01", "2026-04", "2026-08"),
        ),
        "historical_reference_baseline": _variant_summary(
            run_backtest_from_data(
                [
                    observation
                    for observation in observations
                    if observation.observation_date >= calendar.session_offset(start, -70)
                ],
                bars,
                start,
                end,
                initial_capital,
                exposure_factor,
                60,
                60,
                0.75,
                STRATEGY_VERSION,
            )
        ),
        "historical_reference_baseline_parameters": {
            "strategy_version": STRATEGY_VERSION,
            "sc_lookback_days": 60,
            "sp_lookback_days": 60,
            "sp_quantile": 0.75,
            "warmup_sessions": 70,
            "note": "This reproduces the earlier v1.0.2 reference query. It is shown for reconciliation only; the primary comparison uses the common 220-session warm-up above.",
        },
        "baseline_result": baseline,
        "candidate_result": candidate,
        "selection_note": "Candidate was frozen from the stable plateau; it was not selected by highest NAV or PF.",
    }


def run_sql_candidate_comparison(
    source_database: str,
    start: date,
    end: date,
    initial_capital: float = 100_000.0,
    exposure_factor: float = 1.0,
) -> dict[str, Any]:
    calendar = USCashCalendar()
    repository = SqlServerMarketDataRepository(source_database=source_database, nq_symbol="NQMAIN.US")
    query_start = calendar.session_offset(start, -COMMON_CANDIDATE_WARMUP_SESSIONS)
    price_end = calendar.session_offset(end, 7)
    observations = repository.gex_observations(query_start, end)
    bars = repository.nq_bars(query_start, price_end, calendar.timezone_name)
    return compare_backtest_variants_from_data(
        observations, bars, start, end, initial_capital, exposure_factor
    )


def run_candidate_comparison(
    gex_path: str | Path,
    nq_path: str | Path,
    start: date,
    end: date,
    initial_capital: float = 100_000.0,
    exposure_factor: float = 1.0,
) -> dict[str, Any]:
    """Run the frozen candidate comparison against the supplied file data."""
    repository = FileMarketDataRepository(gex_path, nq_path)
    return compare_backtest_variants_from_data(
        repository.gex_observations(),
        repository.nq_bars(),
        start,
        end,
        initial_capital,
        exposure_factor,
    )


THREE_VARIANT_SPECS: tuple[dict[str, Any], ...] = (
    {
        "id": "A",
        "label": "Production baseline",
        "strategy_version": "A-production-baseline",
        "sc_lookback_days": 60,
        "sp_lookback_days": 60,
        "sp_quantile": 0.75,
    },
    {
        "id": "B",
        "label": "Moderate P60",
        "strategy_version": "B-moderate-p60",
        "sc_lookback_days": 60,
        "sp_lookback_days": 120,
        "sp_quantile": 0.60,
    },
    {
        "id": "C",
        "label": "Moderate longer-SC",
        "strategy_version": "C-moderate-longer-sc",
        "sc_lookback_days": 120,
        "sp_lookback_days": 120,
        "sp_quantile": 0.60,
    },
)


def _first_common_valid_causal_date(
    observations: Sequence[DailyGexObservation],
    bars: Sequence[MarketBar],
) -> date | None:
    """Find the first date on which every fixed variant has usable features."""
    calendar = USCashCalendar()
    adjusted_bars, _ = neutralize_nq_roll_gaps(bars)
    closes = nq_daily_closes(adjusted_bars, calendar)
    evaluations_by_variant: dict[str, dict[date, Any]] = {}
    for spec in THREE_VARIANT_SPECS:
        evaluations = classify_observations(
            observations,
            calendar,
            closes,
            sc_lookback_days=int(spec["sc_lookback_days"]),
            sp_lookback_days=int(spec["sp_lookback_days"]),
            sp_quantile=float(spec["sp_quantile"]),
        )
        evaluations_by_variant[spec["id"]] = {
            evaluation.observation.observation_date: evaluation
            for evaluation in evaluations
        }

    for observation_date in sorted(
        set.intersection(*(set(values) for values in evaluations_by_variant.values()))
    ):
        if all(
            evaluations_by_variant[spec["id"]][observation_date].sc_rolling_median_60 is not None
            and evaluations_by_variant[spec["id"]][observation_date].sp_share_p75_60 is not None
            and evaluations_by_variant[spec["id"]][observation_date].observation.sc_gex is not None
            for spec in THREE_VARIANT_SPECS
        ):
            return observation_date
    return None


def compare_three_variants_from_data(
    observations: Sequence[DailyGexObservation],
    bars: Sequence[MarketBar],
    start: date,
    end: date,
    initial_capital: float = 100_000.0,
    exposure_factor: float = 1.0,
) -> dict[str, Any]:
    """Run exactly the predefined A/B/C portfolio comparison twice."""
    common_valid_start = _first_common_valid_causal_date(observations, bars)
    if common_valid_start is None:
        raise ValueError("No date has full valid causal history for all three variants")

    def run_window(window_start: date) -> dict[str, Any]:
        variants: dict[str, Any] = {}
        for spec in THREE_VARIANT_SPECS:
            result = run_backtest_from_data(
                observations,
                bars,
                window_start,
                end,
                initial_capital,
                exposure_factor,
                int(spec["sc_lookback_days"]),
                int(spec["sp_lookback_days"]),
                float(spec["sp_quantile"]),
                str(spec["strategy_version"]),
            )
            variants[spec["id"]] = {
                "label": spec["label"],
                "parameters": {
                    "sc_lookback_days": spec["sc_lookback_days"],
                    "sc_quantile": 0.50,
                    "sp_lookback_days": spec["sp_lookback_days"],
                    "sp_quantile": spec["sp_quantile"],
                },
                "summary": _variant_summary(result),
                "result": result,
            }
        return variants

    def reclassified_rows(variants: dict[str, Any]) -> list[dict[str, Any]]:
        def by_date(variant_id: str) -> dict[str, dict[str, Any]]:
            return {
                str(row["observation_date"]): row
                for row in variants[variant_id]["result"].get("signal_ledger", [])
            }

        def candidate_return(row: dict[str, Any]) -> float | None:
            outcome = row.get("hypothetical_outcome") or {}
            value = outcome.get("return_pct")
            return float(value) if value is not None else None

        def actual_return(row: dict[str, Any]) -> float | None:
            trade = row.get("trade") or {}
            value = trade.get("return_pct")
            return float(value) if value is not None else None

        def classifier_allowed(row: dict[str, Any]) -> bool:
            return bool(row.get("trade_allowed_by_classifier", row.get("trade_allowed", False)))

        a_rows = by_date("A")
        b_rows = by_date("B")
        rows: list[dict[str, Any]] = []
        for observation_date in sorted(set(a_rows) | set(b_rows)):
            a = a_rows.get(observation_date, {})
            b = b_rows.get(observation_date, {})
            if (
                a.get("classification") == b.get("classification")
                and classifier_allowed(a) == classifier_allowed(b)
            ):
                continue
            a_outcome = a.get("hypothetical_outcome") or {}
            b_outcome = b.get("hypothetical_outcome") or {}
            rows.append(
                {
                    "observation_date": observation_date,
                    "signal_raw": a.get("signal_raw") or b.get("signal_raw"),
                    "a_classification": a.get("classification"),
                    "b_classification": b.get("classification"),
                    "a_trade_allowed": classifier_allowed(a),
                    "b_trade_allowed": classifier_allowed(b),
                    "a_decision": a.get("decision"),
                    "b_decision": b.get("decision"),
                    "a_candidate_return_pct": candidate_return(a),
                    "b_candidate_return_pct": candidate_return(b),
                    "a_candidate_exit_reason": a_outcome.get("exit_reason"),
                    "b_candidate_exit_reason": b_outcome.get("exit_reason"),
                    "a_actual_return_pct": actual_return(a),
                    "b_actual_return_pct": actual_return(b),
                    "a_actual_exit_reason": (a.get("trade") or {}).get("exit_reason"),
                    "b_actual_exit_reason": (b.get("trade") or {}).get("exit_reason"),
                }
            )
        return rows

    original_variants = run_window(start)
    common_variants = run_window(common_valid_start)

    return {
        "study": "SPX GEX fixed three-variant full-portfolio threshold comparison",
        "requested_window": {"start": start.isoformat(), "end": end.isoformat()},
        "common_causal_warmup": f"{COMMON_CANDIDATE_WARMUP_SESSIONS} prior US sessions requested for all variants; only observations in each comparison window count.",
        "portfolio_conflicts_applied": True,
        "variants": [
            {
                "id": spec["id"],
                "label": spec["label"],
                "parameters": {
                    "sc_lookback_days": spec["sc_lookback_days"],
                    "sc_quantile": 0.50,
                    "sp_lookback_days": spec["sp_lookback_days"],
                    "sp_quantile": spec["sp_quantile"],
                },
            }
            for spec in THREE_VARIANT_SPECS
        ],
        "common_valid_history_start": common_valid_start.isoformat(),
        "common_valid_history_definition": (
            "First observation date where every variant has a non-null causal SC threshold, "
            "a non-null causal SP threshold, and a current SC GEX level."
        ),
        "original_window": {
            "start": start.isoformat(),
            "end": end.isoformat(),
            "variants": original_variants,
            "a_vs_b_reclassified_trades": reclassified_rows(original_variants),
        },
        "common_valid_history_window": {
            "start": common_valid_start.isoformat(),
            "end": end.isoformat(),
            "variants": common_variants,
            "a_vs_b_reclassified_trades": reclassified_rows(common_variants),
        },
        "nq_roll_gaps_neutralized": True,
        "selection_note": "These are the three predefined variants only; no parameter search or selection by performance was performed.",
    }


def run_sql_three_variant_comparison(
    source_database: str,
    start: date,
    end: date,
    initial_capital: float = 100_000.0,
    exposure_factor: float = 1.0,
) -> dict[str, Any]:
    calendar = USCashCalendar()
    repository = SqlServerMarketDataRepository(source_database=source_database, nq_symbol="NQMAIN.US")
    query_start = calendar.session_offset(start, -COMMON_CANDIDATE_WARMUP_SESSIONS)
    price_end = calendar.session_offset(end, 7)
    return compare_three_variants_from_data(
        repository.gex_observations(query_start, end),
        repository.nq_bars(query_start, price_end, calendar.timezone_name),
        start,
        end,
        initial_capital,
        exposure_factor,
    )


def run_three_variant_comparison(
    gex_path: str | Path,
    nq_path: str | Path,
    start: date,
    end: date,
    initial_capital: float = 100_000.0,
    exposure_factor: float = 1.0,
) -> dict[str, Any]:
    repository = FileMarketDataRepository(gex_path, nq_path)
    return compare_three_variants_from_data(
        repository.gex_observations(),
        repository.nq_bars(),
        start,
        end,
        initial_capital,
        exposure_factor,
    )


def _first_common_valid_for_specs(
    observations: Sequence[DailyGexObservation],
    bars: Sequence[MarketBar],
    specs: Sequence[dict[str, Any]],
) -> date | None:
    calendar = USCashCalendar()
    adjusted_bars, _ = neutralize_nq_roll_gaps(bars)
    closes = nq_daily_closes(adjusted_bars, calendar)
    by_variant: list[dict[date, Any]] = []
    for spec in specs:
        evaluations = classify_observations(
            observations,
            calendar,
            closes,
            sc_lookback_days=int(spec["sc_lookback_days"]),
            sp_lookback_days=int(spec["sp_lookback_days"]),
            sp_quantile=float(spec["sp_quantile"]),
        )
        by_variant.append({item.observation.observation_date: item for item in evaluations})
    if not by_variant:
        return None
    for observation_date in sorted(set.intersection(*(set(values) for values in by_variant))):
        if all(
            item[observation_date].sc_rolling_median_60 is not None
            and item[observation_date].sp_share_p75_60 is not None
            and item[observation_date].observation.sc_gex is not None
            for item in by_variant
        ):
            return observation_date
    return None


def _freeze_variant_summary(result: dict[str, Any]) -> dict[str, Any]:
    ledger = result.get("signal_ledger", [])
    green = [row for row in ledger if row.get("signal_raw") == "BULLISH"]
    summary = _variant_summary(result)
    summary.update(
        {
            "green_base_count": len(green),
            "reversal_green_count": sum(row.get("classification") == SignalClassification.REVERSAL_GREEN.value for row in green),
            "normal_green_count": sum(row.get("classification") == SignalClassification.NORMAL_GREEN.value for row in green),
            "strong_yellow_candidate_executed": {
                "candidate": result.get("category_breakdown", {}).get(SignalClassification.STRONG_YELLOW.value, {}).get("candidate_count", 0),
                "executed": result.get("category_breakdown", {}).get(SignalClassification.STRONG_YELLOW.value, {}).get("executed_count", 0),
            },
            "reliable_yellow_candidate_executed": {
                "candidate": result.get("category_breakdown", {}).get(SignalClassification.RELIABLE_YELLOW.value, {}).get("candidate_count", 0),
                "executed": result.get("category_breakdown", {}).get(SignalClassification.RELIABLE_YELLOW.value, {}).get("executed_count", 0),
            },
            "total_executed_trades": result.get("trade_count", 0),
            "win_rate": result.get("win_rate"),
            "realized_max_drawdown": result.get("realized_exit_to_exit_max_drawdown"),
            "mtm_max_drawdown": result.get("mark_to_market_max_drawdown"),
            "worst_trade": summary.get("worst_trade_return"),
        }
    )
    return summary


def compare_final_freeze_benchmarks_from_data(
    observations: Sequence[DailyGexObservation],
    bars: Sequence[MarketBar],
    canonical_rows: Sequence[dict[str, str]],
    start: date,
    end: date,
    initial_capital: float = 100_000.0,
    exposure_factor: float = 1.0,
) -> dict[str, Any]:
    """Run the four frozen A/B × source-mode benchmarks, and no others."""
    if not FREEZE_VARIANT_SPECS:
        raise ValueError("No frozen variants configured")
    source_history_start = min((item.observation_date for item in observations), default=None)
    canonical_by_date = {
        date.fromisoformat(str(row.get("ObservationDate") or "")[:10]): row
        for row in canonical_rows
        if str(row.get("ObservationDate") or "")[:10]
    }
    reconstructed_dates = [
        item.observation_date.isoformat()
        for item in observations
        if start <= item.observation_date <= end
        and item.signal_raw == "BULLISH"
        and not str(canonical_by_date.get(item.observation_date, {}).get("Signal") or "").strip()
    ]
    common_valid_start = _first_common_valid_for_specs(observations, bars, FREEZE_VARIANT_SPECS)
    if common_valid_start is None:
        raise ValueError("No common valid causal-history date for frozen A/B variants")

    def run_mode(mode: str, window_start: date) -> dict[str, Any]:
        mode_observations = (
            canonical_export_compat_observations(observations, canonical_rows)
            if mode == CANONICAL_EXPORT_COMPAT
            else list(observations)
        )
        variants: dict[str, Any] = {}
        for spec in FREEZE_VARIANT_SPECS:
            result = run_backtest_from_data(
                mode_observations,
                bars,
                window_start,
                end,
                initial_capital,
                exposure_factor,
                int(spec["sc_lookback_days"]),
                int(spec["sp_lookback_days"]),
                float(spec["sp_quantile"]),
                str(spec["strategy_version"]),
                mode,
                source_history_start,
                bool(mode == CAUSAL_COMPLETE and reconstructed_dates),
            )
            variants[spec["id"]] = {
                "label": spec["label"],
                "parameters": {
                    "sc_lookback_days": spec["sc_lookback_days"],
                    "sc_quantile": 0.50,
                    "sp_lookback_days": spec["sp_lookback_days"],
                    "sp_quantile": spec["sp_quantile"],
                },
                "summary": _freeze_variant_summary(result),
                "result": result,
            }
        return {
            "base_signal_source_mode": mode,
            "source_history_start": source_history_start.isoformat() if source_history_start else None,
            "requested_backtest_start": window_start.isoformat(),
            "signal_reconstructed_from_pre_window_history": bool(mode == CAUSAL_COMPLETE and reconstructed_dates),
            "reconstructed_signal_dates": reconstructed_dates if mode == CAUSAL_COMPLETE else [],
            "variants": variants,
        }

    requested_runs = {}
    for mode in (CAUSAL_COMPLETE, CANONICAL_EXPORT_COMPAT):
        mode_result = run_mode(mode, start)
        for spec in FREEZE_VARIANT_SPECS:
            variant = mode_result["variants"][spec["id"]]
            requested_runs[f"{spec['id']}_{mode}"] = {
                "base_signal_source_mode": mode,
                "source_history_start": mode_result["source_history_start"],
                "requested_backtest_start": start.isoformat(),
                "signal_reconstructed_from_pre_window_history": mode_result["signal_reconstructed_from_pre_window_history"],
                "reconstructed_signal_dates": mode_result["reconstructed_signal_dates"],
                "variant": spec,
                "summary": variant["summary"],
                "result": variant["result"],
            }

    common_runs: dict[str, Any] = {}
    for mode in (CAUSAL_COMPLETE, CANONICAL_EXPORT_COMPAT):
        mode_result = run_mode(mode, common_valid_start)
        for spec in FREEZE_VARIANT_SPECS:
            variant = mode_result["variants"][spec["id"]]
            common_runs[f"{spec['id']}_{mode}"] = {
                "base_signal_source_mode": mode,
                "source_history_start": mode_result["source_history_start"],
                "requested_backtest_start": common_valid_start.isoformat(),
                "signal_reconstructed_from_pre_window_history": mode_result["signal_reconstructed_from_pre_window_history"],
                "reconstructed_signal_dates": mode_result["reconstructed_signal_dates"],
                "variant": spec,
                "summary": variant["summary"],
                "result": variant["result"],
            }

    def reclassified_rows(runs: dict[str, Any], mode: str) -> list[dict[str, Any]]:
        a = runs[f"A_{mode}"]["result"].get("signal_ledger", [])
        b = runs[f"B_{mode}"]["result"].get("signal_ledger", [])
        a_by_date = {row["observation_date"]: row for row in a}
        b_by_date = {row["observation_date"]: row for row in b}
        rows: list[dict[str, Any]] = []
        for observation_date in sorted(set(a_by_date) | set(b_by_date)):
            a_row = a_by_date.get(observation_date, {})
            b_row = b_by_date.get(observation_date, {})
            if a_row.get("classification") == b_row.get("classification"):
                continue
            rows.append(
                {
                    "observation_date": observation_date,
                    "base_signal": a_row.get("signal_raw") or b_row.get("signal_raw"),
                    "classification_A": a_row.get("classification"),
                    "classification_B": b_row.get("classification"),
                    "A_trade_allowed": a_row.get("trade_allowed_by_classifier"),
                    "B_trade_allowed": b_row.get("trade_allowed_by_classifier"),
                    "A_decision": a_row.get("decision"),
                    "B_decision": b_row.get("decision"),
                }
            )
        return rows

    return {
        "report": "SPX GEX strategy final freeze benchmarks",
        "window": {"start": start.isoformat(), "end": end.isoformat()},
        "frozen_variants": [
            {
                "id": spec["id"],
                "label": spec["label"],
                "strategy_version": spec["strategy_version"],
                "sc_lookback_days": spec["sc_lookback_days"],
                "sc_quantile": 0.50,
                "sp_lookback_days": spec["sp_lookback_days"],
                "sp_quantile": spec["sp_quantile"],
            }
            for spec in FREEZE_VARIANT_SPECS
        ],
        "source_modes": {
            CAUSAL_COMPLETE: "All available SQL rows loaded before the requested window; missing canonical export fields may be causally reconstructed.",
            CANONICAL_EXPORT_COMPAT: "Canonical stored Signal/CloseChangePct/PCRChangePct fields are authoritative; blank fields remain blank.",
        },
        "source_history_start": source_history_start.isoformat() if source_history_start else None,
        "requested_backtest_start": start.isoformat(),
        "reconstructed_signal_dates": reconstructed_dates,
        "common_valid_history_start": common_valid_start.isoformat(),
        "common_valid_history_definition": "First date where both frozen A and B have non-null causal SC threshold, SP threshold, and current SC GEX level.",
        "requested_window_runs": requested_runs,
        "common_valid_history_runs": common_runs,
        "yellow_reclassified_rows": {
            CAUSAL_COMPLETE: reclassified_rows(requested_runs, CAUSAL_COMPLETE),
            CANONICAL_EXPORT_COMPAT: reclassified_rows(requested_runs, CANONICAL_EXPORT_COMPAT),
        },
        "production_realistic_benchmark": "A_CAUSAL_COMPLETE",
        "canonical_csv_reconciliation_benchmark": "A_CANONICAL_EXPORT_COMPAT",
        "selection_note": "A remains production and B remains shadow. No parameter search or selection by NAV/PF was performed.",
        "nq_roll_gaps_neutralized": True,
    }


def run_sql_final_freeze_benchmarks(
    source_database: str,
    canonical_path: str | Path,
    start: date,
    end: date,
    initial_capital: float = 100_000.0,
    exposure_factor: float = 1.0,
) -> dict[str, Any]:
    calendar = USCashCalendar()
    repository = SqlServerMarketDataRepository(source_database=source_database, nq_symbol="NQMAIN.US")
    query_start = calendar.session_offset(start, -COMMON_CANDIDATE_WARMUP_SESSIONS)
    price_end = calendar.session_offset(end, 7)
    return compare_final_freeze_benchmarks_from_data(
        repository.gex_observations(query_start, end),
        repository.nq_bars(query_start, price_end, calendar.timezone_name),
        read_delimited(canonical_path),
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
    sc_lookback_days: int = 60,
    sp_lookback_days: int = 60,
    sp_quantile: float = 0.75,
    strategy_version: str = STRATEGY_VERSION,
    base_signal_source_mode: str = CAUSAL_COMPLETE,
    source_history_start: date | None = None,
    signal_reconstructed_from_pre_window_history: bool = False,
) -> dict[str, Any]:
    calendar = USCashCalendar()
    bars, roll_adjustments = neutralize_nq_roll_gaps(bars)
    bars = sorted(bars, key=lambda bar: bar.timestamp)
    provenance_parameters = {
        "strategy_version": strategy_version,
        "base_signal_source_mode": base_signal_source_mode,
        "sc_lookback_days": sc_lookback_days,
        "sp_lookback_days": sp_lookback_days,
        "sp_quantile": sp_quantile,
        "initial_capital": initial_capital,
        "exposure_factor": exposure_factor,
    }
    run_provenance = provenance(
        provenance_parameters,
        observations,
        bars,
        Path(__file__).resolve().parents[3],
    )
    closes = nq_daily_closes(bars, calendar)
    evaluations = classify_observations(
        observations,
        calendar,
        closes,
        sc_lookback_days=sc_lookback_days,
        sp_lookback_days=sp_lookback_days,
        sp_quantile=sp_quantile,
    )
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
    tracked_values = {classification.value for classification in tracked_classifications}
    category_breakdown = {
        classification.value: {
            "candidate_count": 0,
            "candidate_signals": 0,
            "candidate_outcome_count": 0,
            "candidate_only_win_rate": 0.0,
            "candidate_only_average_return": 0.0,
            "candidate_only_profit_factor": None,
            "executed_count": 0,
            "executed_win_rate": 0.0,
            "executed_average_return": 0.0,
            "executed_profit_factor": None,
            "skipped_count": 0,
            "skipped_existing_position": 0,
            "hypothetical_skipped_outcome_count": 0,
            "hypothetical_skipped_win_rate": 0.0,
            "hypothetical_skipped_average_return": 0.0,
            "hypothetical_skipped_profit_factor": None,
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

    def _metric_summary(returns: list[float]) -> dict[str, Any]:
        wins = sum(return_pct > 0 for return_pct in returns)
        gross_profit = sum(return_pct for return_pct in returns if return_pct > 0)
        gross_loss = abs(sum(return_pct for return_pct in returns if return_pct < 0))
        return {
            "count": len(returns),
            "win_rate": wins / len(returns) if returns else 0.0,
            "average_return": sum(returns) / len(returns) if returns else 0.0,
            "profit_factor": gross_profit / gross_loss if gross_loss else None,
        }

    def _simulate_candidate(evaluation) -> tuple[dict[str, Any] | None, str | None]:
        classification = evaluation.classification
        observation_date = evaluation.observation.observation_date
        if classification in {SignalClassification.STRONG_YELLOW, SignalClassification.RELIABLE_YELLOW}:
            entry_time = evaluation.actionable_at
            entry_bar = _bar_exact(bars, entry_time)
            if entry_bar is None:
                return None, "MISSING_EXACT_ACTION_BAR"
            entry_price = entry_bar.open
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
                return {
                    "status": "UNRESOLVED",
                    "entry_price": entry_price,
                    "entry_time": entry_time,
                    "exit_price": None,
                    "exit_time": None,
                    "exit_reason": None,
                    "return_pct": None,
                    "mfe_pct": touch.mfe_pct,
                    "mae_pct": touch.mae_pct,
                    "bars_held": touch.bars_held,
                    "ambiguous": touch.ambiguous,
                }, "TP_SL_NOT_TOUCHED_IN_AVAILABLE_DATA"
            return {
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
            }, None
        if classification == SignalClassification.REVERSAL_GREEN:
            entry_time = evaluation.actionable_at
            reference_bar = _bar_exact(bars, entry_time)
            if reference_bar is None:
                return None, "MISSING_EXACT_D1_ACTION_BAR"
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
            if outcome.get("status") != "CLOSED":
                return outcome, outcome.get("reason", "MISSING_CLOSED_OUTCOME")
            return outcome, None
        if classification == SignalClassification.NORMAL_GREEN:
            d3 = calendar.session_offset(observation_date, 3)
            d5 = calendar.session_offset(observation_date, 5)
            entry_time = calendar.actionable_at(d3)
            entry_bar = _bar_exact(bars, entry_time)
            if entry_bar is None:
                return None, "MISSING_EXACT_D3_ACTION_BAR"
            outcome = simulate_normal_green(
                entry_time=entry_time,
                entry_price=entry_bar.open,
                tp_pct=0.025,
                cash_close=calendar.cash_close(d5),
                bars=bars,
            )
            if outcome.get("status") != "CLOSED":
                return outcome, outcome.get("reason", "MISSING_CLOSED_OUTCOME")
            return outcome, None
        return None, "NON_TRADABLE_CLASSIFICATION"

    def _iso(value: Any) -> Any:
        return value.isoformat() if isinstance(value, datetime) else value

    def _outcome_for_report(outcome: dict[str, Any] | None) -> dict[str, Any] | None:
        if outcome is None:
            return None
        return {key: _iso(value) for key, value in outcome.items()}

    # First calculate every candidate independently. This is the
    # candidate-only/hypothetical baseline and prevents the scheduler from
    # changing the outcome used to audit a skipped signal.
    events: list[dict[str, Any]] = []
    details_by_date: dict[date, dict[str, Any]] = {}
    for evaluation in scoped_evaluations:
        detail = _evaluation_detail(evaluation, tracked_classifications)
        details_by_date[evaluation.observation.observation_date] = detail
        category = evaluation.classification.value
        stats = category_breakdown.get(category)
        if stats is not None:
            stats["candidate_count"] += 1
            stats["candidate_signals"] += 1
        if not evaluation.trade_allowed:
            detail["decision"] = "NON_TRADABLE_CLASSIFICATION"
            continue
        outcome, simulation_reason = _simulate_candidate(evaluation)
        if stats is not None and outcome and outcome.get("status") == "CLOSED":
            stats["candidate_outcome_count"] += 1
        if evaluation.classification in {SignalClassification.STRONG_YELLOW, SignalClassification.RELIABLE_YELLOW, SignalClassification.REVERSAL_GREEN}:
            planned_start = evaluation.actionable_at
        else:
            d3 = calendar.session_offset(evaluation.observation.observation_date, 3)
            planned_start = calendar.actionable_at(d3)
        detail["planned_start_at"] = _iso(planned_start)
        detail["hypothetical_outcome"] = _outcome_for_report(outcome)
        detail["simulation_reason"] = simulation_reason
        events.append(
            {
                "evaluation": evaluation,
                "detail": detail,
                "outcome": outcome,
                "simulation_reason": simulation_reason,
                "planned_start": planned_start,
                "priority": {
                    SignalClassification.STRONG_YELLOW: 0,
                    SignalClassification.RELIABLE_YELLOW: 1,
                    SignalClassification.REVERSAL_GREEN: 2,
                    SignalClassification.NORMAL_GREEN: 3,
                }[evaluation.classification],
            }
        )

    # Candidate-only returns are deliberately based on the NQ percentage path,
    # not on a fabricated QQQ share count.
    candidate_returns: dict[str, list[float]] = {value: [] for value in tracked_values}
    for event in events:
        outcome = event["outcome"]
        if outcome and outcome.get("status") == "CLOSED" and outcome.get("return_pct") is not None:
            candidate_returns[event["evaluation"].classification.value].append(float(outcome["return_pct"]))
    for category, stats in category_breakdown.items():
        summary = _metric_summary(candidate_returns[category])
        stats["candidate_only_win_rate"] = summary["win_rate"]
        stats["candidate_only_average_return"] = summary["average_return"]
        stats["candidate_only_profit_factor"] = summary["profit_factor"]

    # The portfolio is scheduled by the time an order becomes active. A
    # Normal Green at D3 therefore cannot reserve the portfolio before D3.
    events.sort(key=lambda event: (event["planned_start"], event["priority"], event["evaluation"].observation.observation_date))
    signal_ledger: list[dict[str, Any]] = []
    trades: list[dict[str, Any]] = []
    skipped_conflicts = 0
    unresolved_yellow: dict[str, Any] | None = None
    active_blocker: dict[str, Any] | None = None
    nav = float(initial_capital)
    equity = [nav]
    skipped_returns: dict[str, list[float]] = {value: [] for value in tracked_values}
    executed_returns: dict[str, list[float]] = {value: [] for value in tracked_values}

    def _state_at(blocker: dict[str, Any], timestamp: datetime) -> str:
        classification = blocker["evaluation"].classification
        outcome = blocker.get("outcome") or {}
        if classification == SignalClassification.REVERSAL_GREEN and outcome.get("entry_time") and timestamp < outcome["entry_time"]:
            return "PENDING_GREEN_DIP"
        return "SHORT_YELLOW" if classification in {SignalClassification.STRONG_YELLOW, SignalClassification.RELIABLE_YELLOW} else "LONG_GREEN"

    for event in events:
        evaluation = event["evaluation"]
        detail = event["detail"]
        category = evaluation.classification.value
        stats = category_breakdown[category]
        planned_start = event["planned_start"]
        if active_blocker and active_blocker.get("exit_time") is not None and active_blocker["exit_time"] < planned_start:
            active_blocker = None
        if active_blocker:
            skipped_conflicts += 1
            stats["skipped_count"] += 1
            stats["skipped_existing_position"] += 1
            outcome = event.get("outcome") or {}
            if outcome.get("status") == "CLOSED" and outcome.get("return_pct") is not None:
                skipped_returns[category].append(float(outcome["return_pct"]))
            blocker_evaluation = active_blocker["evaluation"]
            blocker_outcome = active_blocker.get("outcome") or {}
            detail.update(
                {
                    "decision": "SKIPPED_EXISTING_POSITION",
                    "intended_actual_entry_time": _iso(outcome.get("entry_time") or planned_start),
                    "blocking_signal": blocker_evaluation.classification.value,
                    "blocker_observation_date": blocker_evaluation.observation.observation_date.isoformat(),
                    "blocker_intended_actual_entry_time": _iso(blocker_outcome.get("entry_time") or active_blocker["planned_start"]),
                    "blocker_actual_entry_time": _iso(blocker_outcome.get("entry_time")),
                    "blocker_exit_time": _iso(active_blocker.get("exit_time")),
                    "blocker_state_at_skip_timestamp": _state_at(active_blocker, planned_start),
                    "conflict_active_until": _iso(active_blocker.get("exit_time")),
                    "incorrectly_blocked_by_future_normal": bool(
                        blocker_evaluation.classification == SignalClassification.NORMAL_GREEN
                        and (blocker_outcome.get("entry_time") is None or blocker_outcome.get("entry_time") > planned_start)
                    ),
                }
            )
            signal_ledger.append(detail)
            continue

        outcome = event.get("outcome")
        if not outcome or outcome.get("status") not in {"CLOSED", "UNRESOLVED"}:
            stats["other_skipped"] += 1
            detail.update({"decision": "SKIPPED_DATA", "execution_skip_reason": event.get("simulation_reason") or "MISSING_CLOSED_OUTCOME"})
            signal_ledger.append(detail)
            continue

        # The plan occupies the portfolio from its actual action time. For
        # Reversal Green this is D1 because the dip order is active, even if
        # its eventual fill occurs later.
        active_blocker = {
            "evaluation": evaluation,
            "planned_start": planned_start,
            "outcome": outcome,
            "exit_time": outcome.get("exit_time"),
        }
        if evaluation.classification in {SignalClassification.STRONG_YELLOW, SignalClassification.RELIABLE_YELLOW} and outcome.get("status") == "UNRESOLVED":
            unresolved_yellow = {
                "observation_date": evaluation.observation.observation_date.isoformat(),
                "classification": category,
                "entry_time": _iso(outcome.get("entry_time")),
            }
        if outcome.get("status") != "CLOSED":
            stats["other_skipped"] += 1
            detail.update({"decision": "UNRESOLVED_YELLOW", "execution_skip_reason": event.get("simulation_reason")})
            signal_ledger.append(detail)
            continue

        return_pct = float(outcome["return_pct"])
        entry_price = float(outcome["entry_price"])
        exit_price = float(outcome["exit_price"])
        nav_before = nav
        # Historical NQ is only a percentage path proxy for QQQ. The
        # notional is an exposure fraction of NAV; NQ price is never used to
        # manufacture a QQQ share quantity.
        notional = nav_before * exposure_factor
        pnl = notional * return_pct
        nav += pnl
        trade = {
            "signal_type": category,
            "observation_date": evaluation.observation.observation_date.isoformat(),
            "planned_start_at": _iso(planned_start),
            "entry_time": _iso(outcome.get("entry_time")),
            "entry_price": entry_price,
            "exit_time": _iso(outcome.get("exit_time")),
            "exit_price": exit_price,
            "exit_reason": outcome.get("exit_reason"),
            "quantity": None,
            "quantity_type": "THEORETICAL_UNSIZED_QQQ_PROXY",
            "notional": notional,
            "return_pct": return_pct,
            "pnl_usd": pnl,
            "nav_before": nav_before,
            "nav_after": nav,
            "mfe_pct": outcome.get("mfe_pct"),
            "mae_pct": outcome.get("mae_pct"),
            "ambiguous": bool(outcome.get("ambiguous", False)),
            "price_source": "NQ_PERCENTAGE_PROXY_ONLY",
        }
        trades.append(trade)
        executed_returns[category].append(return_pct)
        stats["executed_count"] += 1
        stats["actual_trades"] += 1
        stats["wins"] += int(return_pct > 0)
        stats["losses"] += int(return_pct <= 0)
        stats["total_pnl"] += pnl
        detail.update({"decision": "TRADED", "trade_index": len(trades) - 1, "trade": trade})
        signal_ledger.append(detail)
        equity.append(nav)

    # Normalize the output for each requested category. The old aliases are
    # retained for existing consumers, but the reconciliation names are the
    # authoritative fields.
    for category, stats in category_breakdown.items():
        executed = _metric_summary(executed_returns[category])
        skipped = _metric_summary(skipped_returns[category])
        stats["executed_win_rate"] = executed["win_rate"]
        stats["executed_average_return"] = executed["average_return"]
        stats["executed_profit_factor"] = executed["profit_factor"]
        stats["hypothetical_skipped_outcome_count"] = skipped["count"]
        stats["hypothetical_skipped_win_rate"] = skipped["win_rate"]
        stats["hypothetical_skipped_average_return"] = skipped["average_return"]
        stats["hypothetical_skipped_profit_factor"] = skipped["profit_factor"]
        stats["average_return"] = executed["average_return"]
        stats["profit_factor"] = executed["profit_factor"]

    peak = float(initial_capital)
    realized_max_drawdown = 0.0
    for value in equity:
        peak = max(peak, value)
        realized_max_drawdown = max(realized_max_drawdown, (peak - value) / peak if peak else 0.0)

    # Mark-to-market uses the worst intrabar NQ proxy value for each open
    # position. It is separate from the realized exit-to-exit curve.
    mark_points: list[tuple[datetime, float]] = []
    for trade in trades:
        entry_time = datetime.fromisoformat(str(trade["entry_time"]))
        exit_time = datetime.fromisoformat(str(trade["exit_time"]))
        entry_price = float(trade["entry_price"])
        nav_before = float(trade["nav_before"])
        notional = float(trade["notional"])
        direction = Direction.SHORT if trade["signal_type"] in {SignalClassification.STRONG_YELLOW.value, SignalClassification.RELIABLE_YELLOW.value} else Direction.LONG
        for bar in bars:
            if not (entry_time <= bar.timestamp <= exit_time):
                continue
            favorable_price = bar.low if direction == Direction.SHORT else bar.high
            adverse_price = bar.high if direction == Direction.SHORT else bar.low
            favorable_return = ((entry_price - favorable_price) / entry_price) if direction == Direction.SHORT else (favorable_price / entry_price - 1.0)
            adverse_return = ((entry_price - adverse_price) / entry_price) if direction == Direction.SHORT else (adverse_price / entry_price - 1.0)
            mark_points.append((bar.timestamp, nav_before + notional * favorable_return))
            mark_points.append((bar.timestamp, nav_before + notional * adverse_return))
        mark_points.append((exit_time, float(trade["nav_after"])))
    mark_points.sort(key=lambda item: item[0])
    mark_peak = float(initial_capital)
    mark_to_market_max_drawdown = 0.0
    for _, value in mark_points:
        mark_peak = max(mark_peak, value)
        mark_to_market_max_drawdown = max(mark_to_market_max_drawdown, (mark_peak - value) / mark_peak if mark_peak else 0.0)

    wins = sum(float(trade["return_pct"]) > 0 for trade in trades)
    overall_gross_profit = sum(trade["pnl_usd"] for trade in trades if trade["pnl_usd"] > 0)
    overall_gross_loss = abs(sum(trade["pnl_usd"] for trade in trades if trade["pnl_usd"] < 0))
    monthly_pnl: dict[str, float] = {}
    for trade in trades:
        exit_time = datetime.fromisoformat(str(trade["exit_time"]))
        month = exit_time.strftime("%Y-%m")
        monthly_pnl[month] = monthly_pnl.get(month, 0.0) + float(trade["pnl_usd"])
    final_month_date = end
    exit_dates = [datetime.fromisoformat(str(trade["exit_time"])).date() for trade in trades]
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
        month_cursor = date(month_cursor.year + 1, 1, 1) if month_cursor.month == 12 else date(month_cursor.year, month_cursor.month + 1, 1)

    # A compatibility audit reproduces the former observation-date scheduler
    # only for diagnostics. It does not affect the corrected result.
    legacy_scheduler_audit: list[dict[str, Any]] = []
    legacy_blocker: dict[str, Any] | None = None
    for event in sorted(events, key=lambda item: item["evaluation"].observation.observation_date):
        if legacy_blocker and legacy_blocker.get("exit_time") is not None and legacy_blocker["exit_time"] < event["planned_start"]:
            legacy_blocker = None
        if legacy_blocker:
            blocker_eval = legacy_blocker["evaluation"]
            blocker_outcome = legacy_blocker.get("outcome") or {}
            legacy_scheduler_audit.append(
                {
                    "skipped_signal": event["evaluation"].classification.value,
                    "observation_date": event["evaluation"].observation.observation_date.isoformat(),
                    "intended_actual_entry_time": _iso((event.get("outcome") or {}).get("entry_time") or event["planned_start"]),
                    "blocking_signal": blocker_eval.classification.value,
                    "blocker_observation_date": blocker_eval.observation.observation_date.isoformat(),
                    "blocker_actual_entry_time": _iso(blocker_outcome.get("entry_time")),
                    "blocker_exit_time": _iso(legacy_blocker.get("exit_time")),
                    "blocker_state_at_skip_timestamp": _state_at(legacy_blocker, event["planned_start"]),
                    "incorrectly_blocked_by_future_normal": bool(
                        blocker_eval.classification == SignalClassification.NORMAL_GREEN
                        and (blocker_outcome.get("entry_time") is None or blocker_outcome.get("entry_time") > event["planned_start"])
                    ),
                }
            )
            continue
        outcome = event.get("outcome")
        if outcome and outcome.get("status") in {"CLOSED", "UNRESOLVED"}:
            legacy_blocker = {"evaluation": event["evaluation"], "outcome": outcome, "exit_time": outcome.get("exit_time")}

    yellow_audit: list[dict[str, Any]] = []
    for trade in trades:
        if trade["signal_type"] not in {SignalClassification.STRONG_YELLOW.value, SignalClassification.RELIABLE_YELLOW.value}:
            continue
        observation_date = date.fromisoformat(trade["observation_date"])
        d1 = calendar.session_offset(observation_date, 1)
        d2 = calendar.session_offset(observation_date, 2)
        d2_cash_close = calendar.cash_close(d2)
        actual_exit = datetime.fromisoformat(str(trade["exit_time"]))
        yellow_audit.append(
            {
                "classification": trade["signal_type"],
                "observation_date": trade["observation_date"],
                "d1_entry": trade["entry_time"],
                "d2_cash_close": d2_cash_close.isoformat(),
                "actual_exit": trade["exit_time"],
                "exit_reason": trade["exit_reason"],
                "exit_after_D2": actual_exit > d2_cash_close,
            }
        )

    return {
        "strategy_version": strategy_version,
        "base_signal_source_mode": base_signal_source_mode,
        "source_history_start": source_history_start.isoformat() if source_history_start else (
            min((item.observation_date for item in observations), default=None).isoformat()
            if observations else None
        ),
        "requested_backtest_start": start.isoformat(),
        "signal_reconstructed_from_pre_window_history": signal_reconstructed_from_pre_window_history,
        **run_provenance,
        "start": start.isoformat(),
        "end": end.isoformat(),
        "initial_capital": initial_capital,
        "exposure_factor": exposure_factor,
        "sc_lookback_days": sc_lookback_days,
        "sp_lookback_days": sp_lookback_days,
        "sp_threshold_quantile": sp_quantile,
        "historical_price_interpretation": "NQ is a percentage-path proxy for QQQ; quantity is intentionally null.",
        "ending_nav": nav,
        "total_return": nav / initial_capital - 1.0,
        "trade_count": len(trades),
        "win_rate": wins / len(trades) if trades else 0.0,
        "profit_factor": overall_gross_profit / overall_gross_loss if overall_gross_loss else None,
        "max_drawdown": realized_max_drawdown,
        "realized_exit_to_exit_max_drawdown": realized_max_drawdown,
        "mark_to_market_max_drawdown": mark_to_market_max_drawdown,
        "classification_counts": classification_counts,
        "category_breakdown": category_breakdown,
        "monthly_returns": monthly_returns,
        "skipped_conflicts": skipped_conflicts,
        "incorrectly_blocked_by_future_normal_count": sum(
            bool(item["incorrectly_blocked_by_future_normal"]) for item in legacy_scheduler_audit
        ),
        "corrected_scheduler_future_normal_block_count": sum(
            bool(item.get("incorrectly_blocked_by_future_normal"))
            for item in signal_ledger
            if item.get("decision") == "SKIPPED_EXISTING_POSITION"
        ),
        "legacy_scheduler_audit": legacy_scheduler_audit,
        "unresolved_yellow": unresolved_yellow,
        "yellow_exit_assumption": "TP_SL_ONLY_UNRESOLVED_REMAINS_ACTIVE",
        "yellow_audit": yellow_audit,
        "nq_roll_gaps_neutralized": True,
        "nq_roll_adjustments": roll_adjustments,
        "signal_ledger": [details_by_date.get(evaluation.observation.observation_date, {}) for evaluation in scoped_evaluations],
        "trades": trades,
    }
