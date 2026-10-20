"""Chronological signal-level comparator for frozen 40, NOT an OOS portfolio PF."""
from __future__ import annotations
import json
import pandas as pd
from rebuild_baseline_40_packets import BASE,SOURCE,save,independent_trigger
from fixed_hypothesis_screen import LABELS,metrics


def run():
    selected=json.loads((SOURCE/'master-manifest.json').read_text())['strategies'];rules={s['ticker']+'.US':s for s in selected}
    panel=pd.read_csv(BASE/'baseline_40_runtime_eligible.csv');panel.market_date=pd.to_datetime(panel.market_date)
    dates=sorted(pd.read_csv(LABELS,usecols=['market_date']).market_date.unique());first=pd.Timestamp(dates[int(len(dates)*.6)]);second=pd.Timestamp(dates[int(len(dates)*.8)])
    panel['horizon']=panel.ticker.map(lambda t:rules[t]['horizon']);panel['direction']=panel.ticker.map(lambda t:rules[t]['direction']);panel['triggered']=panel.apply(lambda r:independent_trigger(rules[r.ticker]['trigger'],r.to_dict()),axis=1)
    panel['gross_pct']=panel.apply(lambda r:float(r[f'ret_{r.horizon}'])*(1 if r.direction=='LONG' else -1),axis=1)
    panel['scheduled_exit']=pd.to_datetime(panel.apply(lambda r:r[f'exit_{r.horizon}'],axis=1))
    rows=[]
    for split,start,end in [('TRAIN',pd.Timestamp(dates[0]),first),('VALIDATION',first,second),('FINAL_RESEARCH_TAIL',second,pd.Timestamp('2026-09-01'))]:
        eligible=panel[(panel.market_date>=start)&(panel.market_date<end)&(panel.scheduled_exit<end)]
        for kind,data in [('FROZEN_40_RULE_TRIGGERED',eligible[eligible.triggered]),('FROZEN_40_RUNTIME_READY_UNCONDITIONAL_DIRECTION',eligible)]:
            rows.append({'split':split,'population':kind,'unique_tickers':data.ticker.nunique(),'unique_dates':data.market_date.nunique(),**metrics(data.gross_pct,.25)})
    pd.DataFrame(rows).to_csv(BASE/'baseline_40_runtime_aligned_split_comparison.csv',index=False)
    save(BASE/'baseline_40_runtime_aligned_split_manifest.json',{'train_before':str(first.date()),'validation_before':str(second.date()),'last_exit_cutoff':'2026-08-31','purge':'Exit date strictly before next split starts','cost_round_trip_bps':25,'bias':'Frozen rule set was selected on earlier flawed pre-cutoff research and September/October inspected; splits are descriptive, not independent validation. Repeated D5 instances overlap. No NAV or execution fill model.'})
    print(pd.DataFrame(rows).to_string(index=False))

if __name__=='__main__':run()
