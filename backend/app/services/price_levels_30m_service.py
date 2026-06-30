from __future__ import annotations

import logging
from datetime import date, datetime
from statistics import median
from typing import Any, Dict, List, Optional
from zoneinfo import ZoneInfo

from app.core.db import get_sql_model
from app.services.live_stock_price_service import get_live_stock_prices

ATR_PERIOD = 14
MIN_ZONE_DISTANCE_ATR = 0.33
MAX_ZONE_DISTANCE_ATR = 3.0
US_EASTERN = ZoneInfo("America/New_York")
logger = logging.getLogger("app.price_levels_30m_service")


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


def _stock_code_aliases(stock_code: str) -> List[str]:
    code = (stock_code or "").strip().upper()
    if not code:
        return []
    base_code = code[:-3] if code.endswith(".US") else code
    aliases: List[str] = []
    for candidate in [code, base_code, f"{base_code}.US"]:
        if candidate and candidate not in aliases:
            aliases.append(candidate)
    return aliases


def _should_use_live_prices(
    observation_date: date,
    market_today: date,
    recent_trading_dates: List[date],
) -> bool:
    live_dates = {market_today}
    prior_trading_dates = [
        trading_date for trading_date in recent_trading_dates if trading_date < market_today
    ][:2]
    live_dates.update(prior_trading_dates)
    return observation_date in live_dates


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
    minimum_distance_atr: float = MIN_ZONE_DISTANCE_ATR,
    maximum_distance_atr: float = MAX_ZONE_DISTANCE_ATR,
    max_levels: int = 2,
) -> List[Dict[str, Any]]:
    selected: List[Dict[str, Any]] = []
    for level in levels:
        distance_atr = abs(level["price"] - latest_close) / atr_daily if atr_daily > 0 else None
        if distance_atr is None:
            continue
        if minimum_distance_atr <= distance_atr <= maximum_distance_atr:
            level["distance_atr"] = distance_atr
            selected.append(level)

    def quality_key(level: Dict[str, Any]) -> tuple[Any, ...]:
        sources = set(level.get("sources", ["30m"]))
        has_confluence = "30m" in sources and "gamma" in sources
        touches = int(level.get("touches") or 0)
        wall = level.get("gamma_wall") or {}
        gamma_open_interest = int(wall.get("open_interest") or 0)
        latest_touch = level.get("latest_touch")
        recency = latest_touch.timestamp() if isinstance(latest_touch, datetime) else 0.0
        return (
            -int(has_confluence),
            -touches,
            -gamma_open_interest,
            -recency,
            level["distance_atr"],
        )

    selected.sort(key=quality_key)
    for rank, level in enumerate(selected, start=1):
        level["strength_rank"] = rank
    return selected[:max_levels]


def _calculate_levels(
    stock_code: str,
    bars: List[Dict[str, Any]],
    daily_bars: List[Dict[str, Any]],
    gamma_walls: Optional[Dict[str, List[Dict[str, Any]]]] = None,
    reference_price: Optional[float] = None,
    price_source: str = "30m_close",
    minimum_distance_atr: float = MIN_ZONE_DISTANCE_ATR,
    maximum_distance_atr: float = MAX_ZONE_DISTANCE_ATR,
    max_levels: int = 2,
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
    has_reference_price = reference_price is not None and reference_price > 0
    current_price = reference_price if has_reference_price else latest_close
    ranges = [max(bar["high"] - bar["low"], 0.0) for bar in clean_bars]
    median_range = median(ranges) if ranges else 0.0
    atr_daily = _calculate_atr(clean_daily_bars)
    tolerance = max(current_price * 0.003, median_range * 0.6, 0.01)

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

    supports = [cluster for cluster in support_clusters if cluster["price"] < current_price]
    resistances = [cluster for cluster in resistance_clusters if cluster["price"] > current_price]

    if not supports:
        lowest = min(clean_bars, key=lambda bar: bar["low"])
        if lowest["low"] < current_price:
            supports = [{"price": lowest["low"], "touches": 1, "latest_touch": lowest["time"]}]
    if not resistances:
        highest = max(clean_bars, key=lambda bar: bar["high"])
        if highest["high"] > current_price:
            resistances = [{"price": highest["high"], "touches": 1, "latest_touch": highest["time"]}]

    supports.sort(key=lambda item: (current_price - item["price"], -item["touches"]))
    resistances.sort(key=lambda item: (item["price"] - current_price, -item["touches"]))

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
        current_price,
        tolerance,
        "support",
    )
    resistances = _merge_gamma_walls(
        resistances,
        walls.get("calls", []),
        current_price,
        tolerance,
        "resistance",
    )
    supports = _select_reasonable_levels(
        supports,
        latest_close,
        atr_daily,
        minimum_distance_atr,
        maximum_distance_atr,
        max_levels,
    )
    resistances = _select_reasonable_levels(
        resistances,
        latest_close,
        atr_daily,
        minimum_distance_atr,
        maximum_distance_atr,
        max_levels,
    )

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
            "strength_rank": int(item.get("strength_rank") or 0),
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
        "reference_price": round(current_price, 4),
        "price_source": price_source if has_reference_price else "30m_close",
        "latest_bar_time": latest["time"].isoformat(),
        "bar_count": len(clean_bars),
        "median_bar_range": round(median_range, 4),
        "atr_daily": round(atr_daily, 4) if atr_daily > 0 else None,
        "atr_period": ATR_PERIOD,
        "reasonable_distance_atr": {
            "minimum": minimum_distance_atr,
            "maximum": maximum_distance_atr,
        },
        "supports": [format_level(item) for item in supports],
        "resistances": [format_level(item) for item in resistances],
    }


def get_30m_support_resistance(
    observation_date: Optional[date] = None,
    lookback_days: int = 10,
    minimum_distance_atr: float = MIN_ZONE_DISTANCE_ATR,
    maximum_distance_atr: float = MAX_ZONE_DISTANCE_ATR,
    stock_codes: Optional[List[str]] = None,
    group: Optional[Dict[str, Any]] = None,
    max_levels: int = 2,
    enable_live_prices: bool = True,
) -> Dict[str, Any]:
    if minimum_distance_atr > maximum_distance_atr:
        raise ValueError("Minimum ATR distance cannot exceed maximum ATR distance")

    model = get_sql_model()
    market_today = datetime.now(US_EASTERN).date()
    filtered_stock_codes = sorted(
        {
            alias
            for code in (stock_codes or [])
            if str(code).strip()
            for alias in _stock_code_aliases(str(code))
        }
    )

    date_rows = model.execute_read_query(
        """
        SELECT DISTINCT TOP (3)
            CAST(TimeIntervalStart AS date) AS TradingDate
        FROM StockDB_US.StockData.PriceHistoryTimeFrame
        WHERE TimeFrame = '30M'
          AND TimeIntervalStart < DATEADD(day, 1, convert(datetime, ?))
        ORDER BY TradingDate DESC
        """,
        (market_today.isoformat(),),
    ) or []
    recent_trading_dates = [
        value if isinstance(value, date) else date.fromisoformat(str(value)[:10])
        for row in date_rows
        if (value := row.get("TradingDate")) is not None
    ]
    if not recent_trading_dates:
        return {
            "observation_date": None,
            "lookback_days": lookback_days,
            "atr_range": {
                "minimum": minimum_distance_atr,
                "maximum": maximum_distance_atr,
            },
            "group": group,
            "stocks": [],
            "count": 0,
        }
    latest_available_date = recent_trading_dates[0]
    if observation_date is None:
        observation_date = latest_available_date

    stock_filter = ""
    stock_filter_params: tuple[Any, ...] = ()
    if filtered_stock_codes:
        stock_filter = f" AND ASXCode IN ({','.join(['convert(varchar(10), ?)'] * len(filtered_stock_codes))})"
        stock_filter_params = tuple(filtered_stock_codes)

    rows = model.execute_read_query(
        f"""
        SELECT ASXCode, TimeIntervalStart, [High], [Low], [Close], Volume
        FROM StockDB_US.StockData.PriceHistoryTimeFrame
        WHERE TimeIntervalStart >= DATEADD(day, -?, convert(datetime, ?))
          AND TimeIntervalStart <= DATEADD(hour, 23, convert(datetime, ?))
          AND TimeFrame = '30M'
          {stock_filter}
        ORDER BY ASXCode, TimeIntervalStart
        """,
        (
            lookback_days,
            observation_date.isoformat(),
            observation_date.isoformat(),
            *stock_filter_params,
        ),
    ) or []

    grouped: Dict[str, List[Dict[str, Any]]] = {}
    for row in rows:
        code = str(row.get("ASXCode") or "")
        if not code:
            continue
        grouped.setdefault(code, []).append(row)

    daily_rows = model.execute_read_query(
        f"""
        SELECT ASXCode, ObservationDate, [High], [Low], [Close]
        FROM StockDB_US.StockData.PriceHistory
        WHERE ObservationDate >= DATEADD(day, -45, convert(date, ?))
          AND ObservationDate <= convert(date, ?)
          {stock_filter}
        ORDER BY ASXCode, ObservationDate
        """,
        (
            observation_date.isoformat(),
            observation_date.isoformat(),
            *stock_filter_params,
        ),
    ) or []

    daily_by_stock: Dict[str, List[Dict[str, Any]]] = {}
    for row in daily_rows:
        code = str(row.get("ASXCode") or "")
        if not code:
            continue
        daily_by_stock.setdefault(code, []).append(row)

    wall_rows = model.execute_read_query(
        f"""
        SELECT
            ASXCode,
            PorC,
            Strike,
            SUM(COALESCE(OpenInterest, 0)) AS OpenInterest,
            MIN(ExpiryDate) AS NearestExpiry
        FROM StockDB_US.StockData.v_OptionDelayedQuote_V2
        WHERE ObservationDate = convert(date, ?)
          AND ExpiryDate >= convert(date, ?)
          AND ExpiryDate <= DATEADD(day, 30, convert(date, ?))
          AND PorC IN ('P', 'C')
          AND OpenInterest > 0
          {stock_filter}
        GROUP BY ASXCode, PorC, Strike
        """,
        (
            observation_date.isoformat(),
            observation_date.isoformat(),
            observation_date.isoformat(),
            *stock_filter_params,
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

    snapshot_rows = model.execute_read_query(
        f"""
        SELECT
            ASXCode,
            ObservationDate,
            ImpliedVolatility,
            HistoricalVolatility,
            IVRank252,
            IVPercentile252,
            IVHistoryCount,
            TrailingPE,
            ForwardPE
        FROM StockDB_US.StockData.v_DailyMarketSnapshot_Latest
        WHERE CollectionStatus = 'COMPLETE'
          {stock_filter}
        """,
        stock_filter_params,
    ) or []
    snapshots_by_stock = {
        str(row.get("ASXCode") or ""): row
        for row in snapshot_rows
        if row.get("ASXCode")
    }

    use_live_prices = enable_live_prices and _should_use_live_prices(
        observation_date,
        market_today,
        recent_trading_dates,
    )
    live_prices: Dict[str, Dict[str, Any]] = {}
    if use_live_prices:
        try:
            live_prices = get_live_stock_prices(grouped.keys())
        except Exception as exc:
            logger.warning("Live price check failed for live-price observation date: %s", exc)

    stocks = []
    live_price_missing: List[str] = []
    for code, stock_bars in grouped.items():
        live_quote = live_prices.get(code)
        if use_live_prices and live_quote is None:
            live_price_missing.append(code)
        result = _calculate_levels(
            code,
            stock_bars,
            daily_by_stock.get(code, []),
            walls_by_stock.get(code),
            reference_price=_number(live_quote.get("price")) if live_quote else None,
            price_source=str(live_quote.get("source")) if live_quote else "30m_close",
            minimum_distance_atr=minimum_distance_atr,
            maximum_distance_atr=maximum_distance_atr,
            max_levels=max_levels,
        )
        if result is not None:
            stored_snapshot = snapshots_by_stock.get(code) or {}
            stored_iv = _number(stored_snapshot.get("ImpliedVolatility"))
            stored_hv = _number(stored_snapshot.get("HistoricalVolatility"))
            result["implied_volatility"] = (
                round(stored_iv, 6)
                if stored_iv is not None
                else None
            )
            result["historical_volatility"] = (
                round(stored_hv, 6)
                if stored_hv is not None
                else None
            )
            iv_percentile = _number(stored_snapshot.get("IVPercentile252"))
            iv_rank = _number(stored_snapshot.get("IVRank252"))
            result["iv_percentile"] = (
                round(iv_percentile, 2) if iv_percentile is not None else None
            )
            result["iv_rank"] = round(iv_rank, 2) if iv_rank is not None else None
            trailing_pe = _number(stored_snapshot.get("TrailingPE"))
            result["trailing_pe"] = (
                round(trailing_pe, 4) if trailing_pe is not None else None
            )
            forward_pe = _number(stored_snapshot.get("ForwardPE"))
            result["forward_pe"] = (
                round(forward_pe, 4) if forward_pe is not None else None
            )
            result["iv_history_count"] = int(
                _number(stored_snapshot.get("IVHistoryCount")) or 0
            )
            result["iv_source"] = (
                "database"
                if stored_iv is not None or stored_hv is not None
                else None
            )
            snapshot_date = stored_snapshot.get("ObservationDate")
            result["iv_observation_date"] = (
                snapshot_date.isoformat()
                if isinstance(snapshot_date, date)
                else str(snapshot_date)[:10] if snapshot_date else None
            )
            stocks.append(result)
    stocks.sort(key=lambda item: item["stock_code"])

    return {
        "observation_date": observation_date.isoformat(),
        "latest_available_date": latest_available_date.isoformat(),
        "recent_trading_dates": [item.isoformat() for item in recent_trading_dates],
        "live_price_check": use_live_prices,
        "live_price_missing": sorted(live_price_missing),
        "lookback_days": lookback_days,
        "atr_range": {
            "minimum": minimum_distance_atr,
            "maximum": maximum_distance_atr,
        },
        "group": group,
        "count": len(stocks),
        "stocks": stocks,
    }


def get_30m_support_resistance_for_stock(
    stock_code: str,
    observation_date: Optional[date] = None,
    lookback_days: int = 10,
    minimum_distance_atr: float = MIN_ZONE_DISTANCE_ATR,
    maximum_distance_atr: float = MAX_ZONE_DISTANCE_ATR,
    max_levels: int = 5,
    enable_live_prices: bool = False,
) -> Dict[str, Any]:
    if minimum_distance_atr > maximum_distance_atr:
        raise ValueError("Minimum ATR distance cannot exceed maximum ATR distance")
    code = (stock_code or "").strip().upper()
    if not code:
        raise ValueError("stock_code is required")

    aliases = _stock_code_aliases(code)

    result = get_30m_support_resistance(
        observation_date=observation_date,
        lookback_days=lookback_days,
        minimum_distance_atr=minimum_distance_atr,
        maximum_distance_atr=maximum_distance_atr,
        stock_codes=aliases,
        group=None,
        max_levels=max_levels,
        enable_live_prices=enable_live_prices,
    )

    if not result.get("stocks"):
        raise ValueError(f"No 30-minute prices found for {code}")

    stocks = result["stocks"]
    stock = next(
        (
            item
            for alias in aliases
            for item in stocks
            if str(item.get("database_code") or "").upper() == alias
        ),
        stocks[0],
    )
    model = get_sql_model()
    raw_bars = model.execute_read_query(
        """
        SELECT TimeIntervalStart, [Open], [High], [Low], [Close], Volume
        FROM StockDB_US.StockData.PriceHistoryTimeFrame
        WHERE TimeIntervalStart >= DATEADD(day, -?, convert(datetime, ?))
          AND TimeIntervalStart <= DATEADD(hour, 23, convert(datetime, ?))
          AND TimeFrame = '30M'
          AND ASXCode = convert(varchar(10), ?)
        ORDER BY TimeIntervalStart
        """,
        (
            lookback_days,
            result["observation_date"],
            result["observation_date"],
            stock["database_code"],
        ),
    ) or []

    bars: List[Dict[str, Any]] = []
    for row in raw_bars:
        open_price = _number(row.get("Open"))
        high = _number(row.get("High"))
        low = _number(row.get("Low"))
        close = _number(row.get("Close"))
        volume = _number(row.get("Volume"))
        if open_price is None or high is None or low is None or close is None:
            continue
        bars.append(
            {
                "time": _timestamp(row.get("TimeIntervalStart")).isoformat(),
                "open": open_price,
                "high": high,
                "low": low,
                "close": close,
                "volume": volume if volume is not None else 0.0,
            }
        )

    return {
        "observation_date": result["observation_date"],
        "latest_available_date": result["latest_available_date"],
        "recent_trading_dates": result["recent_trading_dates"],
        "live_price_check": result["live_price_check"],
        "live_price_missing": result["live_price_missing"],
        "lookback_days": lookback_days,
        "atr_range": result["atr_range"],
        "stock_code": stock["stock_code"],
        "stock": stock,
        "bars": bars,
    }
