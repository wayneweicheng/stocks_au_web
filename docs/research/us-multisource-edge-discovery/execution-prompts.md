# Execution prompts for the implementation/research model

Use the master prompt first, then one stage per bounded execution context. These prompts delegate implementation and experiments, not live trading authority. No sub-agent facility is assumed; a human or orchestrator can run stages sequentially or in isolated workers with the stated dependencies.

## Master prompt — copy this into the executor

```text
You are the execution researcher/coding model for a US stock/ETF multi-source edge-discovery project.

Workspace: C:/Repo/stocks_au_web. Read applicable CLAUDE.md/AGENTS.md instructions. Read these documents COMPLETELY before implementing:
- docs/research/us-multisource-edge-discovery/README.md
- docs/research/us-multisource-edge-discovery/research-plan.md
- docs/research/us-multisource-edge-discovery/hypothesis-register.md
- docs/research/us-multisource-edge-discovery/execution-prompts.md

GOAL
Investigate useful StockDB_US data broadly and determine whether technical price/volume features, option GEX/DEX/walls, delayed option IV/OI/volume, option trades/flows, and market/sector context supply causal, incremental, executable edges. Do not constrain discovery to previously selected GEX triggers or tickers. Explore standalone technical-only, option-only, GEX-only, and combined models. Generate additional hypotheses from the source catalogue. Findings may be negative.

FIXED CONVENTIONS
1. SQL read-only. Do not change production, generate live packets, provision strategies, send notifications, activate schedules, or call brokers. Broker execution HARD_DISABLED.
2. Development feature/label cutoff: 2026-08-31; all exit bars must resolve by then. Do not query September/October for new research selection. Existing September 1–October 15 results were inspected and cannot be advertised as pristine validation for ideas inspired by them.
3. Operator states OptionDelayedQuote_V2 D0 ObservationDate data is available before the next US session, around 07:00 New York time. Include it actively; use that assumption explicitly and do not reject all quote data because publication timestamps are absent. Default evaluation/entry family is D1 07:30 America/New_York, with execution-latency sensitivity. No D1 full-session feature is available at that entry.
4. Keep original 20261018/20261018-a artifacts immutable. New outputs: backend/data/strategy_runtime/20261018-b-research/. Reusable new code may live under backend/tools/multisource_research/ with tests in a suitable inspected test layout.
5. The <=25% candidate-frequency basket is a fixed comparator, not a threshold to optimise using inspected OOS returns.
6. Handle .US symbols and embedded dots correctly. Verify raw source units, snapshot deduplication, causal timestamps and scheduled session horizons. Missing is not zero or a low-regime observation.

FIRST TASK
Perform Stage 0 and Stage 1 only. Do not run a massive feature search until independent source-price/outcome reconciliation passes. Prior files show suspicious repeated returns across different tickers; trace these to raw prices instead of assuming correctness or assuming a bug. Reproduce the old event metrics before treating them as benchmarks. If materially wrong, document/quarantine results and stop ranking.

WORKING METHOD
- Read metadata/schema/procedure lineage, profile indexed slices, cache immutable source extracts, use bounded SQL concurrency/timeouts, support resume.
- Use global chronological nested folds with purging of overlapping labels. Inner folds select candidates; outer dates evaluate the locked selection process.
- Pre-register hypotheses, all variants, costs, folds, entry/exit rules and trial budgets. Record failures and null findings.
- Build point-in-time technical features including MA distance/slope, RSI, Bollinger LOCATION and bandwidth, causal divergences/trendlines, prior-period pivots and support/resistance. Bollinger lower-band location is NOT the same as bandwidth.
- Test standalone signals and incremental additions using matched dates/coverage. Do not merely append filters to old winning GEX rules and call the old tails independent.
- Keep short-history data in explicitly exploratory/pooled arms. More than 200 quote dates is useful coverage, not automatically 200 independent executable trades.
- Costs, overlap policy, capital budgets and confidence intervals are required. A daily average of future returns is not a portfolio backtest.
- Default stages and approval gates are in the plan. A hard data defect stops the pipeline; tiny final samples never become production-ready by wording.

EACH STAGE MUST PRODUCE
1. Persisted code, tests and artifacts, with paths.
2. A checkpoint report listing actual work completed, row/date/symbol coverage, tests run, unresolved blockers and the next bounded stage.
3. A reproducible one-line command or small script. No secret values in logs. Do not claim completion for work only proposed.
4. An updated append-only experiment/status ledger.

Start now with Stage 0 and Stage 1. At the checkpoint report PASS/BLOCKED and wait for review before broad experimentation. Do not ask the user to suggest indicators one at a time; the research agenda is already supplied.
```

## Stage 0 — establish a safe, reproducible run

```text
Execute Stage 0 of docs/research/us-multisource-edge-discovery/research-plan.md.

Inspect git status and local repository instructions. Preserve unrelated changes. Record code/artifact hashes of previous inputs and create a NEW run directory under 20261018-b-research. Read backend/app/core DB access code and available environment variable names without printing values. Do not write SQL or live runtime state.

Create a checkpoint manifest with research cutoff, quote availability assumption, output root, prior-input references, inventory scope and run status. Include a read-only source-access helper with query timeout, bounded concurrency, snapshot cache/provenance and resume keys. Do not perform exhaustive data scans yet.

Deliver checkpoint-00.md, reproducibility-manifest.json, and exact commands. Report any dependency/environment blocker rather than silently substituting data.
```

## Stage 1 — inventory, source semantics and outcome audit

```text
Execute Phase A. Read research-plan.md sections 2–3 completely.

1. Account for every StockDB_US table/view in source-catalog.csv. Start with SQL metadata and local DatabaseSchema definitions. Classify useful candidates, duplicates, operational/sensitive objects, outcome-only/leaking sources, empty and unknown sources. No source is rejected solely because it is not GEX. Do not export sensitive contents.
2. Profile all potentially useful families using indexed pre-cutoff slices: keys, distinct dates, symbol coverage, nulls, revisions, units, availability and lineage. Build pre-cutoff versus total-coverage fields and quote/price/resolved-label intersections. Expand beyond 58 winners; verify long-history symbols from raw coverage.
3. Independently reconcile underlying price outcomes. Check at least 30 events, ten tickers and both directions/horizons present. Investigate identical cross-ticker return flags in the prior extract. Inspect source/execution bindings, entry/exit bars, SQL WHERE symbols, calendar and DST semantics.
4. Outcome reconciliation must expose exact entry/exit source records, not just match previously computed DirectionalReturnPct. Test missing 07:30/close bars and half days; do not shift horizons to available rows.
5. Test quote snapshot duplicates, weighting denominators, .US aliases, embedded-dot symbols, GEX/IV/Greek semantics, and missing flag handling. State unresolved point-in-time revisions explicitly.

Automated tests must cover symbol-specific price separation, direction arithmetic, horizon calendar, duplicate join multiplication, nulls, and quote deduplication. Identify sampled versus exhaustively checked properties.

Output data-audit-report.md, source-catalog.csv, coverage-by-source-symbol.csv, reconciled-events.csv, test code/results and checkpoint-01.md. Audit-only retrospective reconciliation may inspect named already-reviewed OOS records; do not use those records for fitting or new screening. New research extracts remain capped at August 31.

If a material outcome defect exists: preserve old data, describe impacted metrics, create a corrected research-only ledger, label old PF unverified/invalid as warranted, and STOP before ranking. Do not modify live runtime without separate authorisation. Otherwise report Gate A PASS and wait for review.
```

## Stage 2 — causal feature engineering

```text
Proceed only after Gate A passes. Execute Phase B using hypothesis-register.md.

Build tested temporary causal feature modules for:
A. MA/EMA distances/slopes/alignment, RSI and MACD.
B. Bollinger %B/location, ATR-normalised band distance, bandwidth/squeeze/expansion.
C. ATR/realised volatility, price-volume/VWAP, gaps and relative strength.
D. Prior rolling high/low support/resistance; daily/weekly/monthly classic pivots/CPR; deterministic trailing regression and confirmed-pivot trendlines; RSI/MACD/GEX divergence at confirmation time.
E. Delayed options: volume/OI/VOI, matched-contract changes, valid-weight IV, skew/term structure, DTE/moneyness buckets, spread/liquidity, well-defined Greek/exposure measures.
F. GEX/DEX, walls/flip, option trade/flow, market/sector/breadth and other promising sources catalogued in Stage 1.

Implement all feasible families; explicitly record NOT_IMPLEMENTED/BLOCKED features and why. Use verified source coverage rather than requiring the same long history for every source. Separate feature availability from label availability. Never use future-return fields or current-period future H/L in features.

Feature dictionary fields: name/version, source keys, formula/units, lookback/minimum history, available_at, decision_at, null/quality rule, cache hash, causal proof. Valid-quote denominator only for weighted metrics. Do not call weighted absolute Greeks dollar exposure without the necessary factors.

Tests: future-data perturbation invariance; truncated-versus-full-history equality at historical dates; known synthetic MA/RSI/ATR/Bollinger/pivot values; delayed pivot confirmation; snapshot duplication; missing IV/spreads; DST/session/half-day timestamps; stale and incomplete source rows. Keep later-entry intraday feature arms distinct.

Output feature-dictionary.csv, feature-coverage.csv, feature-audit.md, reproducible feature cache, tests and checkpoint-02.md. No performance search yet. Gate B requires causal tests to pass.
```

## Stage 3 — freeze hypotheses, baselines, and splits

```text
After Gate B, pre-register experiments from hypothesis-register.md and add justified catalogue-discovered ideas. Include opposing explanations, economic mechanism, controls, falsification, exact feature variants and trial counts. Design wide but bounded testing; do not presume all indicators help.

Use global chronological nested folds chosen on coverage, not returns. Set actual dates and label-overlap purges in split-manifest.json; include ticker/sector/inverse-ETF-family holdouts. If coverage is insufficient for three outer folds, downgrade the arm to exploratory rather than inventing observations. Fitted preprocessing and selection happen inside training.

Freeze the <=25% basket as a reference only. Baselines: unconditional matched long/short, simple trend/reversion, GEX-only, technical-only, quotes-only and wall/flow-only where feasible. New discovery must include symbols without an existing GEX packet.

Define a standalone arm AND an incremental-on-existing-trigger arm. Existing winner-trigger tails cannot be called independent. Compare at matched date/coverage intersection and separate all-available coverage results.

Budgets: maximum 2,000 initial pre-registered screen variants and 20 confirmatory shortlisted candidates. Freeze selection criteria, costs and provisional shadow-candidate gates before results. Count horizons/directions/thresholds/model hyperparameters as trials. Keep stochastic seeds and versions.

Output hypotheses.jsonl, split-manifest.json, experiment-plan.json, baseline-specifications.md and checkpoint-03.md. Do not consult outer fold results to tune the plan.
```

## Stage 4 — inner-fold discovery screens

```text
Execute only the registered inner-fold screens. Do not load reserved September/October data or expose outer outcomes during candidate selection.

Test technical-only, quote-only, GEX-only, wall/flow/context arms; then the pre-registered two-family interactions and combined models. Examine MA, bands, RSI, support/resistance/pivots, causal divergence/trendlines and option information rather than only old GEX-trigger filters.

Use transparent rule screens and regularised models first. Compare gross and net expectancy/PF plus risk, coverage and turnover. Perform matched-coverage controls and family ablation. Persist every failed/empty/insufficient trial. Short-history arms stay visible with appropriate labels.

Do not present the highest PF as the winner by itself. Freeze at most 20 candidates or selection procedures using the registered inner-fold criterion. If none qualifies, report none. Do not expand threshold grids after failure without a new registered round and an explicit trial-budget change.

Output experiments.jsonl, inner-results.csv, matched-coverage-comparisons.csv, rejected-hypotheses.csv, shortlist.json with configuration hashes and checkpoint-04.md. Outer outcomes remain unconsulted for shortlisting.
```

## Stage 5 — locked outer evaluation and incremental value

```text
Evaluate the frozen inner-selected procedure on chronological outer folds. Refit within the allowed training window of each fold without using its outer outcomes. Final pooled metrics concatenate disjoint outer test events; don't count the same trade from overlapping folds twice.

Compare all prespecified baselines/ablations on matched symbol/date/horizon/cost populations. Report effects by fold, ticker, direction, sector, volatility regime and source availability; include ticker/group-held-out transfer. Show positive and negative cases for hypotheses such as lower-band bounces versus continuation.

Use date/block bootstrap with at least the holding-horizon block length and cross-sectional joint resampling. Account for selection/multiple testing and report attempted trial counts. No tiny no-loss sample is a stable infinite-PF winner.

If outer findings inspire a new filter, record a new hypothesis; do not retune on the same outer outcomes and still call it OOS. Preserve all frozen configs and access history.

Output results-by-fold.csv, results-by-symbol.csv, results-by-family.csv, ablation-report.md, uncertainty-report.md, frozen-research-candidates.json and checkpoint-05.md. No production packets.
```

## Stage 6 — path exits, costs and portfolio feasibility

```text
Execute Phase E only on reconciled bars and prespecified candidates. Compare D1/D3/D5, ATR stops, completed-bar ATR trailing and structural/VWAP exits. MAE/MFE are outcome diagnostics, not future-known input features. Use conservative gap and stop/target ordering and explicit missing-bar status.

Reconstruct separately:
1. Independent signal tranches.
2. One position per ticker.
3. Maximum 1/3/5 D5 tranches per ticker with fixed capital/exposure budgets.

Control ticker/sector/correlated exposures. Pick tie-breaks from pre-decision information only. Do not recycle proceeds before close exits. Include premarket costs/latency, liquidity, fees and short borrow/financing. Compare fixed sizing with training-only volatility sizing under the SAME gross capital budget.

Produce per-tranche entries/exits, commissions/costs, reason, MFE/MAE, pending status, holdings, cash and daily marked-to-market NAV. Reconcile trade cashflows to portfolio P&L; daily averaging of forward returns is prohibited as a substitute.

Output trade-ledger.csv, portfolio-daily.csv, exit-comparisons.csv, cost-stress.csv, exposure-report.md, reconciliation-tests and checkpoint-06.md. Do not choose a live exit based on inspected September/October returns.
```

## Stage 7 — analyst synthesis, not another search

```text
Write the final analyst report from persisted evidence. Do not launch extra unregistered trials to manufacture a positive conclusion.

For each feature/source family explain:
- what was actually tested and the number of variants;
- effective pre-cutoff/outer coverage, unique dates/tickers and dependence;
- matched baseline and incremental net effect;
- fold/sector/ticker robustness and uncertainty;
- whether it helps entry, filtering, direction, exit, sizing, execution, or nothing yet;
- rejected ideas, contradictory evidence and data blockers;
- sample/collection value versus proven strategy value versus deployment readiness.

Provide ranked SHADOW_CANDIDATE / EXPLORATORY / INSUFFICIENT / REJECTED decisions using the frozen gates. Include source-data/label defects discovered and which earlier metrics must no longer be relied on. Do not claim lower-band alpha from bandwidth results.

Propose a frozen prospective validation specification and genuinely unconsulted future dates. Existing inspected September–October data is diagnostic, not pristine confirmation for ideas it inspired. Keep the operator's next-session quote availability convention explicit; don't turn limited timestamp metadata into a blanket reason to exclude useful options data.

Output final-analyst-report.md, candidate-decisions.csv, collection-priorities.md, next-forward-validation.md, reproducibility-manifest.json and checkpoint-07.md. No activation or new production descriptor packets unless separately authorised.
```

## Optional bounded worker prompts

These workers can run after their dependencies pass; none may choose performance thresholds using reserved outcomes.

### Source-catalog worker

```text
Catalogue the assigned StockDB_US schema/source family read-only. Follow research-plan.md Phase A. Inspect metadata, schema and upstream definitions, sample indexed slices and identify keys/units/timestamps/revisions/coverage/causal feature opportunities. Exclude sensitive operational contents. Output only assigned catalog/coverage/lineage artifacts. Do not rank strategies or change shared files owned by another worker.
```

### Technical-feature worker

```text
Implement the assigned technical hypotheses from hypothesis-register.md using the agreed canonical price/availability contracts. Build pure feature functions and causality/synthetic tests. Include Bollinger location distinct from bandwidth; support/resistance and pivots are historical-only; divergences and pivot trendlines are usable only after confirmation. Output code, feature dictionary rows, tests and a blocker list. Do not run unregistered parameter searches.
```

### Option-data worker

```text
Implement assigned delayed-quote/flow/wall hypotheses using the agreed source snapshot contracts. D0 quotes are assumed available before D1 07:30 ET. Validate deduplication, .US symbols, DTE/moneyness, IV/Greek units, matched-contract changes, valid-weight denominators and quote quality. Preserve short histories. Output code/tests/feature metadata; no strategy-promotion claims from aggregate PF.
```

### Independent audit worker

```text
Do not reuse computed return columns as ground truth. Independently reconstruct assigned events from raw symbol-specific entry/exit prices and canonical exchange sessions. Check joins, timing, directions, horizon boundaries, overlapping labels, missing bars and revisions. Read-only. Report discrepancies with source row keys and minimal reproducible examples; do not silently fix the shared ledger or consult future returns for feature design.
```

## Review prompt for the planning/senior model

```text
Review the executor's latest checkpoint against research-plan.md and hypothesis-register.md. Check outcome correctness, causal timestamps, split/selection leakage, symbol and snapshot joins, weighting/units, costs, overlap-capital accounting, small-sample claims and negative-results disclosure. Identify concrete blockers and approve only the next bounded stage. Do not accept numerical claims without matching artifacts and reproducible checks. Do not let an outer-test improvement be retuned on the same dates and remain labelled independent.
```
