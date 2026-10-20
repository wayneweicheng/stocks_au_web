"""Tests for StockDB_US local-wall-clock bar interpretation."""
from __future__ import annotations
import sys
from pathlib import Path
import pandas as pd
import pytest

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
from us_gex_sql_research import local_market_time  # noqa: E402


def test_sql_0730_is_local_0730_not_0330_or_1130():
    result = local_market_time(pd.Series([pd.Timestamp("2026-08-04 07:30:00")]))
    assert result.iloc[0].strftime("%Y-%m-%d %H:%M %z") == "2026-08-04 07:30 -0400"


def test_local_market_time_rejects_timezone_aware_input():
    source = pd.Series([pd.Timestamp("2026-08-04 07:30:00", tz="America/New_York")])
    with pytest.raises(ValueError, match="expected naive"):
        local_market_time(source)


def test_local_market_time_fails_closed_on_ambiguous_or_nonexistent_dst_clock():
    with pytest.raises(Exception):
        local_market_time(pd.Series([pd.Timestamp("2026-03-08 02:30:00")]))
    with pytest.raises(Exception):
        local_market_time(pd.Series([pd.Timestamp("2026-11-01 01:30:00")]))
