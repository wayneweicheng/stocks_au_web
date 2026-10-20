# CRWD August 2026 Best GEX Candidate

## Identity and change rationale

- Strategy Code: `GEX_CRWD_AUGUST_2026_BEST`
- Version Code: `1.0.0-production`
- Implementation Key: `gex-crwd-august-2026-best`
- This packet contains the top-scoring candidate for `CRWD` from the complete August 2026 GEX universe.

## Research provenance

Research uses StockDB_US through **2026-08-31**. September and October 2026 are untouched and reserved for forward validation.

## Instrument Roles

- SUBJECT: `CRWD.US`

## Observation and source provenance

Capital-type data: `Transform.OptionGEXChangeCapitalType`; GEX features: `Analysis.GEX_Features`; execution bars: `StockData.PriceHistoryTimeFrame`.

## Formulas, units, null behavior, and lag ordering

Required inputs: `SCShareRank60`. Causal ranks exclude D0 from their prior reference history. Null, stale, or non-finite inputs produce `NOT_READY`.

## Data validity and fail-closed policy

Incomplete BC/BP/SC/SP data, fewer than 60 prior valid observations, or missing execution bars blocks evaluation.

## Causal history and windows

The candidate was researched with a chronological 60/20/20 split through the August cutoff.

## Ordered Signal rules

| Classification | Direction | Confidence | Action |
|---|---|---|---|
| `CRWD_AUGUST_2026_BEST_SIGNAL` | SHORT | MEDIUM | PLAN_ENTRY |
| `DATA_ERROR` | NONE | NONE | NONE |
| `NO_SIGNAL` | NONE | NONE | NONE |

Trigger: `SCShareRank60 &gt;= 0.80`

## Operational decision and notification policy

Notification-only. Broker execution is hard-disabled.

## Schedule, calendar, and catch-up

Evaluate at 07:30 America/New_York on the next valid US session after D0.

## Lifecycle and occupancy

One actionable signal per D0; scheduled D5 holding period.

## Execution price and outage behavior

Entry is the D1 07:30 ET 30-minute bar Open; missing bars remain pending.

## Report contract

Reports and paper plans may be created for actionable signals; no broker order is created.

## Forward validation and governance

Forward validation must preserve September and October 2026 as out-of-sample data.

## Failure, retry, and correction policy

Data readiness failures remain pending; deterministic evaluation errors are recorded as DATA_ERROR.

## Deterministic acceptance fixtures

See `historical-performance.json`, `historical-instance-ledger.csv`, and `strategy_logic.py`.

## Deployment and rollback

The descriptor is notification-only and must be independently reviewed before provisioning.

## Unresolved decisions and declarations

The candidate is research-derived and not a claim of proof.
