"""Deterministic production reference logic for GEX_MU_CAPITALTYPE 1.1.0-production.
Signal generation/notification runs in Production. Broker execution is HARD_DISABLED; user decides whether to place orders manually.
Future-return target columns and the known leaking GEX_Vol_Percentile family are prohibited inputs.
"""
STRATEGY_CODE='GEX_MU_CAPITALTYPE'
VERSION='1.1.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
RULES=[{'signal_code': 'MU_DOWN_DAY_INTENT_REVERSAL_HIGH', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': '(PriceChangePct < -0.10 AND IntentRatioChangePct < -10.0) AND (QQQ.GEX_Trending_Up == 1 OR MU.GEX_ZScore < -1.0)'}, {'signal_code': 'MU_DOWN_DAY_INTENT_REVERSAL_WEAK', 'direction': 'LONG', 'action': 'WATCH', 'holding_period': 'D5', 'trigger_condition': '(PriceChangePct < -0.10 AND IntentRatioChangePct < -10.0) AND (NOT(QQQ.GEX_Trending_Up == 1 OR MU.GEX_ZScore < -1.0))'}, {'signal_code': 'MU_FEAR_SHOCK_REVERSAL', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': 'PriceChangePct < -0.10 AND PCRChangePct > 5.0 AND PCRAbsShockPct60 >= 0.75'}, {'signal_code': 'MU_CALL_WASHOUT_UPTREND', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D2', 'trigger_condition': 'CallBuyShareChange < 0 AND CallBuyShareAbsShockPct60 >= 0.75 AND Momentum3Pct > 1.0'}, {'signal_code': 'MU_PUT_BUY_MOMENTUM_BREAKDOWN', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D1', 'trigger_condition': 'PutBuyShareChange > 0 AND PutBuyShareAbsShockPct60 >= 0.75 AND Momentum3Pct < -1.0'}]

def evaluate(features):
    out=[]
    def f(name):
        return features[name]
    if f("PriceChangePct") < -0.10 and f("IntentRatioChangePct") < -10.0:
        if f("QQQ_GEX_Trending_Up") == 1 or f("MU_GEX_ZScore") < -1.0: out.append("MU_DOWN_DAY_INTENT_REVERSAL_HIGH")
        else: out.append("MU_DOWN_DAY_INTENT_REVERSAL_WEAK")
    if f("PriceChangePct") < -0.10 and f("PCRChangePct") > 5.0 and f("PCRAbsShockPct60") >= 0.75: out.append("MU_FEAR_SHOCK_REVERSAL")
    if f("CallBuyShareChange") < 0 and f("CallBuyShareAbsShockPct60") >= 0.75 and f("Momentum3Pct") > 1.0: out.append("MU_CALL_WASHOUT_UPTREND")
    if f("PutBuyShareChange") > 0 and f("PutBuyShareAbsShockPct60") >= 0.75 and f("Momentum3Pct") < -1.0: out.append("MU_PUT_BUY_MOMENTUM_BREAKDOWN")
    return out or ["NO_SIGNAL"]
