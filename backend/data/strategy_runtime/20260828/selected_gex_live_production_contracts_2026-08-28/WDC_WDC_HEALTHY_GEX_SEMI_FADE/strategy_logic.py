"""Production notification-only reference logic for GEX_WDC_HEALTHY_GEX_FADE 1.0.0-production.
Broker execution is HARD_DISABLED. User decides manual order placement.
"""
STRATEGY_CODE='GEX_WDC_HEALTHY_GEX_FADE'
VERSION='1.0.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
ENABLED=True
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
SIGNAL_CODE='WDC_HEALTHY_GEX_SEMI_FADE'
DIRECTION='SHORT'
HOLDING_PERIOD='D5'
TRIGGER='GEX_Rank60 >= 0.20 AND QQQ_GEX_ZScore_60day > -1.5'
PROHIBITED_INPUTS={"TomorrowChange","Next2DaysChange","Next5DaysChange","Next10DaysChange","Next20DaysChange","GEX_Vol_Percentile","GEX_HighVolatility","GEX_StableRegime","Setup_Dual_Squeeze"}

def evaluate(features):
    missing=[x for x in ['GEX_Rank60', 'QQQ_GEX_ZScore_60day'] if x not in features or features[x] is None]
    if missing:
        return {"state":"NOT_READY","missing":missing}
    matched=bool(features["GEX_Rank60"] >= 0.20 and features["QQQ_GEX_ZScore_60day"] > -1.5)
    if matched:
        return {"state":"READY","signal_code":SIGNAL_CODE,"action":"PLAN_ENTRY","direction":DIRECTION,"holding_period":HOLDING_PERIOD,"notify":True}
    return {"state":"READY","signal_code":"NO_SIGNAL","action":"NONE","direction":"NONE","holding_period":"NONE","notify":False}
