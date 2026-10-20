"""Research-only improvements for the August-2026 GEX packet selection.

This script uses only the frozen August research extract. It never reads
September or October outcomes and does not alter or provision any packet.
It tests frozen frequency gating, alternate fixed exits, causal regime filters,
signal-strength tiers, simple per-day portfolio caps, and cost sensitivity.
"""
from __future__ import annotations

import ast
import re
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
RESEARCH = ROOT / "backend" / "data" / "strategy_runtime" / "20261017" / "research_all_august_universe"
OUT = ROOT / "backend" / "data" / "strategy_runtime" / "20261018" / "research_improvements"
CUTOFF = pd.Timestamp("2026-08-31")

ATOM = re.compile(r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*(?P<op><=|>=|==|<|>)\s*(?P<value>-?\d+(?:\.\d+)?)")


def metric(values: pd.Series, cost_pct: float = 0.0) -> dict:
    values = pd.to_numeric(values, errors="coerce").dropna() - cost_pct
    if values.empty:
        return {"n": 0, "win_rate_pct": None, "mean_return_pct": None, "profit_factor": None}
    wins = values[values > 0]
    losses = values[values <= 0]
    gross_loss = abs(float(losses.sum()))
    return {
        "n": int(len(values)),
        "win_rate_pct": float((values > 0).mean() * 100),
        "mean_return_pct": float(values.mean()),
        "profit_factor": float(wins.sum() / gross_loss) if gross_loss else None,
    }


def selected_candidates() -> pd.DataFrame:
    candidates = pd.read_csv(RESEARCH / "best-by-ticker.csv")
    return (
        candidates.sort_values(["ticker", "score"], ascending=[True, False])
        .groupby("ticker", as_index=False)
        .head(1)
        .reset_index(drop=True)
    )


def trigger_values(trigger: str, row: pd.Series) -> bool:
    expression = re.sub(r"\bAND\b", "and", trigger, flags=re.I)
    expression = re.sub(r"\bOR\b", "or", expression, flags=re.I)
    expression = re.sub(r"\bNOT\b", "not", expression, flags=re.I)
    tree = ast.parse(expression, mode="eval")

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
                if left is None or right is None:
                    return False
                if isinstance(op, ast.Lt): result = left < right
                elif isinstance(op, ast.LtE): result = left <= right
                elif isinstance(op, ast.Gt): result = left > right
                elif isinstance(op, ast.GtE): result = left >= right
                elif isinstance(op, ast.Eq): result = left == right
                else: raise ValueError(type(op).__name__)
                if not result:
                    return False
                left = right
            return True
        if isinstance(node, ast.Name):
            value = row.get(node.id)
            return None if pd.isna(value) else float(value)
        if isinstance(node, ast.Constant) and isinstance(node.value, (int, float, bool)):
            return node.value
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.UAdd)):
            value = visit(node.operand)
            return None if value is None else (-value if isinstance(node.op, ast.USub) else value)
        raise ValueError(f"unsupported trigger node: {type(node).__name__}")

    return bool(visit(tree))


def strength(trigger: str, row: pd.Series) -> float:
    """Minimum normalized distance beyond each trigger atom.

    The scale is fixed from the predicate units, never learned from outcomes.
    Rank features use a 0..1 scale; percentage and z-score features use the
    larger of one and the absolute threshold to avoid division by zero.
    """
    margins = []
    for atom in ATOM.finditer(trigger):
        value = row.get(atom.group("name"))
        if pd.isna(value):
            return float("nan")
        value = float(value)
        threshold = float(atom.group("value"))
        signed = value - threshold if atom.group("op") in {">", ">="} else threshold - value
        if atom.group("op") == "==":
            signed = 1.0 if value == threshold else -1.0
        scale = 1.0 if "Rank" in atom.group("name") or "Percentile" in atom.group("name") else max(1.0, abs(threshold))
        margins.append(signed / scale)
    return min(margins) if margins else float("nan")


def build_signal_frame() -> pd.DataFrame:
    outcomes = pd.read_csv(RESEARCH / "eligible-outcomes.csv")
    outcomes["market_date"] = pd.to_datetime(outcomes["market_date"])
    candidates = selected_candidates()
    frames = []
    for candidate in candidates.to_dict("records"):
        ticker = candidate["ticker"]
        horizon = candidate["horizon"]
        part = outcomes[(outcomes.ticker == ticker) & outcomes[f"ret_{horizon}"].notna()].copy()
        if part.empty:
            continue
        part["triggered"] = part.apply(lambda row: trigger_values(candidate["trigger"], row), axis=1)
        part = part[part.triggered].copy()
        if part.empty:
            continue
        direction_multiplier = 1 if candidate["direction"] == "LONG" else -1
        for exit_horizon in ("D1", "D3", "D5"):
            part[f"return_{exit_horizon}_pct"] = pd.to_numeric(part[f"ret_{exit_horizon}"], errors="coerce") * direction_multiplier
        part["selected_return_pct"] = part[f"return_{horizon}_pct"]
        part["signal_strength"] = part.apply(lambda row: strength(candidate["trigger"], row), axis=1)
        part["direction"] = candidate["direction"]
        part["selected_horizon"] = horizon
        part["trigger"] = candidate["trigger"]
        part["frequency_pct"] = float(candidate["frequency_pct"])
        part["score"] = float(candidate["score"])
        frames.append(part)
    if not frames:
        return pd.DataFrame()
    result = pd.concat(frames, ignore_index=True)
    result["date_rank"] = result.groupby("ticker")["market_date"].rank(method="first")
    result["ticker_count"] = result.groupby("ticker")["market_date"].transform("count")
    result["split"] = np.select(
        [result.date_rank <= result.ticker_count * 0.6, result.date_rank <= result.ticker_count * 0.8],
        ["TRAIN_60", "VALIDATION_20"],
        default="FINAL_RESEARCH_TAIL_20",
    )
    return result.sort_values(["market_date", "ticker"]).reset_index(drop=True)


def regime_masks(frame: pd.DataFrame) -> dict[str, pd.Series]:
    number = lambda name: pd.to_numeric(frame.get(name, np.nan), errors="coerce")
    return {
        "ALL": pd.Series(True, index=frame.index),
        "VIX_LE_20": number("VIX") <= 20,
        "VIX_GT_20": number("VIX") > 20,
        "VIX_GT_25": number("VIX") > 25,
        "SPY_TREND_UP": number("SPY_GEX_ZScore_60day") >= 0,
        "SPY_TREND_DOWN": number("SPY_GEX_ZScore_60day") < 0,
        "QQQ_TREND_UP": number("QQQ_GEX_ZScore_60day") >= 0,
        "QQQ_TREND_DOWN": number("QQQ_GEX_ZScore_60day") < 0,
        "SPY_DAY_UP": number("SPY_TodayChange") > 0,
        "QQQ_DAY_UP": number("QQQ_TodayChange") > 0,
        "SPY_DAY_DOWN": number("SPY_TodayChange") <= 0,
        "QQQ_DAY_DOWN": number("QQQ_TodayChange") <= 0,
        "LOW_GEX_VOL": number("GEX_HighVolatility") == 0,
        "HIGH_GEX_VOL": number("GEX_HighVolatility") == 1,
    }


def run() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    frame = build_signal_frame()
    if frame.empty:
        raise RuntimeError("no triggered rows were produced")
    frame.to_csv(OUT / "signal-level-inputs.csv", index=False)

    # This is the frozen rule: not fitted to OOS, only applied to the known
    # candidate-frequency field from the August research ledger.
    frame = frame[frame.frequency_pct <= 25].copy()
    frame.to_csv(OUT / "frequency-capped-signals.csv", index=False)

    exit_rows = []
    for exit_horizon in ("D1", "D3", "D5"):
        for split in ("ALL", "TRAIN_60", "VALIDATION_20", "FINAL_RESEARCH_TAIL_20"):
            subset = frame if split == "ALL" else frame[frame.split == split]
            values = subset[f"return_{exit_horizon}_pct"].dropna()
            row = {"basket": "FREQUENCY_LE_25", "exit": exit_horizon, "split": split, **metric(values)}
            exit_rows.append(row)
    pd.DataFrame(exit_rows).to_csv(OUT / "exit-comparison.csv", index=False)

    regime_rows = []
    for name, mask in regime_masks(frame).items():
        for split in ("TRAIN_60", "VALIDATION_20", "FINAL_RESEARCH_TAIL_20"):
            subset = frame[mask & (frame.split == split)]
            result = metric(subset["selected_return_pct"])
            regime_rows.append({"regime": name, "split": split, **result})
    pd.DataFrame(regime_rows).to_csv(OUT / "regime-filter-comparison.csv", index=False)

    strength_rows = []
    for threshold in (0.00, 0.05, 0.10, 0.20, 0.30):
        mask = frame.signal_strength >= threshold
        for split in ("TRAIN_60", "VALIDATION_20", "FINAL_RESEARCH_TAIL_20"):
            subset = frame[mask & (frame.split == split)]
            strength_rows.append({"minimum_strength": threshold, "split": split, **metric(subset["selected_return_pct"])})
    pd.DataFrame(strength_rows).to_csv(OUT / "signal-strength-comparison.csv", index=False)

    cost_rows = []
    for cost_bps in (0, 10, 25, 50, 100):
        for split in ("ALL", "TRAIN_60", "VALIDATION_20", "FINAL_RESEARCH_TAIL_20"):
            subset = frame if split == "ALL" else frame[frame.split == split]
            cost_rows.append({"cost_bps_round_trip": cost_bps, "split": split, **metric(subset["selected_return_pct"], cost_bps / 100)})
    pd.DataFrame(cost_rows).to_csv(OUT / "cost-sensitivity.csv", index=False)

    portfolio_rows = []
    # Daily cap uses only D0 signal strength. Returns are averaged per day,
    # avoiding a high-frequency ticker dominating the portfolio report.
    for cap in (1, 3, 5, 10, 999):
        ordered = frame.sort_values(["market_date", "signal_strength", "ticker"], ascending=[True, False, True])
        limited = ordered.groupby("market_date", group_keys=False).head(cap)
        daily = limited.groupby("market_date")["selected_return_pct"].mean()
        portfolio_rows.append({"max_signals_per_day": cap, **metric(daily)})
    pd.DataFrame(portfolio_rows).to_csv(OUT / "portfolio-cap-comparison.csv", index=False)

    summary = {
        "research_cutoff": str(CUTOFF.date()),
        "reserved_forward_window": "2026-09-01 through 2026-10-31",
        "selected_candidate_count": int(len(selected_candidates())),
        "frequency_capped_ticker_count": int(frame.ticker.nunique()),
        "frequency_capped_signal_count": int(len(frame)),
        "frequency_rule": "candidate frequency_pct <= 25; frozen from pre-cutoff research and not fitted to OOS",
        "tested": ["fixed D1/D3/D5 exits", "causal regime partitions", "signal strength distances", "daily signal caps", "0/10/25/50/100 bps costs"],
        "not_tested": ["trailing/MAE stops require intraday path replay and are not inferred from daily returns"],
        "source": "StockDB_US-derived eligible-outcomes.csv and best-by-ticker.csv",
    }
    (OUT / "README.md").write_text(
        "# August 2026 strategy improvement research\n\n"
        "This is a research-only artifact. It uses data through 2026-08-31 and does not read or modify the September/October validation window. No packet was changed or provisioned.\n\n"
        "The <=25% candidate-frequency rule is frozen, not optimized here. Exit, regime, signal-strength, portfolio-cap, and cost outputs are screening evidence only; any promoted change requires a new chronological walk-forward run.\n\n"
        "Trailing stops and maximum-adverse-excursion exits are intentionally not fabricated from daily OHLC. They require a point-in-time 30-minute path replay with conservative stop ordering.\n",
        encoding="utf-8",
    )
    import json
    (OUT / "run-metadata.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    run()
