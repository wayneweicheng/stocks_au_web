# US multi-source edge discovery — research handoff

## Goal

Discover reproducible, causal, executable US stock/ETF edges using the full useful data available in **StockDB_US**, rather than restricting discovery to existing GEX packets. Investigate technical price/volume structure, option GEX/DEX and walls, delayed option quotes, option trades/flows, market/sector conditions, and other relevant database sources. Establish which families add incremental value, on which instruments and regimes, after costs and portfolio constraints.

The executor implements features and runs hypotheses; the planning model supplies the design and reviews checkpoint evidence. No current live packet is changed by this plan.

## Documents

1. [Research plan](research-plan.md): governance, data audit, feature design, experiments, backtests, acceptance criteria, deliverables.
2. [Hypothesis register](hypothesis-register.md): competing hypotheses, causal features, controls, falsification criteria.
3. [Execution prompts](execution-prompts.md): master delegation prompt and staged prompts suitable for a lower-cost coding/research model.

## Start here

Give the executor the **Master prompt** in `execution-prompts.md`. Execute stages in order. Do not combine a failing data audit with an automatic strategy search. Stage completion means durable evidence, tested code, and explicit limitations, not merely a narrative update.

## Fixed conventions

- Database: `StockDB_US`; SQL research is read-only.
- Development cutoff: **2026-08-31**, including all required exit bars on/before that date.
- September–October 2026: reserved validation history. Much of September 1–October 15 has already been inspected. It is no longer a pristine holdout for ideas motivated by those results. Do not load it during new development; use it only as a locked, explicitly previously-inspected diagnostic if authorised.
- Delayed options: operator states D0 `ObservationDate` snapshots are available the next US trading day around **07:00 New York market time**, before the 07:30 ET candidate entry. Use this as the operating assumption, record it, and verify actual readiness at runtime. Do not reject the whole dataset because a publication timestamp is absent.
- Historical prices, ranks, pivots, divergences, model transforms, and membership must be causal at the decision timestamp.
- Current <=25% candidate-frequency basket is a **reference comparator**, not a proven universally optimal threshold. Do not retune it against the inspected OOS period.
- Broker execution remains **HARD_DISABLED**; no production provisioning, notifications, schedules, or strategy changes.

## Output location

New implementation and experiment artifacts belong under:

`backend/data/strategy_runtime/20261018-b-research/`

New reusable code belongs under a clearly named research package, for example `backend/tools/multisource_research/`, with tests alongside the project’s established test layout after inspection. Do not overwrite `20261018`, `20261018-a`, or the original packets.

## What this handoff does not claim

The earlier PF 2.11 and volatility/option findings are provisional historical reports, not verified proof of a tradable edge. The first stage must independently audit source symbols, price joins, horizons, and aggregation. No new tests or new performance claims are made by these planning documents.
