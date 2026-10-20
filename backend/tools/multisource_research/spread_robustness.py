"""Research-only diagnostics for the already-inspected high option-spread-rank lead.

No threshold search or portfolio claim. Use the same corrected stock labels, purged
chronological folds and D5 25-bp round-trip convention as fixed_hypothesis_screen.
"""
from __future__ import annotations
import json
import sys
from pathlib import Path
import numpy as np
import pandas as pd
from fixed_hypothesis_screen import BASE, LABELS, OPTIONS, TECH, metrics
from technical_features import _prior_rank
sys.path.insert(0,'C:/Repo/stocks_collecting/src')
from strategy_runtime.strategies.spx_gex.calendar import USCashCalendar

OUT=BASE/'spread_robustness'
COST_PCT=.25
RANK='ValidSpreadVolumeWeightedPrior60Rank'


def folds(panel):
    dates=sorted(panel.market_date.dropna().unique())
    first=dates[int(len(dates)*.6)]; second=dates[int(len(dates)*.8)]
    for name,start,end in [('TRAIN',dates[0],first),('VALIDATION',first,second),('FINAL_RESEARCH_TAIL',second,pd.Timestamp('2026-09-01'))]:
        x=panel[(panel.market_date>=start)&(panel.market_date<end)&(panel.exit_D5<end)].copy()
        yield name,x


def join_panel():
    labels=pd.read_csv(LABELS,usecols=['ticker','market_date','ret_D5','exit_D5']);labels['market_date']=pd.to_datetime(labels.market_date);labels['exit_D5']=pd.to_datetime(labels.exit_D5)
    tech=pd.read_csv(TECH,usecols=['ASXCode','ObservationDate','ATR14Pct','Volume']);tech=tech.rename(columns={'ASXCode':'ticker','ObservationDate':'market_date'});tech['market_date']=pd.to_datetime(tech.market_date)
    tech=tech.sort_values(['ticker','market_date'])
    # Prior-only within-symbol rank, insensitive to a fixed vendor volume scale.
    tech['VolumePrior60Rank']=tech.groupby('ticker').Volume.transform(lambda s:_prior_rank(s))
    option=pd.read_csv(OPTIONS,usecols=['ASXCode','ObservationDate',RANK,'TotalSpreadVolumeCoverage']);option=option.rename(columns={'ASXCode':'ticker','ObservationDate':'market_date'});option['market_date']=pd.to_datetime(option.market_date)
    # Lag on the full source history, not the selected-label subset: a previous
    # quote exists even when there was no GEX-feature label on that D0.
    option=option.sort_values(['ticker','market_date']);option['PriorQuoteSpreadRank']=option.groupby('ticker')[RANK].shift(1)
    option['PriorQuoteDate']=option.groupby('ticker').market_date.shift(1)
    cal=USCashCalendar()
    expected={day:pd.Timestamp(cal.session_offset(day.date(),-1)) for day in option.market_date.unique()}
    option.loc[option.PriorQuoteDate!=option.market_date.map(expected),'PriorQuoteSpreadRank']=np.nan
    p=labels.merge(tech,on=['ticker','market_date'],how='left',validate='one_to_one').merge(option,on=['ticker','market_date'],how='left',validate='one_to_one')
    return p.sort_values(['ticker','market_date']).reset_index(drop=True)


def stratified_date_differences(data):
    """Same-date, ATR and prior relative stock-volume strata; no control reused as a signal.

    Predetermined broad bins prevent searching for a favorable match. A signal
    without a contemporaneous non-signal control is excluded and counted.
    """
    x=data[data[RANK].notna()&data.ATR14Pct.notna()&data.VolumePrior60Rank.notna()&data.ret_D5.notna()].copy()
    x['atr_bin']=pd.cut(x.ATR14Pct,[-np.inf,2,5,10,np.inf],labels=False)
    x['volume_bin']=pd.cut(x.VolumePrior60Rank,[-.01,.33,.66,1.01],labels=False)
    x['trigger']=x[RANK]>=.80;x['net']=x.ret_D5-COST_PCT
    keys=['market_date','atr_bin','volume_bin']
    control=x.loc[~x.trigger].groupby(keys).agg(control_mean=('net','mean'),control_n=('net','size'))
    signal=x.loc[x.trigger].join(control,on=keys)
    paired=signal[signal.control_n.notna()].copy()
    paired['incremental_pp']=paired.net-paired.control_mean
    per_day=paired.groupby('market_date').agg(mean_incremental_pp=('incremental_pp','mean'),signal_n=('incremental_pp','size'))
    return paired,per_day,int(x.trigger.sum())


def block_interval(per_day,seed=20261018,reps=2000,block=5):
    """Descriptive date-block CI; does not account for screening/selection."""
    values=per_day.mean_incremental_pp.to_numpy(float);n=len(values)
    if n<block:return None,None
    rng=np.random.default_rng(seed);starts=np.arange(n);draw=[]
    for _ in range(reps):
        picked=np.concatenate([np.arange(s,s+block)%n for s in rng.choice(starts,size=int(np.ceil(n/block)),replace=True)])[:n]
        draw.append(values[picked].mean())
    return [float(v) for v in np.quantile(draw,[.025,.975])]


def summarize(name,split,x):
    ret=x.ret_D5.dropna()
    return {'split':split,'case':name,'signal_n':len(ret),'ticker_n':x.loc[ret.index,'ticker'].nunique(),'date_n':x.loc[ret.index,'market_date'].nunique(),**metrics(ret,COST_PCT)}


def run():
    OUT.mkdir(parents=True,exist_ok=True)
    panel=join_panel();rows=[];details=[]
    for split,full in folds(panel):
        eligible=full[full[RANK].notna()&full.ret_D5.notna()].copy();signal=eligible[eligible[RANK]>=.8].copy()
        rows.extend([summarize('SIGNAL',split,signal),summarize('SAME_COVERAGE_UNCONDITIONAL',split,eligible),summarize('LAGGED_QUOTE_RANK',split,eligible[eligible.PriorQuoteSpreadRank>=.8])])
        top=signal.groupby('ticker').ret_D5.apply(lambda s:(s-COST_PCT).sum()).nlargest(5).index
        rows.extend([summarize('EXCLUDE_SNDU',split,signal[signal.ticker!='SNDU.US']),summarize('EXCLUDE_TOP5_CONTRIBUTORS_INSPECTED',split,signal[~signal.ticker.isin(top)])])
        capped=signal.copy();capped.ret_D5=capped.ret_D5.clip(-20,20)
        rows.append(summarize('CAP_EACH_GROSS_RETURN_TO_PLUS_MINUS_20_PCT',split,capped))
        paired,per_day,signal_qualified=stratified_date_differences(eligible)
        lo,hi=block_interval(per_day)
        details.append({'split':split,'signal_n_with_atr_and_volume_rank':signal_qualified,'matched_signal_n':len(paired),'matched_ticker_n':paired.ticker.nunique(),'matched_dates':len(per_day),'unmatched_signal_n':signal_qualified-len(paired),'mean_signal_minus_controls_pp':float(paired.incremental_pp.mean()) if len(paired) else None,'mean_date_equal_weight_incremental_pp':float(per_day.mean_incremental_pp.mean()) if len(per_day) else None,'date_block_ci_95_descriptive_pp':[lo,hi],'top5_tickers_by_inspected_gross_net_contribution':list(top)})
        paired[['ticker','market_date','net','control_mean','control_n','incremental_pp','atr_bin','volume_bin']].to_csv(OUT/f'matched-trades-{split.lower()}.csv',index=False)
    pd.DataFrame(rows).to_csv(OUT/'stress-cases.csv',index=False)
    pd.DataFrame(details).to_csv(OUT/'matched-controls.csv',index=False)
    (OUT/'method.json').write_text(json.dumps({'status':'EXPLORATORY_POST_INSPECTION','source':'corrected August labels and causal daily panels','horizon':'D5','stock_round_trip_cost_bps':25,'condition':'option spread volume weighted prior 60 rank >= 0.80','matched_controls':'non-trigger observations same date, ATR14Pct bin <=2, (2,5], (5,10], >10, and stock prior-only within-symbol 60-day volume rank <=.33, (.33,.66], (.66,1]; exclude unmatched signals. Absolute volume units not assumed validated','bootstrap':'2000 circular 5-date block resamples of cross-sectional day-mean differences; descriptive, NOT post-selection confidence','extra_quote_lag':'D0 uses the immediately previous XNYS session option-rank (D-1), not an arbitrarily old quote; same D0 underlying label, no forward fill','exclusions':'top five determined separately per split using inspected returns and solely an influence diagnostic; NEVER a tradable rule','cutoff':'2026-08-31'},indent=2)+'\n')
    print(pd.DataFrame(details).to_string(index=False));print(pd.DataFrame(rows).to_string(index=False))

if __name__=='__main__':run()
