# SPX GEX to General Strategy Runtime Refactoring

This directory is the implementation packet for moving the SPX GEX strategy out of the `stocks_au_web` FastAPI process, rebuilding it as a reusable strategy runtime in `stocks_collecting`, and then adding META GEX/PCR as the first additional strategy.

The packet is written for a smaller implementation model. Each task is intentionally bounded and contains prerequisites, exact file areas, invariants, tests, acceptance criteria, rollback conditions, and required handoff evidence. Implement one task at a time and do not silently absorb work from a later task.

## Fixed decisions

These decisions are not open for reinterpretation during implementation:

- The new heavy-lifting application is the top-level Python package `strategy_runtime` at `C:\Repo\stocks_collecting\src\strategy_runtime`.
- `stocks_collecting\pyproject.toml` must explicitly package both `stocks_collecting` and `strategy_runtime` from `src`; do not nest the runtime below `src\stocks_collecting`.
- Production state is stored in SQL Server database `StockDB_US`, schema `[TradingSignal]`.
- SQLite is not a production Adapter. The existing SQLite database is only a migration source and may be used in isolated legacy tests.
- `stocks_collecting` owns all strategy writes, calculations, IB access, lifecycle processing, report generation, and notification publishing.
- FastAPI owns a read-only `ReportCatalog` Module. It must not import or construct the runtime.
- Windows Task Scheduler wakes a short-lived `run-due` command every minute. Market timing is calculated in Python using `America/New_York` and exchange sessions.
- Normal retries reuse the same Strategy Run and outputs. An intentional correction creates a new revision and explicitly supersedes the previous report.
- Every user-facing notification links to an immutable Report Snapshot, not a mutable `latest` URL.
- SPX behavior is migrated and reconciled before META is implemented.
- META `auto_entry=true` means paper/manual lifecycle state plus an `ENTER` notification. It does not authorize broker order placement.
- Each Strategy Deployment uses its own Execution Book unless a future configuration explicitly shares one.

## Repository map

| Responsibility | Repository | Root |
|---|---|---|
| Existing SPX implementation and website | `stocks_au_web` | `C:\Repo\stocks_au_web` |
| New runtime, SQL schema, scheduler entry points, Pushover publishing | `stocks_collecting` | `C:\Repo\stocks_collecting` |
| Production operational database | SQL Server | `StockDB_US.[TradingSignal]` |
| Existing generic Pushover queue | SQL Server | `StockDB.[Notification]` |

## Task order

| Task | Purpose | Depends on |
|---|---|---|
| [01](01-baseline-characterization.md) | Freeze current SPX behavior and migration fixtures | None |
| [02](02-sql-server-schema.md) | Create `StockDB_US.[TradingSignal]` schema and database invariants | 01 |
| [03](03-runtime-domain-and-interface.md) | Create the runtime domain model and small Interfaces | 01 |
| [04](04-sql-server-runtime-store.md) | Implement SQL Server claims, transactions, persistence, and report reads | 02, 03 |
| [05](05-notification-pipeline.md) | Make Pushover publishing durable, idempotent, and report-linked | 02, 03, 04 |
| [06](06-port-spx-strategy.md) | Port SPX calculation, lifecycle, report, and backtest behavior | 03, 04, 05 |
| [07](07-runtime-cli-and-scheduling.md) | Add `run-due`, replay commands, batch files, and scheduling semantics | 04, 06 |
| [08](08-read-only-report-catalog.md) | Replace FastAPI SPX execution imports with a generic read-only catalog | 04, 06 |
| [09](09-general-report-frontend.md) | Build the Trading Signal Reports page and legacy page compatibility | 08 |
| [10](10-sqlite-migration.md) | Migrate retained SPX SQLite state and HTML snapshots to SQL Server | 02, 04, 06, 08 |
| [11](11-dual-run-reconciliation.md) | Run old and new SPX paths side by side without duplicate actions | 06, 07, 10 |
| [12](12-cutover-and-legacy-removal.md) | Cut over scheduling and remove execution behavior from FastAPI | 08, 09, 11 |
| [13](13-new-strategy-contract.md) | Publish and validate the future research-to-production contract | 03, 06 |
| [14](14-meta-gex-pcr-strategy.md) | Add META using the contract and common runtime | 07, 12, 13 |
| [15](15-end-to-end-validation-and-operations.md) | Complete failure testing, deployment runbook, and operational evidence | 12, 14 |

Tasks 02 and 03 may be implemented in parallel after Task 01. Tasks 08 and 13 may be implemented in parallel once their prerequisites are complete. All other ordering is deliberate.

## Supporting design artifacts

- [Target architecture and invariants](00-target-architecture.md)
- [Domain language](CONTEXT.md)
- [New-strategy contract template](new-strategy-contract-template.md)
- [Normalized META GEX/PCR reference](meta-gex-pcr-reference.md)
- [Manual TradingSignal DDL](manual-trading-signal-ddl.sql)
- [Manual notification queue DDL](manual-notification-queue-ddl.sql)
- [Manual database setup order](manual-database-setup.md)
- [Implementation review checklist](review-checklist.md)

## Required implementer protocol

For every task:

1. Read this file, [CONTEXT.md](CONTEXT.md), [00-target-architecture.md](00-target-architecture.md), and the selected task completely.
2. Run `git status --short` in both repositories before editing. Existing changes belong to the user.
3. Limit changes to the task's declared scope. If a prerequisite is missing, stop and report it instead of implementing a workaround from a later task.
4. Add or update tests in the same task as the behavior.
5. Run the task's required verification commands.
6. Run `git diff --check` in every modified repository.
7. Return a handoff containing:
   - files changed;
   - database objects added or changed;
   - commands executed and results;
   - acceptance criteria evidence;
   - assumptions made;
   - remaining risks or blockers.

Do not commit, push, deploy, enable Windows tasks, or change production database objects unless the user explicitly requests that action for the selected task.

## Global stop conditions

Stop and request direction if any of the following is discovered:

- `StockDB` and `StockDB_US` are not on the same SQL Server instance. Task 05 assumes a local cross-database transaction; a relay outbox design is required otherwise.
- Existing production SPX behavior differs from the characterization fixtures created in Task 01.
- The source database does not provide an unambiguous completed Observation date.
- A requested change would place live broker orders. Live order placement is outside this project.
- A database migration would overwrite or delete existing SPX records.
- The implementation cannot distinguish a normal retry from an intentional correction.
- Pushover delivery is ambiguous and the proposed behavior would automatically retry it.

## Standard verification commands

Use the repository's configured environment when available. Record substitutions if local paths differ.

```powershell
# stocks_au_web backend
Set-Location C:\Repo\stocks_au_web\backend
..\venv\Scripts\python.exe -m unittest tests.test_spx_gex_strategy

# stocks_au_web frontend
Set-Location C:\Repo\stocks_au_web\frontend
npm run lint
npm run build

# stocks_collecting
Set-Location C:\Repo\stocks_collecting
poetry run pytest tests\strategy_runtime -q

# whitespace/error check in each modified repository
git diff --check
```

Integration tests that require SQL Server or IB must be separately marked and must fail with a clear skip reason when required credentials or services are unavailable.

The legacy backend SPX test command applies only until Task 12 Stage D. Thereafter, SPX characterization lives in `stocks_collecting\tests\strategy_runtime\spx_gex` and the web backend runs only ReportCatalog/compatibility tests.

## Review packet

The later checking pass should use [review-checklist.md](review-checklist.md). The implementing model should not mark a task complete merely because unit tests pass; database invariants, idempotency, failure behavior, and prohibited dependencies are equally important.
