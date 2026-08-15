# Task 14: Implement META GEX/PCR as the Second Strategy

## Objective

Implement META GEX/PCR V1 as a strategy-local package using the common runtime, SQL Server store, Task Scheduler heartbeat, generic Pushover pipeline, and generic website report catalog. This task proves that a new strategy can be added without reintroducing Instrument-specific runtime/web architecture.

## Prerequisites

- Tasks 07, 12, and 13 are complete.
- [meta-gex-pcr-reference.md](meta-gex-pcr-reference.md) is copied into the canonical contract location and passes `IMPLEMENTABLE` validation.
- The exact SQL source shape/timeframe code and IB market-data entitlement are verified in a non-production environment.
- META remains `FORWARD_PAPER`; no live-order authorization exists.

## Repository and required files

Repository: `C:\Repo\stocks_collecting`

Create:

```text
src\strategy_runtime\strategies\meta_gex_pcr\__init__.py
src\strategy_runtime\strategies\meta_gex_pcr\implementation.py
src\strategy_runtime\strategies\meta_gex_pcr\features.py
src\strategy_runtime\strategies\meta_gex_pcr\classification.py
src\strategy_runtime\strategies\meta_gex_pcr\lifecycle.py
src\strategy_runtime\strategies\meta_gex_pcr\sources.py
src\strategy_runtime\strategies\meta_gex_pcr\report.py
src\strategy_runtime\strategies\meta_gex_pcr\backtest.py
tests\strategy_runtime\meta_gex_pcr\fixtures\
tests\strategy_runtime\meta_gex_pcr\...
```

Add one declarative registry/descriptor entry and deployment seed. Do not add META branches to runtime, SQL procedures, CLI, notification handler, FastAPI, or React.

## Source Adapter

Implement a private SQL source Adapter that reads `StockDB_US.Transform.OptionGEXChangeCapitalType` for `ASXCode='META'` and aggregates to one row per Observation date before lagging or percentile calculations.

- Do not use the existing view's per-CapitalType lag as final strategy input.
- Parameterize Instrument and date bounds.
- Use bound SQL parameters.
- Cast before `ABS`/sum to prevent integer overflow.
- Return the raw source manifest and deterministic hash.
- Validate four required types, Close/VWAP consistency, numeric finiteness, row counts, latest expected date, and taxonomy.
- Validate the authoritative upstream completion/finality marker defined by the canonical contract; four present Capital Types alone do not prove completion.
- Retrieve only the bounded history needed to produce 60 eligible prior Observations plus enough leading data to calculate their changes; do not scan the full table every minute.
- Inspect the query plan. Add a checked-in source-table index beginning `(ASXCode, ObservationDate)` with suitable includes only if measured need and repository schema conventions justify it.

Implement separate private Adapters for fresh IB last-trade quotes and completed price bars. No Adapter may place an order.

## Features and classification

Implement the formulas, shared causal cohort, empirical tie rule, data-quality outcomes, exact boundaries, and first-match priority in the normalized reference. Keep calculation functions pure.

- Persist full-precision metrics and round for display only.
- Store percentage changes as percentage-point values and ranks as `0..1`.
- Preserve both research classification and operational Action when data quality downgrades an otherwise actionable result.
- Include a no-lookahead test that mutates D1/future source rows and execution quotes while leaving D's decision unchanged.
- Generate one Signal per Strategy Version/Observation; classification is output, not identity.

Do not “improve” thresholds from the current database or optimize against the same research sample.

## Strategy registration and deployment seed

Seed:

- Strategy Definition `meta-gex-pcr`;
- immutable Version `v1.0.0-forward-paper` / Implementation Key `meta-gex-pcr-v1`;
- a META-scoped `FORWARD_PAPER` Execution Book;
- SUBJECT/SOURCE/EXECUTION roles from the reference;
- evaluation at 03:30 ET with the documented due window;
- optional 03:25 data readiness check that cannot create a second daily Signal;
- entry check at 04:00 ET;
- one-minute active-plan monitoring through scheduled exit;
- D2 reminder and exit work;
- outcome collection for D1/D2/D3/D5.

Use calendar/session offsets rather than hard-coded dates. A Strategy Schedule representation may use multiple named schedule rows, but canonical Run IDs and event keys must remain deterministic.

Keep the deployment disabled until all acceptance evidence and explicit activation approval are complete.

## Lifecycle

- Only the three strong classes may create a plan.
- Use one normalized share and a META strategy-scoped occupancy key in V1.
- Entry requires valid/non-gap data, `WAITING_ENTRY`, no occupied META book, and a fresh IB last trade in the 04:00-04:05 ET window.
- Repeated invocation produces exactly one `ENTER` event and notification.
- Strong Bearish Continuation uses the exact short TP/SL/time-exit rules.
- Strong Bullish Confirmation and Strong Bearish Divergence use reminder/time exit on D2 and no signal-specific TP/SL.
- Session close drives normal/early-close exit times.
- Missing entry quote cancels after the due window; missing exit quote leaves a visible overdue active plan and data-error escalation.
- An opposite actionable Signal creates an informational event/notification, never reversal.
- No IB order method may be imported/called from lifecycle code.

## Notifications and HTML

Return Notification Intents and Report Documents to the runtime. Do not call Pushover or construct public links in META code.

Implement:

- daily evaluation report for all classifications;
- DETECTED/WATCH report and message as applicable;
- ENTER report;
- TP, SL, scheduled-exit, D2 reminder, opposing-Signal, cancellation, and data-error lifecycle reports.

Use the supplied examples as content guidance but render from structured domain state. Include exact metrics, quality, source date, Direction/Action, schedule, research caveats, and plan status. Escape all source content. Every delivered event must reference its immutable report.

The existing generic `/trading-signal-reports` page must display META automatically from catalog metadata. Add no META frontend component.

## Forward outcomes

Collect `SignalOutcome` rows for every strong/watch Signal at D1, D2, D3, and D5 using the exact research 04:00 ET completed-bar reference, including close, applicable directional return/MFE/MAE, source manifest, and finalized time. For Direction NONE, store raw returns/excursions and null directional fields. Outcomes are collected even when data quality prevented entry so research can distinguish Signal behavior from execution availability.

Persist entered-plan outcomes separately in plan/report metadata, including exact entry/exit, exit reason, realized directional return, and plan-window MFE/MAE.

Do not automatically alter P50/P40/P65 from forward outcomes.

## Tests

Implement every mandatory fixture in the normalized reference. In addition cover:

- source SQL aggregate output against a synthetic database result;
- source query is parameterized and bounded;
- exact SQL fixture with multiple BC/BP/SC/SP rows aggregates before lag;
- registry discovers META without runtime Instrument branching;
- in-memory full workflow from D evaluation through each entry/exit class;
- SQL integration idempotency for duplicate evaluation, entry, reminder, and exit workers;
- notification queue/report transaction and immutable URL;
- no queue row for info-only classes;
- no plan for warning/blocked/watch classes;
- correction creates a superseding report but no automatic plan by default;
- generic catalog API returns META without backend changes;
- synthetic META item renders in the existing frontend without frontend changes.

Backtest tests must share forward feature/classification functions and clearly identify the stop-first same-bar convention.

## Activation gates

Before enabling forward paper:

- all contract/fixture/unit/integration tests pass;
- historical calculation reproduces the supplied research case counts/results within documented differences, or every difference is resolved;
- manual inspection of at least five source dates confirms aggregation, dates, Close, and ranks;
- an IB quote dry-run confirms qualified META contract, timestamp, freshness, and extended-hours availability without placing an order;
- one synthetic end-to-end run proves Pushover message and immutable report link;
- SQL query timing is acceptable and does not block collectors;
- the deployment and queue target are verified as forward paper/manual;
- explicit user approval is obtained to enable the Deployment.

After activation, observe at least five trading sessions before treating operations as stable. This is operational validation, not validation of the edge.

## Acceptance criteria

- META is implemented entirely as a Strategy Implementation plus descriptor/configuration/tests.
- Exact normalized rules and edge cases pass.
- Data is aggregated before lag and all ranks are causal/current-row-excluded.
- No live order can be submitted.
- Strong actions are idempotent paper/manual lifecycle events; watch/info never enter.
- Reports and Pushover links flow through generic infrastructure.
- D1/D2/D3/D5 outcomes are retained with provenance.
- SPX and existing collectors remain unaffected.

## Out of scope

- Live broker orders or capital sizing.
- Threshold optimization.
- Arbitrary TP/SL for D2 Signals.
- Automatic reversal.
- New META-specific FastAPI routes or frontend pages.
- Treating the small research samples as production performance guarantees.

## Verification

```powershell
Set-Location C:\Repo\stocks_collecting
poetry run python -m strategy_runtime.contracts.validate_contract docs\strategy-runtime\contracts\meta-gex-pcr.md
poetry run pytest tests\strategy_runtime\meta_gex_pcr -q
poetry run pytest tests\strategy_runtime -q
poetry run mypy src\strategy_runtime\strategies\meta_gex_pcr
poetry run python -m strategy_runtime health --json
git diff --check

Set-Location C:\Repo\stocks_au_web\backend
..\venv\Scripts\python.exe -m unittest tests.test_trading_signal_reports

Set-Location C:\Repo\stocks_au_web\frontend
npm run lint
npm run build
```

## Required handoff evidence

- Validated filled contract/descriptor and source-query contract.
- Rule/threshold fixture matrix with exact expected outputs.
- Historical research-reproduction comparison.
- Sanitized SQL plan/timing and five-date source audit.
- IB extended-hours quote dry-run proving no order call.
- End-to-end report/queue/Pushover-link evidence.
- Import/registry diff proving no META condition was added to core/web code.
- Explicit statement that the Deployment remains disabled or the approval record used to enable it.
