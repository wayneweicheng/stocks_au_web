# Checkpoint 02 — outcome remediation and corrected August label gate

**Later live-state correction:** checkpoint-05 read-only SQL audit found 40 old-version `LIVE_MANUAL` deployments and 80 enabled schedules with notifications enabled. Statements here that the 40 were not activated describe an earlier assumption, **not the observed current state**. No live SQL changes were made.

## Completed

### Historical replay source binding

In `C:/Repo/stocks_collecting/src/strategy_runtime/outcomes/worker.py`:

- Backtest candidates now resolve a missing TradePlan execution code from `StrategyInstrumentRole` EXECUTION first, then SUBJECT, for generic `GEX_*` packet strategies.
- A generic GEX outcome with no instrument binding now fails closed instead of defaulting to `NQMAIN.US`.
- Bare packet symbols are normalised to `.US`; SPX proxy behavior remains explicit.
- Fixed an existing package import cycle via lazy backtest exports so the outcome tests can be collected.

Tests: `tests/strategy_runtime` **119 passed, 1 skipped**. This is code/test only. No SQL replay was re-run and no prior outcomes were changed. The old replay evidence remains invalid.

### Corrected August research label generation

In `backend/tools/us_gex_sql_research.py` and `backend/tools/all_us_gex_discovery.py`:

- SQL `TimeIntervalStart` is interpreted as New York wall time rather than falsely localized as UTC.
- Entry uses the exact scheduled next-XNYS-session 07:30 ET bar; missing D1 entry does not shift to a later session.
- D1/D3/D5 exits use scheduled XNYS session offsets from D0 and the final bar before the scheduled cash close, rather than the nth future date with an available entry bar.
- Labels whose exit is after 2026-08-31 remain missing.

New research-only archive: `research_corrected/`. The original 20261017/20261018 archives remain unchanged.

### Independent label audit

`backend/tools/multisource_research/audit_august_labels.py` checked the corrected output against raw subject-symbol SQL bars:

- 10,591 eligible D0 rows across 87 symbols.
- 10,591 exact 07:30 entry dates/prices match.
- D1 10,591/10,591; D3 10,422/10,422; D5 10,250/10,250 resolved returns match raw labels within floating-point tolerance.
- No resolved exit after cutoff.

### Option quote data breadth

A distinct-observation-day profile of `OptionDelayedQuote_V2` through **2026-08-31** found:

- 956 symbols with any records;
- 165 symbols with at least 60 distinct observation dates;
- 145 with at least 120 dates;
- 133 with at least 180 dates;
- 7 with at least 208 dates.

Artifact: `option-quote-universe-coverage-through-cutoff.csv`. The operator's approximately 140 symbols with >208 days appears to include September/October collection, which is beyond the development cutoff and already inspected. The prior OptionDelayedQuote_V2 feature test only covered the 58-row selected-candidate CSV; it did not process this wider universe.

## Remaining gates/blockers

- Old 175/286 finalized OOS replay returns all match NQMAIN and none match their subject symbols. They cannot be used for ticker/strategy/regime conclusions. A corrected replay with new isolated BACKTEST identities has not been executed.
- The whole-database source catalogue exists, but semantic/availability profiling across every object is not complete.
- Quote deduplication, valid-value-weight denominators and Greek/IV semantics need a formal data test before any performance screen; the previous quote aggregate is not promoted as trusted.
- Corrected candidate discovery output itself is not an independent performance conclusion. The original simple screening procedure used per-ticker chronological candidate splits and needs replacement with the plan's global purged walk-forward design.

## Decision

**Corrected August stock-price labels pass independent raw-bar reconciliation.** Proceed to Phase B temporary feature construction and data semantics audits on these verified labels. Do not use the old OOS event PF 2.11 or the earlier tech/volatility conclusions. Do not regenerate/activate packets or run broad candidate performance selection until the causal feature and nested-split gates are implemented.
