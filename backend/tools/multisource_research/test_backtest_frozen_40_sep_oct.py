"""Synthetic exact-bar and pending-label checks for the read-only replay."""
from datetime import date,datetime,time
import json
import sys
from pathlib import Path
import pandas as pd
import pytest
sys.path.insert(0,str(Path(__file__).resolve().parent))
from backtest_frozen_40_sep_oct import label,price_by_date,summarize,OUT


def test_scheduled_exit_never_slides_to_later_available_bar():
    bars={(date(2026,9,8),time(7,30)):{'open':100,'close':101},
          (date(2026,9,14),time(15,0)):{'open':104,'close':105}}
    result=label(date(2026,9,4),'D5',bars)
    assert result['entry_date']=='2026-09-08'  # Labor Day is closed
    assert result['exit_date']=='2026-09-14'
    assert result['label_status']=='PENDING_MISSING_EXACT_EXIT_BAR'
    bars[(date(2026,9,14),time(15,30))]={'open':105,'close':106}
    final=label(date(2026,9,4),'D5',bars)
    assert final['label_status']=='FINALIZED' and final['gross_long_pct']==pytest.approx(6)


def test_october_15_d0_is_pending_not_a_return():
    result=label(date(2026,10,15),'D5',{},cutoff=date(2026,10,15))
    assert result['label_status']=='PENDING_ENTRY_AFTER_CUTOFF'
    assert result['gross_long_pct'] is None


def test_half_day_uses_1230_bar_and_missing_premarket_fails_closed():
    d=date(2026,11,27)
    bars={(d,time(7,30)):{'open':10,'close':11},(d,time(12,30)):{'open':12,'close':13}}
    result=label(date(2026,11,25),'D1',bars,cutoff=date(2026,12,1))
    assert result['exit_bar_time']=='12:30' and result['gross_long_pct']==pytest.approx(30)
    bars.pop((d,time(7,30)))
    assert label(date(2026,11,25),'D1',bars,cutoff=date(2026,12,1))['label_status']=='BLOCKED_MISSING_EXACT_D1_0730_OPEN'


def test_duplicate_bars_fail_closed():
    d=datetime(2026,9,8,7,30)
    with pytest.raises(ValueError,match='duplicate'):
        price_by_date([(d,100,101),(d,200,201)])


def test_pending_excluded_from_pf_and_not_assigned_zero():
    x=pd.DataFrame({'market_date':['2026-10-14','2026-10-15'],'ticker':['A.US']*2,'runtime_ready':[True]*2,'triggered':[True]*2,'label_status':['FINALIZED','PENDING_ENTRY_AFTER_CUTOFF'],'gross_directional_pct':[2.0,None]})
    result=summarize(x);row=result[(result.period=='OCT_01_TO_15')&(result.population=='FROZEN40_SIGNAL')&(result.cost_bps_round_trip==25)].iloc[0]
    assert row.finalized_n==1 and row.pending_entry_n==1 and row.mean_net_pct==pytest.approx(1.75)


def test_saved_replay_result_has_complete_raw_bar_audit_and_pending_accounting():
    manifest=json.loads((OUT/'run-manifest.json').read_text())
    audit=json.loads((OUT/'independent-raw-bar-audit.json').read_text())
    signals=pd.read_csv(OUT/'signal-ledger-including-pending.csv')
    assert manifest['frozen_signal_dates']==len(signals)==221
    assert audit['matched']==audit['audited_finalized_signals']==165 and audit['mismatches']==0
    assert signals.label_status.value_counts().to_dict()=={'FINALIZED':165,'PENDING_EXIT_AFTER_CUTOFF':39,'PENDING_ENTRY_AFTER_CUTOFF':17}
    assert not signals.duplicated(['ticker','market_date']).any()
    assert signals.market_date.max()<='2026-10-15'
