"""Reproduce the 2026-10-17 US GEX contract research from StockDB_US.

The research cutoff is deliberately 2026-08-31.  September and October rows are
not queried and are reserved for the user's untouched forward validation.
"""
from __future__ import annotations

import json
import math
import os
from datetime import date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

import numpy as np
import pandas as pd
import pyodbc
import exchange_calendars as xcals

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "backend" / "data" / "strategy_runtime" / "20261017" / "research"
CUTOFF = pd.Timestamp("2026-08-31")
TZ = ZoneInfo("America/New_York")

CANDIDATES = {
    "ADBE": ("LONG", "D5", "BPOptionCount_Rank60 <= 0.70 AND TotalOptionCount_Rank60 <= 0.70"),
    "CRWD": ("LONG", "D1", "SCOptionCountChg_Rank60 <= 0.80 AND Prev2DaysChange >= -1.0"),
    "GDX": ("LONG", "D5", "SafeGEXVolRank60 >= 0.40 AND NASDAQ_chg5 <= -1.0"),
    "IWM": ("LONG", "D5", "SafeGEXVolRank60 >= 0.60 AND SPY_SafeGEXVolRank60 >= 0.65"),
    "BABA": ("SHORT", "D5", "Price_SMA20 > Price_SMA50 AND BuyCall_GEXDeltaPerc_Rank60 <= 0.80"),
    "ORCL": ("SHORT", "D3", "PutBuyShareChgAbsRank60 >= 0.65 AND BuyCall_GEXDeltaPerc_Rank60 <= 0.48"),
    "QCOM": ("SHORT", "D1", "BB_Bandwidth <= 0.346 AND BullShareChgAbsRank60 <= 0.65"),
    "AAPL": ("LONG", "D3", "BCShareRank60 >= 0.65 AND QQQ_TodayChange > 0"),
    "DIA": ("LONG", "D5", "GEX_ZScore < -1.0"),
    "GLD": ("LONG", "D2", "GEX > GEX_SMA20 AND RSI > 65"),
    "INTC": ("SHORT", "D5", "BPOptionShare >= 0.31 AND BB_Bandwidth >= 0.253"),
    "XLE": ("LONG", "D5", "QQQ_SafeGEXVolRank60 <= 0.60 AND GEX_ZScore_60day > 0"),
    "PANW": ("LONG", "D5", "ABS(PCRChangePct) >= 10.0 AND QQQ_BB_Bandwidth >= 0.07"),
    "TLT": ("SHORT", "D5", "PriceDistSMA50Pct >= -1.0 AND SCShareChgRank60 >= 0.60"),
    "TXN": ("SHORT", "D5", "SCShare >= 0.0284 AND QQQ_BuyCall_GEXDeltaPerc_Rank60 <= 0.65 AND Gold_chg5 >= -1.0"),
    "COHR": ("SHORT", "D5", "SCShareRank60 <= 0.60 AND PX_WholeDayRet >= -4.0 AND PX_RTHRet >= -2.5"),
    "DRAM": ("SHORT", "D5", "GEX_Rank60 >= 0.30 AND TodayChange >= -3.0"),
    "FORM": ("SHORT", "D5", "GEX_SMA5 >= -814.3 AND ConcentrationHHI <= 0.5445"),
    "ZS": ("LONG", "D3", "BTC_chg5 <= 2.1 AND BullShareChgAbsRank60 <= 0.65"),
    "WDC": ("SHORT", "D5", "GEX_Rank60 >= 0.20 AND QQQ_GEX_ZScore_60day > -1.5"),
    "HPE": ("SHORT", "D1", "SPShareChgRank60 > 0.37"),
    "SOXL": ("LONG", "D3", "SafeGEXVolRank60 >= 0.65 AND QQQ_BB_Bandwidth > 0.081"),
}


def db_connection() -> pyodbc.Connection:
    values = {}
    for line in (ROOT / "backend" / ".env").read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    cs = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={values['SQL_SERVER_HOST']},"
        f"{values.get('SQL_SERVER_PORT', '1433')};DATABASE=StockDB_US;"
        f"UID={values['SQL_SERVER_USER']};PWD={values['SQL_SERVER_PASSWORD']};"
        "Encrypt=yes;TrustServerCertificate=yes;"
    )
    connection = pyodbc.connect(cs, timeout=15)
    connection.timeout = 120
    return connection


def sql_frame(connection: pyodbc.Connection, sql: str, params: list[str] | None = None) -> pd.DataFrame:
    return pd.read_sql_query(sql, connection, params=params or [])


def fetch_data() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    symbols = sorted({f"{ticker}.US" for ticker in CANDIDATES} | {"QQQ.US", "SPY.US"})
    marks = ",".join("?" for _ in symbols)
    connection = db_connection()
    try:
        capital = sql_frame(connection, f"""
            SELECT ObservationDate, ASXCode, CapitalType, GEXDelta, NoOfOption, GEX, [Close], VWAP
            FROM Transform.OptionGEXChangeCapitalType
            WHERE ASXCode IN ({marks}) AND ObservationDate <= ?
              AND CapitalType IN ('BC','BP','SC','SP')
            ORDER BY ASXCode, ObservationDate, CapitalType
        """, symbols + [CUTOFF.date()])
        features = sql_frame(connection, f"""
            SELECT * FROM Analysis.GEX_Features
            WHERE ASXCode IN ({marks}) AND ObservationDate <= ?
            ORDER BY ASXCode, ObservationDate
        """, symbols + [CUTOFF.date()])
        bars = sql_frame(connection, f"""
            SELECT ASXCode, TimeFrame, TimeIntervalStart, ObservationDate,
                   [Open], High, Low, [Close], Volume, VWAP
            FROM StockData.PriceHistoryTimeFrame
            WHERE ASXCode IN ({marks}) AND TimeFrame = '30M' AND ObservationDate <= ?
            ORDER BY ASXCode, TimeIntervalStart
        """, symbols + [CUTOFF.date()])
    finally:
        connection.close()
    capital["ObservationDate"] = pd.to_datetime(capital["ObservationDate"])
    features["ObservationDate"] = pd.to_datetime(features["ObservationDate"])
    bars["ObservationDate"] = pd.to_datetime(bars["ObservationDate"])
    bars["TimeIntervalStart"] = pd.to_datetime(bars["TimeIntervalStart"])
    return capital, features, bars


_XNYS = xcals.get_calendar("XNYS")


def session_offset(session_date: date, offset: int) -> date:
    """Return an XNYS session offset from D0, never the next available data row."""
    start = pd.Timestamp(session_date - timedelta(days=20))
    end = pd.Timestamp(session_date + timedelta(days=20))
    sessions = [item.date() for item in _XNYS.sessions_in_range(start, end)]
    if session_date in sessions:
        index = sessions.index(session_date)
    else:
        prior = [item for item in sessions if item < session_date]
        if not prior:
            raise ValueError(f"no prior XNYS session around {session_date}")
        index = sessions.index(prior[-1])
    target = index + int(offset)
    if target < 0 or target >= len(sessions):
        raise ValueError(f"session offset out of range: {session_date} + {offset}")
    return sessions[target]


def cash_close_local(session_date: date) -> datetime:
    schedule = _XNYS.schedule.loc[pd.Timestamp(session_date)]
    return schedule["close"].to_pydatetime().astimezone(TZ).replace(tzinfo=None)


def local_market_time(series: pd.Series) -> pd.Series:
    """Interpret SQL smalldatetime bars as New York wall time, not UTC."""
    values = pd.to_datetime(series)
    if values.dt.tz is not None:
        raise ValueError("expected naive StockDB_US wall-clock timestamps")
    return values.dt.tz_localize(TZ, ambiguous="raise", nonexistent="raise")


def prior_rank(series: pd.Series, window: int = 60, minimum: int = 10) -> pd.Series:
    """Percent of the prior window less than or equal to today's value."""
    values = pd.to_numeric(series, errors="coerce").to_numpy(dtype=float)
    result = np.full(len(values), np.nan)
    for index, value in enumerate(values):
        if not np.isfinite(value):
            continue
        prior = values[max(0, index - window):index]
        prior = prior[np.isfinite(prior)]
        if len(prior) >= minimum:
            result[index] = float(np.mean(prior <= value))
    return pd.Series(result, index=series.index)


def safe_z60(series: pd.Series, minimum: int = 10) -> pd.Series:
    values = pd.to_numeric(series, errors="coerce").to_numpy(dtype=float)
    result = np.full(len(values), np.nan)
    for index, value in enumerate(values):
        if not np.isfinite(value):
            continue
        prior = values[max(0, index - 60):index]
        prior = prior[np.isfinite(prior)]
        if len(prior) >= minimum:
            std = float(np.std(prior, ddof=1)) if len(prior) > 1 else 0.0
            result[index] = 0.0 if std == 0 else (value - float(np.mean(prior))) / std
    return pd.Series(result, index=series.index)


def add_daily_features(capital: pd.DataFrame, features: pd.DataFrame) -> pd.DataFrame:
    capital = capital.copy()
    capital["GEXAbs"] = capital["GEXDelta"].abs()
    cap = capital.pivot_table(
        index=["ASXCode", "ObservationDate"], columns="CapitalType",
        values=["GEXAbs", "NoOfOption"], aggfunc="sum"
    )
    cap.columns = [f"{a}_{b}" for a, b in cap.columns]
    cap = cap.reset_index()
    for name in ["BC", "BP", "SC", "SP"]:
        cap[f"GEXAbs_{name}"] = cap.get(f"GEXAbs_{name}", np.nan)
        cap[f"NoOfOption_{name}"] = cap.get(f"NoOfOption_{name}", np.nan)
    cap["TotalAbsGEX"] = cap[[f"GEXAbs_{x}" for x in ["BC", "BP", "SC", "SP"]]].sum(axis=1, min_count=4)
    cap["TotalNoOpt"] = cap[[f"NoOfOption_{x}" for x in ["BC", "BP", "SC", "SP"]]].sum(axis=1, min_count=4)
    for name in ["BC", "BP", "SC", "SP"]:
        cap[f"{name}Share"] = cap[f"GEXAbs_{name}"] / cap["TotalAbsGEX"]
        cap[f"{name}OptionShare"] = cap[f"NoOfOption_{name}"] / cap["TotalNoOpt"]
    cap["BullShare"] = cap["BCShare"] + cap["SPShare"]
    cap["BearShare"] = cap["BPShare"] + cap["SCShare"]
    cap["NetBullShare"] = cap["BullShare"] - cap["BearShare"]
    cap["PCR"] = cap["GEXAbs_BP"] / cap["GEXAbs_BC"].replace(0, np.nan)
    cap["ConcentrationHHI"] = sum(cap[f"{x}Share"] ** 2 for x in ["BC", "BP", "SC", "SP"])
    cap = cap.sort_values(["ASXCode", "ObservationDate"])
    for ticker, group_index in cap.groupby("ASXCode").groups.items():
        idx = list(group_index)
        part = cap.loc[idx].sort_values("ObservationDate")
        for column in ["BCShare", "BPShare", "SCShare", "SPShare", "BullShare", "BearShare", "PCR"]:
            part[f"{column}Chg"] = part[column].pct_change() if column == "PCR" else part[column].diff()
        part["PCRChangePct"] = part["PCR"].pct_change() * 100
        part["BCOptionCountChg"] = part["NoOfOption_BC"].diff()
        part["BPOptionCountChg"] = part["NoOfOption_BP"].diff()
        part["SCOptionCountChg"] = part["NoOfOption_SC"].diff()
        part["SPOptionCountChg"] = part["NoOfOption_SP"].diff()
        part["TotalOptionCount"] = part["TotalNoOpt"]
        part["TotalOptionCountChg"] = part["TotalNoOpt"].diff()
        for column in ["BCShare", "BPShare", "SCShare", "SPShare", "BullShare", "BearShare", "PCR",
                       "NoOfOption_BC", "NoOfOption_BP", "NoOfOption_SC", "NoOfOption_SP",
                       "BCShareChg", "BPShareChg", "SCShareChg", "SPShareChg",
                       "BCOptionCountChg", "BPOptionCountChg", "SCOptionCountChg", "SPOptionCountChg",
                       "TotalOptionCount", "TotalOptionCountChg", "GEXAbs_BP", "GEXAbs_BC"]:
            part[f"{column}_Rank60"] = prior_rank(part[column])
        part["BullShareChgAbsRank60"] = prior_rank(part["BullShareChg"].abs())
        part["PutBuyShareChgAbsRank60"] = prior_rank(part["BPShareChg"].abs())
        part["SCShareChgAbsRank60"] = prior_rank(part["SCShareChg"].abs())
        cap.loc[part.index, part.columns] = part
    # Use explicit names expected by the contracts.
    rename = {
        "NoOfOption_BP_Rank60": "BPOptionCount_Rank60",
        "TotalOptionCount_Rank60": "TotalOptionCount_Rank60",
        "SCOptionCountChg_Rank60": "SCOptionCountChg_Rank60",
        "BCShare_Rank60": "BCShareRank60", "SCShare_Rank60": "SCShareRank60",
        "SCShareChg_Rank60": "SCShareChgRank60", "SPShareChg_Rank60": "SPShareChgRank60",
        "GEXAbs_BP_Rank60": "BPAbsGEXRank60",
    }
    cap = cap.rename(columns=rename)
    feat = features.copy()
    feat["ASXCode"] = feat["ASXCode"].astype(str)
    out = feat.merge(cap, on=["ASXCode", "ObservationDate"], how="left", suffixes=("", "_cap"))
    out = out.sort_values(["ASXCode", "ObservationDate"])
    for ticker, group_index in out.groupby("ASXCode").groups.items():
        part = out.loc[list(group_index)].sort_values("ObservationDate")
        part["GEX_Rank60"] = prior_rank(part["GEX"])
        part["SafeGEXVolRank60"] = prior_rank(part["GEX_Volatility"])
        part["SafeGEXZ60"] = safe_z60(part["GEX"])
        part["BuyCall_GEXDeltaPerc_Rank60"] = prior_rank(part["BuyCall_GEXDeltaPerc"])
        for field in ["BTC", "Gold", "NASDAQ"]:
            part[f"{field}_chg5"] = part[field].pct_change(5) * 100
        part["PriceDistSMA50Pct"] = (part["Close"] / part["Price_SMA50"] - 1) * 100
        out.loc[part.index, part.columns] = part
    return out


def add_intraday_features(daily: pd.DataFrame, bars: pd.DataFrame) -> pd.DataFrame:
    bars = bars.copy()
    bars["local"] = local_market_time(bars["TimeIntervalStart"])
    bars["local_date"] = bars["local"].dt.date
    bars["local_time"] = bars["local"].dt.strftime("%H:%M")
    bars["date"] = pd.to_datetime(bars["local_date"])
    intraday = []
    for (symbol, d), part in bars.groupby(["ASXCode", "date"], sort=True):
        part = part.sort_values("TimeIntervalStart")
        rth = part[(part["local_time"] >= "09:30") & (part["local_time"] <= "15:30")]
        row = {"ASXCode": symbol, "ObservationDate": d}
        if len(part) and pd.notna(part["Open"].iloc[0]) and pd.notna(part["Close"].iloc[-1]):
            row["PX_WholeDayRet"] = (float(part["Close"].iloc[-1]) / float(part["Open"].iloc[0]) - 1) * 100
        if len(rth):
            row["PX_RTHRet"] = (float(rth["Close"].iloc[-1]) / float(rth["Open"].iloc[0]) - 1) * 100
        intraday.append(row)
    intraday = pd.DataFrame(intraday)
    return daily.merge(intraday, on=["ASXCode", "ObservationDate"], how="left")


def add_benchmarks(frame: pd.DataFrame) -> pd.DataFrame:
    frame = frame.copy()
    for benchmark in ["QQQ.US", "SPY.US"]:
        b = frame[frame["ASXCode"] == benchmark].copy()
        keep = ["ObservationDate", "SafeGEXVolRank60", "SafeGEXZ60", "GEX_ZScore_60day", "BB_Bandwidth",
                "BuyCall_GEXDeltaPerc", "BuyCall_GEXDeltaPerc_Rank60", "TodayChange"]
        b = b[keep].rename(columns={x: f"{benchmark.split('.')[0]}_{x}" for x in keep if x != "ObservationDate"})
        frame = frame.merge(b, on="ObservationDate", how="left")
    return frame


def evaluation_rows(frame: pd.DataFrame, bars: pd.DataFrame, triggered_only: bool = True) -> pd.DataFrame:
    bars = bars.copy()
    bars["local"] = local_market_time(bars["TimeIntervalStart"])
    bars["local_date"] = pd.to_datetime(bars["local"].dt.date)
    bars["local_time"] = bars["local"].dt.strftime("%H:%M")
    entries = bars[bars["local_time"] == "07:30"].sort_values(["ASXCode", "local_date"])
    exits = bars[bars["local_time"] == "15:30"].sort_values(["ASXCode", "local_date"])
    def as_date(value):
        return value.date() if isinstance(value, pd.Timestamp) else value
    entry_map = {(r.ASXCode, as_date(r.local_date)): float(r.Open) for r in entries.itertuples() if pd.notna(r.Open)}
    exit_map = {(r.ASXCode, as_date(r.local_date)): float(r.Close) for r in exits.itertuples() if pd.notna(r.Close)}
    all_rows = []
    for ticker, (direction, horizon, trigger) in CANDIDATES.items():
        subject = frame[frame["ASXCode"] == f"{ticker}.US"].copy().sort_values("ObservationDate")
        if subject.empty:
            continue
        subject["market_date"] = subject["ObservationDate"].dt.date
        subject["triggered"] = trigger_mask(subject, ticker)
        dates = sorted(d.date() if isinstance(d, pd.Timestamp) else d for d in entries.loc[entries["ASXCode"] == f"{ticker}.US", "local_date"].unique())
        source_rows = subject[subject["triggered"]] if triggered_only else subject
        for row in source_rows.itertuples():
            d0 = row.market_date
            future = [d for d in dates if d > d0]
            if not future or (future[0] - d0).days > 4:
                continue
            d1 = future[0]
            entry = entry_map.get((f"{ticker}.US", d1))
            if entry is None:
                continue
            n = int(horizon[1:])
            if len(future) < n:
                continue
            exit_date = future[n - 1]
            exit_price = exit_map.get((f"{ticker}.US", exit_date))
            if exit_price is None or exit_date > CUTOFF.date():
                continue
            raw = (exit_price / entry - 1) * 100
            ret = raw if direction == "LONG" else -raw
            values = {k: getattr(row, k, np.nan) for k in subject.columns if k not in {"Index"}}
            values.update({"ticker": ticker, "market_date": d0, "direction": direction, "horizon": horizon,
                           "triggered": bool(row.triggered),
                           "entry_date": d1, "entry_price": entry, "exit_date": exit_date,
                           "exit_price": exit_price, "return_pct": ret, "signal_code": ticker})
            all_rows.append(values)
    return pd.DataFrame(all_rows)


def trigger_mask(df: pd.DataFrame, ticker: str) -> pd.Series:
    # Every expression is written explicitly to prevent accidental use of a future label.
    def col(name: str) -> pd.Series:
        return pd.to_numeric(df.get(name, pd.Series(np.nan, index=df.index)), errors="coerce")
    q = lambda name: col(f"QQQ_{name}")
    s = lambda name: col(f"SPY_{name}")
    tests = {
        "ADBE": (col("BPOptionCount_Rank60") <= .70) & (col("TotalOptionCount_Rank60") <= .70),
        "CRWD": (col("SCOptionCountChg_Rank60") <= .80) & (col("Prev2DaysChange") >= -1.0),
        "GDX": (col("SafeGEXVolRank60") >= .40) & (col("NASDAQ_chg5") <= -1.0),
        "IWM": (col("SafeGEXVolRank60") >= .60) & (s("SafeGEXVolRank60") >= .65),
        "BABA": (col("Price_SMA20") > col("Price_SMA50")) & (col("BuyCall_GEXDeltaPerc_Rank60") <= .80),
        "ORCL": (col("PutBuyShareChgAbsRank60") >= .65) & (col("BuyCall_GEXDeltaPerc_Rank60") <= .48),
        "QCOM": (col("BB_Bandwidth") <= .346) & (col("BullShareChgAbsRank60") <= .65),
        "AAPL": (col("BCShareRank60") >= .65) & (q("TodayChange") > 0),
        "DIA": col("GEX_ZScore") < -1.0,
        "GLD": (col("GEX") > col("GEX_SMA20")) & (col("RSI") > 65),
        "INTC": (col("BPOptionShare") >= .31) & (col("BB_Bandwidth") >= .253),
        "XLE": (q("SafeGEXVolRank60") <= .60) & (col("GEX_ZScore_60day") > 0),
        "PANW": (col("PCRChangePct").abs() >= 10.0) & (q("BB_Bandwidth") >= .07),
        "TLT": (col("PriceDistSMA50Pct") >= -1.0) & (col("SCShareChgRank60") >= .60),
        "TXN": (col("SCShare") >= .0284) & (q("BuyCall_GEXDeltaPerc_Rank60") <= .65) & (col("Gold_chg5") >= -1.0),
        "COHR": (col("SCShareRank60") <= .60) & (col("PX_WholeDayRet") >= -4.0) & (col("PX_RTHRet") >= -2.5),
        "DRAM": (col("GEX_Rank60") >= .30) & (col("TodayChange") >= -3.0),
        "FORM": (col("GEX_SMA5") >= -814.3) & (col("ConcentrationHHI") <= .5445),
        "ZS": (col("BTC_chg5") <= 2.1) & (col("BullShareChgAbsRank60") <= .65),
        "WDC": (col("GEX_Rank60") >= .20) & (q("SafeGEXZ60") > -1.5),
        "HPE": col("SPShareChgRank60") > .37,
        "SOXL": (col("SafeGEXVolRank60") >= .65) & (q("BB_Bandwidth") > .081),
    }
    result = tests[ticker].fillna(False)
    forbidden = {"TomorrowChange", "Next2DaysChange", "Next5DaysChange", "Next10DaysChange", "Next20DaysChange"}
    assert not forbidden.intersection(set(df.columns)), "future target column entered predictor dataframe"
    return result


def metrics(returns: pd.Series) -> dict:
    values = pd.to_numeric(returns, errors="coerce").dropna().to_numpy(dtype=float)
    if not len(values):
        return {"n": 0}
    wins = values[values > 0]
    losses = values[values <= 0]
    gross_loss = abs(float(losses.sum()))
    return {
        "n": int(len(values)), "wins": int(len(wins)), "losses": int(len(losses)),
        "win_rate_pct": float(np.mean(values > 0) * 100), "mean_return_pct": float(np.mean(values)),
        "median_return_pct": float(np.median(values)), "stddev_return_pct": float(np.std(values, ddof=1)) if len(values) > 1 else 0.0,
        "average_winner_pct": float(np.mean(wins)) if len(wins) else None,
        "average_loser_pct": float(np.mean(losses)) if len(losses) else None,
        "largest_winner_pct": float(np.max(values)), "largest_loser_pct": float(np.min(values)),
        "profit_factor": float(wins.sum() / gross_loss) if gross_loss else None,
    }


def run() -> tuple[pd.DataFrame, pd.DataFrame]:
    capital, features, bars = fetch_data()
    daily = add_daily_features(capital, features)
    daily = add_intraday_features(daily, bars)
    daily = add_benchmarks(daily)
    # These are labels, not predictors. Remove them before any trigger evaluation
    # so the leakage assertion cannot be bypassed by an unused selected column.
    forbidden = ["TomorrowChange", "Next2DaysChange", "Next5DaysChange", "Next10DaysChange", "Next20DaysChange"]
    daily = daily.drop(columns=[x for x in forbidden if x in daily.columns])
    all_rows = evaluation_rows(daily, bars, triggered_only=False)
    rows = all_rows[all_rows["triggered"]].copy()
    all_rows.to_csv(OUT / "eligible-outcomes.csv", index=False)
    summaries = []
    for ticker in CANDIDATES:
        part = rows[rows["ticker"] == ticker].sort_values("market_date").copy()
        n = len(part)
        cut1 = int(math.floor(n * .60))
        cut2 = int(math.floor(n * .80))
        splits = [("TRAIN_60", part.iloc[:cut1]), ("RESEARCH_VALIDATION_20", part.iloc[cut1:cut2]), ("FINAL_RESEARCH_TAIL_20", part.iloc[cut2:])]
        summary = {"ticker": ticker, "direction": CANDIDATES[ticker][0], "holding_period": CANDIDATES[ticker][1],
                   "trigger": CANDIDATES[ticker][2], "research_cutoff": str(CUTOFF.date()), "reserved_oos": "2026-09-01 through 2026-10-31",
                   "full": metrics(part["return_pct"]), "splits": {label: metrics(sub["return_pct"]) for label, sub in splits}}
        summaries.append(summary)
    OUT.mkdir(parents=True, exist_ok=True)
    rows.to_csv(OUT / "candidate-ledger.csv", index=False)
    (OUT / "candidate-summary.json").write_text(json.dumps(summaries, indent=2, default=str), encoding="utf-8")
    return rows, pd.DataFrame(summaries)


if __name__ == "__main__":
    ledger, summary = run()
    for row in json.loads((OUT / "candidate-summary.json").read_text()):
        f = row["full"]
        v = row["splits"]["RESEARCH_VALIDATION_20"]
        t = row["splits"]["TRAIN_60"]
        print(row["ticker"], f.get("n", 0), round(f.get("win_rate_pct", 0), 1), round(f.get("mean_return_pct", 0), 2),
              "train", t.get("n", 0), round(t.get("win_rate_pct", 0), 1),
              "val", v.get("n", 0), round(v.get("win_rate_pct", 0), 1))
