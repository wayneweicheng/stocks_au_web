"""Frozen SQL-backed notification-only strategy IWM 2.0.0-production."""
import math

STRATEGY_CODE = "GEX_IWM_HIGH_GEX_VOL_REGIME_LONG"
VERSION = "2.0.0-production"
DEPLOYMENT_TARGET = "PRODUCTION"
ENABLED = True
NOTIFICATIONS_ENABLED = True
BROKER_EXECUTION = "HARD_DISABLED"
SIGNAL_CODE = "IWM_HIGH_GEX_VOL_REGIME_LONG"
DIRECTION = "LONG"
HOLDING_PERIOD = "D5"
TRIGGER = "SafeGEXVolRank60 >= 0.60 AND SPY_SafeGEXVolRank60 >= 0.65"
REQUIRED_INPUTS = ['SafeGEXVolRank60', 'SPY_SafeGEXVolRank60']
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
        matched = bool(features['SafeGEXVolRank60'] >= 0.60 and features['SPY_SafeGEXVolRank60'] >= 0.65)
    except (TypeError, ValueError, KeyError, ZeroDivisionError) as exc:
        return {"state": "DATA_ERROR", "error": str(exc)}
    if matched:
        return {"state": "READY", "signal_code": SIGNAL_CODE, "action": "PLAN_ENTRY", "direction": DIRECTION, "holding_period": HOLDING_PERIOD, "notify": True}
    return {"state": "READY", "signal_code": "NO_SIGNAL", "action": "NONE", "direction": "NONE", "holding_period": "NONE", "notify": False}
