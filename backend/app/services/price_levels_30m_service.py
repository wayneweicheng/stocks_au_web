from __future__ import annotations

from datetime import date, datetime
from statistics import median
from typing import Any, Dict, List, Optional

from app.core.db import get_sql_model

ATR_PERIOD = 14
MIN_ZONE_DISTANCE_ATR = 0.33
MAX_ZONE_DISTANCE_ATR = 3.0


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


def _merge_gamma_walls(
    levels: List[Dict[str, Any]],
    walls: List[Dict[str, Any]],
    latest_close: float,
    tolerance: float,
    side: str,
) -> List[Dict[str, Any]]:
    merged = [dict(level, sources=["30m"]) for level in levels]
    eligible_walls = [
        wall
        for wall in walls
        if (side == "support" and wall["strike"] < latest_close)
        or (side == "resistance" and wall["strike"] > latest_close)
    ]
    eligible_walls.sort(key=lambda item: item["open_interest"], reverse=True)

    for wall in eligible_walls[:4]:
        strike = wall["strike"]
        match = next(
            (
                level
                for level in merged
                if abs(strike - level["price"]) <= tolerance
            ),
            None,
        )
        if match is not None:
            match["sources"] = ["30m", "gamma"]
            match["range_low"] = min(match["range_low"], strike - tolerance / 2.0)
            match["range_high"] = max(match["range_high"], strike + tolerance / 2.0)
            match["gamma_wall"] = wall
            continue

        merged.append(
            {
                "price": strike,
                "range_low": max(strike - tolerance / 2.0, 0.0),
                "range_high": strike + tolerance / 2.0,
                "touches": 0,
                "latest_touch": None,
                "sources": ["gamma"],
                "gamma_wall": wall,
            }
        )

    if side == "support":
        merged.sort(key=lambda item: latest_close - item["price"])
    else:
        merged.sort(key=lambda item: item["price"] - latest_close)
    return merged


def _calculate_atr(bars: List[Dict[str, Any]], period: int = ATR_PERIOD) -> float:
    if len(bars) < period + 1:
        return 0.0

    true_ranges: List[float] = []
    for index in range(1, len(bars)):
        bar = bars[index]
        previous_close = bars[index - 1]["close"]
        true_range = max(
            bar["high"] - bar["low"],
            abs(bar["high"] - previous_close),
            abs(bar["low"] - previous_close),
        )
        true_ranges.append(max(true_range, 0.0))

    atr = sum(true_ranges[:period]) / period
    for true_range in true_ranges[period:]:
        atr = ((atr * (period - 1)) + true_range) / period
    return atr


def _select_reasonable_levels(
    levels: List[Dict[str, Any]],
    latest_close: float,
    atr_daily: float,
) -> List[Dict[str, Any]]:
    selected: List[Dict[str, Any]] = []
    for level in levels:
        distance_atr = abs(level["price"] - latest_close) / atr_daily if atr_daily > 0 else None
        if distance_atr is None:
            continue
        if MIN_ZONE_DISTANCE_ATR <= distance_atr <= MAX_ZONE_DISTANCE_ATR:
            level["distance_atr"] = distance_atr
            selected.append(level)
    return selected[:2]


def _calculate_levels(
    stock_code: str,
    bars: List[Dict[str, Any]],
    daily_bars: List[Dict[str, Any]],
    gamma_walls: Optional[Dict[str, List[Dict[str, Any]]]] = None,
) -> Optional[Dict[str, Any]]:
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

    clean_daily_bars: List[Dict[str, Any]] = []
    for row in daily_bars:
        high = _number(row.get("High"))
        low = _number(row.get("Low"))
        close = _number(row.get("Close"))
        if high is None or low is None or close is None:
            continue
        clean_daily_bars.append(
            {
                "time": _timestamp(row.get("ObservationDate")),
                "high": high,
                "low": low,
                "close": close,
            }
        )

    latest = clean_bars[-1]
    latest_close = latest["close"]
    ranges = [max(bar["high"] - bar["low"], 0.0) for bar in clean_bars]
    median_range = median(ranges) if ranges else 0.0
    atr_daily = _calculate_atr(clean_daily_bars)
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

    half_width = tolerance / 2.0
    for item in supports:
        item["range_low"] = max(item["price"] - half_width, 0.0)
        item["range_high"] = item["price"] + half_width
    for item in resistances:
        item["range_low"] = max(item["price"] - half_width, 0.0)
        item["range_high"] = item["price"] + half_width

    walls = gamma_walls or {}
    supports = _merge_gamma_walls(
        supports,
        walls.get("puts", []),
        latest_close,
        tolerance,
        "support",
    )
    resistances = _merge_gamma_walls(
        resistances,
        walls.get("calls", []),
        latest_close,
        tolerance,
        "resistance",
    )
    supports = _select_reasonable_levels(supports, latest_close, atr_daily)
    resistances = _select_reasonable_levels(resistances, latest_close, atr_daily)

    def format_level(item: Dict[str, Any]) -> Dict[str, Any]:
        distance_pct = (item["price"] - latest_close) / latest_close * 100 if latest_close else 0.0
        wall = item.get("gamma_wall")
        return {
            "price": round(item["price"], 4),
            "range_low": round(max(item["range_low"], 0.0), 4),
            "range_high": round(item["range_high"], 4),
            "touches": int(item["touches"]),
            "distance_pct": round(distance_pct, 2),
            "distance_atr": round(item["distance_atr"], 2),
            "latest_touch": item["latest_touch"].isoformat() if item.get("latest_touch") else None,
            "sources": item.get("sources", ["30m"]),
            "gamma_wall": (
                {
                    "strike": round(wall["strike"], 4),
                    "open_interest": int(wall["open_interest"]),
                    "nearest_expiry": wall["nearest_expiry"].isoformat()
                    if isinstance(wall.get("nearest_expiry"), date)
                    else str(wall.get("nearest_expiry") or ""),
                }
                if wall
                else None
            ),
        }

    return {
        "stock_code": stock_code[:-3] if stock_code.upper().endswith(".US") else stock_code,
        "database_code": stock_code,
        "latest_close": round(latest_close, 4),
        "latest_bar_time": latest["time"].isoformat(),
        "bar_count": len(clean_bars),
        "median_bar_range": round(median_range, 4),
        "atr_daily": round(atr_daily, 4) if atr_daily > 0 else None,
        "atr_period": ATR_PERIOD,
        "reasonable_distance_atr": {
            "minimum": MIN_ZONE_DISTANCE_ATR,
            "maximum": MAX_ZONE_DISTANCE_ATR,
        },
        "supports": [format_level(item) for item in supports[:2]],
        "resistances": [format_level(item) for item in resistances[:2]],
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

    daily_rows = model.execute_read_query(
        """
        SELECT ASXCode, ObservationDate, [High], [Low], [Close]
        FROM StockDB_US.StockData.PriceHistory
        WHERE ObservationDate >= DATEADD(day, -45, ?)
          AND ObservationDate <= ?
        ORDER BY ASXCode, ObservationDate
        """,
        (observation_date.isoformat(), observation_date.isoformat()),
    ) or []

    daily_by_stock: Dict[str, List[Dict[str, Any]]] = {}
    for row in daily_rows:
        code = str(row.get("ASXCode") or "")
        if not code:
            continue
        daily_by_stock.setdefault(code, []).append(row)

    wall_rows = model.execute_read_query(
        """
        SELECT
            ASXCode,
            PorC,
            Strike,
            SUM(COALESCE(OpenInterest, 0)) AS OpenInterest,
            MIN(ExpiryDate) AS NearestExpiry
        FROM StockDB_US.StockData.v_OptionDelayedQuote_V2
        WHERE ObservationDate = ?
          AND ExpiryDate >= ?
          AND ExpiryDate <= DATEADD(day, 30, ?)
          AND PorC IN ('P', 'C')
          AND OpenInterest > 0
        GROUP BY ASXCode, PorC, Strike
        """,
        (
            observation_date.isoformat(),
            observation_date.isoformat(),
            observation_date.isoformat(),
        ),
    ) or []

    walls_by_stock: Dict[str, Dict[str, List[Dict[str, Any]]]] = {}
    for row in wall_rows:
        code = str(row.get("ASXCode") or "")
        strike = _number(row.get("Strike"))
        open_interest = _number(row.get("OpenInterest"))
        option_type = str(row.get("PorC") or "").upper()
        if not code or strike is None or open_interest is None or option_type not in {"P", "C"}:
            continue
        bucket = walls_by_stock.setdefault(code, {"puts": [], "calls": []})
        bucket["puts" if option_type == "P" else "calls"].append(
            {
                "strike": strike,
                "open_interest": int(open_interest),
                "nearest_expiry": row.get("NearestExpiry"),
            }
        )

    stocks = []
    for code, stock_bars in grouped.items():
        result = _calculate_levels(
            code,
            stock_bars,
            daily_by_stock.get(code, []),
            walls_by_stock.get(code),
        )
        if result is not None:
            stocks.append(result)
    stocks.sort(key=lambda item: item["stock_code"])

    return {
        "observation_date": observation_date.isoformat(),
        "lookback_days": lookback_days,
        "count": len(stocks),
        "stocks": stocks,
    }
