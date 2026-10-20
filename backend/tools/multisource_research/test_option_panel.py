"""Causal and valid-denominator tests for OptionDelayedQuote_V2 aggregates."""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np
import pandas as pd

sys.path.insert(0,str(Path(__file__).resolve().parent))
from build_option_panel import aggregate, prior_rank


def raw_rows():
    common={
        'ObservationDate':pd.Timestamp('2026-08-03'),'ContractRows':1,'Contracts':1,
        'OpenInterest':10,'IVOINum':0.0,'IVOIDen':0.0,'DeltaNum':0.0,'DeltaDen':0.0,
        'GammaNum':0.0,'GammaDen':0.0,'VegaNum':0.0,'VegaDen':0.0,
        'SpreadNum':0.0,'SpreadDen':0.0,'VolDTE0_7':0,'VolDTE8_30':0,'VolDTE31_60':0,
        'OIDTE0_7':0,'OIDTE8_30':0,'OIDTE31_60':0,'NearVol45':0,'NearOI45':0,
    }
    call={**common,'PorC':'C','Volume':100,'IVVolNum':5.0,'IVVolDen':10.0,'DeltaNum':4.0,'DeltaDen':20.0,'GammaNum':8.0,'GammaDen':20.0,'VegaNum':10.0,'VegaDen':20.0,'SpreadNum':0.2,'SpreadDen':20.0}
    put={**common,'PorC':'P','Volume':10,'IVVolNum':2.0,'IVVolDen':2.0,'DeltaNum':1.0,'DeltaDen':2.0,'GammaNum':3.0,'GammaDen':2.0,'VegaNum':4.0,'VegaDen':2.0,'SpreadNum':0.1,'SpreadDen':2.0}
    return pd.DataFrame([call,put])


def test_weighted_features_use_only_valid_value_denominators():
    result=aggregate('TEST',raw_rows()).iloc[0]
    assert result['CallIVVolumeWeighted']==0.5
    assert result['PutIVVolumeWeighted']==1.0
    assert np.isclose(result['IVVolumeWeighted'],7.0/12.0)
    assert np.isclose(result['TotalIVVolumeCoverage'],12.0/110.0)
    assert np.isclose(result['AbsDeltaVolumeWeighted'],5.0/22.0)
    assert np.isclose(result['ValidSpreadVolumeWeighted'],0.3/22.0)


def test_prior_ranks_exclude_current_observation_and_fail_closed_until_warm():
    values=pd.Series([1.0,2.0,3.0,0.0])
    result=prior_rank(values,window=3,minimum=2)
    assert np.isnan(result[0])
    assert np.isnan(result[1])
    assert result[2]==1.0
    assert result[3]==0.0
