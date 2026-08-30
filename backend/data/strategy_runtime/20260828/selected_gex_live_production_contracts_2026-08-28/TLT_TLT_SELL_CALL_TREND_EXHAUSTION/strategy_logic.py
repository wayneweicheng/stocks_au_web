"""Production notification-only reference logic for GEX_TLT_SELL_CALL_EXHAUSTION 1.0.0-production.
Broker execution is HARD_DISABLED. User decides manual order placement.
"""
STRATEGY_CODE='GEX_TLT_SELL_CALL_EXHAUSTION'
VERSION='1.0.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
ENABLED=True
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
SIGNAL_CODE='TLT_SELL_CALL_TREND_EXHAUSTION'
DIRECTION='SHORT'
HOLDING_PERIOD='D5'
TRIGGER='PriceDistSMA50Pct >= -1.0 AND SCShareChgRank60 >= 0.60'
PROHIBITED_INPUTS={"TomorrowChange","Next2DaysChange","Next5DaysChange","Next10DaysChange","Next20DaysChange","GEX_Vol_Percentile","GEX_HighVolatility","GEX_StableRegime","Setup_Dual_Squeeze"}

def evaluate(features):
    missing=[x for x in ['PriceDistSMA50Pct', 'SCShareChgRank60'] if x not in features or features[x] is None]
    if missing:
        return {"state":"NOT_READY","missing":missing}
    matched=bool(features["PriceDistSMA50Pct"] >= -1.0 and features["SCShareChgRank60"] >= 0.60)
    if matched:
        return {"state":"READY","signal_code":SIGNAL_CODE,"action":"PLAN_ENTRY","direction":DIRECTION,"holding_period":HOLDING_PERIOD,"notify":True}
    return {"state":"READY","signal_code":"NO_SIGNAL","action":"NONE","direction":"NONE","holding_period":"NONE","notify":False}
