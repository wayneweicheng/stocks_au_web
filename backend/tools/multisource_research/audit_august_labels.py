"""Independently validate corrected August research labels against raw SQL bars."""
from __future__ import annotations
import argparse
import json
import sys
from datetime import date, datetime, time, timedelta
from pathlib import Path
import pandas as pd
import pyodbc

ROOT=Path(__file__).resolve().parents[2]
DEFAULT_INPUT=ROOT/'data/strategy_runtime/20261018-b-research/research_corrected/eligible-outcomes.csv'
DEFAULT_OUTPUT=ROOT/'data/strategy_runtime/20261018-b-research/august-label-audit.csv'
sys.path.insert(0,'C:/Repo/stocks_collecting/src')
from strategy_runtime.strategies.spx_gex.calendar import USCashCalendar


def env_values(path):
 d={}
 for line in path.read_text(encoding='utf-8').splitlines():
  if '=' in line and not line.lstrip().startswith('#'):
   k,v=line.split('=',1);d[k.strip()]=v.strip().strip('"').strip("'")
 return d


def connect(path):
 v=env_values(path);server=v['SQL_SERVER_HOST']+(','+v['SQL_SERVER_PORT'] if v.get('SQL_SERVER_PORT') else '')
 c=pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={server};DATABASE=StockDB_US;UID={v['SQL_SERVER_USER']};PWD={v['SQL_SERVER_PASSWORD']};Encrypt=no;TrustServerCertificate=yes;",timeout=30);c.timeout=180;return c


def main():
 ap=argparse.ArgumentParser();ap.add_argument('--input',type=Path,default=DEFAULT_INPUT);ap.add_argument('--env-file',type=Path,default=ROOT/'.env');ap.add_argument('--output',type=Path,default=DEFAULT_OUTPUT);args=ap.parse_args()
 data=pd.read_csv(args.input);data['market_date']=pd.to_datetime(data.market_date).dt.date;symbols=sorted(data.ticker.astype(str).unique());cal=USCashCalendar();bars_by_symbol={}
 c=connect(args.env_file)
 try:
  cur=c.cursor()
  for symbol in symbols:
   dates=data.loc[data.ticker==symbol,'market_date'];start=min(dates)-timedelta(days=3);end=max(dates)+timedelta(days=12)
   cur.execute('''SELECT TimeIntervalStart,[Open],[Close] FROM StockDB_US.StockData.PriceHistoryTimeFrame WITH (NOLOCK) WHERE ASXCode=? AND TimeFrame='30M' AND TimeIntervalStart>=? AND TimeIntervalStart<? ORDER BY TimeIntervalStart''',(symbol,datetime.combine(start,time()),datetime.combine(end,time())))
   bars_by_symbol[symbol]=[{"t":r[0],"open":float(r[1]) if r[1] is not None else None,"close":float(r[2]) if r[2] is not None else None} for r in cur.fetchall()]
  cur.close()
 finally:c.close()
 results=[]
 for row in data.to_dict('records'):
  symbol=row['ticker'];bars=bars_by_symbol.get(symbol,[]);d0=row['market_date'];d1=cal.session_offset(d0,1);entry_gate=datetime.combine(d1,time(7,30));entry=next((b for b in bars if b['t']==entry_gate),None)
  out={'ticker':symbol,'market_date':d0.isoformat(),'expected_entry_date':d1.isoformat(),'status':'OK'}
  if entry is None or entry['open'] is None or entry['open']<=0:
   out['status']='MISSING_ENTRY';results.append(out);continue
  out['expected_entry_time']=entry['t'].isoformat(sep=' ');out['expected_entry_price']=entry['open'];out['entry_exact_0730']=entry['t'].time()==time(7,30);out['entry_price_match']=abs(entry['open']-float(row['entry_price']))<0.00011
  out['entry_date_match']=str(row['entry_date'])[:10]==d1.isoformat()
  for h in (1,3,5):
   xdate=cal.session_offset(d0,h);close_at=cal.cash_close(xdate).replace(tzinfo=None);exit_bar=next((b for b in reversed(bars) if b['t'].date()==xdate and b['t']<close_at and b['close'] is not None),None)
   key=f'D{h}'
   if exit_bar is None or pd.isna(row.get(f'ret_{key}')):
    if pd.isna(row.get(f'ret_{key}')):out[f'{key}_status']='LABEL_MISSING'
    else:out[f'{key}_status']='MISSING_EXIT'
    continue
   ret=(exit_bar['close']/entry['open']-1)*100
   out[f'{key}_expected_exit_date']=xdate.isoformat();out[f'{key}_exit_time']=exit_bar['t'].isoformat(sep=' ');out[f'{key}_exit_date_match']=str(row[f'exit_{key}'])[:10]==xdate.isoformat();out[f'{key}_return_recomputed']=ret;out[f'{key}_return_difference_pp']=ret-float(row[f'ret_{key}']);out[f'{key}_match']=abs(ret-float(row[f'ret_{key}']))<=0.00011 and out[f'{key}_exit_date_match']
  results.append(out)
 result=pd.DataFrame(results);args.output.parent.mkdir(parents=True,exist_ok=True);result.to_csv(args.output,index=False)
 summary={'input_rows':len(data),'symbols':len(symbols),'source_bars':sum(len(x) for x in bars_by_symbol.values()),'row_status':result.status.value_counts().to_dict(),'entry_price_match_count':int(result.get('entry_price_match',pd.Series(dtype=bool)).fillna(False).sum()),'entry_date_match_count':int(result.get('entry_date_match',pd.Series(dtype=bool)).fillna(False).sum()),'exact_0730_count':int(result.get('entry_exact_0730',pd.Series(dtype=bool)).fillna(False).sum()),'horizons':{}}
 for h in ('D1','D3','D5'):
  col=f'{h}_match';summary['horizons'][h]={'available_labels':int(data[f'ret_{h}'].notna().sum()),'matches':int(result.get(col,pd.Series(dtype=bool)).fillna(False).sum()),'mismatches':int(result.get(col,pd.Series(dtype=bool)).notna().sum()-result.get(col,pd.Series(dtype=bool)).fillna(False).sum()),'max_abs_difference_pp':float(result.get(f'{h}_return_difference_pp',pd.Series(dtype=float)).abs().max()) if f'{h}_return_difference_pp' in result else None}
 print(json.dumps(summary,indent=2,default=str));print('output',args.output)
 if any(x['mismatches'] for x in summary['horizons'].values()) or summary['row_status'].get('MISSING_ENTRY',0):return 2
 return 0

if __name__=='__main__':raise SystemExit(main())
