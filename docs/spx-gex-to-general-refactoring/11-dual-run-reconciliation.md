# Task 11: Dual-Run and Reconcile SPX

## Objective

Run the legacy FastAPI SPX implementation and the new `strategy_runtime` SPX implementation over identical observations, compare all financially meaningful outputs, and prove parity without duplicate Trade Plans or notifications.

## Prerequisites

- Tasks 06, 07, and 10 are complete.
- Task 01 characterization and Task 10 migration reports have no unresolved critical discrepancy.
- The old path remains the sole operational source of SPX actions during this task.

## Safety configuration

Create a dedicated new deployment such as:

```text
DeploymentKey: spx-gex-parity
Environment: MIGRATION_SHADOW
execution_enabled: false
notification_delivery_enabled: false
report_visibility: operator-only
```

Rules:

- The legacy FastAPI path remains authoritative and may continue its existing notifications/lifecycle.
- The new path may persist observations, signals, comparisons, and diagnostic reports only.
- It must not create an actionable Trade Plan, occupy the production Execution Book, insert `StockDB.Notification.MessageQueue`, or send Pushover.
- Use a separate Execution Book even for shadow state. Never point both implementations at one mutable portfolio row.
- Tag all parity runs and reports so the normal website excludes them unless an operator explicitly filters for `MIGRATION_SHADOW`.

## Reconciliation tooling

Create in `C:\Repo\stocks_collecting`:

```text
src\strategy_runtime\reconciliation\spx_parity.py
tests\strategy_runtime\reconciliation\test_spx_parity.py
```

The tool accepts a market-date range and compares legacy SQLite/exported fixtures with SQL Server using stable observation/deployment/version identities. It must produce JSON plus Markdown and return non-zero when an unexplained mismatch exceeds the gate.

## Comparison contract

For each market date and Run Kind compare:

- whether a run should exist and its scheduled effective time;
- source date ranges, row counts, content hashes where equivalent, and data-quality classification;
- all raw/derived financially meaningful metrics with an explicit per-field tolerance;
- production and shadow classifications, Direction, Confidence, Action, and rule precedence;
- actionable/planned/entry/monitor/exit timestamps;
- execution quote/bar identity, price, quantity, TP/SL, cash/NAV/P&L projections;
- notification type/title/body after documented generic-link normalization;
- report kind, metadata, normalized content hash, and every displayed financial value;
- failure/retry disposition;
- monthly summary outputs.

Do not use one blanket float tolerance. Define decimal/price/percentage tolerances by field based on the legacy calculation and persisted precision. Exact enums, dates, IDs derived from deterministic mapping, state transitions, and classifications require exact equality.

## Test windows

Use three layers:

1. Every Task 01 golden fixture and edge case.
2. At least the most recent 60 valid historical SPX observations, plus any older dates needed to include every known classification and lifecycle branch.
3. At least five consecutive completed US trading sessions of scheduler-driven dual-run operation, covering data check, evaluation, retry wake-up, monitoring, and any applicable month-end summary. If no actionable Signal occurs, use deterministic lifecycle replay fixtures; do not wait indefinitely or manufacture a production Signal.

Include at least one DST boundary, holiday adjacency, early close, missing-data failure, repeated invocation, and source delay/retry case through historical or controlled replay.

## Difference classification

Every mismatch is one of:

- `EXPECTED_PRESENTATION`: approved generic chrome/link/identifier difference with normalization documented;
- `EXPECTED_ARCHITECTURE`: persistence/attempt metadata differs without changing domain outcome;
- `BUG_LEGACY`: legacy behavior is unsafe/incorrect but retained for parity pending an explicit version change;
- `BUG_NEW`: new implementation must be fixed before cutover;
- `RESEARCH_CHANGE`: prohibited in this migration and requires a new Strategy Version/task;
- `UNKNOWN`: blocks cutover.

The tool may apply only reviewed normalization rules checked into source. It must not suppress a mismatch solely because a field is hard to compare.

## Parity gates

Cutover eligibility requires:

- zero `BUG_NEW`, `RESEARCH_CHANGE`, or `UNKNOWN` differences;
- exact classification/action/direction and lifecycle-state parity for all comparable cases;
- zero unexpected actionable notification or Trade Plan differences;
- no duplicate run/report/event identities under repeated invocation;
- all presentation/architecture differences individually documented and approved;
- successful five-session live scheduler window with no new-path delivery side effects;
- database/CLI health showing no stuck leases or accumulating retry backlog.

A legacy bug may not be silently fixed during parity. Record it and either preserve it for the migrated version or obtain approval for a new version and updated fixtures.

## Operational procedure

1. Record both repository commits, configuration hashes, database schema version, source IDs, and comparison window.
2. Verify all new-path delivery and execution gates are disabled at both configuration and database policy levels.
3. Run historical reconciliation.
4. Enable only the new `MIGRATION_SHADOW` scheduled evaluation path.
5. Inspect output after each session and classify differences.
6. Re-run the full report after any fix; do not carry forward a stale pass.
7. Freeze the final evidence and proposed cutover watermark.

Do not enable production scheduling or disable the legacy scheduler in this task.

## Tests

Cover the reconciliation tool itself:

- exact match;
- exact-enum mismatch despite close numeric values;
- per-field numerical tolerance boundaries;
- missing row on either side;
- duplicate observations;
- normalization rule application and audit output;
- new-path queue/event side-effect detection;
- non-zero process exit on blocking difference;
- deterministic JSON/Markdown output.

## Acceptance criteria

- Required historical and scheduler-driven windows pass all parity gates.
- No new-path Pushover queue row or production-book mutation occurred.
- Each difference has evidence and classification.
- The final report names the exact commits/configuration/schema it validates.
- A cutover watermark and rollback baseline are proposed but not activated.

## Out of scope

- Production cutover.
- Rule improvements.
- META implementation.
- Legacy code deletion.
- Treating visual similarity alone as parity.

## Verification

```powershell
Set-Location C:\Repo\stocks_collecting
poetry run pytest tests\strategy_runtime\reconciliation -q
poetry run python -m strategy_runtime.reconciliation.spx_parity --from <date> --to <date> --format both
poetry run python -m strategy_runtime health --json
git diff --check

Set-Location C:\Repo\stocks_au_web\backend
..\venv\Scripts\python.exe -m unittest tests.test_spx_gex_strategy
```

## Required handoff evidence

- Final reconciliation JSON and Markdown.
- Difference register with approval status.
- SQL evidence of zero shadow queue messages and zero production-book writes.
- Five-session scheduler record.
- Exact commits, configuration hashes, schema version, and source hashes.
- Explicit `READY FOR CUTOVER` or `NOT READY` conclusion.

