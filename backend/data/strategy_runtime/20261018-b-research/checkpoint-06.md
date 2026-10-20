# Checkpoint 06 — frozen 40 retrospective Sep 1–Oct 15 stock-price replay

**Decision: the frozen 40 do not show a profitable aggregate signal edge in this already-inspected period under the stated model.** This is a research-only, read-only StockDB_US replay; no live deployments/schedules/reports were edited. The old 40 `LIVE_MANUAL` notification-enabled deployments remain active pending an explicit operator decision (see checkpoint-05).

## Contract and audit

- Exact **same 40 ticker/direction/D3–D5/trigger definitions** as the runtime-aligned review ZIP (`baseline_40_runtime_aligned_review_packets_2026-10-18-b.zip`). No post-window selection or threshold change.
- D0 runs over 2026-09-01 through 2026-10-15 XNYS sessions only. Source inputs loaded via SQL SELECT as D0 + 60 prior complete capital/GEX rows and classified with the current `CapitalTypeGexImplementation` runtime code. No future D0 source rows used for a predicate. Source revisions/first-ready timestamps are not proven point-in-time immutable; source swing-flag confirmation remains unverified.
- Entry is D1 **07:30 ET 30M bar open** (optimistic for a 07:30 evaluation). Exit is scheduled D3/D5 **exact last regular-session 30M close** for each stock/ETF, half-day calendar aware. No fallback to next available entry/exit bar. If scheduled D1 or exit is beyond Oct 15, the outcome is PENDING, not a zero/loss/win. Missing exact bars block or remain pending. No signals entered manually, no broker calls.
- Every **165** finalized signal outcome was independently re-queried from raw subject `.US` SQL price bars by exact symbol and entry/exit timestamp: **165/165 matched**, across 35 tickers, 150 D5 and 15 D3; no mismatches. `independent-raw-bar-audit.csv/json` stores entry/exit prices, timestamps and per-trade returns.
- All **221** ticker/D0 signal identities match the old archived 221-signal replay *exactly*, but old replay returns were sourced from NQMAIN and are invalid. Identity parity **does not** rescue old performance. The old replay's pending/finalized state was evaluated with later knowledge; this new replay cuts off resolved labels at Oct 15.

## Profit factor and costs (instance weighted)

| D0 period | Total signals | Finalized by Oct 15 | Pending (exit / entry) | Net PF at 25 bps | Net mean/trade | Wins on finalized |
|---|---:|---:|---:|---:|---:|---:|
| September | 115 | 115 | 0 / 0 | **0.71** | −0.588% | 45.2% |
| Oct 1–15 | 106 | 50 | 39 / 17 | **0.91** | −0.172% | 42.0% |
| Combined | **221** | **165** | **39 / 17** | **0.77** | **−0.462%** | **44.2%** |

No exact entry/exit bar was missing for the 221 signaled D0 dates; pending October entries/exits simply lie beyond the explicit Oct 15 label cutoff. Oct 1–15's 50 resolved signals are an **early-maturing subset**, not the eventual performance of all 106 October signals.

Cost sensitivity on the same 165 finalized signals: **PF 0.89 at 0 bps**, **0.77 at 25 bps**, **0.67 at 50 bps**, **0.50 at 100 bps**. The 25-bp same-runtime-ready **unconditional frozen direction/horizon** comparator had combined PF **1.01** on 987 resolved symbol/date observations; it is not a practicable all-stocks portfolio.

## Concentration / admission diagnostics

- The META SHORT (`PriceDistSMA50Pct >= 2.0`) produced **23 finalized signals**, −3.73% net mean per instance, PF **0.11**; its simple sum of equal-instance net percentage-point returns was −85.8 pp. Without META, basket PF would be **1.04** on 142 signals, but this is a **post-hoc influence diagnostic, not an authorized filter**. Excluding SQQQ's unverified swing flag gives PF 0.77 on 164, essentially unchanged.
- One-position-per-ticker admission (D1 premarket to D3/D5 close, deterministic date/ticker sorting) reduces 165 finalized signals to **88**, with instance-weighted PF **1.03**, mean +0.050% after 25 bps. It excludes pending later-period positions from selection and is **not** marked-to-market NAV or an executable portfolio simulation.
- Do not choose winning tickers or remove losing ones based on this inspected period. The pre-cutoff research-selected 40 already carried multiple-selection risk. This Sep/Oct window had also been inspected in earlier conversations, so these are **not pristine independent validation results**.

## Files and reproduction

- `frozen_40_sep01_oct15_replay/run-manifest.json` (frozen ZIP SHA, dates, costs, causal/source/cutoff assumptions)
- `candidate-dates-and-labels.csv` (all 40 x session readiness, including NO_SIGNAL), `signal-ledger-including-pending.csv` (221 signals), `results-by-period-and-cost.csv`, `results-by-ticker.csv`, `source-coverage-by-symbol.csv`
- `independent-raw-bar-audit.csv/json`, `one-ticker-overlap.json`, `concentration-sensitivity.json`, `legacy-signal-parity-not-outcome-parity.json`
- Tools: `backend/tools/multisource_research/backtest_frozen_40_sep_oct.py`, `audit_frozen_40_sep_oct_prices.py`, `report_frozen_40_sep_oct.py`. Backtest refuses to overwrite an existing replay; SQL calls are SELECT only.
- Tests: research **30 passed** including calendar/half-day/exact bar/missing/pending checks; collecting strategy runtime **119 passed, 1 skipped**. No broker execution or production SQL writes.

**Do not treat PF 0.77 as a complete capital-weighted P&L**: signals overlap, 25 bps is flat, D1 07:30 opening fills and shorts may be infeasible, and 56 signals have no resolved label by the cutoff. Nevertheless, the historical stock-return evidence materially contradicts the old proxy-based PF 2.11 claim. The right next step is to review live notification risk and either shadow-test a new frozen design prospectively or stop these 40; no Sep/Oct-driven tuning masquerading as fresh OOS.
