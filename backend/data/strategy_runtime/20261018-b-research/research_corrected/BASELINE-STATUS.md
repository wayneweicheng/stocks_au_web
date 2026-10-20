# Corrected August GEX discovery baseline — awaiting multi-source research

**Later audit:** See `../checkpoint-05.md`: the earlier 40-packet archive's labels are invalid; a distinct runtime-aligned review ZIP now exists. A read-only SQL audit also found 40 old-version notification-enabled live-manual deployments and 80 enabled schedules, contradicting earlier non-activation assumptions. No live changes were made.

This is a fresh StockDB_US-only research extract built after correcting local-bar interpretation **and** scheduled-session mapping. Development uses completed data through 2026-08-31; September/October were not queried for candidate selection. It is not a live strategy or approved packet archive.

## Construction

- Analysis.GEX_Features August universe: 90 symbols; `_VIX.US` excluded from tradable candidate discovery.
- 30-minute price coverage: 88 symbols.
- Corrected eligible outcomes: **10,591 rows across 87 symbols** after requiring an exact next-XNYS-session 07:30 ET bar.
- Resolved labels on or before cutoff: D1 10,591; D3 10,422; D5 10,250. No label exits after 2026-08-31.
- Original broad GEX discovery family found 3,078 screening candidates; 60 symbols had at least one candidate. This family remains an exploratory comparator, not the final model search.

## Independent raw-bar reconciliation

`backend/tools/multisource_research/audit_august_labels.py` independently queried 367,229 subject-symbol 30-minute bars and checked all 10,591 eligible rows:

- 10,591/10,591 entry dates, exact 07:30 ET bars and entry prices matched raw SQL bars.
- D1: 10,591/10,591 label returns matched within 0.00011 percentage points.
- D3: 10,422/10,422 resolved labels matched.
- D5: 10,250/10,250 resolved labels matched.
- Resolved D3/D5 labels after the research cutoff: zero.
- No D0 was shifted to a later available data-bar date if its scheduled D1 entry bar was missing.

Audit artifact: `../august-label-audit.csv`.

## Important separation

The previous replay event-ledger results remain invalid as stock/ETF OOS results: 286/286 finalized rows matched NQMAIN returns, not their subject symbol. A code fix now resolves generic GEX replay execution symbols from EXECUTION/SUBJECT instrument roles and refuses an unbound generic GEX instrument rather than falling back to NQMAIN. The old finalized rows remain untouched and invalid. A corrected fresh replay would require new isolated BACKTEST identities and explicit execution approval; it has not been run.

This corrected August label set is suitable as a **research input**, after the separate source-feature causal audit. No refreshed contract packets or forward-performance claims have been created.
