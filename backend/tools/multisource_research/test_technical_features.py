"""Synthetic, causal tests for temporary daily technical features."""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
from technical_features import build_features


def bars(n=140):
    dates = pd.bdate_range("2025-01-02", periods=n)
    close = 100.0 + np.arange(n) * 0.2 + np.sin(np.arange(n) / 4.0)
    return pd.DataFrame({
        "ASXCode": "TEST.US", "ObservationDate": dates,
        "Open": close - 0.1, "High": close + 1.0, "Low": close - 1.0,
        "Close": close, "Volume": 1000 + np.arange(n) * 10,
        "VWAP": close - 0.05,
    })


def test_builds_technical_feature_families_and_prior_levels():
    result = build_features(bars())
    assert result.RSI14.notna().sum() > 100
    assert result.BB20PercentB.notna().sum() > 100
    assert result.ATR14.notna().sum() > 100
    assert result.PriorHigh20.notna().sum() > 100
    assert result.PriorDayPivot.iloc[30] == (result.High.iloc[29] + result.Low.iloc[29] + result.Close.iloc[29]) / 3
    assert result.PriorHigh20.iloc[30] == result.High.iloc[10:30].max()
    assert result.PriceDistSMA20ATR.notna().sum() > 80
    assert result.PriorWeekPivot.notna().sum() > 80
    assert result.PriorMonthPivot.notna().sum() > 80


def test_prior_support_and_pivots_do_not_use_current_or_future_ohlc():
    source = bars()
    baseline = build_features(source)
    changed = source.copy()
    changed.loc[100:, ["High", "Low", "Close", "Open", "Volume"]] *= 1.7
    altered = build_features(changed)
    columns = ["PriorHigh20", "PriorLow20", "PriorDayPivot", "PriorWeekPivot", "PriorMonthPivot"]
    pd.testing.assert_frame_equal(baseline.loc[:99, columns], altered.loc[:99, columns])


def test_bollinger_location_and_bandwidth_are_distinct_features():
    result = build_features(bars())
    assert not result.BB20PercentB.equals(result.BB20Bandwidth)
    assert result.BB20LowerDistanceATR.notna().sum() > 80
    assert result.BB20UpperDistanceATR.notna().sum() > 80


def test_pivot_is_recorded_only_after_three_right_bars_confirm_it():
    source = bars(80)
    source.loc[20, "High"] = 150.0
    result = build_features(source)
    assert pd.isna(result.loc[22, "ConfirmedPivotHigh"])
    assert result.loc[23, "ConfirmedPivotHigh"] == 150.0
    changed = source.copy()
    changed.loc[24, "High"] = 200.0
    altered = build_features(changed)
    assert altered.loc[23, "ConfirmedPivotHigh"] == result.loc[23, "ConfirmedPivotHigh"]


def test_rejects_duplicate_daily_rows():
    source = pd.concat([bars(30), bars(30).iloc[[10]]], ignore_index=True)
    try:
        build_features(source)
    except ValueError as error:
        assert "duplicate ObservationDate" in str(error)
    else:
        raise AssertionError("duplicate daily bars must fail closed")
