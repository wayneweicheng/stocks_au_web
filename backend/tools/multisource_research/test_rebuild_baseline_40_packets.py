"""Packet rebuild must fail closed and keep the old archive untouched."""
from __future__ import annotations
import hashlib
import json
import sys
import zipfile
from pathlib import Path
import pandas as pd
import pytest
sys.path.insert(0,str(Path(__file__).resolve().parent))
from rebuild_baseline_40_packets import independent_trigger,run,RUNTIME_DEST,BASE,SOURCE,digest
from strategy_runtime.contracts.validate_contract import validate_contract


def test_independent_frozen_trigger_handles_numeric_boundaries_and_missing():
    expr='GEX_ZScore <= -1.0 AND PriceDistSMA50Pct >= 2.0'
    assert independent_trigger(expr,{'GEX_ZScore':-1,'PriceDistSMA50Pct':2})
    assert not independent_trigger(expr,{'GEX_ZScore':-.9,'PriceDistSMA50Pct':2})
    assert not independent_trigger(expr,{'GEX_ZScore':-1,'PriceDistSMA50Pct':None})
    with pytest.raises(ValueError,match='not supported'): 
        independent_trigger('GEX_ZScore <= -1.0 OR True',{'GEX_ZScore':0})


def test_existing_output_is_never_overwritten(tmp_path):
    existing=tmp_path/'archive';existing.mkdir();sentinel=existing/'dont-touch';sentinel.write_text('keep')
    with pytest.raises(FileExistsError):run(existing)
    assert sentinel.read_text()=='keep'


def test_final_review_archive_matches_runtime_events_and_disables_production(tmp_path):
    path=BASE/(RUNTIME_DEST.name+'.zip')
    assert path.is_file()
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None
        assert all(name.startswith(RUNTIME_DEST.name+'/') and '..' not in Path(name).parts for name in archive.namelist())
        archive.extractall(tmp_path)
    folder_root=tmp_path/RUNTIME_DEST.name
    manifest=json.loads((folder_root/'master-manifest.json').read_text())
    assert manifest['selected_rule_count']==manifest['generated_packet_count']==40
    assert manifest['descriptor_validation_issue_count']==0
    assert manifest['source_hashes']['manifest']==digest(SOURCE/'master-manifest.json')
    events=pd.read_csv(BASE/'baseline_40_runtime_readiness.csv')
    expected={(r.ticker,r.market_date) for r in events.itertuples() if r.status=='READY' and r.runtime_predicate is True}
    ledger=pd.read_csv(folder_root/'reconciled-trades.csv')
    assert len(ledger)==len(expected)==manifest['audited_trade_count']==1224
    assert set(map(tuple,ledger[['ticker','market_date']].to_numpy()))==expected
    assert ledger.source_raw_bar_audit.eq('PASS').all()
    assert ledger.exit_date.max()<='2026-08-31'
    for folder in (p for p in folder_root.iterdir() if p.is_dir()):
        desc=json.loads((folder/'strategy.descriptor.json').read_text())
        assert not validate_contract(folder/'strategy.md')
        assert desc['status']=='RESEARCH_DRAFT'
        assert desc['environments']==['BACKTEST']
        policy=desc['production_policy']
        assert policy['enabled'] is False and policy['notification_default'] is False
        assert policy['notifications']['enabled'] is False
        assert policy['broker_execution']=='HARD_DISABLED'
        assert all(not s['sends_notification'] for s in desc['signal_definitions'])
        for line in (folder/'file-hashes.sha256').read_text().splitlines():
            expected_hash,name=line.split('  ',1)
            assert hashlib.sha256((folder/name).read_bytes()).hexdigest()==expected_hash
