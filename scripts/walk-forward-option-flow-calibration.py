"""Leakage-aware walk-forward evaluation for OptionFlowFeatures calibration.

The model is intentionally simple: historical medians by DTE bucket and gamma
regime are used to adjust implied range and implied volatility, while historical
pin rates are used as probabilities. No production scores are written.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import statistics
from collections import defaultdict
from datetime import date, datetime
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

ROOT = Path(__file__).resolve().parents[1]
CALIBRATION_SCRIPT = ROOT / "scripts" / "calibrate-option-flow-features.py"
DEFAULT_OUTPUT = ROOT / "backend" / "data" / "option_flow_calibration"


def load_calibration_module():
    spec = importlib.util.spec_from_file_location("option_flow_calibration", CALIBRATION_SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {CALIBRATION_SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def median_or_none(values: Iterable[float]) -> Optional[float]:
    values = list(values)
    return statistics.median(values) if values else None


def mean_or_none(values: Iterable[float]) -> Optional[float]:
    values = list(values)
    return statistics.mean(values) if values else None


def mean_bool(values: Iterable[bool]) -> Optional[float]:
    values = list(values)
    return sum(values) / len(values) if values else None


def key_for(item: Dict[str, Any]) -> Tuple[str, str]:
    return item["dte_bucket"], item["gamma_regime"]


def make_priors(items: List[Dict[str, Any]]) -> Dict[str, Dict[Tuple[str, str], float]]:
    groups: Dict[Tuple[str, str], List[Dict[str, Any]]] = defaultdict(list)
    for item in items:
        groups[key_for(item)].append(item)

    priors: Dict[str, Dict[Tuple[str, str], float]] = {
        "range_ratio": {},
        "pin_probability": {},
        "vol_ratio": {},
        "vol_probability": {},
    }
    for key, group in groups.items():
        range_ratios = [
            x["actual_abs_move_pct"] / x["implied_move_pct"]
            for x in group if x["implied_move_pct"] and x["implied_move_pct"] > 0
        ]
        pin_values = [x["pin_within_1pct"] for x in group]
        vol_ratios = [
            x["realized_to_implied_vol_ratio"]
            for x in group if x["realized_to_implied_vol_ratio"] is not None
        ]
        priors["range_ratio"][key] = median_or_none(range_ratios) or 1.0
        priors["pin_probability"][key] = mean_bool(pin_values) or 0.0
        if vol_ratios:
            priors["vol_ratio"][key] = median_or_none(vol_ratios) or 1.0
            priors["vol_probability"][key] = mean_bool(ratio > 1.0 for ratio in vol_ratios) or 0.0

    return priors


def lookup(priors: Dict[str, Dict[Tuple[str, str], float]], metric: str, item: Dict[str, Any]) -> Optional[float]:
    bucket = item["dte_bucket"]
    regime = item["gamma_regime"]
    candidates = [
        (bucket, regime),
        (bucket, "ALL"),
        ("ALL", regime),
        ("ALL", "ALL"),
    ]
    for key in candidates:
        if key in priors[metric]:
            return priors[metric][key]
    return None


def evaluate(items: List[Dict[str, Any]], priors: Dict[str, Dict[Tuple[str, str], float]]) -> Dict[str, Any]:
    range_items = [x for x in items if x["implied_move_valid"]]
    pin_items = [x for x in items if x["max_abs_gamma_strike"] is not None]
    vol_items = [x for x in items if x["realized_to_implied_vol_ratio"] is not None]

    range_raw_errors = [x["actual_abs_move_pct"] - x["implied_move_pct"] for x in range_items]
    range_calibrated = [
        x["implied_move_pct"] * (lookup(priors, "range_ratio", x) or 1.0)
        for x in range_items
    ]
    range_calibrated_errors = [x["actual_abs_move_pct"] - prediction for x, prediction in zip(range_items, range_calibrated)]
    range_raw_inside = [x["inside_implied_move"] for x in range_items]
    range_calibrated_inside = [
        x["actual_abs_move_pct"] <= prediction for x, prediction in zip(range_items, range_calibrated)
    ]

    pin_probabilities = [lookup(priors, "pin_probability", x) or 0.0 for x in pin_items]
    pin_outcomes = [x["pin_within_1pct"] for x in pin_items]

    vol_raw_errors = [x["realized_vol"] - x["implied_iv"] for x in vol_items]
    vol_calibrated_errors = [
        x["realized_vol"] - x["implied_iv"] * (lookup(priors, "vol_ratio", x) or 1.0)
        for x in vol_items
    ]
    vol_probabilities = [lookup(priors, "vol_probability", x) or 0.0 for x in vol_items]
    vol_outcomes = [x["realized_to_implied_vol_ratio"] > 1.0 for x in vol_items]

    result: Dict[str, Any] = {
        "range": {
            "n": len(range_items),
            "raw_inside_implied_move_pct": mean_bool(range_raw_inside),
            "calibrated_inside_move_pct": mean_bool(range_calibrated_inside),
            "raw_mae_pct": mean_or_none(abs(x) for x in range_raw_errors),
            "calibrated_mae_pct": mean_or_none(abs(x) for x in range_calibrated_errors),
            "median_actual_to_implied_ratio": median_or_none(
                x["actual_abs_move_pct"] / x["implied_move_pct"] for x in range_items if x["implied_move_pct"] > 0
            ),
        },
        "pin": {
            "n": len(pin_items),
            "observed_pin_within_1pct_pct": mean_bool(pin_outcomes),
            "mean_predicted_probability_pct": mean_or_none(pin_probabilities),
            "brier_score": mean_or_none((prediction - outcome) ** 2 for prediction, outcome in zip(pin_probabilities, pin_outcomes)),
        },
        "volatility": {
            "n": len(vol_items),
            "observed_realized_above_implied_pct": mean_bool(vol_outcomes),
            "mean_predicted_probability_pct": mean_or_none(vol_probabilities),
            "raw_mae": mean_or_none(abs(x) for x in vol_raw_errors),
            "calibrated_mae": mean_or_none(abs(x) for x in vol_calibrated_errors),
            "brier_score": mean_or_none((prediction - outcome) ** 2 for prediction, outcome in zip(vol_probabilities, vol_outcomes)),
        },
    }
    return result


def group_evaluation(items: List[Dict[str, Any]], priors: Dict[str, Dict[Tuple[str, str], float]]) -> Dict[str, Any]:
    groups: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    for item in items:
        groups[f"{item['dte_bucket']} / {item['gamma_regime']}"].append(item)
    result: Dict[str, Any] = {}
    for name, group in groups.items():
        evaluated = evaluate(group, priors)
        key_item = group[0]
        evaluated["n_total"] = len(group)
        evaluated["learned_range_ratio"] = lookup(priors, "range_ratio", key_item)
        evaluated["learned_pin_probability"] = lookup(priors, "pin_probability", key_item)
        evaluated["learned_vol_ratio"] = lookup(priors, "vol_ratio", key_item)
        result[name] = evaluated
    return result


def split_items(items: List[Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
    # Training labels must have resolved by the training cutoff. Validation and
    # test outcomes may resolve later because they are evaluated retrospectively.
    train_end = date(2026, 3, 31)
    validation_end = date(2026, 6, 30)
    validation_start = date(2026, 4, 1)
    test_start = date(2026, 7, 1)

    train = [
        x for x in items
        if date.fromisoformat(x["observation_date"]) <= train_end
        and date.fromisoformat(x["expiry_date"]) <= train_end
    ]
    validation = [
        x for x in items
        if validation_start <= date.fromisoformat(x["observation_date"]) <= validation_end
    ]
    test = [x for x in items if date.fromisoformat(x["observation_date"]) >= test_start]
    return {"train": train, "validation": validation, "test": test}


def fmt(value: Any, percent: bool = False) -> str:
    if value is None:
        return "n/a"
    return f"{value * 100:.2f}%" if percent else f"{value:.3f}"


def fmt_percentage_points(value: Any) -> str:
    return "n/a" if value is None else f"{value:.3f}%"


def markdown_report(stock_code: str, splits: Dict[str, List[Dict[str, Any]]], evaluations: Dict[str, Any]) -> str:
    lines = [
        f"# {stock_code} Walk-Forward Option-Flow Calibration",
        "",
        "This evaluates simple historical median adjustments without writing production scores.",
        "Training observations are restricted to rows whose expiry outcome was known by the training cutoff.",
        "",
        "## Split sizes",
        "",
        "| Split | Observation rows | Date range |",
        "|---|---:|---|",
    ]
    for name in ("train", "validation", "test"):
        rows = splits[name]
        lines.append(
            f"| {name.title()} | {len(rows)} | "
            f"{min((x['observation_date'] for x in rows), default='n/a')} → "
            f"{max((x['observation_date'] for x in rows), default='n/a')} |"
        )

    lines += [
        "",
        "## Walk-forward results",
        "",
        "| Evaluation | N | Raw metric | Calibrated metric |",
        "|---|---:|---:|---:|",
    ]
    for name in ("validation", "test"):
        result = evaluations[name]
        r = result["range"]
        lines.append(f"| {name.title()} range coverage | {r['n']} | {fmt(r['raw_inside_implied_move_pct'], True)} | {fmt(r['calibrated_inside_move_pct'], True)} |")
        lines.append(f"| {name.title()} range MAE | {r['n']} | {fmt_percentage_points(r['raw_mae_pct'])} | {fmt_percentage_points(r['calibrated_mae_pct'])} |")
        v = result["volatility"]
        lines.append(f"| {name.title()} volatility MAE | {v['n']} | {fmt(v['raw_mae'])} | {fmt(v['calibrated_mae'])} |")
        p = result["pin"]
        lines.append(f"| {name.title()} pin Brier score | {p['n']} | n/a | {fmt(p['brier_score'])} |")

    lines += [
        "",
        "## Test results by DTE and gamma regime",
        "",
        "| Group | N | Learned range ratio | Range coverage | Pin probability / observed | Learned vol ratio |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for name, result in evaluations["test_by_group"].items():
        r = result["range"]
        p = result["pin"]
        v = result["volatility"]
        lines.append(
            f"| {name} | {result['n_total']} | {fmt(result['learned_range_ratio'])} | "
            f"{fmt(r['calibrated_inside_move_pct'], True)} | "
            f"{fmt(result['learned_pin_probability'], True)} / {fmt(p['observed_pin_within_1pct_pct'], True)} | "
            f"{fmt(result['learned_vol_ratio'])} |"
        )

    lines += [
        "",
        "## Decision",
        "",
        "- These results are diagnostic only; no production score columns were updated.",
        "- A calibrated range multiplier should only be promoted if it improves coverage and MAE in both validation and test periods.",
        "- Pin probabilities should be promoted only after checking confidence intervals and expiry-level dependence.",
        "- Volatility selection requires actual strategy P&L, including spreads and transaction costs; forecast error alone is insufficient.",
    ]
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stock-code", default="QQQ")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    module = load_calibration_module()
    module.load_env()
    stock_code = args.stock_code.upper().removesuffix(".US")
    cn = module.connect()
    try:
        features, prices = module.fetch_rows(cn, stock_code)
    finally:
        cn.close()
    observations = module.build_observations(features, prices)
    clean = [
        x for x in observations
        if x["implied_move_valid"] and x["implied_iv_valid"] and x["gamma_valid"]
    ]
    splits = split_items(clean)
    train_priors = make_priors(splits["train"])
    validation_result = evaluate(splits["validation"], train_priors)
    test_result = evaluate(splits["test"], train_priors)
    evaluations = {
        "validation": validation_result,
        "test": test_result,
        "test_by_group": group_evaluation(splits["test"], train_priors),
        "training_priors": {
            metric: {f"{key[0]} / {key[1]}": value for key, value in values.items()}
            for metric, values in train_priors.items()
        },
    }
    output = {
        "stock_code": stock_code,
        "generated_utc": datetime.utcnow().isoformat() + "Z",
        "feature_rows": len(features),
        "outcome_observations": len(observations),
        "calibration_observations": len(clean),
        "excluded_invalid_move_or_gamma": len(observations) - len(clean),
        "split_sizes": {name: len(rows) for name, rows in splits.items()},
        "evaluations": evaluations,
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    stem = f"{stock_code.lower()}-walk-forward-calibration"
    (args.output_dir / f"{stem}.json").write_text(json.dumps(output, indent=2), encoding="utf-8")
    (args.output_dir / f"{stem}.md").write_text(
        markdown_report(stock_code, splits, evaluations), encoding="utf-8"
    )
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
