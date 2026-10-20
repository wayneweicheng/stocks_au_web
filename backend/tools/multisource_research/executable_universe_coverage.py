"""Assess whether the existing 07:30 30M-price entry supports quote-universe expansion."""
from __future__ import annotations
import json
import pandas as pd
from fixed_hypothesis_screen import BASE,LABELS


def run():
    quotes=pd.read_csv(BASE/'option-quote-universe-coverage-through-cutoff.csv')
    bars=pd.read_csv(BASE/'intraday-30m-coverage-through-cutoff.csv')
    labeled=set(pd.read_csv(LABELS,usecols=['ticker']).ticker)
    x=quotes.loc[quotes.ObservationDays>=120,['ASXCode','ObservationDays']].merge(bars[['ASXCode','BarDays','FirstDate','LastDate']],on='ASXCode',how='left',validate='one_to_one')
    x['HasExistingCorrectedLabel']=x.ASXCode.isin(labeled)
    x['HasAny30m']=x.BarDays.notna()
    x['Has120ThirtyMinuteDays']=x.BarDays.fillna(0)>=120
    x.sort_values(['HasAny30m','ObservationDays'],ascending=[True,False]).to_csv(BASE/'expanded-universe-entry-coverage.csv',index=False)
    extras=sorted(x.loc[x.HasAny30m&~x.HasExistingCorrectedLabel,'ASXCode'].tolist())
    summary={'quote_symbols_at_least_120_days':len(x),'with_30m_history':int(x.HasAny30m.sum()),'with_30m_at_least_120_days':int(x.Has120ThirtyMinuteDays.sum()),'existing_label_symbols_with_long_quotes':int(x.HasExistingCorrectedLabel.sum()),'long_quote_symbols_with_30m_outside_existing_label_universe':extras,'conclusion':'Only non-equity context instruments have 30M history beyond the original 87. A daily-open/09:30 entry is a distinct untested execution family, not an expansion of the 07:30 label.'}
    (BASE/'expanded-universe-entry-coverage.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary,indent=2))

if __name__=='__main__':run()
