"""Deterministic strategy logic contract for AMZN v1.0.0.
I/O, calendars, persistence, authentication and notifications are external runtime concerns.
Percentiles MUST be causal prior-60 ranks with current observation excluded and <= tie handling.
"""
STRATEGY_CODE = "GEX_AMZN_CAPITALTYPE"
VERSION = "1.0.0"
RULES = [{'signal_code': 'AMZN_BP_SHARE_SHOCK_REBOUND', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': 'BPShareChange > 0 AND BPShareAbsShockPct60 >= 0.75'}]

def evaluate(features):
    out=[]
    if features["BPShareChange"] > 0 and features["BPShareAbsShockPct60"] >= 0.75:
        out.append("AMZN_BP_SHARE_SHOCK_REBOUND")
    return out or ["NO_SIGNAL"]
