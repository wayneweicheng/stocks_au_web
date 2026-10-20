# First fixed-threshold technical/option screen — exploratory results

**Erratum (checkpoint 04):** The first-run combined-family result is **invalid**. Its availability check looked for a literal column named `BB20PercentB+GEX_ZScore` (and analogous composite names), so all eight conjunctions were incorrectly scored as unavailable. The corrected, separately saved `fixed_hypothesis_screen_v2/` is the authoritative output for those eight. Other single-feature rows are unchanged. See `checkpoint-04.md`; neither run is fresh validation.

## Experiment protocol

- Input labels are from `research_corrected/eligible-outcomes.csv`, independently reconciled to raw subject bars (10,591 entry rows; resolved D1/D3/D5 labels on/before cutoff only).
- Fixed, pre-registered set: **62** condition/direction tests: 30 technical, 20 option, 8 technical/GEX/option conjunctions, 4 broad-market context tests. These counts are code registry IDs; horizons and cost cases create dependent repeated evaluations, not independent tests.
- Standalone technical and option conditions do not require an existing GEX trigger. Combined conditions are included as separate hypotheses.
- Same symbol/date panel and direction-specific matched-coverage baseline; entry D1 exact 07:30 ET, scheduled exits D1/D3/D5.
- Global chronological split on 215 distinct D0 dates: train up to 2026-04-22, validation begins 2026-04-23, final research tail begins 2026-06-30 and ends 2026-08-28. Cross-boundary outcome labels are purged by the exit date.
- Costs: 0/10/25/50 bps round trip. Table below uses **25 bps**. Final research tail is report-only; no threshold was chosen from it.
- Results are per-signal instance statistics, not capital-weighted portfolio returns. Signals overlap, and ticker/date dependence remains. No multiple-testing correction or independent forward confirmation is claimed.

Artifacts: `fixed_hypothesis_screen/hypotheses.jsonl`, `split-manifest.json`, and `fixed-screen-results.csv` (2,232 rows).

## Main result: no robust edge qualifies yet

The descriptive final research tail contains some striking observations, but the fixed tests do **not** show consistent train/validation/final performance:

| Prespecified condition, D5 | Train PF / mean | Validation PF / mean | Final-tail PF / mean | Interpretation |
|---|---:|---:|---:|---|
| Close at/below lower Bollinger %B 0.10, LONG | 1.15 / +0.30% | 0.91 / -0.20% | 5.63 / +6.28% | Large tail rebound; no validation support. Not an established lower-band edge. |
| RSI14 <=30, LONG | 1.52 / +0.79% | 0.46 / -2.18% | 4.15 / +5.89% | Reverses between validation and final; not robust. |
| RSI14 >=70, SHORT | 0.72 / -0.92% | 0.65 / -1.59% | 2.80 / +2.42% | Final tail contradicts earlier folds. |
| Above prior completed month pivot, LONG | 1.24 / +0.46% | 1.47 / +1.21% | 0.75 / -0.68% | Trend/context effect reverses in final tail. |
| High prior-60 OI rank, LONG | 1.46 / +0.86% | 1.29 / +0.69% | 0.94 / -0.20% | Modest early effect fails final-tail PF. |
| High IV rank, LONG | 0.98 / -0.05% | 1.67 / +2.04% | 0.97 / -0.12% | Validation-only rise, fails train and final. |
| High vega activity rank, LONG | 1.19 / +0.40% | 1.57 / +1.65% | 0.78 / -0.61% | Validation-only rise, fails final. |
| High spread-rank, LONG | 1.18 / +0.33% (N=816) | 1.31 / +0.72% (N=594) | 1.34 / +0.80% (N=818) | Most consistent initial lead: mean exceeds same-coverage baseline by +0.09/+0.23/+0.65 pp. But final-tail PF falls to 1.22 without SNDU and 1.07 without the five largest ticker contributors. This is concentration-sensitive and only an exploratory follow-up, not a promoted edge. |

Means and PF are computed net of the same flat 25 bp charge per trade. Final-tail bands and RSI statistics must not be used to claim a forward-confirmed strategy; they are subject to broader prior research inspection and are one fixed-threshold screen among many.

### Bollinger clarification

This experiment separately tests **Bollinger location** (`%B <= 0.10`) and **bandwidth**. It gives no train/validation evidence that a lower-band touch should be bought. It does not establish a predictive effect for lower-band proximity. Future research should test competing reversion versus breakdown-continuation hypotheses, but these data already belong to development after this look.

### Combined screens

~~The eight combined conditions had zero qualifying signals in validation.~~ **Withdrawn:** that was a scorer availability bug, not insufficient coverage. In the corrected v2 D5 validation run, all eight conditions have nonzero signals (1–256; see v2 CSV); seven have at least 20. The lower-band/high-IV conjunction has 35 validation signals, PF 1.47 net 25 bps, but train PF 1.17 with 200 signals and the final tail is already inspected. No combined result is validated or promoted.

### Option features

The option-only conditions are tested on the 87-symbol corrected-label universe and its available quote intersection; this is smaller than the 180-symbol feature cache and should not be described as a 180-stock predictive backtest. Quote features exist for a wider universe, but executable labels are not yet generated for every ticker. OI, IV and Greek families produced positive validation summaries that fail in the final tail. The spread-rank lead is concentration-sensitive. No option-family edge is promoted. No current packet was modified.

## Current decisions

- **Do not promote any of these 62 conditions.** One fixed chronological validation split plus a final tail is not enough for the project’s candidate gate, and multiple tests were run.
- The strongest next *research* leads are: Bollinger lower-tail rebound as a competing reversion/breakdown test; option OI/IV/vega interactions with trend and volatility; and confirmed pivot/support behavior. These are leads for a new registered round, not recommended trading rules.
- Add at least two additional rolling outer windows or freeze a prospective future validation. Do not reuse the inspected September/October 2026 outcomes as clean confirmation.
- Validate path-dependent exits and portfolio effects separately. Signal-level PF is not portfolio PF.

## Limitations and next work

1. One global 60/20/20 split is exploratory, not nested multi-fold walk-forward. Although labels crossing split boundaries were purged, adjacent same-ticker signals and cross-sectional market dependence remain.
2. The D1/D3/D5 rows share dates and holdings; 62 x 3 x 3 x 4 output rows are heavily dependent. Apply family-level multiplicity controls and date-block/bootstrap uncertainty in the next confirmatory round.
3. Costs are flat sensitivity only (25 bp is not ticker-specific). Build real spread/slippage and premarket feasibility scenarios.
4. No portfolio sizing, concurrent positions, caps, cash, drawdown or exposure accounting is included.
5. The first run found option holiday-date observations on 494 symbol-dates (Good Friday, Juneteenth, early July holiday context); they were excluded from trading-day features and saved in `option_features/excluded-non-session-observations.csv`. SPXW had 16,212 duplicate contract rows on a non-session date; after calendar filtering, no duplicate OptionSymbol-date rows remained in the output coverage check. Investigate cause and `CreateDate`/revision semantics before using those dates.
6. 180 quote symbols were processed (145 have at least 120 distinct quote days through cutoff), versus only 87 symbols with the corrected GEX-universe execution-label panel. Generate and independently audit underlying 07:30/close labels for more of the 30-minute-coverage universe before claiming broad option-only results.
7. `Analysis.GEX_Features.Is_Swing_*` was not used in this first technical set; upstream future-confirmation semantics still need audit. No discretionary trendline or option-wall signal has been tested yet.
