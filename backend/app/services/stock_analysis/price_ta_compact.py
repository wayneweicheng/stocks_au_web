"""Compact price and technical analysis data to LLM-ready format."""

from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta
import statistics


def _numeric(value: Any, default: float = 0.0) -> float:
    try:
        if value is None:
            return default
        return float(value)
    except (TypeError, ValueError):
        return default


def calculate_sma(prices: List[float], period: int) -> Optional[float]:
    """Calculate simple moving average."""
    if len(prices) < period:
        return None
    return statistics.mean(prices[-period:])


def calculate_price_change(prices: List[Dict[str, Any]], days: int) -> Optional[float]:
    """Calculate price change percentage over N days."""
    if len(prices) < days:
        return None

    recent = prices[0].get("Close")
    past = prices[min(days, len(prices) - 1)].get("Close")

    if not recent or not past:
        return None

    recent_value = _numeric(recent)
    past_value = _numeric(past)
    if not past_value:
        return None

    return round(((recent_value - past_value) / past_value) * 100, 2)


def detect_support_resistance(prices: List[Dict[str, Any]]) -> Dict[str, List[float]]:
    """Identify key support and resistance levels."""
    if not prices:
        return {"support": [], "resistance": []}

    # Get recent lows and highs
    recent_30 = prices[:30] if len(prices) >= 30 else prices

    lows = [_numeric(p.get("Low")) for p in recent_30 if p.get("Low") is not None]
    highs = [_numeric(p.get("High")) for p in recent_30 if p.get("High") is not None]

    # Simple support/resistance: recent min/max and round numbers nearby
    support = []
    resistance = []

    if lows:
        recent_low = min(lows)
        support.append(round(recent_low, 2))
        # Add round number below
        support.append(round(recent_low * 0.95, 2))

    if highs:
        recent_high = max(highs)
        resistance.append(round(recent_high, 2))
        # Add round number above
        resistance.append(round(recent_high * 1.05, 2))

    return {
        "support": sorted(support),
        "resistance": sorted(resistance)
    }


def analyze_volume_trend(prices: List[Dict[str, Any]]) -> str:
    """Analyze volume trend."""
    if len(prices) < 20:
        return "Insufficient data"

    recent_volume = [_numeric(p.get("Volume", 0)) for p in prices[:10]]
    past_volume = [_numeric(p.get("Volume", 0)) for p in prices[10:20]]

    if not recent_volume or not past_volume:
        return "Unknown"

    avg_recent = statistics.mean(recent_volume)
    avg_past = statistics.mean(past_volume)

    change = ((avg_recent - avg_past) / avg_past) * 100

    if change > 20:
        return "Increasing"
    elif change < -20:
        return "Decreasing"
    else:
        return "Stable"


def assess_momentum(prices: List[Dict[str, Any]]) -> str:
    """Assess price momentum."""
    if len(prices) < 5:
        return "Unknown"

    recent_5 = [_numeric(p.get("Close", 0)) for p in prices[:5]]

    if not recent_5 or min(recent_5) == 0:
        return "Unknown"

    # Simple momentum: are we trending up?
    if recent_5[0] > recent_5[-1]:
        change = ((recent_5[0] - recent_5[-1]) / recent_5[-1]) * 100
        if change > 5:
            return "Strong"
        else:
            return "Positive"
    else:
        change = ((recent_5[-1] - recent_5[0]) / recent_5[0]) * 100
        if change > 5:
            return "Weak"
        else:
            return "Negative"


def detect_technical_setup(prices: List[Dict[str, Any]]) -> str:
    """Detect technical setup pattern."""
    if len(prices) < 20:
        return "Insufficient data"

    current_price = _numeric(prices[0].get("Close"))
    sma_20 = calculate_sma([_numeric(p.get("Close", 0)) for p in prices[:20]], 20)
    sma_50 = calculate_sma([_numeric(p.get("Close", 0)) for p in prices[:50]], 50) if len(prices) >= 50 else None

    if not current_price or not sma_20:
        return "Unknown"

    # Above/below moving averages
    if current_price > sma_20:
        if sma_50 and current_price > sma_50:
            return "Breakout (above MA20 and MA50)"
        else:
            return "Above MA20"
    else:
        if sma_50 and current_price < sma_50:
            return "Breakdown (below MA20 and MA50)"
        else:
            return "Below MA20"


def compact_price_ta(raw_prices: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Compact price and technical analysis data.
    Target: ~2,000 tokens
    """
    if not raw_prices:
        return {
            "current_price": None,
            "price_changes": {},
            "technical_setup": "No data",
            "support_resistance": {"support": [], "resistance": []},
            "volume_trend": "Unknown",
            "momentum": "Unknown",
            "volatility": "Unknown"
        }

    # Sort by date (most recent first)
    prices = sorted(
        raw_prices,
        key=lambda x: x.get("TradeDate") or "",
        reverse=True
    )

    current_price = _numeric(prices[0].get("Close"))

    # Price changes
    price_changes = {
        "1d": calculate_price_change(prices, 1),
        "5d": calculate_price_change(prices, 5),
        "10d": calculate_price_change(prices, 10),
        "30d": calculate_price_change(prices, 30),
        "90d": calculate_price_change(prices, 90)
    }

    # Support/Resistance
    levels = detect_support_resistance(prices)

    # Volume trend
    volume_trend = analyze_volume_trend(prices)

    # Momentum
    momentum = assess_momentum(prices)

    # Technical setup
    technical_setup = detect_technical_setup(prices)

    # Volatility (simple: stddev of recent % changes)
    recent_changes = []
    for i in range(min(20, len(prices) - 1)):
        if prices[i].get("Close") and prices[i+1].get("Close"):
            current_close = _numeric(prices[i]["Close"])
            prior_close = _numeric(prices[i+1]["Close"])
            if not prior_close:
                continue
            pct_change = ((current_close - prior_close) / prior_close) * 100
            recent_changes.append(abs(pct_change))

    volatility = "Unknown"
    if recent_changes:
        avg_volatility = statistics.mean(recent_changes)
        if avg_volatility > 5:
            volatility = "High"
        elif avg_volatility > 2:
            volatility = "Moderate"
        else:
            volatility = "Low"

    # Market cap info
    market_cap = _numeric(prices[0].get("MarketCap"))

    return {
        "current_price": round(current_price, 3) if current_price else None,
        "current_date": prices[0].get("TradeDate").isoformat() if prices[0].get("TradeDate") else None,
        "market_cap": market_cap,
        "price_changes": price_changes,
        "technical_setup": technical_setup,
        "support_resistance": levels,
        "volume_trend": volume_trend,
        "momentum": momentum,
        "volatility": volatility,
        "trading_days": len(prices)
    }
