"""Deterministic strategy logic contract for TSLA v1.0.0.
I/O, calendars, persistence, authentication and notifications are external runtime concerns.
Percentiles MUST be causal prior-60 ranks with current observation excluded and <= tie handling.
"""
STRATEGY_CODE = "GEX_TSLA_CAPITALTYPE"
VERSION = "1.0.0"
RULES = [{'signal_code': 'TSLA_BEARISH_RALLY_DIVERGENCE', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D3', 'trigger_condition': 'PriceChangePct > 0.10 AND IntentRatioChangePct > 10.0 AND SCAbsPct60 >= 0.65'}, {'signal_code': 'TSLA_FAILED_PUT_SELL_SUPPORT', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D3', 'trigger_condition': 'PriceChangePct < -0.10 AND PCRChangePct < -5.0 AND SPSharePct60 >= 0.65'}, {'signal_code': 'TSLA_FAILED_RALLY', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D1', 'trigger_condition': 'VWAPDiffPct < -0.15 AND NetBullSharePct60 <= 0.35 AND Momentum3Pct > 1.0'}, {'signal_code': 'TSLA_CROWDED_BULLISH_EXHAUSTION', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D3', 'trigger_condition': 'PutBuyShareChange < 0 AND PutBuyShareAbsShockPct60 >= 0.75 AND BullSharePct60 >= 0.65'}]

def evaluate(features):
    out=[]
    if features["PriceChangePct"] > 0.10 and features["IntentRatioChangePct"] > 10.0 and features["SCAbsPct60"] >= 0.65:
        out.append("TSLA_BEARISH_RALLY_DIVERGENCE")
    if features["PriceChangePct"] < -0.10 and features["PCRChangePct"] < -5.0 and features["SPSharePct60"] >= 0.65:
        out.append("TSLA_FAILED_PUT_SELL_SUPPORT")
    if features["VWAPDiffPct"] < -0.15 and features["NetBullSharePct60"] <= 0.35 and features["Momentum3Pct"] > 1.0:
        out.append("TSLA_FAILED_RALLY")
    if features["PutBuyShareChange"] < 0 and features["PutBuyShareAbsShockPct60"] >= 0.75 and features["BullSharePct60"] >= 0.65:
        out.append("TSLA_CROWDED_BULLISH_EXHAUSTION")
    return out or ["NO_SIGNAL"]
