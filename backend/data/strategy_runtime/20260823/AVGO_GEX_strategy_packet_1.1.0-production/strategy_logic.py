"""Deterministic production reference logic for GEX_AVGO_CAPITALTYPE 1.1.0-production.
Signal generation/notification runs in Production. Broker execution is HARD_DISABLED; user decides whether to place orders manually.
Future-return target columns and the known leaking GEX_Vol_Percentile family are prohibited inputs.
"""
STRATEGY_CODE='GEX_AVGO_CAPITALTYPE'
VERSION='1.1.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
RULES=[{'signal_code': 'AVGO_BULLISH_INTENT_RALLY_EXHAUSTION_HIGH', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': '(PriceChangePct > 0.10 AND IntentRatioChangePct < -10.0) AND (QQQ.Is_Potential_Swing_Up == 1 OR QQQ.TodayChange < 0)'}, {'signal_code': 'AVGO_BULLISH_INTENT_RALLY_EXHAUSTION_WEAK', 'direction': 'SHORT', 'action': 'WATCH', 'holding_period': 'D5', 'trigger_condition': '(PriceChangePct > 0.10 AND IntentRatioChangePct < -10.0) AND (NOT(QQQ.Is_Potential_Swing_Up == 1 OR QQQ.TodayChange < 0))'}]

def evaluate(features):
    out=[]
    def f(name):
        return features[name]
    if f("PriceChangePct") > 0.10 and f("IntentRatioChangePct") < -10.0:
        out.append("AVGO_BULLISH_INTENT_RALLY_EXHAUSTION_HIGH" if (f("QQQ_Is_Potential_Swing_Up")==1 or f("QQQ_TodayChange")<0) else "AVGO_BULLISH_INTENT_RALLY_EXHAUSTION_WEAK")
    return out or ["NO_SIGNAL"]
