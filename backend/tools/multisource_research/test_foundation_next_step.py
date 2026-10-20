"""Offline regression gates for the read-only Stage 0/1 foundation audit."""
from __future__ import annotations

import json

import pandas as pd
import pytest

from pause_legacy_40_alerts import assert_preconditions
from foundation_next_step import BASE, SOURCE, classify, coverage, source_paths


def test_coverage_reconciles_august_and_the_frozen_set():
    table, summary = coverage(source_paths())
    assert (summary['august_gex_universe'], summary['eligible_symbols'], summary['frozen_40']) == (90, 87, 40)
    assert (summary['outside_40_eligible_symbols'], summary['outside_40_eligible_d0']) == (47, 3310)
    assert summary['no_label_in_august_universe'] == ['C.US', 'CAT.US', 'SPXW.US']
    assert table.symbol.is_unique
    assert table.loc[table.in_frozen_40, 'eligible_d0_dates'].gt(0).all()
    assert table.loc[~table.in_frozen_40, 'frozen_runtime_ready_d0'].isna().all()
    assert summary['operator_supplied_count'] == 91
    assert summary['operator_outside_frozen_40'] == 51
    assert summary['operator_outside_40_with_corrected_labels'] == 47
    assert summary['operator_not_in_august_gex'] == ['QQQU.US', '_SPX.US', '_VIX.US']
    assert summary['august_gex_not_in_operator'] == ['C.US', 'CAT.US']
    assert not summary['previously_claimed_92_count_reconciled']


def test_unverified_instrument_kind_is_not_overstated():
    assert classify('SPXW.US') == 'CONTEXT_OR_OPTION_ROOT_NOT_ORDINARY_STOCK'
    assert classify('_SPX.US') == 'CONTEXT_OR_OPTION_ROOT_NOT_ORDINARY_STOCK'
    assert classify('_VIX.US') == 'CONTEXT_OR_OPTION_ROOT_NOT_ORDINARY_STOCK'
    assert classify('SPX.US') == 'CONTEXT_OR_OPTION_ROOT_NOT_ORDINARY_STOCK'
    assert classify('SPY.US') == 'UNVERIFIED_STOCK_OR_ETF_KIND'


def test_independent_price_and_offline_runtime_evidence():
    audit = pd.read_csv(BASE / 'foundation-next-step/august-label-independent-raw-bar-audit.csv')
    assert len(audit) == 10591
    assert audit.status.eq('OK').all() and audit.entry_price_match.all()
    assert audit.entry_date_match.all() and audit.entry_exact_0730.all()
    assert [int(audit[f'{h}_match'].sum()) for h in ('D1', 'D3', 'D5')] == [10591, 10422, 10250]
    assert all(audit[f'{h}_match'].dropna().all() for h in ('D1', 'D3', 'D5'))
    readiness = pd.read_csv(BASE / 'baseline_40_runtime_readiness.csv')
    assert len(readiness) == 7127
    assert readiness.status.eq('READY').sum() == 6755
    assert readiness.runtime_predicate.fillna(False).sum() == 1224
    assert json.loads((SOURCE / 'master-manifest.json').read_text())['strategies']


def test_pause_preconditions_fail_closed_against_wrong_scope():
    from foundation_next_step import DEFAULT_OUTPUT
    rows = json.loads((DEFAULT_OUTPUT / 'operator-confirmation/live-deployments.json').read_text())
    selected = {r['strategy_code'] for r in json.loads((SOURCE / 'master-manifest.json').read_text())['strategies']}
    active = assert_preconditions(rows, selected)
    assert len(active) == 40 and sum(len(r['schedules']) for r in active) == 80
    changed = [dict(r) for r in rows]
    target = next(r for r in changed if r['environment'] == 'LIVE_MANUAL' and r['enabled'])
    target['configuration_notification_enabled_override'] = False
    with pytest.raises(ValueError, match='identity/policy/schedule'):
        assert_preconditions(changed, selected)
