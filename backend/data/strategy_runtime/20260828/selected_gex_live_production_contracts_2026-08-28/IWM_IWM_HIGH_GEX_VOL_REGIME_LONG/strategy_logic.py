"""Production notification-only reference logic for GEX_IWM_CROSS_GEX_VOL_REVERSAL 1.0.0-production.
Broker execution is HARD_DISABLED. User decides manual order placement.
"""
STRATEGY_CODE='GEX_IWM_CROSS_GEX_VOL_REVERSAL'
VERSION='1.0.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
ENABLED=True
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
SIGNAL_CODE='IWM_HIGH_GEX_VOL_REGIME_LONG'
DIRECTION='LONG'
HOLDING_PERIOD='D5'
TRIGGER='SafeGEXVolRank60 >= 0.60 AND SPY_SafeGEXVolRank60 >= 0.65'
PROHIBITED_INPUTS={"TomorrowChange","Next2DaysChange","Next5DaysChange","Next10DaysChange","Next20DaysChange","GEX_Vol_Percentile","GEX_HighVolatility","GEX_StableRegime","Setup_Dual_Squeeze"}

def evaluate(features):
    missing=[x for x in ['SafeGEXVolRank60', 'SPY_SafeGEXVolRank60'] if x not in features or features[x] is None]
    if missing:
        return {"state":"NOT_READY","missing":missing}
    matched=bool(features["SafeGEXVolRank60"] >= 0.60 and features["SPY_SafeGEXVolRank60"] >= 0.65)
    if matched:
        return {"state":"READY","signal_code":SIGNAL_CODE,"action":"PLAN_ENTRY","direction":DIRECTION,"holding_period":HOLDING_PERIOD,"notify":True}
    return {"state":"READY","signal_code":"NO_SIGNAL","action":"NONE","direction":"NONE","holding_period":"NONE","notify":False}
