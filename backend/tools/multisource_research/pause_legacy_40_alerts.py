"""Operator-approved, exact-key, transactional full pause of the archived GEX 40.

Default: read-only dry run. --apply implements the separately approved full pause:
40 old LIVE_MANUAL notification columns + JSON overrides, 80 schedules.
It does NOT disable deployments, change versions, touch outcomes, or call brokers.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from audit_august_labels import ROOT, connect
from foundation_next_step import BASE, SOURCE, live_snapshot

OUT = BASE / 'foundation-next-step'


def assert_preconditions(deployments: list[dict], expected: set[str]) -> list[dict]:
    active = [r for r in deployments if r['environment'] == 'LIVE_MANUAL' and r['enabled']]
    if len(active) != 40 or {r['strategy_code'] for r in active} != expected:
        raise ValueError('active legacy deployments differ from the exact frozen 40')
    if len({r['deployment_id'] for r in active}) != 40:
        raise ValueError('duplicate deployment id')
    schedules = [s for r in active for s in r['schedules']]
    if len(schedules) != 80 or len({s['schedule_id'] for s in schedules}) != 80:
        raise ValueError('unexpected schedule identities/count')
    for row in active:
        if (row['version_code'] != '1.0.0-production' or not row['archive_source_hash_matches_version'] or
            row['execution_enabled'] or row['sql_broker_guard'] != 'HARD_DISABLED' or
            not row['notification_enabled'] or row['configuration_notification_enabled_override'] is not True or
            len(row['schedules']) != 2 or {s['run_kind'] for s in row['schedules']} != {'EVALUATE', 'MONITOR'} or
            not all(s['enabled'] for s in row['schedules'])):
            raise ValueError('legacy live identity/policy/schedule changed for ' + row['strategy_code'])
    return sorted(active, key=lambda r: r['deployment_id'])


def locked_current(cursor, row: dict) -> tuple[str, list[int]]:
    cursor.execute('''SELECT f.StrategyCode, v.VersionCode, v.ConfigurationJson, d.EnvironmentType,
       d.IsEnabled, d.ExecutionEnabled, d.NotificationEnabled, d.ConfigurationJson
       FROM StockDB_US.TradingSignal.StrategyDeployment d WITH (UPDLOCK,HOLDLOCK)
       JOIN StockDB_US.TradingSignal.StrategyVersion v ON v.StrategyVersionID=d.StrategyVersionID
       JOIN StockDB_US.TradingSignal.StrategyDefinition f ON f.StrategyDefinitionID=v.StrategyDefinitionID
       WHERE d.StrategyDeploymentID=?''', row['deployment_id'])
    result = cursor.fetchone()
    if result is None:
        raise ValueError('deployment disappeared')
    code, version, version_json, env, enabled, execution, notifications, config_text = result
    saved_hash = (json.loads(version_json or '{}').get('provenance') or {}).get('source_hash')
    if (code != row['strategy_code'] or version != row['version_code'] or
        saved_hash != row['version_source_hash'] or env != 'LIVE_MANUAL' or
        not enabled or execution or not notifications or
        json.loads(config_text or '{}').get('notification_enabled') is not True):
        raise ValueError('deployment changed during immediate locked preflight: ' + row['strategy_code'])
    cursor.execute('''SELECT StrategyScheduleID,RunKind,IsEnabled FROM StockDB_US.TradingSignal.StrategySchedule
        WITH (UPDLOCK,HOLDLOCK) WHERE StrategyDeploymentID=? ORDER BY StrategyScheduleID''', row['deployment_id'])
    schedule_rows = [(int(s[0]), s[1], bool(s[2])) for s in cursor.fetchall()]
    expected = sorted((s['schedule_id'], s['run_kind'], True) for s in row['schedules'])
    if schedule_rows != expected:
        raise ValueError('schedule changed during immediate locked preflight: ' + row['strategy_code'])
    return config_text, [r[0] for r in schedule_rows]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true', help='perform explicitly authorized full pause; default dry-run')
    parser.add_argument('--output', type=Path, default=OUT)
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to(BASE.resolve()):
        parser.error('audit output must be under 20261018-b-research')
    manifest = json.loads((SOURCE / 'master-manifest.json').read_text())
    selected = {r['strategy_code'] for r in manifest['strategies']}
    connection = connect(ROOT / '.env')
    try:
        deployments, _, summary = live_snapshot(connection, manifest, SOURCE)
    finally:
        connection.close()
    active = assert_preconditions(deployments.to_dict('records'), selected)
    print('preflight', json.dumps({k: summary[k] for k in ('checked_at_utc', 'enabled_live_manual',
        'notification_enabled_live_manual', 'live_notification_config_override_true',
        'enabled_live_schedules', 'live_manual_execution_enabled') if k in summary}))
    if not args.apply:
        print('READ-ONLY DRY RUN: rerun with --apply only for operator-approved full pause')
        return 0
    output.mkdir(parents=True, exist_ok=True)
    run_dir = output / ('full-pause-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
    run_dir.mkdir(exist_ok=False)
    connection = connect(ROOT / '.env')
    cursor = connection.cursor()
    try:
        cursor.execute('SET XACT_ABORT ON')
        prior = []
        # The SELECT locks make identity and flags an immediate precondition,
        # not merely a previously observed dry-run snapshot.
        for row in active:
            text, ids = locked_current(cursor, row)
            prior.append({'strategy_code': row['strategy_code'], 'deployment_id': row['deployment_id'],
                'deployment_key': row['deployment_key'], 'version_code': row['version_code'],
                'old_notification_enabled': True, 'old_json_notification_enabled': True,
                'old_configuration_sha256': hashlib.sha256(text.encode('utf-8')).hexdigest(),
                'schedule_ids': ids, 'old_schedule_is_enabled': [True, True]})
        backup = {'captured_at_utc': datetime.now(timezone.utc).isoformat(),
            'action': 'FULL_PAUSE_40_LEGACY_LIVE_MANUAL', 'committed': False,
            'deployments': prior, 'version_unchanged': True, 'broker_action': 'NONE'}
        (run_dir / 'prestate.json').write_text(json.dumps(backup, indent=2) + '\n', encoding='utf-8')
        for row in active:
            cursor.execute('''UPDATE StockDB_US.TradingSignal.StrategyDeployment
                SET NotificationEnabled=0,
                    ConfigurationJson=JSON_MODIFY(ConfigurationJson,'$.notification_enabled',CAST(0 AS bit))
                WHERE StrategyDeploymentID=? AND IsEnabled=1 AND ExecutionEnabled=0 AND NotificationEnabled=1
                    AND EnvironmentType='LIVE_MANUAL' AND JSON_VALUE(ConfigurationJson,'$.notification_enabled')='true' ''', row['deployment_id'])
            if cursor.rowcount != 1:
                raise ValueError('deployment update mismatch ' + row['strategy_code'])
            for schedule in row['schedules']:
                cursor.execute('''UPDATE StockDB_US.TradingSignal.StrategySchedule SET IsEnabled=0
                    WHERE StrategyScheduleID=? AND StrategyDeploymentID=? AND IsEnabled=1''',
                    schedule['schedule_id'], row['deployment_id'])
                if cursor.rowcount != 1:
                    raise ValueError('schedule update mismatch ' + row['strategy_code'])
        # Transactional assertion BEFORE commit: no partial pause is permissible.
        for row in active:
            cursor.execute('''SELECT NotificationEnabled,JSON_VALUE(ConfigurationJson,'$.notification_enabled'),
                IsEnabled,ExecutionEnabled FROM StockDB_US.TradingSignal.StrategyDeployment
                WHERE StrategyDeploymentID=?''', row['deployment_id'])
            r = cursor.fetchone()
            if tuple(r) != (False, 'false', True, False):
                raise ValueError('post-update notification check failed ' + row['strategy_code'])
            cursor.execute('''SELECT COUNT_BIG(*) FROM StockDB_US.TradingSignal.StrategySchedule
                WHERE StrategyDeploymentID=? AND IsEnabled=1''', row['deployment_id'])
            if cursor.fetchone()[0] != 0:
                raise ValueError('post-update schedule check failed ' + row['strategy_code'])
        connection.commit()
    except Exception:
        connection.rollback()
        (run_dir / 'ROLLED_BACK.txt').write_text('SQL transaction rolled back; no partial pause committed. Recheck live state.\n')
        raise
    finally:
        cursor.close()
        connection.close()
    connection = connect(ROOT / '.env')
    try:
        after, _, final = live_snapshot(connection, manifest, SOURCE)
    finally:
        connection.close()
    after_active = after[(after.environment == 'LIVE_MANUAL') & (after.enabled)]
    verified = (len(after_active) == 40 and set(after_active.strategy_code) == selected and
        all(not r['notification_enabled'] and r['configuration_notification_enabled_override'] is False and
            r['enabled_schedule_count'] == 0 and not r['execution_enabled'] and
            r['version_code'] == '1.0.0-production' for r in after_active.to_dict('records')))
    record = {'committed_at_utc': datetime.now(timezone.utc).isoformat(), 'post_read_utc': final['checked_at_utc'],
        'deployment_updates': 40, 'schedule_updates': 80, 'independent_readback_pass': verified,
        'post_summary': final, 'rollback_metadata': 'prestate.json',
        'notice': 'Reactivation requires separate explicit operator approval; no broker or descriptor changes.'}
    (run_dir / 'result.json').write_text(json.dumps(record, indent=2) + '\n')
    print('result', json.dumps(record))
    if not verified:
        raise RuntimeError('Committed pause did not pass independent readback; operator action required: ' + str(run_dir))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
