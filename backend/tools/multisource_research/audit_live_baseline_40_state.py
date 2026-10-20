"""Read-only SQL snapshot of live frozen-40 deployment state and descriptor identity.

No change to versions, deployments, schedules, reports, or notifications.
"""
from __future__ import annotations
import json
from datetime import datetime,timezone
from pathlib import Path
import pandas as pd
from audit_august_labels import connect,ROOT
from rebuild_baseline_40_packets import SOURCE,BASE,save,digest


def run():
    selected=json.loads((SOURCE/'master-manifest.json').read_text())['strategies'];lookup={x['strategy_code']:x for x in selected}
    c=connect(ROOT/'.env');rows=[]
    try:
        cur=c.cursor();cur.execute("""SELECT f.StrategyCode,v.VersionCode,v.ImplementationKey,v.ConfigurationJson,d.StrategyDeploymentID,d.DeploymentKey,d.EnvironmentType,d.IsEnabled,d.ExecutionEnabled,d.NotificationEnabled FROM StockDB_US.TradingSignal.StrategyDeployment d JOIN StockDB_US.TradingSignal.StrategyVersion v ON v.StrategyVersionID=d.StrategyVersionID JOIN StockDB_US.TradingSignal.StrategyDefinition f ON f.StrategyDefinitionID=v.StrategyDefinitionID WHERE f.StrategyCode LIKE 'GEX[_]%[_]AUGUST[_]2026[_]BEST' ORDER BY f.StrategyCode,d.DeploymentKey""")
        for code,version,implementation,config,deployment_id,key,env,enabled,execution,notifications in cur.fetchall():
            if code not in lookup:continue
            original=json.loads((SOURCE/lookup[code]['directory']/'strategy.descriptor.json').read_text())
            actual=json.loads(config) if config else {}
            cur2=c.cursor();cur2.execute('SELECT RoleCode,InstrumentCode FROM StockDB_US.TradingSignal.StrategyInstrumentRole WHERE StrategyDeploymentID=? ORDER BY RoleCode',deployment_id);roles={r[0]:r[1] for r in cur2.fetchall()}
            cur2.execute('SELECT RunKind,IsEnabled FROM StockDB_US.TradingSignal.StrategySchedule WHERE StrategyDeploymentID=?',deployment_id);schedules=cur2.fetchall();cur2.close()
            rows.append({'strategy_code':code,'version_code':version,'deployment_key':key,'environment':env,'is_enabled':bool(enabled),'execution_enabled':bool(execution),'notification_enabled':bool(notifications),'schedule_count':len(schedules),'schedule_enabled_count':sum(bool(r[1]) for r in schedules),'schedule_kinds':','.join(sorted(set(str(r[0]) for r in schedules))),'subject_role':roles.get('SUBJECT'),'execution_role':roles.get('EXECUTION'),'sql_status':actual.get('status'),'sql_strategy_version_code':actual.get('version_code'),'sql_source_hash':(actual.get('provenance') or {}).get('source_hash'),'original_archive_source_hash':original['provenance']['source_hash'],'old_descriptor_source_hash_matches_sql':(actual.get('provenance') or {}).get('source_hash')==original['provenance']['source_hash'],'sql_broker_execution':(actual.get('production_policy') or {}).get('broker_execution'),'sql_policy_enabled':(actual.get('production_policy') or {}).get('enabled')})
    finally:c.close()
    output=pd.DataFrame(rows);output.to_csv(BASE/'baseline_40_live_state_read_only.csv',index=False)
    active=output[(output.environment=='LIVE_MANUAL')&output.is_enabled]
    save(BASE/'baseline_40_live_state_read_only.json',{'checked_at_utc':datetime.now(timezone.utc).isoformat(),'original_40_master_sha256':digest(SOURCE/'master-manifest.json'),'selected_tickers':len(selected),'deployments_for_selected_codes':len(output),'live_manual_deployments_enabled':len(active),'live_manual_notifications_enabled':int(active.notification_enabled.sum()),'live_manual_execution_enabled':int(active.execution_enabled.sum()),'live_manual_schedules_enabled':int(active.schedule_enabled_count.sum()),'live_manual_archived_source_hash_matches_sql':int(active.old_descriptor_source_hash_matches_sql.sum()),'live_manual_subjects_match_source':int((active.subject_role==active.strategy_code.str.removeprefix('GEX_').str.removesuffix('_AUGUST_2026_BEST')).sum()),'action':'READ_ONLY_NO_CHANGES','warning':'Enabled deployments and notification schedules exist despite previous research handoff saying not activated. Do not alter without explicit operator authorization.'})
    print((BASE/'baseline_40_live_state_read_only.json').read_text())

if __name__=='__main__':run()
