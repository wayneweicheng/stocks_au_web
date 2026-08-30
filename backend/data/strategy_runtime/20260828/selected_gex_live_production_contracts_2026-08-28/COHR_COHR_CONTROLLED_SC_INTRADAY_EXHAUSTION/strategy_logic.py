"""Production notification-only reference logic for GEX_COHR_SC_INTRADAY_EXHAUSTION 1.0.0-production.
Broker execution is HARD_DISABLED. User decides manual order placement.
"""
STRATEGY_CODE='GEX_COHR_SC_INTRADAY_EXHAUSTION'
VERSION='1.0.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
ENABLED=True
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
SIGNAL_CODE='COHR_CONTROLLED_SC_INTRADAY_EXHAUSTION'
DIRECTION='SHORT'
HOLDING_PERIOD='D5'
TRIGGER='SCShareRank60 <= 0.60 AND PX_WholeDayRet >= -4.0 AND PX_RTHRet >= -2.5'
PROHIBITED_INPUTS={"TomorrowChange","Next2DaysChange","Next5DaysChange","Next10DaysChange","Next20DaysChange","GEX_Vol_Percentile","GEX_HighVolatility","GEX_StableRegime","Setup_Dual_Squeeze"}

def evaluate(features):
    missing=[x for x in ['SCShareRank60', 'PX_WholeDayRet', 'PX_RTHRet'] if x not in features or features[x] is None]
    if missing:
        return {"state":"NOT_READY","missing":missing}
    matched=bool(features["SCShareRank60"] <= 0.60 and features["PX_WholeDayRet"] >= -4.0 and features["PX_RTHRet"] >= -2.5)
    if matched:
        return {"state":"READY","signal_code":SIGNAL_CODE,"action":"PLAN_ENTRY","direction":DIRECTION,"holding_period":HOLDING_PERIOD,"notify":True}
    return {"state":"READY","signal_code":"NO_SIGNAL","action":"NONE","direction":"NONE","holding_period":"NONE","notify":False}
