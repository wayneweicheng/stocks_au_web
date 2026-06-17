"""Compact liquidity metrics to LLM-ready format."""

from typing import Dict, List, Any
import statistics


def _numeric(value: Any, default: float = 0.0) -> float:
    try:
        if value is None:
            return default
        return float(value)
    except (TypeError, ValueError):
        return default


def calculate_liquidity_score(avg_volume: float, market_cap: float) -> int:
    """Calculate liquidity score (0-10) based on volume and market cap."""
    if not avg_volume or not market_cap:
        return 5

    # Volume as % of market cap
    volume_ratio = (avg_volume * 1) / market_cap if market_cap > 0 else 0

    # Score based on turnover
    if volume_ratio > 0.05:  # >5% daily turnover
        return 9
    elif volume_ratio > 0.03:
        return 8
    elif volume_ratio > 0.02:
        return 7
    elif volume_ratio > 0.01:
        return 6
    elif volume_ratio > 0.005:
        return 5
    elif volume_ratio > 0.002:
        return 4
    else:
        return 3


def assess_depth(avg_volume: float) -> int:
    """Assess market depth score (0-10)."""
    # Simple heuristic based on average volume
    if avg_volume > 5_000_000:
        return 9
    elif avg_volume > 2_000_000:
        return 8
    elif avg_volume > 1_000_000:
        return 7
    elif avg_volume > 500_000:
        return 6
    elif avg_volume > 100_000:
        return 5
    elif avg_volume > 50_000:
        return 4
    else:
        return 3


def compact_liquidity(price_data: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Compact liquidity metrics.
    Target: ~1,000 tokens
    """
    if not price_data:
        return {
            "avg_daily_volume": 0,
            "liquidity_score": 0,
            "depth_score": 0,
            "volume_consistency": "Unknown"
        }

    # Calculate average volume (last 20 days)
    recent_20 = price_data[:20] if len(price_data) >= 20 else price_data
    volumes = [_numeric(p.get("Volume", 0)) for p in recent_20]

    avg_volume = statistics.mean(volumes) if volumes else 0

    # Get market cap from most recent day
    market_cap = _numeric(price_data[0].get("MarketCap", 0))

    # Calculate scores
    liquidity_score = calculate_liquidity_score(avg_volume, market_cap)
    depth_score = assess_depth(avg_volume)

    # Volume consistency (coefficient of variation)
    volume_consistency = "Unknown"
    if len(volumes) > 1:
        std_dev = statistics.stdev(volumes)
        cv = (std_dev / avg_volume) if avg_volume > 0 else 0

        if cv < 0.5:
            volume_consistency = "Consistent"
        elif cv < 1.0:
            volume_consistency = "Moderate"
        else:
            volume_consistency = "Volatile"

    # Median trade value estimate (volume * avg price / num trades)
    # Since we don't have trade count, estimate
    avg_price = statistics.mean([_numeric(p.get("Close", 0)) for p in recent_20]) if recent_20 else 0
    estimated_median_trade = (avg_price * avg_volume / 1000) if avg_volume > 0 else 0

    return {
        "avg_daily_volume": round(avg_volume),
        "market_cap": market_cap,
        "liquidity_score": liquidity_score,
        "depth_score": depth_score,
        "volume_consistency": volume_consistency,
        "estimated_median_trade_value": round(estimated_median_trade, 2)
    }
