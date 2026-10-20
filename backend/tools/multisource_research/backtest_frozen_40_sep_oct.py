"""Read-only Sep 1–Oct 15 2026 retrospective replay of the frozen 40 GEX rules.

Uses actual runtime feature/predicate code, exact subject-stock 30M entry/exit
bars, scheduled XNYS D1/D3/D5 sessions; no SQL writes or provisioning. This
window was previously inspected and is NOT untouched out-of-sample evidence.
"""
from __future__ import annotations
import hashlib
import io
import json
import math
import re
import zipfile
from datetime import date, datetime, time, timedelta
from pathlib import Path
import pandas as pd
from audit_august_labels import connect,ROOT
from audit_baseline_40_runtime_parity import get_rows,ready_capital_rows
from build_baseline_40_runtime_panel import runtime_at_date
from fixed_hypothesis_screen import BASE,metrics
from rebuild_baseline_40_packets import SOURCE,save,digest
from strategy_runtime.strategies.capital_type_gex.implementation import CapitalTypeGexImplementation
from strategy_runtime.strategies.gex_sql_source import SqlServerGexSource
from strategy_runtime.strategies.spx_gex.calendar import USCashCalendar

OUT=BASE/'frozen_40_sep01_oct15_replay'
ARCHIVE=BASE/'baseline_40_runtime_aligned_review_packets_2026-10-18-b.zip'
START=date(2026,9,1);CUTOFF=date(2026,10,15)
COST_BPS=(0,25,50,100)
CALENDAR=USCashCalendar()


def sessions(start=START,end=CUTOFF):
    day=start;result=[]
    while day<=end:
        if CALENDAR.is_session(day):result.append(day)
        day+=timedelta(days=1)
    return result


def price_by_date(rows):
    """Fail closed on duplicates, no 'next available bar' entry/exit substitution."""
    indexed={}
    for stamp,opening,closing in rows:
        key=(stamp.date(),stamp.time())
        if key in indexed:raise ValueError(f'duplicate symbol/time bar: {key}')
        indexed[key]={'open':float(opening) if opening is not None else None,'close':float(closing) if closing is not None else None}
    return indexed


def label(d0,horizon,bars,cutoff=CUTOFF):
    entry_day=CALENDAR.session_offset(d0,1)
    exit_day=CALENDAR.session_offset(d0,int(horizon[1:]))
    result={'entry_date':entry_day.isoformat(),'exit_date':exit_day.isoformat(),'entry_time':'07:30','exit_bar_time':(CALENDAR.cash_close(exit_day)-timedelta(minutes=30)).strftime('%H:%M'),'entry_price':None,'exit_price':None,'gross_long_pct':None}
    if entry_day>cutoff:
        result['label_status']='PENDING_ENTRY_AFTER_CUTOFF';return result
    entry=bars.get((entry_day,time(7,30)))
    if not entry or entry['open'] is None or entry['open']<=0:
        result['label_status']='BLOCKED_MISSING_EXACT_D1_0730_OPEN';return result
    result['entry_price']=entry['open']
    if exit_day>cutoff:
        result['label_status']='PENDING_EXIT_AFTER_CUTOFF';return result
    expected_clock=(CALENDAR.cash_close(exit_day)-timedelta(minutes=30)).time().replace(tzinfo=None)
    exitbar=bars.get((exit_day,expected_clock))
    if not exitbar or exitbar['close'] is None or exitbar['close']<=0:
        result['label_status']='PENDING_MISSING_EXACT_EXIT_BAR';return result
    result['exit_price']=exitbar['close']
    result['gross_long_pct']=100*(exitbar['close']/entry['open']-1)
    result['label_status']='FINALIZED';return result


def load_review_descriptors():
    if not ARCHIVE.is_file():raise FileNotFoundError(ARCHIVE)
    old=json.loads((SOURCE/'master-manifest.json').read_text())['strategies']
    result={}
    with zipfile.ZipFile(ARCHIVE) as archive:
        if archive.testzip() is not None:raise ValueError('corrupt review archive')
        for strategy in old:
            key=next((n for n in archive.namelist() if n.endswith('/'+strategy['directory']+'/strategy.descriptor.json')),None)
            if not key:raise ValueError(f'missing frozen packet: {strategy["ticker"]}')
            descriptor=json.loads(archive.read(key))
            actionable=descriptor['signal_definitions'][0]
            if descriptor['strategy_code']!=strategy['strategy_code'] or actionable['trigger_condition']!=strategy['trigger'] or actionable['direction']!=strategy['direction'] or actionable['holding_period']!=strategy['horizon'] or descriptor['status']!='RESEARCH_DRAFT' or descriptor['production_policy']['enabled']:
                raise ValueError(f'frozen archive identity or safety mismatch: {strategy["ticker"]}')
            result[strategy['ticker']+'.US']=(strategy,descriptor)
    if len(result)!=40:raise ValueError('not frozen 40')
    return result


def query_symbol(cur,symbol,descriptor):
    begin=START-timedelta(days=500)
    cap=ready_capital_rows(get_rows(cur,"SELECT ObservationDate,CapitalType,GEXDelta,GEX,[Close],VWAP,NoOfOption FROM StockDB_US.Transform.OptionGEXChangeCapitalType WITH (NOLOCK) WHERE ASXCode=? AND ObservationDate BETWEEN ? AND ? AND CapitalType IN ('BC','BP','SC','SP') ORDER BY ObservationDate,CapitalType",(symbol,begin,CUTOFF)))
    required,_=SqlServerGexSource._contract_feature_requirements(descriptor)
    features=[];fields=required.get('SUBJECT',set())
    if fields:
        if any(not re.fullmatch('[A-Za-z_][A-Za-z0-9_]*',f) for f in fields):raise ValueError('unsafe GEX source field')
        selected=', '.join('[%s]'%f for f in ['ObservationDate',*sorted(fields)])
        features=get_rows(cur,f'SELECT {selected} FROM StockDB_US.Analysis.GEX_Features WITH (NOLOCK) WHERE ASXCode IN (?,?) AND ObservationDate BETWEEN ? AND ? ORDER BY ObservationDate',(symbol,symbol.removesuffix('.US'),begin,CUTOFF))
        if len(features)!=len({r['ObservationDate'] for r in features}):raise ValueError(f'duplicate GEX dates {symbol}')
    rows=get_rows(cur,"SELECT TimeIntervalStart,[Open],[Close] FROM StockDB_US.StockData.PriceHistoryTimeFrame WITH (NOLOCK) WHERE ASXCode=? AND TimeFrame='30M' AND TimeIntervalStart>=? AND TimeIntervalStart<? ORDER BY TimeIntervalStart",(symbol,datetime.combine(START,time()),datetime.combine(CUTOFF+timedelta(days=1),time())))
    price=price_by_date([(r['TimeIntervalStart'],r['Open'],r['Close']) for r in rows])
    return cap,features,price,len(rows)


def evaluate():
    packets=load_review_descriptors();dates=sessions();rows=[];source_meta=[]
    c=connect(ROOT/'.env')
    try:
        cur=c.cursor()
        for symbol,(strategy,descriptor) in packets.items():
            cap,gex,bars,barcount=query_symbol(cur,symbol,descriptor)
            capdates=sorted({r['ObservationDate'] for r in cap});gexdates=sorted({r['ObservationDate'] for r in gex})
            implementation=CapitalTypeGexImplementation(descriptor)
            needed=descriptor['signal_definitions'][0]['variables'];code=descriptor['signal_definitions'][0]['signal_code']
            count=0
            for d0 in dates:
                row={'ticker':symbol,'strategy_code':strategy['strategy_code'],'market_date':d0.isoformat(),'direction':strategy['direction'],'horizon':strategy['horizon'],'runtime_ready':False,'triggered':False,'reason':'','source_history_count':None}
                try:feat,status=runtime_at_date(cap,gex,capdates,gexdates,d0,descriptor)
                except Exception as exc:feat=None;status='FEATURE_ERROR:'+repr(exc)
                if feat is None:row['reason']=status;rows.append(row);continue
                evaluation=implementation._classify(feat);signal=evaluation.trigger_evaluations.get(code)
                if evaluation.error or signal is None or any(feat.values.get(k) is None or not math.isfinite(float(feat.values[k])) for k in needed):
                    row['reason']='PREDICATE_UNAVAILABLE:'+str(evaluation.error);rows.append(row);continue
                row.update(runtime_ready=True,triggered=bool(signal),source_history_count=feat.history_count,reason='READY')
                outcome=label(d0,strategy['horizon'],bars)
                row.update(outcome)
                if outcome['label_status']=='FINALIZED':
                    row['gross_directional_pct']=float(outcome['gross_long_pct'])*(1 if strategy['direction']=='LONG' else -1)
                    row['net_25bp_pct']=row['gross_directional_pct']-.25
                rows.append(row)
                count+=bool(signal)
            source_meta.append({'ticker':symbol,'cap_complete_rows':len(cap)//4,'gex_feature_rows':len(gex),'price_bars':barcount,'triggered_D0_dates':count})
            print(symbol,'signals',count,'bars',barcount,flush=True)
    finally:c.close()
    frame=pd.DataFrame(rows)
    if len(frame)!=len(packets)*len(dates) or frame.duplicated(['ticker','market_date']).any():raise ValueError('panel missing ticker/date rows')
    return frame,pd.DataFrame(source_meta)


def pf_statistics(frame):
    return {'n':len(frame),'tickers':int(frame.ticker.nunique()),'dates':int(frame.market_date.nunique()),'wins':int((frame.net_25bp_pct>0).sum()),'losses':int((frame.net_25bp_pct<=0).sum()),'median_net_pct':float(frame.net_25bp_pct.median()) if len(frame) else None,'worst_net_pct':float(frame.net_25bp_pct.min()) if len(frame) else None}


def summarize(panel):
    results=[]
    for period,start,end in [('SEPTEMBER','2026-09-01','2026-10-01'),('OCT_01_TO_15','2026-10-01','2026-10-16'),('COMBINED','2026-09-01','2026-10-16')]:
        x=panel[(panel.market_date>=start)&(panel.market_date<end)&panel.runtime_ready]
        for population,cohort in [('FROZEN40_SIGNAL',x[x.triggered]),('SAME_RUNTIME_READY_DIRECTION_BASELINE',x)]:
            statuses=cohort.label_status.value_counts().to_dict()
            completed=cohort[cohort.label_status=='FINALIZED']
            for cost in COST_BPS:
                direction=completed.gross_directional_pct
                info=metrics(direction,cost/100)
                results.append({'period':period,'population':population,'cost_bps_round_trip':cost,'signal_dates':len(cohort),'finalized_n':len(completed),'pending_exit_n':int(statuses.get('PENDING_EXIT_AFTER_CUTOFF',0)),'pending_entry_n':int(statuses.get('PENDING_ENTRY_AFTER_CUTOFF',0)),'missing_entry_n':int(statuses.get('BLOCKED_MISSING_EXACT_D1_0730_OPEN',0)),'missing_exit_bar_n':int(statuses.get('PENDING_MISSING_EXACT_EXIT_BAR',0)),'unique_tickers':completed.ticker.nunique(),'unique_D0_dates':completed.market_date.nunique(),**info,**({'median_net_pct':float((direction-cost/100).median()) if len(direction) else None,'worst_net_pct':float((direction-cost/100).min()) if len(direction) else None})})
    return pd.DataFrame(results)


def overlap(panel):
    """Selection sensitivity: one active ticker position, never a portfolio NAV."""
    eligible=panel[(panel.runtime_ready)&(panel.triggered)&(panel.label_status=='FINALIZED')].copy()
    eligible['entry_date']=pd.to_datetime(eligible.entry_date);eligible['exit_date']=pd.to_datetime(eligible.exit_date)
    positions={};admitted=[]
    for row in eligible.sort_values(['entry_date','ticker','market_date']).itertuples():
        prior=positions.get(row.ticker)
        if prior is not None and prior>=row.entry_date:continue
        positions[row.ticker]=row.exit_date
        admitted.append(row.Index)
    kept=eligible.loc[admitted]
    return {'all_finalized_signals':len(eligible),'one_position_per_ticker_n':len(kept),**metrics(kept.gross_directional_pct,.25),'note':'Close-day position occupies the morning slot. Pending trades are excluded from this selection diagnostic, so it is NOT a historical capital/NAV backtest.'}


def run():
    if OUT.exists():raise FileExistsError(f'refusing to overwrite previous replay: {OUT}')
    # Only create output once every source/readiness/identity check succeeds.
    panel,source=evaluate()
    report=summarize(panel);allocation=overlap(panel)
    OUT.mkdir(parents=True)
    panel.to_csv(OUT/'candidate-dates-and-labels.csv',index=False)
    panel[(panel.runtime_ready)&panel.triggered].to_csv(OUT/'signal-ledger-including-pending.csv',index=False)
    source.to_csv(OUT/'source-coverage-by-symbol.csv',index=False)
    report.to_csv(OUT/'results-by-period-and-cost.csv',index=False)
    save(OUT/'one-ticker-overlap.json',allocation)
    save(OUT/'run-manifest.json',{'frozen_packet_zip':str(ARCHIVE),'frozen_packet_zip_sha256':digest(ARCHIVE),'old_source_40_master_sha256':digest(SOURCE/'master-manifest.json'),'query_mode':'SQL SELECT only','observation_window':['2026-09-01','2026-10-15'],'label_cutoff':'2026-10-15','time_zone':'America/New_York','entry':'exact scheduled D1 07:30 30M bar OPEN, optimistic after 07:30 decision','exit':'exact last scheduled 30M bar close at XNYS regular close, half-day aware; no substitute bars','runtime_feature_contract':'D0+60 prior complete capital-type observations and independently GEX_Features source window via build_contract_feature_history and CapitalTypeGexImplementation','costs_round_trip_bps':list(COST_BPS),'pending_policy':'do not score unresolved outcomes as wins/losses or carry them into later source dates','caveats':['September–October 15 was already inspected; NOT pristine OOS','historical feature revisions/first-ready timestamps not independently proven','Is_Swing_Down source publication chronology unverified','25bps cost is sensitivity, not measured premarket fill/slippage','signal PF is instance-weighted, not portfolio NAV'],'date_count':len(sessions()),'ticker_count':40,'all_dates':len(panel),'runtime_ready_dates':int(panel.runtime_ready.sum()),'frozen_signal_dates':int(panel.triggered.sum()),'source_file_hashes':{'ledger':digest(OUT/'signal-ledger-including-pending.csv'),'results':digest(OUT/'results-by-period-and-cost.csv')}})
    print('\n25bps:',report[report.cost_bps_round_trip==25][['period','population','signal_dates','finalized_n','pending_exit_n','pending_entry_n','missing_entry_n','n','mean_net_pct','pf_net']].to_string(index=False));print('overlap',allocation)

if __name__=='__main__':run()
