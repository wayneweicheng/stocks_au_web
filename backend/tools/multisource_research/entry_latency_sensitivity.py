"""Read-only D1 entry bar-price sensitivity; NOT an executable fill simulation.

The 07:30 bar's OPEN is optimistic for an evaluation at 07:30. Alternative
30-minute bar closes and later opens are only price proxies: timestamp, quote
readiness, depth, spread, slippage and latency require separate verification.
"""
from __future__ import annotations
import json
from datetime import datetime,time,timedelta
from pathlib import Path
import pandas as pd
from audit_august_labels import connect, ROOT
from fixed_hypothesis_screen import LABELS,OPTIONS,BASE,metrics

OUT=BASE/'entry_latency_sensitivity'


def entry_proxies(rows):
    """Reject duplicate source symbol/date/time bars instead of choosing one."""
    grouped={}
    for timestamp,open_,close in rows:
        if timestamp.time() in {time(7,30),time(8),time(9,30)}:
            key=(timestamp.date(),timestamp.time())
            if key in grouped:raise ValueError(f'duplicate 30M entry bar {key}')
            grouped[key]=(float(open_) if open_ is not None else None,float(close) if close is not None else None)
    result={}
    for date_,clock in grouped:
        result.setdefault(date_,{})[clock]=grouped[(date_,clock)]
    return {day:{'OPEN_0730':bars.get(time(7,30),(None,None))[0],
                 'CLOSE_0730':bars.get(time(7,30),(None,None))[1],
                 'OPEN_0800':bars.get(time(8),(None,None))[0],
                 'OPEN_0930':bars.get(time(9,30),(None,None))[0]} for day,bars in result.items()}


def run():
    OUT.mkdir(parents=True,exist_ok=True)
    labels=pd.read_csv(LABELS,usecols=['ticker','market_date','entry_date','entry_price','exit_D5','ret_D5'])
    labels.market_date=pd.to_datetime(labels.market_date);labels.entry_date=pd.to_datetime(labels.entry_date);labels.exit_D5=pd.to_datetime(labels.exit_D5)
    ranks=pd.read_csv(OPTIONS,usecols=['ASXCode','ObservationDate','ValidSpreadVolumeWeightedPrior60Rank']).rename(columns={'ASXCode':'ticker','ObservationDate':'market_date'});ranks.market_date=pd.to_datetime(ranks.market_date)
    labels=labels.merge(ranks,on=['ticker','market_date'],how='left',validate='one_to_one')
    all_proxies={};c=connect(ROOT/'.env')
    try:
        cur=c.cursor()
        for symbol,group in labels.groupby('ticker'):
            first=group.entry_date.min().date();last=group.entry_date.max().date()+timedelta(days=1)
            cur.execute('''SELECT TimeIntervalStart,[Open],[Close] FROM StockDB_US.StockData.PriceHistoryTimeFrame WITH (NOLOCK) WHERE ASXCode=? AND TimeFrame='30M' AND TimeIntervalStart>=? AND TimeIntervalStart<? AND DATEPART(hour,TimeIntervalStart) IN (7,8,9) ORDER BY TimeIntervalStart''',symbol,datetime.combine(first,time()),datetime.combine(last,time()))
            all_proxies[symbol]=entry_proxies(cur.fetchall())
    finally:c.close()
    for name in ('OPEN_0730','CLOSE_0730','OPEN_0800','OPEN_0930'):
        labels[name]=[all_proxies.get(r.ticker,{}).get(r.entry_date.date(),{}).get(name) for r in labels.itertuples()]
        labels[name]=pd.to_numeric(labels[name],errors='coerce')
    if not ((labels.OPEN_0730-labels.entry_price).abs().dropna()<.00011).all() or labels.OPEN_0730.isna().any():
        raise ValueError('source 07:30 open differs from independently audited original label')
    labels['implied_exit_price']=labels.entry_price*(1+labels.ret_D5/100)
    dates=sorted(labels.market_date.dropna().unique());d1=dates[int(len(dates)*.60)];d2=dates[int(len(dates)*.80)]
    labels['split']='FINAL_RESEARCH_TAIL';labels.loc[labels.market_date<d2,'split']='VALIDATION';labels.loc[labels.market_date<d1,'split']='TRAIN'
    boundaries={'TRAIN':d1,'VALIDATION':d2,'FINAL_RESEARCH_TAIL':pd.Timestamp('2026-09-01')}
    labels=labels[labels.apply(lambda r:pd.notna(r.exit_D5) and r.exit_D5<boundaries[r.split],axis=1)].copy()
    rank='ValidSpreadVolumeWeightedPrior60Rank';labels['trigger']=labels[rank]>=.8
    rows=[]
    for split,group in labels.groupby('split'):
        base=group[group[rank].notna()&group.implied_exit_price.notna()]
        for population,x in [('HIGH_SPREAD_RANK',base[base.trigger]),('SAME_COVERAGE_UNCONDITIONAL',base)]:
            for name in ('OPEN_0730','CLOSE_0730','OPEN_0800','OPEN_0930'):
                valid=x[x[name]>0]
                returns=100*(valid.implied_exit_price/valid[name]-1)
                rows.append({'split':split,'population':population,'entry_proxy':name,'available_n':len(valid),'missing_n':len(x)-len(valid),**metrics(returns,.25)})
    result=pd.DataFrame(rows);result.to_csv(OUT/'entry-proxy-sensitivity.csv',index=False)
    labels[['ticker','market_date','entry_date','split',rank,'entry_price','implied_exit_price','ret_D5','OPEN_0730','CLOSE_0730','OPEN_0800','OPEN_0930']].to_csv(OUT/'entry-proxy-ledger.csv',index=False)
    (OUT/'method.json').write_text(json.dumps({'status':'EXPLORATORY_PRICE_PROXY_NOT_EXECUTABLE_FILLS','sql_mode':'SELECT only, no replay changes','cutoff':'2026-08-31','quote_availability':'D0 quote readiness at D1 07:00 ET is an OPERATOR ASSUMPTION; CreateDate/revisions cannot by themselves prove historical first readiness','entry_price_proxies':['07:30 bar open','07:30 bar close (only observable at 08:00)','08:00 bar open','09:30 bar open (different trading window)'],'exit':'unchanged audited D5 regular close derived from original 07:30 label; exit availability and same-stock price units assumed','cost':'25 bps flat round trip; no premarket liquidity, impact or short borrow modeled','interpretation':'07:30 bar close is not a fill at 07:30; opens at 08:00/09:30 may also be unavailable once the decision has been made. Proxy sensitivity, NOT execution validation.'},indent=2)+'\n')
    print(result.to_string(index=False))

if __name__=='__main__':run()
