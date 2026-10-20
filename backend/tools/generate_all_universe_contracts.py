"""Create usable descriptor packets for the top August-2026 candidate per ticker.

The input is the completed all-August-universe research extract. This generator
never queries September or October 2026 and does not change the existing
20261017 packet set.
"""
from __future__ import annotations

import ast
import csv
import hashlib
import json
import re
import shutil
from datetime import datetime, time
from pathlib import Path
from zoneinfo import ZoneInfo

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
RESEARCH = ROOT / "backend" / "data" / "strategy_runtime" / "20261017" / "research_all_august_universe"
PACKAGE = ROOT / "backend" / "data" / "strategy_runtime" / "20261018"
CONTRACT_ROOT = PACKAGE / "selected_gex_live_production_contracts_2026-10-18"
VERSION = "1.0.0-production"
AS_OF = "2026-10-18T18:00:00+11:00"
CUTOFF = "2026-08-31"
TZ = ZoneInfo("America/New_York")

IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
EXCLUDED_NAMES = {"AND", "OR", "NOT", "True", "False", "abs"}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalized_text_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_text(encoding="utf-8").encode("utf-8")).hexdigest()


def dump(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, allow_nan=False, default=str) + "\n", encoding="utf-8")


def metric(values: pd.Series) -> dict:
    a = pd.to_numeric(values, errors="coerce").dropna().to_numpy(float)
    if len(a) == 0:
        return {"n": 0, "mean": None, "wr": None, "pf": None}
    wins, losses = a[a > 0], a[a <= 0]
    gross_loss = abs(float(losses.sum()))
    return {
        "n": int(len(a)),
        "mean": float(a.mean()),
        "wr": float((a > 0).mean() * 100),
        "pf": float(wins.sum() / gross_loss) if gross_loss else None,
    }


def identifiers(trigger: str) -> list[str]:
    return [name for name in IDENTIFIER.findall(trigger) if name not in EXCLUDED_NAMES]


def eval_trigger(trigger: str, values: dict[str, object]) -> bool:
    normalized = re.sub(r"\bAND\b", "and", trigger, flags=re.I)
    normalized = re.sub(r"\bOR\b", "or", normalized, flags=re.I)
    normalized = re.sub(r"\bNOT\b", "not", normalized, flags=re.I)
    tree = ast.parse(normalized, mode="eval")

    def visit(node: ast.AST):
        if isinstance(node, ast.Expression):
            return visit(node.body)
        if isinstance(node, ast.BoolOp):
            results = [bool(visit(item)) for item in node.values]
            return all(results) if isinstance(node.op, ast.And) else any(results)
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
            return not bool(visit(node.operand))
        if isinstance(node, ast.Compare):
            left = visit(node.left)
            for op, right_node in zip(node.ops, node.comparators):
                right = visit(right_node)
                if isinstance(op, ast.Lt): result = left < right
                elif isinstance(op, ast.LtE): result = left <= right
                elif isinstance(op, ast.Gt): result = left > right
                elif isinstance(op, ast.GtE): result = left >= right
                elif isinstance(op, ast.Eq): result = left == right
                elif isinstance(op, ast.NotEq): result = left != right
                else: raise ValueError(f"unsupported operator: {type(op).__name__}")
                if not result: return False
                left = right
            return True
        if isinstance(node, ast.Name):
            if node.id in {"True", "False"}: return node.id == "True"
            value = values.get(node.id)
            if value is None: raise ValueError(f"missing trigger input: {node.id}")
            return float(value) if isinstance(value, (int, float)) else value
        if isinstance(node, ast.Constant) and isinstance(node.value, (int, float, bool)):
            return node.value
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.UAdd)):
            value = visit(node.operand)
            return -value if isinstance(node.op, ast.USub) else value
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "abs":
            return abs(visit(node.args[0]))
        raise ValueError(f"unsupported trigger node: {type(node).__name__}")

    return bool(visit(tree))


def timestamp(local_date: str, clock: time) -> str:
    return datetime.combine(pd.Timestamp(local_date).date(), clock, tzinfo=TZ).isoformat()


def feature_spec(name: str) -> dict:
    rank_names = {"GEX_Rank60", "SafeGEXVolRank60", "BCShareRank60", "BPShare_Rank60", "BPOptionCount_Rank60", "SCShareRank60", "SPShare_Rank60", "SCShareChgRank60", "SPShareChgRank60", "PutBuyShareChgAbsRank60", "BullShareChgAbsRank60", "ConcentrationHHIRank60"}
    cap_names = {"BCShareRank60", "BPShare_Rank60", "BPOptionCount_Rank60", "SCShareRank60", "SPShare_Rank60", "SCShareChgRank60", "SPShareChgRank60", "PutBuyShareChgAbsRank60", "BullShareChgAbsRank60", "ConcentrationHHIRank60"}
    if name in cap_names:
        formula = {
            "BCShareRank60": "causal_rank60(BCShare)", "BPShare_Rank60": "causal_rank60(BPShare)",
            "BPOptionCount_Rank60": "causal_rank60(NoOfOption where CapitalType='BP')",
            "SCShareRank60": "causal_rank60(SCShare)", "SPShare_Rank60": "causal_rank60(SPShare)",
            "SCShareChgRank60": "causal_rank60(change(SCShare))", "SPShareChgRank60": "causal_rank60(change(SPShare))",
            "PutBuyShareChgAbsRank60": "causal_rank60(abs(change(PutBuyShare)))",
            "BullShareChgAbsRank60": "causal_rank60(abs(change(BullShare)))",
            "ConcentrationHHIRank60": "causal_rank60(sum(capital_share^2))",
        }[name]
        source = "Transform.OptionGEXChangeCapitalType + causal layer"
    elif name in {"GEX_Rank60", "SafeGEXVolRank60"}:
        formula = "causal_rank60(GEX)" if name == "GEX_Rank60" else "causal_rank60(GEX_Volatility)"
        source = "Analysis.GEX_Features + causal layer"
    elif name == "PriceDistSMA50Pct":
        formula, source = "100*(Close/Price_SMA50-1)", "Analysis.GEX_Features"
    else:
        formula, source = f"source {name}", "Analysis.GEX_Features"
    return {
        "name": name, "source": source, "formula": formula,
        "units": "0..1" if name in rank_names else "source units",
        "lookback": "prior 60 valid observations excluding current for causal ranks" if name in rank_names else "source-defined",
        "minimum_prior_observations": 60 if name in rank_names else None,
        "current_D0_in_reference_distribution": False if name in rank_names else "SOURCE_DEFINED",
        "null_behavior": "NOT_READY",
        "future_information_proof": "Computed from completed D0/prior SQL rows only; future-return labels are prohibited.",
    }


def make_logic(strategy_code: str, signal_code: str, trigger: str, direction: str, horizon: str, required: list[str]) -> str:
    return f'''"""Declarative candidate packet; runtime evaluates strategy.descriptor.json."""
STRATEGY_CODE = "{strategy_code}"
VERSION = "{VERSION}"
SIGNAL_CODE = "{signal_code}"
DIRECTION = "{direction}"
HOLDING_PERIOD = "{horizon}"
TRIGGER = {trigger!r}
REQUIRED_INPUTS = {required!r}
DEPLOYMENT_TARGET = "PRODUCTION"
NOTIFICATIONS_ENABLED = True
BROKER_EXECUTION = "HARD_DISABLED"
'''


def split_metrics(part: pd.DataFrame, direction: str) -> dict:
    values = pd.to_numeric(part["return_pct"], errors="coerce") * (1 if direction == "LONG" else -1)
    n = len(part)
    output = {}
    for label, lo, hi in (("TRAIN_60", 0, int(n * .6)), ("RESEARCH_VALIDATION_20", int(n * .6), int(n * .8)), ("FINAL_RESEARCH_TAIL_20", int(n * .8), n)):
        subset = part.iloc[lo:hi]
        output[label] = metric(values.iloc[lo:hi])
        if len(subset): output[label].update({"start": str(subset.market_date.iloc[0])[:10], "end": str(subset.market_date.iloc[-1])[:10]})
    return output


def build_packet(row: pd.Series, outcomes: pd.DataFrame, source_hash: str) -> dict:
    ticker = str(row.ticker).replace(".US", "").upper()
    strategy_code = f"GEX_{ticker}_AUGUST_2026_BEST"
    signal_code = f"{ticker}_AUGUST_2026_BEST_SIGNAL"
    display = f"{ticker} August 2026 Best GEX Candidate"
    direction, horizon, trigger = str(row.direction), str(row.horizon), str(row.trigger)
    required = identifiers(trigger)
    directory = CONTRACT_ROOT / f"{ticker}_AUGUST_2026_BEST"
    directory.mkdir(parents=True, exist_ok=True)
    p = outcomes[(outcomes.ticker == row.ticker) & outcomes[f"ret_{horizon}"].notna()].sort_values("market_date").copy()
    masks = []
    for item in p.to_dict("records"):
        masks.append(eval_trigger(trigger, {name: item.get(name) for name in required}))
    p["triggered"] = masks
    raw_return = pd.to_numeric(p[f"ret_{horizon}"], errors="coerce")
    p["return_pct"] = raw_return * (1 if direction == "LONG" else -1)
    signal_rows = p[p.triggered].copy()
    full = metric(signal_rows.return_pct)
    nonsignal = metric(p.loc[~p.triggered, "return_pct"])
    source_start = str(p.market_date.min())[:10] if len(p) else "2026-08-01"
    ledger_rows = []
    for item in signal_rows.itertuples(index=False):
        d0 = str(item.market_date)[:10]
        entry_date = str(item.entry_date)[:10]
        entry = float(item.entry_price)
        directional = float(item.return_pct)
        raw = directional if direction == "LONG" else -directional
        exit_price = entry * (1 + raw / 100)
        values = {"signal_code": signal_code, "market_date": d0, "direction": direction, "triggered": True, "resolved": True, "entry_timestamp": timestamp(entry_date, time(7, 30)), "entry_price": entry, "exit_timestamp": timestamp(str(getattr(item, f"exit_D{horizon[1:]}") or item.entry_date)[:10], time(16, 0)), "exit_price": exit_price, "exit_reason": f"{horizon}_CLOSE", "return_pct": directional, "source_revision": hashlib.sha256(f"{strategy_code}|{d0}|{source_hash}".encode()).hexdigest(), "source_hash": source_hash}
        for name in required:
            value = getattr(item, name, None)
            values[f"feature__{name}"] = None if pd.isna(value) else float(value)
        ledger_rows.append(values)
    with (directory / "historical-instance-ledger.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(ledger_rows[0]) if ledger_rows else ["signal_code", "market_date"])
        writer.writeheader(); writer.writerows(ledger_rows)
    sample_start = str(p.market_date.min())[:10] if len(p) else None
    sample_end = str(p.market_date.max())[:10] if len(p) else None
    signal_history = {"status": "AVAILABLE" if full["n"] else "INSUFFICIENT", "instances": full["n"], "sample_start": sample_start, "sample_end": sample_end, "measurement_horizon": horizon, "win_rate_pct": full["wr"], "profit_factor": full["pf"], "source_reference": "historical-performance.json + historical-instance-ledger.csv", "as_of_utc": "2026-10-18T07:00:00Z", "notes": "August all-universe research candidate; September and October 2026 were excluded."}
    empty_history = {"status": "NOT_AVAILABLE", "instances": 0, "sample_start": None, "sample_end": None, "measurement_horizon": "NONE", "win_rate_pct": None, "profit_factor": None, "source_reference": "No actionable instances", "as_of_utc": "2026-10-18T07:00:00Z", "notes": "Non-actionable catalogue state."}
    performance = {"format_version": 2, "strategy_code": strategy_code, "version_code": VERSION, "as_of": AS_OF, "signal_code": signal_code, "status": "AVAILABLE", "eligible_sample_definition": "D0 has complete SQL-backed causal inputs, next valid US 07:30 ET bar, and scheduled exit bar on or before 2026-08-31.", "number_signal_instances": full["n"], "resolved_denominator": full["n"], "unresolved_instances": 0, "performance": full, "research_splits": split_metrics(signal_rows, direction), "non_signal_comparison": {"n": nonsignal["n"], "mean_return_pct": nonsignal["mean"], "edge_vs_non_signal_pct_points": (full["mean"] - nonsignal["mean"]) if full["mean"] is not None and nonsignal["mean"] is not None else None}, "return_units": "percentage points, direction-adjusted gross return", "entry_rule": "D1 07:30 ET Open", "exit_rule": f"{horizon} final regular-session Close", "transaction_costs_bps_round_trip": 0, "slippage_bps_round_trip": 0, "position_sizing": "1x theoretical notional return per independent signal instance", "overlap_treatment": "Signals are not suppressed by prior positions; manual portfolio decisions remain separate.", "research_cutoff": CUTOFF, "reserved_forward_window": "2026-09-01 through 2026-10-31; not included.", "classification": "ALL_UNIVERSE_RESEARCH_CANDIDATE", "source_snapshot_hash": source_hash, "per_instance_ledger": "historical-instance-ledger.csv"}
    dump(directory / "historical-performance.json", performance)
    confidence = "MEDIUM" if full["n"] >= 8 else "LOW"
    descriptor = {"descriptor_format": 2, "contract_format_version": "2", "strategy_code": strategy_code, "strategy_definition": f"{ticker} {trigger} {direction} candidate with {horizon} scheduled exit.", "display_name": display, "version_code": VERSION, "implementation_key": strategy_code.lower().replace("_", "-"), "status": "IMPLEMENTABLE", "definition": {"purpose": f"{ticker} all-August-universe GEX candidate selected from best-by-ticker research.", "rationale": "Research candidate generated from the complete August 2026 Analysis.GEX_Features universe; not a claim of proof or automatic production promotion.", "market_timezone": "America/New_York", "calendar": "US listed-equity sessions; DST and holidays handled by runtime.", "multiple_signal_policy": "One actionable signal per D0; DATA_ERROR precedes NO_SIGNAL.", "trigger_precedence": [signal_code, "DATA_ERROR", "NO_SIGNAL"], "source_refresh_gate": "At/after D1 07:30 ET require previous completed D0, complete required StockDB_US rows, causal history, and executable D1 entry. Missing/stale/null inputs => NOT_READY."}, "research_governance": {"owner": "USER", "research_date": "2026-10-18", "freeze_date": "2026-10-18", "research_cutoff": CUTOFF, "reserved_oos_window": "2026-09-01 through 2026-10-31", "change_summary": "All-August-universe candidate packet; no September or October data used.", "classification": "ALL_UNIVERSE_RESEARCH_CANDIDATE", "validation_method": "Chronological 60/20/20 split through the August cutoff.", "bias_controls": ["future-return fields excluded from predicates", "prior-only causal ranks", "D1 07:30 ET entry", "SQL date cutoff", "broker execution hard-disabled", "multiple-testing risk disclosed"]}, "instruments": [{"code": ticker, "role": "SUBJECT", "market": "US listed market", "currency": "USD", "timezone": "America/New_York"}], "instrument_roles": [{"role": "SUBJECT", "instrument": f"{ticker}.US"}], "environments": ["BACKTEST", "LIVE_MANUAL"], "run_kinds": ["DATA_CHECK", "EVALUATE", "MONITOR", "SUMMARY"], "schedule_requirements": ["07:30 America/New_York daily EVALUATE", "30-minute MONITOR until session close"], "report_kinds": ["SIGNAL", "DATA_ERROR", "NO_SIGNAL"], "required_sources": ["StockDB_US.Transform.OptionGEXChangeCapitalType", "StockDB_US.Analysis.GEX_Features", "StockDB_US.StockData.PriceHistoryTimeFrame"], "execution_enabled_capability": False, "outcome_horizons": [horizon], "feature_specification": [feature_spec(name) for name in required], "signal_definitions": [{"signal_code": signal_code, "display_name": display, "strategy_definition": f"{ticker} {trigger} {direction} candidate with {horizon} scheduled exit.", "direction": direction, "confidence": confidence, "action": "PLAN_ENTRY", "notification_level": "NORMAL", "production_notification_allowed": True, "definition": f"{trigger} with direction-adjusted {horizon} outcome.", "trigger_condition": trigger, "variables": required, "entry_policy": "D1 07:30 America/New_York 30-minute bar Open; D1 is next valid US session after D0.", "holding_period": horizon, "exit_conditions": [{"kind": "SCHEDULED_CLOSE", "description": f"Scheduled exit at {horizon} final regular-session bar Close", "horizon": horizon}, {"kind": "NO_STOP", "description": "No stop-loss or take-profit in this contract", "horizon": None}, {"kind": "MISSING_EXIT", "description": "Missing exit bar => PENDING", "horizon": None}], "creates_report": True, "creates_paper_plan": True, "sends_notification": True, "historical_performance": signal_history}, {"signal_code": "DATA_ERROR", "display_name": "Data Error", "strategy_definition": "Readiness-passed evaluation error catalogue state.", "direction": "NONE", "confidence": "NONE", "action": "NONE", "notification_level": "HIGH", "production_notification_allowed": False, "definition": "Readiness passed but evaluation received invalid input.", "trigger_condition": "evaluation_error_after_readiness == true", "variables": [], "entry_policy": "NONE", "holding_period": "NONE", "exit_conditions": [{"kind": "NONE", "description": "No trade action", "horizon": None}], "creates_report": True, "creates_paper_plan": False, "sends_notification": False, "historical_performance": empty_history}, {"signal_code": "NO_SIGNAL", "display_name": "No Signal", "strategy_definition": "Readiness-passed non-actionable catalogue state.", "direction": "NONE", "confidence": "NONE", "action": "NONE", "notification_level": "NONE", "production_notification_allowed": False, "definition": "Readiness passed and candidate predicate is false.", "trigger_condition": f"NOT({trigger})", "variables": required, "entry_policy": "NONE", "holding_period": "NONE", "exit_conditions": [{"kind": "NONE", "description": "No trade action", "horizon": None}], "creates_report": True, "creates_paper_plan": False, "sends_notification": False, "historical_performance": empty_history}], "production_policy": {"deployment_state": "PRODUCTION", "deployment_target": "PRODUCTION", "enabled": True, "mode": "NOTIFICATION_ONLY", "broker_execution": "HARD_DISABLED", "broker_orders_authorized": False, "human_trade_recording_required": True, "notification_default": True, "manual_trade_optional": True, "manual_trade_required_for_outcome": False, "notifications": {"enabled": True, "channel": "PUSHOVER", "deduplication_key": "SHA256(strategy_code|version_code|market_date|signal_code|source_revision)", "recipient": "Configured production recipient from secrets; never embedded"}, "report_authentication_required": True, "change_control": "Any trigger, feature, direction, entry, exit, or notification change requires a new version."}, "provenance": {"as_of": AS_OF, "research_window": {"start": source_start, "end": CUTOFF}, "reserved_oos_window": {"start": "2026-09-01", "end": "2026-10-31", "status": "UNTOUCHED_BY_THIS_PACKET"}, "source_hash": source_hash, "implementation_hash": "", "source_manifest": "source-manifest.json"}}
    logic_path = directory / "strategy_logic.py"; logic_path.write_text(make_logic(strategy_code, signal_code, trigger, direction, horizon, required), encoding="utf-8")
    descriptor["provenance"]["implementation_hash"] = sha256(logic_path)
    dump(directory / "strategy.descriptor.json", descriptor)
    manifest = {"manifest_format": 2, "strategy_code": strategy_code, "version_code": VERSION, "as_of": AS_OF, "combined_source_hash": source_hash, "implementation_sha256": descriptor["provenance"]["implementation_hash"], "database": {"name": "StockDB_US", "read_only_research": True, "cutoff": CUTOFF, "schemas": {"capital": "Transform.OptionGEXChangeCapitalType", "features": "Analysis.GEX_Features", "intraday": "StockData.PriceHistoryTimeFrame", "option_quotes_explored_not_used": "StockData.OptionDelayedQuote_V2"}}, "option_quote_timing_policy": {"observation_date": "authoritative US trading date", "create_date": "insert-system timestamp only; never relabels ObservationDate", "last_trade_time": "option last-trade timestamp in source US timezone", "open_interest_availability": "commonly available on the second Sydney date between 20:00 and 23:00; map to the D1 07:30 ET readiness gate"}, "query_policy": {"symbols": [f"{ticker}.US"], "capital_types": ["BC", "BP", "SC", "SP"], "timeframe": "30M", "future_labels_excluded": ["TomorrowChange", "Next2DaysChange", "Next5DaysChange", "Next10DaysChange", "Next20DaysChange"]}, "research_source_note": "Direct StockDB_US research through 2026-08-31 only; no Google Drive; September and October reserved."}
    dump(directory / "source-manifest.json", manifest)
    markdown = f'''# {display}\n\n## Identity and change rationale\n\n- Strategy Code: `{strategy_code}`\n- Version Code: `{VERSION}`\n- Implementation Key: `{descriptor["implementation_key"]}`\n- This packet contains the top-scoring candidate for `{ticker}` from the complete August 2026 GEX universe.\n\n## Research provenance\n\nResearch uses StockDB_US through **2026-08-31**. September and October 2026 are untouched and reserved for forward validation.\n\n## Instrument Roles\n\n- SUBJECT: `{ticker}.US`\n\n## Observation and source provenance\n\nCapital-type data: `Transform.OptionGEXChangeCapitalType`; GEX features: `Analysis.GEX_Features`; execution bars: `StockData.PriceHistoryTimeFrame`.\n\n## Formulas, units, null behavior, and lag ordering\n\nRequired inputs: `{", ".join(required)}`. Causal ranks exclude D0 from their prior reference history. Null, stale, or non-finite inputs produce `NOT_READY`.\n\n## Data validity and fail-closed policy\n\nIncomplete BC/BP/SC/SP data, fewer than 60 prior valid observations, or missing execution bars blocks evaluation.\n\n## Causal history and windows\n\nThe candidate was researched with a chronological 60/20/20 split through the August cutoff.\n\n## Ordered Signal rules\n\n| Classification | Direction | Confidence | Action |\n|---|---|---|---|\n| `{signal_code}` | {direction} | {confidence} | PLAN_ENTRY |\n| `DATA_ERROR` | NONE | NONE | NONE |\n| `NO_SIGNAL` | NONE | NONE | NONE |\n\nTrigger: `{trigger.replace('<', '&lt;').replace('>', '&gt;')}`\n\n## Operational decision and notification policy\n\nNotification-only. Broker execution is hard-disabled.\n\n## Schedule, calendar, and catch-up\n\nEvaluate at 07:30 America/New_York on the next valid US session after D0.\n\n## Lifecycle and occupancy\n\nOne actionable signal per D0; scheduled {horizon} holding period.\n\n## Execution price and outage behavior\n\nEntry is the D1 07:30 ET 30-minute bar Open; missing bars remain pending.\n\n## Report contract\n\nReports and paper plans may be created for actionable signals; no broker order is created.\n\n## Forward validation and governance\n\nForward validation must preserve September and October 2026 as out-of-sample data.\n\n## Failure, retry, and correction policy\n\nData readiness failures remain pending; deterministic evaluation errors are recorded as DATA_ERROR.\n\n## Deterministic acceptance fixtures\n\nSee `historical-performance.json`, `historical-instance-ledger.csv`, and `strategy_logic.py`.\n\n## Deployment and rollback\n\nThe descriptor is notification-only and must be independently reviewed before provisioning.\n\n## Unresolved decisions and declarations\n\nThe candidate is research-derived and not a claim of proof.\n'''
    md_path = directory / "strategy.md"; md_path.write_text(markdown, encoding="utf-8")
    descriptor["markdown_path"] = "strategy.md"; descriptor["markdown_sha256"] = normalized_text_sha256(md_path); dump(directory / "strategy.descriptor.json", descriptor)
    dump(directory / "fixtures.json", {"strategy_code": strategy_code, "version_code": VERSION, "fixtures": [{"id": "missing-required-input", "expected_state": "NOT_READY"}, {"id": "production-policy", "expected": {"mode": "NOTIFICATION_ONLY", "broker_execution": "HARD_DISABLED"}}, {"id": "reserved-oos", "expected": "September and October 2026 excluded"}]})
    dump(directory / "acceptance-status.json", {"strategy_code": strategy_code, "version_code": VERSION, "status": "IMPLEMENTABLE", "classification": "ALL_UNIVERSE_RESEARCH_CANDIDATE", "research_cutoff": CUTOFF, "reserved_oos": "2026-09-01 through 2026-10-31", "broker_execution": "HARD_DISABLED", "notification_only": True})
    names = ["acceptance-status.json", "fixtures.json", "historical-instance-ledger.csv", "historical-performance.json", "source-manifest.json", "strategy.descriptor.json", "strategy.md", "strategy_logic.py"]
    (directory / "file-hashes.sha256").write_text("\n".join(f"{sha256(directory / name)}  {name}" for name in names) + "\n", encoding="utf-8")
    return {"ticker": ticker, "directory": directory.name, "strategy_code": strategy_code, "signal_code": signal_code, "direction": direction, "horizon": horizon, "trigger": trigger, "frequency_pct": float(row.frequency_pct), "instances": full["n"], "win_rate_pct": full["wr"], "mean_return_pct": full["mean"], "profit_factor": full["pf"]}


def main() -> None:
    best = pd.read_csv(RESEARCH / "best-by-ticker.csv")
    best = best.sort_values(["ticker", "score"], ascending=[True, False]).groupby("ticker", as_index=False).head(1).reset_index(drop=True)
    outcomes = pd.read_csv(RESEARCH / "eligible-outcomes.csv")
    outcomes["market_date"] = pd.to_datetime(outcomes["market_date"])
    source_hash = hashlib.sha256((RESEARCH / "best-by-ticker.csv").read_bytes() + (RESEARCH / "eligible-outcomes.csv").read_bytes()).hexdigest()
    if CONTRACT_ROOT.exists(): shutil.rmtree(CONTRACT_ROOT)
    CONTRACT_ROOT.mkdir(parents=True)
    rows = [build_packet(row, outcomes, source_hash) for _, row in best.iterrows()]
    for name in ("README.md", "data-audit.json", "best-by-ticker.csv", "all-candidates.csv", "best-symbol-occurrence.csv", "distinct-stocks.csv", "high-frequency-review.md", "high-frequency-reduction-summary.csv"):
        source = RESEARCH / name
        if source.exists(): shutil.copy2(source, PACKAGE / name)
    pd.DataFrame(rows).to_csv(PACKAGE / "strategy-summary.csv", index=False)
    dump(PACKAGE / "master-manifest.json", {"package": "All-August-Universe GEX Candidate Contracts", "as_of": AS_OF, "research_cutoff": CUTOFF, "reserved_oos": "2026-09-01 through 2026-10-31", "source": "StockDB_US only", "deployment_policy": {"target": "PRODUCTION", "enabled": True, "mode": "NOTIFICATION_ONLY", "broker_execution": "HARD_DISABLED"}, "directory_count": len(rows), "strategies": rows})
    (CONTRACT_ROOT / "README.md").write_text(f"# All-August-Universe GEX Candidate Contracts — 2026-10-18\n\nThis archive contains one usable descriptor packet for each of the {len(rows)} symbols in `best-by-ticker.csv`, selecting the highest-scoring candidate per ticker. Research cutoff: **{CUTOFF}**. September and October 2026 are reserved for forward validation. All packets are notification-only and broker execution is hard-disabled. These are research candidates for backtesting and review, not automatic approval for live activation.\n", encoding="utf-8")
    print(CONTRACT_ROOT)
    print(f"generated {len(rows)} packets")


if __name__ == "__main__":
    main()
