# Stage 1 data audit — BLOCKED on outcome identity

**Date:** 2026-10-18 (workspace clock)  
**Research cutoff:** 2026-08-31 for model development  
**Mode:** SQL SELECT only; no database writes, production provisioning, deployment, notifications, or broker actions.

## Executive finding

The existing 58-packet historical replay's stock/ETF outcomes are **not outcomes for the packet's subject symbols**. The generic outcome worker fell back to `NQMAIN.US` when replay signals had no TradePlan `ExecutionInstrumentCode`. Independently reconstructed raw returns from NQMAIN match every finalized replay return, while raw subject-symbol returns match none.

- Frequency-capped replay: **175/175** finalized returns match NQMAIN within 0.0001 percentage points; **0/175** match the corresponding stock/ETF.
- Full 58-packet replay: **286/286** finalized returns match NQMAIN within tolerance; **0/286** match the corresponding stock/ETF.
- Confirmed source path: `C:/Repo/stocks_collecting/src/strategy_runtime/outcomes/worker.py`, `_load_bars`, initializes `instrument = candidate.execution_instrument_code or "NQMAIN.US"`. Replay-generated signal rows have no TradePlan execution instrument; the outcome candidate consequently uses NQMAIN for all 52 observed subject symbols.
- Raw outcome manifests for ADBE replay rows explicitly contain `symbol: NQMAIN.US`, `entry_price` near 30,000, and no TradePlan execution binding.

This invalidates interpretation of the previously reported **OOS PF 2.11 / 58.29% win rate** as stock/ETF strategy performance. It also invalidates technology-specific weaknesses, ticker-level rankings, frequency-filter conclusions and comparisons based on these replay outcomes. They describe NQMAIN outcomes attached to unrelated stock signals—not those stocks' returns. Preserve prior files as historical artifacts, but mark their subject-equity conclusions **INVALID / DO NOT USE**.

## Independent audit method

Added `backend/tools/multisource_research/audit_oos_outcomes.py`. It:

1. Reads the immutable prior event CSV.
2. Fetches raw `StockData.PriceHistoryTimeFrame` rows for each actual subject symbol, plus NQMAIN, using symbol-specific SQL and bounded date ranges.
3. Uses the repository's XNYS `USCashCalendar` to compute next-session D1 entry and D1/D3/D5 exit session.
4. Selects first same-session bar at/after 07:30 and final bar before scheduled cash close; calculates raw and direction-adjusted returns from the source Open/Close.
5. Separately compares each stored event return against reconstructed NQMAIN return.

Artifacts:

- Capped audit: `reconciled-events.csv`, `outcome-audit-metadata.json`
- Full 58 audit: `full-58-audit/reconciled-events.csv`, `full-58-audit/outcome-audit-metadata.json`
- Four pure unit tests: `backend/tools/multisource_research/test_outcome_audit.py` (**4 passed**).

The database timestamp column has no timezone type metadata. Raw 04:00 premarket through 19:30 records and runtime behavior support interpreting its values as New York wall-clock time. The audit records this assumption explicitly.

## Second independent issue: August discovery labels used the wrong entry bar

`backend/tools/us_gex_sql_research.py` and `backend/tools/all_us_gex_discovery.py` call `tz_localize("UTC").tz_convert("America/New_York")` on SQL `TimeIntervalStart` values that are stored/consumed as New York wall-clock timestamps. This shifts intraday selection by four/five hours. Their computed “07:30 ET” entry selection corresponds to a raw ~11:30 ET bar during the sampled dates, not the actual 07:30 ET bar.

Direct StockDB_US checks for D0 2026-08-03 / entry 2026-08-04:

| Symbol | Research `entry_price` | Raw 07:30 ET Open | Raw 11:30 ET Open |
|---|---:|---:|---:|
| META.US | 583.25 | 579.50 | 583.25 |
| AMD.US | 519.27 | 509.20 | 519.27 |
| AMAT.US | 544.49 | 540.20 | 544.49 |
| MU.US | 895.18 | 868.00 | 895.18 |

This is a source-label/convention defect, not evidence of a strategy edge. Since the original candidate search used these labels, the 58 candidate selection, frequency measurements, historical performance ledgers and generated contract performance claims must be regenerated from corrected labels before they are used for strategy research. Existing packets and archives remain immutable; create a new archive only after corrected research and review.

## Additional scope correction: quote coverage

The prior OptionDelayedQuote_V2 run processed the `distinct-stocks.csv` universe that currently contains **58 rows**. Its “58/58 coverage” refers only to those selected candidate symbols. It did **not** test the broader list of approximately 140 instruments with 208+ quote-observation dates supplied by the operator. Therefore:

- the claim that all 140 instruments have been tested is false;
- prior OptionDelayedQuote_V2 screen results are at most exploratory on a 58-symbol GEX-selected subset;
- expand profiling and testing to the operator-provided broad universe, plus all eligible source-supported symbols, after the outcome/entry-label defect is corrected.

The earlier option aggregation also requires a feature audit: weighted IV/Greek numerator/denominator consistency, snapshot deduplication and contract-history semantics need correction/verification before screens are reused.

## Decision and blocked work

**Initial audit Gate A: FAIL.** Do not implement feature discovery, train models, generate new contracts or draw performance conclusions using the old labels/outcomes.

### Follow-up remediation status

The execution-symbol fallback and local-time label defects were addressed in research/runtime code and the corrected August label output was re-audited. See `checkpoint-02.md` and `checkpoint-03.md`: all corrected resolved August labels match raw bars, while old replay rows remain invalid and untouched. Stage 2 temporary feature panels and a fixed, exploratory 62-condition screen have since been run; they do not promote a strategy. SQL replay rows were not rewritten or re-created.

Next required actions:

1. In the strategy-runtime repository, fix or isolate the historical replay outcome instrument binding so each GEX packet resolves its own SUBJECT/EXECUTION symbol when TradePlan is absent. Keep SPX proxy behavior intentional and separately tested. Read that repository's local instructions before changing it.
2. Create fresh, isolated BACKTEST replay deployments/run IDs; do not mutate/finalize over the old rows. Independently verify raw subject-symbol bar manifests and sample prices before computing any aggregates.
3. Correct the research extract's `TimeIntervalStart` timezone interpretation. Rebuild eligible outcomes using exact D1 07:30 and scheduled D1/D3/D5 closes, with missing bars blocked rather than shifted.
4. Regenerate the complete 90-symbol August universe research from corrected labels; preserve the 2026-08-31 cutoff and reject labels whose exit bars are after cutoff.
5. Audit candidate selection and descriptors from scratch; old strategy winner selection and claimed performance must not be carried forward as verified evidence.
6. Rerun the broad option coverage profile for the operator's approximately 140 symbols. Use distinct observation dates and valid-data counts, not just presence counts.
7. Re-run Stage 1 verification and obtain Gate A PASS before Stage 2 feature construction or any signal testing.

## Reproduction

Using the collecting repository virtual environment and backend `.env`:

`C:\Repo\stocks_collecting\.venv\Scripts\python.exe C:\Repo\stocks_au_web\backend\tools\multisource_research\audit_oos_outcomes.py`

Full replay:

`C:\Repo\stocks_collecting\.venv\Scripts\python.exe C:\Repo\stocks_au_web\backend\tools\multisource_research\audit_oos_outcomes.py --events C:\Repo\stocks_au_web\backend\data\strategy_runtime\20261018\oos-backtest-events.csv --output-dir C:\Repo\stocks_au_web\backend\data\strategy_runtime\20261018-b-research\full-58-audit`

The audit command intentionally exits 2 when any subject-symbol result differs from the saved replay return; here that is a required failure signal.
