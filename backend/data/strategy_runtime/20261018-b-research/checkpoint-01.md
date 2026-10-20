# Checkpoint 01 — Stage 1 data audit: BLOCKED

## Work completed

- Preserved source files; created separate `backend/data/strategy_runtime/20261018-b-research/` output.
- Independently reconstructed 175 finalized capped-basket OOS outcomes and all 286 finalized outcomes from raw subject-symbol 30-minute bars and XNYS sessions.
- Compared both against raw NQMAIN bars.
- Traced the source fallback in `C:/Repo/stocks_collecting/src/strategy_runtime/outcomes/worker.py:182`.
- Confirmed the August candidate-research entry-time conversion defect in `backend/tools/us_gex_sql_research.py:206,237` and `backend/tools/all_us_gex_discovery.py:83`.
- Added reusable read-only audit script and four pure unit tests; all four tests pass and both new Python files compile.
- Confirmed prior OptionDelayedQuote_V2 run processed 58 symbols, not the operator's broader ~140-symbol set.

## Gate results

| Check | Result |
|---|---|
| Full OOS finalized rows audited | 286 |
| Raw subject bar windows fetched | 52 symbols, 38,751 bars |
| Saved returns matching raw subject | 0 / 286 |
| Saved returns matching NQMAIN within 0.0001 pp | 286 / 286 |
| Capped finalized rows audited | 175 |
| Capped returns matching raw subject | 0 / 175 |
| Capped returns matching NQMAIN within tolerance | 175 / 175 |
| Stage 1 unit tests | 4 passed |
| Stage 1 schema-wide profiling | Not completed (inventory exists; broader profiling deferred) |
| Outcome labels trustworthy | **No** |
| Gate A | **FAIL — STOP** |

## Consequence

The previous capped PF 2.11, 58.29% win rate, stock/sector breakdowns, technology/volatility conclusions, and all OOS claims from these outcome tables are not valid subject-equity performance evidence. The packet replay measured NQMAIN price moves for unrelated symbols because a BACKTEST replay has no TradePlan execution binding and the outcome worker defaults to NQMAIN.US.

The existing 58 selected strategies also used research returns whose “07:30 ET” entry selection maps to the SQL 11:30 ET bar after a false UTC localization. The earlier packets and associated historical-performance summaries therefore need fresh corrected discovery, not a cosmetic metric update.

## Next bounded stage

Do **not** advance to technical/option hypothesis screening yet. First fix/contain the execution-symbol fallback in an isolated historical replay path, create new replay identities, rerun subject-symbol outcomes, fix the research label timezone mapping, regenerate pre-cutoff eligible labels, and independently revalidate. No prior database rows are overwritten. No production/runtime activation is authorised.

## Artifacts

- `stage-1-data-audit.md`
- `reconciled-events.csv` (capped)
- `outcome-audit-metadata.json` (capped)
- `full-58-audit/reconciled-events.csv`
- `full-58-audit/outcome-audit-metadata.json`
- `backend/tools/multisource_research/audit_oos_outcomes.py`
- `backend/tools/multisource_research/test_outcome_audit.py`
- `reproducibility-manifest.json`
