"""Regression tests for the actual screen feature-availability and split seams."""
import sys
from pathlib import Path
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fixed_hypothesis_screen import SCREEN_DEFS, feature_eligible_mask


def test_combined_conditions_have_available_features_without_fake_joint_column():
    panel = pd.DataFrame({
        'BB20PercentB': [0.05, 0.05, None],
        'GEX_ZScore': [-1.5, None, -1.5],
        'ret_D5': [1.0, 2.0, 3.0],
    })
    family, feature, predicate, direction = SCREEN_DEFS['COMBO_BB_LOWER_GEX_LOW_LONG']
    eligible = feature_eligible_mask(panel, feature)
    assert eligible.tolist() == [True, False, False]
    assert (predicate(panel).fillna(False) & eligible).tolist() == [True, False, False]


def test_missing_column_fails_closed_instead_of_all_false_or_key_error():
    panel = pd.DataFrame({'BB20PercentB': [.05]})
    assert feature_eligible_mask(panel, ('BB20PercentB', 'GEX_ZScore')).tolist() == [False]
