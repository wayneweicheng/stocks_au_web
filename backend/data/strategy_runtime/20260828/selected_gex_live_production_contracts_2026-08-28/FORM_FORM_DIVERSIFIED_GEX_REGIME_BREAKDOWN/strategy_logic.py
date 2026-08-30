"""Production notification-only reference logic for GEX_FORM_DIVERSIFIED_GEX_BREAKDOWN 1.0.0-production.
Broker execution is HARD_DISABLED. User decides manual order placement.
"""
STRATEGY_CODE='GEX_FORM_DIVERSIFIED_GEX_BREAKDOWN'
VERSION='1.0.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
ENABLED=True
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
SIGNAL_CODE='FORM_DIVERSIFIED_GEX_REGIME_BREAKDOWN'
DIRECTION='SHORT'
HOLDING_PERIOD='D5'
TRIGGER='GEX_SMA5 >= -814.3 AND ConcentrationHHI <= 0.5445'
PROHIBITED_INPUTS={"TomorrowChange","Next2DaysChange","Next5DaysChange","Next10DaysChange","Next20DaysChange","GEX_Vol_Percentile","GEX_HighVolatility","GEX_StableRegime","Setup_Dual_Squeeze"}

def evaluate(features):
    missing=[x for x in ['GEX_SMA5', 'ConcentrationHHI'] if x not in features or features[x] is None]
    if missing:
        return {"state":"NOT_READY","missing":missing}
    matched=bool(features["GEX_SMA5"] >= -814.3 and features["ConcentrationHHI"] <= 0.5445)
    if matched:
        return {"state":"READY","signal_code":SIGNAL_CODE,"action":"PLAN_ENTRY","direction":DIRECTION,"holding_period":HOLDING_PERIOD,"notify":True}
    return {"state":"READY","signal_code":"NO_SIGNAL","action":"NONE","direction":"NONE","holding_period":"NONE","notify":False}
