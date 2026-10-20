"""Test stricter variants of the highest-frequency August-2026 GEX candidates.

This reads the already-frozen universe-wide outcomes and never queries September
or October 2026. Variant selection uses only the train/validation partitions;
the August final tail is reported as a research-tail check, not used for
selection.
"""
from __future__ import annotations
import ast
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "backend" / "data" / "strategy_runtime" / "20261017" / "research_all_august_universe"
TARGET = 25.0

# These are the currently highest-frequency candidates from best-by-ticker.csv.
# Threshold variants only make the same rule more selective; they do not switch
# to a different signal family.
CONFIGS = {
    "S.US": ("D5", "LONG", "vol_price", {"vol": [.80, .85, .90, .95], "price": [2.0, 2.5, 3.0, 3.5, 4.0, 5.0]}),
    "MOD.US": ("D3", "LONG", "price_bp", {"price": [-2.0, -2.5, -3.0, -3.5, -4.0], "bp": [.80, .85, .90, .95]}),
    "IGV.US": ("D3", "LONG", "vol_price", {"vol": [.80, .85, .90, .95], "price": [2.0, 2.5, 3.0, 3.5, 4.0, 5.0]}),
    "ADBE.US": ("D5", "LONG", "price", {"price": [-2.0, -2.5, -3.0, -3.5, -4.0]}),
    "FCX.US": ("D5", "LONG", "price", {"price": [2.0, 2.5, 3.0, 3.5, 4.0, 5.0]}),
    "ZS.US": ("D5", "LONG", "sc", {"sc": [.80, .85, .90, .95]}),
    "COHR.US": ("D3", "LONG", "bc", {"bc": [.80, .85, .90, .95]}),
    "INTC.US": ("D5", "SHORT", "vol_bp", {"vol": [.20, .15, .10, .05], "bp": [.80, .85, .90, .95]}),
    "GDX.US": ("D5", "SHORT", "vol", {"vol": [.80, .85, .90, .95]}),
    "TXN.US": ("D5", "SHORT", "bp", {"bp": [.80, .85, .90, .95]}),
    "SPXU.US": ("D1", "LONG", "put", {"put": [.80, .85, .90, .95]}),
    "QCOM.US": ("D5", "LONG", "z", {"z": [-1.0, -1.25, -1.5, -1.75, -2.0]}),
    "PANW.US": ("D5", "LONG", "z", {"z": [-1.0, -1.25, -1.5, -1.75, -2.0]}),
}


def metric(values: pd.Series) -> dict:
    x = pd.to_numeric(values, errors="coerce").dropna().to_numpy(float)
    if len(x) == 0:
        return {"n": 0, "mean": None, "wr": None, "pf": None}
    wins, losses = x[x > 0], x[x <= 0]
    gross_loss = abs(losses.sum())
    return {
        "n": int(len(x)),
        "mean": float(x.mean()),
        "wr": float((x > 0).mean() * 100),
        "pf": float(wins.sum() / gross_loss) if gross_loss else None,
    }


def make_mask(p: pd.DataFrame, kind: str, params: dict) -> tuple[pd.Series, str]:
    if kind == "vol_price":
        m = (p.SafeGEXVolRank60 >= params["vol"]) & (p.PriceDistSMA50Pct >= params["price"])
        text = f"SafeGEXVolRank60 >= {params['vol']:.2f} AND PriceDistSMA50Pct >= {params['price']:.1f}"
    elif kind == "price_bp":
        m = (p.PriceDistSMA50Pct <= params["price"]) & (p.BPOptionCount_Rank60 >= params["bp"])
        text = f"PriceDistSMA50Pct <= {params['price']:.1f} AND BPOptionCount_Rank60 >= {params['bp']:.2f}"
    elif kind == "price":
        if params["price"] < 0:
            m = p.PriceDistSMA50Pct <= params["price"]
            text = f"PriceDistSMA50Pct <= {params['price']:.1f}"
        else:
            m = p.PriceDistSMA50Pct >= params["price"]
            text = f"PriceDistSMA50Pct >= {params['price']:.1f}"
    elif kind == "sc":
        m = p.SCShareRank60 >= params["sc"]
        text = f"SCShareRank60 >= {params['sc']:.2f}"
    elif kind == "bc":
        m = p.BCShareRank60 >= params["bc"]
        text = f"BCShareRank60 >= {params['bc']:.2f}"
    elif kind == "vol_bp":
        m = (p.SafeGEXVolRank60 <= params["vol"]) & (p.BPOptionCount_Rank60 >= params["bp"])
        text = f"SafeGEXVolRank60 <= {params['vol']:.2f} AND BPOptionCount_Rank60 >= {params['bp']:.2f}"
    elif kind == "vol":
        m = p.SafeGEXVolRank60 >= params["vol"]
        text = f"SafeGEXVolRank60 >= {params['vol']:.2f}"
    elif kind == "bp":
        m = p.BPOptionCount_Rank60 >= params["bp"]
        text = f"BPOptionCount_Rank60 >= {params['bp']:.2f}"
    elif kind == "put":
        m = p.PutBuyShareChgAbsRank60 >= params["put"]
        text = f"PutBuyShareChgAbsRank60 >= {params['put']:.2f}"
    elif kind == "z":
        m = p.GEX_ZScore <= params["z"]
        text = f"GEX_ZScore <= {params['z']:.2f}"
    else:
        raise ValueError(kind)
    return m.fillna(False), text


def flat(prefix: str, m: dict) -> dict:
    return {f"{prefix}_{k}": v for k, v in m.items()}


def run() -> tuple[pd.DataFrame, pd.DataFrame]:
    outcomes = pd.read_csv(OUT / "eligible-outcomes.csv")
    outcomes["market_date"] = pd.to_datetime(outcomes["market_date"])
    rows = []
    for ticker, (horizon, direction, kind, grid) in CONFIGS.items():
        p = outcomes[outcomes.ticker == ticker].dropna(subset=[f"ret_{horizon}"]).sort_values("market_date").copy()
        if len(p) < 20:
            continue
        n = len(p)
        train_end, validation_end = int(n * .6), int(n * .8)
        raw = p[f"ret_{horizon}"] * (1 if direction == "LONG" else -1)
        for keys in np.array(np.meshgrid(*grid.values())).T.reshape(-1, len(grid)):
            params = dict(zip(grid, keys))
            mask, trigger = make_mask(p, kind, params)
            train_mask = mask.iloc[:train_end]
            validation_mask = mask.iloc[train_end:validation_end]
            final_mask = mask.iloc[validation_end:]
            train = metric(raw.iloc[:train_end][train_mask])
            validation = metric(raw.iloc[train_end:validation_end][validation_mask])
            final = metric(raw.iloc[validation_end:][final_mask])
            rows.append({
                "ticker": ticker, "horizon": horizon, "direction": direction,
                "trigger": trigger, "frequency_pct": float(mask.mean() * 100),
                **flat("train", train), **flat("validation", validation), **flat("final", final),
                "target_distance": abs(float(mask.mean() * 100) - TARGET),
            })
    all_rows = pd.DataFrame(rows)
    if all_rows.empty:
        return all_rows, all_rows
    # Selection is intentionally based only on frequency, train, and validation.
    # The final August tail is not used to choose a rule. A reduction must be
    # strictly below the current candidate's frequency.
    current = pd.read_csv(OUT / "best-by-ticker.csv")
    current = current.sort_values(["ticker", "score"], ascending=[True, False]).groupby("ticker", as_index=False).head(1)
    base_frequency = current.set_index("ticker")["frequency_pct"].to_dict()
    all_rows["current_frequency_pct"] = all_rows["ticker"].map(base_frequency)
    all_rows["strictly_reduced"] = all_rows.frequency_pct < all_rows.current_frequency_pct - 1e-9
    eligible = all_rows[
        all_rows.strictly_reduced
        & all_rows.frequency_pct.between(15, 30)
        & (all_rows.train_n >= 8)
        & (all_rows.validation_n >= 4)
        & (all_rows.train_mean > 0)
        & (all_rows.validation_mean > 0)
        & (all_rows.train_pf.fillna(np.inf) > 1)
        & (all_rows.validation_pf.fillna(np.inf) > 1)
    ].copy()
    selected = eligible.sort_values(
        ["ticker", "target_distance", "validation_mean", "train_mean"],
        ascending=[True, True, False, False],
    ).groupby("ticker", as_index=False).head(1)
    selected["final_status"] = np.select(
        [selected.final_n < 3, (selected.final_mean > 0) & (selected.final_pf.fillna(np.inf) > 1)],
        ["NOT_ENOUGH_FINAL_DATA", "POSITIVE_AUGUST_FINAL_TAIL"],
        default="FAILED_AUGUST_FINAL_TAIL",
    )
    summary = pd.DataFrame({"ticker": list(CONFIGS)})
    summary["current_frequency_pct"] = summary.ticker.map(base_frequency)
    summary = summary.merge(selected[["ticker", "trigger", "frequency_pct", "train_n", "train_mean", "validation_n", "validation_mean", "validation_pf", "final_n", "final_mean", "final_pf", "final_status"]], on="ticker", how="left")
    summary["decision"] = np.where(summary.trigger.isna(), "NO_STRICT_VARIANT_PASSED_TRAIN_VALIDATION", summary.final_status)
    all_rows.to_csv(OUT / "high-frequency-reduction-all-variants.csv", index=False)
    selected.to_csv(OUT / "high-frequency-reduction-selected.csv", index=False)
    summary.to_csv(OUT / "high-frequency-reduction-summary.csv", index=False)
    return all_rows, selected


if __name__ == "__main__":
    all_variants, selected = run()
    print(f"tested variants: {len(all_variants)}")
    print(f"selected reductions: {len(selected)}")
    if not selected.empty:
        print(selected[["ticker", "trigger", "frequency_pct", "train_n", "train_mean", "validation_n", "validation_mean", "validation_pf", "final_n", "final_mean", "final_pf"]].to_string(index=False))
