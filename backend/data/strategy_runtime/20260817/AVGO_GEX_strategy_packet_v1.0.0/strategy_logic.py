"""Deterministic strategy logic contract for AVGO v1.0.0.
I/O, calendars, persistence, authentication and notifications are external runtime concerns.
Percentiles MUST be causal prior-60 ranks with current observation excluded and <= tie handling.
"""
STRATEGY_CODE = "GEX_AVGO_CAPITALTYPE"
VERSION = "1.0.0"
RULES = [{'signal_code': 'AVGO_BULLISH_INTENT_RALLY_EXHAUSTION', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': 'PriceChangePct > 0.10 AND IntentRatioChangePct < -10.0'}]

def evaluate(features):
    out=[]
    if features["PriceChangePct"] > 0.10 and features["IntentRatioChangePct"] < -10.0:
        out.append("AVGO_BULLISH_INTENT_RALLY_EXHAUSTION")
    return out or ["NO_SIGNAL"]
