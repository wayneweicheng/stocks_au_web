"""Read-only raw daily-price context for extreme corrected-label D5 returns.

A return reconciling to the 30M source is not itself proof of a split-adjusted,
tradeable market price. This produces an investigation list, not deletions.
"""
from __future__ import annotations
from datetime import timedelta
from pathlib import Path
import pandas as pd
from audit_august_labels import connect,ROOT
from fixed_hypothesis_screen import LABELS,BASE

OUT=BASE/'extreme_return_audit'


def run():
    OUT.mkdir(parents=True,exist_ok=True)
    d=pd.read_csv(LABELS,usecols=['ticker','market_date','entry_date','entry_price','exit_D5','ret_D5']);d=d[d.ret_D5.abs()>=40].copy()
    d['entry_date']=pd.to_datetime(d.entry_date);d['exit_D5']=pd.to_datetime(d.exit_D5)
    symbols=sorted(d.ticker.unique());rows=[]
    c=connect(ROOT/'.env')
    try:
        cur=c.cursor()
        for symbol in symbols:
            sub=d[d.ticker==symbol];start=sub.entry_date.min().date()-timedelta(days=3);end=sub.exit_D5.max().date()+timedelta(days=2)
            cur.execute('''SELECT ObservationDate,[Open],High,Low,[Close],Volume FROM StockDB_US.StockData.PriceHistory WITH (NOLOCK) WHERE ASXCode=? AND ObservationDate BETWEEN ? AND ? ORDER BY ObservationDate''',symbol,start,end)
            daily={str(r[0])[:10]:r for r in cur.fetchall()}
            for row in sub.itertuples():
                entry=daily.get(str(row.entry_date.date()));exit_=daily.get(str(row.exit_D5.date())) if pd.notna(row.exit_D5) else None
                rows.append({'ticker':symbol,'market_date':row.market_date,'entry_date':str(row.entry_date.date()),'exit_D5':str(row.exit_D5.date()),'entry_0730_open':row.entry_price,'intraday_D5_return_pct':row.ret_D5,'entry_daily_open':float(entry[1]) if entry and entry[1] is not None else None,'entry_daily_close':float(entry[4]) if entry and entry[4] is not None else None,'exit_daily_close':float(exit_[4]) if exit_ and exit_[4] is not None else None,'daily_close_to_close_return_pct':100*(float(exit_[4])/float(entry[4])-1) if entry and exit_ and entry[4] and exit_[4] else None,'entry_daily_volume':float(entry[5]) if entry and entry[5] is not None else None,'exit_daily_volume':float(exit_[5]) if exit_ and exit_[5] is not None else None})
    finally:c.close()
    frame=pd.DataFrame(rows);frame.to_csv(OUT/'extreme-D5-raw-daily-context.csv',index=False)
    print('extreme events',len(frame),'symbols',len(symbols));print(frame.sort_values('intraday_D5_return_pct',ascending=False).head(15).to_string(index=False))
    (OUT/'README.md').write_text('Returns with |raw D5| >=40%, compared against daily PriceHistory for the same symbol. Different daily close-to-close returns are expected because the D5 label enters at D1 07:30. Neither daily nor 30M source independently establishes corporate-action adjustment, correct symbol mapping, displayed size, or achievable premarket fills. This file is a QA queue; never exclude winners post hoc to construct a strategy. SQL SELECT only.\n')

if __name__=='__main__':run()
