"""Production notification-only reference logic for GEX_ORCL_PUT_FLOW_ROTATION 1.0.0-production.
Broker execution is HARD_DISABLED. User decides manual order placement.
"""
STRATEGY_CODE='GEX_ORCL_PUT_FLOW_ROTATION'
VERSION='1.0.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
ENABLED=True
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
SIGNAL_CODE='ORCL_PUT_FLOW_ROTATION_BREAKDOWN'
DIRECTION='SHORT'
HOLDING_PERIOD='D3'
TRIGGER='PutBuyShareChgAbsRank60 >= 0.65 AND BuyCall_GEXDeltaPerc_Rank60 <= 0.48'
PROHIBITED_INPUTS={"TomorrowChange","Next2DaysChange","Next5DaysChange","Next10DaysChange","Next20DaysChange","GEX_Vol_Percentile","GEX_HighVolatility","GEX_StableRegime","Setup_Dual_Squeeze"}

def evaluate(features):
    missing=[x for x in ['PutBuyShareChgAbsRank60', 'BuyCall_GEXDeltaPerc_Rank60'] if x not in features or features[x] is None]
    if missing:
        return {"state":"NOT_READY","missing":missing}
    matched=bool(features["PutBuyShareChgAbsRank60"] >= 0.65 and features["BuyCall_GEXDeltaPerc_Rank60"] <= 0.48)
    if matched:
        return {"state":"READY","signal_code":SIGNAL_CODE,"action":"PLAN_ENTRY","direction":DIRECTION,"holding_period":HOLDING_PERIOD,"notify":True}
    return {"state":"READY","signal_code":"NO_SIGNAL","action":"NONE","direction":"NONE","holding_period":"NONE","notify":False}
