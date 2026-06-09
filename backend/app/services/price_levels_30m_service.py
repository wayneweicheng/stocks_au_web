from __future__ import annotations

from datetime import date, datetime
from statistics import median
from typing import Any, Dict, List, Optional

from app.core.db import get_sql_model


def _number(value: Any) -> Optional[float]:
    try:
        if value is None:
            return None
        return float(value)
    except (TypeError, ValueError):
        return None


def _timestamp(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value
    return datetime.fromisoformat(str(value))


def _cluster_levels(points: List[Dict[str, Any]], tolerance: float) -> List[Dict[str, Any]]:
    clusters: List[Dict[str, Any]] = []
    for point in sorted(points, key=lambda item: item["price"]):
        match = next(
            (
                cluster
                for cluster in clusters
                if abs(point["price"] - cluster["price"]) <= tolerance
            ),
            None,
        )
        if match is None:
            clusters.append(
                {
                    "price": point["price"],
                    "touches": 1,
                    "latest_touch": point["time"],
                    "prices": [point["price"]],
                }
            )
            continue

        match["prices"].append(point["price"])
        match["touches"] += 1
        match["price"] = sum(match["prices"]) / len(match["prices"])
        if point["time"] > match["latest_touch"]:
            match["latest_touch"] = point["time"]

    return clusters


def _calculate_levels(stock_code: str, bars: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    clean_bars: List[Dict[str, Any]] = []
    for row in bars:
        high = _number(row.get("High"))
        low = _number(row.get("Low"))
        close = _number(row.get("Close"))
        if high is None or low is None or close is None:
            continue
        clean_bars.append(
            {
                "time": _timestamp(row.get("TimeIntervalStart")),
                "high": high,
                "low": low,
                "close": close,
                "volume": _number(row.get("Volume")) or 0.0,
            }
        )

    if len(clean_bars) < 3:
        return None

    latest = clean_bars[-1]
    latest_close = latest["close"]
    ranges = [max(bar["high"] - bar["low"], 0.0) for bar in clean_bars]
    median_range = median(ranges) if ranges else 0.0
    tolerance = max(latest_close * 0.003, median_range * 0.6, 0.01)

    support_points: List[Dict[str, Any]] = []
    resistance_points: List[Dict[str, Any]] = []
    for index in range(1, len(clean_bars) - 1):
        previous = clean_bars[index - 1]
        current = clean_bars[index]
        following = clean_bars[index + 1]
        if current["low"] <= previous["low"] and current["low"] <= following["low"]:
            support_points.append({"price": current["low"], "time": current["time"]})
        if current["high"] >= previous["high"] and current["high"] >= following["high"]:
            resistance_points.append({"price": current["high"], "time": current["time"]})

    support_clusters = _cluster_levels(support_points, tolerance)
    resistance_clusters = _cluster_levels(resistance_points, tolerance)

    supports = [cluster for cluster in support_clusters if cluster["price"] < latest_close]
    resistances = [cluster for cluster in resistance_clusters if cluster["price"] > latest_close]

    if not supports:
        lowest = min(clean_bars, key=lambda bar: bar["low"])
        supports = [{"price": lowest["low"], "touches": 1, "latest_touch": lowest["time"]}]
    if not resistances:
        highest = max(clean_bars, key=lambda bar: bar["high"])
        resistances = [{"price": highest["high"], "touches": 1, "latest_touch": highest["time"]}]

    supports.sort(key=lambda item: (latest_close - item["price"], -item["touches"]))
    resistances.sort(key=lambda item: (item["price"] - latest_close, -item["touches"]))

    def format_level(item: Dict[str, Any]) -> Dict[str, Any]:
        distance_pct = (item["price"] - latest_close) / latest_close * 100 if latest_close else 0.0
        half_width = tolerance / 2.0
        return {
            "price": round(item["price"], 4),
            "range_low": round(max(item["price"] - half_width, 0.0), 4),
            "range_high": round(item["price"] + half_width, 4),
            "touches": int(item["touches"]),
            "distance_pct": round(distance_pct, 2),
            "latest_touch": item["latest_touch"].isoformat(),
        }

    return {
        "stock_code": stock_code[:-3] if stock_code.upper().endswith(".US") else stock_code,
        "database_code": stock_code,
        "latest_close": round(latest_close, 4),
        "latest_bar_time": latest["time"].isoformat(),
        "bar_count": len(clean_bars),
        "median_bar_range": round(median_range, 4),
        "supports": [format_level(item) for item in supports[:3]],
        "resistances": [format_level(item) for item in resistances[:3]],
    }


def get_30m_support_resistance(
    observation_date: Optional[date] = None,
    lookback_days: int = 10,
) -> Dict[str, Any]:
    model = get_sql_model()

    if observation_date is None:
        date_rows = model.execute_read_query(
            """
            SELECT MAX(CAST(TimeIntervalStart AS date)) AS LatestDate
            FROM StockDB_US.StockData.PriceHistoryTimeFrame
            WHERE TimeFrame = '30M'
            """,
            (),
        ) or []
        latest_value = date_rows[0].get("LatestDate") if date_rows else None
        if latest_value is None:
            return {"observation_date": None, "lookback_days": lookback_days, "stocks": [], "count": 0}
        observation_date = latest_value if isinstance(latest_value, date) else date.fromisoformat(str(latest_value)[:10])

    rows = model.execute_read_query(
        """
        SELECT ASXCode, TimeIntervalStart, [High], [Low], [Close], Volume
        FROM StockDB_US.StockData.PriceHistoryTimeFrame
        WHERE TimeIntervalStart >= DATEADD(day, -?, ?)
          AND TimeIntervalStart <= DATEADD(hour, 23, CAST(? AS datetime))
          AND TimeFrame = '30M'
        ORDER BY ASXCode, TimeIntervalStart
        """,
        (lookback_days, observation_date.isoformat(), observation_date.isoformat()),
    ) or []

    grouped: Dict[str, List[Dict[str, Any]]] = {}
    for row in rows:
        code = str(row.get("ASXCode") or "")
        if not code:
            continue
        grouped.setdefault(code, []).append(row)

    stocks = []
    for code, stock_bars in grouped.items():
        result = _calculate_levels(code, stock_bars)
        if result is not None:
            stocks.append(result)
    stocks.sort(key=lambda item: item["stock_code"])

    return {
        "observation_date": observation_date.isoformat(),
        "lookback_days": lookback_days,
        "count": len(stocks),
        "stocks": stocks,
    }
