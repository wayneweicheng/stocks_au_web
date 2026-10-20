"""Causal OptionDelayedQuote_V2 enrichment research through 2026-08-31."""
from __future__ import annotations

import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import numpy as np
import pandas as pd
import pyodbc

from generate_all_universe_contracts import eval_trigger

ROOT = Path(__file__).resolve().parents[2]
RESEARCH = ROOT / "backend/data/strategy_runtime/20261017/research_all_august_universe"
OUT = ROOT / "backend/data/strategy_runtime/20261018/option_quote_research"
START, CUTOFF = "2025-06-01", "2026-08-31"

SQL = """
SELECT ObservationDate, PorC, COUNT_BIG(*) ContractCount,
 SUM(COALESCE(Volume,0)) Volume, SUM(COALESCE(OpenInterest,0)) OpenInterest,
 SUM(CASE WHEN Volume>0 AND IV IS NOT NULL THEN Volume*IV ELSE 0 END) IVVolNum,
 SUM(CASE WHEN Volume>0 AND IV IS NOT NULL THEN Volume ELSE 0 END) IVVolDen,
 SUM(CASE WHEN OpenInterest>0 AND IV IS NOT NULL THEN OpenInterest*IV ELSE 0 END) IVOINum,
 SUM(CASE WHEN OpenInterest>0 AND IV IS NOT NULL THEN OpenInterest ELSE 0 END) IVOIDen,
 SUM(CASE WHEN Volume>0 AND Delta IS NOT NULL THEN Volume*ABS(Delta) ELSE 0 END) DeltaNum,
 SUM(CASE WHEN Volume>0 AND Gamma IS NOT NULL THEN Volume*ABS(Gamma) ELSE 0 END) GammaNum,
 SUM(CASE WHEN Volume>0 AND Vega IS NOT NULL THEN Volume*ABS(Vega) ELSE 0 END) VegaNum,
 SUM(CASE WHEN Volume>0 THEN Volume ELSE 0 END) GreekDen,
 SUM(CASE WHEN Bid IS NOT NULL AND Ask IS NOT NULL AND Bid+Ask>0 THEN (Ask-Bid)/((Bid+Ask)/2.0)*COALESCE(Volume,0) ELSE 0 END) SpreadNum,
 SUM(CASE WHEN Bid IS NOT NULL AND Ask IS NOT NULL AND Bid+Ask>0 THEN COALESCE(Volume,0) ELSE 0 END) SpreadDen,
 SUM(CASE WHEN DATEDIFF(day,ObservationDate,ExpiryDate) BETWEEN 0 AND 45 THEN COALESCE(Volume,0) ELSE 0 END) NearVolume,
 SUM(CASE WHEN DATEDIFF(day,ObservationDate,ExpiryDate) BETWEEN 0 AND 45 THEN COALESCE(OpenInterest,0) ELSE 0 END) NearOI,
 SUM(CASE WHEN DATEDIFF(day,ObservationDate,ExpiryDate) BETWEEN 0 AND 45 AND Volume>0 AND IV IS NOT NULL THEN Volume*IV ELSE 0 END) NearIVNum,
 SUM(CASE WHEN DATEDIFF(day,ObservationDate,ExpiryDate) BETWEEN 0 AND 45 AND Volume>0 AND IV IS NOT NULL THEN Volume ELSE 0 END) NearIVDen
FROM StockData.OptionDelayedQuote_V2 WITH (NOLOCK)
WHERE ASXCode=? AND ObservationDate BETWEEN ? AND ?
GROUP BY ObservationDate,PorC ORDER BY ObservationDate,PorC
"""


def db():
    vals = {}
    for line in (ROOT / "backend/.env").read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            k, v = line.split("=", 1)
            vals[k.strip()] = v.strip().strip('"').strip("'")
    cs = f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={vals['SQL_SERVER_HOST']},{vals.get('SQL_SERVER_PORT','1433')};DATABASE=StockDB_US;UID={vals['SQL_SERVER_USER']};PWD={vals['SQL_SERVER_PASSWORD']};Encrypt=no;TrustServerCertificate=yes;"
    return pyodbc.connect(cs, timeout=180)


def fetch(ticker):
    c = db()
    try:
        cur = c.cursor()
        cur.execute(SQL, ticker + ".US", START, CUTOFF)
        columns = [x[0] for x in cur.description]
        return ticker, pd.DataFrame.from_records(cur.fetchall(), columns=columns)
    finally:
        c.close()


def ratio(num, den):
    return num / den if den else np.nan


def aggregate(ticker, raw):
    if raw.empty:
        return pd.DataFrame()
    raw["PorC"] = raw["PorC"].fillna("U").astype(str).str.upper()
    raw["ObservationDate"] = pd.to_datetime(raw["ObservationDate"])
    rows = []
    for day, group in raw.groupby("ObservationDate"):
        out = {"ticker": ticker + ".US", "market_date": day}
        for kind, label in (("C", "Call"), ("P", "Put"), ("U", "Unknown")):
            z = group[group.PorC == kind]
            for field in ("ContractCount", "Volume", "OpenInterest", "NearVolume", "NearOI"):
                out[f"{label}{field}"] = float(z[field].sum()) if len(z) else 0.0
            for num, den, name in (("IVVolNum", "IVVolDen", "IVVol"), ("IVOINum", "IVOIDen", "IVOI"), ("NearIVNum", "NearIVDen", "NearIV"), ("DeltaNum", "GreekDen", "AbsDeltaVol"), ("GammaNum", "GreekDen", "AbsGammaVol"), ("VegaNum", "GreekDen", "AbsVegaVol"), ("SpreadNum", "SpreadDen", "SpreadVol")):
                out[f"{label}{name}"] = ratio(float(z[num].sum()), float(z[den].sum())) if len(z) else np.nan
        for field in ("Volume", "OpenInterest", "NearVolume", "NearOI", "ContractCount"):
            out[f"Total{field}"] = sum(out[f"{label}{field}"] for label in ("Call", "Put", "Unknown"))
        out["PutCallVolumeRatio"] = ratio(out["PutVolume"], out["CallVolume"])
        out["PutCallOIRatio"] = ratio(out["PutOpenInterest"], out["CallOpenInterest"])
        out["VolumeOIRatio"] = ratio(out["TotalVolume"], out["TotalOpenInterest"])
        out["NearVolumeShare"] = ratio(out["TotalNearVolume"], out["TotalVolume"])
        out["IV"] = ratio(sum(out[f"{label}IVVol"] * out[f"{label}Volume"] for label in ("Call", "Put", "Unknown") if np.isfinite(out[f"{label}IVVol"])), out["TotalVolume"])
        out["CallPutIVDiff"] = out["CallIVVol"] - out["PutIVVol"]
        out["Spread"] = ratio(sum(out[f"{label}SpreadVol"] * out[f"{label}Volume"] for label in ("Call", "Put", "Unknown") if np.isfinite(out[f"{label}SpreadVol"])), out["TotalVolume"])
        out["AbsDeltaVol"] = ratio(sum(out[f"{label}AbsDeltaVol"] * out[f"{label}Volume"] for label in ("Call", "Put", "Unknown") if np.isfinite(out[f"{label}AbsDeltaVol"])), out["TotalVolume"])
        out["AbsGammaVol"] = ratio(sum(out[f"{label}AbsGammaVol"] * out[f"{label}Volume"] for label in ("Call", "Put", "Unknown") if np.isfinite(out[f"{label}AbsGammaVol"])), out["TotalVolume"])
        out["AbsVegaVol"] = ratio(sum(out[f"{label}AbsVegaVol"] * out[f"{label}Volume"] for label in ("Call", "Put", "Unknown") if np.isfinite(out[f"{label}AbsVegaVol"])), out["TotalVolume"])
        rows.append(out)
    return pd.DataFrame(rows)


def rank(series, minimum=10):
    values = pd.to_numeric(series, errors="coerce").to_numpy(float)
    result = np.full(len(values), np.nan)
    for i, value in enumerate(values):
        if not np.isfinite(value):
            continue
        prior = values[max(0, i - 60):i]
        prior = prior[np.isfinite(prior)]
        if len(prior) >= minimum:
            result[i] = float((prior <= value).mean())
    return result


def stats(values):
    values = pd.to_numeric(values, errors="coerce").dropna()
    wins, losses = values[values > 0], values[values <= 0]
    loss = abs(float(losses.sum()))
    return {"n": len(values), "win_rate_pct": float((values > 0).mean() * 100) if len(values) else None, "mean_return_pct": float(values.mean()) if len(values) else None, "profit_factor": float(wins.sum() / loss) if loss else None}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    candidates = pd.read_csv(ROOT / "backend/data/strategy_runtime/20261018/strategy-summary.csv")
    symbols = sorted(pd.read_csv(RESEARCH / "distinct-stocks.csv").ticker.str.replace(".US", "", regex=False).tolist())
    frames = []
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = {pool.submit(fetch, ticker): ticker for ticker in symbols}
        for future in as_completed(futures):
            ticker = futures[future]
            try:
                ticker, raw = future.result()
                frames.append(aggregate(ticker, raw))
                print(ticker, len(raw))
            except Exception as exc:
                print("ERROR", ticker, exc)
    daily = pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()
    daily = daily.sort_values(["ticker", "market_date"])
    base_features = ["TotalVolume", "TotalOpenInterest", "VolumeOIRatio", "PutCallVolumeRatio", "PutCallOIRatio", "IV", "CallPutIVDiff", "NearVolumeShare", "Spread", "AbsDeltaVol", "AbsGammaVol", "AbsVegaVol", "TotalContractCount"]
    for ticker, indices in daily.groupby("ticker").groups.items():
        part = daily.loc[indices].sort_values("market_date").copy()
        for field in base_features:
            part[field + "_Rank60"] = rank(part[field])
            part[field + "_ChgRank60"] = rank(part[field].pct_change().abs())
        daily.loc[part.index, part.columns] = part
    daily.to_csv(OUT / "option-quote-daily-features.csv", index=False)

    outcomes = pd.read_csv(RESEARCH / "eligible-outcomes.csv")
    outcomes["market_date"] = pd.to_datetime(outcomes["market_date"])
    merged = outcomes.merge(daily, on=["ticker", "market_date"], how="left")
    capped = candidates[candidates.frequency_pct <= 25].copy()
    rows = []
    for candidate in capped.to_dict("records"):
        part = merged[merged.ticker == str(candidate["ticker"]) + ".US"].copy()
        if part.empty:
            continue
        part["triggered"] = part.apply(lambda row: eval_trigger(candidate["trigger"], row.to_dict()), axis=1)
        part = part[part.triggered].copy()
        if part.empty:
            continue
        for horizon in ("D1", "D3", "D5"):
            part["return_pct"] = pd.to_numeric(part[f"ret_{horizon}"], errors="coerce") * (1 if candidate["direction"] == "LONG" else -1)
            screens = {
                "OPTION_VOLUME_HIGH": part.TotalVolume_Rank60 >= .80,
                "OPTION_VOLUME_LOW": part.TotalVolume_Rank60 <= .20,
                "OPTION_OI_HIGH": part.TotalOpenInterest_Rank60 >= .80,
                "VOLUME_OI_HIGH": part.VolumeOIRatio_Rank60 >= .80,
                "PUT_CALL_VOLUME_HIGH": part.PutCallVolumeRatio_Rank60 >= .80,
                "IV_HIGH": part.IV_Rank60 >= .80,
                "IV_LOW": part.IV_Rank60 <= .20,
                "IV_CHANGE_HIGH": part.IV_ChgRank60 >= .80,
                "NEAR_VOLUME_HIGH": part.NearVolumeShare_Rank60 >= .80,
                "WIDE_SPREAD_HIGH": part.Spread_ChgRank60 >= .80,
            }
            for screen, mask in screens.items():
                rows.append({"ticker": candidate["ticker"], "direction": candidate["direction"], "horizon": horizon, "screen": screen, "frequency_pct": float(mask.mean() * 100), **stats(part.loc[mask, "return_pct"])})
    pd.DataFrame(rows).to_csv(OUT / "option-screen-results.csv", index=False)
    metadata = {"symbols_requested": len(symbols), "symbols_with_quote_features": int(daily.ticker.nunique()) if not daily.empty else 0, "date_start": str(daily.market_date.min())[:10] if not daily.empty else None, "date_end": str(daily.market_date.max())[:10] if not daily.empty else None, "observation_lag_policy": "ObservationDate D0 quote snapshot is assumed available before D1 07:30 ET, per operating convention.", "research_cutoff": CUTOFF, "oos_used_for_selection": False, "no_packet_changes": True}
    (OUT / "run-metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    (OUT / "README.md").write_text("# OptionDelayedQuote_V2 enriched research\n\n" + json.dumps(metadata, indent=2) + "\n\nFeatures include option volume, open interest, IV, call/put ratios, near-term concentration, spreads, and Greek exposure. Ranks exclude the current observation and require prior history.\n", encoding="utf-8")
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
