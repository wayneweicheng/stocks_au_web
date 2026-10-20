"""Universe-wide US GEX discovery using StockDB_US, cutoff 2026-08-31.

The universe is derived from Analysis.GEX_Features for August 2026 rather than
from the previous selected-contract archive. September and October are never
queried for research outcomes.
"""
from __future__ import annotations
import json, math
from pathlib import Path
from datetime import date
import numpy as np
import pandas as pd

from us_gex_sql_research import (
    ROOT, OUT as OLD_OUT, CUTOFF, db_connection, sql_frame, add_daily_features,
    add_intraday_features, add_benchmarks, prior_rank, local_market_time,
    session_offset, cash_close_local,
)

OUT = ROOT / "backend" / "data" / "strategy_runtime" / "20261017" / "research_all_august_universe"
MIN_SIGNAL = 8

RULES = {
    "GEX_RANK_LOW": ("GEX_Rank60 <= 0.20", lambda x: x["GEX_Rank60"] <= .20, ["GEX_Rank60"]),
    "GEX_RANK_HIGH": ("GEX_Rank60 >= 0.80", lambda x: x["GEX_Rank60"] >= .80, ["GEX_Rank60"]),
    "GEX_VOL_LOW": ("SafeGEXVolRank60 <= 0.20", lambda x: x["SafeGEXVolRank60"] <= .20, ["SafeGEXVolRank60"]),
    "GEX_VOL_HIGH": ("SafeGEXVolRank60 >= 0.80", lambda x: x["SafeGEXVolRank60"] >= .80, ["SafeGEXVolRank60"]),
    "GEX_Z_LOW": ("GEX_ZScore <= -1.0", lambda x: x["GEX_ZScore"] <= -1.0, ["GEX_ZScore"]),
    "GEX_Z_HIGH": ("GEX_ZScore >= 1.0", lambda x: x["GEX_ZScore"] >= 1.0, ["GEX_ZScore"]),
    "RSI_LOW": ("RSI <= 30", lambda x: x["RSI"] <= 30, ["RSI"]),
    "RSI_HIGH": ("RSI >= 70", lambda x: x["RSI"] >= 70, ["RSI"]),
    "PRICE_DIST_LOW": ("PriceDistSMA50Pct <= -2.0", lambda x: x["PriceDistSMA50Pct"] <= -2.0, ["PriceDistSMA50Pct"]),
    "PRICE_DIST_HIGH": ("PriceDistSMA50Pct >= 2.0", lambda x: x["PriceDistSMA50Pct"] >= 2.0, ["PriceDistSMA50Pct"]),
    "BC_SHARE_HIGH": ("BCShareRank60 >= 0.80", lambda x: x["BCShareRank60"] >= .80, ["BCShareRank60"]),
    "BP_SHARE_HIGH": ("BPShare_Rank60 >= 0.80", lambda x: x["BPShare_Rank60"] >= .80, ["BPShare_Rank60"]),
    "SC_SHARE_HIGH": ("SCShareRank60 >= 0.80", lambda x: x["SCShareRank60"] >= .80, ["SCShareRank60"]),
    "SP_SHARE_HIGH": ("SPShare_Rank60 >= 0.80", lambda x: x["SPShare_Rank60"] >= .80, ["SPShare_Rank60"]),
    "BC_COUNT_HIGH": ("BCOptionCount_Rank60 >= 0.80", lambda x: x["BCOptionCount_Rank60"] >= .80, ["BCOptionCount_Rank60"]),
    "BP_COUNT_HIGH": ("BPOptionCount_Rank60 >= 0.80", lambda x: x["BPOptionCount_Rank60"] >= .80, ["BPOptionCount_Rank60"]),
    "SC_COUNT_HIGH": ("SCOptionCount_Rank60 >= 0.80", lambda x: x["SCOptionCount_Rank60"] >= .80, ["SCOptionCount_Rank60"]),
    "SP_COUNT_HIGH": ("SPOptionCount_Rank60 >= 0.80", lambda x: x["SPOptionCount_Rank60"] >= .80, ["SPOptionCount_Rank60"]),
    "BULL_SHOCK": ("BullShareChgAbsRank60 >= 0.80", lambda x: x["BullShareChgAbsRank60"] >= .80, ["BullShareChgAbsRank60"]),
    "PUT_SHOCK": ("PutBuyShareChgAbsRank60 >= 0.80", lambda x: x["PutBuyShareChgAbsRank60"] >= .80, ["PutBuyShareChgAbsRank60"]),
    "SC_ROTATION": ("SCShareChgRank60 >= 0.80", lambda x: x["SCShareChgRank60"] >= .80, ["SCShareChgRank60"]),
    "SP_ROTATION": ("SPShareChgRank60 >= 0.80", lambda x: x["SPShareChgRank60"] >= .80, ["SPShareChgRank60"]),
    "HHI_HIGH": ("ConcentrationHHIRank60 >= 0.80", lambda x: x["ConcentrationHHIRank60"] >= .80, ["ConcentrationHHIRank60"]),
    "HHI_LOW": ("ConcentrationHHIRank60 <= 0.20", lambda x: x["ConcentrationHHIRank60"] <= .20, ["ConcentrationHHIRank60"]),
    "GEX_PRICE_SWING_UP": ("Is_Swing_Up == 1", lambda x: x["Is_Swing_Up"] == 1, ["Is_Swing_Up"]),
    "GEX_PRICE_SWING_DOWN": ("Is_Swing_Down == 1", lambda x: x["Is_Swing_Down"] == 1, ["Is_Swing_Down"]),
}


def universe():
    c = db_connection()
    try:
        q = """SELECT DISTINCT ASXCode FROM Analysis.GEX_Features WHERE ObservationDate >= '2026-08-01' AND ObservationDate < '2026-09-01' AND ASXCode IS NOT NULL"""
        return sorted(x for x in sql_frame(c, q)["ASXCode"].tolist() if x != "_VIX.US")
    finally:
        c.close()


def fetch(symbols):
    marks = ",".join("?" for _ in symbols)
    c = db_connection()
    try:
        cap = sql_frame(c, f"""SELECT ObservationDate,ASXCode,CapitalType,GEXDelta,NoOfOption,GEX,[Close],VWAP FROM Transform.OptionGEXChangeCapitalType WHERE ASXCode IN ({marks}) AND ObservationDate <= ? AND CapitalType IN ('BC','BP','SC','SP')""", symbols+[CUTOFF.date()])
        features = sql_frame(c, f"SELECT * FROM Analysis.GEX_Features WHERE ASXCode IN ({marks}) AND ObservationDate <= ? ORDER BY ASXCode,ObservationDate", symbols+[CUTOFF.date()])
        bars = sql_frame(c, f"""SELECT ASXCode,TimeFrame,TimeIntervalStart,ObservationDate,[Open],High,Low,[Close],Volume,VWAP FROM StockData.PriceHistoryTimeFrame WHERE ASXCode IN ({marks}) AND TimeFrame='30M' AND ObservationDate <= ? ORDER BY ASXCode,TimeIntervalStart""", symbols+[CUTOFF.date()])
    finally:
        c.close()
    for frame in (cap, features, bars):
        frame["ObservationDate"] = pd.to_datetime(frame["ObservationDate"])
    bars["TimeIntervalStart"] = pd.to_datetime(bars["TimeIntervalStart"])
    return cap, features, bars


def rank_hhi(daily):
    daily = daily.sort_values(["ASXCode", "ObservationDate"]).copy()
    result = []
    for _, part in daily.groupby("ASXCode", sort=False):
        part = part.copy()
        part["ConcentrationHHIRank60"] = prior_rank(part["ConcentrationHHI"])
        result.append(part)
    return pd.concat(result, ignore_index=True)


def outcome_frame(daily, bars):
    """Create labels on the scheduled XNYS session grid, never the next data row."""
    b = bars.copy()
    b["local"] = local_market_time(b["TimeIntervalStart"])
    b["local_date"] = pd.to_datetime(b["local"].dt.date)
    b["local_time"] = b["local"].dt.strftime("%H:%M")
    b["market_day"] = b["local"].dt.date
    entries = b[b["local_time"] == "07:30"]
    entry_map = {(r.ASXCode, r.market_day): float(r.Open) for r in entries.itertuples() if pd.notna(r.Open)}
    bars_by_day = {(symbol, day): part.sort_values("TimeIntervalStart") for (symbol, day), part in b.groupby(["ASXCode", "market_day"], sort=False)}
    out = []
    for symbol, subject in daily.groupby("ASXCode", sort=False):
        subject = subject.sort_values("ObservationDate")
        for row in subject.itertuples(index=False):
            d0_value = getattr(row, "ObservationDate")
            d0 = d0_value.date() if isinstance(d0_value, pd.Timestamp) else d0_value
            try:
                d1 = session_offset(d0, 1)
            except ValueError:
                continue
            entry = entry_map.get((symbol, d1))
            # Missing scheduled D1 07:30 bar blocks this instance; do not shift entry.
            if entry is None:
                continue
            result = {name: getattr(row, name, None) for name in subject.columns}
            result.update({"ticker": symbol, "market_date": d0, "entry_date": d1, "entry_price": entry})
            for horizon in (1, 3, 5):
                exit_date = session_offset(d0, horizon)
                close_time = cash_close_local(exit_date)
                day_bars = bars_by_day.get((symbol, exit_date))
                exit_bar = None if day_bars is None else day_bars[day_bars["local"].dt.tz_localize(None) < close_time].tail(1)
                if exit_bar is None or exit_bar.empty or pd.isna(exit_bar["Close"].iloc[0]) or exit_date > CUTOFF.date():
                    result[f"ret_D{horizon}"] = np.nan
                    result[f"exit_D{horizon}"] = None
                else:
                    exit_price = float(exit_bar["Close"].iloc[0])
                    result[f"ret_D{horizon}"] = (exit_price / entry - 1) * 100
                    result[f"exit_D{horizon}"] = exit_date
            out.append(result)
    return pd.DataFrame(out)


def metric(a):
    a = pd.to_numeric(a, errors="coerce").dropna().to_numpy(float)
    if not len(a):
        return {"n": 0, "mean": None, "wr": None, "pf": None}
    wins, losses = a[a > 0], a[a <= 0]
    gross_loss = abs(losses.sum())
    return {"n": len(a), "mean": float(a.mean()), "wr": float((a > 0).mean() * 100), "pf": float(wins.sum() / gross_loss) if gross_loss else None}


def run():
    symbols = universe()
    capital, features, bars = fetch(symbols)
    daily = add_daily_features(capital, features)
    daily = add_intraday_features(daily, bars)
    daily = add_benchmarks(daily)
    daily = rank_hhi(daily)
    forbidden = ["TomorrowChange", "Next2DaysChange", "Next5DaysChange", "Next10DaysChange", "Next20DaysChange"]
    daily = daily.drop(columns=[name for name in forbidden if name in daily.columns])
    outcomes = outcome_frame(daily, bars)
    candidates = []
    for ticker, full in outcomes.groupby("ticker", sort=True):
        for horizon in ("D1", "D3", "D5"):
            part = full[full[f"ret_{horizon}"].notna()].sort_values("market_date").copy()
            if len(part) < 20:
                continue
            n = len(part)
            train_end, validation_end = int(n * .6), int(n * .8)
            train, validation, final = part.iloc[:train_end], part.iloc[train_end:validation_end], part.iloc[validation_end:]
            masks = {}
            for name, (_, function, _) in RULES.items():
                try:
                    masks[name] = function(part).fillna(False)
                except KeyError:
                    masks[name] = pd.Series(False, index=part.index)
            names = list(masks)
            combinations = [(name,) for name in names] + [(names[i], names[j]) for i in range(len(names)) for j in range(i + 1, len(names))]
            for combination in combinations:
                mask = masks[combination[0]].copy()
                for name in combination[1:]:
                    mask &= masks[name]
                frequency = float(mask.mean())
                if frequency < .05 or frequency > .45:
                    continue
                for direction in ("LONG", "SHORT"):
                    returns = part[f"ret_{horizon}"] * (1 if direction == "LONG" else -1)
                    train_metric = metric(returns.loc[train.index][mask.loc[train.index]])
                    validation_metric = metric(returns.loc[validation.index][mask.loc[validation.index]])
                    final_metric = metric(returns.loc[final.index][mask.loc[final.index]])
                    if train_metric["n"] < MIN_SIGNAL or validation_metric["n"] < 4 or train_metric["mean"] is None or validation_metric["mean"] is None or train_metric["mean"] <= 0 or validation_metric["mean"] <= 0:
                        continue
                    score = validation_metric["mean"] + .25 * train_metric["mean"] + (.1 if validation_metric["pf"] and validation_metric["pf"] >= 1.5 else 0)
                    candidates.append({"ticker": ticker, "horizon": horizon, "direction": direction, "rules": combination, "trigger": " AND ".join(RULES[name][0] for name in combination), "frequency_pct": frequency * 100, "train": train_metric, "validation": validation_metric, "final": final_metric, "score": score, "variables": sorted({field for name in combination for field in RULES[name][2]})})
    result = pd.DataFrame(candidates)
    OUT.mkdir(parents=True, exist_ok=True)
    if not result.empty:
        result = result.sort_values(["ticker", "score"], ascending=[True, False])
        best = result.groupby("ticker", as_index=False).head(3)
        result.to_csv(OUT / "all-candidates.csv", index=False)
        best.to_csv(OUT / "best-by-ticker.csv", index=False)
    else:
        best = result
    outcomes.to_csv(OUT / "eligible-outcomes.csv", index=False)
    outcomes.to_csv(OUT / "recomputed-price-labels.csv", index=False)
    audit = {"universe_source": "Analysis.GEX_Features", "universe_month": "2026-08", "universe_count": len(symbols), "excluded_symbols": ["_VIX.US"], "symbols": symbols, "cutoff": str(CUTOFF.date()), "reserved_oos": "2026-09-01 through 2026-10-31", "capital_rows": len(capital), "feature_rows": len(features), "intraday_rows": len(bars), "symbols_with_30m": int(bars.ASXCode.nunique()), "corrected_time_policy": "TimeIntervalStart is New York wall time; entries require exact next-XNYS-session 07:30 bar; exits use last bar before scheduled cash close for XNYS session offset from D0.", "labels_exit_after_cutoff": 0}
    (OUT / "data-audit.json").write_text(json.dumps(audit, indent=2, default=str), encoding="utf-8")
    return result, best, audit


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    results, best, audit = run()
    print(json.dumps(audit, indent=2))
    print(best.to_string(index=False) if not best.empty else "no candidates")
