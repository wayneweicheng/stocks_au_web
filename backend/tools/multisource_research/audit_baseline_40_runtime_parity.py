"""Read-only runtime-predicate parity for the corrected frozen 40 baseline.

Descriptor structure/price reconciliation alone is not runtime rule parity. Load
only source-required SQL columns and compare historical packet triggers with the
actual capital-type GEX implementation's feature/evaluator path. NO SQL writes.
"""
from __future__ import annotations
import json
import math
import re
import tempfile
import zipfile
from datetime import timedelta
import pandas as pd
from audit_august_labels import connect,ROOT
from rebuild_baseline_40_packets import DEST,BASE,independent_trigger,save
from strategy_runtime.strategies.capital_type_gex.features import build_contract_feature_history
from strategy_runtime.strategies.capital_type_gex.implementation import CapitalTypeGexImplementation
from strategy_runtime.strategies.gex_sql_source import SqlServerGexSource


def get_rows(cur,sql,args):
    cur.execute(sql,*args);columns=[str(d[0]) for d in cur.description]
    return [dict(zip(columns,row)) for row in cur.fetchall()]


def ready_capital_rows(rows):
    """Mirror the runtime completeness gate before passing a causal history."""
    days={}
    for row in rows:days.setdefault(row['ObservationDate'],[]).append(row)
    valid=[]
    for day,part in sorted(days.items()):
        if len(part)!=4 or {p['CapitalType'] for p in part}!={'BC','BP','SC','SP'}:continue
        try:
            close={float(p['Close']) for p in part};vwap={float(p['VWAP']) for p in part}
            if len(close)!=1 or len(vwap)!=1:continue
            if any(not math.isfinite(float(p[k])) for p in part for k in ('GEXDelta','GEX','Close','VWAP','NoOfOption')):continue
            if sum(abs(float(p['GEXDelta'])) for p in part)<=0:continue
        except (ValueError,TypeError):continue
        valid.extend(part)
    return valid


def _run_source(archive_root):
    all_results=[];c=connect(ROOT/'.env')
    try:
        cur=c.cursor()
        for folder in sorted(p for p in archive_root.iterdir() if p.is_dir() and (p/'strategy.descriptor.json').exists()):
            desc=json.loads((folder/'strategy.descriptor.json').read_text());ledger=pd.read_csv(folder/'historical-instance-ledger.csv');symbol=desc['instrument_roles'][0]['instrument']
            if ledger.empty:continue
            dates=pd.to_datetime(ledger.market_date);start=dates.min().date()-timedelta(days=500);end=dates.max().date()
            cap=get_rows(cur,'SELECT ObservationDate,CapitalType,GEXDelta,GEX,[Close],VWAP,NoOfOption FROM StockDB_US.Transform.OptionGEXChangeCapitalType WITH (NOLOCK) WHERE ASXCode=? AND ObservationDate BETWEEN ? AND ? AND CapitalType IN (\'BC\',\'BP\',\'SC\',\'SP\') ORDER BY ObservationDate,CapitalType',(symbol,start,end))
            cap=ready_capital_rows(cap)
            requirements,_=SqlServerGexSource._contract_feature_requirements(desc)
            fields=requirements.get('SUBJECT',set())
            if any(not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*',name) for name in fields):raise ValueError('unsafe SQL feature identifier')
            features=[]
            if fields:
                selected=', '.join('[%s]'%name for name in ['ObservationDate',*sorted(fields)])
                features=get_rows(cur,f'SELECT {selected} FROM StockDB_US.Analysis.GEX_Features WITH (NOLOCK) WHERE ASXCode IN (?,?) AND ObservationDate BETWEEN ? AND ? ORDER BY ObservationDate',(symbol,symbol.removesuffix('.US'),start,end))
                if len({row['ObservationDate'] for row in features})!=len(features):raise ValueError(f'duplicate GEX feature dates: {symbol}')
            # Production source persists only D0 plus 60 prior complete capital
            # dates and independently D0 plus 60 prior source-feature dates.
            # Passing an unbounded GEX history would silently rank over years.
            capdays=sorted({r['ObservationDate'] for r in cap});gexdays=sorted({r['ObservationDate'] for r in features})
            impl=CapitalTypeGexImplementation(desc)
            nmatch=0;nmissing=0
            for item in ledger.itertuples():
                d0=pd.Timestamp(item.market_date).date()
                cap_window=set([d for d in capdays if d<=d0][-61:]);gex_window=set([d for d in gexdays if d<=d0][-61:])
                try:
                    history=build_contract_feature_history([r for r in cap if r['ObservationDate'] in cap_window],descriptor=desc,gex_feature_rows=[r for r in features if r['ObservationDate'] in gex_window],minimum_history=60)
                    f=next((x for x in history if x.observation_date==d0),None)
                except Exception as exc:
                    f=None;row_error=repr(exc)
                else:row_error=''
                row={'ticker':symbol,'market_date':item.market_date,'history_count':f.history_count if f else None,'runtime_quality':f.quality if f else None}
                if f is None:
                    row.update(status='MISSING_COMPLETE_CAPITAL_DAY',reason=row_error or 'D0 not present after runtime completeness filter');nmissing+=1
                else:
                    evaluate=impl._classify(f);actual=evaluate.trigger_evaluations.get(desc['signal_definitions'][0]['signal_code'])
                    required=desc['signal_definitions'][0]['variables']
                    differences={name:{'packet':getattr(item,'feature__'+name,None),'runtime':f.values.get(name)} for name in required if not _close(getattr(item,'feature__'+name,None),f.values.get(name))}
                    row.update(runtime_predicate=actual,runtime_issue=evaluate.error,feature_mismatch_count=len(differences),feature_mismatch_details=json.dumps(differences,default=str),status=('MATCH' if actual is True and f.history_count>=60 and not differences else 'MISMATCH'),reason='')
                    nmatch+=row['status']=='MATCH'
                all_results.append(row)
            print(symbol,'trades',len(ledger),'matched',nmatch,'missing_days',nmissing)
    finally:c.close()
    result=pd.DataFrame(all_results);result.to_csv(BASE/'baseline_40_runtime_parity.csv',index=False)
    counts=result.status.value_counts(dropna=False).to_dict();summary={'tested_ledger_rows':len(result),'status_counts':{str(k):int(v) for k,v in counts.items()},'source':'StockDB_US read-only; use live runtime capital-type feature and expression implementations; descriptor metadata only, no provisioning','minimum_history':60,'note':'Any mismatch means research-ledger trigger counts are NOT runtime-equivalent. Never use packet PF as validated production PF.'}
    save(BASE/'baseline_40_runtime_parity.json',summary);print(json.dumps(summary,indent=2))


def _close(a,b):
    if a is None or b is None or pd.isna(a) or pd.isna(b):return False
    return math.isclose(float(a),float(b),rel_tol=1e-5,abs_tol=1e-6)

def run():
    with tempfile.TemporaryDirectory(prefix='baseline40-audit-') as temporary:
        with zipfile.ZipFile(BASE/(DEST.name+'.zip')) as archive:
            if archive.testzip() is not None:raise ValueError('invalid packet archive')
            archive.extractall(temporary)
        _run_source(Path(temporary)/DEST.name)


if __name__=='__main__':run()
