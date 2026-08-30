"""Deterministic strategy logic contract for AMD v1.0.0.
I/O, calendars, persistence, authentication and notifications are external runtime concerns.
Percentiles MUST be causal prior-60 ranks with current observation excluded and <= tie handling.
"""
STRATEGY_CODE = "GEX_AMD_CAPITALTYPE"
VERSION = "1.0.0"
RULES = [{'signal_code': 'AMD_STRONG_FEAR_EXPANSION_REVERSAL', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': 'PriceChangePct < -0.10 AND PCRChangePct > 5.0 AND Momentum3Pct < -1.0'}, {'signal_code': 'AMD_BULLISH_POSITION_DIP_BUY', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': 'PriceChangePct < 0 AND NetBullSharePct60 >= 0.80'}, {'signal_code': 'AMD_SELL_PUT_SUPPORTED_STRENGTH', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D3', 'trigger_condition': 'VWAPDiffPct > 0.15 AND NetBullSharePct60 >= 0.65 AND SPSharePct60 >= 0.65'}, {'signal_code': 'AMD_PUT_BUY_COLLAPSE_REBOUND', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D2', 'trigger_condition': 'PutBuyShareChange < 0 AND PutBuyShareAbsShockPct60 >= 0.75 AND Momentum3Pct < -1.0'}, {'signal_code': 'AMD_COMPRESSION_SQUEEZE_WATCH', 'direction': 'LONG', 'action': 'WATCH', 'holding_period': 'D1', 'trigger_condition': 'AbsPriceMovePct60 <= 0.30 AND PCRChangePct > 20.0 AND PCRAbsShockPct60 >= 0.75 AND NetBullSharePct60 <= 0.30 AND Close < VWAP'}]

def evaluate(features):
    out=[]
    if features["PriceChangePct"] < -0.10 and features["PCRChangePct"] > 5.0 and features["Momentum3Pct"] < -1.0:
        out.append("AMD_STRONG_FEAR_EXPANSION_REVERSAL")
    if features["PriceChangePct"] < 0 and features["NetBullSharePct60"] >= 0.80:
        out.append("AMD_BULLISH_POSITION_DIP_BUY")
    if features["VWAPDiffPct"] > 0.15 and features["NetBullSharePct60"] >= 0.65 and features["SPSharePct60"] >= 0.65:
        out.append("AMD_SELL_PUT_SUPPORTED_STRENGTH")
    if features["PutBuyShareChange"] < 0 and features["PutBuyShareAbsShockPct60"] >= 0.75 and features["Momentum3Pct"] < -1.0:
        out.append("AMD_PUT_BUY_COLLAPSE_REBOUND")
    if features["AbsPriceMovePct60"] <= 0.30 and features["PCRChangePct"] > 20.0 and features["PCRAbsShockPct60"] >= 0.75 and features["NetBullSharePct60"] <= 0.30 and features["Close"] < features["VWAP"]:
        out.append("AMD_COMPRESSION_SQUEEZE_WATCH")
    return out or ["NO_SIGNAL"]
