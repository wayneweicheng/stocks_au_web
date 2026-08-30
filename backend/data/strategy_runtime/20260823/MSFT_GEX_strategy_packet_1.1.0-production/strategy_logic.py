"""Deterministic production reference logic for GEX_MSFT_CAPITALTYPE 1.1.0-production.
Signal generation/notification runs in Production. Broker execution is HARD_DISABLED; user decides whether to place orders manually.
Future-return target columns and the known leaking GEX_Vol_Percentile family are prohibited inputs.
"""
STRATEGY_CODE='GEX_MSFT_CAPITALTYPE'
VERSION='1.1.0-production'
DEPLOYMENT_TARGET="PRODUCTION"
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"
RULES=[{'signal_code': 'MSFT_STRONG_BEARISH_CONTINUATION', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D1', 'trigger_condition': 'PriceChangePct < -0.10 AND PCRChangePct < -5.0 AND BullSharePct60 >= 0.65'}, {'signal_code': 'MSFT_BULL_SHARE_COLLAPSE', 'direction': 'SHORT', 'action': 'PLAN_ENTRY', 'holding_period': 'D2', 'trigger_condition': 'BullShareChange < 0 AND BullShareAbsShockPct60 >= 0.75'}, {'signal_code': 'MSFT_HIGH_GEX_BULLISH_CONFIRMATION', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D2', 'trigger_condition': 'PriceChangePct > 0.10 AND PCRChangePct < -5.0 AND TotalGEXPct60 >= 0.75'}, {'signal_code': 'MSFT_BEARISH_CROWDING_SQUEEZE_CONFIRMED', 'direction': 'LONG', 'action': 'PLAN_ENTRY', 'holding_period': 'D5', 'trigger_condition': '(PriceChangePct > 0 AND NetBullSharePct60 <= 0.20) AND (QQQ.TodayChange > 1.0 OR MSFT.GEXChange < -10.0)'}, {'signal_code': 'MSFT_BEARISH_CROWDING_SQUEEZE_WEAK', 'direction': 'LONG', 'action': 'WATCH', 'holding_period': 'D5', 'trigger_condition': '(PriceChangePct > 0 AND NetBullSharePct60 <= 0.20) AND (NOT(QQQ.TodayChange > 1.0 OR MSFT.GEXChange < -10.0))'}]

def evaluate(features):
    out=[]
    def f(name):
        return features[name]
    if f("PriceChangePct") < -0.10 and f("PCRChangePct") < -5.0 and f("BullSharePct60") >= 0.65: out.append("MSFT_STRONG_BEARISH_CONTINUATION")
    if f("BullShareChange") < 0 and f("BullShareAbsShockPct60") >= 0.75: out.append("MSFT_BULL_SHARE_COLLAPSE")
    if f("PriceChangePct") > 0.10 and f("PCRChangePct") < -5.0 and f("TotalGEXPct60") >= 0.75: out.append("MSFT_HIGH_GEX_BULLISH_CONFIRMATION")
    if f("PriceChangePct") > 0 and f("NetBullSharePct60") <= 0.20:
        out.append("MSFT_BEARISH_CROWDING_SQUEEZE_CONFIRMED" if (f("QQQ_TodayChange")>1.0 or f("MSFT_GEXChange")<-10.0) else "MSFT_BEARISH_CROWDING_SQUEEZE_WEAK")
    return out or ["NO_SIGNAL"]
