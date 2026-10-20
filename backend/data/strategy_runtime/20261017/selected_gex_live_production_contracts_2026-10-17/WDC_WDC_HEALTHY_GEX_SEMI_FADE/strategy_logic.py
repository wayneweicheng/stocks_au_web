"""Frozen SQL-backed notification-only strategy WDC 2.0.0-production."""
import math

STRATEGY_CODE = "GEX_WDC_HEALTHY_GEX_SEMI_FADE"
VERSION = "2.0.0-production"
DEPLOYMENT_TARGET = "PRODUCTION"
ENABLED = True
NOTIFICATIONS_ENABLED = True
BROKER_EXECUTION = "HARD_DISABLED"
SIGNAL_CODE = "WDC_HEALTHY_GEX_SEMI_FADE"
DIRECTION = "SHORT"
HOLDING_PERIOD = "D5"
TRIGGER = "GEX_Rank60 >= 0.20 AND QQQ_GEX_ZScore_60day > -1.5"
REQUIRED_INPUTS = ['GEX_Rank60', 'QQQ_SafeGEXZ60']
PROHIBITED_INPUTS = {"TomorrowChange", "Next2DaysChange", "Next5DaysChange", "Next10DaysChange", "Next20DaysChange", "GEX_Vol_Percentile", "GEX_HighVolatility", "GEX_StableRegime", "Setup_Dual_Squeeze"}


def evaluate(features):
    missing = [name for name in REQUIRED_INPUTS if name not in features or features[name] is None]
    if missing:
        return {"state": "NOT_READY", "missing": missing}
    for name in REQUIRED_INPUTS:
        try:
            if not math.isfinite(float(features[name])):
                return {"state": "NOT_READY", "missing": [name]}
        except (TypeError, ValueError):
            return {"state": "DATA_ERROR", "error": f"non_numeric:{name}"}
    try:
        matched = bool(features['GEX_Rank60'] >= 0.20 and features['QQQ_SafeGEXZ60'] > -1.5)
    except (TypeError, ValueError, KeyError, ZeroDivisionError) as exc:
        return {"state": "DATA_ERROR", "error": str(exc)}
    if matched:
        return {"state": "READY", "signal_code": SIGNAL_CODE, "action": "PLAN_ENTRY", "direction": DIRECTION, "holding_period": HOLDING_PERIOD, "notify": True}
    return {"state": "READY", "signal_code": "NO_SIGNAL", "action": "NONE", "direction": "NONE", "holding_period": "NONE", "notify": False}
