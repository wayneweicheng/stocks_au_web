"""Deterministic reference logic for SPX_GEX_QQQ_V1 1.0.2-production."""

def base_signal(close_change_pct, pcr_change_pct):
    if ((close_change_pct > 0 and pcr_change_pct > 5) or
        (abs(close_change_pct) < 0.1 and pcr_change_pct > 20)):
        return "BEARISH"
    if ((close_change_pct < 0 and pcr_change_pct < -5) or
        (abs(close_change_pct) < 0.1 and pcr_change_pct < -20)):
        return "BULLISH"
    return "NONE"

def classify(base, sc=None, sc_median=None, sp_share=None, sp_p75=None, prior5d=None, history=60):
    if history < 60:
        return "NOT_READY"
    if base == "BEARISH":
        if None in (sc, sc_median, sp_share, sp_p75): return "NOT_READY"
        if sc <= sc_median and sp_share > sp_p75: return "STRONG_YELLOW"
        if sc <= sc_median and sp_share <= sp_p75: return "RELIABLE_YELLOW"
        if sc > sc_median and sp_share > sp_p75: return "MIXED_YELLOW"
        return "WEAK_YELLOW"
    if base == "BULLISH":
        if prior5d is None: return "NOT_READY"
        return "REVERSAL_GREEN" if prior5d <= 0 else "NORMAL_GREEN"
    return "NO_SIGNAL"

def short_first_touch(entry, tp_price, sl_price, bar):
    op, hi, lo = bar["Open"], bar["High"], bar["Low"]
    if op >= sl_price: return "SL_GAP", op
    if op <= tp_price: return "TP_GAP", op
    hit_tp, hit_sl = lo <= tp_price, hi >= sl_price
    if hit_tp and hit_sl: return "SL_SAME_BAR_CONSERVATIVE", sl_price
    if hit_sl: return "SL", sl_price
    if hit_tp: return "TP", tp_price
    return None, None
