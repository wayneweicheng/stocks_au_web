"""Deterministic strategy logic contract for PLTR v1.0.0.
I/O, calendars, persistence, authentication and notifications are external runtime concerns.
Percentiles MUST be causal prior-60 ranks with current observation excluded and <= tie handling.
"""
STRATEGY_CODE = "GEX_PLTR_CAPITALTYPE"
VERSION = "1.0.0"
RULES = [{'signal_code': 'PLTR_SMALL_DIP_FEAR_CONTINUATION', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D2', 'trigger_condition': 'PriceChangePct < -0.10 AND PCRChangePct > 5.0 AND AbsPriceMovePct60 <= 0.50'}]

def evaluate(features):
    out=[]
    if features["PriceChangePct"] < -0.10 and features["PCRChangePct"] > 5.0 and features["AbsPriceMovePct60"] <= 0.50:
        out.append("PLTR_SMALL_DIP_FEAR_CONTINUATION")
    return out or ["NO_SIGNAL"]
