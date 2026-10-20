"""Frozen SQL-backed notification-only strategy GDX 2.0.0-production."""
import math

STRATEGY_CODE = "GEX_GDX_GEX_VOL_WEAK_NASDAQ_REVERSAL"
VERSION = "2.0.0-production"
DEPLOYMENT_TARGET = "PRODUCTION"
ENABLED = True
NOTIFICATIONS_ENABLED = True
BROKER_EXECUTION = "HARD_DISABLED"
SIGNAL_CODE = "GDX_GEX_VOL_WEAK_NASDAQ_REVERSAL"
DIRECTION = "LONG"
HOLDING_PERIOD = "D5"
TRIGGER = "SafeGEXVolRank60 >= 0.40 AND NASDAQ_chg5 <= -1.0"
REQUIRED_INPUTS = ['SafeGEXVolRank60', 'NASDAQ_chg5']
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
        matched = bool(features['SafeGEXVolRank60'] >= 0.40 and features['NASDAQ_chg5'] <= -1.0)
    except (TypeError, ValueError, KeyError, ZeroDivisionError) as exc:
        return {"state": "DATA_ERROR", "error": str(exc)}
    if matched:
        return {"state": "READY", "signal_code": SIGNAL_CODE, "action": "PLAN_ENTRY", "direction": DIRECTION, "holding_period": HOLDING_PERIOD, "notify": True}
    return {"state": "READY", "signal_code": "NO_SIGNAL", "action": "NONE", "direction": "NONE", "holding_period": "NONE", "notify": False}
