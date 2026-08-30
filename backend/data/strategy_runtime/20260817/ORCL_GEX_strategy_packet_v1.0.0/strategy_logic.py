"""Deterministic strategy logic contract for ORCL v1.0.0.
I/O, calendars, persistence, authentication and notifications are external runtime concerns.
Percentiles MUST be causal prior-60 ranks with current observation excluded and <= tie handling.
"""
STRATEGY_CODE = "GEX_ORCL_CAPITALTYPE"
VERSION = "1.0.0"
RULES = [{'signal_code': 'ORCL_FAILED_BULLISH_SUPPORT', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D2', 'trigger_condition': 'Close < VWAP AND BullSharePct60 >= 0.65'}]

def evaluate(features):
    out=[]
    if features["Close"] < features["VWAP"] and features["BullSharePct60"] >= 0.65:
        out.append("ORCL_FAILED_BULLISH_SUPPORT")
    return out or ["NO_SIGNAL"]
