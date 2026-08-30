"""Production notification-only reference logic for GEX_XLE_GEX_REGIME_REBOUND 1.0.0-production.
Broker execution is HARD_DISABLED. User decides manual order placement.
"""
STRATEGY_CODE='GEX_XLE_GEX_REGIME_REBOUND'
VERSION='1.0.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
ENABLED=True
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
SIGNAL_CODE='XLE_GEX_REGIME_ENERGY_REBOUND'
DIRECTION='LONG'
HOLDING_PERIOD='D5'
TRIGGER='QQQ_SafeGEXVolRank60 <= 0.60 AND GEX_ZScore_60day > 0'
PROHIBITED_INPUTS={"TomorrowChange","Next2DaysChange","Next5DaysChange","Next10DaysChange","Next20DaysChange","GEX_Vol_Percentile","GEX_HighVolatility","GEX_StableRegime","Setup_Dual_Squeeze"}

def evaluate(features):
    missing=[x for x in ['QQQ_SafeGEXVolRank60', 'GEX_ZScore_60day'] if x not in features or features[x] is None]
    if missing:
        return {"state":"NOT_READY","missing":missing}
    matched=bool(features["QQQ_SafeGEXVolRank60"] <= 0.60 and features["GEX_ZScore_60day"] > 0)
    if matched:
        return {"state":"READY","signal_code":SIGNAL_CODE,"action":"PLAN_ENTRY","direction":DIRECTION,"holding_period":HOLDING_PERIOD,"notify":True}
    return {"state":"READY","signal_code":"NO_SIGNAL","action":"NONE","direction":"NONE","holding_period":"NONE","notify":False}
