# OOS technology and volatility analysis

## Scope

This is diagnostic analysis of the frozen `frequency_pct <= 25%` basket over 2026-09-01 through 2026-10-15. It does not promote a rule or alter the validation contracts.

## Findings

A rough technology/semiconductor group (excluding ETFs) produced:

- 69 finalized signals
- 53.6% win rate
- 0.325% mean directional return
- 1.36 profit factor

The non-technology remainder produced 106 finalized signals, 61.3% wins, 1.065% mean return, and 2.87 PF. Technology was weaker, but not uniformly unusable.

META is the dominant concentration: 24 of the 69 technology signals. Removing META diagnostically raises technology PF from 1.36 to 2.20. Removing META, AMD, and MU raises it to 2.65. These are not removal recommendations because they use the validation window.

## Volatility evidence

The weak names were not failing during a high-VIX regime:

- All 31 finalized events for META, MRVL, AMD, and MU occurred with VIX <= 20.
- `GEX_HighVolatility` was false for all 31 events.
- This argues against a simple broad-VIX filter as the explanation.

Asset-level Bollinger bandwidth was more informative:

| OOS subset | N | Win rate | Mean return | PF |
|---|---:|---:|---:|---:|
| Entire capped basket, lower bandwidth | 139 | 62.6% | 1.14% | 3.19 |
| Entire capped basket, higher bandwidth | 36 | 41.7% | -0.64% | 0.54 |
| Weak tech names, lower bandwidth | 15 | 60.0% | 0.58% | 1.87 |
| Weak tech names, higher bandwidth | 16 | 31.3% | -1.73% | 0.15 |

The threshold here is the median OOS bandwidth and is diagnostic only. It must not be used to retune the current validation period.

## Interpretation

The likely issue is not simply “technology does not work.” The evidence is more consistent with:

1. concentrated META exposure;
2. subject-level expansion/contraction and gap risk not captured by VIX;
3. D5 continuation/reversal behavior changing during the OOS regime;
4. correlated technology and semiconductor exposure.

META's signal direction was SHORT, and the later sequence included several adverse multi-day moves. AMD and MU have too few observations to support a conclusion.

## Decision

Do not delete technology packets based on this OOS sample. For the next pre-cutoff research pass:

- test subject-level bandwidth/realized-volatility gates;
- test a volatility-scaled D5 exit and MAE stop using 30-minute paths;
- cap correlated semiconductor/technology exposure;
- evaluate META separately because it dominates the group sample;
- require confirmation on a fresh forward period before promoting a tech-specific filter.

Source snapshot: `oos-volatility-feature-snapshot.csv`. Detailed trade data: `oos-backtest-frequency-capped-221-trades.csv`.
