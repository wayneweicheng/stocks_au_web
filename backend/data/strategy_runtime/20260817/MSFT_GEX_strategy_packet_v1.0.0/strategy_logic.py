"""Deterministic strategy logic contract for MSFT v1.0.0.
I/O, calendars, persistence, authentication and notifications are external runtime concerns.
Percentiles MUST be causal prior-60 ranks with current observation excluded and <= tie handling.
"""
STRATEGY_CODE = "GEX_MSFT_CAPITALTYPE"
VERSION = "1.0.0"
RULES = [{'signal_code': 'MSFT_STRONG_BEARISH_CONTINUATION', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D1', 'trigger_condition': 'PriceChangePct < -0.10 AND PCRChangePct < -5.0 AND BullSharePct60 >= 0.65'}, {'signal_code': 'MSFT_BULL_SHARE_COLLAPSE', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D2', 'trigger_condition': 'BullShareChange < 0 AND BullShareAbsShockPct60 >= 0.75'}, {'signal_code': 'MSFT_HIGH_GEX_BULLISH_CONFIRMATION', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D2', 'trigger_condition': 'PriceChangePct > 0.10 AND PCRChangePct < -5.0 AND TotalGEXPct60 >= 0.75'}, {'signal_code': 'MSFT_BEARISH_CROWDING_SQUEEZE_WATCH', 'direction': 'LONG', 'action': 'WATCH', 'holding_period': 'D5', 'trigger_condition': 'PriceChangePct > 0 AND NetBullSharePct60 <= 0.20'}]

def evaluate(features):
    out=[]
    if features["PriceChangePct"] < -0.10 and features["PCRChangePct"] < -5.0 and features["BullSharePct60"] >= 0.65:
        out.append("MSFT_STRONG_BEARISH_CONTINUATION")
    if features["BullShareChange"] < 0 and features["BullShareAbsShockPct60"] >= 0.75:
        out.append("MSFT_BULL_SHARE_COLLAPSE")
    if features["PriceChangePct"] > 0.10 and features["PCRChangePct"] < -5.0 and features["TotalGEXPct60"] >= 0.75:
        out.append("MSFT_HIGH_GEX_BULLISH_CONFIRMATION")
    if features["PriceChangePct"] > 0 and features["NetBullSharePct60"] <= 0.20:
        out.append("MSFT_BEARISH_CROWDING_SQUEEZE_WATCH")
    return out or ["NO_SIGNAL"]
