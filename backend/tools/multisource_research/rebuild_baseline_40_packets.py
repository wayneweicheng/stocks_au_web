"""Rebuild frozen 40 GEX comparators from audited labels; no SQL/provisioning.

NEVER calls generate_all_universe_contracts.main(): that function deletes its
production archive. Outputs are new, review-only packets under 20261018-b.
"""
from __future__ import annotations
import hashlib
import json
import math
import re
import sys
import tempfile
import zipfile
from datetime import date, datetime, timezone
from pathlib import Path
import pandas as pd

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
sys.path.insert(0,'C:/Repo/stocks_collecting/src')
import generate_all_universe_contracts as generator
from strategy_runtime.contracts.validate_contract import validate_contract
from strategy_runtime.strategies.spx_gex.calendar import USCashCalendar
from fixed_hypothesis_screen import BASE,LABELS,metrics

SOURCE=ROOT/'data/strategy_runtime/20261018-a/selected_gex_live_production_contracts_2026-10-18-a'
DEST=BASE/'baseline_40_corrected_review_packets_2026-10-18-b'
RUNTIME_DEST=BASE/'baseline_40_runtime_aligned_review_packets_2026-10-18-b'
RUNTIME_LABELS=BASE/'baseline_40_runtime_eligible.csv'
VERSION='1.0.1-research'
CUTOFF=pd.Timestamp('2026-08-31')
ATOM=re.compile(r'^([A-Za-z_][A-Za-z_0-9]*)\s*(<=|>=|==|<|>)\s*(-?\d+(?:\.\d+)?)$')


def independent_trigger(expression: str, values: dict) -> bool:
    """Separate simple predicate evaluator: reject unknown grammar, never eval()."""
    if re.search(r'\bOR\b|\bNOT\b|\babs\b',expression,re.I):
        raise ValueError(f'not supported for independent audit: {expression}')
    for part in re.split(r'\s+AND\s+',expression,flags=re.I):
        match=ATOM.fullmatch(part.strip())
        if not match:raise ValueError(f'unknown frozen predicate syntax: {part}')
        field,op,value=match.groups();actual=values.get(field)
        if actual is None or pd.isna(actual):return False
        a=float(actual);b=float(value)
        if not math.isfinite(a):return False
        ok={'<':lambda:a<b,'<=':lambda:a<=b,'>':lambda:a>b,'>=':lambda:a>=b,'==':lambda:a==b}[op]()
        if not ok:return False
    return True


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path:Path,value:dict):
    path.write_text(json.dumps(value,indent=2,allow_nan=False,default=str)+'\n',encoding='utf-8')


def update_hashes(folder):
    names=['acceptance-status.json','fixtures.json','historical-instance-ledger.csv','historical-performance.json','source-manifest.json','strategy.descriptor.json','strategy.md','strategy_logic.py']
    (folder/'file-hashes.sha256').write_text(''.join(f'{digest(folder/name)}  {name}\n' for name in names),encoding='utf-8')


def run(destination:Path=DEST,data_path:Path=LABELS,*,runtime_aligned:bool=False):
    if destination.exists():raise FileExistsError(f'refusing to overwrite packet archive: {destination}')
    if destination.resolve().is_relative_to(BASE.resolve()):
        raise ValueError('unpacked review descriptors under strategy_runtime are discovered by the live registry; use package_review_zip()')
    old=json.loads((SOURCE/'master-manifest.json').read_text(encoding='utf-8'))
    selected=old['strategies']
    if len(selected)!=40 or len({s['ticker'] for s in selected})!=40 or any(float(s['frequency_pct'])>25 for s in selected):
        raise ValueError('source archive is not the frozen 40-ticker comparator')
    if runtime_aligned and (data_path!=RUNTIME_LABELS or destination.name!=RUNTIME_DEST.name):
        raise ValueError('runtime rebuild requires the pinned runtime-eligible panel and separate archive')
    data=pd.read_csv(data_path);data['market_date']=pd.to_datetime(data.market_date)
    audit=pd.read_csv(BASE/'august-label-audit.csv');audit['market_date']=pd.to_datetime(audit.market_date)
    audit=audit.set_index(['ticker','market_date'],verify_integrity=True)
    if data.duplicated(['ticker','market_date']).any():raise ValueError('duplicate corrected labels')
    if data.market_date.max()>CUTOFF:raise ValueError('post-cutoff D0 row')
    for s in selected:
        d=json.loads((SOURCE/s['directory']/'strategy.descriptor.json').read_text())
        actual=d['signal_definitions'][0]
        if (d['strategy_code'],actual['trigger_condition'],actual['direction'],actual['holding_period'])!=(s['strategy_code'],s['trigger'],s['direction'],s['horizon']):
            raise ValueError(f'archive manifest/descriptor disagreement: {s["ticker"]}')
        if d['instrument_roles']!=[{'role':'SUBJECT','instrument':s['ticker']+'.US'}]:raise ValueError('bad instrument binding')
        # Fail closed on unidentified predicate syntax BEFORE writing anything.
        independent_trigger(s['trigger'],{name:0.0 for name in actual['variables']})
    original_hashes={'manifest':digest(SOURCE/'master-manifest.json'),'corrected_labels':digest(LABELS),'label_audit':digest(BASE/'august-label-audit.csv'),'packet_input':digest(data_path)}
    source_hash=hashlib.sha256('|'.join(original_hashes.values()).encode()).hexdigest()
    as_of=datetime.now(timezone.utc).isoformat()
    generator.CONTRACT_ROOT=destination
    generator.VERSION='1.0.2-research' if runtime_aligned else VERSION
    generator.AS_OF=as_of
    destination.mkdir(parents=True)
    calendar=USCashCalendar();stats=[];bad=[];source_audit=[]
    for s in selected:
        ticker=s['ticker']+'.US';horizon=s['horizon'];direction=s['direction'];trigger=s['trigger']
        needed=generator.identifiers(trigger)
        subject=data[(data.ticker==ticker)&data[f'ret_{horizon}'].notna()].copy()
        ready=subject[subject[needed].notna().all(axis=1)].copy()
        expected=ready.apply(lambda r:independent_trigger(trigger,r.to_dict()),axis=1)
        expected_dates=set(ready.loc[expected,'market_date'].dt.strftime('%Y-%m-%d'))
        row=pd.Series({**s,'ticker':ticker})
        result=generator.build_packet(row,ready,source_hash)
        folder=destination/s['directory']
        ledger=pd.read_csv(folder/'historical-instance-ledger.csv')
        if len(ledger)!=len(expected_dates) or set(ledger.market_date)!=expected_dates:
            raise ValueError(f'generated ledger does not reproduce independent predicate: {ticker}')
        for item in ledger.to_dict('records'):
            d0=pd.Timestamp(item['market_date']);raw=ready.loc[ready.market_date==d0]
            if len(raw)!=1:raise ValueError(f'bad ledger join: {ticker} {d0}')
            raw=raw.iloc[0];check=audit.loc[(ticker,d0)]
            if check['status']!='OK' or not bool(check['entry_price_match']) or not bool(check[f'{horizon}_match']):
                raise ValueError(f'bar audit mismatch: {ticker} {d0}')
            signed=float(raw[f'ret_{horizon}'])*(1 if direction=='LONG' else -1)
            exit_date=pd.Timestamp(raw[f'exit_{horizon}']).date()
            if exit_date>CUTOFF.date() or str(pd.Timestamp(item['entry_timestamp']).date())!=str(raw.entry_date)[:10]:raise ValueError(f'date mismatch {ticker} {d0}')
            if abs(float(item['entry_price'])-float(raw.entry_price))>1e-4 or abs(float(item['return_pct'])-signed)>1e-5:
                raise ValueError(f'return mismatch {ticker} {d0}')
            item['exit_timestamp']=calendar.cash_close(exit_date).isoformat()
            source_audit.append({'ticker':ticker,'market_date':str(d0.date()),'entry_date':str(raw.entry_date)[:10],'exit_date':str(exit_date),'horizon':horizon,'direction':direction,'entry_price':float(item['entry_price']),'gross_directional_return_pct':signed,'net_25bp_pct':signed-.25,'source_raw_bar_audit':'PASS'})
        # Update the ledger AFTER checking it against independently calculated predicates and audited raw prices.
        if len(ledger):
            new=pd.DataFrame([{**record,'exit_timestamp':calendar.cash_close(pd.Timestamp(record['exit_timestamp']).date()).isoformat()} for record in ledger.to_dict('records')])
            new.to_csv(folder/'historical-instance-ledger.csv',index=False)
        perf=json.loads((folder/'historical-performance.json').read_text())
        gross=pd.Series([item['gross_directional_return_pct'] for item in source_audit if item['ticker']==ticker]);net=metrics(gross,.25)
        perf.update({'as_of':as_of,'version_code':generator.VERSION,'status':'EXPLORATORY_NOT_VALIDATED','candidate_origin':'Frozen 20261018-a selected rules; no reselection on corrected labels','gross_results':perf['performance'],'net_25bp_results':net,'transaction_costs_bps_round_trip':25,'slippage_bps_round_trip':None,'reserved_forward_window':'2026-09-01 through 2026-10-15 was inspected earlier; NOT pristine confirmation.','caveat':'Returns are corrected but selected on earlier flawed research; overlapping gross instances and optimistic 07:30 bar open, no portfolio NAV.','missing_required_input_rows':len(subject)-len(ready),'selection_frequency_pct_old_source':s['frequency_pct'],'corrected_trigger_frequency_pct':len(ledger)/len(ready)*100 if len(ready) else None})
        # Existing performance block describes zero-cost gross, not net; make this explicit.
        perf['return_units']='directional gross stock return in percentage points; separate 25-bp net sensitivity'
        save(folder/'historical-performance.json',perf)
        descriptor=json.loads((folder/'strategy.descriptor.json').read_text());descriptor['status']='RESEARCH_DRAFT'
        descriptor['environments']=['BACKTEST'];descriptor['run_kinds']=['DATA_CHECK','EVALUATE'];descriptor['schedule_requirements']=['Research-only theoretical next-session 07:30 America/New_York evaluation; no schedules approved']
        descriptor['research_governance'].update({'validation_method':'Frozen prior-selected rules recalculated on audited corrected labels; NOT independent selection or forward validation.','reserved_oos_window':'Previously inspected Sep/Oct 2026; NOT pristine confirmation.','classification':'CORRECTED_RESEARCH_COMPARATOR_NOT_APPROVED','change_summary':'Corrected subject price labels and session mapping; same 40 frozen triggers, no provision/activation.'})
        descriptor['production_policy'].update({'deployment_state':'RESEARCH_ONLY','deployment_target':'NONE','enabled':False,'notification_default':False,'broker_execution':'HARD_DISABLED','broker_orders_authorized':False})
        descriptor['production_policy']['notifications']['enabled']=False
        for signal in descriptor['signal_definitions']:
            signal['sends_notification']=False;signal['production_notification_allowed']=False
            if signal['action']=='PLAN_ENTRY':
                signal['historical_performance'].update({'status':'INSUFFICIENT','as_of_utc':as_of,'notes':'Corrected historical gross labels, selected on previously flawed research; not forward validated; no production approval.'})
        descriptor['provenance']['reserved_oos_window']['status']='PREVIOUSLY_INSPECTED_NOT_PRISTINE'
        descriptor['provenance']['source_hash']=source_hash
        source=json.loads((folder/'source-manifest.json').read_text());source.update({'version_code':generator.VERSION,'combined_source_hash':source_hash,'as_of':as_of,'read_only_source_hashes':original_hashes,'prior_archive':str(SOURCE),'source_version':'corrected August labels, independent raw-bar reconciliation'+(' and runtime feature/predicate recalculation' if runtime_aligned else '')})
        source['option_quote_timing_policy']['open_interest_availability']='D0 quote observations assumed available next XNYS session approximately 07:00 ET; actual first-ready timestamp unverified. Option quotes are NOT used in these frozen GEX rules.'
        source['research_source_note']='Corrected pre-cutoff StockDB_US research; old September/October results were inspected and cannot serve as pristine confirmation.'
        save(folder/'source-manifest.json',source)
        descriptor['provenance']['implementation_hash']=''
        logic=generator.make_logic(s['strategy_code'],s['signal_code'],trigger,direction,horizon,needed).replace('DEPLOYMENT_TARGET = "PRODUCTION"','DEPLOYMENT_TARGET = "RESEARCH_ONLY"').replace('NOTIFICATIONS_ENABLED = True','NOTIFICATIONS_ENABLED = False')
        (folder/'strategy_logic.py').write_text(logic,encoding='utf-8')
        descriptor['provenance']['implementation_hash']=digest(folder/'strategy_logic.py')
        source['implementation_sha256']=descriptor['provenance']['implementation_hash'];save(folder/'source-manifest.json',source)
        markdown=(folder/'strategy.md').read_text(encoding='utf-8')
        markdown=markdown.replace('September and October 2026 are untouched and reserved for forward validation.','September and October 2026 were previously inspected; they are not pristine forward validation.').replace('Forward validation must preserve September and October 2026 as out-of-sample data.','September and October 2026 were already inspected; new prospective confirmation must be identified.').replace('Notification-only. Broker execution is hard-disabled.','Review-only; notifications and deployment disabled. Broker execution is hard-disabled.').replace('The descriptor is notification-only and must be independently reviewed before provisioning.','RESEARCH_DRAFT only: no provisioning, schedules or notifications authorized.').replace('The candidate is research-derived and not a claim of proof.','The frozen candidate was selected using earlier flawed research; these corrected labels are exploratory, not independent proof. No deployment approval.')
        markdown=markdown.replace('This packet contains the top-scoring candidate','This packet retains the previously selected top-scoring candidate')
        (folder/'strategy.md').write_text(markdown,encoding='utf-8')
        descriptor['markdown_sha256']=generator.normalized_text_sha256(folder/'strategy.md');save(folder/'strategy.descriptor.json',descriptor)
        acceptance=json.loads((folder/'acceptance-status.json').read_text());acceptance.update({'status':'RESEARCH_DRAFT','classification':'CORRECTED_RESEARCH_COMPARATOR_NOT_APPROVED','broker_execution':'HARD_DISABLED','notification_only':False,'provisioning_approved':False});save(folder/'acceptance-status.json',acceptance)
        fixture=json.loads((folder/'fixtures.json').read_text());fixture['fixtures']=[x for x in fixture['fixtures'] if x.get('id') not in {'reserved-oos','production-policy'}]+[{'id':'approval-gate','expected':'No provisioning, notifications or execution; fresh forward confirmation required'}];save(folder/'fixtures.json',fixture)
        update_hashes(folder)
        issues=validate_contract(folder/'strategy.md')
        if issues:bad.append({'ticker':ticker,'issues':[i.as_dict() for i in issues]})
        stats.append({**result,'ticker':ticker,'old_frequency_pct':s['frequency_pct'],'corrected_ready_n':len(ready),'missing_input_n':len(subject)-len(ready),'corrected_frequency_pct':len(ledger)/len(ready)*100 if len(ready) else None,'gross_pf_corrected':perf['performance']['pf'],'net_25bp_pf':net['pf_net'],'net_25bp_mean_pct':net['mean_net_pct'],'validator_issue_n':len(issues)})
    pd.DataFrame(stats).to_csv(destination/'strategy-summary.csv',index=False)
    pd.DataFrame(source_audit).to_csv(destination/'reconciled-trades.csv',index=False)
    save(destination/'validation-issues.json',{'packets_with_issues':bad,'issue_count':sum(len(x['issues']) for x in bad)})
    aggregate=metrics(pd.Series([r['gross_directional_return_pct'] for r in source_audit]),.25)
    save(destination/'master-manifest.json',{'package':'Frozen 40 GEX baseline — '+('runtime-aligned' if runtime_aligned else 'corrected research-only')+' rebuild','as_of':as_of,'version_code':generator.VERSION,'research_cutoff':'2026-08-31','original_master_sha256':original_hashes['manifest'],'source_hashes':original_hashes,'selected_rule_count':len(selected),'generated_packet_count':len(stats),'audited_trade_count':len(source_audit),'gross_return_note':'Per-signal subject-stock raw-bar returns, not portfolio NAV','net_25bp_signal_level':aggregate,'descriptor_validation_issue_count':sum(len(x['issues']) for x in bad),'status':'RESEARCH_DRAFT_NOT_PROVISIONED','production_actions':False,'strategies':stats})
    (destination/'README.md').write_text('# Frozen 40 corrected baseline — REVIEW ONLY\n\nPreserves the existing 20261018-a 40 ticker/horizon/direction/trigger selections. Recomputes **August only** using independently audited subject-symbol 30M labels. '+('Inputs/predicates were recalculated through the runtime feature code using 61-date windows. Source: baseline_40_runtime_eligible.csv. ' if runtime_aligned else 'RESEARCH FEATURE VALUES NOT PROVEN RUNTIME-EQUIVALENT; THIS ARCHIVE IS BLOCKED. ')+'Old selection and September/October research were inspected; no OOS claim. Gross packet performance and separate 25-bp net sensitivity are **overlapping per-signal statistics, not portfolio results**. Original archive untouched. Descriptors are RESEARCH_DRAFT with deployment and notification disabled; broker execution HARD_DISABLED. Source missing required inputs fail closed. See `validation-issues.json`, `master-manifest.json`, `reconciled-trades.csv` and `strategy-summary.csv`. Never provision from this review archive.\n',encoding='utf-8')
    if bad:raise RuntimeError(f'{len(bad)} descriptors have validator issues: see {destination / "validation-issues.json"}')
    print(json.dumps({'path':str(destination),'packets':len(stats),'audited_trades':len(source_audit),'net_25bp_signal_level':aggregate,'validation_issues':len(bad)},indent=2))

def package_review_zip(*,runtime_aligned:bool=True):
    """Generate under the OS temp directory; ZIP inside research root is not scanned."""
    name=(RUNTIME_DEST if runtime_aligned else DEST).name
    target=BASE/(name+'.zip')
    if target.exists():raise FileExistsError(f'refusing to overwrite {target}')
    with tempfile.TemporaryDirectory(prefix='gex-review-packets-') as tmp:
        output=Path(tmp)/name
        run(output,RUNTIME_LABELS if runtime_aligned else LABELS,runtime_aligned=runtime_aligned)
        with zipfile.ZipFile(target,'x',compression=zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(output.rglob('*')):
                if path.is_file():archive.write(path,arcname=str(Path(name)/path.relative_to(output)).replace('\\','/'))
        with zipfile.ZipFile(target) as archive:
            assert archive.testzip() is None
            assert len([n for n in archive.namelist() if n.endswith('/strategy.descriptor.json')])==40
    print('review-only archive',target,'sha256',digest(target))


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--runtime-aligned',action='store_true')
    args=parser.parse_args()
    package_review_zip(runtime_aligned=args.runtime_aligned)
