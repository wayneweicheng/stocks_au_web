"""Post-audit diagnostics; no ticker removal or threshold adjustment."""
from __future__ import annotations
import json
import pandas as pd
from backtest_frozen_40_sep_oct import OUT,ROOT
from fixed_hypothesis_screen import metrics
from rebuild_baseline_40_packets import save


def run():
    audit=json.loads((OUT/'independent-raw-bar-audit.json').read_text())
    if audit['mismatches'] or audit['matched']!=audit['audited_finalized_signals']:raise ValueError('audit gate failed')
    signals=pd.read_csv(OUT/'signal-ledger-including-pending.csv');closed=signals[signals.label_status=='FINALIZED'].copy();closed['net']=closed.gross_directional_pct-.25
    rows=[]
    for ticker,part in closed.groupby('ticker'):
        out=metrics(part.gross_directional_pct,.25)
        rows.append({'ticker':ticker,'horizon':part.horizon.iloc[0],'direction':part.direction.iloc[0],'finalized_n':len(part),'distinct_D0_dates':part.market_date.nunique(),'net_total_percentage_point_instances':part.net.sum(),'pending_n':int(((signals.ticker==ticker)&signals.label_status.str.startswith('PENDING')).sum()),**out})
    by_ticker=pd.DataFrame(rows).sort_values('ticker');by_ticker.to_csv(OUT/'results-by-ticker.csv',index=False)
    full=metrics(closed.gross_directional_pct,.25);without_sqqq=metrics(closed.loc[closed.ticker!='SQQQ.US','gross_directional_pct'],.25)
    without_meta=metrics(closed.loc[closed.ticker!='META.US','gross_directional_pct'],.25)
    legacy=pd.read_csv(ROOT/'data/strategy_runtime/20261018/oos-backtest-frequency-capped-221-trades.csv')
    old_ids={(str(r.ticker)+'.US',str(r.MarketDate)) for r in legacy.itertuples()}
    new_ids={(str(r.ticker),str(r.market_date)) for r in signals.itertuples()}
    save(OUT/'legacy-signal-parity-not-outcome-parity.json',{'legacy_signal_rows':len(legacy),'new_signal_rows':len(signals),'same_symbol_and_D0':len(old_ids&new_ids),'old_only':len(old_ids-new_ids),'new_only':len(new_ids-old_ids),'caveat':'Legacy NQMAIN-sourced RETURNS ARE INVALID even when the trigger identity matches. New replay uses stock-specific, independently audited bars and only labels through October 15.'})
    biggest=by_ticker.sort_values('net_total_percentage_point_instances',ascending=False).head(3).ticker.tolist()
    without_top=metrics(closed.loc[~closed.ticker.isin(biggest),'gross_directional_pct'],.25)
    save(OUT/'concentration-sensitivity.json',{'full_including_sqqq':full,'exclude_SQQQ_unverified_swing_flag':without_sqqq,'exclude_META_posthoc_diagnostic_only':without_meta,'top_three_tickers_by_inspected_net_return':biggest,'exclude_inspected_top_three_influence_only':without_top,'status':'POSTHOC_DESCRIPTIVE_ONLY_NOT_A_TRADING_FILTER','note':'Ranking ticker contributions after inspecting this window cannot be used as a selection rule. PF is instance-weighted, not NAV.'})
    print('all',full,'without SQQQ',without_sqqq,'without META (posthoc)',without_meta,'without posthoc top three',without_top);print('top/bottom\n',by_ticker.sort_values('net_total_percentage_point_instances',ascending=False).head(10).to_string(index=False));print(by_ticker.sort_values('net_total_percentage_point_instances').head(10).to_string(index=False))

if __name__=='__main__':run()
