# 2026-09-01 through 2026-10-15 OOS diagnostics

## Scope and data status

The database replay was checked against the 58 new `GEX_*_AUGUST_2026_BEST` packet deployments. The reported totals reconcile exactly:

- 1,681 observations/signals
- 350 actionable signals
- 286 finalized outcomes
- 64 pending outcomes
- 55.94% win rate
- 0.4606 percentage-point mean directional return
- 1.5941 profit factor

The 64 pending outcomes are all actionable signals dated 2026-10-12 through 2026-10-15. They are primarily D3/D5 outcomes waiting for their terminal exit bars. The aggregate OOS result is therefore provisional until those outcomes are finalized.

The six incomplete packet coverages are data-availability issues, not losses: SPXU, MOD, COHR, IGV, S, and TXN. The replay correctly retained those blocked dates as evidence rather than converting them to losses.

## What the OOS result says

The decline from the pre-cutoff research ledger is real in the current sample, not just a reporting arithmetic issue:

| Metric | Research through 2026-08-31 | OOS finalized | Change |
|---|---:|---:|---:|
| Weighted win rate | 66.35% | 55.94% | -10.41 percentage points |
| Weighted mean return | 2.4167% | 0.4606% | -1.9561 points |
| Profit factor | 2.7546 | 1.5941 | -1.1605 |

The OOS mean remains positive, but the edge is materially weaker and should not be treated as stable production evidence yet. The 58 strategy results are also correlated and overlapping; 286 finalized outcomes are not 286 independent bets.

### OOS segmentation

| Segment | N | Win rate | Mean return | Profit factor |
|---|---:|---:|---:|---:|
| D1 | 3 | 66.7% | 0.2714% | 3.15 |
| D3 | 24 | 50.0% | -0.2571% | 0.71 |
| D5 | 259 | 56.4% | 0.5293% | 1.68 |
| LONG | 168 | 52.4% | 0.6236% | 1.90 |
| SHORT | 118 | 61.0% | 0.2286% | 1.25 |

D3 is currently the weakest horizon, but its sample is small. D5 provides almost all of the evidence and should be examined separately rather than pooled indiscriminately.

### Signal-frequency diagnostic

Frequency bins use the frozen pre-cutoff candidate frequency, so this is a diagnostic segmentation rather than a new OOS-fitted rule:

| Candidate frequency | Finalized N | Win rate | Mean return | Profit factor |
|---|---:|---:|---:|---:|
| <=15% | 22 | 50.0% | 0.5881% | 1.89 |
| 15%–25% | 153 | 59.5% | 0.7995% | 2.14 |
| 25%–35% | 58 | 55.2% | 0.1840% | 1.26 |
| >35% | 53 | 49.1% | -0.2679% | 0.76 |

This supports keeping a 15%–25% preferred frequency range. It does not justify changing the existing contracts using this OOS window; doing so would contaminate the validation.

## Likely causes of decay

1. **Multiple-testing selection bias.** The top candidate per ticker was selected from many rule/horizon/direction combinations. The pre-cutoff ledger therefore contains winner's-curse estimates.
2. **Regime change.** The OOS period contains different volatility, index, sector, and trend conditions from the research period. The predicates are mostly subject-only and do not consistently gate on market regime.
3. **Horizon mismatch.** D3 candidates underperformed in this sample while D5 candidates carried the aggregate result.
4. **Portfolio construction.** Equal per-signal aggregation allows high-frequency and correlated instruments to dominate. The current report is an instance-weighted result, not a capital-weighted portfolio result.
5. **Data coverage.** Six packets missed part of the requested window because the source-readiness gate could not prove a complete causal input set. This is correctly fail-closed but reduces coverage.
6. **Costs are zero.** The gross OOS result does not include spread, fees, slippage, or ETF-specific execution friction. Adding costs will reduce the edge, especially for frequent and leveraged instruments.
7. **Pending-tail bias.** The latest 64 signals are not yet in the finalized denominator. They must be finalized before treating the OOS result as complete.

## Recommended improvement plan

### First: finish and freeze this validation

- Rerun the outcome worker after the D3/D5 bars through 2026-10-15 are available.
- Keep the 2026-09-01 through 2026-10-15 results immutable as a validation report.
- Do not select thresholds, remove symbols, or change exits using these outcomes.
- Preserve the remaining 2026-10-16 through 2026-10-31 period as a clean confirmation window if possible.

### Second: rerun research only through 2026-08-31

Use a nested walk-forward process:

- Expand the pre-cutoff source history as far back as reliable SQL coverage allows.
- Use rolling train/validation/final slices rather than one global top-row selection.
- Select rules inside each training window; use the next window only for validation.
- Require positive expectancy and PF stability across multiple subperiods, not only the aggregate.
- Apply a multiple-testing penalty or deflated-performance ranking.
- Prefer 15%–25% frequency; review or reject candidates above 30% unless the rule is exceptionally stable.
- Treat D3 as a separate family and require stronger evidence before selecting it.

### Third: add causal information available in StockDB_US

Candidate feature families to test without future leakage:

- `Analysis.GEX_Features`: VIX, NASDAQ, Gold, BTC, RSI, GEX z-score/percentile, GEX volatility, price trend, Bollinger state, MACD, and swing flags.
- `Transform.OptionGEXChangeCapitalType`: capital-type share and option-count changes, GEX concentration, call/put activity imbalance, and causal prior ranks.
- `StockData.PriceHistoryTimeFrame`: overnight gap, 30-minute opening range, ATR/realized volatility, volume shock, VWAP distance, and path-based adverse/favorable excursion.
- Benchmark context: SPY/QQQ trend, volatility, and relative subject performance; sector ETF context where available.
- `StockData.OptionDelayedQuote_V2`: point-in-time OI/volume/quote features using `ObservationDate` as authoritative, `CreateDate` only as ingestion audit, `LastTradeTime` in the source US timezone, and the known Sydney-time OI availability gate. Do not use a quote row before that gate is satisfied.

### Fourth: improve portfolio decision rules

Research and backtest a portfolio layer separately from the signal layer:

- cap concurrent positions;
- de-duplicate correlated ETFs and leveraged products;
- use volatility/risk-parity sizing rather than equal signal weighting;
- cap exposure by sector and direction;
- measure portfolio return, drawdown, turnover, and worst loss path;
- model realistic costs and slippage by symbol class.

### Fifth: test exits without contaminating the current OOS window

Through the August cutoff, compare fixed D3/D5 close exits with:

- D1/D3/D5 selection by regime;
- ATR-based stop and time exit;
- adverse-excursion stop rules;
- partial exit plus trailing remainder;
- opening-range or VWAP failure exits.

Every exit variant must be chosen only from pre-cutoff data and then tested on a new untouched forward window.

## Decision

The immediate best improvement is not to add more indicators blindly. It is to reduce selection bias, finish the pending outcomes, separate D3 from D5, control high-frequency candidates, and evaluate a causal market-regime and portfolio-risk layer. The OOS result is still positive, but it is not strong enough to activate all 58 strategies as if they were equally reliable.
