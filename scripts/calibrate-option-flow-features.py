"""Build a first, leakage-aware calibration report for OptionFlowFeatures.

This is deliberately a diagnostic/calibration tool, not an execution strategy.
It evaluates expiry outcomes only when the underlying price history contains the
expiry-date close and only uses feature values from the observation date.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import statistics
from collections import defaultdict
from datetime import date, datetime
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

import pyodbc

ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / "backend" / ".env"
DEFAULT_OUTPUT = ROOT / "backend" / "data" / "option_flow_calibration"


def load_env() -> None:
    if not ENV_PATH.exists():
        return
    for line in ENV_PATH.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def connect() -> pyodbc.Connection:
    driver = os.getenv("sqlserver_odbc_driver", os.getenv("SQLSERVER_ODBC_DRIVER", "ODBC Driver 18 for SQL Server"))
    host = os.getenv("SQL_SERVER_HOST", os.getenv("sqlserver_server"))
    port = os.getenv("SQL_SERVER_PORT", os.getenv("sqlserver_port", "1433"))
    user = os.getenv("SQL_SERVER_USER", os.getenv("sqlserver_username"))
    password = os.getenv("SQL_SERVER_PASSWORD", os.getenv("sqlserver_password"))
    if not all((host, user, password)):
        raise RuntimeError("SQL Server connection settings are incomplete")
    cn = pyodbc.connect(
        f"DRIVER={{{driver}}};SERVER={host},{port};DATABASE=StockDB_US;"
        f"UID={user};PWD={password};Encrypt=yes;TrustServerCertificate=yes;",
        timeout=20,
    )
    cn.timeout = 120
    return cn


def as_float(value: Any) -> Optional[float]:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def fetch_rows(cn: pyodbc.Connection, stock_code: str) -> tuple[List[Dict[str, Any]], Dict[date, float]]:
    cur = cn.cursor()
    cur.execute("SELECT * FROM Analysis.OptionFlowFeatures WHERE StockCode = ? ORDER BY ObservationDate, ExpiryDate", stock_code)
    feature_columns = [column[0] for column in cur.description]
    features = [dict(zip(feature_columns, row)) for row in cur.fetchall()]
    cur.execute("SELECT ObservationDate, [Close] FROM StockData.PriceHistory WHERE ASXCode = ? ORDER BY ObservationDate", f"{stock_code}.US")
    prices = {row[0]: float(row[1]) for row in cur.fetchall()}
    cur.close()
    return features, prices


def log_returns(prices: Dict[date, float], start: date, end: date) -> List[float]:
    dates = sorted(d for d in prices if start <= d <= end)
    result: List[float] = []
    for previous, current in zip(dates, dates[1:]):
        if prices[previous] > 0 and prices[current] > 0:
            result.append(math.log(prices[current] / prices[previous]))
    return result


def median_or_none(values: Iterable[float]) -> Optional[float]:
    values = list(values)
    return statistics.median(values) if values else None


def mean_or_none(values: Iterable[float]) -> Optional[float]:
    values = list(values)
    return statistics.mean(values) if values else None


def percentile(values: List[float], q: float) -> Optional[float]:
    if not values:
        return None
    values = sorted(values)
    index = (len(values) - 1) * q
    lower = math.floor(index)
    upper = math.ceil(index)
    if lower == upper:
        return values[lower]
    return values[lower] + (values[upper] - values[lower]) * (index - lower)


def dte_bucket(dte: int) -> str:
    if dte <= 5:
        return "01-05"
    if dte <= 10:
        return "06-10"
    if dte <= 30:
        return "11-30"
    return "31+"


def build_observations(features: List[Dict[str, Any]], prices: Dict[date, float]) -> List[Dict[str, Any]]:
    observations: List[Dict[str, Any]] = []
    for row in features:
        if not row.get("OptionChainAvailable"):
            continue
        observation_date = row["ObservationDate"]
        expiry_date = row["ExpiryDate"]
        if expiry_date not in prices or observation_date >= expiry_date:
            continue
        spot = as_float(row.get("UnderlyingClose"))
        expiry_close = prices.get(expiry_date)
        if not spot or expiry_close is None:
            continue
        dte = int(row["DaysToExpiry"])
        actual_return = expiry_close / spot - 1.0
        implied_move = as_float(row.get("ImpliedMovePct"))
        expected_abs_move = implied_move / 100.0 if implied_move is not None and implied_move > 0 else None
        candidate = as_float(row.get("MaxAbsGammaStrike"))
        forward_returns = log_returns(prices, observation_date, expiry_date)
        realized_vol = statistics.stdev(forward_returns) * math.sqrt(252.0) if len(forward_returns) >= 5 else None
        implied_iv = as_float(row.get("NearATMIV"))
        item = {
            "observation_date": observation_date.isoformat(),
            "expiry_date": expiry_date.isoformat(),
            "dte_bucket": dte_bucket(dte),
            "dte": dte,
            "spot": spot,
            "expiry_close": expiry_close,
            "actual_return_pct": actual_return * 100.0,
            "actual_abs_move_pct": abs(actual_return) * 100.0,
            "implied_move_pct": implied_move,
            "inside_implied_move": expected_abs_move is not None and abs(actual_return) <= expected_abs_move,
            "max_abs_gamma_strike": candidate,
            "pin_distance_pct": abs(expiry_close - candidate) * 100.0 / spot if candidate is not None else None,
            "pin_within_1pct": candidate is not None and abs(expiry_close - candidate) / spot <= 0.01,
            "pin_within_2pct": candidate is not None and abs(expiry_close - candidate) / spot <= 0.02,
            "realized_vol": realized_vol,
            "implied_iv": implied_iv,
            "realized_minus_implied_vol": realized_vol - implied_iv if realized_vol is not None and implied_iv is not None and implied_iv > 0 else None,
            "realized_to_implied_vol_ratio": realized_vol / implied_iv if realized_vol is not None and implied_iv is not None and implied_iv > 0 else None,
            "net_gamma_exposure": as_float(row.get("NetGammaExposure")),
            "gamma_regime": (
                "POSITIVE_GAMMA" if as_float(row.get("NetGammaExposure")) is not None and as_float(row.get("NetGammaExposure")) > 0
                else "NEGATIVE_GAMMA" if as_float(row.get("NetGammaExposure")) is not None and as_float(row.get("NetGammaExposure")) < 0
                else "ZERO_OR_UNKNOWN_GAMMA"
            ),
            "gamma_concentration_pct": as_float(row.get("GammaConcentrationPct")),
            "directional_flow_score": as_float(row.get("DirectionalFlowScore")),
            "flow_quality_score": as_float(row.get("FlowQualityScore")),
            "feature_status": row.get("FeatureStatus"),
        }
        observations.append(item)
    return observations


def summarize_group(group: List[Dict[str, Any]]) -> Dict[str, Any]:
    actual = [x["actual_abs_move_pct"] for x in group]
    implied = [x["implied_move_pct"] for x in group if x["implied_move_pct"] is not None and x["implied_move_pct"] > 0]
    ratios = [x["realized_to_implied_vol_ratio"] for x in group if x["realized_to_implied_vol_ratio"] is not None]
    realized = [x["realized_vol"] for x in group if x["realized_vol"] is not None]
    iv = [x["implied_iv"] for x in group if x["implied_iv"] is not None and x["implied_iv"] > 0]
    pin1 = [x for x in group if x["max_abs_gamma_strike"] is not None]
    return {
        "n": len(group),
        "expiry_inside_implied_move_pct": mean_or_none(100.0 if x["inside_implied_move"] else 0.0 for x in group),
        "median_actual_abs_move_pct": median_or_none(actual),
        "median_implied_move_pct": median_or_none(implied),
        "median_actual_to_implied_move_ratio": median_or_none(
            x["actual_abs_move_pct"] / x["implied_move_pct"] for x in group
            if x["implied_move_pct"] and x["implied_move_pct"] > 0
        ),
        "median_realized_vol": median_or_none(realized),
        "median_implied_iv": median_or_none(iv),
        "median_realized_to_implied_vol_ratio": median_or_none(ratios),
        "realized_vol_exceeded_implied_pct": mean_or_none(
            100.0 if x["realized_to_implied_vol_ratio"] > 1 else 0.0
            for x in group if x["realized_to_implied_vol_ratio"] is not None
        ),
        "pin_within_1pct_pct": mean_or_none(100.0 if x["pin_within_1pct"] else 0.0 for x in pin1),
        "pin_within_2pct_pct": mean_or_none(100.0 if x["pin_within_2pct"] else 0.0 for x in pin1),
        "pin_candidate_coverage": len(pin1) * 100.0 / len(group) if group else None,
    }


def summarize(items: List[Dict[str, Any]]) -> Dict[str, Any]:
    groups: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    groups["ALL"] = items
    for item in items:
        groups[item["dte_bucket"]].append(item)
        groups[item["gamma_regime"]].append(item)
    return {name: summarize_group(group) for name, group in groups.items()}


def summarize_dte_gamma(items: List[Dict[str, Any]]) -> Dict[str, Any]:
    groups: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    bucket_order = ["01-05", "06-10", "11-30", "31+"]
    regime_order = ["POSITIVE_GAMMA", "NEGATIVE_GAMMA", "ZERO_OR_UNKNOWN_GAMMA"]
    for item in items:
        groups[f"{item['dte_bucket']} / {item['gamma_regime']}"].append(item)
    result: Dict[str, Any] = {}
    for bucket in bucket_order:
        for regime in regime_order:
            name = f"{bucket} / {regime}"
            if name in groups:
                result[name] = summarize_group(groups[name])
    return result


def markdown_report(
    stock_code: str,
    observations: List[Dict[str, Any]],
    summary: Dict[str, Any],
    dte_gamma_summary: Dict[str, Any],
) -> str:
    lines = [
        f"# {stock_code} Option-Flow Feature Calibration",
        "",
        "This is a preliminary expiry-outcome calibration. It is descriptive, not a trading recommendation.",
        "Only FULL_CHAIN rows with an exact underlying close on the expiry date are included.",
        "",
        f"- Usable observations: **{len(observations)}**",
        f"- Observation range: **{min((x['observation_date'] for x in observations), default='n/a')}** to **{max((x['observation_date'] for x in observations), default='n/a')}**",
        "- Pin candidate: `MaxAbsGammaStrike`",
        "- Implied move: near-ATM call/put mid sum divided by spot",
        "",
        "## Calibration summary",
        "",
        "| Group | N | Inside implied move | Median actual move | Median implied move | Actual/implied move | Pin within 1% | Realized IV > implied IV |",
        "|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    def fmt_pct(value: Any) -> str:
        return "n/a" if value is None else f"{value:.2f}%"

    def fmt_num(value: Any) -> str:
        return "n/a" if value is None else f"{value:.3f}"

    for name, s in summary.items():
        lines.append(
            f"| {name} | {s['n']} | {fmt_pct(s['expiry_inside_implied_move_pct'])} | "
            f"{fmt_pct(s['median_actual_abs_move_pct'])} | {fmt_pct(s['median_implied_move_pct'])} | "
            f"{fmt_num(s['median_actual_to_implied_move_ratio'])} | {fmt_pct(s['pin_within_1pct_pct'])} | "
            f"{fmt_pct(s['realized_vol_exceeded_implied_pct'])} |"
        )
    lines += [
        "",
        "## DTE × gamma regime",
        "",
        "This cross-tab is the primary diagnostic for deciding whether range and pin behaviour differs by gamma regime.",
        "",
        "| Group | N | Inside implied move | Median actual move | Median implied move | Actual/implied move | Pin within 1% | Realized IV > implied IV |",
        "|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for name, s in dte_gamma_summary.items():
        lines.append(
            f"| {name} | {s['n']} | {fmt_pct(s['expiry_inside_implied_move_pct'])} | "
            f"{fmt_pct(s['median_actual_abs_move_pct'])} | {fmt_pct(s['median_implied_move_pct'])} | "
            f"{fmt_num(s['median_actual_to_implied_move_ratio'])} | {fmt_pct(s['pin_within_1pct_pct'])} | "
            f"{fmt_pct(s['realized_vol_exceeded_implied_pct'])} |"
        )
    lines += [
        "",
        "## Interpretation",
        "",
        "- Use the implied-move coverage as the first test for condor/butterfly range calibration.",
        "- Use realized-to-implied volatility ratio as the first test for long- versus short-volatility selection.",
        "- Treat pin rates as conditional on expiry, DTE, gamma regime, liquidity, and data quality.",
        "- Do not fit production probabilities from this sample alone; it is too short and expiry outcomes overlap.",
    ]
    return "\n".join(lines) + "\n"


def main() -> None:
    load_env()
    parser = argparse.ArgumentParser()
    parser.add_argument("--stock-code", default="QQQ")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    stock_code = args.stock_code.upper().removesuffix(".US")
    cn = connect()
    try:
        features, prices = fetch_rows(cn, stock_code)
    finally:
        cn.close()
    observations = build_observations(features, prices)
    summary = summarize(observations)
    dte_gamma_summary = summarize_dte_gamma(observations)
    output = {
        "stock_code": stock_code,
        "generated_utc": datetime.utcnow().isoformat() + "Z",
        "feature_rows": len(features),
        "usable_observations": len(observations),
        "summary": summary,
        "dte_gamma_summary": dte_gamma_summary,
        "observations": observations,
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    stem = f"{stock_code.lower()}-option-flow-calibration"
    (args.output_dir / f"{stem}.json").write_text(json.dumps(output, indent=2), encoding="utf-8")
    (args.output_dir / f"{stem}.md").write_text(
        markdown_report(stock_code, observations, summary, dte_gamma_summary),
        encoding="utf-8",
    )
    print(json.dumps({
        "feature_rows": len(features),
        "usable_observations": len(observations),
        "dte_gamma_summary": dte_gamma_summary,
    }, indent=2))


if __name__ == "__main__":
    main()
