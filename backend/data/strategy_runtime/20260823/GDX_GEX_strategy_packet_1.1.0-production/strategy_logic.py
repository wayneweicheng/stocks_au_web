"""Deterministic production reference logic for GEX_GDX_CAPITALTYPE 1.1.0-production.
Signal generation/notification runs in Production. Broker execution is HARD_DISABLED; user decides whether to place orders manually.
Future-return target columns and the known leaking GEX_Vol_Percentile family are prohibited inputs.
"""
STRATEGY_CODE='GEX_GDX_CAPITALTYPE'
VERSION='1.1.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
RULES=[{'signal_code': 'GDX_CALL_BUY_SHARE_SURGE_HIGH', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': '(BCShareChange > 0 AND BCShareAbsShockPct60 >= 0.75) AND (SPY.Price_Above_SMA20 == 0)'}, {'signal_code': 'GDX_CALL_BUY_SHARE_SURGE_STANDARD', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': '(BCShareChange > 0 AND BCShareAbsShockPct60 >= 0.75) AND (NOT(SPY.Price_Above_SMA20 == 0))'}]

def evaluate(features):
    out=[]
    def f(name):
        return features[name]
    if f("BCShareChange") > 0 and f("BCShareAbsShockPct60") >= 0.75:
        out.append("GDX_CALL_BUY_SHARE_SURGE_HIGH" if f("SPY_Price_Above_SMA20")==0 else "GDX_CALL_BUY_SHARE_SURGE_STANDARD")
    return out or ["NO_SIGNAL"]
