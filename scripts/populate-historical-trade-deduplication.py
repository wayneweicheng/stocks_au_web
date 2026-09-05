"""Persist overlap groups for Strategy Admin historical trade detail.

The grouping is transitive: if A overlaps B and B overlaps C, all three
receive the same persisted DeduplicationGroupID.
"""
from __future__ import annotations

import hashlib
import json
import uuid
from datetime import date
from pathlib import Path
from typing import Any

import pyodbc


ROOT = Path(__file__).resolve().parents[1]
ENV = ROOT / "backend" / ".env"


def env_values() -> dict[str, str]:
    values: dict[str, str] = {}
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip('"')
    return values


def fingerprint(record: dict[str, Any]) -> str:
    payload = json.dumps(record, sort_keys=True, separators=(",", ":"), default=str)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def date_part(value: Any) -> date | None:
    if value is None or str(value).strip() == "":
        return None
    text = str(value).strip()
    try:
        return date.fromisoformat(text[:10])
    except ValueError:
        return None


def records_for_version(configuration: dict[str, Any]) -> list[dict[str, Any]]:
    ledger = configuration.get("historical_trade_ledger") or configuration.get("per_instance_ledger")
    if not isinstance(ledger, dict):
        return []
    records = ledger.get("records")
    return [record for record in records if isinstance(record, dict)] if isinstance(records, list) else []


def build_groups(version_id: int, records: list[dict[str, Any]]) -> list[tuple[int, str, str, date | None, date | None, str]]:
    prepared: list[dict[str, Any]] = []
    for record in records:
        signal = str(record.get("signal_code") or "").strip().upper()
        entry = date_part(record.get("entry_timestamp") or record.get("entry_time") or record.get("market_date"))
        exit_date = date_part(record.get("exit_timestamp") or record.get("exit_time")) or entry
        if exit_date is not None and entry is not None and exit_date < entry:
            entry, exit_date = exit_date, entry
        prepared.append({
            "fingerprint": fingerprint(record),
            "signal": signal,
            "entry": entry,
            "exit": exit_date,
        })

    result: list[tuple[int, str, str, date | None, date | None, str]] = []
    for signal in sorted({item["signal"] for item in prepared}):
        intervals = sorted(
            (item for item in prepared if item["signal"] == signal),
            key=lambda item: (item["entry"] or date.min, item["exit"] or date.min, item["fingerprint"]),
        )
        group_number = 0
        group_end: date | None = None
        group_start: date | None = None
        group_id: str | None = None
        for item in intervals:
            entry = item["entry"]
            exit_date = item["exit"] or entry
            starts_new_group = group_end is None or (entry is not None and entry > group_end)
            if starts_new_group:
                group_number += 1
                group_start = entry
                group_end = exit_date
                group_id = str(uuid.uuid5(
                    uuid.NAMESPACE_URL,
                    f"historical-trade-group:{version_id}:{signal}:{group_number}:{group_start}:{group_end}",
                ))
            elif exit_date is not None and (group_end is None or exit_date > group_end):
                group_end = exit_date
            assert group_id is not None
            result.append((version_id, item["fingerprint"], signal, entry, exit_date, group_id))
    return result


def main() -> None:
    values = env_values()
    connection_string = (
        "DRIVER={ODBC Driver 18 for SQL Server};"
        f"SERVER={values['SQL_SERVER_HOST']},{values['SQL_SERVER_PORT']};"
        "DATABASE=StockDB_US;"
        f"UID={values['SQL_SERVER_USER']};PWD={values['SQL_SERVER_PASSWORD']};"
        "Encrypt=yes;TrustServerCertificate=yes;"
    )
    connection = pyodbc.connect(connection_string, timeout=15)
    connection.timeout = 120
    cursor = connection.cursor()
    cursor.execute("""
        SELECT StrategyVersionID, ConfigurationJson
        FROM [TradingSignal].[StrategyVersion]
        WHERE ConfigurationJson IS NOT NULL
    """)
    versions = cursor.fetchall()
    inserted = 0
    for version_id, configuration_json in versions:
        try:
            configuration = json.loads(configuration_json)
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        rows = build_groups(int(version_id), records_for_version(configuration))
        for row in rows:
            cursor.execute("""
                MERGE [TradingSignal].[HistoricalTradeDeduplication] AS target
                USING (VALUES (?, ?, ?, ?, ?, ?)) AS source
                       (StrategyVersionID, TradeFingerprint, SignalCode, EntryDate, ExitDate, DeduplicationGroupID)
                   ON target.StrategyVersionID = source.StrategyVersionID
                  AND target.TradeFingerprint = source.TradeFingerprint
                WHEN NOT MATCHED THEN
                    INSERT (StrategyVersionID, TradeFingerprint, SignalCode, EntryDate, ExitDate, DeduplicationGroupID)
                    VALUES (source.StrategyVersionID, source.TradeFingerprint, source.SignalCode,
                            source.EntryDate, source.ExitDate, source.DeduplicationGroupID);
            """, row)
            inserted += cursor.rowcount if cursor.rowcount > 0 else 0
    connection.commit()
    cursor.execute("SELECT COUNT(*) FROM [TradingSignal].[HistoricalTradeDeduplication]")
    print(f"rows inserted: {inserted}; total persisted mappings: {cursor.fetchone()[0]}")
    connection.close()


if __name__ == "__main__":
    main()
