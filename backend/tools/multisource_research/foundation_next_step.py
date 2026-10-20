"""Read-only Stage 0/1 audit: snapshot live state and August research coverage.

Never provisions contracts or changes SQL. Output is confined to 20261018-b-research.
No descriptor files are unpacked inside the recursively scanned runtime tree.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

from audit_august_labels import ROOT, connect

BASE = ROOT / 'data/strategy_runtime/20261018-b-research'
SOURCE = ROOT / 'data/strategy_runtime/20261018-a/selected_gex_live_production_contracts_2026-10-18-a'
DEFAULT_OUTPUT = BASE / 'foundation-next-step'


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def source_paths():
    return {
        'universe': BASE / 'research_corrected/data-audit.json',
        'labels': BASE / 'research_corrected/eligible-outcomes.csv',
        'bars': BASE / 'intraday-30m-coverage-through-cutoff.csv',
        'quotes': BASE / 'option-quote-universe-coverage-through-cutoff.csv',
        'daily': BASE / 'technical_features/price-history-coverage.csv',
        'frozen': SOURCE / 'master-manifest.json',
        'runtime_readiness': BASE / 'baseline_40_runtime_readiness.csv',
        'label_audit': BASE / 'august-label-audit.csv',
        'operator_universe': DEFAULT_OUTPUT / 'operator-universe-2026-10-18.txt',
    }


def classify(symbol: str) -> str:
    # Only the three context/root symbols are unambiguous without an authoritative
    # dated instrument registry. Names that look like ETFs are not guessed here.
    if symbol in {'SPX.US', '_SPX.US', 'SPXW.US', '_VIX.US'}:
        return 'CONTEXT_OR_OPTION_ROOT_NOT_ORDINARY_STOCK'
    return 'UNVERIFIED_STOCK_OR_ETF_KIND'


def coverage(paths: dict[str, Path]) -> tuple[pd.DataFrame, dict]:
    universe = json.loads(paths['universe'].read_text())
    symbols = set(universe['symbols'])
    frozen = json.loads(paths['frozen'].read_text())
    selected = {x['ticker'] + '.US' for x in frozen['strategies']}
    lines = paths['operator_universe'].read_text().splitlines()
    if not lines or lines[0] != 'ASXCode' or len(lines[1:]) != len(set(lines[1:])):
        raise ValueError('operator universe must have header and unique codes')
    operator = set(lines[1:])
    if len(symbols) != 90 or len(selected) != 40 or not selected <= symbols or not selected <= operator:
        raise ValueError('unexpected source-universe/frozen-rule/operator identity; stop and investigate')
    bar = pd.read_csv(paths['bars']).set_index('ASXCode')
    quote = pd.read_csv(paths['quotes']).set_index('ASXCode')
    daily = pd.read_csv(paths['daily']).set_index('ASXCode')
    readiness = pd.read_csv(paths['runtime_readiness'], usecols=['ticker', 'market_date', 'status'])
    ready = readiness[readiness.status == 'READY'].groupby('ticker').market_date.nunique().to_dict()
    # This read is restricted to identity/label columns: the predictor fields are
    # NOT presumed causally available just because they are present in this CSV.
    labels = pd.read_csv(paths['labels'], usecols=['ticker', 'market_date', 'ret_D1', 'ret_D3', 'ret_D5'])
    if labels.duplicated(['ticker', 'market_date']).any():
        raise ValueError('duplicate eligible symbol/D0 date')
    label_dates = labels.groupby('ticker').market_date.nunique().to_dict()
    resolved = {h: labels[labels[f'ret_{h}'].notna()].groupby('ticker').market_date.nunique().to_dict() for h in ('D1', 'D3', 'D5')}
    rows = []
    for sym in sorted(symbols | operator | set(quote.index) | set(bar.index) | set(daily.index) | {'SPX.US'}):
        n = int(label_dates.get(sym, 0))
        rows.append({
            'symbol': sym, 'instrument_class': classify(sym),
            'in_august_gex_universe': sym in symbols, 'in_operator_universe': sym in operator,
            'in_frozen_40': sym in selected,
            'eligible_d0_dates': n, 'resolved_D1': int(resolved['D1'].get(sym, 0)),
            'resolved_D3': int(resolved['D3'].get(sym, 0)), 'resolved_D5': int(resolved['D5'].get(sym, 0)),
            'days_with_any_30m_bars': int(bar.at[sym, 'BarDays']) if sym in bar.index else 0,
            'quote_observation_days_not_readiness_proof': int(quote.at[sym, 'ObservationDays']) if sym in quote.index else 0,
            'daily_price_bars': int(daily.at[sym, 'daily_bars']) if sym in daily.index else 0,
            'frozen_runtime_ready_d0': int(ready.get(sym, 0)) if sym in selected else None,
            'runtime_readiness_state': 'OFFLINE_RUNTIME_SIMULATION_NOT_PUBLISHED_ASOF_PROVEN' if sym in selected else 'NOT_TESTED',
            'eligibility_state': ('CONTEXT_ONLY' if classify(sym).startswith('CONTEXT') else
                                  'CORRECTED_0730_LABEL_EXISTS' if n else 'NO_CORRECTED_0730_LABEL'),
        })
    table = pd.DataFrame(rows)
    outside = table[table.in_august_gex_universe & ~table.in_frozen_40 & (table.eligible_d0_dates > 0)]
    summary = {
        'cutoff': universe['cutoff'], 'august_gex_universe': len(symbols),
        'frozen_40': len(selected), 'eligible_symbols': len(label_dates),
        'outside_40_eligible_symbols': len(outside), 'outside_40_eligible_d0': int(outside.eligible_d0_dates.sum()),
        'no_label_in_august_universe': table[table.in_august_gex_universe & (table.eligible_d0_dates == 0)].symbol.tolist(),
        'operator_supplied_count': len(operator), 'operator_outside_frozen_40': len(operator - selected),
        'operator_outside_40_with_corrected_labels': int(table[table.in_operator_universe & ~table.in_frozen_40 & (table.eligible_d0_dates > 0)].shape[0]),
        'operator_not_in_august_gex': sorted(operator - symbols),
        'august_gex_not_in_operator': sorted(symbols - operator),
        'operator_historical_membership': 'NOT_PROVED; supplied as undated snapshot',
        'previously_claimed_92_count_reconciled': len(operator) == 92,
        'feature_availability': 'NOT_CERTIFIED; observation dates and file coverage are not publication timestamps',
        'source_hashes': {name: file_hash(p) for name, p in paths.items()},
    }
    if (summary['eligible_symbols'], summary['outside_40_eligible_symbols'], summary['outside_40_eligible_d0']) != (87, 47, 3310):
        raise ValueError('unexpected baseline coverage; investigate before publishing')
    return table, summary


def live_snapshot(connection, master: dict, source_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, dict]:
    """Only parameterized SELECTs. No configuration bodies, recipients or PII exported."""
    selected = {r['strategy_code']: r for r in master['strategies']}
    cursor = connection.cursor()
    cursor.execute("""SELECT f.StrategyCode, v.VersionCode, v.ConfigurationHash, v.ConfigurationJson,
      d.StrategyDeploymentID, d.DeploymentKey, d.EnvironmentType, d.IsEnabled, d.ExecutionEnabled, d.NotificationEnabled,
      d.ConfigurationJson
      FROM StockDB_US.TradingSignal.StrategyDeployment d
      JOIN StockDB_US.TradingSignal.StrategyVersion v ON v.StrategyVersionID=d.StrategyVersionID
      JOIN StockDB_US.TradingSignal.StrategyDefinition f ON f.StrategyDefinitionID=v.StrategyDefinitionID
      WHERE f.StrategyCode LIKE 'GEX[_]%[_]AUGUST[_]2026[_]BEST'
      ORDER BY f.StrategyCode, d.DeploymentKey""")
    deployments = []
    for code, version, vhash, vconfig, dep_id, key, env, enabled, execution, notifications, dconfig in cursor.fetchall():
        if code not in selected:
            continue
        descriptor = json.loads((source_dir / selected[code]['directory'] / 'strategy.descriptor.json').read_text())
        configuration = json.loads(vconfig or '{}')
        deployment_config = json.loads(dconfig or '{}')
        cursor2 = connection.cursor()
        cursor2.execute('''SELECT StrategyScheduleID,ScheduleKey,RunKind,IsEnabled,TimeZoneName,SessionOffset,
            CONVERT(varchar(16),LocalTime),DueWindowSeconds,CatchUpPolicy
          FROM StockDB_US.TradingSignal.StrategySchedule WHERE StrategyDeploymentID=?''', dep_id)
        schedules = [{'schedule_id': int(r[0]), 'schedule_key': r[1], 'run_kind': r[2], 'enabled': bool(r[3]),
                      'time_zone': r[4], 'session_offset': r[5], 'local_time': r[6],
                      'due_window_seconds': r[7], 'catch_up_policy': r[8]} for r in cursor2.fetchall()]
        cursor2.execute('''SELECT RoleCode,InstrumentCode,InstrumentKind FROM StockDB_US.TradingSignal.StrategyInstrumentRole
          WHERE StrategyDeploymentID=? ORDER BY RoleCode''', dep_id)
        roles = [{'role': r[0], 'instrument': r[1], 'instrument_kind': r[2]} for r in cursor2.fetchall()]
        cursor2.execute('''SELECT COUNT_BIG(*) FROM StockDB_US.TradingSignal.Observation WHERE StrategyDeploymentID=?''', dep_id)
        obs_count = int(cursor2.fetchone()[0])
        cursor2.execute('''SELECT COUNT_BIG(*) FROM StockDB_US.TradingSignal.StrategyRun WHERE StrategyDeploymentID=?''', dep_id)
        run_count = int(cursor2.fetchone()[0])
        cursor2.close()
        saved_source_hash = (configuration.get('provenance') or {}).get('source_hash')
        deployments.append({
            'strategy_code': code, 'version_code': version, 'version_configuration_hash': vhash,
            'deployment_id': int(dep_id), 'deployment_key': key, 'environment': env,
            'enabled': bool(enabled), 'execution_enabled': bool(execution), 'notification_enabled': bool(notifications),
            'configuration_notification_enabled_override': deployment_config.get('notification_enabled'),
            'schedules': schedules, 'instrument_roles': roles,
            'enabled_schedule_count': sum(s['enabled'] for s in schedules),
            'archived_descriptor_sha256': file_hash(source_dir / selected[code]['directory'] / 'strategy.descriptor.json'),
            'archive_source_hash_matches_version': saved_source_hash == descriptor['provenance']['source_hash'],
            'version_source_hash': saved_source_hash, 'sql_broker_guard': (configuration.get('production_policy') or {}).get('broker_execution'),
            'deployment_broker_guard': (deployment_config.get('production_policy') or {}).get('broker_execution'),
            'observation_rows': obs_count, 'run_rows': run_count,
        })
    active = [r for r in deployments if r['environment'] == 'LIVE_MANUAL' and r['enabled']]
    # Per-deployment last 20 *distinct* D0 market dates, latest revision on that
    # day. A missing observation is not a NO_SIGNAL or missing notification.
    observations = []
    for item in active:
        cursor.execute('''WITH latest AS (
            SELECT ObservationID,MarketDate,RevisionNo,QualityStatus,CreatedUtc,
                ROW_NUMBER() OVER(PARTITION BY MarketDate ORDER BY RevisionNo DESC, CreatedUtc DESC, ObservationID DESC) AS rn
            FROM StockDB_US.TradingSignal.Observation WHERE StrategyDeploymentID=?
          ) SELECT TOP (20) ObservationID,MarketDate,RevisionNo,QualityStatus
            FROM latest WHERE rn=1 ORDER BY MarketDate DESC''', item['deployment_id'])
        observed = cursor.fetchall()
        for observation_id, d0, revision, quality in observed:
            cursor2 = connection.cursor()
            cursor2.execute('''SELECT SignalID,Classification,ActionCode FROM StockDB_US.TradingSignal.Signal WHERE ObservationID=?''', observation_id)
            sigs = cursor2.fetchall()
            signal_ids = [int(s[0]) for s in sigs]
            notice_counts = Counter()
            outcome_counts = Counter()
            for sig in signal_ids:
                cursor2.execute('''SELECT NotificationType,COUNT_BIG(*) FROM StockDB_US.TradingSignal.NotificationEvent
                  WHERE SignalID=? GROUP BY NotificationType''', sig)
                notice_counts.update({str(r[0]): int(r[1]) for r in cursor2.fetchall()})
                cursor2.execute('''SELECT HorizonCode,COUNT_BIG(*) FROM StockDB_US.TradingSignal.SignalOutcome
                  WHERE SignalID=? AND SupersedesSignalOutcomeID IS NULL GROUP BY HorizonCode''', sig)
                outcome_counts.update({str(r[0]): int(r[1]) for r in cursor2.fetchall()})
            cursor2.close()
            observations.append({
                'strategy_code': item['strategy_code'], 'deployment_id': item['deployment_id'],
                'market_date': str(d0)[:10], 'revision': int(revision), 'quality_status': quality,
                'signal_count': len(sigs), 'classifications': ','.join(sorted(str(s[1]) for s in sigs)),
                'action_codes': ','.join(sorted(str(s[2]) for s in sigs)),
                'notification_type_counts': json.dumps(notice_counts, sort_keys=True),
                'outcome_horizon_counts': json.dumps(outcome_counts, sort_keys=True),
                'raw_feature_parity': 'NOT_TESTED', 'raw_predicate_parity': 'NOT_TESTED',
            })
    cursor.close()
    summary = {
        'checked_at_utc': datetime.now(timezone.utc).isoformat(), 'sql_operations': 'SELECT_ONLY',
        'selected_codes': len(selected), 'all_deployment_rows': len(deployments),
        'enabled_live_manual': len(active),
        'notification_enabled_live_manual': sum(r['notification_enabled'] for r in active),
        'live_notification_config_override_true': sum(r['configuration_notification_enabled_override'] is True for r in active),
        'execution_enabled_live_manual': sum(r['execution_enabled'] for r in active),
        'enabled_live_schedules': sum(r['enabled_schedule_count'] for r in active),
        'archived_source_hash_matches_live_version': sum(r['archive_source_hash_matches_version'] for r in active),
        'live_observations': sum(r['observation_rows'] for r in active),
        'live_runs': sum(r['run_rows'] for r in active),
        'last_20_observed_days_extracted': len(observations),
        'readiness_and_raw_predicate_parity': 'NOT_TESTED; no live rows is not NO_SIGNAL',
    }
    return pd.DataFrame(deployments), pd.DataFrame(observations), summary


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument('--offline', action='store_true', help='coverage only; skip live SQL SELECT audit')
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to(BASE.resolve()):
        parser.error('research output must be inside 20261018-b-research')
    paths = source_paths()
    table, cov = coverage(paths)
    output.mkdir(parents=True, exist_ok=True)
    table.to_csv(output / 'canonical-universe-coverage.csv', index=False)
    (output / 'coverage-summary.json').write_text(json.dumps(cov, indent=2) + '\n')
    audit_path = output / 'august-label-independent-raw-bar-audit.csv'
    if audit_path.exists():
        raw_audit = pd.read_csv(audit_path)
        if (len(raw_audit) != 10591 or not raw_audit.status.eq('OK').all() or
            not raw_audit.entry_price_match.all() or not raw_audit.entry_date_match.all() or
            not raw_audit.entry_exact_0730.all()):
            raise ValueError('independent entry-bar audit failed')
        results = {'rows': len(raw_audit), 'entry_matches': int(raw_audit.entry_price_match.sum()),
                   'audit_sha256': file_hash(audit_path), 'exits': {}}
        for horizon in ('D1', 'D3', 'D5'):
            series = raw_audit[f'{horizon}_match'].dropna()
            if not series.all():
                raise ValueError('independent exit-bar audit failed for ' + horizon)
            results['exits'][horizon] = {'resolved': len(series), 'pending_or_unresolved': len(raw_audit) - len(series)}
        (output / 'label-audit-summary.json').write_text(json.dumps(results, indent=2) + '\n')
    if not args.offline:
        connection = connect(ROOT / '.env')
        try:
            dep, obs, status = live_snapshot(connection, json.loads(paths['frozen'].read_text()), SOURCE)
        finally:
            connection.close()
        dep.to_json(output / 'live-deployments.json', orient='records', indent=2)
        obs.to_csv(output / 'last-20-live-observations.csv', index=False)
        (output / 'live-summary.json').write_text(json.dumps(status, indent=2) + '\n')
        print('live:', json.dumps(status))
    print('coverage:', json.dumps({k: v for k, v in cov.items() if k != 'source_hashes'}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
