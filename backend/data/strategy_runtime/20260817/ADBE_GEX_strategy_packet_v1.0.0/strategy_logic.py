"""Deterministic strategy logic contract for ADBE v1.0.0.
I/O, calendars, persistence, authentication and notifications are external runtime concerns.
Percentiles MUST be causal prior-60 ranks with current observation excluded and <= tie handling.
"""
STRATEGY_CODE = "GEX_ADBE_CAPITALTYPE"
VERSION = "1.0.0"
RULES = [{'signal_code': 'ADBE_CONCENTRATED_BULLISH_REGIME', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': 'GEXConcentrationPct60 >= 0.70 AND NetBullSharePct60 >= 0.70'}]

def evaluate(features):
    out=[]
    if features["GEXConcentrationPct60"] >= 0.70 and features["NetBullSharePct60"] >= 0.70:
        out.append("ADBE_CONCENTRATED_BULLISH_REGIME")
    return out or ["NO_SIGNAL"]
