"""Deterministic strategy logic contract for GDX v1.0.0.
I/O, calendars, persistence, authentication and notifications are external runtime concerns.
Percentiles MUST be causal prior-60 ranks with current observation excluded and <= tie handling.
"""
STRATEGY_CODE = "GEX_GDX_CAPITALTYPE"
VERSION = "1.0.0"
RULES = [{'signal_code': 'GDX_CALL_BUY_SHARE_SURGE', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': 'BCShareChange > 0 AND BCShareAbsShockPct60 >= 0.75'}]

def evaluate(features):
    out=[]
    if features["BCShareChange"] > 0 and features["BCShareAbsShockPct60"] >= 0.75:
        out.append("GDX_CALL_BUY_SHARE_SURGE")
    return out or ["NO_SIGNAL"]
