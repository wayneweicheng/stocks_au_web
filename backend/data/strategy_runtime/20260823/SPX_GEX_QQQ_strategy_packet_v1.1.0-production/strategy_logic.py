"""Production deterministic classifier for SPX_GEX_QQQ_V1 v1.1.0-production. Notifications enabled; broker execution HARD_DISABLED."""
DEPLOYMENT_TARGET="PRODUCTION"
NOTIFICATIONS_ENABLED=True
BROKER_EXECUTION="HARD_DISABLED"

def base_signal(close_change_pct,pcr_change_pct):
    if ((close_change_pct>0 and pcr_change_pct>5) or (abs(close_change_pct)<0.1 and pcr_change_pct>20)): return "BEARISH"
    if ((close_change_pct<0 and pcr_change_pct<-5) or (abs(close_change_pct)<0.1 and pcr_change_pct<-20)): return "BULLISH"
    return "NONE"

def classify(base,sc=None,sc_median=None,sp_share=None,sp_p75=None,prior5d=None,spx_gex_trending_up=None,spx_gex_falling=None,qqq_gex_above_sma20=None,spx_price_above_sma50=None,qqq_macd_positive=None,history=60):
    if history<60:return "NOT_READY"
    if base=="BEARISH":
        if None in (sc,sc_median,sp_share,sp_p75):return "NOT_READY"
        if sc<=sc_median and sp_share>sp_p75:return "STRONG_YELLOW"
        if sc<=sc_median and sp_share<=sp_p75:return "RELIABLE_YELLOW"
        if sc>sc_median and sp_share>sp_p75:return "MIXED_YELLOW"
        return "WEAK_YELLOW"
    if base=="BULLISH":
        if prior5d is None:return "NOT_READY"
        if prior5d>0:return "NORMAL_GREEN"
        vals=(spx_gex_trending_up,spx_gex_falling,qqq_gex_above_sma20,spx_price_above_sma50,qqq_macd_positive)
        if any(v is None for v in vals):return "NOT_READY"
        if spx_gex_trending_up==1 or spx_gex_falling==1 or qqq_gex_above_sma20==1:return "REVERSAL_GREEN_HIGH"
        if spx_price_above_sma50==1 or qqq_macd_positive==1:return "REVERSAL_GREEN_STANDARD"
        return "REVERSAL_GREEN_WEAK"
    return "NO_SIGNAL"

def short_first_touch(entry,tp_price,sl_price,bar):
    op,hi,lo=bar["Open"],bar["High"],bar["Low"]
    if op>=sl_price:return "SL_GAP",op
    if op<=tp_price:return "TP_GAP",op
    ht,hs=lo<=tp_price,hi>=sl_price
    if ht and hs:return "SL_SAME_BAR_CONSERVATIVE",sl_price
    if hs:return "SL",sl_price
    if ht:return "TP",tp_price
    return None,None
