"""Independently reconcile ALL finalized Sep–Oct replay instances against SQL PK bars."""
from __future__ import annotations
import json
from datetime import datetime,time,timedelta
import pandas as pd
from audit_august_labels import connect,ROOT
from backtest_frozen_40_sep_oct import OUT,CUTOFF,CALENDAR,START
from rebuild_baseline_40_packets import save


def audit():
    ledger=pd.read_csv(OUT/'signal-ledger-including-pending.csv')
    resolved=ledger[ledger.label_status=='FINALIZED'].copy()
    if resolved.empty:raise ValueError('no finalized signals')
    dates=pd.to_datetime(ledger.market_date).dt.date
    if min(dates)<START or max(dates)>CUTOFF:raise ValueError('out of observation window')
    c=connect(ROOT/'.env');rows=[]
    try:
        cur=c.cursor()
        for item in resolved.itertuples():
            d0=pd.Timestamp(item.market_date).date();d1=CALENDAR.session_offset(d0,1);exit_day=CALENDAR.session_offset(d0,int(item.horizon[1:]))
            expected_end=CALENDAR.cash_close(exit_day)
            last_bar=datetime.combine(exit_day,(expected_end-timedelta(minutes=30)).time().replace(tzinfo=None))
            entry_bar=datetime.combine(d1,time(7,30))
            cur.execute('SELECT TimeIntervalStart,[Open],[Close] FROM StockDB_US.StockData.PriceHistoryTimeFrame WITH (NOLOCK) WHERE TimeFrame=? AND ASXCode=? AND TimeIntervalStart IN (?,?) ORDER BY TimeIntervalStart','30M',item.ticker,entry_bar,last_bar)
            extracted=list(cur.fetchall())
            entry=[r for r in extracted if r[0]==entry_bar];exit_=[r for r in extracted if r[0]==last_bar]
            raw_entry=float(entry[0][1]) if len(entry)==1 and entry[0][1] is not None else None
            raw_exit=float(exit_[0][2]) if len(exit_)==1 and exit_[0][2] is not None else None
            ret=100*(raw_exit/raw_entry-1)*(1 if item.direction=='LONG' else -1) if raw_entry and raw_exit else None
            matched=(raw_entry is not None and raw_exit is not None and abs(raw_entry-float(item.entry_price))<=.00011 and abs(raw_exit-float(item.exit_price))<=.00011 and abs(ret-float(item.gross_directional_pct))<=.00011 and d1.isoformat()==item.entry_date and exit_day.isoformat()==item.exit_date and exit_day<=CUTOFF)
            rows.append({'ticker':item.ticker,'market_date':item.market_date,'horizon':item.horizon,'direction':item.direction,'scheduled_entry_bar':entry_bar.isoformat(sep=' '),'scheduled_exit_bar':last_bar.isoformat(sep=' '),'raw_entry_open':raw_entry,'raw_exit_close':raw_exit,'raw_directional_return_pct':ret,'ledger_entry_open':item.entry_price,'ledger_exit_close':item.exit_price,'ledger_directional_return_pct':item.gross_directional_pct,'match':matched})
    finally:c.close()
    result=pd.DataFrame(rows);result.to_csv(OUT/'independent-raw-bar-audit.csv',index=False)
    summary={'audited_finalized_signals':len(result),'matched':int(result.match.sum()),'mismatches':int((~result.match).sum()),'symbols':result.ticker.nunique(),'horizons':result.horizon.value_counts().to_dict(),'D0_dates':result.market_date.nunique(),'pending_entry_after_cutoff':int(ledger.label_status.eq('PENDING_ENTRY_AFTER_CUTOFF').sum()),'pending_exit_after_cutoff':int(ledger.label_status.eq('PENDING_EXIT_AFTER_CUTOFF').sum()),'missing_price_bars':int(ledger.label_status.isin(['BLOCKED_MISSING_EXACT_D1_0730_OPEN','PENDING_MISSING_EXACT_EXIT_BAR']).sum()),'method':'Independent SQL SELECT per event by exact symbol, TimeFrame=30M and scheduled XNYS timestamps; no fallback or SQL writes.'}
    save(OUT/'independent-raw-bar-audit.json',summary)
    print(json.dumps(summary,indent=2))
    if summary['mismatches']:raise RuntimeError('raw-bar audit failed; do not quote replay PF')

if __name__=='__main__':audit()
