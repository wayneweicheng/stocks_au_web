"""Capacity/overlap diagnostic, NOT an NAV or executable portfolio backtest."""
from __future__ import annotations
from collections import defaultdict
from pathlib import Path
import pandas as pd
from fixed_hypothesis_screen import BASE,LABELS,OPTIONS,metrics

OUT=BASE/'overlap_sensitivity'


def select_tranches(data,ticker_cap=1,global_cap=None):
    """Entry at D1 premarket, exit at D5 close; close-date capital unavailable at entry."""
    opened=[];selected=[];peak=0
    ordered=data.sort_values(['entry_date','ticker','market_date'])
    for row in ordered.itertuples():
        entry=row.entry_date
        opened=[p for p in opened if p['exit_D5']>=entry]
        same=sum(p['ticker']==row.ticker for p in opened)
        if same>=ticker_cap or (global_cap is not None and len(opened)>=global_cap):continue
        opened.append({'ticker':row.ticker,'exit_D5':row.exit_D5})
        selected.append(row.Index);peak=max(peak,len(opened))
    return data.loc[selected],peak


def run():
    OUT.mkdir(parents=True,exist_ok=True)
    labels=pd.read_csv(LABELS,usecols=['ticker','market_date','entry_date','exit_D5','ret_D5']);option=pd.read_csv(OPTIONS,usecols=['ASXCode','ObservationDate','ValidSpreadVolumeWeightedPrior60Rank']).rename(columns={'ASXCode':'ticker','ObservationDate':'market_date'})
    labels.market_date=pd.to_datetime(labels.market_date);labels.entry_date=pd.to_datetime(labels.entry_date);labels.exit_D5=pd.to_datetime(labels.exit_D5);option.market_date=pd.to_datetime(option.market_date)
    p=labels.merge(option,on=['ticker','market_date'],how='left',validate='one_to_one')
    dates=sorted(p.market_date.unique());first=dates[int(len(dates)*.6)];second=dates[int(len(dates)*.8)]
    rows=[]
    for split,start,end in [('TRAIN',dates[0],first),('VALIDATION',first,second),('FINAL_RESEARCH_TAIL',second,pd.Timestamp('2026-09-01'))]:
        data=p[(p.market_date>=start)&(p.market_date<end)&(p.exit_D5<end)&(p.ValidSpreadVolumeWeightedPrior60Rank>=.8)].copy()
        for cap,global_cap in [(100000,None),(1,None),(3,None),(1,10),(1,20)]:
            sel,peak=select_tranches(data,cap,global_cap)
            desc=f'ticker_cap_{cap}_global_{global_cap}'
            rows.append({'split':split,'policy':desc,'signal_n':len(sel),'unique_tickers':sel.ticker.nunique(),'unique_entry_dates':sel.entry_date.nunique(),'peak_open_tranches':peak,**metrics(sel.ret_D5,.25)})
            sel[['ticker','market_date','entry_date','exit_D5','ret_D5']].to_csv(OUT/f'{split.lower()}-{desc}.csv',index=False)
    result=pd.DataFrame(rows);result.to_csv(OUT/'overlap-policies.csv',index=False)
    (OUT/'README.md').write_text('Exploratory selection-only concurrency sensitivity on D5 corrected stock-price labels, 25 bps flat round trip. All triggers known from D0, D1 premarket entries sorted by ticker; a prior position that exits at D5 close still occupies a slot at that morning entry. This is NOT a cash/NAV/mark-to-market portfolio simulation: PF is instance-weighted on admitted signals, no allocation, interim value, borrow, exposure, costs beyond 25 bp or slippage is modeled. Policies and thresholds were inspected after the initial screen and are not untouched validation.\n')
    print(result.to_string(index=False))

if __name__=='__main__':run()
