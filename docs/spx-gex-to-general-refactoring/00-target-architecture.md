# Target Architecture and Non-Negotiable Invariants

## Outcome

The refactor creates two deep Modules separated by SQL Server:

- `StrategyRuntime` in `stocks_collecting` owns all writes and operational behavior.
- `ReportCatalog` in `stocks_au_web` owns authenticated/read-token access to committed reports.

```text
Windows Task Scheduler
        |
        | run-due every minute
        v
strategy_runtime
  |-- Strategy Implementations: SPX, META, future
  |-- SQL/IB/Web source Adapters
  |-- Session calendar and lifecycle rules
  |-- HTML renderers
  |
  +--> StockDB_US.[TradingSignal]
         |-- committed strategy state
         |-- immutable Report Snapshots ------> FastAPI ReportCatalog ------> browser
         +-- Notification Events
                    |
                    +--> StockDB.[Notification].[MessageQueue]
                              |
                              +--> generic handler --> Pushover
```

SQL Server is the cross-repository seam. Neither repository reads files owned by the other repository at runtime.

## Why SQL Server replaces SQLite

The reason is not that SQLite is incapable of storing these rows. The reason is ownership and coordination:

- both repositories already need the same committed reports and metadata, so a file path would become a fragile cross-repository API;
- Windows Task Scheduler, manual retries, the notification handler, and future Strategy Deployments can overlap, requiring database claims, leases, fencing, unique constraints, and transactional occupancy;
- a Signal, Trade Plan transition, immutable report, Notification Event, and Pushover queue row must commit atomically;
- SQL Server supports a least-privilege read-only FastAPI principal without exposing the writer's filesystem;
- backup, restore, monitoring, schema deployment, query access, and multi-strategy history belong in the existing operational database.

Moving the SQLite file into `stocks_collecting` would preserve its coupled concerns and add shared-file locking, path, deployment, and permission failure modes. SQLite remains useful as the read-only legacy migration source and for isolated tests only.

## Why the runtime is a short-lived heartbeat

Windows Task Scheduler wakes `run-due` once per minute. Python and SQL decide what is canonically due. This keeps process recovery, deployment, and logging simple while SQL leases make overlapping wake-ups safe. A perpetual in-process loop would duplicate service supervision and make a hung strategy able to delay all later strategies.

## External Interfaces

The runtime Interface has two operations:

```python
class StrategyRuntime:
    def run_due(self, *, now: datetime, worker_id: str) -> tuple[RunResult, ...]: ...

    def rerun(self, request: RerunRequest) -> RunResult: ...
```

`run_due` discovers work from enabled Strategy Deployments and persisted Trade Plans. Callers do not choose data sources, calculate sessions, generate idempotency keys, render HTML, or send notifications.

The report Interface has three operations:

```python
class ReportCatalog:
    def list(self, query: ReportQuery) -> ReportPage: ...
    def get(self, public_report_id: str) -> ReportSnapshot | None: ...
    def latest(self, query: LatestReportQuery) -> ReportSnapshot | None: ...
```

FastAPI receives only the `ReportCatalog`. It cannot construct the runtime or its Adapters.

## Internal strategy seam

Two Strategy Implementations make this a real seam: SPX and META.

```python
class StrategyImplementation(Protocol):
    descriptor: StrategyDescriptor

    def evaluate(self, context: EvaluationContext) -> DecisionBundle: ...
    def advance(self, context: MonitoringContext) -> LifecycleBundle: ...
    def render(self, context: ReportContext) -> ReportDocument: ...
```

The Implementation returns proposed domain results. It must not:

- commit SQL;
- update a plan directly;
- call Pushover;
- create public URLs;
- calculate its own run idempotency key;
- branch on Environment to bypass runtime invariants.

Source Adapters remain strategy-owned because SQL, web, file, and IB inputs vary too widely for a useful universal data-source Interface.

## Proposed package layout

```text
C:\Repo\stocks_collecting\src\strategy_runtime\
  __init__.py
  __main__.py
  interface.py
  domain.py
  config.py
  registry.py
  runtime.py
  scheduling.py
  reporting.py
  cli.py
  contracts\
    strategy-descriptor.schema.json
  persistence\
    __init__.py
    sql_server.py
  notifications\
    __init__.py
    publisher.py
  strategies\
    __init__.py
    spx_gex\
      implementation.py
      domain.py
      sources.py
      features.py
      classification.py
      lifecycle.py
      report.py
      backtest.py
    meta_gex_pcr\
      implementation.py
      sources.py
      features.py
      classification.py
      lifecycle.py
      report.py
      backtest.py
```

Provider connection helpers may be shared as private infrastructure, but source selection, query semantics, and provenance remain inside each Strategy package. The exact number of internal files may change if locality improves, but the external Interfaces and ownership rules may not.

`C:\Repo\stocks_collecting\pyproject.toml` packages `strategy_runtime` as a second top-level package alongside the existing `stocks_collecting` package.

## State models

### Strategy Run

```text
PENDING -> CLAIMED -> SUCCEEDED
              |
              +----> RETRY_WAITING -> CLAIMED
              |
              +----> FAILED_TERMINAL
```

- An expired `CLAIMED` lease may be reclaimed using a new fencing token.
- A retry changes Run Attempt records, not Strategy Run identity.
- `SUCCEEDED` is immutable.
- A correction creates a different run key with `CorrectionNo > 0`.

### Signal action

```text
NONE          persist only
WATCH         persist, report, optional WATCH notification
PLAN_ENTRY    persist and create at most one Trade Plan
```

Direction is `LONG`, `SHORT`, or `NONE`. Do not encode `LONG BIAS` as a direction; use `Direction=LONG`, `Action=WATCH`.

### Trade Plan

```text
WAITING_ENTRY -> ACTIVE -> EXITED_TP
      |            |----> EXITED_SL
      |            |----> EXITED_TIME
      |            +----> CANCELLED
      +-----------------> CANCELLED
```

`WAITING_ENTRY` may transition directly to `CANCELLED`. Terminal states cannot transition again. Opposing Signals do not automatically reverse a plan.

Every transition creates an immutable Trade Plan Event. The mutable Trade Plan row is only a projection for efficient reads and must carry a SQL Server `rowversion`.

## Instrument and book rules

- SPX uses Subject `SPX`, Source `SPXW.US`, Proxy `NQMAIN.US`, and Execution `QQQ`.
- META uses Subject and Execution `META`.
- An Execution Book is not global. Initial deployments use separate books:
  - `SPX_GEX_FORWARD_PAPER`
  - `META_GEX_PCR_FORWARD_PAPER`
- A Trade Plan reserves one nullable `OccupancyKey` while waiting or active. A filtered unique index prevents conflicting occupancy in the same book.
- Cross-strategy capital allocation is a future project.

## Time rules

- All Interface datetimes are timezone-aware.
- Persist instants in UTC and store the relevant market timezone separately where needed.
- Evaluate schedules in `America/New_York`.
- D is the completed Observation session. D1/D2/D3/D5 use the exchange calendar.
- Early-close session times come from the exchange calendar, not constants.
- The scheduled effective time identifies a run; process start time does not.
- A missed slot is handled according to an explicit catch-up or cancellation policy.

## Transaction and ordering rules

For evaluation and lifecycle runs:

1. Claim the Strategy Run in a short transaction.
2. Perform SQL reads and external IB/web calls without holding the final state transaction.
3. Validate and hash source facts.
4. Ask the Strategy Implementation for a proposed result.
5. Render HTML from the proposed committed state.
6. In one SQL transaction:
   - insert/reuse Observation;
   - insert Signal or Trade Plan Event;
   - update the Trade Plan/Execution Book projection with optimistic concurrency;
   - insert the immutable Report Snapshot;
   - insert the Notification Event;
   - enqueue `StockDB.Notification.MessageQueue` when required;
   - mark the Strategy Run `SUCCEEDED`.
7. Release the connection before Pushover delivery occurs.

If any step in item 6 fails, none of it commits.

## Idempotency keys

Use deterministic, persisted keys with unique constraints:

```text
Strategy Run:
deployment | run_kind | scheduled_effective_utc | correction_no

Observation:
deployment | market_date | revision_no

Signal:
strategy_version | observation_id

Trade Plan:
signal_id | execution_book

Trade Plan Event:
plan_id | event_type | effective_utc | discriminator

Report Snapshot:
run_id | report_kind

Notification Event:
origin_event_id | notification_type | recipient | channel | template_version
```

Signal identity must not include classification. A changed classification for the same Strategy Version and Observation revision is a deterministic conflict, not a second Signal.

## Correction semantics

- `RETRY` retries incomplete work under the existing run key.
- `CORRECTION` requires a reason and creates a new Observation revision and Strategy Run correction number.
- Corrected reports set `SupersedesReportID`.
- Corrections do not create or reverse Trade Plans automatically.
- Correction notifications are disabled by default and require an explicit operator flag.

## Report rules

- HTML is stored in `StockDB_US.[TradingSignal].[ReportSnapshot].[HtmlContent]` as `nvarchar(max)`.
- Public report identity is opaque and immutable.
- The filename is presentation metadata, not identity.
- Every report stores strategy, version, Environment, Instrument metadata, Observation date, generated UTC time, content hash, and provenance hashes.
- A routine retry returns the existing report.
- A correction creates an append-only report revision.
- FastAPI may serve HTML and metadata but may not regenerate it.

## Notification rules

- Strategies create channel-neutral Notification Intents.
- Runtime templates may add common strategy/version/date/report metadata.
- Pushover delivery uses the existing generic notification infrastructure after Task 05 hardens it.
- Message URLs point to `/api/trading-signal-reports/{public_report_id}.html?report_token=...`.
- Do not repeat the URL in the body when the Pushover URL field is populated.
- Application-level duplicate queueing is prohibited by a unique key.
- Pushover cannot guarantee exactly-once delivery after an ambiguous network timeout. Such attempts become `DELIVERY_UNKNOWN` and require manual resolution.

## Production configuration ownership

Runtime configuration belongs in `stocks_collecting` and includes:

- SQL Server connection settings;
- report public base URL and token;
- runtime worker/lease settings;
- IB connection settings;
- enabled Strategy Deployments and their versions;
- Environment and Execution Book settings.

FastAPI retains only read-side SQL settings and the report token. SPX calculation thresholds must eventually be removed from FastAPI configuration after cutover.

## Non-goals

- Live broker order placement.
- A YAML or SQL rule language for arbitrary strategies.
- Cross-strategy capital optimization.
- Rewriting SPX research rules during migration.
- Optimizing META thresholds on the same research sample.
- Deleting legacy data or URLs.
- Making FastAPI a callback target for the runtime.
