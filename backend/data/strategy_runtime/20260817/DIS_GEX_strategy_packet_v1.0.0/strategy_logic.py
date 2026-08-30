"""Deterministic strategy logic contract for DIS v1.0.0.
I/O, calendars, persistence, authentication and notifications are external runtime concerns.
Percentiles MUST be causal prior-60 ranks with current observation excluded and <= tie handling.
"""
STRATEGY_CODE = "GEX_DIS_CAPITALTYPE"
VERSION = "1.0.0"
RULES = [{'signal_code': 'DIS_LOW_GEX_RALLY_FEAR_FADE', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': 'PriceChangePct > 0.10 AND PCRChangePct > 5.0 AND TotalGEXPct60 <= 0.30'}]

def evaluate(features):
    out=[]
    if features["PriceChangePct"] > 0.10 and features["PCRChangePct"] > 5.0 and features["TotalGEXPct60"] <= 0.30:
        out.append("DIS_LOW_GEX_RALLY_FEAR_FADE")
    return out or ["NO_SIGNAL"]
