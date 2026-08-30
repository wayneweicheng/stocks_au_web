"""Production notification-only reference logic for GEX_CRWD_CONTROLLED_SC_LONG 1.0.0-production.
Broker execution is HARD_DISABLED. User decides manual order placement.
"""
STRATEGY_CODE='GEX_CRWD_CONTROLLED_SC_LONG'
VERSION='1.0.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
ENABLED=True
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
SIGNAL_CODE='CRWD_CONTROLLED_SC_ACTIVITY_LONG'
DIRECTION='LONG'
HOLDING_PERIOD='D1'
TRIGGER='SCOptionCountChg_Rank60 <= 0.80 AND Prev2DaysChange >= -1.0'
PROHIBITED_INPUTS={"TomorrowChange","Next2DaysChange","Next5DaysChange","Next10DaysChange","Next20DaysChange","GEX_Vol_Percentile","GEX_HighVolatility","GEX_StableRegime","Setup_Dual_Squeeze"}

def evaluate(features):
    missing=[x for x in ['SCOptionCountChg_Rank60', 'Prev2DaysChange'] if x not in features or features[x] is None]
    if missing:
        return {"state":"NOT_READY","missing":missing}
    matched=bool(features["SCOptionCountChg_Rank60"] <= 0.80 and features["Prev2DaysChange"] >= -1.0)
    if matched:
        return {"state":"READY","signal_code":SIGNAL_CODE,"action":"PLAN_ENTRY","direction":DIRECTION,"holding_period":HOLDING_PERIOD,"notify":True}
    return {"state":"READY","signal_code":"NO_SIGNAL","action":"NONE","direction":"NONE","holding_period":"NONE","notify":False}
