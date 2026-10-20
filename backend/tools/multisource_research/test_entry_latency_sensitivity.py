from datetime import datetime
import sys
from pathlib import Path
import pytest
sys.path.insert(0,str(Path(__file__).resolve().parent))
from entry_latency_sensitivity import entry_proxies


def test_entry_proxies_do_not_use_future_bar_for_missing_timestamp():
    d=datetime.fromisoformat('2026-08-04T07:30:00')
    result=entry_proxies([(d,100,101)])
    assert result[d.date()]=={'OPEN_0730':100,'CLOSE_0730':101,'OPEN_0800':None,'OPEN_0930':None}


def test_duplicate_bar_is_rejected():
    d=datetime.fromisoformat('2026-08-04T07:30:00')
    with pytest.raises(ValueError,match='duplicate'):
        entry_proxies([(d,100,101),(d,200,201)])
