"""Recalculate frozen-40 D0 predicates with the production feature code, SQL SELECT only.

Run this before rebuilding a runtime-aligned review archive. Historical readiness
and availability remain assumptions; no SQL changes or strategy activation.
"""
from __future__ import annotations
import json
from datetime import timedelta
from pathlib import Path
import pandas as pd
from audit_august_labels import connect,ROOT
from audit_baseline_40_runtime_parity import get_rows,ready_capital_rows
from rebuild_baseline_40_packets import SOURCE,BASE,LABELS,save
from strategy_runtime.strategies.capital_type_gex.features import build_contract_feature_history
from strategy_runtime.strategies.capital_type_gex.implementation import CapitalTypeGexImplementation
from strategy_runtime.strategies.gex_sql_source import SqlServerGexSource

OUT=BASE/'baseline_40_runtime_eligible.csv'


def runtime_at_date(cap,features,capdates,featuredates,d0,descriptor):
    capwindow=set([d for d in capdates if d<=d0][-61:]);gexwindow=set([d for d in featuredates if d<=d0][-61:])
    if d0 not in capwindow:return None,'CAPITAL_NOT_READY'
    if features and d0 not in gexwindow:return None,'GEX_FEATURE_NOT_READY'
    result=build_contract_feature_history([r for r in cap if r['ObservationDate'] in capwindow],descriptor=descriptor,gex_feature_rows=[r for r in features if r['ObservationDate'] in gexwindow],minimum_history=60)
    feature=next((r for r in result if r.observation_date==d0),None)
    if feature is None or feature.history_count<60 or feature.blocked:return None,'MINIMUM_HISTORY_OR_QUALITY_NOT_READY'
    return feature,'READY'


def run():
    source=json.loads((SOURCE/'master-manifest.json').read_text())['strategies'];labels=pd.read_csv(LABELS);labels.market_date=pd.to_datetime(labels.market_date)
    collected=[];diagnostics=[];c=connect(ROOT/'.env')
    try:
        cur=c.cursor()
        for strategy in source:
            symbol=strategy['ticker']+'.US';folder=SOURCE/strategy['directory'];descriptor=json.loads((folder/'strategy.descriptor.json').read_text())
            subset=labels[(labels.ticker==symbol)&labels[f"ret_{strategy['horizon']}"].notna()].copy()
            if subset.empty:raise ValueError(f'no corrected labels: {symbol}')
            start=subset.market_date.min().date()-timedelta(days=500);end=subset.market_date.max().date()
            cap=ready_capital_rows(get_rows(cur,"SELECT ObservationDate,CapitalType,GEXDelta,GEX,[Close],VWAP,NoOfOption FROM StockDB_US.Transform.OptionGEXChangeCapitalType WITH (NOLOCK) WHERE ASXCode=? AND ObservationDate BETWEEN ? AND ? AND CapitalType IN ('BC','BP','SC','SP') ORDER BY ObservationDate,CapitalType",(symbol,start,end)))
            requirements,_=SqlServerGexSource._contract_feature_requirements(descriptor)
            features=[];fields=requirements.get('SUBJECT',set())
            if fields:
                if any(not str(f).replace('_','').isalnum() for f in fields):raise ValueError('unsafe GEX field')
                selected=', '.join('[%s]'%f for f in ['ObservationDate',*sorted(fields)])
                features=get_rows(cur,f'SELECT {selected} FROM StockDB_US.Analysis.GEX_Features WITH (NOLOCK) WHERE ASXCode IN (?,?) AND ObservationDate BETWEEN ? AND ? ORDER BY ObservationDate',(symbol,strategy['ticker'],start,end))
                if len(features)!=len({p['ObservationDate'] for p in features}):raise ValueError(f'duplicate feature dates: {symbol}')
            capdates=sorted({r['ObservationDate'] for r in cap});gexdates=sorted({r['ObservationDate'] for r in features});impl=CapitalTypeGexImplementation(descriptor)
            needed=descriptor['signal_definitions'][0]['variables'];signal=descriptor['signal_definitions'][0]['signal_code'];ready_n=0;triggers=0
            for index,row in subset.iterrows():
                d0=row.market_date.date();entry={'ticker':symbol,'market_date':row.market_date.strftime('%Y-%m-%d')}
                try:feature,status=runtime_at_date(cap,features,capdates,gexdates,d0,descriptor)
                except Exception as exc:feature=None;status='FEATURE_ERROR:'+repr(exc)
                if feature is not None:
                    evaluation=impl._classify(feature);value=evaluation.trigger_evaluations.get(signal)
                    if evaluation.error or value is None or any(feature.values.get(field) is None for field in needed):status='PREDICATE_UNAVAILABLE'
                    else:
                        ready_n+=1;triggers+=value is True
                        for field in needed:
                            # Replace exploratory research feature with exactly the
                            # value supplied to the declarative runtime predicate.
                            subset.at[index,field]=feature.values[field]
                        collected.append(subset.loc[index].to_dict())
                    entry.update(runtime_predicate=value,history_count=feature.history_count,feature_quality=feature.quality)
                entry['status']=status;diagnostics.append(entry)
            print(symbol,'eligible',len(subset),'runtime-ready',ready_n,'triggers',triggers,flush=True)
    finally:c.close()
    frame=pd.DataFrame(collected)
    if frame.duplicated(['ticker','market_date']).any():raise ValueError('duplicate runtime labels')
    frame.to_csv(OUT,index=False)
    d=pd.DataFrame(diagnostics);d.to_csv(BASE/'baseline_40_runtime_readiness.csv',index=False)
    save(BASE/'baseline_40_runtime_panel_metadata.json',{'cutoff':'2026-08-31','source':'read-only StockDB_US, raw price labels audited independently','runtime_feature_impl':'strategy_runtime.strategies.capital_type_gex.features.build_contract_feature_history','rows_examined':len(d),'runtime_ready_rows':len(frame),'nonready_by_status':d[d.status!='READY'].status.value_counts().to_dict(),'frozen_rules':len(source),'notes':'Per-D0 61-complete-capital-observation and independently 61-GEX-source-row window; runtime MINIMUM_HISTORY 60; predicates use actual runtime feature values; no outcome used to change thresholds or memberships. Is_Swing_Down source chronology not independently proved.'})
    print('runtime-ready',len(frame),'examined',len(d),'triggers',int(d.runtime_predicate.fillna(False).sum()))

if __name__=='__main__':run()
