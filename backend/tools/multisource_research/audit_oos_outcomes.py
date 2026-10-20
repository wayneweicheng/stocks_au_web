"""Independently reconcile the capped OOS event ledger to raw SQL price bars.

Read-only audit; no strategy selection or production writes. Assumes the
PriceHistoryTimeFrame TimeIntervalStart values are New York wall-clock times,
consistent with the current outcome worker's timezone attachment and observed
04:00 premarket rows. The output records this assumption and observed checks.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from datetime import date, datetime, time, timedelta
from pathlib import Path

import pandas as pd
import pyodbc

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_EVENTS = ROOT / "data/strategy_runtime/20261018/oos-backtest-frequency-capped-221-trades.csv"
DEFAULT_OUT = ROOT / "data/strategy_runtime/20261018-b-research"
COLLECTING_SRC = Path("C:/Repo/stocks_collecting/src")
sys.path.insert(0, str(COLLECTING_SRC))
from strategy_runtime.strategies.spx_gex.calendar import USCashCalendar  # noqa: E402


def read_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def connect(env_path: Path):
    values = read_env(env_path)
    required = ("SQL_SERVER_HOST", "SQL_SERVER_USER", "SQL_SERVER_PASSWORD")
    missing = [key for key in required if not values.get(key)]
    if missing:
        raise RuntimeError(f"missing required SQL environment keys: {missing}")
    driver = values.get("SQL_SERVER_ODBC_DRIVER", "ODBC Driver 18 for SQL Server")
    server = values["SQL_SERVER_HOST"]
    if values.get("SQL_SERVER_PORT"):
        server += "," + values["SQL_SERVER_PORT"]
    connection_string = (
        f"DRIVER={{{driver}}};SERVER={server};DATABASE=StockDB_US;"
        f"UID={values['SQL_SERVER_USER']};PWD={values['SQL_SERVER_PASSWORD']};"
        "Encrypt=no;TrustServerCertificate=yes;"
    )
    connection = pyodbc.connect(connection_string, timeout=30)
    connection.timeout = 90
    return connection


def get_date(value) -> date:
    return pd.Timestamp(value).date()


def expected_prices(candidate: dict, bars: list[dict], calendar: USCashCalendar) -> dict:
    market_date = get_date(candidate["MarketDate"])
    horizon = str(candidate["HoldingPeriodCode"] or "").upper()
    if not horizon.startswith("D") or not horizon[1:].isdigit():
        return {"audit_status": "UNSUPPORTED_HORIZON"}
    entry_date = calendar.session_offset(market_date, 1)
    exit_date = calendar.session_offset(market_date, int(horizon[1:]))
    entry_at = datetime.combine(entry_date, time(7, 30))
    close_at = calendar.cash_close(exit_date).replace(tzinfo=None)
    ordered = sorted(bars, key=lambda row: row["TimeIntervalStart"])
    entry_bar = next((row for row in ordered if row["TimeIntervalStart"] >= entry_at and row["TimeIntervalStart"].date() == entry_date), None)
    exit_bar = next((row for row in reversed(ordered) if row["TimeIntervalStart"].date() == exit_date and row["TimeIntervalStart"] < close_at), None)
    if entry_bar is None or exit_bar is None:
        return {
            "audit_status": "MISSING_ENTRY_BAR" if entry_bar is None else "MISSING_EXIT_BAR",
            "expected_entry_date": entry_date.isoformat(),
            "expected_exit_date": exit_date.isoformat(),
        }
    entry = float(entry_bar["Open"])
    exit_price = float(exit_bar["Close"])
    raw = 100.0 * (exit_price / entry - 1.0)
    direction = str(candidate["Direction"]).upper()
    directional = raw if direction == "LONG" else -raw
    return {
        "audit_status": "RECONCILED",
        "expected_entry_date": entry_date.isoformat(),
        "expected_entry_time": entry_bar["TimeIntervalStart"].isoformat(sep=" "),
        "expected_entry_price": entry,
        "expected_exit_date": exit_date.isoformat(),
        "expected_exit_time": exit_bar["TimeIntervalStart"].isoformat(sep=" "),
        "expected_exit_price": exit_price,
        "reconstructed_raw_return_pct": raw,
        "reconstructed_directional_return_pct": directional,
        "entry_timestamp_exact_0730": entry_bar["TimeIntervalStart"].time() == time(7, 30),
        "exit_timestamp": exit_bar["TimeIntervalStart"].isoformat(sep=" "),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--events", type=Path, default=DEFAULT_EVENTS)
    parser.add_argument("--env-file", type=Path, default=ROOT / ".env")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    events = pd.read_csv(args.events)
    events["MarketDate"] = pd.to_datetime(events["MarketDate"])
    if "ticker" not in events:
        events["ticker"] = events["StrategyCode"].astype(str).str.extract(r"GEX_(.*?)_AUGUST_2026_BEST")[0]
    events["ticker"] = events["ticker"].astype(str).str.strip()
    if "outcome_status" in events:
        finalized = events[events.outcome_status == "FINALIZED"].copy()
    else:
        finalized = events[events.FinalizedUtc.notna()].copy()
    if finalized.empty:
        raise RuntimeError("no finalized events in supplied event ledger")

    grouped: dict[str, list[dict]] = defaultdict(list)
    for row in finalized.to_dict("records"):
        symbol = row["ticker"]
        if not symbol.upper().endswith(".US"):
            symbol += ".US"
        row["_sql_symbol"] = symbol
        grouped[symbol].append(row)

    calendar = USCashCalendar()
    raw_bars: dict[str, list[dict]] = {}
    nq_bars: list[dict] = []
    connection = connect(args.env_file)
    try:
        cursor = connection.cursor()
        cursor.execute("SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED")
        for symbol, rows in sorted(grouped.items()):
            first = min(get_date(row["MarketDate"]) for row in rows) - timedelta(days=2)
            last = max(get_date(row["MarketDate"]) for row in rows) + timedelta(days=14)
            cursor.execute(
                """SELECT TimeIntervalStart, [Open], [High], [Low], [Close], ObservationDate
                   FROM StockDB_US.StockData.PriceHistoryTimeFrame WITH (NOLOCK)
                   WHERE ASXCode=? AND TimeFrame='30M'
                     AND TimeIntervalStart>=? AND TimeIntervalStart<?
                   ORDER BY TimeIntervalStart""",
                (symbol, datetime.combine(first, time(0)), datetime.combine(last, time(0))),
            )
            columns = [item[0] for item in cursor.description]
            raw_bars[symbol] = [dict(zip(columns, row)) for row in cursor.fetchall()]
        first = min(get_date(row["MarketDate"]) for row in finalized.to_dict("records")) - timedelta(days=2)
        last = max(get_date(row["MarketDate"]) for row in finalized.to_dict("records")) + timedelta(days=14)
        cursor.execute(
            """SELECT TimeIntervalStart, [Open], [High], [Low], [Close], ObservationDate
               FROM StockDB_US.StockData.PriceHistoryTimeFrame WITH (NOLOCK)
               WHERE ASXCode='NQMAIN.US' AND TimeFrame='30M'
                 AND TimeIntervalStart>=? AND TimeIntervalStart<?
               ORDER BY TimeIntervalStart""",
            (datetime.combine(first, time(0)), datetime.combine(last, time(0))),
        )
        columns = [item[0] for item in cursor.description]
        nq_bars = [dict(zip(columns, row)) for row in cursor.fetchall()]
        cursor.close()
    finally:
        connection.close()

    audited = []
    for symbol, rows in grouped.items():
        bars = raw_bars.get(symbol, [])
        for row in rows:
            details = expected_prices(row, bars, calendar)
            result = {key: value for key, value in row.items() if not key.startswith("_")}
            result.update({key: value for key, value in details.items()})
            reported_raw = pd.to_numeric(row.get("RawReturnPct"), errors="coerce")
            reported_directional = pd.to_numeric(row.get("DirectionalReturnPct"), errors="coerce")
            result["reported_raw_return_pct"] = None if pd.isna(reported_raw) else float(reported_raw)
            result["reported_directional_return_pct"] = None if pd.isna(reported_directional) else float(reported_directional)
            nq_details = expected_prices(row, nq_bars, calendar)
            result["nqmain_reconstructed_raw_return_pct"] = nq_details.get("reconstructed_raw_return_pct")
            result["nqmain_reconstructed_directional_return_pct"] = nq_details.get("reconstructed_directional_return_pct")
            result["nqmain_return_match_within_0_0001pp"] = bool(
                nq_details.get("audit_status") == "RECONCILED"
                and pd.notna(reported_raw)
                and abs(float(nq_details["reconstructed_raw_return_pct"]) - float(reported_raw)) <= 0.0001
            )
            if details.get("audit_status") == "RECONCILED":
                result["raw_return_abs_difference_pct_points"] = abs(float(details["reconstructed_raw_return_pct"]) - float(reported_raw)) if pd.notna(reported_raw) else None
                result["directional_abs_difference_pct_points"] = abs(float(details["reconstructed_directional_return_pct"]) - float(reported_directional)) if pd.notna(reported_directional) else None
                result["raw_match_within_0_0001pp"] = bool(result["raw_return_abs_difference_pct_points"] is not None and result["raw_return_abs_difference_pct_points"] <= 0.0001)
                result["direction_match_within_0_0001pp"] = bool(result["directional_abs_difference_pct_points"] is not None and result["directional_abs_difference_pct_points"] <= 0.0001)
            audited.append(result)

    audit = pd.DataFrame(audited)
    audit_path = args.output_dir / "reconciled-events.csv"
    audit.to_csv(audit_path, index=False)
    reconciled = audit[audit.audit_status == "RECONCILED"]
    mismatches = reconciled[~reconciled.raw_match_within_0_0001pp | ~reconciled.direction_match_within_0_0001pp]
    metadata = {
        "events_file": str(args.events),
        "total_events_in_input": int(len(events)),
        "finalized_events_audited": int(len(finalized)),
        "symbol_count": int(finalized.ticker.nunique()),
        "raw_symbols_fetched": len(raw_bars),
        "raw_bar_count": int(sum(len(rows) for rows in raw_bars.values())),
        "nqmain_bar_count": len(nq_bars),
        "reported_returns_matching_nqmain_within_0_0001pp": int(audit.nqmain_return_match_within_0_0001pp.sum()),
        "audit_status_counts": audit.audit_status.value_counts(dropna=False).to_dict(),
        "raw_return_matches_within_0_0001pp": int(reconciled.raw_match_within_0_0001pp.sum()) if len(reconciled) else 0,
        "direction_matches_within_0_0001pp": int(reconciled.direction_match_within_0_0001pp.sum()) if len(reconciled) else 0,
        "mismatch_count": int(len(mismatches)),
        "time_interpretation": "PriceHistoryTimeFrame.TimeIntervalStart treated as America/New_York wall time, consistent with StockDB values showing 04:00 premarket and existing runtime attaching USCashCalendar.timezone to naive timestamps. This was verified against raw bar timestamps, but SQL schema itself has no timezone metadata.",
        "entry_policy": "first same-session bar whose local TimeIntervalStart is >= 07:30 ET; expected exact 07:30 bar",
        "exit_policy": "last same-session bar before XNYS scheduled cash close; regular-day 15:30 bar expected",
        "sql_mode": "read-only SELECT with READ UNCOMMITTED/NOLOCK; no database writes",
    }
    (args.output_dir / "outcome-audit-metadata.json").write_text(json.dumps(metadata, indent=2, default=str) + "\n", encoding="utf-8")
    print(json.dumps(metadata, indent=2, default=str))
    print("Audit CSV:", audit_path)
    return 2 if len(mismatches) else 0


if __name__ == "__main__":
    raise SystemExit(main())
