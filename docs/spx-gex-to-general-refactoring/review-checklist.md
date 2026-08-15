# Refactoring Review Checklist

Use this checklist after each task and for the final review. A checked box requires evidence, not an assertion.

## Repository safety

- [ ] The implementer recorded initial `git status --short` for both repositories.
- [ ] Unrelated user changes were preserved.
- [ ] The task did not implement scope assigned to a later task.
- [ ] `git diff --check` passes in every modified repository.
- [ ] No secret, token, connection string, or personal path was committed.

## Module ownership

- [ ] FastAPI does not import `strategy_runtime` or legacy SPX execution code after the relevant task.
- [ ] Strategy Implementations do not write SQL or call Pushover directly.
- [ ] Runtime callers do not calculate sessions, choose source Adapters, or construct idempotency keys.
- [ ] No runtime core branch checks for `SPX`, `META`, `QQQ`, `NQ`, or another specific Instrument.
- [ ] The database is the only runtime seam between repositories.
- [ ] `strategy_runtime` is installed as a top-level package from `src\strategy_runtime`, not nested under `stocks_collecting`.

## Domain invariants

- [ ] Strategy Versions are immutable.
- [ ] All market/session times are timezone-aware.
- [ ] D1/D2/D3/D5 are exchange-session offsets.
- [ ] Signal identity does not include classification.
- [ ] A Trade Plan has at most one ENTER and one terminal event.
- [ ] Opposing Signals do not auto-reverse active plans.
- [ ] Execution Book occupancy is enforced transactionally.
- [ ] Normal retries and corrections have different, tested semantics.
- [ ] D1/D2/D3/D5 Signal Outcomes are versioned, causal, and independent of whether a plan entered.

## SQL Server

- [ ] Production writes target `StockDB_US.[TradingSignal]`, not SQLite.
- [ ] Unique constraints enforce every documented idempotency key.
- [ ] Claims use atomic locking plus an expiring lease/fencing token.
- [ ] Mutable projections use `rowversion` or equivalent compare-and-set behavior.
- [ ] Observation, Signal/event, report, notification, and successful run status commit atomically.
- [ ] Schema deployment is idempotent and non-destructive.
- [ ] Queries are parameterized.
- [ ] HTML and JSON size limits are explicit.

## Reports and website

- [ ] Reports are immutable and content-hashed.
- [ ] A normal retry returns an existing report.
- [ ] A correction creates a new report with `SupersedesReportID`.
- [ ] FastAPI list/get/latest paths perform only SQL reads.
- [ ] The HTML endpoint enforces the report token when configured.
- [ ] Date filters are server-side and inclusive.
- [ ] Legacy SPX report URLs continue to resolve.
- [ ] Pushover links target immutable report IDs.

## Notifications

- [ ] The Notification Event and queue row have deterministic unique keys.
- [ ] Queue rows are claimed atomically.
- [ ] Two workers cannot send the same claimed row concurrently.
- [ ] Safe retry failures are distinguished from ambiguous delivery.
- [ ] `DELIVERY_UNKNOWN` is never automatically retried.
- [ ] Existing announcement and non-strategy notifications still work.
- [ ] WATCH, ENTER, TP, SL, TIME EXIT, CANCELLED, and DATA ERROR behavior is covered.

## SPX migration

- [ ] All Task 01 characterization fixtures pass against the new Implementation.
- [ ] Production and shadow classifications persist as a pair.
- [ ] No-lookahead thresholds exclude the current Observation.
- [ ] SPXW/NQ/QQQ Instrument Roles remain distinct.
- [ ] Exact action-bar and cash-close rules are preserved.
- [ ] Existing HTML historical evidence and archive behavior are preserved.
- [ ] SQLite migration count/hash reconciliation passes.
- [ ] Dual-run differences are zero or explicitly approved.

## META

- [ ] META uses one Strategy with ordered classifications, not separate runtime jobs per classification.
- [ ] The canonical META contract has no unresolved source/finality/timeframe decision and passes contract validation.
- [ ] GEX is aggregated to one row per Observation before lag calculations.
- [ ] Causal percentile windows exclude the current Observation.
- [ ] Percentage-point versus rank units and every equality boundary match the normalized reference.
- [ ] Data gaps persist research metrics but suppress entry.
- [ ] Only the three approved strong classifications create entry plans.
- [ ] D1 and D2 exits use exchange sessions.
- [ ] Early-close exit/reminder times derive from the official session close.
- [ ] No unvalidated TP/SL was added to D2 strategies.
- [ ] Missing/stale entry and exit quotes fail according to the bounded lifecycle policy.
- [ ] D1/D2/D3/D5 outcomes are collected for strong/watch Signals, including non-entered Signals.
- [ ] Auto-entry does not place a broker order.

## Verification evidence

- [ ] Unit-test command and result are included.
- [ ] SQL integration-test command and result are included where relevant.
- [ ] Frontend lint/build results are included where relevant.
- [ ] Failure-path tests were run, not only happy paths.
- [ ] A rollback or disable procedure exists for operational changes.
- [ ] The handoff lists all modified files and database objects.
