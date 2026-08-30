"""Deterministic strategy logic contract for MU v1.0.0.
I/O, calendars, persistence, authentication and notifications are external runtime concerns.
Percentiles MUST be causal prior-60 ranks with current observation excluded and <= tie handling.
"""
STRATEGY_CODE = "GEX_MU_CAPITALTYPE"
VERSION = "1.0.0"
RULES = [{'signal_code': 'MU_DOWN_DAY_INTENT_REVERSAL', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': 'PriceChangePct < -0.10 AND IntentRatioChangePct < -10.0'}, {'signal_code': 'MU_FEAR_SHOCK_REVERSAL', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': 'PriceChangePct < -0.10 AND PCRChangePct > 5.0 AND PCRAbsShockPct60 >= 0.75'}, {'signal_code': 'MU_CALL_WASHOUT_UPTREND', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D2', 'trigger_condition': 'CallBuyShareChange < 0 AND CallBuyShareAbsShockPct60 >= 0.75 AND Momentum3Pct > 1.0'}, {'signal_code': 'MU_PUT_BUY_MOMENTUM_BREAKDOWN', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D1', 'trigger_condition': 'PutBuyShareChange > 0 AND PutBuyShareAbsShockPct60 >= 0.75 AND Momentum3Pct < -1.0'}]

def evaluate(features):
    out=[]
    if features["PriceChangePct"] < -0.10 and features["IntentRatioChangePct"] < -10.0:
        out.append("MU_DOWN_DAY_INTENT_REVERSAL")
    if features["PriceChangePct"] < -0.10 and features["PCRChangePct"] > 5.0 and features["PCRAbsShockPct60"] >= 0.75:
        out.append("MU_FEAR_SHOCK_REVERSAL")
    if features["CallBuyShareChange"] < 0 and features["CallBuyShareAbsShockPct60"] >= 0.75 and features["Momentum3Pct"] > 1.0:
        out.append("MU_CALL_WASHOUT_UPTREND")
    if features["PutBuyShareChange"] > 0 and features["PutBuyShareAbsShockPct60"] >= 0.75 and features["Momentum3Pct"] < -1.0:
        out.append("MU_PUT_BUY_MOMENTUM_BREAKDOWN")
    return out or ["NO_SIGNAL"]
