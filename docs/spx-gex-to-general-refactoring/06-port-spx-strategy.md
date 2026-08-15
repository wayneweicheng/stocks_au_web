# Task 06: Port SPX GEX into the General Runtime

## Objective

Port the current SPX GEX calculation, production/shadow comparison, Trade Plan lifecycle, HTML reports, and backtest behavior from `stocks_au_web` into a Strategy Implementation under `C:\Repo\stocks_collecting\src\strategy_runtime`. Preserve the characterized behavior before making any rule improvement.

## Prerequisites

- Tasks 01, 03, 04, and 05 are complete.
- Task 01 characterization fixtures and their expected outputs are committed or otherwise available to the implementation branch.
- Read the current SPX package and its tests completely before editing either repository.

## Repositories and source files

Read from `C:\Repo\stocks_au_web`:

```text
backend\app\spx_gex_strategy\
backend\tests\test_spx_gex_strategy.py
```

Create in `C:\Repo\stocks_collecting`:

```text
src\strategy_runtime\strategies\spx_gex\__init__.py
src\strategy_runtime\strategies\spx_gex\implementation.py
src\strategy_runtime\strategies\spx_gex\domain.py
src\strategy_runtime\strategies\spx_gex\features.py
src\strategy_runtime\strategies\spx_gex\classification.py
src\strategy_runtime\strategies\spx_gex\lifecycle.py
src\strategy_runtime\strategies\spx_gex\report.py
src\strategy_runtime\strategies\spx_gex\sources.py
src\strategy_runtime\strategies\spx_gex\backtest.py
tests\strategy_runtime\spx_gex\
```

File grouping may change when it improves cohesion, but retain one registered SPX Strategy Implementation and keep source-specific details inside this package.

## Porting rule

Treat the current working-tree implementation and Task 01 fixtures as the specification. This task is a move across an architectural seam, not a research revision.

- Preserve `v1.0.3-production` and `v1.1.0-shadow` as distinct immutable Strategy Versions.
- Preserve all green/yellow/reverse-green and other current classification precedence, thresholds, wording, and production/shadow differences.
- Preserve the exact causal/no-lookahead behavior, required bars, timezone conversion, session selection, price fallback rules, and numerical rounding.
- Preserve the report's financially meaningful values and explanations. Incidental generated IDs, timestamps, and generic page chrome may differ only where Task 01 normalization allows it.
- If the legacy code and a Task 01 fixture disagree, stop. Do not update the fixture or silently choose one behavior.

## Required implementation

### Strategy boundary

Implement the Task 03 `StrategyImplementation` Interface. The SPX implementation may:

- load its required source observations through private source Adapters;
- calculate features and a Signal Decision;
- compare production and shadow decisions;
- propose lifecycle transitions from an existing Execution Book view;
- render strategy-specific immutable HTML;
- expose deterministic backtest calculations.

It must not:

- open a SQL Server connection or issue SQL;
- import FastAPI or backend settings;
- call Pushover or insert into `StockDB.Notification`;
- claim runs, construct notification idempotency keys, or decide whether a retry is a correction;
- place an IB order.

### Source Adapters and provenance

Port the working data acquisition behavior for the current source instruments, including `SPXW.US`, `NQMAIN.US`, and the QQQ Interactive Brokers quote path where used. Keep concrete provider identifiers in SPX configuration rather than the runtime core.

Each source result must include:

- provider and source identity;
- query or contract identity without credentials;
- requested and returned market-date/time ranges;
- retrieval UTC;
- source timezone and normalized timezone;
- row count and required-field completeness;
- deterministic source-content hash;
- freshness/data-quality issues.

Do not substitute a different vendor, bar interval, close convention, or IB contract during the move.

### Mapping legacy state to generic state

Use these mappings:

| Legacy concern | Target concept |
|---|---|
| signal row | `Observation` plus `Signal` |
| production/shadow result | two Strategy Versions plus `StrategyComparison` |
| planned/active trade | `TradePlan` and append-only `TradePlanEvent` |
| singleton portfolio row | deployment-scoped `ExecutionBook` |
| notification row | `NotificationEvent` produced by the runtime publisher |
| event log | `StrategyRunAttempt`, `TradePlanEvent`, or `AuditEvent` according to meaning |
| HTML report | immutable `ReportSnapshot` |

The Strategy Implementation returns domain bundles. Task 04 persists them; do not recreate the legacy storage API.

### Lifecycle behavior

- Reproduce the current paper/manual entry, monitoring, exit, and monthly-summary behavior.
- Resolve entry/exit using the configured execution instrument and the same quote/bar semantics as the legacy path.
- Validate every transition through the common transition validator.
- A `WATCH` or `NONE` decision never creates a Trade Plan.
- A stale/missing required quote or blocked Observation must fail closed and produce the characterized data-quality outcome.
- An opposing decision while a plan is active records an `OPPOSING_SIGNAL` informational event only.
- Quantity, cash, NAV, exposure factor, P&L, and rounding must match the fixtures.
- There is no broker-order call in this package.

### Report behavior

Move SPX HTML generation into the SPX package. Rendering receives a complete immutable view model; it must not query a database or live provider.

- Include Strategy Version, Environment, market date, revision, generated UTC, provenance/data-quality summary, decision, Trade Plan state, and production/shadow comparison.
- Escape all provider-supplied and database-supplied strings.
- Do not embed credentials, connection strings, report tokens, or local file paths.
- Do not construct the public report URL in the template; Task 05's publishing Module owns that URL.
- Keep content deterministic for the same view model apart from explicitly normalized generated metadata.

### Backtest behavior

Move the SPX backtest calculation to the SPX package and make it reuse the same feature/classification functions as forward evaluation. It may use a backtest-specific orchestrator, but it must not fork the decision rules.

## Tests

Build parameterized tests from every Task 01 fixture. Cover at minimum:

- all existing production and shadow classifications;
- precedence where two raw conditions overlap;
- the exact minimum-history and exact-bar boundaries;
- no-lookahead by changing future rows without changing the result;
- New York/Sydney/UTC conversions, US DST boundaries, holidays, and early close behavior already characterized;
- missing, duplicate, stale, zero, and malformed source values;
- production/shadow comparison persistence bundle;
- plan creation, entry, TP, SL, time exit, cancellation, monthly summary, and opposing signal;
- immutable HTML normalization and escaping;
- source hash stability;
- backtest and forward calculation parity on the same input.

Keep SQL integration tests separate from pure strategy tests. Most SPX tests must run without SQL Server, IB, or network access.

## Acceptance criteria

- Every Task 01 golden case produces the same normalized decision, metrics, lifecycle result, and report facts.
- Production and shadow versions are separately registered and no version-specific branch was added to runtime core.
- SPX source and report details are confined to `strategies\spx_gex`.
- The strategy is testable through the generic Interface with the in-memory store.
- A source failure cannot produce an actionable plan.
- No live order API exists or is invoked.
- The legacy web implementation remains operational and unchanged except for any Task 01 test-only fixture support.

## Out of scope

- Changing SPX research rules or version numbers.
- Enabling the new scheduler.
- FastAPI or frontend cutover.
- Migrating SQLite records.
- Adding META.
- Removing legacy SPX code.

## Verification

```powershell
Set-Location C:\Repo\stocks_collecting
poetry run pytest tests\strategy_runtime\spx_gex -q
poetry run pytest tests\strategy_runtime -q
poetry run mypy src\strategy_runtime\strategies\spx_gex

Set-Location C:\Repo\stocks_au_web\backend
..\venv\Scripts\python.exe -m unittest tests.test_spx_gex_strategy

Set-Location C:\Repo\stocks_collecting
git diff --check
Set-Location C:\Repo\stocks_au_web
git diff --check
```

## Required handoff evidence

- A table mapping each legacy module/function to its new owner or explaining why it was retired.
- Golden-fixture parity output, including production/shadow cases.
- Explicit confirmation that no rule threshold or priority changed.
- Source Adapter/provenance examples with secrets removed.
- Test output and any characterized HTML normalization differences.

