"""Deterministic production reference logic for GEX_ORCL_CAPITALTYPE 1.1.0-production.
Signal generation/notification runs in Production. Broker execution is HARD_DISABLED; user decides whether to place orders manually.
Future-return target columns and the known leaking GEX_Vol_Percentile family are prohibited inputs.
"""
STRATEGY_CODE='GEX_ORCL_CAPITALTYPE'
VERSION='1.1.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
RULES=[{'signal_code': 'ORCL_FAILED_BULLISH_SUPPORT_HIGH', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D2', 'trigger_condition': '(Close < VWAP AND BullSharePct60 >= 0.65) AND (ORCL.GEXChange < -10.0)'}, {'signal_code': 'ORCL_FAILED_BULLISH_SUPPORT_STANDARD', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D2', 'trigger_condition': '(Close < VWAP AND BullSharePct60 >= 0.65) AND (NOT(ORCL.GEXChange < -10.0))'}]

def evaluate(features):
    out=[]
    def f(name):
        return features[name]
    if f("Close") < f("VWAP") and f("BullSharePct60") >= 0.65:
        out.append("ORCL_FAILED_BULLISH_SUPPORT_HIGH" if f("ORCL_GEXChange")<-10.0 else "ORCL_FAILED_BULLISH_SUPPORT_STANDARD")
    return out or ["NO_SIGNAL"]
