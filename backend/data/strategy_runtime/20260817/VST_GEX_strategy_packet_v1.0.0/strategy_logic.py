"""Deterministic strategy logic contract for VST v1.0.0.
I/O, calendars, persistence, authentication and notifications are external runtime concerns.
Percentiles MUST be causal prior-60 ranks with current observation excluded and <= tie handling.
"""
STRATEGY_CODE = "GEX_VST_CAPITALTYPE"
VERSION = "1.0.0"
RULES = [{'signal_code': 'VST_DOUBLE_DOWN_CONTINUATION_D1', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D1', 'trigger_condition': 'PriceChangePct < -0.10 AND PCRChangePct < -5.0'}, {'signal_code': 'VST_DOUBLE_DOWN_REVERSAL_D5', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': 'PriceChangePct < -0.10 AND PCRChangePct < -5.0'}]

def evaluate(features):
    out=[]
    if features["PriceChangePct"] < -0.10 and features["PCRChangePct"] < -5.0:
        out.append("VST_DOUBLE_DOWN_CONTINUATION_D1")
    if features["PriceChangePct"] < -0.10 and features["PCRChangePct"] < -5.0:
        out.append("VST_DOUBLE_DOWN_REVERSAL_D5")
    return out or ["NO_SIGNAL"]
