"""Chronological evaluation of OptionDelayedQuote_V2 screens.

Uses only the August-31 research extract. Screens are evaluated after the
existing selected GEX predicate, with train/validation/final chronological
splits; final is reported but never used for screen selection.
"""
from __future__ import annotations
import ast
from pathlib import Path
import numpy as np
import pandas as pd
from generate_all_universe_contracts import eval_trigger

ROOT=Path(__file__).resolve().parents[2]
RESEARCH=ROOT/'backend/data/strategy_runtime/20261017/research_all_august_universe'
OUT=ROOT/'backend/data/strategy_runtime/20261018/option_quote_research'

def stat(x):
 x=pd.to_numeric(x,errors='coerce').dropna();w=x[x>0].sum();l=abs(x[x<=0].sum())
 return {'n':len(x),'wr':(x>0).mean()*100 if len(x) else None,'mean':x.mean() if len(x) else None,'pf':w/l if l else None}

def flat(prefix,x):return {prefix+'_'+k:v for k,v in stat(x).items()}

def main():
 q=pd.read_csv(OUT/'option-quote-daily-features.csv');q.market_date=pd.to_datetime(q.market_date)
 o=pd.read_csv(RESEARCH/'eligible-outcomes.csv');o.market_date=pd.to_datetime(o.market_date)
 c=pd.read_csv(ROOT/'backend/data/strategy_runtime/20261018/strategy-summary.csv');c=c[c.frequency_pct<=25].copy()
 m=o.merge(q,on=['ticker','market_date'],how='left'); rows=[]
 screens={
  'OPTION_VOLUME_HIGH':('TotalVolume_Rank60','>=',.8),'OPTION_VOLUME_LOW':('TotalVolume_Rank60','<=',.2),
  'OPTION_OI_HIGH':('TotalOpenInterest_Rank60','>=',.8),'OPTION_OI_LOW':('TotalOpenInterest_Rank60','<=',.2),
  'VOLUME_OI_HIGH':('VolumeOIRatio_Rank60','>=',.8),'VOLUME_OI_LOW':('VolumeOIRatio_Rank60','<=',.2),
  'PUT_CALL_VOLUME_HIGH':('PutCallVolumeRatio_Rank60','>=',.8),'PUT_CALL_VOLUME_LOW':('PutCallVolumeRatio_Rank60','<=',.2),
  'IV_HIGH':('IV_Rank60','>=',.8),'IV_LOW':('IV_Rank60','<=',.2),
  'IV_CHANGE_HIGH':('IV_ChgRank60','>=',.8),'IV_CHANGE_LOW':('IV_ChgRank60','<=',.2),
  'NEAR_VOLUME_HIGH':('NearVolumeShare_Rank60','>=',.8),'NEAR_VOLUME_LOW':('NearVolumeShare_Rank60','<=',.2),
  'SPREAD_HIGH':('Spread_Rank60','>=',.8),'SPREAD_LOW':('Spread_Rank60','<=',.2),
  'DELTA_HIGH':('AbsDeltaVol_Rank60','>=',.8),'GAMMA_HIGH':('AbsGammaVol_Rank60','>=',.8),'VEGA_HIGH':('AbsVegaVol_Rank60','>=',.8),
 }
 for candidate in c.to_dict('records'):
  p=m[m.ticker==str(candidate['ticker'])+'.US'].copy()
  if p.empty:continue
  p['gex_trigger']=p.apply(lambda r:eval_trigger(candidate['trigger'],r.to_dict()),axis=1);p=p[p.gex_trigger].sort_values('market_date')
  for horizon in ('D1','D3','D5'):
   if p.empty:continue
   z=p[p[f'ret_{horizon}'].notna()].copy();z['return_pct']=pd.to_numeric(z[f'ret_{horizon}'],errors='coerce')*(1 if candidate['direction']=='LONG' else -1)
   z['rank']=range(len(z));n=len(z);z['split']=np.select([z['rank']<n*.6,z['rank']<n*.8],['TRAIN_60','VALIDATION_20'],'FINAL_RESEARCH_TAIL_20')
   for name,(field,op,threshold) in screens.items():
    value=pd.to_numeric(z[field],errors='coerce');mask=value>=threshold if op=='>=' else value<=threshold
    row={'ticker':candidate['ticker'],'direction':candidate['direction'],'horizon':horizon,'screen':name,'screen_frequency_pct':float(mask.mean()*100)}
    for split in ('TRAIN_60','VALIDATION_20','FINAL_RESEARCH_TAIL_20'):
     row.update(flat(split,z.loc[mask & (z.split==split),'return_pct']))
    rows.append(row)
 out=pd.DataFrame(rows);out.to_csv(OUT/'option-screen-walkforward-results.csv',index=False)
 # Select only on train/validation; final is a holdout report.
 eligible=out[(out.TRAIN_60_n>=6)&(out.VALIDATION_20_n>=3)&(out.TRAIN_60_mean>0)&(out.VALIDATION_20_mean>0)&(out.TRAIN_60_pf.fillna(0)>1)&(out.VALIDATION_20_pf.fillna(0)>1)]
 selected=eligible.sort_values(['ticker','VALIDATION_20_pf','VALIDATION_20_mean'],ascending=[True,False,False]).groupby('ticker',as_index=False).head(1)
 selected.to_csv(OUT/'option-screen-walkforward-selected.csv',index=False)
 print('all variants',len(out),'eligible',len(eligible),'selected tickers',selected.ticker.nunique())
 print(selected[['ticker','horizon','screen','screen_frequency_pct','TRAIN_60_n','TRAIN_60_pf','VALIDATION_20_n','VALIDATION_20_pf','FINAL_RESEARCH_TAIL_20_n','FINAL_RESEARCH_TAIL_20_pf']].to_string(index=False))
if __name__=='__main__':main()
