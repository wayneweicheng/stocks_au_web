"""Read-only, causal daily option-quote feature panel through 2026-08-31."""
from __future__ import annotations
import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import numpy as np
import pandas as pd
import pyodbc
import sys

ROOT=Path(__file__).resolve().parents[2]
COVERAGE=ROOT/'data/strategy_runtime/20261018-b-research/option-quote-universe-coverage-through-cutoff.csv'
LABELS=ROOT/'data/strategy_runtime/20261018-b-research/research_corrected/eligible-outcomes.csv'
OUT=ROOT/'data/strategy_runtime/20261018-b-research/option_features'
CACHE=OUT/'daily_cache'
sys.path.insert(0,'C:/Repo/stocks_collecting/src')
from strategy_runtime.strategies.spx_gex.calendar import USCashCalendar
SESSION_CALENDAR=USCashCalendar()
START='2025-06-01'; CUTOFF='2026-08-31'
SQL="""
SELECT ObservationDate,PorC,COUNT_BIG(*) ContractRows,COUNT(DISTINCT OptionSymbol) Contracts,
 SUM(COALESCE(Volume,0)) Volume,SUM(COALESCE(OpenInterest,0)) OpenInterest,
 SUM(CASE WHEN Volume>0 AND IV IS NOT NULL THEN Volume*IV ELSE 0 END) IVVolNum,
 SUM(CASE WHEN Volume>0 AND IV IS NOT NULL THEN Volume ELSE 0 END) IVVolDen,
 SUM(CASE WHEN OpenInterest>0 AND IV IS NOT NULL THEN OpenInterest*IV ELSE 0 END) IVOINum,
 SUM(CASE WHEN OpenInterest>0 AND IV IS NOT NULL THEN OpenInterest ELSE 0 END) IVOIDen,
 SUM(CASE WHEN Volume>0 AND Delta IS NOT NULL THEN Volume*ABS(Delta) ELSE 0 END) DeltaNum,
 SUM(CASE WHEN Volume>0 AND Delta IS NOT NULL THEN Volume ELSE 0 END) DeltaDen,
 SUM(CASE WHEN Volume>0 AND Gamma IS NOT NULL THEN Volume*ABS(Gamma) ELSE 0 END) GammaNum,
 SUM(CASE WHEN Volume>0 AND Gamma IS NOT NULL THEN Volume ELSE 0 END) GammaDen,
 SUM(CASE WHEN Volume>0 AND Vega IS NOT NULL THEN Volume*ABS(Vega) ELSE 0 END) VegaNum,
 SUM(CASE WHEN Volume>0 AND Vega IS NOT NULL THEN Volume ELSE 0 END) VegaDen,
 SUM(CASE WHEN Bid IS NOT NULL AND Ask IS NOT NULL AND Bid>=0 AND Ask>=Bid AND Bid+Ask>0 THEN ((Ask-Bid)/((Bid+Ask)/2.0))*COALESCE(Volume,0) ELSE 0 END) SpreadNum,
 SUM(CASE WHEN Bid IS NOT NULL AND Ask IS NOT NULL AND Bid>=0 AND Ask>=Bid AND Bid+Ask>0 THEN COALESCE(Volume,0) ELSE 0 END) SpreadDen,
 SUM(CASE WHEN DATEDIFF(day,ObservationDate,ExpiryDate) BETWEEN 0 AND 7 THEN COALESCE(Volume,0) ELSE 0 END) VolDTE0_7,
 SUM(CASE WHEN DATEDIFF(day,ObservationDate,ExpiryDate) BETWEEN 8 AND 30 THEN COALESCE(Volume,0) ELSE 0 END) VolDTE8_30,
 SUM(CASE WHEN DATEDIFF(day,ObservationDate,ExpiryDate) BETWEEN 31 AND 60 THEN COALESCE(Volume,0) ELSE 0 END) VolDTE31_60,
 SUM(CASE WHEN DATEDIFF(day,ObservationDate,ExpiryDate) BETWEEN 0 AND 7 THEN COALESCE(OpenInterest,0) ELSE 0 END) OIDTE0_7,
 SUM(CASE WHEN DATEDIFF(day,ObservationDate,ExpiryDate) BETWEEN 8 AND 30 THEN COALESCE(OpenInterest,0) ELSE 0 END) OIDTE8_30,
 SUM(CASE WHEN DATEDIFF(day,ObservationDate,ExpiryDate) BETWEEN 31 AND 60 THEN COALESCE(OpenInterest,0) ELSE 0 END) OIDTE31_60,
 SUM(CASE WHEN DATEDIFF(day,ObservationDate,ExpiryDate) BETWEEN 0 AND 45 THEN COALESCE(Volume,0) ELSE 0 END) NearVol45,
 SUM(CASE WHEN DATEDIFF(day,ObservationDate,ExpiryDate) BETWEEN 0 AND 45 THEN COALESCE(OpenInterest,0) ELSE 0 END) NearOI45
FROM StockData.OptionDelayedQuote_V2 WITH (NOLOCK)
WHERE ASXCode=? AND ObservationDate BETWEEN ? AND ?
GROUP BY ObservationDate,PorC ORDER BY ObservationDate,PorC
"""


def db():
 values={}
 for line in (ROOT/'.env').read_text(encoding='utf-8').splitlines():
  if '=' in line and not line.lstrip().startswith('#'):
   k,v=line.split('=',1);values[k.strip()]=v.strip().strip('"').strip("'")
 server=values['SQL_SERVER_HOST']+(','+values['SQL_SERVER_PORT'] if values.get('SQL_SERVER_PORT') else '')
 c=pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={server};DATABASE=StockDB_US;UID={values['SQL_SERVER_USER']};PWD={values['SQL_SERVER_PASSWORD']};Encrypt=no;TrustServerCertificate=yes;",timeout=60);c.timeout=600;return c


def fetch(symbol):
 c=db()
 try:
  cur=c.cursor();cur.execute(SQL,symbol,START,CUTOFF);cols=[x[0] for x in cur.description];return symbol,pd.DataFrame.from_records(cur.fetchall(),columns=cols)
 finally:c.close()


def divide(a,b):return a/b if b and np.isfinite(b) else np.nan


def aggregate(symbol,raw):
 if raw.empty:return pd.DataFrame()
 raw=raw.copy();raw['PorC']=raw.PorC.fillna('U').astype(str).str.upper();raw['ObservationDate']=pd.to_datetime(raw.ObservationDate)
 rows=[]
 for day,g in raw.groupby('ObservationDate'):
  row={'ASXCode':symbol,'ObservationDate':day}
  for typ,label in [('C','Call'),('P','Put'),('U','Unknown')]:
   x=g[g.PorC==typ]
   for field in ['ContractRows','Contracts','Volume','OpenInterest','NearVol45','NearOI45','VolDTE0_7','VolDTE8_30','VolDTE31_60','OIDTE0_7','OIDTE8_30','OIDTE31_60']:
    row[f'{label}{field}']=float(x[field].sum()) if len(x) else 0.0
   for num,den,name in [('IVVolNum','IVVolDen','IVVolumeWeighted'),('IVOINum','IVOIDen','IVOpenInterestWeighted'),('DeltaNum','DeltaDen','AbsDeltaVolumeWeighted'),('GammaNum','GammaDen','AbsGammaVolumeWeighted'),('VegaNum','VegaDen','AbsVegaVolumeWeighted'),('SpreadNum','SpreadDen','ValidSpreadVolumeWeighted')]:
    row[f'{label}{name}']=divide(float(x[num].sum()),float(x[den].sum())) if len(x) else np.nan
    row[f'{label}{name}Numerator']=float(x[num].sum()) if len(x) else 0.0
    row[f'{label}{name}Denominator']=float(x[den].sum()) if len(x) else 0.0
   row[f'{label}IVVolumeCoverage']=divide(float(x.IVVolDen.sum()),float(x.Volume.sum())) if len(x) else np.nan
   row[f'{label}SpreadVolumeCoverage']=divide(float(x.SpreadDen.sum()),float(x.Volume.sum())) if len(x) else np.nan
  for f in ['ContractRows','Contracts','Volume','OpenInterest','NearVol45','NearOI45','VolDTE0_7','VolDTE8_30','VolDTE31_60','OIDTE0_7','OIDTE8_30','OIDTE31_60']:
   row['Total'+f]=sum(row[f'{x}{f}'] for x in ('Call','Put','Unknown'))
  for label in ('IVVolumeWeighted','IVOpenInterestWeighted','AbsDeltaVolumeWeighted','AbsGammaVolumeWeighted','AbsVegaVolumeWeighted','ValidSpreadVolumeWeighted'):
   numerator=sum(row[f'{x}{label}Numerator'] for x in ('Call','Put','Unknown'))
   denominator=sum(row[f'{x}{label}Denominator'] for x in ('Call','Put','Unknown'))
   row[label]=divide(numerator,denominator)
  row['TotalIVVolumeCoverage']=divide(sum(row[f'{x}IVVolumeWeightedDenominator'] for x in ('Call','Put','Unknown')),row['TotalVolume'])
  row['TotalSpreadVolumeCoverage']=divide(sum(row[f'{x}ValidSpreadVolumeWeightedDenominator'] for x in ('Call','Put','Unknown')),row['TotalVolume'])
  row['PutCallVolumeRatio']=divide(row['PutVolume'],row['CallVolume'])
  row['PutCallOIRatio']=divide(row['PutOpenInterest'],row['CallOpenInterest'])
  row['VolumeOIRatio']=divide(row['TotalVolume'],row['TotalOpenInterest'])
  row['Near45VolumeShare']=divide(row['TotalNearVol45'],row['TotalVolume'])
  row['Near45OIShare']=divide(row['TotalNearOI45'],row['TotalOpenInterest'])
  row['CallMinusPutIV']=row['CallIVVolumeWeighted']-row['PutIVVolumeWeighted'] if np.isfinite(row['CallIVVolumeWeighted']) and np.isfinite(row['PutIVVolumeWeighted']) else np.nan
  row['CallContractCoverage']=divide(row['CallContracts'],row['TotalContracts'])
  row['DuplicateRows']=row['TotalContractRows']-row['TotalContracts']
  rows.append(row)
 return pd.DataFrame(rows)


def prior_rank(series,window=60,minimum=20):
 values=pd.to_numeric(series,errors='coerce').to_numpy(float);result=np.full(len(values),np.nan)
 for i,value in enumerate(values):
  if not np.isfinite(value):continue
  prior=values[max(0,i-window):i];prior=prior[np.isfinite(prior)]
  if len(prior)>=minimum:result[i]=float((prior<=value).mean())
 return result


def main():
 OUT.mkdir(parents=True,exist_ok=True)
 coverage=pd.read_csv(COVERAGE);symbols=set(coverage.loc[coverage.ObservationDays>=120,'ASXCode'].astype(str))
 labels=pd.read_csv(LABELS,usecols=['ticker']);symbols.update(labels.ticker.astype(str));symbols=sorted(symbols)
 CACHE.mkdir(parents=True,exist_ok=True)
 parts=[];failed=[]
 pending=[]
 for symbol in symbols:
  cache_file=CACHE/(symbol.replace('/','_')+'.csv')
  if cache_file.exists():
   cached=pd.read_csv(cache_file,parse_dates=['ObservationDate'])
   if not cached.empty:parts.append(cached)
  else:pending.append(symbol)
 with ThreadPoolExecutor(max_workers=2) as pool:
  futures={pool.submit(fetch,s):s for s in pending}
  for f in as_completed(futures):
   s=futures[f]
   try:
    ticker,raw=f.result();daily=aggregate(ticker,raw)
    cache_file=CACHE/(ticker.replace('/','_')+'.csv')
    daily.to_csv(cache_file,index=False)
    if not daily.empty:parts.append(daily)
    print(ticker,'quote-days',daily.ObservationDate.nunique() if not daily.empty else 0,'raw-rows',int(raw.ContractRows.sum()) if not raw.empty else 0,'duplicates',int(raw.ContractRows.sum()-raw.Contracts.sum()) if not raw.empty else 0)
   except Exception as exc:
    failed.append({'symbol':s,'error':repr(exc)});print('ERROR',s,repr(exc))
 panel=pd.concat(parts,ignore_index=True).sort_values(['ASXCode','ObservationDate']) if parts else pd.DataFrame()
 non_session_rows=0
 if not panel.empty:
  session_mask=panel.ObservationDate.dt.date.map(SESSION_CALENDAR.is_session)
  non_session_rows=int((~session_mask).sum())
  panel.loc[~session_mask,['ASXCode','ObservationDate','TotalContracts','TotalVolume','TotalOpenInterest']].to_csv(OUT/'excluded-non-session-observations.csv',index=False)
  panel=panel.loc[session_mask].copy()
 pd.DataFrame(failed,columns=['symbol','error']).to_csv(OUT/'failed-symbols.csv',index=False)
 features=['TotalVolume','TotalOpenInterest','VolumeOIRatio','PutCallVolumeRatio','PutCallOIRatio','IVVolumeWeighted','CallMinusPutIV','Near45VolumeShare','Near45OIShare','ValidSpreadVolumeWeighted','AbsDeltaVolumeWeighted','AbsGammaVolumeWeighted','AbsVegaVolumeWeighted','TotalVolDTE0_7','TotalVolDTE8_30','TotalVolDTE31_60','TotalOIDTE0_7','TotalOIDTE8_30','TotalOIDTE31_60']
 if not panel.empty:
  for symbol,idx in panel.groupby('ASXCode').groups.items():
   p=panel.loc[idx].sort_values('ObservationDate').copy()
   for name in features:
    p[name+'Prior60Rank']=prior_rank(p[name])
    p[name+'AbsChangePrior60Rank']=prior_rank(p[name].pct_change(fill_method=None).abs())
   p['OpenInterestChangePct']=p.TotalOpenInterest.pct_change(fill_method=None)*100
   p['CallVolumeChangePct']=p.CallVolume.pct_change(fill_method=None)*100
   p['PutVolumeChangePct']=p.PutVolume.pct_change(fill_method=None)*100
   panel.loc[p.index,p.columns]=p
 panel.to_csv(OUT/'option-daily-features.csv',index=False)
 coverage_out=panel.groupby('ASXCode').agg(first_date=('ObservationDate','min'),last_date=('ObservationDate','max'),observation_days=('ObservationDate','nunique'),mean_contract_rows=('TotalContractRows','mean'),mean_contracts=('TotalContracts','mean'),mean_duplicate_rows=('DuplicateRows','mean'),iv_valid_days=('IVVolumeWeighted',lambda s:int(s.notna().sum())),oi_positive_days=('TotalOpenInterest',lambda s:int((s>0).sum()))).reset_index() if not panel.empty else pd.DataFrame()
 coverage_out.to_csv(OUT/'option-daily-coverage.csv',index=False)
 metadata={'symbols_requested':len(symbols),'symbols_with_quote_days':int(panel.ASXCode.nunique()) if not panel.empty else 0,'failed_symbol_count':len(failed),'non_session_symbol_dates_excluded':non_session_rows,'resumable_cache_dir':str(CACHE),'quote_min_days_filter':120,'development_cutoff':CUTOFF,'date_start':str(panel.ObservationDate.min())[:10] if not panel.empty else None,'date_end':str(panel.ObservationDate.max())[:10] if not panel.empty else None,'assumed_availability':'D0 ObservationDate is assumed available before D1 around 07:00 ET; runtime must gate on freshness.','weights':'Every weighted feature uses its own valid-value denominator. Greek columns are volume-weighted absolute source values, not asserted dollar exposures.','no_oos_selection':True,'no_db_writes':True}
 (OUT/'run-metadata.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(metadata,indent=2))

if __name__=='__main__':main()
