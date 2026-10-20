# Checkpoint 03 — causal feature panels and first fixed screens

**Live-state correction:** checkpoint-05 found 40 existing enabled old-version `LIVE_MANUAL` deployments/notification schedules in SQL. This was not caused by the new research outputs. No live state was changed.

**Superseded for the combined family:** see `checkpoint-04.md` and `fixed_hypothesis_screen_v2/`. The original combined-family zero counts resulted from an availability-check bug, not the data. Single-feature scores are unchanged.

## Data integrity first

A serious replay defect was confirmed and its source code was corrected:

- 286/286 finalized old replay outcomes match NQMAIN, not the intended ticker. Old PF/win-rate and sector/technology conclusions are invalid for stock/ETF performance.
- Generic GEX outcomes now resolve TradePlan EXECUTION or deployment EXECUTION/SUBJECT roles and fail closed if no binding exists, rather than silently falling back to NQMAIN.
- Historical outcome database rows were not changed. A corrected SQL BACKTEST replay has not been run.
- Research bar times now remain New York wall time; the false UTC localization is removed.
- Label builder now requires the exact scheduled D1 07:30 bar and uses XNYS session offsets for exits. It does not substitute a later available bar.
- Independently validated all corrected August research labels against raw SQL price bars: 10,591/10,591 entries match; D1 10,591/10,591, D3 10,422/10,422, D5 10,250/10,250 resolved returns match. No exit after cutoff.

Tests: collecting strategy-runtime suite **119 passed, 1 skipped**; multisource outcome/time/technical/option pure tests **14 passed**; new Python research scripts compile.

## Feature panel work

### Technical OHLCV

From `StockDB_US.StockData.PriceHistory` through cutoff:

- 180 symbols requested (145 with >=120 quote observation days plus the corrected August universe).
- 156 had daily history; 63,056 feature rows.
- Causal technical panel includes SMA/EMA levels and slopes, normalized MA distance, RSI 7/14/21, MACD histogram, ATR/realised volatility, Bollinger %B/location/bandwidth, prior rolling highs/lows, prior day/week/month pivots, confirmed three-right-bar pivots, gap, relative volume, VWAP distance, OBV and slope divergence.
- Confirmed pivots are timestamped at confirmation, not backdated. Prior levels exclude current/future bars.
- Five synthetic causality/indicator tests pass.

### Option quotes

From `StockData.OptionDelayedQuote_V2`, `ObservationDate <= 2026-08-31`:

- 180 symbols processed, 180 with quote-date records; 30,533 trading-session symbol/date feature rows after filtering non-XNYS observations.
- 145 symbols have >=120 observed quote days by the cutoff; 133 >=180; 7 >=208. The operator's approximately 140 symbols with >208 dates includes later Sep/Oct data; only 7 meet 208 by the frozen cutoff. Shorter histories are retained.
- 494 non-session symbol/date observations were excluded from trading-session features and saved for investigation. They cluster on 2026-04-03, 2026-06-19 and 2026-07-03.
- SPXW had 16,212 duplicate contract rows on a non-session date; no duplicate OptionSymbol/date rows remained after the non-session filter. Source/revision cause remains unresolved.
- Features cover call/put volume and OI, VOI/put-call ratios, valid-denominator IV/spread/Greek aggregates, expiry buckets, near-expiry shares, and prior-only ranks/changes.
- SQL source-row checks confirmed no duplicate OptionSymbol rows across sampled ordinary META dates. No broad duplicate existed after session filtering in the generated coverage panel.

### Joined research panel

- 10,591 corrected label rows, 87 symbols, 443 columns after joining technical/options/GEX features.
- Option IV/OI values available for 10,136/10,591 labels (about 95.7%).
- This remains the 87-symbol GEX-feature universe, not yet a full 145-symbol option-only trade universe.

## First fixed-hypothesis screen

Before calculating results, `fixed_hypothesis_screen/hypotheses.jsonl` recorded 62 fixed condition/direction tests:

- technical-only: MA/trend, RSI, Bollinger location/bandwidth, MACD, support/resistance, pivots, causal divergence, confirmed pivots, volume breakouts;
- option-only: volume, OI, VOI, put/call, IV, near-expiry mix, spread/liquidity, gamma and vega activity;
- combined technical/GEX/options conditions and broad VIX/QQQ context.

The screen produced 2,232 evaluation rows across 3 horizons, 3 chronological splits and 4 cost cases. At 25 bps round trip:

- **No condition qualifies for promotion.** Only two D5 screens exceeded N>=100 train/N>=30 validation, positive mean and PF>1.2 in both train and validation: high OI + LONG and above-prior-month-pivot + LONG. Both failed final research tail PF (0.94 and 0.75 respectively).
- Lower Bollinger %B <=0.10 LONG D5: train PF 1.15/mean +0.30%, validation PF 0.91/mean -0.20%, final PF 5.63/mean +6.28%. This directly fails train/validation confirmation; do not claim a proven lower-band edge.
- RSI14<=30 LONG D5: train PF 1.52, validation PF 0.46, final PF 4.15. Again inconsistent; not a usable rule.
- High option OI-rank LONG D5: train PF 1.46, validation 1.29, final 0.94.
- High option IV-rank LONG D5: train 0.98, validation 1.67, final 0.97.
- High option spread-rank LONG D5: PF 1.18/1.31/1.34 across train/validation/final, but final PF falls to 1.22 without SNDU and 1.07 after removing the five largest ticker contributors. Concentration-sensitive; candidate for a new, frozen follow-up, not promotion.
- ~~The eight technical+GEX/option conjunctions had no validation signals~~. This was a bug; their corrected v2 results are in checkpoint 04 and do not qualify for promotion.

All results are per-instance signal statistics, not portfolio results; 50 bps sensitivity, nested outer-fold validation, family-level multiplicity correction and ticker-held-out robustness remain future work. The final chronological segment is a research tail, not an untouched forward test; the inspected Sep/Oct period is not clean validation.

## Artifacts

- `research_corrected/eligible-outcomes.csv`, `research_corrected/all-candidates.csv`, `research_corrected/best-by-ticker.csv`
- `august-label-audit.csv`
- `option-quote-universe-coverage-through-cutoff.csv`
- `intraday-30m-coverage-through-cutoff.csv`
- `technical_features/causal-technical-features.csv`, `technical_features/feature-dictionary.csv`, `technical_features/price-history-coverage.csv`
- `option_features/option-daily-features.csv`, `option_features/option-daily-coverage.csv`, `option_features/excluded-non-session-observations.csv`
- `multi-source-feature-panel.csv`, `multi-source-feature-coverage.csv`
- `fixed_hypothesis_screen/hypotheses.jsonl`, `split-manifest.json`, `fixed-screen-results.csv`
- `first-screen-analysis.md`

## Next bounded work

1. Extend raw label/execution validation to the 90 symbol 30-minute universe (only 42 have >=120 30-minute dates through cutoff). A separate D1 09:30/daily-open family may expand beyond that, but must use an explicitly different entry convention and costs.
2. Reconcile old BACKTEST rows only by an isolated new replay identity; never mutate old finalized outcomes. Verify each source manifest symbol after any new replay before summarizing.
3. Run a new registered round for spread/OI/GEX-volatility interactions, stronger per-ticker/sector leave-out, family-level correction and nested rolling folds. The current final tail is now consulted and cannot be reused as untouched validation.
4. Profile and incorporate other promising database sources (OptionTrade/OptionTradeSideInference, SignificantOptionTrade, GEX/DEX walls, OptionFlowContractDaily, underlying volatility, breadth/sector flows, events) after availability/semantics audit. Do not claim these have been tested yet.
5. No descriptor generation, SQL provisioning, schedules, notifications or live activation until fresh forward validation and explicit review.
