# Trading Signal Operations

Trading Signal Operations turns completed market observations into versioned signals, optional paper/manual trade plans, immutable reports, and user notifications while preserving research provenance.

## Language

**Strategy Runtime**:
The top-level `strategy_runtime` application that claims due work and coordinates Strategy Implementations, persistence, lifecycle, reports, and notification publication.
_Avoid_: FastAPI service, scheduler loop

**Strategy Implementation**:
Strategy-local code that reads its sources, calculates one versioned decision, proposes lifecycle changes, and renders its report without owning persistence or delivery.
_Avoid_: Runtime, job, plugin when no plugin mechanism exists

**Report Catalog**:
The read-only FastAPI Module that lists and serves committed Report Snapshots from SQL Server.
_Avoid_: Report generator, strategy API

**Source Adapter**:
A Strategy-owned boundary that converts one provider/database source into validated, provenance-bearing facts.
_Avoid_: Generic data loader when source semantics differ

**Instrument**:
An index, equity, ETF, future, or other market instrument that has a defined role in a strategy.
_Avoid_: Stock when referring to all supported instrument kinds, ticker as the whole identity

**Instrument Role**:
The purpose an Instrument serves in a Strategy Deployment, such as Subject, Source, Proxy, Execution, or Benchmark.
_Avoid_: Ticker type

**Strategy**:
A family of decision rules that interprets Observations and may propose a Trade Plan.
_Avoid_: Signal, job, report

**Strategy Version**:
An immutable combination of decision rules, thresholds, and execution policy.
_Avoid_: Configuration revision when behavior changes without a new version

**Strategy Deployment**:
An enabled Strategy Version bound to Instrument Roles, an Environment, an Execution Book, and a Schedule.
_Avoid_: Strategy instance, job config

**Environment**:
The operating mode in which a Strategy Deployment runs, such as Backtest, Migration Shadow, Forward Paper, or Live Manual.
_Avoid_: Mode without qualification

**Observation**:
Completed source facts attributed to one market session and preserved with their provenance.
_Avoid_: Current data, row, snapshot when the market-date meaning is absent

**Signal**:
One Strategy Version's classification of one Observation, including direction, confidence, and actionability.
_Avoid_: Strategy, alert, trade

**Trade Plan**:
Persisted paper/manual intent describing a possible entry, management policy, and exit for an actionable Signal.
_Avoid_: Order, position

**Execution Book**:
The concurrency and capital scope within which Trade Plans may reserve or hold exposure.
_Avoid_: Global portfolio, singleton portfolio

**Trade Plan Event**:
An immutable lifecycle fact such as Planned, Entered, Take Profit, Stop Loss, Time Exit, or Cancelled.
_Avoid_: Mutable status update

**Strategy Run**:
One claimed evaluation, monitoring, summary, or correction operation identified by its scheduled effective time.
_Avoid_: Process invocation, retry attempt

**Run Attempt**:
One worker's attempt to complete a Strategy Run.
_Avoid_: Strategy Run

**Report Snapshot**:
An immutable HTML publication describing the committed result of a Strategy Run.
_Avoid_: Latest report, generated page

**Notification Event**:
A durable, idempotent request to communicate one committed lifecycle fact to a recipient.
_Avoid_: Pushover call, alert row

**Signal Outcome**:
An append-only, provenance-bearing forward measurement of a Signal at a declared horizon, whether or not a Trade Plan entered.
_Avoid_: Trade result, when no entry occurred

**Correction**:
An explicit new revision produced because previously committed source facts or outputs were wrong.
_Avoid_: Retry, rerun

**D**:
The market session to which an Observation belongs.
_Avoid_: Processing day

**D1, D2, D3, D5**:
Subsequent exchange sessions relative to D, excluding weekends and market holidays.
_Avoid_: Calendar-day offsets, weekday offsets
