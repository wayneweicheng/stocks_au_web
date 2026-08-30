"""Deterministic production reference logic for GEX_AMD_CAPITALTYPE 1.1.0-production.
Signal generation/notification runs in Production. Broker execution is HARD_DISABLED; user decides whether to place orders manually.
Future-return target columns and the known leaking GEX_Vol_Percentile family are prohibited inputs.
"""
STRATEGY_CODE='GEX_AMD_CAPITALTYPE'
VERSION='1.1.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
RULES=[{'signal_code': 'AMD_STRONG_FEAR_EXPANSION_REVERSAL', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': 'PriceChangePct < -0.10 AND PCRChangePct > 5.0 AND Momentum3Pct < -1.0'}, {'signal_code': 'AMD_BULLISH_POSITION_DIP_BUY', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': 'PriceChangePct < 0 AND NetBullSharePct60 >= 0.80'}, {'signal_code': 'AMD_SELL_PUT_SUPPORTED_STRENGTH_HIGH', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D3', 'trigger_condition': '(VWAPDiffPct > 0.15 AND NetBullSharePct60 >= 0.65 AND SPSharePct60 >= 0.65) AND (QQQ.GEX_ZScore_60day < 0)'}, {'signal_code': 'AMD_SELL_PUT_SUPPORTED_STRENGTH_STANDARD', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D3', 'trigger_condition': '(VWAPDiffPct > 0.15 AND NetBullSharePct60 >= 0.65 AND SPSharePct60 >= 0.65) AND (NOT(QQQ.GEX_ZScore_60day < 0))'}, {'signal_code': 'AMD_PUT_BUY_COLLAPSE_REBOUND', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D2', 'trigger_condition': 'PutBuyShareChange < 0 AND PutBuyShareAbsShockPct60 >= 0.75 AND Momentum3Pct < -1.0'}, {'signal_code': 'AMD_COMPRESSION_SQUEEZE_WATCH', 'direction': 'LONG', 'action': 'WATCH', 'holding_period': 'D1', 'trigger_condition': 'AbsPriceMovePct60 <= 0.30 AND PCRChangePct > 20.0 AND PCRAbsShockPct60 >= 0.75 AND NetBullSharePct60 <= 0.30 AND Close < VWAP'}]

def evaluate(features):
    out=[]
    def f(name):
        return features[name]
    if f("PriceChangePct") < -0.10 and f("PCRChangePct") > 5.0 and f("Momentum3Pct") < -1.0: out.append("AMD_STRONG_FEAR_EXPANSION_REVERSAL")
    if f("PriceChangePct") < 0 and f("NetBullSharePct60") >= 0.80: out.append("AMD_BULLISH_POSITION_DIP_BUY")
    if f("VWAPDiffPct") > 0.15 and f("NetBullSharePct60") >= 0.65 and f("SPSharePct60") >= 0.65:
        out.append("AMD_SELL_PUT_SUPPORTED_STRENGTH_HIGH" if f("QQQ_GEX_ZScore_60day")<0 else "AMD_SELL_PUT_SUPPORTED_STRENGTH_STANDARD")
    if f("PutBuyShareChange") < 0 and f("PutBuyShareAbsShockPct60") >= 0.75 and f("Momentum3Pct") < -1.0: out.append("AMD_PUT_BUY_COLLAPSE_REBOUND")
    if f("AbsPriceMovePct60") <= 0.30 and f("PCRChangePct") > 20.0 and f("PCRAbsShockPct60") >= 0.75 and f("NetBullSharePct60") <= 0.30 and f("Close") < f("VWAP"): out.append("AMD_COMPRESSION_SQUEEZE_WATCH")
    return out or ["NO_SIGNAL"]
