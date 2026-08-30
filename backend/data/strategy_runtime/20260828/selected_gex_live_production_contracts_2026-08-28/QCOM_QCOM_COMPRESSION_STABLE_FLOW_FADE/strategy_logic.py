"""Production notification-only reference logic for GEX_QCOM_COMPRESSION_FLOW_FADE 1.0.0-production.
Broker execution is HARD_DISABLED. User decides manual order placement.
"""
STRATEGY_CODE='GEX_QCOM_COMPRESSION_FLOW_FADE'
VERSION='1.0.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
ENABLED=True
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
SIGNAL_CODE='QCOM_COMPRESSION_STABLE_FLOW_FADE'
DIRECTION='SHORT'
HOLDING_PERIOD='D1'
TRIGGER='BB_Bandwidth <= 0.346 AND BullShareChgAbsRank60 <= 0.65'
PROHIBITED_INPUTS={"TomorrowChange","Next2DaysChange","Next5DaysChange","Next10DaysChange","Next20DaysChange","GEX_Vol_Percentile","GEX_HighVolatility","GEX_StableRegime","Setup_Dual_Squeeze"}

def evaluate(features):
    missing=[x for x in ['BB_Bandwidth', 'BullShareChgAbsRank60'] if x not in features or features[x] is None]
    if missing:
        return {"state":"NOT_READY","missing":missing}
    matched=bool(features["BB_Bandwidth"] <= 0.346 and features["BullShareChgAbsRank60"] <= 0.65)
    if matched:
        return {"state":"READY","signal_code":SIGNAL_CODE,"action":"PLAN_ENTRY","direction":DIRECTION,"holding_period":HOLDING_PERIOD,"notify":True}
    return {"state":"READY","signal_code":"NO_SIGNAL","action":"NONE","direction":"NONE","holding_period":"NONE","notify":False}
