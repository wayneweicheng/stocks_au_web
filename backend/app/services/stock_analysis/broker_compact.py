"""Compact broker flow data to LLM-ready format."""

from typing import Dict, List, Any, Optional
from collections import Counter


def _numeric(value: Any, default: float = 0.0) -> float:
    try:
        if value is None:
            return default
        return float(value)
    except (TypeError, ValueError):
        return default


def calculate_accumulation_score(setup_data: List[Dict[str, Any]]) -> int:
    """Calculate broker accumulation score (0-10)."""
    if not setup_data:
        return 0

    score = 5  # Start neutral

    # Check recent transform setup balance
    recent_5 = setup_data[:5]
    setup_deltas = [
        _numeric(s.get("BullishSetupScore")) - _numeric(s.get("BearishSetupScore"))
        for s in recent_5
    ]

    positive_count = sum(1 for delta in setup_deltas if delta > 0)

    # Consistent buying
    if positive_count >= 4:
        score += 3
    elif positive_count >= 3:
        score += 2
    elif positive_count >= 2:
        score += 1
    elif positive_count == 0:
        score -= 2

    # Buyer concentration (high is good for accumulation)
    if recent_5:
        avg_bull = sum(_numeric(s.get("BullishSetupScore")) for s in recent_5) / len(recent_5)
        avg_bear = sum(_numeric(s.get("BearishSetupScore")) for s in recent_5) / len(recent_5)
        spread = avg_bull - avg_bear
        if spread > 0.30:
            score += 2
        elif spread > 0.15:
            score += 1

    return max(0, min(10, score))


def identify_top_participants(setup_data: List[Dict[str, Any]]) -> Dict[str, List[str]]:
    """Identify top buyers and sellers."""
    buyers = []
    sellers = []

    for setup in setup_data[:10]:  # Recent 10 days
        if setup.get("TopBuyBroker"):
            buyers.append(setup["TopBuyBroker"])
        if setup.get("TopSellBroker"):
            sellers.append(setup["TopSellBroker"])

    # Count occurrences
    buyer_counts = Counter(buyers)
    seller_counts = Counter(sellers)

    return {
        "top_buyers": [broker for broker, _ in buyer_counts.most_common(3)],
        "top_sellers": [broker for broker, _ in seller_counts.most_common(3)]
    }


def analyze_institutional_flow(micro_data: List[Dict[str, Any]]) -> str:
    """Analyze institutional vs retail flow."""
    if not micro_data:
        return "Unknown"

    recent_5 = micro_data[:5]

    avg_execution = sum(_numeric(m.get("LiveExecutionQualityScore")) for m in recent_5) / len(recent_5)
    avg_distribution = sum(_numeric(m.get("LiveDistributionScore")) for m in recent_5) / len(recent_5)
    avg_buyer_aggression = sum(_numeric(m.get("BuyerAggressionScore")) for m in recent_5) / len(recent_5)
    avg_seller_aggression = sum(_numeric(m.get("SellerAggressionScore")) for m in recent_5) / len(recent_5)

    if avg_execution > avg_distribution and avg_buyer_aggression > avg_seller_aggression:
        return "Institutional accumulation"
    if avg_distribution > avg_execution and avg_seller_aggression > avg_buyer_aggression:
        return "Institutional distribution"
    if avg_buyer_aggression > avg_seller_aggression:
        return "Buyer aggression leading"
    if avg_seller_aggression > avg_buyer_aggression:
        return "Seller aggression leading"
    return "Mixed signals"


def calculate_microstructure_score(micro_data: List[Dict[str, Any]]) -> int:
    """Calculate microstructure quality score (0-10)."""
    if not micro_data:
        return 5

    recent_5 = micro_data[:5]

    # Average category flow score
    flow_scores = [
        5 + (_numeric(m.get("BuyerAggressionScore")) - _numeric(m.get("SellerAggressionScore"))) * 5
        for m in recent_5
    ]
    avg_flow = sum(flow_scores) / len(flow_scores)

    # Average quality score
    quality_scores = [
        5 + (_numeric(m.get("LiveExecutionQualityScore")) - _numeric(m.get("LiveDistributionScore"))) * 5
        for m in recent_5
    ]
    avg_absorption = sum(quality_scores) / len(quality_scores)

    # Combined score
    combined = (avg_flow + avg_absorption) / 2

    return round(max(0, min(10, combined)))


def assess_concentration(setup_data: List[Dict[str, Any]]) -> str:
    """Assess broker concentration."""
    if not setup_data:
        return "Unknown"

    recent_5 = setup_data[:5]

    avg_bull = sum(_numeric(s.get("BullishSetupScore")) for s in recent_5) / len(recent_5)
    avg_bear = sum(_numeric(s.get("BearishSetupScore")) for s in recent_5) / len(recent_5)

    if avg_bull - avg_bear > 0.30:
        return "Strong bullish setup concentration"
    if avg_bear - avg_bull > 0.30:
        return "Strong bearish setup concentration"
    if avg_bull > avg_bear:
        return "Moderate bullish skew"
    return "Mixed or distributed flow"


def compact_broker_data(
    setup_data: List[Dict[str, Any]],
    micro_data: List[Dict[str, Any]],
    historical_data: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    """
    Compact broker flow data.
    Target: ~3,000 tokens
    """
    historical_data = historical_data or []

    if not setup_data and not micro_data:
        return {
            "data_available": False,
            "accumulation_score": 0,
            "microstructure_score": 5,
            "top_participants": {"top_buyers": [], "top_sellers": []},
            "institutional_flow": "Unknown",
            "concentration": "Unknown",
            "historical_edge": "Unknown",
        }

    # Calculate scores
    accumulation_score = calculate_accumulation_score(setup_data)
    microstructure_score = calculate_microstructure_score(micro_data)

    # Identify participants
    top_participants = identify_top_participants(setup_data)

    # Flow analysis
    institutional_flow = analyze_institutional_flow(micro_data)

    # Concentration
    concentration = assess_concentration(setup_data)

    bullish_hist = [
        _numeric(item.get("HistoricalEdgeScore"))
        for item in historical_data
        if str(item.get("EventDirection", "")).upper() == "BULL"
    ]
    bearish_hist = [
        _numeric(item.get("HistoricalEdgeScore"))
        for item in historical_data
        if str(item.get("EventDirection", "")).upper() == "BEAR"
    ]
    historical_edge = "Unavailable"
    if bullish_hist or bearish_hist:
        avg_bull_hist = sum(bullish_hist) / len(bullish_hist) if bullish_hist else 0.0
        avg_bear_hist = sum(bearish_hist) / len(bearish_hist) if bearish_hist else 0.0
        if avg_bull_hist > avg_bear_hist:
            historical_edge = "Bullish historical broker edge"
        elif avg_bear_hist > avg_bull_hist:
            historical_edge = "Bearish historical broker edge"
        else:
            historical_edge = "Balanced historical broker edge"

    # Recent activity summary (last 5 days)
    recent_activity = []
    for setup in setup_data[:5]:
        recent_activity.append({
            "date": setup.get("TradeDate").isoformat() if setup.get("TradeDate") else None,
            "bullish_setup_score": setup.get("BullishSetupScore"),
            "bearish_setup_score": setup.get("BearishSetupScore"),
            "top_buyer": setup.get("TopBuyBroker"),
            "top_seller": setup.get("TopSellBroker")
        })

    return {
        "data_available": True,
        "accumulation_score": accumulation_score,
        "microstructure_score": microstructure_score,
        "top_participants": top_participants,
        "institutional_flow": institutional_flow,
        "concentration": concentration,
        "historical_edge": historical_edge,
        "recent_activity": recent_activity,
        "setup_days": len(setup_data),
        "micro_days": len(micro_data),
        "historical_rows": len(historical_data),
    }
