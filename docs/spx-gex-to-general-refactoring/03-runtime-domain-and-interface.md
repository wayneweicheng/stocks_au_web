# Task 03: Build the Runtime Domain and Interfaces

## Objective

Create the top-level `strategy_runtime` package, domain types, scheduling abstractions, Strategy Implementation seam, and a pure/in-memory runtime test harness. This task defines behavior but does not connect to SQL Server, IB, FastAPI, or Pushover.

## Prerequisites

- Task 01 fixtures are available.
- Read `CONTEXT.md` and `00-target-architecture.md` completely.

## Repository

`C:\Repo\stocks_collecting`

## Required files

Create at minimum:

```text
src\strategy_runtime\__init__.py
src\strategy_runtime\domain.py
src\strategy_runtime\interface.py
src\strategy_runtime\registry.py
src\strategy_runtime\scheduling.py
src\strategy_runtime\runtime.py
src\strategy_runtime\config.py
tests\strategy_runtime\test_domain.py
tests\strategy_runtime\test_runtime_interface.py
tests\strategy_runtime\test_scheduling.py
```

Internal file grouping may be adjusted, but keep a single public Interface surface re-exported from `strategy_runtime.__init__`.

## Dependency changes

Declare direct dependencies in `pyproject.toml` for packages the migrated runtime imports. Do not rely on transitive dependencies from `arkofdata-common`.

Change Poetry's package discovery explicitly so the existing collectors and the new top-level application are both installed:

```toml
packages = [
    { include = "stocks_collecting", from = "src" },
    { include = "strategy_runtime", from = "src" },
]
```

Verify both `import stocks_collecting` and `import strategy_runtime` in the Poetry environment. Do not move existing collector code and do not create `src\stocks_collecting\strategy_runtime`.

Expected additions include:

- `pyodbc` matching the working web backend version unless repository constraints require another compatible version;
- `ib-insync==0.9.86` initially, preserving current SPX behavior;
- `exchange-calendars` compatible with the working backend.

Do not remove `pandas-market-calendars` in this task because other collectors may use it.

## Required domain types

Use frozen dataclasses or Pydantic models for immutable value objects. Use string enums for persisted values.

At minimum define:

- `InstrumentRef` and `InstrumentRole`;
- `StrategyRef`, `StrategyDescriptor`, and `StrategyDeployment`;
- `EnvironmentType`;
- `RunKind`, `RunStatus`, `RerunMode`, `RunDisposition`;
- `StrategyRunKey`, `RunRequest`, `RerunRequest`, and `RunResult`;
- `Observation`, `ObservationQuality`, and `QualityIssue`;
- `Direction`, `SignalAction`, `Confidence`, and `SignalDecision`;
- `SignalOutcome` and `OutcomeHorizon`;
- `TradePlan`, `TradePlanStatus`, `TradePlanEvent`, and `ExitReason`;
- `ExecutionBookView`;
- `ReportDocument` and `ReportSummary`;
- `NotificationIntent`, `NotificationType`, and priority;
- `DecisionBundle` and `LifecycleBundle`;
- provenance/source manifest value objects.

Strategy-specific classifications remain strings namespaced by Strategy Version; do not add SPX or META classifications to core enums.

The common Confidence values are `NONE`, `LOW`, `LOW_MEDIUM`, `MEDIUM`, `MEDIUM_HIGH`, and `HIGH`. A strategy may not persist ad hoc spelling variants.

## Public runtime Interface

Expose only:

```python
class StrategyRuntime(Protocol):
    def run_due(self, *, now: datetime, worker_id: str) -> tuple[RunResult, ...]: ...
    def rerun(self, request: RerunRequest) -> RunResult: ...
```

Document:

- timezone requirements;
- deterministic run identity;
- ordering guarantees;
- retry and correction semantics;
- expected dispositions;
- failure modes;
- maximum work-per-call behavior.

Do not expose persistence, notification, or data-source methods through this Interface.

## Internal Interfaces

Define only seams that have or will immediately have two Adapters:

- `StrategyImplementation`: SPX and META.
- `RuntimeStore`: in-memory and SQL Server.
- `SessionCalendar`: exchange and deterministic test calendar.
- `Clock`: system and fixed.

Source Adapters remain private to a Strategy Implementation. Report rendering is a strategy method because report content materially differs.

## Registry

The registry maps immutable `ImplementationKey` values to Strategy Implementations. Requirements:

- duplicate keys fail at startup;
- an enabled deployment with an unknown key fails closed;
- version/deployment metadata is passed to implementations but implementations cannot mutate it;
- registry lookups do not branch on Instrument code;
- shadow implementations can be marked `execution_enabled=False`.

## Scheduling model

Implement pure calculations that convert a deployment schedule and `now` into canonical due work.

Requirements:

- all `now` values are timezone-aware;
- schedules are interpreted in `America/New_York` unless the deployment explicitly declares another IANA timezone;
- exchange sessions handle holidays, early closes, and DST;
- scheduled effective time, not wake time, enters the run key;
- a due window prevents an old entry from executing indefinitely;
- catch-up policy distinguishes evaluation, monitoring, and entry/exit work;
- duplicate heartbeat calls return the same canonical work identity;
- no weekday-only fallback is allowed in production.

## Trade Plan transition validator

Implement a pure validator for the state model:

```text
WAITING_ENTRY -> ACTIVE | CANCELLED
ACTIVE -> EXITED_TP | EXITED_SL | EXITED_TIME | CANCELLED
terminal -> no transition
```

Additional rules:

- only a `PLAN_ENTRY` Signal can create a plan;
- `WATCH` and `NONE` cannot create plans;
- one plan cannot ENTER twice;
- one plan cannot produce two terminal exits;
- an opposing Signal creates an informational event, not automatic reversal;
- a blocked Observation cannot produce `PLAN_ENTRY`.

## In-memory runtime harness

Create a deterministic in-memory `RuntimeStore` Adapter for Interface-level tests. It must emulate:

- run identity and already-completed disposition;
- lease ownership at a behavioral level;
- atomic commit/rollback;
- Trade Plan transition validation;
- immutable report reuse;
- correction revisions;
- Notification Intent deduplication.

This Adapter is for tests, not production.

## Tests

Cover at minimum:

- naive datetimes rejected;
- UTC/New York normalization;
- DST and market-holiday schedule cases from Task 01;
- repeated heartbeats produce one run identity;
- expired entry window cancels rather than entering late;
- normal rerun returns `ALREADY_COMPLETED`;
- correction requires a non-empty reason;
- corrections receive a new revision and do not create a plan by default;
- illegal lifecycle transitions are rejected;
- blocked data cannot create entry;
- two deployments of the same Strategy Version remain distinct;
- separate Execution Books do not conflict;
- unknown implementation key fails before work is claimed;
- runtime core contains no SPX/META Instrument branch.

## Acceptance criteria

- The package imports without SQL Server, IB, or Pushover being available.
- The public Interface has only the documented runtime operations.
- Interface tests exercise the complete workflow through the deep Module rather than calling internal helpers.
- Domain types make invalid direction/action/status combinations difficult or explicitly validated.
- Scheduling tests use exchange sessions and pass the Task 01 calendar cases.
- No SPX or META calculation logic exists yet.

## Out of scope

- SQL Server Implementation.
- Any network call.
- Strategy-specific classification.
- HTML templates.
- CLI/batch files.

## Verification

```powershell
Set-Location C:\Repo\stocks_collecting
poetry lock
poetry run pytest tests\strategy_runtime\test_domain.py tests\strategy_runtime\test_runtime_interface.py tests\strategy_runtime\test_scheduling.py -q
poetry run mypy src\strategy_runtime
git diff --check
```

If the repository's existing mypy configuration reports unrelated failures, scope mypy to the new package and report any remaining package-local errors.

## Required handoff evidence

- Public Interface listing.
- Dependency changes and lockfile result.
- State/scheduling test output.
- Explanation of every new internal seam and its two Adapters.
