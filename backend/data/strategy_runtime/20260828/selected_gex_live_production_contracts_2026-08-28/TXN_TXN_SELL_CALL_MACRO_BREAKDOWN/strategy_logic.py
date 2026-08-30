"""Production notification-only reference logic for GEX_TXN_SELL_CALL_MACRO 1.0.0-production.
Broker execution is HARD_DISABLED. User decides manual order placement.
"""
STRATEGY_CODE='GEX_TXN_SELL_CALL_MACRO'
VERSION='1.0.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
ENABLED=True
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
SIGNAL_CODE='TXN_SELL_CALL_MACRO_BREAKDOWN'
DIRECTION='SHORT'
HOLDING_PERIOD='D5'
TRIGGER='SCShare >= 0.0284 AND QQQ_BuyCall_GEXDeltaPerc_Rank60 <= 0.65 AND Gold_chg5 >= -1.0'
PROHIBITED_INPUTS={"TomorrowChange","Next2DaysChange","Next5DaysChange","Next10DaysChange","Next20DaysChange","GEX_Vol_Percentile","GEX_HighVolatility","GEX_StableRegime","Setup_Dual_Squeeze"}

def evaluate(features):
    missing=[x for x in ['SCShare', 'QQQ_BuyCall_GEXDeltaPerc_Rank60', 'Gold_chg5'] if x not in features or features[x] is None]
    if missing:
        return {"state":"NOT_READY","missing":missing}
    matched=bool(features["SCShare"] >= 0.0284 and features["QQQ_BuyCall_GEXDeltaPerc_Rank60"] <= 0.65 and features["Gold_chg5"] >= -1.0)
    if matched:
        return {"state":"READY","signal_code":SIGNAL_CODE,"action":"PLAN_ENTRY","direction":DIRECTION,"holding_period":HOLDING_PERIOD,"notify":True}
    return {"state":"READY","signal_code":"NO_SIGNAL","action":"NONE","direction":"NONE","holding_period":"NONE","notify":False}
