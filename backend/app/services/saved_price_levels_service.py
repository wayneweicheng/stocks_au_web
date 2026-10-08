from __future__ import annotations

import json
import logging
from datetime import date, datetime, timedelta
from typing import Any, Dict, List, Optional

from app.core.config import settings
from app.core.db import get_timed_sql_model

logger = logging.getLogger("app.saved_price_levels")


class SavedPriceLevelsDatabaseError(RuntimeError):
    """Raised when saved support/resistance levels cannot be loaded."""


def _open_saved_price_levels_model():
    try:
        return get_timed_sql_model(
            database="StockDB_US",
            connection_timeout=settings.support_resistance_db_connection_timeout,
            query_timeout=settings.support_resistance_db_query_timeout,
        )
    except Exception as exc:
        raise SavedPriceLevelsDatabaseError(
            "Unable to connect to the saved support/resistance database"
        ) from exc


def _close_saved_price_levels_model(model) -> None:
    try:
        model.close()
    except Exception:
        logger.warning("Failed to close saved price-level database connection", exc_info=True)


def _execute_saved_price_levels_query(model, query: str, values: tuple[Any, ...]):
    try:
        return model.execute_read_query(query, values) or []
    except Exception as exc:
        logger.warning("Saved support/resistance query failed: %s", exc)
        raise SavedPriceLevelsDatabaseError(
            "Saved support/resistance data could not be loaded"
        ) from exc


def _stock_code_aliases(stock_code: str) -> List[str]:
    code = (stock_code or "").strip().upper()
    if not code:
        return []
    base_code = code[:-3] if code.endswith(".US") else code
    return list(dict.fromkeys((code, base_code, f"{base_code}.US")))


def _iso(value: Any) -> Optional[str]:
    if value is None:
        return None
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return str(value)


def _float(value: Any) -> Optional[float]:
    try:
        return None if value is None else float(value)
    except (TypeError, ValueError):
        return None


def _int(value: Any, default: int = 0) -> int:
    try:
        return int(value) if value is not None else default
    except (TypeError, ValueError):
        return default


def _read_json(value: Any) -> Dict[str, Any]:
    if not value:
        return {}
    try:
        parsed = json.loads(value) if isinstance(value, str) else value
        return parsed if isinstance(parsed, dict) else {}
    except (TypeError, ValueError, json.JSONDecodeError):
        return {}


def _format_level(row: Dict[str, Any]) -> Dict[str, Any]:
    """Return the same level shape as the live support/resistance endpoint."""
    source = _read_json(row.get("LevelJson"))
    low = _float(row.get("LevelLow"))
    high = _float(row.get("LevelHigh"))
    center = _float(row.get("LevelCenter"))
    side = str(
        source.get("side")
        or source.get("level_type")
        or row.get("LevelType")
        or row.get("Polarity")
        or ""
    ).lower()
    sources = source.get("sources")
    if not isinstance(sources, list):
        sources = ["30m"]

    level = {
        "price": _float(source.get("price")) or center,
        "range_low": _float(source.get("range_low")) or low,
        "range_high": _float(source.get("range_high")) or high,
        "touches": _int(source.get("touches")),
        "distance_pct": _float(source.get("distance_pct")) or 0.0,
        "distance_atr": _float(source.get("distance_atr")) or 0.0,
        "strength_rank": _int(source.get("strength_rank"), _int(row.get("LevelOrdinal"))),
        "latest_touch": source.get("latest_touch"),
        "sources": [str(item) for item in sources],
        "gamma_wall": source.get("gamma_wall"),
        "side": side,
    }
    return level


def _get_recorded_hours_with_model(
    stock_code: str,
    model=None,
) -> List[str]:
    aliases = _stock_code_aliases(stock_code)
    if not aliases:
        raise ValueError("stock_code is required")
    placeholders = ", ".join("?" for _ in aliases)
    rows = _execute_saved_price_levels_query(
        model,
        """
        WITH RecordedHours AS
        (
            SELECT DISTINCT
                DATEADD(
                    hour,
                    DATEDIFF(hour, CONVERT(datetime2, '19000101'), p.MapGeneratedAtUtc),
                    CONVERT(datetime2, '19000101')
                ) AS RecordedHourUtc
            FROM StockData.PriceLevelMap AS p WITH (NOLOCK)
            WHERE UPPER(LTRIM(RTRIM(p.ASXCode))) IN ({placeholders})
              AND EXISTS
              (
                  SELECT 1
                  FROM StockData.PriceLevelMapLevel AS l WITH (NOLOCK)
                  WHERE l.PriceLevelMapId = p.PriceLevelMapId
                    AND LOWER(COALESCE(l.LevelType, l.Polarity, '')) IN ('support', 'resistance')
              )
        )
        SELECT RecordedHourUtc
        FROM RecordedHours
        ORDER BY RecordedHourUtc DESC;
        """.format(placeholders=placeholders),
        tuple(aliases),
    )
    return [
        value
        for row in rows
        if (value := _iso(row.get("RecordedHourUtc"))) is not None
    ]


def get_recorded_support_resistance_hours(stock_code: str) -> List[str]:
    model = _open_saved_price_levels_model()
    try:
        return _get_recorded_hours_with_model(stock_code, model=model)
    finally:
        _close_saved_price_levels_model(model)


def _empty_result(stock_code: str, observation_datetime: Optional[datetime]) -> Dict[str, Any]:
    code = (stock_code or "").strip().upper()
    if code.endswith(".US"):
        code = code[:-3]
    return {
        "stock_code": code,
        "requested_stock_code": (stock_code or "").strip().upper(),
        "found": False,
        "as_at": observation_datetime.isoformat() if observation_datetime else None,
        "matched_hour_utc": None,
        "map_generated_at_utc": None,
        "map_as_of_at_utc": None,
        "observation_date": None,
        "bars": [],
        "stock": {
            "stock_code": code,
            "database_code": None,
            "latest_close": None,
            "reference_price": None,
            "supports": [],
            "resistances": [],
        },
    }


def _get_saved_support_resistance_with_model(
    stock_code: str,
    observation_datetime: Optional[datetime] = None,
    model=None,
) -> Dict[str, Any]:
    aliases = _stock_code_aliases(stock_code)
    if not aliases:
        raise ValueError("stock_code is required")

    placeholders = ", ".join("?" for _ in aliases)
    if observation_datetime is None:
        cte = """
        WITH CandidateMap AS
        (
            SELECT TOP (1)
                p.PriceLevelMapId, p.ASXCode, p.ObservationDate,
                p.MapGeneratedAtUtc, p.MapAsOfAtUtc, p.MethodVersion,
                p.SourceSystem, p.MapJson
            FROM StockData.PriceLevelMap AS p WITH (NOLOCK)
            WHERE UPPER(LTRIM(RTRIM(p.ASXCode))) IN ({placeholders})
            ORDER BY p.MapGeneratedAtUtc DESC, p.PriceLevelMapId DESC
        )
        """.format(placeholders=placeholders)
        values: tuple[Any, ...] = tuple(aliases)
    else:
        # MapGeneratedAtUtc is stored as UTC.  The entered as-at timestamp is
        # deliberately mapped to the database clock hour, with no nearest-hour
        # fallback, so an absent recorded hour is reported as no data.
        cte = """
        WITH RequestedHour AS
        (
            SELECT DATEADD(
                hour,
                DATEDIFF(hour, CONVERT(datetime2, '19000101'), CONVERT(datetime2, ?)),
                CONVERT(datetime2, '19000101')
            ) AS HourStart
        ),
        CandidateMap AS
        (
            SELECT TOP (1)
                p.PriceLevelMapId, p.ASXCode, p.ObservationDate,
                p.MapGeneratedAtUtc, p.MapAsOfAtUtc, p.MethodVersion,
                p.SourceSystem, p.MapJson
            FROM StockData.PriceLevelMap AS p WITH (NOLOCK)
            CROSS JOIN RequestedHour AS h
            WHERE UPPER(LTRIM(RTRIM(p.ASXCode))) IN ({placeholders})
              AND p.MapGeneratedAtUtc >= h.HourStart
              AND p.MapGeneratedAtUtc < DATEADD(hour, 1, h.HourStart)
            ORDER BY p.MapGeneratedAtUtc DESC, p.PriceLevelMapId DESC
        )
        """.format(placeholders=placeholders)
        values = (observation_datetime, *aliases)

    rows = _execute_saved_price_levels_query(
        model,
        cte
        + """
        SELECT
            m.PriceLevelMapId, m.ASXCode, m.ObservationDate,
            m.MapGeneratedAtUtc, m.MapAsOfAtUtc, m.MethodVersion,
            m.SourceSystem, m.MapJson,
            l.PriceLevelMapLevelId, l.LevelOrdinal, l.LevelLow, l.LevelHigh,
            l.LevelCenter, l.LevelType, l.Polarity, l.LevelJson
        FROM CandidateMap AS m
        LEFT JOIN StockData.PriceLevelMapLevel AS l WITH (NOLOCK)
          ON l.PriceLevelMapId = m.PriceLevelMapId
        ORDER BY l.LevelOrdinal;
        """,
        values,
    )
    if not rows:
        return _empty_result(stock_code, observation_datetime)

    parent = rows[0]
    payload = _read_json(parent.get("MapJson"))
    supports: List[Dict[str, Any]] = []
    resistances: List[Dict[str, Any]] = []
    for row in rows:
        if row.get("PriceLevelMapLevelId") is None:
            continue
        level = _format_level(row)
        if level["side"] == "support":
            supports.append(level)
        elif level["side"] == "resistance":
            resistances.append(level)

    # A parent snapshot with no child levels is equivalent to no usable data
    # for this tab.
    if not supports and not resistances:
        return _empty_result(stock_code, observation_datetime)

    generated = parent.get("MapGeneratedAtUtc")
    matched_hour = None
    if isinstance(generated, datetime):
        matched_hour = generated.replace(minute=0, second=0, microsecond=0).isoformat()

    canonical_code = str(parent.get("ASXCode") or stock_code).strip().upper()
    chart_cutoff = parent.get("MapAsOfAtUtc")
    if not isinstance(chart_cutoff, datetime):
        observation_value = parent.get("ObservationDate")
        if isinstance(observation_value, date):
            chart_cutoff = datetime.combine(observation_value, datetime.max.time()).replace(microsecond=0)
    bars: List[Dict[str, Any]] = []
    if isinstance(chart_cutoff, datetime):
        bar_aliases = _stock_code_aliases(str(parent.get("ASXCode") or canonical_code))
        bar_placeholders = ", ".join("?" for _ in bar_aliases)
        raw_bars = _execute_saved_price_levels_query(
            model,
            """
            SELECT TimeIntervalStart, [Open], [High], [Low], [Close], Volume
            FROM StockDB_US.StockData.PriceHistoryTimeFrame WITH (NOLOCK)
            WHERE ASXCode IN ({bar_placeholders})
              AND TimeFrame = '30M'
              AND TimeIntervalStart >= ?
              AND TimeIntervalStart <= ?
            ORDER BY TimeIntervalStart;
            """.format(bar_placeholders=bar_placeholders),
            (
                *_stock_code_aliases(str(parent.get("ASXCode") or canonical_code)),
                chart_cutoff - timedelta(days=10),
                chart_cutoff,
            ),
        )
        for row in raw_bars:
            open_price = _float(row.get("Open"))
            high = _float(row.get("High"))
            low = _float(row.get("Low"))
            close = _float(row.get("Close"))
            if open_price is None or high is None or low is None or close is None:
                continue
            bars.append(
                {
                    "time": _iso(row.get("TimeIntervalStart")),
                    "open": open_price,
                    "high": high,
                    "low": low,
                    "close": close,
                    "volume": _float(row.get("Volume")) or 0.0,
                }
            )

    if canonical_code.endswith(".US"):
        canonical_code = canonical_code[:-3]
    return {
        "stock_code": canonical_code,
        "requested_stock_code": (stock_code or "").strip().upper(),
        "found": True,
        "as_at": observation_datetime.isoformat() if observation_datetime else None,
        "matched_hour_utc": matched_hour,
        "map_generated_at_utc": _iso(generated),
        "map_as_of_at_utc": _iso(parent.get("MapAsOfAtUtc")),
        "observation_date": _iso(parent.get("ObservationDate")),
        "bars": bars,
        "method_version": parent.get("MethodVersion"),
        "source_system": parent.get("SourceSystem"),
        "stock": {
            "stock_code": canonical_code,
            "database_code": str(parent.get("ASXCode") or canonical_code),
            "latest_close": _float(payload.get("latest_close")),
            "reference_price": _float(payload.get("reference_price")),
            "supports": supports,
            "resistances": resistances,
        },
    }


def get_saved_support_resistance(
    stock_code: str,
    observation_datetime: Optional[datetime] = None,
) -> Dict[str, Any]:
    model = _open_saved_price_levels_model()
    try:
        return _get_saved_support_resistance_with_model(
            stock_code=stock_code,
            observation_datetime=observation_datetime,
            model=model,
        )
    finally:
        _close_saved_price_levels_model(model)
