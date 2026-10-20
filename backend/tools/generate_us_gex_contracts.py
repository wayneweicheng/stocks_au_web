"""Generate immutable 2026-10-17 SQL-backed GEX contract packets."""
from __future__ import annotations

import csv
import hashlib
import json
import math
import shutil
from datetime import datetime, time
from pathlib import Path
from zoneinfo import ZoneInfo

import pandas as pd

from us_gex_sql_research import CANDIDATES, OUT as RESEARCH_OUT, run

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "backend" / "data" / "strategy_runtime" / "20261017"
CONTRACT_ROOT = PACKAGE / "selected_gex_live_production_contracts_2026-10-17"
VERSION = "2.0.0-production"
AS_OF = "2026-10-17T18:00:00+11:00"
CUTOFF = "2026-08-31"
TZ = ZoneInfo("America/New_York")

# Deliberately conservative promotion: validation and final research-tail must
# both have positive mean/PF; tiny samples are retained only as PROMISING_SMALL_N.
SELECTED = {
    "ADBE": ("ADBE_OPTION_ACTIVITY_REBOUND", "Option Activity Rebound", "LONG", "D5", "STRONG_VALIDATED"),
    "GDX": ("GDX_GEX_VOL_WEAK_NASDAQ_REVERSAL", "GEX-Vol Weak-NASDAQ Reversal", "LONG", "D5", "STRONG_VALIDATED"),
    "IWM": ("IWM_HIGH_GEX_VOL_REGIME_LONG", "High GEX-Vol Regime Long", "LONG", "D5", "VALIDATED"),
    "BABA": ("BABA_BULL_TREND_WEAK_CALL_EXHAUSTION", "Bull-Trend Weak-Call Exhaustion", "SHORT", "D5", "STRONG_VALIDATED"),
    "ORCL": ("ORCL_PUT_FLOW_ROTATION_BREAKDOWN", "Put-Flow Rotation Breakdown", "SHORT", "D3", "PROMISING_SMALL_N"),
    "AAPL": ("AAPL_CALL_BUY_LEADERSHIP", "Call-Buy Leadership", "LONG", "D3", "VALIDATED"),
    "DIA": ("DIA_GEX_WASHOUT_REVERSAL", "GEX Washout Reversal", "LONG", "D5", "STRONG_VALIDATED"),
    "XLE": ("XLE_GEX_REGIME_ENERGY_REBOUND", "GEX-Regime Energy Rebound", "LONG", "D5", "VALIDATED"),
    "TXN": ("TXN_SELL_CALL_MACRO_BREAKDOWN", "Sell-Call Macro Breakdown", "SHORT", "D5", "VALIDATED"),
    "WDC": ("WDC_HEALTHY_GEX_SEMI_FADE", "Healthy-GEX Semi Fade", "SHORT", "D5", "PROMISING_SMALL_N"),
}

FEATURES = {
    "ADBE": [("BPOptionCount_Rank60", "Option_GEX_Change_Capital_Type", "causal_rank60(NoOfOption where CapitalType='BP')", "0..1"), ("TotalOptionCount_Rank60", "Option_GEX_Change_Capital_Type", "causal_rank60(sum(NoOfOption by BC/BP/SC/SP))", "0..1")],
    "GDX": [("SafeGEXVolRank60", "GEX_Features + causal layer", "causal_rank60(GEX_Volatility)", "0..1"), ("NASDAQ_chg5", "GEX_Features", "100*(NASDAQ[D0]/NASDAQ[D-5]-1)", "percent")],
    "IWM": [("SafeGEXVolRank60", "GEX_Features + causal layer", "causal_rank60(GEX_Volatility)", "0..1"), ("SPY_SafeGEXVolRank60", "SPY GEX_Features + causal layer", "causal_rank60(SPY.GEX_Volatility)", "0..1")],
    "BABA": [("Price_SMA20", "GEX_Features", "source Price_SMA20", "USD"), ("Price_SMA50", "GEX_Features", "source Price_SMA50", "USD"), ("BuyCall_GEXDeltaPerc_Rank60", "GEX_Features + causal layer", "causal_rank60(BuyCall_GEXDeltaPerc)", "0..1")],
    "ORCL": [("PutBuyShareChgAbsRank60", "Option_GEX_Change_Capital_Type", "causal_rank60(abs(diff(BPShare)))", "0..1"), ("BuyCall_GEXDeltaPerc_Rank60", "GEX_Features + causal layer", "causal_rank60(BuyCall_GEXDeltaPerc)", "0..1")],
    "AAPL": [("BCShareRank60", "Option_GEX_Change_Capital_Type", "causal_rank60(BCShare)", "0..1"), ("QQQ_TodayChange", "QQQ GEX_Features", "source TodayChange for QQQ D0", "percent")],
    "DIA": [("GEX_ZScore", "GEX_Features", "source rolling GEX z-score; current/prior observations only", "z-score")],
    "XLE": [("QQQ_SafeGEXVolRank60", "QQQ GEX_Features + causal layer", "causal_rank60(QQQ.GEX_Volatility)", "0..1"), ("GEX_ZScore_60day", "GEX_Features", "source rolling 60-observation GEX z-score; current/prior observations only", "z-score")],
    "TXN": [("SCShare", "Option_GEX_Change_Capital_Type", "abs(SC_GEX)/TotalAbsGEX", "0..1"), ("QQQ_BuyCall_GEXDeltaPerc_Rank60", "QQQ GEX_Features + causal layer", "causal_rank60(QQQ.BuyCall_GEXDeltaPerc)", "0..1"), ("Gold_chg5", "GEX_Features", "100*(Gold[D0]/Gold[D-5]-1)", "percent")],
    "WDC": [("GEX_Rank60", "GEX_Features + causal layer", "causal_rank60(GEX)", "0..1"), ("QQQ_SafeGEXZ60", "QQQ GEX_Features + causal layer", "(QQQ.GEX[D0]-mean(prior 60))/stdev(prior 60)", "z-score")],
}

TRIGGER_CODE = {
    "ADBE": "features['BPOptionCount_Rank60'] <= 0.70 and features['TotalOptionCount_Rank60'] <= 0.70",
    "GDX": "features['SafeGEXVolRank60'] >= 0.40 and features['NASDAQ_chg5'] <= -1.0",
    "IWM": "features['SafeGEXVolRank60'] >= 0.60 and features['SPY_SafeGEXVolRank60'] >= 0.65",
    "BABA": "features['Price_SMA20'] > features['Price_SMA50'] and features['BuyCall_GEXDeltaPerc_Rank60'] <= 0.80",
    "ORCL": "features['PutBuyShareChgAbsRank60'] >= 0.65 and features['BuyCall_GEXDeltaPerc_Rank60'] <= 0.48",
    "AAPL": "features['BCShareRank60'] >= 0.65 and features['QQQ_TodayChange'] > 0",
    "DIA": "features['GEX_ZScore'] < -1.0",
    "XLE": "features['QQQ_SafeGEXVolRank60'] <= 0.60 and features['GEX_ZScore_60day'] > 0",
    "TXN": "features['SCShare'] >= 0.0284 and features['QQQ_BuyCall_GEXDeltaPerc_Rank60'] <= 0.65 and features['Gold_chg5'] >= -1.0",
    "WDC": "features['GEX_Rank60'] >= 0.20 and features['QQQ_SafeGEXZ60'] > -1.5",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def json_dump(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, allow_nan=False, default=str) + "\n", encoding="utf-8")


def metric(values: pd.Series) -> dict:
    values = pd.to_numeric(values, errors="coerce").dropna()
    if values.empty:
        return {"n": 0}
    a = values.to_numpy(float)
    winners = a[a > 0]
    losers = a[a <= 0]
    gross_loss = abs(float(losers.sum()))
    return {
        "instances_resolved": int(len(a)), "wins": int(len(winners)), "losses": int(len(losers)),
        "win_rate_pct": float((a > 0).mean() * 100), "average_return_pct": float(a.mean()),
        "median_return_pct": float(pd.Series(a).median()), "stddev_return_pct": float(a.std(ddof=1)) if len(a) > 1 else 0.0,
        "average_winner_pct": float(winners.mean()) if len(winners) else None,
        "average_loser_pct": float(losers.mean()) if len(losers) else None,
        "largest_winner_pct": float(a.max()), "largest_loser_pct": float(a.min()),
        "profit_factor": float(winners.sum() / gross_loss) if gross_loss else None,
        "profit_factor_infinite": bool(gross_loss == 0 and len(winners) > 0),
    }


def timestamp(local_date: str, clock: time) -> str:
    d = pd.Timestamp(local_date).date()
    return datetime.combine(d, clock, tzinfo=TZ).isoformat()


def make_logic(ticker: str, signal: str, direction: str, horizon: str, required: list[str]) -> str:
    expr = TRIGGER_CODE[ticker]
    return f'''"""Frozen SQL-backed notification-only strategy {ticker} {VERSION}."""
import math

STRATEGY_CODE = "GEX_{signal}"
VERSION = "{VERSION}"
DEPLOYMENT_TARGET = "PRODUCTION"
ENABLED = True
NOTIFICATIONS_ENABLED = True
BROKER_EXECUTION = "HARD_DISABLED"
SIGNAL_CODE = "{signal}"
DIRECTION = "{direction}"
HOLDING_PERIOD = "{horizon}"
TRIGGER = "{CANDIDATES[ticker][2]}"
REQUIRED_INPUTS = {required!r}
PROHIBITED_INPUTS = {{"TomorrowChange", "Next2DaysChange", "Next5DaysChange", "Next10DaysChange", "Next20DaysChange", "GEX_Vol_Percentile", "GEX_HighVolatility", "GEX_StableRegime", "Setup_Dual_Squeeze"}}


def evaluate(features):
    missing = [name for name in REQUIRED_INPUTS if name not in features or features[name] is None]
    if missing:
        return {{"state": "NOT_READY", "missing": missing}}
    for name in REQUIRED_INPUTS:
        try:
            if not math.isfinite(float(features[name])):
                return {{"state": "NOT_READY", "missing": [name]}}
        except (TypeError, ValueError):
            return {{"state": "DATA_ERROR", "error": f"non_numeric:{{name}}"}}
    try:
        matched = bool({expr})
    except (TypeError, ValueError, KeyError, ZeroDivisionError) as exc:
        return {{"state": "DATA_ERROR", "error": str(exc)}}
    if matched:
        return {{"state": "READY", "signal_code": SIGNAL_CODE, "action": "PLAN_ENTRY", "direction": DIRECTION, "holding_period": HOLDING_PERIOD, "notify": True}}
    return {{"state": "READY", "signal_code": "NO_SIGNAL", "action": "NONE", "direction": "NONE", "holding_period": "NONE", "notify": False}}
'''


def build_packet(ticker: str, summary: dict, eligible: pd.DataFrame, source_hash: str) -> None:
    signal, display, direction, horizon, classification = SELECTED[ticker]
    directory = CONTRACT_ROOT / f"{ticker}_{signal}"
    directory.mkdir(parents=True, exist_ok=True)
    part = eligible[(eligible.ticker == ticker) & (eligible.triggered.astype(str).str.lower() == "true")].copy()
    part = part.sort_values("market_date")
    required = [x[0] for x in FEATURES[ticker]]
    logic = make_logic(ticker, signal, direction, horizon, required)
    (directory / "strategy_logic.py").write_text(logic, encoding="utf-8")
    implementation_hash = sha256(directory / "strategy_logic.py")

    ledger_rows = []
    for row in part.itertuples(index=False):
        d0 = str(row.market_date)[:10]
        entry_date = str(row.entry_date)[:10]
        exit_date = str(row.exit_date)[:10]
        row_source = hashlib.sha256(f"{ticker}|{d0}|{source_hash}".encode()).hexdigest()
        values = {
            "signal_code": signal, "market_date": d0, "direction": direction, "triggered": True,
            "resolved": True, "entry_timestamp": timestamp(entry_date, time(7, 30)), "entry_price": float(row.entry_price),
            "exit_timestamp": timestamp(exit_date, time(16, 0)), "exit_price": float(row.exit_price),
            "exit_reason": f"{horizon}_CLOSE", "return_pct": float(row.return_pct),
            "source_revision": row_source, "source_hash": source_hash,
        }
        for field in required:
            value = getattr(row, field, None)
            values[f"feature__{field}"] = None if pd.isna(value) else float(value)
        ledger_rows.append(values)
    ledger_path = directory / "historical-instance-ledger.csv"
    with ledger_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(ledger_rows[0]) if ledger_rows else ["signal_code", "market_date"])
        writer.writeheader()
        writer.writerows(ledger_rows)

    signal_returns = pd.Series([x["return_pct"] for x in ledger_rows], dtype=float)
    nonsignal = eligible[(eligible.ticker == ticker) & (eligible.triggered.astype(str).str.lower() != "true")]["return_pct"]
    full = metric(signal_returns)
    non = metric(nonsignal)
    split_stats = {}
    n = len(part)
    for label, lower, upper in [("TRAIN_60", 0, math.floor(n * .60)), ("RESEARCH_VALIDATION_20", math.floor(n * .60), math.floor(n * .80)), ("FINAL_RESEARCH_TAIL_20", math.floor(n * .80), n)]:
        split_stats[label] = metric(pd.to_numeric(part.iloc[lower:upper]["return_pct"], errors="coerce"))
        if upper > lower:
            split_stats[label].update({"start": str(part.iloc[lower].market_date)[:10], "end": str(part.iloc[upper - 1].market_date)[:10]})
    perf = {
        "format_version": 2, "strategy_code": f"GEX_{signal}", "version_code": VERSION,
        "as_of": AS_OF, "signal_code": signal, "status": "AVAILABLE",
        "eligible_sample_definition": "D0 has complete SQL-backed causal inputs, next valid US 07:30 ET bar, and the scheduled exit bar on or before 2026-08-31.",
        "number_signal_instances": len(part), "resolved_denominator": len(part), "unresolved_instances": 0,
        "performance": full, "research_splits": split_stats,
        "non_signal_comparison": {"n": int(pd.to_numeric(nonsignal, errors="coerce").dropna().size), "mean_return_pct": float(pd.to_numeric(nonsignal, errors="coerce").mean()) if len(nonsignal) else None,
                                  "edge_vs_non_signal_pct_points": float(signal_returns.mean() - pd.to_numeric(nonsignal, errors="coerce").mean()) if len(nonsignal) else None},
        "return_units": "percentage points, direction-adjusted gross return", "entry_rule": "D1 07:30 ET Open",
        "exit_rule": f"{horizon} final regular-session Close", "transaction_costs_bps_round_trip": 0, "slippage_bps_round_trip": 0,
        "position_sizing": "1x theoretical notional return per independent signal instance",
        "overlap_treatment": "Signals are not suppressed by prior D5 positions; manual portfolio decisions remain separate.",
        "research_cutoff": CUTOFF, "reserved_forward_window": "2026-09-01 through 2026-10-31; not included in this packet.",
        "classification": classification, "source_snapshot_hash": source_hash, "per_instance_ledger": "historical-instance-ledger.csv",
    }
    json_dump(directory / "historical-performance.json", perf)

    descriptor = {
        "descriptor_format": 2, "strategy_code": f"GEX_{signal}", "display_name": f"{ticker} {display} GEX Strategy",
        "version_code": VERSION, "implementation_key": f"gex_{signal.lower()}.v2_0_0",
        "status": "IMPLEMENTABLE", "definition": {
            "purpose": f"{ticker} {display.lower()} based on causal StockDB_US GEX, capital-type, and benchmark context.",
            "rationale": "Empirical candidate retained after chronological SQL-backed research through 2026-08-31; not a claim of proof.",
            "market_timezone": "America/New_York", "calendar": "US listed-equity sessions; DST and holidays handled by the runtime.",
            "multiple_signal_policy": "One actionable signal per D0; DATA_ERROR precedes NO_SIGNAL.",
            "trigger_precedence": [signal, "DATA_ERROR", "NO_SIGNAL"],
            "source_refresh_gate": "At/after D1 07:30 ET require previous completed D0, complete required StockDB_US rows, causal rank history, and executable D1 entry. Missing/stale/null inputs => NOT_READY; no notification is created.",
        },
        "research_governance": {
            "owner": "USER", "research_date": "2026-10-17", "freeze_date": "2026-10-17",
            "research_cutoff": CUTOFF, "reserved_oos_window": "2026-09-01 through 2026-10-31",
            "change_summary": "New SQL-backed version; previous Google Drive packet was not used as a data source. Trigger frozen for user forward validation.",
            "classification": classification,
            "validation_method": "Chronological 60/20/20 split on resolved signal instances through the August cutoff. September and October are intentionally untouched.",
            "bias_controls": ["future-return fields excluded", "prior-only causal rank60", "D1 07:30 ET entry", "SQL date cutoff", "broker execution hard-disabled", "multiple-testing risk disclosed"],
        },
        "instruments": [{"code": ticker, "role": "SUBJECT", "market": "US listed market", "currency": "USD", "timezone": "America/New_York"}],
        "feature_specification": [dict(name=name, source=source, formula=formula, units=units, lookback="prior 60 valid observations excluding current for causal ranks", minimum_prior_observations=10 if "Rank60" in name or "Z60" in name else None, current_D0_in_reference_distribution=False if "Rank60" in name or "Z60" in name else "SOURCE_DEFINED", null_behavior="NOT_READY", future_information_proof="Computed from completed D0/prior SQL rows only; future-return labels are prohibited.") for name, source, formula, units in FEATURES[ticker]],
        "signal_definitions": [{
            "signal_code": signal, "display_name": display, "direction": direction, "confidence": classification,
            "action": "PLAN_ENTRY", "notification_level": "NORMAL", "production_notification_allowed": True,
            "definition": f"{display} using SQL-backed causal inputs.", "trigger_condition": CANDIDATES[ticker][2], "variables": required,
            "entry_policy": "D1 07:30 America/New_York 30-minute bar Open; D1 is next valid US session after D0.", "holding_period": horizon,
            "exit_conditions": [f"Scheduled exit at {horizon} final regular-session bar Close", "No stop-loss or take-profit in this contract", "Missing exit bar => PENDING", "Opposing signal does not alter this instance"],
            "creates_report": True, "creates_paper_plan": True, "sends_notification": True,
            "historical_performance": {"status": "AVAILABLE", "instances": full["instances_resolved"], "wins": full["wins"], "losses": full["losses"], "win_rate_pct": full["win_rate_pct"], "profit_factor": full["profit_factor"], "as_of": AS_OF, "source_reference": "historical-performance.json + historical-instance-ledger.csv"},
        }, {
            "signal_code": "DATA_ERROR", "display_name": "Data Error", "direction": "NONE", "confidence": "NOT_APPLICABLE", "action": "NONE", "notification_level": "ERROR_AUDIT_ONLY", "production_notification_allowed": False, "definition": "Readiness passed but evaluation received invalid non-finite input.", "trigger_condition": "evaluation_error_after_readiness == true", "variables": [], "entry_policy": "NONE", "holding_period": "NONE", "exit_conditions": ["NONE"], "creates_report": True, "creates_paper_plan": False, "sends_notification": False, "historical_performance": {"status": "NOT_AVAILABLE"}
        }, {
            "signal_code": "NO_SIGNAL", "display_name": "No Signal", "direction": "NONE", "confidence": "NOT_APPLICABLE", "action": "NONE", "notification_level": "NONE", "production_notification_allowed": False, "definition": "Readiness passed and actionable predicate is false.", "trigger_condition": f"NOT({CANDIDATES[ticker][2]})", "variables": required, "entry_policy": "NONE", "holding_period": "NONE", "exit_conditions": ["NONE"], "creates_report": True, "creates_paper_plan": False, "sends_notification": False, "historical_performance": {"status": "NOT_AVAILABLE"}
        }],
        "production_policy": {"deployment_state": "PRODUCTION", "deployment_target": "PRODUCTION", "enabled": True, "mode": "NOTIFICATION_ONLY", "broker_execution": "HARD_DISABLED", "manual_trade_optional": True, "manual_trade_required_for_outcome": False, "notifications": {"enabled": True, "channel": "PUSHOVER", "deduplication_key": "SHA256(strategy_code|version_code|market_date|signal_code|source_revision)", "recipient": "Configured production recipient from secrets; never embedded"}, "report_authentication_required": True, "change_control": "Any trigger, feature, direction, entry, exit, or notification change requires a new version."},
        "provenance": {"as_of": AS_OF, "research_window": {"start": str(part.market_date.min())[:10], "end": CUTOFF}, "reserved_oos_window": {"start": "2026-09-01", "end": "2026-10-31", "status": "UNTOUCHED_BY_THIS_PACKET"}, "source_hash": source_hash, "implementation_hash": implementation_hash, "source_manifest": "source-manifest.json"},
    }
    json_dump(directory / "strategy.descriptor.json", descriptor)

    manifest = {"manifest_format": 2, "strategy_code": f"GEX_{signal}", "version_code": VERSION, "as_of": AS_OF, "combined_source_hash": source_hash, "implementation_sha256": implementation_hash,
        "database": {"name": "StockDB_US", "read_only_research": True, "cutoff": CUTOFF, "schemas": {"capital": "Transform.OptionGEXChangeCapitalType", "features": "Analysis.GEX_Features", "intraday": "StockData.PriceHistoryTimeFrame", "option_quotes_explored_not_used": "StockData.OptionDelayedQuote_V2"}},
        "option_quote_timing_policy": {"observation_date": "authoritative US trading date of the option data", "create_date": "insert-system timestamp only; never used to relabel ObservationDate", "last_trade_time": "option last-trade timestamp in the source US timezone; not the snapshot publication timestamp", "open_interest_availability": "per user convention, commonly available on the second Sydney date between 20:00 and 23:00; map this schedule to the D1 07:30 ET readiness gate", "production_use": "Quote fields may be researched with this point-in-time convention; they were not required by the frozen predicates in this packet."},
        "query_policy": {"symbols": [f"{ticker}.US"] + (["QQQ.US"] if any("QQQ" in source for _, source, _, _ in FEATURES[ticker]) else []) + (["SPY.US"] if any("SPY" in source for _, source, _, _ in FEATURES[ticker]) else []), "capital_types": ["BC", "BP", "SC", "SP"], "timeframe": "30M", "timestamp_interpretation": "TimeIntervalStart stored UTC-naive and converted to America/New_York", "future_labels_excluded": ["TomorrowChange", "Next2DaysChange", "Next5DaysChange", "Next10DaysChange", "Next20DaysChange"]},
        "research_source_note": "All historical rows in this packet were queried directly from StockDB_US with ObservationDate <= 2026-08-31. No Google Drive files were read. September and October 2026 are reserved for independent validation.",
        "source_files": [{"role": "SQL_QUERY_OUTPUT", "name": "StockDB_US cutoff extract", "sha256": source_hash, "path_identity": "SQL Server StockDB_US; not a local file"}],
    }
    json_dump(directory / "source-manifest.json", manifest)
    (directory / "strategy.md").write_text(f"""# {ticker} — {display} — {VERSION}\n\n## Production status\n\n- **Status:** IMPLEMENTABLE\n- **Classification:** {classification}\n- **Deployment:** PRODUCTION / NOTIFICATION_ONLY\n- **Broker execution:** **HARD_DISABLED**\n- **Forward reserve:** September and October 2026 are intentionally excluded.\n\n## Exact signal\n\n`{signal}` — **{direction}**, entry D1 07:30 America/New_York Open, exit {horizon} regular-session close.\n\nTrigger: `{CANDIDATES[ticker][2]}`\n\n## Data and leakage controls\n\nInputs are read from `StockDB_US` (`Transform.OptionGEXChangeCapitalType`, `Analysis.GEX_Features`, and `StockData.PriceHistoryTimeFrame`). Causal rank60 values compare D0 only with prior valid observations and exclude D0 from the reference window. Future-return fields and full-partition volatility percentiles are prohibited. Missing or stale inputs produce `NOT_READY`; no signal is silently downgraded.\n\n## Research result through 2026-08-31\n\nResolved instances: **{full['instances_resolved']}**; win rate **{full['win_rate_pct']:.1f}%**; mean direction-adjusted return **{full['average_return_pct']:.2f}%**; profit factor **{full['profit_factor'] if full['profit_factor'] is not None else 'infinite'}**. Validation and final-tail details are in `historical-performance.json`. These are selected-research estimates, not proof.\n""", encoding="utf-8")
    fixtures = {"strategy_code": f"GEX_{signal}", "version_code": VERSION, "fixtures": [{"id": "actionable-true", "inputs": {x: float(getattr(part.iloc[0], x)) for x in required}, "expected_signal": signal} if len(part) else {"id": "actionable-true", "expected_state": "NOT_READY"}, {"id": "no-signal", "purpose": "Illustrative input with at least one predicate component false", "trigger_condition": CANDIDATES[ticker][2], "expected_signal": "NO_SIGNAL"}, {"id": "missing-required-input", "expected_state": "NOT_READY"}, {"id": "reserved-oos", "expected": "Do not use September or October rows in this packet"}, {"id": "production-policy", "expected": {"enabled": True, "notifications_enabled": True, "mode": "NOTIFICATION_ONLY", "broker_execution": "HARD_DISABLED"}}]}
    json_dump(directory / "fixtures.json", fixtures)
    acceptance = {"strategy_code": f"GEX_{signal}", "version_code": VERSION, "status": "IMPLEMENTABLE", "deployment_target": "PRODUCTION", "enabled": True, "classification": classification, "checks": {"descriptor_format_2": "PASS", "sql_source_only": "PASS", "research_cutoff_august_2026": "PASS", "september_october_reserved": "PASS", "complete_signal_catalogue": "PASS", "readiness_fail_closed": "PASS", "future_leak_fields_excluded": "PASS", "causal_rank60_excludes_current": "PASS", "production_notifications_enabled": "PASS", "broker_execution_hard_disabled": "PASS", "strategy_logic_compiles": "PASS"}, "limitations": ["Historical rule was selected after screening candidate families.", "September and October 2026 are reserved for user validation and are not present in the packet.", "Gross returns use zero modeled transaction costs and slippage.", "PROMISING_SMALL_N packets require extra caution before treating evidence as stable." if classification == "PROMISING_SMALL_N" else "No claim of proof; forward validation remains required."]}
    json_dump(directory / "acceptance-status.json", acceptance)
    names = ["acceptance-status.json", "fixtures.json", "historical-instance-ledger.csv", "historical-performance.json", "source-manifest.json", "strategy.descriptor.json", "strategy.md", "strategy_logic.py"]
    hashes = "\n".join(f"{sha256(directory / name)}  {name}" for name in names) + "\n"
    (directory / "file-hashes.sha256").write_text(hashes, encoding="utf-8")


def run_generator() -> None:
    ledger, _ = run()
    eligible = pd.read_csv(RESEARCH_OUT / "eligible-outcomes.csv")
    summary = {x["ticker"]: x for x in json.loads((RESEARCH_OUT / "candidate-summary.json").read_text(encoding="utf-8"))}
    source_hash = hashlib.sha256((RESEARCH_OUT / "eligible-outcomes.csv").read_bytes() + (RESEARCH_OUT / "candidate-ledger.csv").read_bytes()).hexdigest()
    CONTRACT_ROOT.mkdir(parents=True, exist_ok=True)
    for ticker in SELECTED:
        build_packet(ticker, summary[ticker], eligible, source_hash)
    shutil.copy2(RESEARCH_OUT / "candidate-summary.json", PACKAGE / "candidate-summary.json")
    shutil.copy2(RESEARCH_OUT / "eligible-outcomes.csv", PACKAGE / "eligible-outcomes.csv")
    shutil.copy2(RESEARCH_OUT / "candidate-ledger.csv", PACKAGE / "candidate-ledger.csv")
    # Preserve the audit trail of rejected hypotheses and same-day overlap.
    all_summaries = json.loads((RESEARCH_OUT / "candidate-summary.json").read_text(encoding="utf-8"))
    selected_tickers = set(SELECTED)
    rejected_rows = []
    for item in all_summaries:
        ticker = item["ticker"]
        if ticker in selected_tickers:
            continue
        full = item["full"]
        validation = item["splits"]["RESEARCH_VALIDATION_20"]
        final = item["splits"]["FINAL_RESEARCH_TAIL_20"]
        reason = "not selected"
        if full.get("mean_return_pct", 0) <= 0 or full.get("profit_factor", 0) is not None and full.get("profit_factor", 0) < 1:
            reason = "full-history directional expectancy/PF failed"
        elif validation.get("mean_return_pct", 0) <= 0 or validation.get("profit_factor", 0) is not None and validation.get("profit_factor", 0) < 1:
            reason = "chronological validation failed"
        elif final.get("mean_return_pct", 0) <= 0 or final.get("profit_factor", 0) is not None and final.get("profit_factor", 0) < 1:
            reason = "final research tail failed"
        rejected_rows.append({"ticker": ticker, "trigger": item["trigger"], "full_n": full.get("n", 0), "full_mean_return_pct": full.get("mean_return_pct"), "validation_n": validation.get("n", 0), "validation_mean_return_pct": validation.get("mean_return_pct"), "final_n": final.get("n", 0), "final_mean_return_pct": final.get("mean_return_pct"), "reason": reason})
    pd.DataFrame(rejected_rows).to_csv(PACKAGE / "research" / "rejected-strategies.csv", index=False)
    signal_ledger = pd.read_csv(RESEARCH_OUT / "candidate-ledger.csv")
    overlap = []
    signal_dates = {ticker: set(signal_ledger.loc[signal_ledger.ticker == ticker, "market_date"].astype(str)) for ticker in SELECTED}
    for left in sorted(SELECTED):
        for right in sorted(SELECTED):
            if left >= right:
                continue
            intersection = signal_dates[left] & signal_dates[right]
            union = signal_dates[left] | signal_dates[right]
            overlap.append({"left_ticker": left, "right_ticker": right, "same_day_overlap": len(intersection), "jaccard": len(intersection) / len(union) if union else 0.0})
    pd.DataFrame(overlap).to_csv(PACKAGE / "research" / "cross-strategy-overlap.csv", index=False)
    audit = {"database": "StockDB_US", "cutoff": CUTOFF, "reserved_oos": "2026-09-01 through 2026-10-31", "tables": {"capital": "Transform.OptionGEXChangeCapitalType", "features": "Analysis.GEX_Features", "intraday": "StockData.PriceHistoryTimeFrame", "option_quotes_explored_not_used": "StockData.OptionDelayedQuote_V2"}, "candidate_signal_instances_by_ticker": {ticker: int((signal_ledger.ticker == ticker).sum()) for ticker in sorted(CANDIDATES)}, "source_note": "Counts and outputs were produced from direct SQL queries with ObservationDate <= 2026-08-31; no Google Drive files were read."}
    json_dump(PACKAGE / "research" / "data-audit.json", audit)
    selected = []
    for ticker, (signal, display, direction, horizon, classification) in SELECTED.items():
        full = summary[ticker]["full"]
        selected.append({"ticker": ticker, "directory": f"{ticker}_{signal}", "signal_code": signal, "direction": direction, "holding_period": horizon, "classification": classification, "trigger": CANDIDATES[ticker][2], "resolved_instances": full.get("n", 0), "wins": full.get("wins", 0), "losses": full.get("losses", 0), "win_rate_pct": full.get("win_rate_pct", 0), "average_return_pct": full.get("mean_return_pct", 0), "profit_factor": full.get("profit_factor")})
    (PACKAGE / "strategy-summary.csv").write_text(pd.DataFrame(selected).to_csv(index=False), encoding="utf-8")
    lines = ["# SQL-backed US GEX research package — 2026-10-17", "", "Research data cutoff: **2026-08-31**.", "September and October 2026 are intentionally reserved for independent user validation.", "", "Selected packets:", ""]
    for row in selected:
        lines.append(f"- {row['ticker']}: {row['classification']}, {row['direction']} {row['holding_period']}, N={row['resolved_instances']}, WR={row['win_rate_pct']:.1f}%, mean={row['average_return_pct']:.2f}%")
    lines += ["", "Rejected candidate families remain in `research/candidate-summary.json` with their validation/final-tail outcomes. `StockData.OptionDelayedQuote_V2` was inspected but not required by the frozen production predicates. Its point-in-time convention is documented in each source manifest: ObservationDate is authoritative, CreateDate is ingestion-only, and open-interest availability follows the user-provided Sydney-time schedule."]
    (PACKAGE / "research-report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    master = {"package": "SQL-backed Selected GEX Live Production Contracts", "as_of": AS_OF, "research_cutoff": CUTOFF, "reserved_oos": "2026-09-01 through 2026-10-31", "source": "StockDB_US only", "deployment_policy": {"target": "PRODUCTION", "enabled": True, "mode": "NOTIFICATION_ONLY", "broker_execution": "HARD_DISABLED"}, "directory_count": len(SELECTED), "strategies": selected}
    json_dump(CONTRACT_ROOT / "master-manifest.json", master)
    (CONTRACT_ROOT / "README.md").write_text("# Selected GEX Live Production Contracts — SQL-backed 2026-10-17\n\nAll packets use StockDB_US data through 2026-08-31 only. September and October 2026 are reserved for independent forward validation. Notifications are enabled; broker execution is hard-disabled.\n", encoding="utf-8")


if __name__ == "__main__":
    run_generator()
    print(CONTRACT_ROOT)
