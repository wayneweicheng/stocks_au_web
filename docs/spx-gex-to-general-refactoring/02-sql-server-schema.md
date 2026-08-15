# Task 02: Create the SQL Server TradingSignal Schema

## Objective

Create an idempotent, non-destructive SQL Server schema in `StockDB_US.[TradingSignal]` that enforces runtime identity, concurrency, lifecycle, correction, report, and audit invariants.

The schema must be usable by multiple short-lived workers and by a read-only FastAPI connection. SQLite is not used by the production design.

## Prerequisites

- Task 01 is complete.
- The implementer has confirmed the intended SQL Server and database name.
- Before Task 05, confirm `StockDB` and `StockDB_US` report the same `SERVERPROPERTY('ServerName')`. Do not assume cross-database atomic writes otherwise.

## Repository and file layout

Create database source files in `C:\Repo\stocks_collecting`:

```text
DatabaseSchema\StockDB_US\Schemas\TradingSignal.sql
DatabaseSchema\StockDB_US\Tables\TradingSignal\*.sql
DatabaseSchema\StockDB_US\StoredProcedures\TradingSignal\*.sql
DatabaseSchema\StockDB_US\Views\TradingSignal\*.sql
src\strategy_runtime\deploy_schema.py
tests\strategy_runtime\test_schema_contract.py
tests\strategy_runtime\test_schema_integration.py
```

Follow existing `DatabaseSchema` conventions, but deployment ordering must be explicit and repeatable.

For manual pre-implementation database setup, use the reviewed reference scripts in this packet:

- `manual-trading-signal-ddl.sql` against `StockDB_US`;
- `manual-notification-queue-ddl.sql` against `StockDB`.

These scripts create/add only tables, constraints, indexes, and queue columns. They do not create stored procedures, views, permissions, seed deployments, or production strategy configuration. The implementation model must later reproduce them as repository-managed `DatabaseSchema` files and add/test the semantic procedures/views.

## Required tables

Column names may follow repository SQL naming conventions, but every listed concept and constraint is required.

Common storage rules:

- use `datetime2(3)` or finer for UTC instants and explicit `date` for market dates;
- use fixed-precision `decimal`, not SQL `float`, for persisted prices, cash, NAV, quantities, returns, and thresholds;
- JSON columns are `nvarchar(max)` with `ISJSON` checks and a `DATALENGTH <= 2,097,152` byte guard unless a documented field-specific lower limit applies;
- Report HTML is `nvarchar(max)` with `DATALENGTH <= 10,485,760` bytes;
- user/provider text is length-bounded according to its downstream contract rather than unbounded by default;
- hashes use a fixed-length lowercase-hex or binary representation and are validated consistently;
- operational timestamps receive database-side UTC defaults where a caller-supplied historical time is not required.

### `StrategyDefinition`

- Stable strategy family identity.
- `StrategyCode` is unique and immutable, for example `spx-gex` or `meta-gex-pcr`.
- Contains display name and description only; versioned behavior does not belong here.

### `StrategyVersion`

- Foreign key to Strategy Definition.
- Immutable `VersionCode`, `ImplementationKey`, `ConfigurationJson`, and `ConfigurationHash`.
- Status: `DRAFT`, `ACTIVE`, `RETIRED`.
- Unique `(StrategyDefinitionID, VersionCode)`.
- Once referenced by a successful Strategy Run, behavioral columns cannot be updated. Enforce through stored procedures/permissions and test it.

### `StrategyDeployment`

- Binds a Strategy Version to Environment, Execution Book, enabled state, and deployment key.
- Environments: `BACKTEST`, `MIGRATION_SHADOW`, `FORWARD_PAPER`, `LIVE_MANUAL`.
- `DeploymentKey` is unique and stable.
- `LIVE_AUTOMATED` is deliberately absent.

### `StrategyInstrumentRole`

- Foreign key to Strategy Deployment.
- Stores Instrument code, market, kind, role, and optional source metadata.
- Roles: `SUBJECT`, `SOURCE`, `PROXY`, `EXECUTION`, `BENCHMARK`.
- Unique `(StrategyDeploymentID, RoleCode, InstrumentCode)`.
- Do not assume every Instrument is an equity.

### `StrategySchedule`

- Deployment, Run Kind, `America/New_York` timezone, session offset, local time, cadence, due window, catch-up policy, and enabled state.
- Run Kinds: `DATA_CHECK`, `EVALUATE`, `MONITOR`, `SUMMARY`.
- Store structured columns for common timing, with JSON only for genuinely strategy-specific policy.

### `StrategyRun`

- `uniqueidentifier` primary key.
- Deployment, Run Kind, scheduled effective UTC, market date, correction number, deterministic idempotency key.
- Status, lease owner, fencing token, lease expiry, next attempt time, terminal error fields, created/started/completed timestamps.
- Provenance: git commit, configuration hash, data hash.
- Unique deterministic idempotency key.
- `rowversion` for compare-and-set updates.

### `StrategyRunAttempt`

- Append-only attempt records linked to Strategy Run.
- Worker, fencing token, start/end, outcome, retry classification, error code/message, dependency timing JSON.
- Never overwrite prior attempt diagnostics.

### `Observation`

- Deployment, market date, revision number, previous Observation date, quality status, quality issues JSON, facts JSON, source manifest JSON, data hash, created UTC.
- Quality: `VALID`, `WARNING`, `BLOCKED`.
- Unique `(StrategyDeploymentID, MarketDate, RevisionNo)`.
- Also require uniqueness for `(StrategyDeploymentID, MarketDate, DataHash)` to make repeated identical corrections idempotent.

### `Signal`

- Observation and Strategy Version foreign keys.
- Classification, Direction, Confidence, Action, detection time, actionable time, holding-period code, metrics JSON, research metadata JSON.
- Direction: `LONG`, `SHORT`, `NONE`.
- Action: `NONE`, `WATCH`, `PLAN_ENTRY`.
- Unique `(StrategyVersionID, ObservationID)`.
- Classification is not part of identity.

### `StrategyComparison`

- Supports SPX production/shadow reconciliation without adding SPX columns to core tables.
- Primary and comparison Signal/Strategy Version references, Observation, outcome statuses, outcome JSON, metrics JSON.
- Unique `(ObservationID, PrimaryStrategyVersionID, ComparisonStrategyVersionID, EnvironmentType)`.

### `SignalOutcome`

- Append-only forward-validation facts linked to Signal, with Horizon Code, revision number, declared reference price/time, horizon close, raw and applicable directional return, maximum favorable/adverse excursion through that horizon, source manifest/data hash, finalized UTC, and optional `SupersedesSignalOutcomeID`.
- Unique `(SignalID, HorizonCode, RevisionNo)` and `(SignalID, HorizonCode, DataHash)`; a changed historical source value creates an explicit higher revision, never an in-place silent rewrite.
- Outcome rows measure a Signal and do not imply that a Trade Plan was entered.

### `ExecutionBook`

- Stable Book Key, Environment, cash, NAV, exposure factor, state metadata JSON, and `rowversion`.
- No singleton constraint.
- Initial books are strategy-scoped.

### `TradePlan`

- Signal, Execution Book, Execution Instrument, Direction, status, planned entry/exit, actual paper/manual entry/exit fields, TP/SL, quantity, metadata JSON, occupancy key, and `rowversion`.
- Unique `(SignalID, ExecutionBookID)`.
- `OccupancyKey` is non-null only while `WAITING_ENTRY` or `ACTIVE`.
- A filtered unique index on non-null `OccupancyKey` prevents conflicting plans.
- Status check constraint matches the state model in `00-target-architecture.md`.

### `TradePlanEvent`

- Append-only event linked to Trade Plan and Strategy Run.
- Event Type, effective UTC, price, reason code, payload JSON, deterministic idempotency key, created UTC.
- Unique idempotency key.
- Event types include `PLANNED`, `ENTERED`, `EXITED_TP`, `EXITED_SL`, `EXITED_TIME`, `CANCELLED`, `EXIT_APPROACHING`, and `OPPOSING_SIGNAL`.

### `ReportSnapshot`

- Strategy Run, Signal/Trade Plan references when applicable, opaque public report ID, report kind, report/Observation dates, strategy and Instrument display metadata, safe title/summary, filename, revision, content hash, HTML content, generated UTC, and `SupersedesReportID`.
- `HtmlContent` is `nvarchar(max)`.
- Unique `(StrategyRunID, ReportKind)`.
- Unique public report ID.
- Content hash is SHA-256 lowercase hex.
- A foreign key prevents `SupersedesReportID` from referencing itself.

### `NotificationEvent`

- Immutable channel-neutral notification linked to origin Signal/Trade Plan Event, Report Snapshot, recipient target, type, title, body, priority, template version, idempotency key, created UTC.
- Unique idempotency key.
- A Notification Event requiring user delivery must reference a Report Snapshot.

### `NotificationDelivery`

- Notification Event, channel, queue message ID/provider request ID, state, attempts, lease fields, last error, timestamps, and `rowversion`.
- States: `PENDING`, `QUEUED`, `PROCESSING`, `SENT`, `RETRY_WAITING`, `FAILED`, `DELIVERY_UNKNOWN`, `SKIPPED`.
- Unique `(NotificationEventID, ChannelCode, RecipientKey)`.

### `AuditEvent`

- Append-only operational/migration events that do not fit the Strategy Run or Trade Plan lifecycle.
- Event Type, source, payload JSON, created UTC, optional legacy identity.

### `LegacyImportBatch`

- One row per attempted SQLite import with source identifier, canonical source path for operator evidence, file SHA-256, source schema fingerprint, import-tool version, started/completed UTC, status, source/target count summary JSON, and error summary.
- Do not store SQLite bytes in SQL Server.
- A completed file hash cannot be imported a second time unless the operator explicitly selects verification-only mode.

### `LegacyIdentityMap`

- Maps `(SourceSystem, SourceTable, LegacyID)` to target entity type and target `uniqueidentifier`.
- Includes Import Batch and optional mapping metadata JSON.
- Unique source identity and unique `(TargetEntityType, TargetEntityID)` constraints make migration resumable and auditable.

### `ReportAlias`

- Maps a normalized legacy alias key, legacy filename/path/date metadata, and optional Environment to one `ReportSnapshot`.
- The normalized alias key is unique; aliases are immutable after creation except for an explicit audited collision resolution.
- Alias lookup returns the exact imported snapshot. It must never resolve through `latest`.

## Stored procedures

At minimum provide tightly scoped procedures for:

- registering immutable strategy metadata and deployments;
- claiming or reclaiming a due Strategy Run with `UPDLOCK`, `READPAST`, `ROWLOCK`, an expiring lease, and fencing token;
- completing/retrying/failing a Strategy Run only when the caller owns the current fence;
- committing an evaluation atomically;
- committing a Trade Plan transition atomically with Execution Book occupancy checks;
- appending/revising a Signal Outcome with source provenance;
- synchronizing a Notification Delivery claim/outcome by Notification Event and queue message identity;
- creating/reusing a Report Snapshot;
- listing and reading report metadata for FastAPI;
- resolving a legacy Report Alias to one immutable Report Snapshot;
- recording corrections and `SupersedesReportID`.

Do not create one shallow procedure per CRUD operation. Procedures should protect complete invariants.

## Read views

Create read-only views suitable for Task 08:

- `v_ReportCatalog`
- `v_ReportSnapshotContent`
- `v_CurrentTradePlans`
- `v_StrategyRunHealth`

The catalog view must expose only fields needed for filtering and display. The content view includes HTML and should be granted separately.

## Deployment script

`deploy_schema.py` must:

- require an explicit database name and default only to `StockDB_US`;
- refuse databases not allow-listed by configuration;
- apply schema, tables, indexes, procedures, then views in deterministic order;
- be idempotent;
- support `--dry-run` and `--verify-only`;
- never drop a table or column;
- print an object/change summary without printing credentials;
- return non-zero on partial failure.

Do not use an ORM auto-migration tool for this task.

## Tests

### Contract tests without a database

Parse/check SQL sources for required objects, constraints, indexes, and prohibited destructive statements.

### SQL integration tests

When a test database is configured, verify:

- deployment can run twice;
- duplicate run keys resolve to one row;
- duplicate Signal identity is rejected;
- duplicate active occupancy is rejected;
- stale fencing tokens cannot complete runs;
- terminal Trade Plans cannot transition;
- normal report retry reuses a report;
- correction report can supersede but not overwrite;
- Strategy Version behavior cannot mutate after use;
- Unicode HTML and JSON round-trip exactly;
- oversized/invalid JSON and oversized HTML are rejected by the invariant-owning procedure/constraint;
- Signal Outcome duplicate data is reused and a changed value requires a higher revision;
- Legacy Identity and Report Alias uniqueness reject conflicting mappings;
- rollback removes all rows from a deliberately failed multi-table transaction.

Use test-specific Strategy Codes and clean up only those exact rows.

## Acceptance criteria

- All required objects exist in source-controlled DDL.
- Every identity/invariant has a database unique/check/foreign-key constraint where feasible.
- No production table is dropped, renamed, or truncated.
- SQL deployment is repeatable.
- The schema supports more than one Execution Book and Strategy Deployment.
- SQL integration tests demonstrate lease, fencing, occupancy, idempotency, and rollback behavior.
- No application implementation from later tasks is smuggled into the deploy script.

## Out of scope

- Porting SPX code.
- FastAPI endpoints.
- Frontend work.
- Deploying to production without explicit user approval.
- Modifying `StockDB.Notification` objects; that belongs to Task 05.

## Verification

```powershell
Set-Location C:\Repo\stocks_collecting
poetry run pytest tests\strategy_runtime\test_schema_contract.py -q
poetry run python -m strategy_runtime.deploy_schema --database StockDB_US --dry-run
poetry run python -m strategy_runtime.deploy_schema --database StockDB_US --verify-only
poetry run pytest tests\strategy_runtime\test_schema_integration.py -q
git diff --check
```

## Required handoff evidence

- Object list and DDL file list.
- Dry-run and verify output.
- Integration database used, clearly identifying whether it was production or test.
- Constraint/concurrency test results.
- Confirmation of whether `StockDB` and `StockDB_US` share one SQL Server instance.
