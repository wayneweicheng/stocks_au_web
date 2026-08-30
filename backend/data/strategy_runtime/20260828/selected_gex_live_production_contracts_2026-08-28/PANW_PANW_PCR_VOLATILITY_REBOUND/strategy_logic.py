"""Production notification-only reference logic for GEX_PANW_PCR_VOL_REBOUND 1.0.0-production.
Broker execution is HARD_DISABLED. User decides manual order placement.
"""
STRATEGY_CODE='GEX_PANW_PCR_VOL_REBOUND'
VERSION='1.0.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
ENABLED=True
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
SIGNAL_CODE='PANW_PCR_VOLATILITY_REBOUND'
DIRECTION='LONG'
HOLDING_PERIOD='D5'
TRIGGER='ABS(PCRChangePct) >= 10.0 AND QQQ_BB_Bandwidth >= 0.07'
PROHIBITED_INPUTS={"TomorrowChange","Next2DaysChange","Next5DaysChange","Next10DaysChange","Next20DaysChange","GEX_Vol_Percentile","GEX_HighVolatility","GEX_StableRegime","Setup_Dual_Squeeze"}

def evaluate(features):
    missing=[x for x in ['PCRChangePct', 'QQQ_BB_Bandwidth'] if x not in features or features[x] is None]
    if missing:
        return {"state":"NOT_READY","missing":missing}
    matched=bool(abs(features["PCRChangePct"]) >= 10.0 and features["QQQ_BB_Bandwidth"] >= 0.07)
    if matched:
        return {"state":"READY","signal_code":SIGNAL_CODE,"action":"PLAN_ENTRY","direction":DIRECTION,"holding_period":HOLDING_PERIOD,"notify":True}
    return {"state":"READY","signal_code":"NO_SIGNAL","action":"NONE","direction":"NONE","holding_period":"NONE","notify":False}
