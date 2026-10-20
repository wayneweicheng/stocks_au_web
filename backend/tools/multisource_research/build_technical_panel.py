"""Read-only build of causal daily price technical features through cutoff."""
from __future__ import annotations
import json
import sys
from pathlib import Path
import pandas as pd
import pyodbc

ROOT=Path(__file__).resolve().parents[2]
DEFAULT_COVERAGE=ROOT/'data/strategy_runtime/20261018-b-research/option-quote-universe-coverage-through-cutoff.csv'
OUT=ROOT/'data/strategy_runtime/20261018-b-research/technical_features'
sys.path.insert(0,str(Path(__file__).resolve().parent))
from technical_features import build_features


def db(env_path):
 values={}
 for line in env_path.read_text(encoding='utf-8').splitlines():
  if '=' in line and not line.lstrip().startswith('#'):
   k,v=line.split('=',1);values[k.strip()]=v.strip().strip('"').strip("'")
 server=values['SQL_SERVER_HOST']+(','+values['SQL_SERVER_PORT'] if values.get('SQL_SERVER_PORT') else '')
 c=pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={server};DATABASE=StockDB_US;UID={values['SQL_SERVER_USER']};PWD={values['SQL_SERVER_PASSWORD']};Encrypt=no;TrustServerCertificate=yes;",timeout=30);c.timeout=180;return c


def main():
 OUT.mkdir(parents=True,exist_ok=True)
 coverage=pd.read_csv(DEFAULT_COVERAGE)
 quote_symbols=coverage.loc[coverage.ObservationDays>=120,'ASXCode'].astype(str).tolist()
 # Include the corrected August feature universe even when quote history is short.
 labels=pd.read_csv(ROOT/'data/strategy_runtime/20261018-b-research/research_corrected/eligible-outcomes.csv',usecols=['ticker'])
 symbols=sorted(set(quote_symbols)|set(labels.ticker.astype(str)))
 marks=','.join('?' for _ in symbols)
 c=db(ROOT/'.env')
 try:
  cur=c.cursor()
  cur.execute(f'''SELECT ASXCode,ObservationDate,[Open],High,Low,[Close],Volume,VWAP FROM StockDB_US.StockData.PriceHistory WITH (NOLOCK) WHERE ASXCode IN ({marks}) AND ObservationDate BETWEEN '2025-01-01' AND '2026-08-31' ORDER BY ASXCode,ObservationDate''',symbols)
  cols=[d[0] for d in cur.description];rows=cur.fetchall();cur.close()
 finally:c.close()
 source=pd.DataFrame.from_records(rows,columns=cols)
 features=build_features(source) if not source.empty else pd.DataFrame()
 if not features.empty:
  features.to_csv(OUT/'causal-technical-features.csv',index=False)
  cov=features.groupby('ASXCode').agg(first_date=('ObservationDate','min'),last_date=('ObservationDate','max'),daily_bars=('ObservationDate','nunique')).reset_index()
 else:cov=pd.DataFrame(columns=['ASXCode','first_date','last_date','daily_bars'])
 cov.to_csv(OUT/'price-history-coverage.csv',index=False)
 feature_names=[name for name in features.columns if name not in {'ASXCode','ObservationDate','Open','High','Low','Close','Volume','VWAP'}]
 dictionary=[]
 for name in feature_names:
  dictionary.append({'name':name,'source':'StockDB_US.StockData.PriceHistory','availability':'Completed D0 daily bar; assumed available by next-session premarket decision','formula_family':name.split('20')[0] if name.startswith(('BB20','PriorHigh20','PriorLow20')) else name.split('14')[0] if name.startswith(('RSI14','ATR14')) else name,'causal_rule':'Current completed D0 values may be used D1; prior support/resistance and pivot levels exclude current/future period; confirmed pivots recorded only on confirmation date.','null_rule':'Insufficient lookback, zero denominator, or invalid source => NaN/NOT_READY'})
 pd.DataFrame(dictionary).to_csv(OUT/'feature-dictionary.csv',index=False)
 metadata={'symbols_requested':len(symbols),'symbols_with_daily_bars':int(features.ASXCode.nunique()) if not features.empty else 0,'quote_universe_symbols_with_at_least_120_pre_cutoff_days':len(quote_symbols),'source_rows':len(source),'feature_rows':len(features),'date_start':str(features.ObservationDate.min())[:10] if not features.empty else None,'date_end':str(features.ObservationDate.max())[:10] if not features.empty else None,'cutoff':'2026-08-31','source':'StockDB_US.StockData.PriceHistory','no_outcomes_used_for_feature_selection':True,'no_db_writes':True}
 (OUT/'run-metadata.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(metadata,indent=2))

if __name__=='__main__':main()
