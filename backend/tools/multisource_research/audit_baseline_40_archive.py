"""Compare immutable 20261018-a packet ledgers with independently audited labels."""
from __future__ import annotations
import json
from pathlib import Path
import pandas as pd
from rebuild_baseline_40_packets import SOURCE,BASE,LABELS,DEST,save


def run():
    old=json.loads((SOURCE/'master-manifest.json').read_text());data=pd.read_csv(LABELS,usecols=['ticker','market_date','entry_price','entry_date','ret_D1','ret_D3','ret_D5'])
    data=data.set_index(['ticker','market_date'],verify_integrity=True)
    rows=[]
    for strategy in old['strategies']:
        path=SOURCE/strategy['directory']/'historical-instance-ledger.csv'
        for entry in pd.read_csv(path).to_dict('records'):
            ticker=strategy['ticker']+'.US';d0=str(entry['market_date']);key=(ticker,d0);row=data.loc[key] if key in data.index else None
            corrected_return=float(row[f"ret_{strategy['horizon']}"])*(1 if strategy['direction']=='LONG' else -1) if row is not None and pd.notna(row[f"ret_{strategy['horizon']}"]) else None
            rows.append({'ticker':ticker,'market_date':d0,'horizon':strategy['horizon'],'direction':strategy['direction'],'old_entry_price':float(entry['entry_price']),'corrected_entry_price':float(row.entry_price) if row is not None else None,'old_return_pct':float(entry['return_pct']),'corrected_return_pct':corrected_return,'entry_price_match':bool(row is not None and abs(float(entry['entry_price'])-float(row.entry_price))<.00011),'return_match':bool(corrected_return is not None and abs(float(entry['return_pct'])-corrected_return)<.00011),'corrected_label_present':row is not None,'corrected_return_resolved':corrected_return is not None})
    frame=pd.DataFrame(rows);output=BASE/'baseline_40_legacy_ledger_audit.csv';frame.to_csv(output,index=False)
    result={'old_packets':len(old['strategies']),'old_instances':len(frame),'corrected_D0_present':int(frame.corrected_label_present.sum()),'old_entry_prices_matching_corrected':int(frame.entry_price_match.sum()),'old_returns_matching_corrected':int(frame.return_match.sum()),'old_returns_with_resolved_corrected_comparator':int(frame.corrected_return_resolved.sum()),'note':'Old archive immutable. Differences reflect historical entry-time/session labeling defects; legacy gross performance is not a valid stock baseline. Date/trigger selection was originally made using flawed research.'}
    save(BASE/'baseline_40_legacy_ledger_audit.json',result)
    print(json.dumps(result,indent=2))

if __name__=='__main__':run()
