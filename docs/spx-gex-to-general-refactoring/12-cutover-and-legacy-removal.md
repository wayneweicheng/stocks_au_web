# Task 12: Cut Over SPX and Remove Runtime Work from FastAPI

## Objective

Make `strategy_runtime` the sole SPX operational writer/scheduler, keep report browsing compatible, and remove heavy SPX execution work from FastAPI in controlled stages with a duplicate-action-safe rollback.

## Prerequisites and approval

- Tasks 08, 09, and 11 are complete.
- Task 11 concludes `READY FOR CUTOVER` with no blocking differences.
- A production backup, rollback owner, maintenance window, and cutover watermark are approved.
- Enabling/disabling Windows tasks, changing production configuration, or deploying database changes requires explicit user authorization at execution time.

## Cutover invariant

For every canonical SPX scheduled work identity, exactly one implementation may own operational side effects. The old and new paths must never both be delivery/execution enabled for overlapping effective times.

Record an immutable `CutoverWatermarkUTC` aligned to a canonical scheduled boundary:

- the legacy path owns work strictly before the watermark;
- the new production deployment owns work at or after the watermark;
- neither path may reinterpret an already-completed pre-watermark run as new work.

## Stage A: Pre-cutover preparation

1. Freeze both repository commits, package lockfiles, runtime configuration hash, SQL schema version, scheduler definitions, and Task 11 evidence.
2. Back up the production SQLite database and verify restore/readability.
3. Verify SQL Server backups and the web read principal.
4. Import/final-verify retained SQLite rows using Task 10; never queue imported notifications.
5. Seed the production SPX Strategy Definitions, Versions, Deployment, Execution Book, Instrument roles, and schedules while keeping the Deployment disabled.
6. Configure report base URL/token and perform an operator-only link check.
7. Install but keep disabled the generic Windows heartbeat task.
8. Identify and document all SPX FastAPI scheduler registrations in `backend\app\core\scheduler.py` and all enabling settings in `backend\app\core\config.py`.
9. Query open plans, pending/unknown notifications, leased runs, and the legacy portfolio immediately before cutover. Resolve or explicitly carry each item.

Do not cut over while a legacy notification is `SENDING`, delivery is ambiguous, or lifecycle ownership of an open plan is unclear.

## Stage B: Atomic operational switch

Perform within the approved window:

1. Stop/disable legacy SPX scheduler registrations without stopping unrelated FastAPI jobs.
2. Wait for any in-flight legacy SPX call to finish and record its last completed effective time.
3. Confirm the last legacy completion is before the cutover watermark and no legacy notification is in an ambiguous send state.
4. Enable the new SPX production Deployment with the cutover watermark enforced.
5. Enable/start the generic Windows heartbeat task.
6. Run `health`, then one bounded `run-due`; no manual synthetic due time in production.
7. Confirm run claim/completion, report snapshot, queue row, generic handler delivery, and tokenized immutable web link as applicable.
8. Confirm FastAPI report browsing works and FastAPI has not constructed an SPX service or IB connection.

If any ordering step fails before the first new actionable side effect, disable the new Deployment/task and restore the legacy scheduler using the recorded watermark. Do not improvise overlap.

## Open-plan handoff

Prefer cutting over with no open SPX plan. If an open legacy paper/manual plan must be carried:

- import and reconcile the plan/events/book immediately before the watermark;
- assign lifecycle ownership to the new Deployment exactly once;
- suppress a duplicate `ENTER` notification;
- test the next legal monitoring/exit transition in a controlled environment;
- record an `AuditEvent` naming old/new identities and operator approval.

If identity, price, or notification status is ambiguous, postpone cutover.

## Rollback after new side effects

Once the new runtime has emitted an actionable notification or changed a plan, rollback is not a simple scheduler toggle.

1. Disable the new Deployment and heartbeat.
2. Freeze SPX operational actions while retaining report reads.
3. Reconcile the latest Strategy Run, Trade Plan Events, Execution Book, MessageQueue, and Pushover delivery state.
4. Choose and record one authoritative state/watermark.
5. Only then re-enable the legacy scheduler with explicit suppression for identities already handled by the new path, or deploy a forward fix.

Never delete SQL rows, reset a sent notification to pending, or re-enable both paths to “see which works.”

## Stage C: FastAPI simplification

After the switch is stable for at least five completed US trading sessions:

- remove SPX job registrations from `backend\app\core\scheduler.py`;
- remove backend startup construction of the SPX service/runtime;
- change old report APIs to Task 08 catalog aliases only;
- remove/deprecate live-quote and manual-run endpoints rather than retaining hidden execution behavior;
- remove runtime-only SPX settings from `backend\app\core\config.py`, retaining only generic report-catalog settings;
- ensure `backend\app\main.py` includes only the generic report router and any thin compatibility router;
- update operations/startup documentation.

FastAPI must no longer import IB, schedule SPX work, write strategy state, render new reports, or publish Pushover for SPX.

## Stage D: Legacy code retirement

After at least one further approved retention period (minimum suggested: 20 completed US trading sessions) with successful backup/restore evidence:

- remove or archive `backend\app\spx_gex_strategy` runtime modules that have migrated;
- retain no duplicate implementation in the web application;
- preserve characterization fixtures needed to prove historical behavior, moving them to an appropriate archive/test-data location if necessary;
- retain the read-only SQLite backup according to the operational retention policy;
- remove obsolete dependencies only after proving no other backend feature imports them.

Do not delete the SQLite backup or historical HTML as part of source cleanup.

## Validation

Validate at cutover and on each of the next five sessions:

- exactly one SPX production run per canonical due identity;
- no legacy scheduler execution after watermark;
- no duplicate Signal, Plan Event, Report Snapshot, Notification Event, or MessageQueue idempotency key;
- expected reports appear in the generic catalog and legacy URLs resolve;
- tokenized notification links open immutable HTML;
- notification delivery outcomes are terminal or operator-owned, with no automatic retry of unknown delivery;
- no expired leases, overdue runs, or unexpected queue backlog;
- FastAPI response/startup health and no IB/runtime initialization;
- unrelated website scheduler jobs remain operational.

## Tests

Add regression/import-boundary tests proving:

- FastAPI startup does not import or instantiate SPX execution modules;
- no SPX jobs are registered;
- compatibility routes use only ReportCatalog;
- cutover watermark prevents old/new overlap in runtime tests;
- retrying the first post-cutover run cannot duplicate notification or plan events;
- simulated rollback procedure identifies side effects requiring reconciliation.

## Acceptance criteria

- `strategy_runtime` is the only SPX writer and scheduler at/after the watermark.
- FastAPI is a generic read-only report consumer.
- Generic and legacy report URLs work.
- Five-session stability checks pass before web runtime code removal.
- Rollback documentation distinguishes pre-side-effect and post-side-effect recovery.
- Legacy data remains recoverable.

## Out of scope

- SPX rule changes.
- META activation.
- Live broker ordering.
- Deleting production backups.
- Removing unrelated FastAPI scheduled jobs.

## Verification

```powershell
Set-Location C:\Repo\stocks_collecting
poetry run python -m strategy_runtime health --json
poetry run pytest tests\strategy_runtime -q
git diff --check

Set-Location C:\Repo\stocks_au_web\backend
..\venv\Scripts\python.exe -m unittest tests.test_trading_signal_reports
# Before Stage D only, also run: ..\venv\Scripts\python.exe -m unittest tests.test_spx_gex_strategy

Set-Location C:\Repo\stocks_au_web\frontend
npm run lint
npm run build

Set-Location C:\Repo\stocks_au_web
rg -n "spx_gex_strategy|ib_insync" backend\app\main.py backend\app\core\scheduler.py backend\app\routers
git diff --check
```

Every remaining `rg` match must be a documented read-only compatibility reference.

After Stage D, SPX golden parity is verified from `stocks_collecting\tests\strategy_runtime\spx_gex`; do not retain a web runtime package solely to keep the old test module importable.

## Required handoff evidence

- Approved watermark and minute-by-minute cutover log.
- Before/after scheduler/task definitions.
- First-run/report/queue/delivery/link evidence with secrets removed.
- SQL duplicate/invariant checks.
- Five-session stability checklist.
- Removed/retained legacy file list and backup location/retention record.
- Tested pre-side-effect and post-side-effect rollback procedures.
