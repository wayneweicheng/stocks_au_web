# Task 04: Implement the SQL Server Runtime Store

## Objective

Implement the production `RuntimeStore` Adapter over `StockDB_US.[TradingSignal]`. The Adapter must provide atomic run claims, fenced writes, complete evaluation/lifecycle transactions, immutable reports, and read-side report queries without leaking table-level CRUD through the runtime Interface.

## Prerequisites

- Tasks 02 and 03 are complete.
- Schema integration tests pass against an approved database.

## Repository

`C:\Repo\stocks_collecting`

## Required files

```text
src\strategy_runtime\persistence\__init__.py
src\strategy_runtime\persistence\sql_server.py
src\strategy_runtime\persistence\row_mapping.py
tests\strategy_runtime\test_sql_server_store_contract.py
tests\strategy_runtime\test_sql_server_store_integration.py
```

Names may vary, but SQL details must remain localized under `persistence`.

## Connection requirements

- Use direct `pyodbc` connections or a new narrow connection factory that propagates exceptions.
- Do not use helper methods that swallow SQL exceptions or auto-commit each statement.
- Read credentials from environment/configuration without logging them.
- Set explicit login and statement timeouts.
- Open a fresh connection per short-lived runtime invocation or controlled transaction scope.
- Parameterize every value.
- Fully qualify production objects as `[StockDB_US].[TradingSignal].[ObjectName]` where cross-database transactions will later include `StockDB.Notification`.

## Adapter Interface behavior

The SQL Adapter should expose semantic operations such as:

- discover enabled deployments and schedules;
- claim a Strategy Run;
- record retryable/terminal attempts;
- load current Execution Book and open plans;
- commit an evaluation result;
- commit a lifecycle result;
- fetch report catalog summaries/content;
- create an explicit correction.

Do not expose one method per table or allow callers to assemble transaction ordering themselves.

## Claim algorithm

Implement claims through the Task 02 stored procedure or equivalent single transaction:

1. Derive the deterministic run key before connecting.
2. Insert the Strategy Run if absent.
3. Lock the exact row with `UPDLOCK`, `ROWLOCK`.
4. Return `ALREADY_COMPLETED` if `SUCCEEDED`.
5. Return `BUSY` if another unexpired lease exists.
6. Otherwise increment fencing token, assign lease owner/expiry, set `CLAIMED`, and append a Run Attempt.
7. Return run ID and fencing token.

Every completion/retry/failure write must include the fencing token in its predicate. A stale worker updating zero rows is a `STALE_FENCE` error and must not continue.

## Evaluation transaction

One transaction must:

- verify current run fence;
- insert/reuse the immutable Observation;
- reject same revision/different data hash;
- insert the Signal;
- reserve Execution Book occupancy and insert a Trade Plan only for `PLAN_ENTRY`;
- insert a Strategy Comparison when supplied;
- insert the Report Snapshot;
- insert Notification Events;
- update the Strategy Run provenance and status to `SUCCEEDED`;
- complete the current Run Attempt.

On a duplicate normal run, return existing identifiers. Do not generate another report or notification.

If report rendering did not produce HTML, the transaction must not commit a user-facing Signal run.

## Lifecycle transaction

One transaction must:

- verify run fence;
- lock Trade Plan and Execution Book projection rows;
- verify expected `rowversion` and allowed transition;
- insert one deterministic Trade Plan Event;
- update plan prices/status/metadata;
- update NAV/cash/exposure projection when applicable;
- clear Occupancy Key for terminal states;
- insert a lifecycle Report Snapshot;
- insert Notification Events;
- complete the run/attempt.

A duplicate event returns the previously committed result. It must not apply P&L twice.

## Correction behavior

- Require `RerunMode.CORRECTION`, operator, and reason.
- Create a new correction run and Observation revision.
- Link the new report to `SupersedesReportID`.
- Preserve prior Observation, Signal, report, and event rows.
- Do not reserve an Execution Book or create a new Trade Plan unless a future explicit correction policy is added.
- Notification Events are suppressed unless `notify_correction=True` is explicitly supplied by an operator command.

## JSON and numeric mapping

- Serialize JSON deterministically for hashes: UTF-8, stable key order, no NaN/Infinity.
- Use `Decimal` for persisted prices, NAV, quantity, and P&L mapping where SQL types are decimal.
- Convert to float only inside existing strategy calculations that require it.
- Store UTC datetimes with sufficient precision and always restore timezone information.
- Reject malformed JSON/status values instead of silently defaulting.

## Report reads

Implement read methods needed by Task 08:

- inclusive Observation/report date range;
- free-text search over strategy code/name, Instrument codes, classification, filename, version, and public ID;
- optional strategy, Instrument, Environment, and report-kind filters;
- deterministic order by report market date descending, generated UTC descending, then public report ID;
- bounded limit and cursor/keyset pagination;
- latest report by optional deployment/strategy filter;
- HTML by opaque public report ID.

Do not return notification token or database internal IDs not needed by FastAPI.

## Forward outcome writes

Support idempotent append/finalization of D1/D2/D3/D5 and strategy-declared Signal Outcomes. Outcome collection is independent of whether a Trade Plan was entered. Require source provenance and prevent an ordinary retry from changing a finalized value; changed source facts use the explicit revision/correction path.

## Tests

Use one behavioral contract suite against the in-memory and SQL Server Adapters where possible.

SQL integration cases must include:

- two workers racing to claim the same run; only one receives the lease;
- expired lease reclaimed with a new fence;
- stale fence cannot commit;
- injected failure after Signal insert rolls back Observation, Signal, plan, report, notification, and run completion;
- duplicate lifecycle event does not apply P&L twice;
- simultaneous plans competing for one Occupancy Key; only one succeeds;
- separate books can each hold a plan;
- normal retry returns same report ID/content hash;
- correction creates a new report and preserves old HTML;
- Unicode notification/report content round-trips;
- report filters and cursor ordering are stable.

Integration tests must use unique test deployment keys and clean only their own rows.

## Acceptance criteria

- No SQLite imports exist in the production Adapter.
- Runtime orchestration cannot bypass fenced semantic operations.
- Every multi-table commit is one explicit transaction.
- Concurrent tests prove run and book safety.
- Reports and Notification Events are committed with the domain state they describe.
- Read queries are bounded, parameterized, and suitable for FastAPI.
- SQL errors propagate with useful context but without credentials.

## Out of scope

- Enqueueing or sending Pushover; Task 05.
- SPX/META implementations.
- FastAPI routes.
- Production schema deployment without approval.

## Verification

```powershell
Set-Location C:\Repo\stocks_collecting
poetry run pytest tests\strategy_runtime\test_sql_server_store_contract.py -q
poetry run pytest tests\strategy_runtime\test_sql_server_store_integration.py -q
git diff --check
```

## Required handoff evidence

- Semantic store operation list.
- Transaction diagrams or concise ordering description.
- Concurrency/fencing test output.
- Failure-injection rollback evidence.
- Confirmation that no production SQLite Adapter is registered.
