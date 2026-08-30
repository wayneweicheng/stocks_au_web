"""Production notification-only reference logic for GEX_ZS_CONTROLLED_BULL_REBOUND 1.0.0-production.
Broker execution is HARD_DISABLED. User decides manual order placement.
"""
STRATEGY_CODE='GEX_ZS_CONTROLLED_BULL_REBOUND'
VERSION='1.0.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
ENABLED=True
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
SIGNAL_CODE='ZS_CONTROLLED_BULL_FLOW_REBOUND'
DIRECTION='LONG'
HOLDING_PERIOD='D3'
TRIGGER='BTC_chg5 <= 2.1 AND BullShareChgAbsRank60 <= 0.65'
PROHIBITED_INPUTS={"TomorrowChange","Next2DaysChange","Next5DaysChange","Next10DaysChange","Next20DaysChange","GEX_Vol_Percentile","GEX_HighVolatility","GEX_StableRegime","Setup_Dual_Squeeze"}

def evaluate(features):
    missing=[x for x in ['BTC_chg5', 'BullShareChgAbsRank60'] if x not in features or features[x] is None]
    if missing:
        return {"state":"NOT_READY","missing":missing}
    matched=bool(features["BTC_chg5"] <= 2.1 and features["BullShareChgAbsRank60"] <= 0.65)
    if matched:
        return {"state":"READY","signal_code":SIGNAL_CODE,"action":"PLAN_ENTRY","direction":DIRECTION,"holding_period":HOLDING_PERIOD,"notify":True}
    return {"state":"READY","signal_code":"NO_SIGNAL","action":"NONE","direction":"NONE","holding_period":"NONE","notify":False}
