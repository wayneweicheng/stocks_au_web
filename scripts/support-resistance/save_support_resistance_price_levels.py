#!/usr/bin/env python3
"""Fetch support/resistance levels from the API and persist one map snapshot.

Examples:
    venv\\Scripts\\python.exe scripts\\support-resistance\\save_support_resistance_price_levels.py QQQ
    venv\\Scripts\\python.exe scripts\\support-resistance\\save_support_resistance_price_levels.py ALL

The API calculation is intentionally performed through the same endpoint used by
``/support-resistance``.  Database writes are made directly to StockDB_US so the
header and child rows can be committed as one transaction.
"""

from __future__ import annotations

import argparse
import base64
import json
import math
import os
import sys
from datetime import date, datetime, timezone
from getpass import getpass
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "backend"
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))

from dotenv import load_dotenv  # noqa: E402

load_dotenv(BACKEND / ".env")

from app.core.db import get_db_connection  # noqa: E402


LOOKBACK_DAYS = 10
MINIMUM_DISTANCE_ATR = 0.00
MAXIMUM_DISTANCE_ATR = 3.00
MAX_LEVELS = 5
METHOD_VERSION = "support-resistance-api-v1"
SOURCE_SYSTEM = "support-resistance-api"
DEFAULT_API_PATH = "/api/support-resistance"


def _default_api_url() -> str:
    configured = os.getenv("SUPPORT_RESISTANCE_API_URL", "").strip()
    if configured:
        return configured
    backend_url = os.getenv("NEXT_PUBLIC_BACKEND_URL", "").strip().rstrip("/")
    if backend_url:
        return f"{backend_url}{DEFAULT_API_PATH}"
    return f"http://127.0.0.1:3101{DEFAULT_API_PATH}"


def _number(value: Any, field_name: str) -> float:
    try:
        result = float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"API returned a non-numeric {field_name}: {value!r}") from exc
    if not math.isfinite(result):
        raise ValueError(f"API returned a non-finite {field_name}")
    return result


def _as_utc_naive(value: Any) -> datetime | None:
    """Convert an API ISO timestamp to a DATETIME2-compatible UTC value."""
    if not value:
        return None
    parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    if parsed.tzinfo is not None:
        parsed = parsed.astimezone(timezone.utc).replace(tzinfo=None)
    # The source API returns SQL timestamps without an offset.  They are stored
    # as UTC in the database and are therefore already suitable for DATETIME2.
    return parsed.replace(microsecond=(parsed.microsecond // 1000) * 1000)


def _canonical_stock_code(input_code: str, stock: dict[str, Any]) -> str:
    code = str(stock.get("stock_code") or input_code).strip().upper()
    if code.endswith(".US"):
        code = code[:-3]
    if not code or len(code) > 32:
        raise ValueError(f"Invalid stock code returned by API: {code!r}")
    return code


def fetch_support_resistance(
    stock_code: str,
    api_url: str,
    username: str,
    password: str,
    timeout: int,
) -> dict[str, Any]:
    params = {
        "stock_code": stock_code,
        "lookback_days": str(LOOKBACK_DAYS),
        "minimum_distance_atr": f"{MINIMUM_DISTANCE_ATR:.2f}",
        "maximum_distance_atr": f"{MAXIMUM_DISTANCE_ATR:.2f}",
        "max_levels": str(MAX_LEVELS),
        "enable_live_prices": "true",
    }
    url = f"{api_url.rstrip('?&')}{'&' if '?' in api_url else '?'}{urlencode(params)}"
    token = base64.b64encode(f"{username}:{password}".encode("utf-8")).decode("ascii")
    request = Request(
        url,
        headers={"Accept": "application/json", "Authorization": f"Basic {token}"},
        method="GET",
    )
    try:
        with urlopen(request, timeout=timeout) as response:
            body = response.read().decode("utf-8")
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Support/resistance API returned HTTP {exc.code}: {detail[:500]}") from exc
    except URLError as exc:
        raise RuntimeError(f"Could not reach support/resistance API at {api_url}: {exc.reason}") from exc

    try:
        result = json.loads(body)
    except json.JSONDecodeError as exc:
        raise RuntimeError("Support/resistance API returned invalid JSON") from exc
    if not isinstance(result, dict):
        raise RuntimeError("Support/resistance API returned an unexpected JSON shape")
    return result


def build_snapshot(
    input_code: str,
    response: dict[str, Any],
    generated_at_utc: datetime,
) -> tuple[str, date, datetime | None, str, list[dict[str, Any]]]:
    stock = response.get("stock")
    if not isinstance(stock, dict):
        raise ValueError("Support/resistance API response did not contain stock data")

    asx_code = _canonical_stock_code(input_code, stock)
    observation_value = response.get("observation_date")
    try:
        observation_date = date.fromisoformat(str(observation_value)[:10])
    except (TypeError, ValueError) as exc:
        raise ValueError(f"Invalid observation_date returned by API: {observation_value!r}") from exc

    as_of = _as_utc_naive(stock.get("latest_bar_time"))
    if as_of is None:
        as_of = _as_utc_naive(response.get("observation_datetime"))

    zones: list[dict[str, Any]] = []
    for side, key in (("support", "supports"), ("resistance", "resistances")):
        raw_levels = stock.get(key) or []
        if not isinstance(raw_levels, list):
            raise ValueError(f"API field stock.{key} was not an array")
        for raw_level in raw_levels:
            if not isinstance(raw_level, dict):
                raise ValueError(f"API field stock.{key} contained a non-object zone")
            low = _number(raw_level.get("range_low"), f"{side}.range_low")
            high = _number(raw_level.get("range_high"), f"{side}.range_high")
            if low <= 0 or high < low:
                raise ValueError(f"Invalid {side} range returned by API: {low}..{high}")

            # Keep the API zone intact in JSON while adding explicit fields used
            # by the relational child table.
            zone = dict(raw_level)
            zone["side"] = side
            zone["range_low"] = low
            zone["range_high"] = high
            zone["level_type"] = side
            zone["polarity"] = side
            zones.append(zone)

    map_payload = {
        "schema_version": 1,
        "stock_code": asx_code,
        "database_code": stock.get("database_code"),
        "observation_date": observation_date.isoformat(),
        "map_generated_at_utc": generated_at_utc.isoformat(timespec="milliseconds") + "Z",
        "map_as_of_at_utc": as_of.isoformat(timespec="milliseconds") + "Z" if as_of else None,
        "method_version": METHOD_VERSION,
        "source_system": SOURCE_SYSTEM,
        "parameters": {
            "lookback_days": LOOKBACK_DAYS,
            "minimum_distance_atr": MINIMUM_DISTANCE_ATR,
            "maximum_distance_atr": MAXIMUM_DISTANCE_ATR,
            "max_levels": MAX_LEVELS,
        },
        "reference_price": stock.get("reference_price"),
        "latest_close": stock.get("latest_close"),
        "zones": zones,
    }
    map_json = json.dumps(map_payload, ensure_ascii=False, allow_nan=False, separators=(",", ":"))
    return asx_code, observation_date, as_of, map_json, zones


def save_snapshot(
    asx_code: str,
    observation_date: date,
    map_as_of_at_utc: datetime | None,
    map_generated_at_utc: datetime,
    map_json: str,
    zones: list[dict[str, Any]],
) -> tuple[int, int]:
    """Replace this stock's snapshot in the current UTC clock-hour atomically."""
    # A transaction-scoped application lock prevents two simultaneous runs for
    # one stock from both passing the delete/insert sequence.
    lock_resource = f"StockData.PriceLevelMap:{asx_code}"
    connection = get_db_connection("StockDB_US")
    # Use an explicit SQL transaction.  With pyodbc's implicit transaction
    # mode, BEGIN TRANSACTION can become nested and connection.commit() would
    # leave the outer transaction open until connection.close() rolls it back.
    connection.autocommit = True
    cursor = connection.cursor()
    try:
        cursor.execute("SET XACT_ABORT ON; BEGIN TRANSACTION;")
        cursor.execute(
            """
            DECLARE @LockResult int;
            EXEC @LockResult = sys.sp_getapplock
                @Resource = ?,
                @LockMode = 'Exclusive',
                @LockOwner = 'Transaction',
                @LockTimeout = 60000;
            IF @LockResult < 0
                THROW 51000, 'Could not acquire the price-level map lock.', 1;
            """,
            (lock_resource,),
        )
        cursor.execute(
            """
            DECLARE @GeneratedAtUtc datetime2(3) = ?;
            DECLARE @HourStart datetime2(3) = DATEADD(
                hour,
                DATEDIFF(hour, CONVERT(datetime2(3), '19000101'), @GeneratedAtUtc),
                CONVERT(datetime2(3), '19000101')
            );
            DECLARE @HourEnd datetime2(3) = DATEADD(hour, 1, @HourStart);

            DELETE child
            FROM StockData.PriceLevelMapLevel AS child
            INNER JOIN StockData.PriceLevelMap AS parent
                ON parent.PriceLevelMapId = child.PriceLevelMapId
            WHERE parent.ASXCode = ?
              AND parent.MapGeneratedAtUtc >= @HourStart
              AND parent.MapGeneratedAtUtc < @HourEnd;

            DELETE FROM StockData.PriceLevelMap
            WHERE ASXCode = ?
              AND MapGeneratedAtUtc >= @HourStart
              AND MapGeneratedAtUtc < @HourEnd;
            """,
            (map_generated_at_utc, asx_code, asx_code),
        )
        cursor.execute(
            """
            INSERT INTO StockData.PriceLevelMap
            (
                ASXCode, ObservationDate, MapGeneratedAtUtc, MapAsOfAtUtc,
                MethodVersion, SourceSystem, MapJson
            )
            OUTPUT INSERTED.PriceLevelMapId
            VALUES (?, ?, ?, ?, ?, ?, ?);
            """,
            (
                asx_code,
                observation_date,
                map_generated_at_utc,
                map_as_of_at_utc,
                METHOD_VERSION,
                SOURCE_SYSTEM,
                map_json,
            ),
        )
        map_id = int(cursor.fetchone()[0])

        if zones:
            child_rows = []
            for ordinal, zone in enumerate(zones, start=1):
                child_rows.append(
                    (
                        map_id,
                        ordinal,
                        zone["range_low"],
                        zone["range_high"],
                        str(zone["level_type"]),
                        str(zone["polarity"]),
                        f"zones[{ordinal - 1}]",
                        json.dumps(zone, ensure_ascii=False, allow_nan=False, separators=(",", ":")),
                    )
                )
            cursor.executemany(
                """
                INSERT INTO StockData.PriceLevelMapLevel
                (
                    PriceLevelMapId, LevelOrdinal, LevelLow, LevelHigh,
                    LevelType, Polarity, SourceJsonPath, LevelJson
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?);
                """,
                child_rows,
            )

        cursor.execute("COMMIT TRANSACTION;")
        return map_id, len(zones)
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()
        connection.close()


def get_stock_codes_to_check() -> list[str]:
    """Return the distinct stock codes configured by the database view."""
    connection = get_db_connection("StockDB_US")
    try:
        cursor = connection.cursor()
        try:
            cursor.execute(
                """
                SELECT DISTINCT ASXCode
                FROM LookupRef.v_StockToCheck
                WHERE ASXCode IS NOT NULL
                  AND LTRIM(RTRIM(ASXCode)) <> ''
                  AND UPPER(LTRIM(RTRIM(ASXCode))) NOT IN
                      ('_SPX.US', 'ESMAIN', 'ESMAIN.US', 'NQMAIN', 'NQMAIN.US')
                ORDER BY ASXCode;
                """
            )
            return [str(row[0]).strip().upper() for row in cursor.fetchall()]
        finally:
            cursor.close()
    except Exception as exc:
        raise RuntimeError("Could not read stocks from LookupRef.v_StockToCheck") from exc
    finally:
        connection.close()


def save_one_stock(
    input_code: str,
    api_url: str,
    username: str,
    password: str,
    timeout: int,
) -> tuple[int, int, str]:
    generated_at_utc = datetime.now(timezone.utc).replace(tzinfo=None)
    generated_at_utc = generated_at_utc.replace(
        microsecond=(generated_at_utc.microsecond // 1000) * 1000
    )
    response = fetch_support_resistance(
        input_code,
        api_url,
        username,
        password,
        timeout,
    )
    asx_code, observation_date, as_of, map_json, zones = build_snapshot(
        input_code,
        response,
        generated_at_utc,
    )
    map_id, zone_count = save_snapshot(
        asx_code,
        observation_date,
        as_of,
        generated_at_utc,
        map_json,
        zones,
    )
    return map_id, zone_count, asx_code


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "stock_code",
        help="US stock/ETF symbol, for example QQQ, or ALL for LookupRef.v_StockToCheck",
    )
    parser.add_argument("--api-url", default=_default_api_url(), help="Support/resistance API URL")
    parser.add_argument("--username", default=os.getenv("ADMIN_USERNAME"), help="API basic-auth username")
    parser.add_argument("--password", default=os.getenv("ADMIN_PASSWORD"), help="API basic-auth password")
    parser.add_argument("--timeout", type=int, default=90, help="API timeout in seconds")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    input_code = args.stock_code.strip().upper()
    if not input_code:
        raise SystemExit("stock_code cannot be empty")
    username = args.username or input("API username: ")
    password = args.password or getpass("API password: ")

    if input_code != "ALL":
        map_id, zone_count, asx_code = save_one_stock(
            input_code, args.api_url, username, password, args.timeout
        )
        print(f"Saved PriceLevelMapId={map_id} ASXCode={asx_code} zones={zone_count}")
        return 0

    stock_codes = get_stock_codes_to_check()
    if not stock_codes:
        print("No stocks found in LookupRef.v_StockToCheck", file=sys.stderr)
        return 1

    succeeded = 0
    failures: list[tuple[str, str]] = []
    print(f"Processing {len(stock_codes)} stocks from LookupRef.v_StockToCheck")
    for position, stock_code in enumerate(stock_codes, start=1):
        print(f"[{position}/{len(stock_codes)}] {stock_code}")
        try:
            map_id, zone_count, asx_code = save_one_stock(
                stock_code, args.api_url, username, password, args.timeout
            )
            succeeded += 1
            print(f"  saved PriceLevelMapId={map_id} ASXCode={asx_code} zones={zone_count}")
        except Exception as exc:
            failures.append((stock_code, str(exc)))
            print(f"  FAILED: {exc}", file=sys.stderr)

    print(f"Completed ALL: succeeded={succeeded} failed={len(failures)}")
    if failures:
        print("Failed stocks:", file=sys.stderr)
        for stock_code, error in failures:
            print(f"  {stock_code}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
