"""Export the deterministic SPX migration characterization fixtures.

This module is deliberately a test-support adapter.  It calls the current
legacy SPX modules with synthetic inputs only; it never opens SQL Server, IB,
or Pushover connections.

Run from ``backend`` with::

    ..\\venv\\Scripts\\python.exe tests\\support\\export_spx_migration_fixtures.py

Use ``--check`` to rebuild the expected structures in memory and compare them
field-by-field with the checked-in JSON files.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import date, datetime, time, timedelta
from pathlib import Path
from typing import Any, Mapping
from zoneinfo import ZoneInfo

# The verification command executes this file by path from ``backend``.
# Make that invocation independent of the caller's current module search path.
BACKEND_ROOT = Path(__file__).resolve().parents[2]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.spx_gex_strategy.calendar import USCashCalendar
from app.spx_gex_strategy.data import aggregate_daily_gex
from app.spx_gex_strategy.features import classify_observations
from app.spx_gex_strategy.models import (
    DailyGexObservation,
    Direction,
    EnvironmentType,
    MarketBar,
    PortfolioSnapshot,
    PortfolioState,
    SignalClassification,
    SignalEvaluation,
    TradePlan,
)
from app.spx_gex_strategy.notifications import exit_notification, signal_notification
from app.spx_gex_strategy.portfolio import PortfolioManager
from app.spx_gex_strategy.report import render_html_report
from app.spx_gex_strategy.simulation import (
    first_touch,
    simulate_normal_green,
    simulate_reversal_green,
)
from app.spx_gex_strategy.storage import StrategyStore


EXPORTER_VERSION = "spx-migration-fixtures-v1"
PRODUCTION_VERSION = "v1.0.3-production"
SHADOW_VERSION = "v1.1.0-shadow"
FIXED_GENERATED_AT = datetime(2026, 8, 15, 5, 0, tzinfo=ZoneInfo("UTC"))
REPORT_URL = (
    "https://reports.example.test/api/spx-gex/reports/"
    "spx-gex-report-2026-08-05-20260806153000.html?report_token=<REPORT_TOKEN>"
)
NY = ZoneInfo("America/New_York")


def _json_value(value: Any) -> Any:
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    if isinstance(value, (SignalClassification, Direction, EnvironmentType, PortfolioState)):
        return value.value
    if isinstance(value, Mapping):
        return {str(key): _json_value(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_value(item) for item in value]
    if hasattr(value, "__dict__"):
        return _json_value(vars(value))
    return value


def _stable_json(value: Any) -> str:
    return json.dumps(_json_value(value), ensure_ascii=False, sort_keys=True, indent=2) + "\n"


def _observation_json(observation: DailyGexObservation) -> dict[str, Any]:
    return {
        "observation_date": observation.observation_date.isoformat(),
        "bc_gex_delta": observation.bc_gex_delta,
        "bp_gex_delta": observation.bp_gex_delta,
        "sc_gex_delta": observation.sc_gex_delta,
        "sp_gex_delta": observation.sp_gex_delta,
        "total_abs_gex_delta": observation.total_abs_gex_delta,
        "close": observation.close,
        "vwap": observation.vwap,
        "put_call_ratio": observation.put_call_ratio,
        "close_change_pct": observation.close_change_pct,
        "pcr_change_pct": observation.pcr_change_pct,
        "signal_raw": observation.signal_raw,
        "bc_gex": observation.bc_gex,
        "bp_gex": observation.bp_gex,
        "sc_gex": observation.sc_gex,
        "sp_gex": observation.sp_gex,
        "source_rows": observation.source_rows,
        "sp_delta_share": observation.sp_delta_share,
        "derived": observation.derived,
    }


def _evaluation_json(evaluation: SignalEvaluation, history_count: int) -> dict[str, Any]:
    return {
        "classification": evaluation.classification.value,
        "trade_allowed": evaluation.trade_allowed,
        "skip_reason": evaluation.skip_reason,
        "observation_date": evaluation.observation.observation_date.isoformat(),
        "action_date": evaluation.action_date.isoformat() if evaluation.action_date else None,
        "actionable_at": evaluation.actionable_at.isoformat() if evaluation.actionable_at else None,
        "causal_history_count": history_count,
        "sc_threshold": evaluation.sc_rolling_median_60,
        "sc_percentile": evaluation.sc_percentile_60,
        "sp_threshold": evaluation.sp_share_p75_60,
        "sp_percentile": evaluation.sp_share_percentile_60,
        "prior_5d_nq_return": evaluation.prior_5d_nq_return,
        "strategy_version": PRODUCTION_VERSION,
    }


def _raw_rows_for_day(
    observation_date: date,
    *,
    sc_level: float | None = 100.0,
    sp_delta: float = 1.0,
    signal: str | None = None,
    close: float | None = None,
) -> list[dict[str, Any]]:
    values = {
        "BC": (1.0, 10.0),
        "BP": (-1.0, -10.0),
        "SC": (1.0, sc_level),
        "SP": (sp_delta, -20.0),
    }
    return [
        {
            "ObservationDate": observation_date.isoformat(),
            "CapitalType": capital_type,
            "GEXDelta": gex_delta,
            "GEX": gex,
            "Close": close,
            "VWAP": close,
            "Signal": signal,
            "Ticker": "SPXW.US",
        }
        for capital_type, (gex_delta, gex) in values.items()
    ]


def _class_case(
    name: str,
    target_signal: str | None,
    *,
    target_sc: float | None = 100.0,
    target_sp_delta: float = 1.0,
    history: bool = False,
    nq_return: float | None = None,
    expected_error: str | None = None,
) -> dict[str, Any]:
    calendar = USCashCalendar()
    target = date(2026, 2, 2)
    raw_rows: list[dict[str, Any]] = []
    prior_dates = [calendar.session_offset(target, -offset) for offset in range(60, 0, -1)] if history else []
    for index, prior_date in enumerate(prior_dates):
        raw_rows.extend(_raw_rows_for_day(prior_date, close=None, sc_level=100.0, sp_delta=1.0))

    raw_rows.extend(
        _raw_rows_for_day(
            target,
            close=None,
            sc_level=target_sc,
            sp_delta=target_sp_delta,
            signal=target_signal,
        )
    )
    observations = aggregate_daily_gex(raw_rows)
    nq_daily_closes: dict[str, float] = {}
    if nq_return is not None:
        prior_date = calendar.session_offset(target, -5)
        nq_daily_closes[prior_date.isoformat()] = 100.0
        nq_daily_closes[target.isoformat()] = 100.0 * (1.0 + nq_return)
    if expected_error:
        expected: dict[str, Any] = {"error_type": expected_error}
    else:
        closes = {date.fromisoformat(key): value for key, value in nq_daily_closes.items()}
        evaluations = classify_observations(observations, calendar, closes)
        expected = _evaluation_json(evaluations[-1], len(observations) - 1)
    return {
        "name": name,
        "strategy_version": PRODUCTION_VERSION,
        "inputs": {
            "raw_gex_rows": raw_rows,
            "nq_daily_closes": nq_daily_closes,
            "lookback_days": 60,
            "sc_lookback_days": 60,
            "sp_lookback_days": 60,
            "sp_quantile": 0.75,
        },
        "daily_observations": [_observation_json(item) for item in observations],
        "expected": expected,
        "invariants": {
            "current_observation_excluded_from_thresholds": bool(history),
            "sc_classification_field": "sc_gex_level",
            "yellow_variant_a": PRODUCTION_VERSION,
            "yellow_variant_b": SHADOW_VERSION,
        },
    }


def _classification_cases() -> list[dict[str, Any]]:
    cases = [
        _class_case("no-signal", None),
        _class_case("insufficient-history", "BEARISH"),
        _class_case("strong-yellow", "BEARISH", target_sc=100.0, target_sp_delta=6.0, history=True),
        _class_case("reliable-yellow", "BEARISH", target_sc=100.0, target_sp_delta=1.0, history=True),
        _class_case("mixed-yellow", "BEARISH", target_sc=200.0, target_sp_delta=6.0, history=True),
        _class_case("weak-yellow", "BEARISH", target_sc=200.0, target_sp_delta=1.0, history=True),
        _class_case("reversal-green", "BULLISH", nq_return=-0.01),
        _class_case("normal-green", "BULLISH", nq_return=0.01),
        _class_case(
            "missing-current-sc-level",
            "BEARISH",
            target_sc=None,
            target_sp_delta=6.0,
            history=True,
        ),
    ]

    duplicate_date = date(2026, 2, 2)
    duplicate_rows = _raw_rows_for_day(duplicate_date, signal="BEARISH") + _raw_rows_for_day(
        duplicate_date, signal="BEARISH"
    )
    cases.append(
        {
            "name": "duplicate-observation-date-rejected",
            "strategy_version": PRODUCTION_VERSION,
            "inputs": {"raw_gex_rows": duplicate_rows, "nq_daily_closes": {}},
            "daily_observations": [
                _observation_json(item)
                for item in (aggregate_daily_gex(duplicate_rows[:4]) + aggregate_daily_gex(duplicate_rows[4:]))
            ],
            "expected": {"error_type": "ValueError", "error_message": "Duplicate GEX observation dates are not allowed"},
            "invariants": {"duplicate_dates_fail_closed": True},
        }
    )
    return cases


def _bar_json(bar: MarketBar) -> dict[str, Any]:
    return {
        "timestamp": bar.timestamp.isoformat(),
        "open": bar.open,
        "high": bar.high,
        "low": bar.low,
        "close": bar.close,
        "symbol": bar.symbol,
    }


def _lifecycle_cases() -> list[dict[str, Any]]:
    zone = NY
    yellow_time = datetime(2026, 2, 3, 3, 30, tzinfo=zone)
    close_time = datetime(2026, 2, 6, 16, 0, tzinfo=zone)
    cases: list[dict[str, Any]] = []

    def touch_case(name: str, bars: list[MarketBar], time_exit: datetime | None = None) -> None:
        result = first_touch(100.0, Direction.SHORT, 99.2, 101.0, bars, time_exit=time_exit)
        cases.append(
            {
                "name": name,
                "kind": "first_touch",
                "inputs": {
                    "entry": 100.0,
                    "side": "SHORT",
                    "tp": 99.2,
                    "sl": 101.0,
                    "time_exit": time_exit,
                    "bars": [_bar_json(item) for item in bars],
                    "qqq_entry_price": 500.0,
                },
                "expected": {
                    "event_path": ["ENTRY", result.exit_reason or "OPEN"],
                    "result": _json_value(result),
                    "terminal_state": "FLAT" if result.exit_price is not None else "SHORT_YELLOW",
                    "proxy_price_basis": "NQ_PROXY",
                    "qqq_price_basis": "QQQ_QUOTE",
                },
            }
        )

    touch_case(
        "yellow-entry-tp",
        [MarketBar(yellow_time, 100, 100.3, 99.0, 99.2)],
    )
    touch_case(
        "yellow-entry-sl",
        [MarketBar(yellow_time, 100, 101.2, 99.8, 101.0)],
    )
    touch_case(
        "yellow-time-exit",
        [
            MarketBar(datetime(2026, 2, 3, 15, 0, tzinfo=zone), 100, 100.2, 99.8, 100.1),
        ],
        time_exit=datetime(2026, 2, 3, 16, 0, tzinfo=zone),
    )

    reference = datetime(2026, 2, 2, 3, 30, tzinfo=zone)
    d3 = datetime(2026, 2, 5, 3, 30, tzinfo=zone)
    dip_bars = [
        MarketBar(reference, 100, 100.2, 98.9, 99.5),
        MarketBar(datetime(2026, 2, 6, 15, 30, tzinfo=zone), 99.5, 100, 99, 99.5),
    ]
    dip_result = simulate_reversal_green(reference, 100, 0.01, d3, d3, close_time, dip_bars)
    cases.append(
        {
            "name": "reversal-green-dip-fill",
            "kind": "reversal_green",
            "inputs": {"reference_time": reference, "reference_price": 100.0, "dip_pct": 0.01, "dip_expiry": d3, "fallback_time": d3, "cash_close": close_time, "bars": [_bar_json(item) for item in dip_bars], "qqq_reference_price": 500.0, "qqq_entry_price": 495.0},
            "expected": {"event_path": ["SIGNAL_READY", "DIP_ORDER_UPDATE", "D5_TIME_EXIT"], "result": dip_result, "terminal_state": "FLAT", "qqq_price_basis": "QQQ_QUOTE"},
        }
    )

    fallback_bars = [
        MarketBar(reference, 100, 100.2, 99.5, 100),
        MarketBar(d3, 101, 101.5, 100.5, 101),
        MarketBar(datetime(2026, 2, 6, 15, 30, tzinfo=zone), 101, 102, 100, 101.5),
    ]
    fallback_result = simulate_reversal_green(reference, 100, 0.01, d3, d3, close_time, fallback_bars)
    cases.append(
        {
            "name": "reversal-green-d3-fallback",
            "kind": "reversal_green",
            "inputs": {"reference_time": reference, "reference_price": 100.0, "dip_pct": 0.01, "dip_expiry": d3, "fallback_time": d3, "cash_close": close_time, "bars": [_bar_json(item) for item in fallback_bars], "qqq_reference_price": 500.0, "qqq_entry_price": 505.0},
            "expected": {"event_path": ["SIGNAL_READY", "D3_FALLBACK", "D5_TIME_EXIT"], "result": fallback_result, "terminal_state": "FLAT"},
        }
    )

    missing_fallback = simulate_reversal_green(reference, 100, 0.01, d3, d3, close_time, [fallback_bars[0], fallback_bars[2]])
    cases.append(
        {
            "name": "missing-exact-d3-action-bar",
            "kind": "reversal_green",
            "inputs": {"reference_time": reference, "reference_price": 100.0, "dip_pct": 0.01, "dip_expiry": d3, "fallback_time": d3, "cash_close": close_time, "bars": [_bar_json(item) for item in [fallback_bars[0], fallback_bars[2]]]},
            "expected": {"event_path": ["PENDING_GREEN_DIP", "DATA_ERROR"], "result": missing_fallback, "terminal_state": "PENDING_GREEN_DIP"},
        }
    )

    normal_entry = datetime(2026, 2, 5, 3, 30, tzinfo=zone)
    normal_bars = [
        MarketBar(normal_entry, 100, 102.6, 99.5, 102.5),
        MarketBar(datetime(2026, 2, 6, 15, 30, tzinfo=zone), 102, 102.5, 101, 102),
        MarketBar(close_time, 102, 110, 101, 109),
    ]
    normal_result = simulate_normal_green(normal_entry, 100, 0.025, close_time, normal_bars)
    cases.append(
        {
            "name": "normal-green-deferred-d3-entry",
            "kind": "normal_green",
            "inputs": {"entry_time": normal_entry, "entry_price": 100.0, "tp_pct": 0.025, "cash_close": close_time, "bars": [_bar_json(item) for item in normal_bars], "qqq_entry_price": 500.0},
            "expected": {"event_path": ["SIGNAL_RECORDED", "D3_MARKET", "TP_HIT"], "result": normal_result, "terminal_state": "FLAT"},
        }
    )
    cases.append(
        {
            "name": "d5-cash-close-exit",
            "kind": "normal_green",
            "inputs": {"entry_time": normal_entry, "entry_price": 100.0, "tp_pct": 0.25, "cash_close": close_time, "bars": [_bar_json(item) for item in [normal_bars[0], normal_bars[1], normal_bars[2]]]},
            "expected": {"event_path": ["D3_MARKET", "TIME_EXIT"], "result": simulate_normal_green(normal_entry, 100, 0.25, close_time, normal_bars), "terminal_state": "FLAT", "cash_close_bar_rule": "last_bar_timestamp_strictly_before_cash_close"},
        }
    )

    def portfolio_evaluation(observation_date: date, classification: SignalClassification) -> SignalEvaluation:
        action_date = USCashCalendar().next_session(observation_date)
        observation = DailyGexObservation(
            observation_date=observation_date,
            bc_gex_delta=1,
            bp_gex_delta=-1,
            sc_gex_delta=-1,
            sp_gex_delta=1,
            total_abs_gex_delta=4,
            close=None,
            vwap=None,
            put_call_ratio=None,
            close_change_pct=None,
            pcr_change_pct=None,
            signal_raw="BEARISH" if "YELLOW" in classification.value else "BULLISH",
            sc_gex=100,
        )
        return SignalEvaluation(observation, classification, USCashCalendar().actionable_at(action_date), action_date, True, None)

    occupied_store = StrategyStore(":memory:")
    occupied_manager = PortfolioManager(occupied_store, USCashCalendar(), PRODUCTION_VERSION)
    first_eval = portfolio_evaluation(date(2026, 2, 2), SignalClassification.STRONG_YELLOW)
    first_signal, _ = occupied_store.save_signal(first_eval, PRODUCTION_VERSION, EnvironmentType.FORWARD_PAPER)
    first_plan, _ = occupied_manager.reserve_plan(first_eval, first_signal, reference_price=100.0)
    assert first_plan is not None
    occupied_manager.open_trade(first_plan, 100.0, first_eval.actionable_at, quote_price=500.0)
    second_eval = portfolio_evaluation(date(2026, 2, 3), SignalClassification.RELIABLE_YELLOW)
    occupied_reason = occupied_manager.conflict_reason(second_eval.classification, second_eval.actionable_at)
    cases.append(
        {
            "name": "execution-book-occupied",
            "kind": "portfolio_conflict",
            "inputs": {"initial_state": "FLAT", "first_classification": "STRONG_YELLOW", "second_classification": "RELIABLE_YELLOW", "qqq_entry_price": 500.0},
            "expected": {"reason": occupied_reason, "state_after_first_entry": occupied_manager.snapshot.state.value, "second_trade_allowed": False, "terminal_state": "SHORT_YELLOW"},
        }
    )

    stale_store = StrategyStore(":memory:")
    stale_manager = PortfolioManager(stale_store, USCashCalendar(), PRODUCTION_VERSION)
    stale_eval = portfolio_evaluation(date(2026, 1, 5), SignalClassification.STRONG_YELLOW)
    stale_signal, _ = stale_store.save_signal(stale_eval, PRODUCTION_VERSION, EnvironmentType.FORWARD_PAPER)
    stale_manager.reserve_plan(stale_eval, stale_signal, reference_price=100.0)
    candidate_at = USCashCalendar().actionable_at(date(2026, 2, 3))
    cases.append(
        {
            "name": "stale-planned-work-does-not-reserve-early",
            "kind": "portfolio_conflict",
            "inputs": {"old_first_action_at": stale_eval.actionable_at, "candidate_action_at": candidate_at, "stored_plan_status": "PLANNED"},
            "expected": {"conflict_reason": stale_manager.conflict_reason(SignalClassification.REVERSAL_GREEN, candidate_at), "terminal_state": stale_manager.snapshot.state.value, "rule": "only_same_action_timestamp_or_unexpired_dip_overlaps"},
        }
    )

    missing_quote_store = StrategyStore(":memory:")
    missing_quote_manager = PortfolioManager(missing_quote_store, USCashCalendar(), PRODUCTION_VERSION)
    quote_eval = portfolio_evaluation(date(2026, 2, 2), SignalClassification.STRONG_YELLOW)
    quote_signal, _ = missing_quote_store.save_signal(quote_eval, PRODUCTION_VERSION, EnvironmentType.FORWARD_PAPER)
    quote_plan, _ = missing_quote_manager.reserve_plan(quote_eval, quote_signal, reference_price=100.0)
    assert quote_plan is not None
    try:
        missing_quote_manager.open_trade(quote_plan, 100.0, quote_eval.actionable_at, quote_price=0.0)
    except Exception as exc:  # Characterize the exact fail-closed seam.
        quote_error = {"error_type": type(exc).__name__, "error_message": str(exc)}
    else:  # pragma: no cover - protects the fixture from silently weakening.
        quote_error = {"error_type": None, "error_message": None}
    cases.append(
        {
            "name": "missing-qqq-quote",
            "kind": "portfolio_validation",
            "inputs": {"proxy_entry_price": 100.0, "qqq_entry_price": None, "quote_argument": 0.0},
            "expected": {**quote_error, "terminal_state": missing_quote_manager.snapshot.state.value, "trade_opened": False},
        }
    )
    return cases


def _calendar_cases() -> dict[str, Any]:
    calendar = USCashCalendar()
    observation = date(2026, 1, 5)
    early_close_date = date(2026, 11, 27)
    early_bars = [
        MarketBar(datetime(2026, 11, 27, 12, 30, tzinfo=NY), 100, 101, 99, 100.5),
        MarketBar(datetime(2026, 11, 27, 13, 0, tzinfo=NY), 100.5, 103, 100, 102.0),
    ]
    return {
        "timezone": calendar.timezone_name,
        "cases": [
            {"name": "standard-action-time", "session": "2026-01-05", "actionable_at": calendar.actionable_at(date(2026, 1, 5)).isoformat(), "offset": "-05:00"},
            {"name": "daylight-saving-action-time", "session": "2026-07-06", "actionable_at": calendar.actionable_at(date(2026, 7, 6)).isoformat(), "offset": "-04:00"},
            {"name": "weekend-skips-to-monday", "date": "2026-01-09", "next_session": calendar.next_session(date(2026, 1, 9)).isoformat()},
            {"name": "us-holiday-skipped", "date": "2026-01-19", "is_session": calendar.is_session(date(2026, 1, 19)), "next_session": calendar.next_session(date(2026, 1, 19)).isoformat()},
            {"name": "early-close", "session": early_close_date.isoformat(), "cash_close": calendar.cash_close(early_close_date).isoformat()},
            {
                "name": "session-offsets-d1-d2-d3-d5",
                "observation_date": observation.isoformat(),
                "D1": calendar.session_offset(observation, 1).isoformat(),
                "D2": calendar.session_offset(observation, 2).isoformat(),
                "D3": calendar.session_offset(observation, 3).isoformat(),
                "D5": calendar.session_offset(observation, 5).isoformat(),
            },
            {
                "name": "early-close-bar-selection",
                "session": early_close_date.isoformat(),
                "bars": [_bar_json(item) for item in early_bars],
                "cash_close": calendar.cash_close(early_close_date).isoformat(),
                "selected_bar": _bar_json(early_bars[0]),
                "rule": "timestamp_strictly_before_official_cash_close",
            },
        ],
    }


def _simple_evaluation(
    observation_date: date,
    classification: SignalClassification,
    *,
    trade_allowed: bool = True,
    skip_reason: str | None = None,
    prior_return: float | None = None,
) -> SignalEvaluation:
    calendar = USCashCalendar()
    action_date = calendar.next_session(observation_date)
    observation = DailyGexObservation(
        observation_date=observation_date,
        bc_gex_delta=10,
        bp_gex_delta=-10,
        sc_gex_delta=-5,
        sp_gex_delta=2,
        total_abs_gex_delta=27,
        close=None,
        vwap=None,
        put_call_ratio=None,
        close_change_pct=None,
        pcr_change_pct=None,
        signal_raw="BEARISH" if "YELLOW" in classification.value else "BULLISH",
        sc_gex=100,
        sp_gex=-20,
        derived={
            "SC_GEX_current": 100,
            "SC_GEX_threshold": 200,
            "SP_delta_share_current": 2 / 27,
            "SP_delta_share_threshold": 0.10,
            "prior_5d_nq_return": prior_return,
            "SC_lookback_days": 60,
            "SP_lookback_days": 60,
            "SP_threshold_quantile": 0.75,
        },
    )
    return SignalEvaluation(
        observation=observation,
        classification=classification,
        actionable_at=calendar.actionable_at(action_date),
        action_date=action_date,
        trade_allowed=trade_allowed,
        skip_reason=skip_reason,
        sc_rolling_median_60=200,
        sc_percentile_60=10,
        sp_share_p75_60=0.10,
        sp_share_percentile_60=25,
        prior_5d_nq_return=prior_return,
    )


def _report_case(
    name: str,
    evaluation: SignalEvaluation | None,
    *,
    with_plan: bool = False,
    shadow: bool = False,
    archive: bool = False,
) -> dict[str, Any]:
    store = StrategyStore(":memory:")
    store.ensure_portfolio(100000.0, 1.0)
    archive_links = [
        {"report_date": "2026-08-04", "generated_at": "2026-08-05T05:00:00+00:00", "url": REPORT_URL.replace("2026-08-05", "2026-08-04")},
        {"report_date": "2026-08-05", "generated_at": "2026-08-06T05:00:00+00:00", "url": REPORT_URL},
    ] if archive else []
    if evaluation is not None:
        signal_id, _ = store.save_signal(evaluation, PRODUCTION_VERSION, EnvironmentType.FORWARD_PAPER)
        if with_plan:
            manager = PortfolioManager(store, USCashCalendar(), PRODUCTION_VERSION)
            plan = manager.build_plan(evaluation, reference_price=20000.0)
            plan.signal_id = signal_id
            store.save_plan(plan)
        if shadow:
            shadow_eval = _simple_evaluation(evaluation.observation.observation_date, SignalClassification.WEAK_YELLOW, trade_allowed=False, skip_reason="NON_TRADABLE_YELLOW_CLASSIFICATION")
            shadow_id, _ = store.save_signal(shadow_eval, SHADOW_VERSION, EnvironmentType.FORWARD_PAPER)
            store.save_strategy_comparison(
                {
                    "observation_date": evaluation.observation.observation_date.isoformat(),
                    "production_signal_id": signal_id,
                    "shadow_signal_id": shadow_id,
                    "production_strategy_version": PRODUCTION_VERSION,
                    "shadow_strategy_version": SHADOW_VERSION,
                    "environment_type": EnvironmentType.FORWARD_PAPER.value,
                    "production_classification": evaluation.classification.value,
                    "shadow_classification": shadow_eval.classification.value,
                    "production_trade_allowed": int(evaluation.trade_allowed),
                    "shadow_trade_allowed": int(shadow_eval.trade_allowed),
                    "production_outcome_status": "NOT_RUN",
                    "shadow_outcome_status": "CLOSED",
                    "shadow_outcome_json": json.dumps({"return_pct": 0.0125}, sort_keys=True),
                }
            )
    html = render_html_report(
        store,
        PRODUCTION_VERSION,
        qqq_reference={"reference_price": 500.0, "reference_timestamp": "2026-08-05T03:30:00-04:00", "reference_source": "IB_HISTORICAL_03:30"},
        archive_links=archive_links,
        focus_date=evaluation.observation.observation_date if evaluation else None,
        report_as_of=date(2026, 8, 5),
        generated_at=FIXED_GENERATED_AT,
    )
    normalized = re.sub(r"generated_at=[^ >]+", "generated_at=<GENERATED_AT>", html)
    required = {
        "no-signal": ["SPX GEX Signal Report", "No current signal", "DO NOT PLACE AN ORDER"],
        "reliable-yellow": ["Reliable Yellow", "ACTION: SHORT QQQ at D1 03:30 ET.", PRODUCTION_VERSION],
        "reversal-green": ["Reversal Green action plan", "ACTION: PLACE A QQQ BUY LIMIT ORDER.", "D3 03:30 ET"],
        "production-shadow-comparison": ["Production vs " + SHADOW_VERSION, "RELIABLE_YELLOW", "WEAK_YELLOW"],
        "historical-archive": ["Historical reports", "2026-08-04", "2026-08-05"],
    }[name]
    prohibited = {
        "no-signal": ["ACTION: PLACE A QQQ"],
        "reliable-yellow": ["Reversal Green action plan"],
        "reversal-green": ["tradable LONG QQQ"],
        "production-shadow-comparison": [],
        "historical-archive": [],
    }[name]
    return {
        "name": name,
        "strategy_version": PRODUCTION_VERSION,
        "normalized_html": normalized,
        "sha256": hashlib.sha256(normalized.encode("utf-8")).hexdigest(),
        "required_fragments": required,
        "prohibited_fragments": prohibited,
        "metadata": {"report_as_of": "2026-08-05", "observation_date": evaluation.observation.observation_date.isoformat() if evaluation else None, "generated_at": FIXED_GENERATED_AT.isoformat(), "immutable_snapshot_url": REPORT_URL, "archive_count": len(archive_links)},
    }


def _report_cases() -> dict[str, Any]:
    reliable = _simple_evaluation(date(2026, 8, 5), SignalClassification.RELIABLE_YELLOW)
    reversal = _simple_evaluation(date(2026, 8, 5), SignalClassification.REVERSAL_GREEN, prior_return=-0.01)
    return {
        "cases": [
            _report_case("no-signal", None),
            _report_case("reliable-yellow", reliable, with_plan=True),
            _report_case("reversal-green", reversal),
            _report_case("production-shadow-comparison", reliable, shadow=True),
            _report_case("historical-archive", reliable, archive=True),
        ],
        "route_cases": [
            {"path": "/api/spx-gex/report.html", "kind": "latest_alias", "immutable": False, "token_required_when_configured": True},
            {"path": "/api/spx-gex/reports", "kind": "archive_catalog", "immutable": True, "response_shape": {"items": "newest_first"}},
            {"path": "/api/spx-gex/reports/spx-gex-report-<date>-<id>.html", "kind": "filename_snapshot", "immutable": True, "lookup": "file_name"},
            {"path": "/api/spx-gex/reports/<date>.html?report_id=<id>", "kind": "legacy_exact_snapshot", "immutable": True, "lookup": "date_and_report_id"},
            {"path": "/api/spx-gex/reports/<date>.html", "kind": "legacy_date_fallback", "immutable": True, "lookup": "latest_for_date"},
            {"path": "/api/spx-gex/live-nq", "kind": "live_dependency", "immutable": False, "error_status": 502},
        ],
    }


def _notification_case(name: str, notification_type: str, title: str, body: str, *, priority: str = "high") -> dict[str, Any]:
    return {"name": name, "notification_type": notification_type, "title": title, "body": body, "priority": priority, "url": REPORT_URL, "url_title": "Open SPX GEX HTML report"}


def _notification_cases() -> dict[str, Any]:
    snapshot = PortfolioSnapshot(PortfolioState.FLAT, 100000.0, 100000.0, 1.0)
    reliable = _simple_evaluation(date(2026, 8, 5), SignalClassification.RELIABLE_YELLOW)
    reliable_plan = TradePlan("signal", SignalClassification.RELIABLE_YELLOW, date(2026, 8, 5), date(2026, 8, 6), reliable.actionable_at, Direction.SHORT, "D1_MARKET", tp_pct=0.004, sl_pct=0.008)
    reversal = _simple_evaluation(date(2026, 8, 5), SignalClassification.REVERSAL_GREEN, prior_return=-0.01)
    skipped = _simple_evaluation(date(2026, 8, 5), SignalClassification.WEAK_YELLOW, trade_allowed=False, skip_reason="NON_TRADABLE_YELLOW_CLASSIFICATION")
    cases = []
    notification_type, title, body = signal_notification(reliable, snapshot, PRODUCTION_VERSION, plan=reliable_plan, reference_price=20000, nq_snapshot={"price": 20000, "previous_close": 19900, "move_fraction": 0.005, "source": "fixture"}, qqq_snapshot={"price": 500, "source": "fixture"}, report_url=REPORT_URL)
    cases.append(_notification_case("actionable-signal", notification_type, title, body))
    notification_type, title, body = signal_notification(skipped, snapshot, PRODUCTION_VERSION, report_url=REPORT_URL)
    cases.append(_notification_case("skipped-signal", notification_type, title, body))
    cases.append(_notification_case("pending-dip-event", "DIP_ORDER_UPDATE", "âœ… REVERSAL GREEN DIP FILLED", "Dip order filled at $99.00\nExit: D5 cash close\nShadow NAV: $100,000.00\nHTML Report: " + REPORT_URL + "\nStrategy Version: " + PRODUCTION_VERSION))
    cases.append(_notification_case("d3-fallback", "D3_FALLBACK", "ðŸŸ¢ REVERSAL GREEN â€” D3 FALLBACK BUY", "Dip order was not filled.\nBUY QQQ at D3 03:30 proxy price $101.00\nExit: D5 cash close\nShadow NAV: $100,000.00\nHTML Report: " + REPORT_URL + "\nStrategy Version: " + PRODUCTION_VERSION))
    for reason in ("TP_HIT", "SL_HIT", "TIME_EXIT"):
        exit_type, exit_title, exit_body = exit_notification({"trade_id": "fixture-trade", "entry_price": 500.0, "exit_price": 502.5 if reason == "TP_HIT" else 496.0 if reason == "SL_HIT" else 501.0, "return_pct": 0.005 if reason == "TP_HIT" else -0.008 if reason == "SL_HIT" else 0.002, "pnl_usd": 500.0 if reason == "TP_HIT" else -800.0 if reason == "SL_HIT" else 200.0, "shadow_nav": 100500.0 if reason == "TP_HIT" else 99200.0 if reason == "SL_HIT" else 100200.0, "exit_reason": reason}, "RELIABLE_YELLOW", PRODUCTION_VERSION)
        cases.append(_notification_case(reason.lower(), exit_type, exit_title, exit_body))
    cases.append(_notification_case("data-error", "DATA_ERROR", "âš ï¸ SIGNAL DATA INCOMPLETE", "Observation Date: 2026-08-05\nNO TRADE\nReason: MISSING_REQUIRED_GEX_LEVELS\nStrategy Version: " + PRODUCTION_VERSION))
    cases.append(_notification_case("monthly-summary", "SHADOW_SUMMARY", "ðŸ“Š MONTHLY SIGNAL REPORT", "Month: 2026-07\nTrades: 2\nWins: 1\nLosses: 1\nCurrent NAV: $100,200.00\nForward trades accumulated / 50: 2 / 50\nStrategy Version: " + PRODUCTION_VERSION + "\n" + SHADOW_VERSION + " Yellow candidates: 3 (Strong 1 / Reliable 2)\n" + SHADOW_VERSION + " outcomes closed: 2"))
    cases.append({"name": "reversal-signal-without-qqq-quote", "notification_type": signal_notification(reversal, snapshot, PRODUCTION_VERSION, plan=TradePlan("signal", SignalClassification.REVERSAL_GREEN, date(2026, 8, 5), date(2026, 8, 6), reversal.actionable_at, Direction.LONG, "DIP_LIMIT", reference_price=20000, dip_price=19800), report_url=REPORT_URL)[0], "title": signal_notification(reversal, snapshot, PRODUCTION_VERSION, plan=TradePlan("signal", SignalClassification.REVERSAL_GREEN, date(2026, 8, 5), date(2026, 8, 6), reversal.actionable_at, Direction.LONG, "DIP_LIMIT", reference_price=20000, dip_price=19800), report_url=REPORT_URL)[1], "body": signal_notification(reversal, snapshot, PRODUCTION_VERSION, plan=TradePlan("signal", SignalClassification.REVERSAL_GREEN, date(2026, 8, 5), date(2026, 8, 6), reversal.actionable_at, Direction.LONG, "DIP_LIMIT", reference_price=20000, dip_price=19800), report_url=REPORT_URL)[2], "priority": "high", "url": REPORT_URL, "url_title": "Open SPX GEX HTML report", "invariant": "message remains actionable and says Manual; runtime obtains QQQ quote before opening"})
    return {"secrets": {"pushover_user_key": "<PUSHOVER_USER_KEY>", "pushover_app_token": "<PUSHOVER_APP_TOKEN>", "report_token": "<REPORT_TOKEN>"}, "cases": cases}


def _git_info(repo: Path, label: str) -> dict[str, Any]:
    def run(*args: str) -> str:
        command = ["git", "-c", f"safe.directory={repo}", "-C", str(repo), *args]
        try:
            return subprocess.check_output(command, text=True, stderr=subprocess.DEVNULL).strip()
        except (OSError, subprocess.CalledProcessError):
            return "UNAVAILABLE"

    status = run("status", "--short")
    return {"repository": label, "commit": run("rev-parse", "HEAD"), "dirty": bool(status), "changed_files": [line[3:] for line in status.splitlines() if len(line) >= 4]}


def build_fixture_data() -> dict[str, Any]:
    return {
        "classification_cases.json": {"schema_version": 1, "cases": _classification_cases()},
        "lifecycle_cases.json": {"schema_version": 1, "cases": _lifecycle_cases()},
        "report_cases.json": {"schema_version": 1, **_report_cases()},
        "notification_cases.json": {"schema_version": 1, **_notification_cases()},
        "calendar_cases.json": {"schema_version": 1, **_calendar_cases()},
    }


def _default_output_root() -> Path:
    web_root = Path(__file__).resolve().parents[3]
    return web_root.parent / "stocks_collecting" / "tests" / "strategy_runtime" / "fixtures" / "spx_legacy"


def _manifest(data: dict[str, Any], destination: Path) -> dict[str, Any]:
    web_root = Path(__file__).resolve().parents[3]
    # ...\\stocks_collecting\\tests\\strategy_runtime\\fixtures\\spx_legacy
    # -> parents[3] is the collecting repository root.
    collecting_root = destination.parents[3] if len(destination.parents) >= 4 else destination
    hashes = {
        name: hashlib.sha256(_stable_json(value).encode("utf-8")).hexdigest()
        for name, value in sorted(data.items())
    }
    return {
        "schema_version": 1,
        "exporter_version": EXPORTER_VERSION,
        "source_worktrees": [_git_info(web_root, "stocks_au_web"), _git_info(collecting_root, "stocks_collecting")],
        "production_strategy_version": PRODUCTION_VERSION,
        "shadow_strategy_version": SHADOW_VERSION,
        "baseline": {"command": "..\\venv\\Scripts\\python.exe -m unittest tests.test_spx_gex_strategy", "tests": 33, "result": "PASS", "skipped": 0, "runtime_seconds": 10.367},
        "fixture_generation_command": "..\\venv\\Scripts\\python.exe tests\\support\\export_spx_migration_fixtures.py",
        "generated_file_hashes": hashes,
        "generated_file_names": sorted([*hashes, "manifest.json"]),
        "data_policy": "Synthetic in-memory inputs only; no production secrets, live SQL Server data, IB data, or Pushover calls.",
        "absolute_paths_omitted": True,
    }


def export(destination: Path) -> None:
    data = build_fixture_data()
    destination.mkdir(parents=True, exist_ok=True)
    for name, value in sorted(data.items()):
        (destination / name).write_text(_stable_json(value), encoding="utf-8", newline="\n")
    manifest = _manifest(data, destination)
    (destination / "manifest.json").write_text(_stable_json(manifest), encoding="utf-8", newline="\n")


def _first_difference(expected: Any, actual: Any, path: str = "$-") -> str | None:
    if type(expected) is not type(actual):
        return f"{path}: expected type {type(expected).__name__}, got {type(actual).__name__}"
    if isinstance(expected, dict):
        for key in sorted(set(expected) | set(actual)):
            if key not in expected:
                return f"{path}.{key}: unexpected field"
            if key not in actual:
                return f"{path}.{key}: missing field"
            difference = _first_difference(expected[key], actual[key], f"{path}.{key}")
            if difference:
                return difference
        return None
    if isinstance(expected, list):
        if len(expected) != len(actual):
            return f"{path}: expected {len(expected)} items, got {len(actual)}"
        for index, (left, right) in enumerate(zip(expected, actual)):
            difference = _first_difference(left, right, f"{path}[{index}]")
            if difference:
                return difference
        return None
    return None if expected == actual else f"{path}: expected {expected!r}, got {actual!r}"


def check(destination: Path) -> int:
    expected = _json_value(build_fixture_data())
    for name, value in sorted(expected.items()):
        path = destination / name
        if not path.exists():
            print(f"MISSING {path}", file=sys.stderr)
            return 1
        actual = json.loads(path.read_text(encoding="utf-8"))
        difference = _first_difference(value, actual)
        if difference:
            print(f"MISMATCH {name}: {difference}", file=sys.stderr)
            return 1
    print(f"OK: {len(expected)} SPX migration fixture files match current legacy behavior")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="compare checked-in fixtures without writing")
    parser.add_argument("--output-root", type=Path, default=None, help="fixture directory override")
    args = parser.parse_args(argv)
    destination = (args.output_root or _default_output_root()).resolve()
    if args.check:
        return check(destination)
    export(destination)
    print(f"Wrote deterministic SPX migration fixtures to {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
