# Task 15: Complete End-to-End Validation and Operations

## Objective

Prove the full multi-strategy system under normal and failure conditions, publish executable operational runbooks, and define the evidence/approval needed for continued forward-paper operation. This task does not itself authorize production database changes, Windows task registration, or strategy activation.

## Prerequisites

- Tasks 12 and 14 are complete.
- SPX is stable on the new runtime and META code is present with its Deployment disabled unless separately approved.
- SQL Server backup/restore and service-account ownership are known.
- A non-production Pushover recipient/application path is available for delivery testing.

## Repositories and required artifacts

In `C:\Repo\stocks_collecting`, create or update:

```text
docs\strategy-runtime\operations-runbook.md
docs\strategy-runtime\deployment-checklist.md
docs\strategy-runtime\failure-recovery.md
docs\strategy-runtime\sql-health-queries.sql
docs\strategy-runtime\windows-task-installation.md
tests\strategy_runtime\end_to_end\...
```

In `C:\Repo\stocks_au_web`, update report-catalog deployment/operations documentation and add boundary/security tests where needed.

Runbooks must use placeholders for hostnames, accounts, passwords, tokens, recipient keys, and environment-specific paths. Never paste production secrets into evidence.

## Deployed topology inventory

Document one authoritative diagram/table containing:

- `C:\Repo\stocks_collecting\src\strategy_runtime` installed application/version and composition root;
- generic one-minute Windows heartbeat task and service account;
- SPX and META Strategy Deployments, Environments, schedules, Execution Books, and enabled states;
- SQL Server instance plus `StockDB_US.[TradingSignal]` and `StockDB.[Notification]` ownership/grants;
- generic notification handler process/task and Pushover target configuration;
- FastAPI generic read-only ReportCatalog and web principal;
- frontend canonical/legacy routes;
- log, backup, reconciliation-evidence, and retention locations.

Confirm `StockDB` and `StockDB_US` are on the same SQL Server instance. If not, stop: Task 05's atomic cross-database queue publication is invalid and an outbox relay task must be designed before completion.

## End-to-end scenarios

Run deterministic integration scenarios in an isolated environment for:

1. SPX evaluation with production/shadow comparison, immutable report, MessageQueue row, simulated/safe Pushover delivery, and browser-opened link.
2. SPX duplicate invocation/retry and correction/superseding report.
3. SPX plan entry and each characterized exit/lifecycle path.
4. META `NO_SIGNAL`/`NO_EDGE` persisted with no user delivery.
5. Every META watch classification with one report-linked watch delivery.
6. Every META strong classification from DETECTED through entry and its applicable TP/SL/reminder/time exit.
7. META data-gap/source warning preventing entry.
8. Opposing META Signal while active with no reversal.
9. D1/D2/D3/D5 Signal Outcomes independent of whether entry occurred.
10. Generic catalog filtering by date/search/Strategy/Instrument/Environment/kind and legacy SPX URL compatibility.

For each scenario record canonical run/event/idempotency keys and assert one committed row/event/report/queue delivery at every required boundary.

## Failure-injection matrix

Automate where practical and rehearse the rest in a disposable environment:

| Failure point | Required outcome |
|---|---|
| SQL unavailable before claim | no domain change; retryable CLI exit/health alert |
| process dies after claim | lease expires; new fence reclaims; stale worker cannot commit |
| source fails/stales | run retry or blocked Signal according to due window; no entry |
| transaction fails before commit | no partial Observation/Signal/Plan/report/queue row |
| process dies after commit before exit | next invocation returns already completed; no duplicate |
| cross-database queue insert fails | domain/report/run transaction rolls back |
| two heartbeat processes race | one claim/one set of side effects |
| IB unavailable before entry | bounded retry then one cancellation/data warning; no fabricated price |
| IB unavailable at scheduled exit | active plan becomes visibly overdue/operator-owned; one data alert |
| Task Scheduler misses wake-ups | catch-up only inside declared due windows; expired entries never execute late |
| notification pre-accept failure | safe bounded retry with same idempotency key |
| notification delivery ambiguous | `DELIVERY_UNKNOWN`; no automatic resend |
| notification handler dies with lease | safe reclaim only when provider non-acceptance is known |
| FastAPI unavailable | strategy/queue continues; immutable report remains stored; web health alerts |
| report ID unknown/token invalid | consistent non-leaking denial/404 behavior |
| HTML content/hash mismatch | health/integrity failure; content is not silently rewritten |
| source correction after completion | explicit corrected revision/superseding report; no ordinary-retry mutation |
| SQL restore to earlier point | documented reconciliation of scheduler watermark and provider side effects before re-enable |

Include Windows clock/timezone misconfiguration, US DST, Sydney DST, holiday, early close, and month-end cases. Runtime timing must derive from timezone-aware system UTC plus exchange calendar, not the host's display timezone.

## Health queries and alerts

Provide read-only SQL queries with comments and expected normal ranges for:

- last success/failure by Deployment and Run Kind;
- overdue due work and expired leases;
- repeated attempt/failure trends;
- active/overdue/colliding Trade Plans and Execution Book occupancy;
- report count/hash/alias integrity;
- pending/retry/processing/failed/delivery-unknown Notification Deliveries;
- MessageQueue rows not reconciled to Notification Events;
- orphan foreign keys/identity mappings and duplicate idempotency keys;
- Strategy Version/configuration hash drift;
- missing D1/D2/D3/D5 outcomes;
- source Observation staleness/gaps.

Define alert ownership and thresholds. At minimum page/escalate on an overdue actionable exit, blocked daily evaluation near entry time, unknown notification delivery, schema mismatch, or repeated SQL/source outage. Avoid paging for expected `NO_SIGNAL` or no due work.

## Operational procedures

The runbook must include exact, safe procedures for:

- checking runtime/web/queue health;
- inspecting a Strategy Run and attempts;
- retrying a known pre-commit/pre-provider failure;
- requesting and documenting a correction;
- resolving `DELIVERY_UNKNOWN` without automatic duplicate send;
- handling an overdue active plan with missing quote;
- disabling one Deployment without stopping other strategies;
- disabling the generic heartbeat safely;
- rotating/revoking report token and Pushover credentials;
- installing/updating/rolling back the Windows task and application package;
- backing up/restoring SQL Server and retaining the legacy SQLite backup;
- reconciling external Pushover effects after database restore;
- adding a new Strategy through the Task 13 contract.

Commands that mutate production must be clearly labelled, require an operator confirmation/approval step, and begin with read-only identification queries.

## Security review

Verify:

- runtime principal has only required write/execute grants;
- FastAPI report principal is read-only and cannot access MessageQueue/runtime write procedures;
- notification handler can claim/update only its queue surface;
- secrets are supplied outside Git and never appear in task XML, batch arguments, logs, health JSON, report HTML, API responses, screenshots, or test fixtures;
- report token comparison and log redaction work;
- HTML has escaping, CSP, nosniff, and iframe sandbox defense;
- opaque report IDs are not sequential database IDs;
- live IB order methods are absent from the runtime's strategy/lifecycle call graph.

Add an automated secret-pattern scan over changed artifacts using the repository's existing tooling if available; do not print matched secret contents to logs.

## Performance and retention

Measure with representative volumes:

- `run-due` no-work and one/multiple-due invocation latency;
- META bounded source-query plan/reads;
- claim contention under duplicate workers;
- evaluation/lifecycle transaction duration;
- catalog first page/filter/cursor and HTML fetch latency;
- queue claim/send throughput;
- database growth from Reports, Attempts, Audit Events, and Outcomes.

Set initial budgets from measured baseline and hardware rather than fictional universal numbers. The heartbeat must normally finish before the next minute without depending on that for correctness.

Define retention:

- Reports, Signals, Plans, events, and research outcomes are audit/research records and not automatically purged;
- verbose attempts/logs may use a reviewed retention period;
- queue/provider metadata follows notification policy;
- backups and legacy SQLite follow the approved recovery retention;
- any future archival preserves immutable IDs/hashes and report link behavior.

## Deployment checklist

Include explicit gates in this order:

1. Repository status/commits and test evidence frozen.
2. SQL backup and schema dry-run/verification.
3. Schema/procedure deployment.
4. Runtime package/dependencies/configuration deployment with Deployments disabled.
5. Notification handler schema/code deployment and dry run.
6. FastAPI ReportCatalog and frontend deployment.
7. Read-only health/security/link checks.
8. Strategy metadata/schedules/Execution Books seeded.
9. Approved Deployment enablement and scheduler watermark.
10. Windows task enablement.
11. First-run observation and Pushover/report-link verification.
12. Stabilization-period checks and formal closeout.

Each gate states owner, evidence, rollback point, and stop condition. Do not conflate code deployment with strategy activation.

## Automated test requirements

- Run all runtime unit/contract/integration/end-to-end tests.
- Run legacy SPX characterization tests retained in the web repository.
- Run FastAPI report API/security/import-boundary tests.
- Run frontend lint/build and available UI tests.
- Run SQL constraint/concurrency/migration tests against a disposable database.
- Run generic notification handler claim/idempotency/outcome tests.
- Run a test proving one additional synthetic strategy can register and report without core/web changes.

Tests requiring IB, SQL Server, Pushover, or browser deployment must have clear environment markers and skip reasons. A skipped mandatory activation check blocks activation; it is not silently treated as pass.

## Acceptance criteria

- Every end-to-end and failure scenario has passing evidence or a named blocking owner.
- Runtime, report serving, and Pushover delivery remain independently diagnosable.
- SQL Server transactions/idempotency survive crashes and duplicate workers.
- No path can produce a live broker order.
- Operations can disable one Strategy without disabling others.
- Backup/restore rehearsal includes reconciliation of external notifications and scheduler watermarks.
- Runbooks contain exact safe commands, ownership, thresholds, and rollback points.
- The final system supports SPX and META through the same deep runtime/catalog Interfaces.

## Out of scope

- Activating a strategy or production Windows task without explicit approval.
- Promoting forward-paper research to capital trading.
- Creating a 24/7 daemon.
- Automatically tuning rules.
- Purging audit/history data.

## Verification

```powershell
Set-Location C:\Repo\stocks_collecting
poetry run pytest tests\strategy_runtime -q
poetry run python -m strategy_runtime health --json
git diff --check

Set-Location C:\Repo\stocks_au_web\backend
..\venv\Scripts\python.exe -m unittest tests.test_trading_signal_reports

Set-Location C:\Repo\stocks_au_web\frontend
npm run lint
npm run build

Set-Location C:\Repo\stocks_au_web
git diff --check
```

Append environment-specific SQL/Pushover/IB/end-to-end commands to the deployment checklist; do not put real secrets in command history or evidence.

If legacy SPX characterization tests remain during the retention stage, run them as additional evidence. After legacy removal, the canonical SPX golden suite is `stocks_collecting\tests\strategy_runtime\spx_gex`.

## Required handoff evidence

- Final topology/configuration inventory with secrets removed.
- Completed end-to-end and failure-injection matrix.
- SQL health queries plus sample normal/abnormal output.
- Security/grant/import/order-call audit.
- Performance baseline and retention decisions.
- Backup/restore and notification reconciliation rehearsal.
- Fully completed deployment checklist showing which actions were only documented versus actually approved/executed.
- Final residual-risk register and named operational owners.
