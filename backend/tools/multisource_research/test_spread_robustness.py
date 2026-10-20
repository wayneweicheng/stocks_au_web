from __future__ import annotations
import sys
from pathlib import Path
import pandas as pd

sys.path.insert(0,str(Path(__file__).resolve().parent))
from spread_robustness import stratified_date_differences, folds, RANK


def test_control_is_other_symbol_same_date_volatility_and_relative_volume_bin():
    day=pd.Timestamp('2026-07-08')
    d=pd.DataFrame({'ticker':['A.US','B.US','C.US','D.US'],'market_date':[day]*4,
        RANK:[.9,.1,.1,.9],'ATR14Pct':[3,3,8,15],
        'VolumePrior60Rank':[.5,.5,.5,.5],'ret_D5':[2,1,50,70]})
    matched,dates,total=stratified_date_differences(d)
    assert total==2
    assert len(matched)==1
    assert matched.iloc[0].ticker=='A.US'
    assert matched.iloc[0].control_n==1
    assert abs(matched.iloc[0].incremental_pp-1)<1e-10
    assert len(dates)==1


def test_purge_removes_train_label_exiting_at_validation_boundary():
    d=pd.DataFrame({'market_date':pd.date_range('2026-01-01',periods=10),
        'exit_D5':pd.date_range('2026-01-02',periods=10)})
    train=next(iter(folds(d)))[1]
    assert (train.exit_D5<pd.Timestamp('2026-01-07')).all()
    assert len(train)==5
