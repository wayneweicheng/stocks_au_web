# QQQ Option-Flow Feature Calibration

This is a preliminary expiry-outcome calibration. It is descriptive, not a trading recommendation.
Only FULL_CHAIN rows with an exact underlying close on the expiry date are included.

- Outcome observations: **6219**
- Calibration-ready observations: **5726**
- Excluded for invalid implied move or gamma: **493**
- Observation range: **2025-06-03** to **2026-08-27**
- Pin candidate: `MaxAbsGammaStrike`
- Implied move: near-ATM call/put mid sum divided by spot

## Calibration summary

| Group | N | Inside implied move | Median actual move | Median implied move | Actual/implied move | Pin within 1% | Realized IV > implied IV |
|---|---:|---:|---:|---:|---:|---:|---:|
| ALL | 5726 | 63.33% | 2.42% | 3.55% | 0.761 | 21.32% | 25.18% |
| 01-05 | 936 | 61.00% | 0.93% | 1.20% | 0.800 | 47.01% | n/a |
| POSITIVE_GAMMA | 2807 | 62.99% | 2.20% | 3.22% | 0.764 | 25.94% | 25.95% |
| 06-10 | 1098 | 62.57% | 1.63% | 2.14% | 0.763 | 25.96% | 26.50% |
| NEGATIVE_GAMMA | 2919 | 63.65% | 2.67% | 3.93% | 0.757 | 16.89% | 24.45% |
| 11-30 | 1475 | 68.34% | 2.18% | 3.35% | 0.695 | 20.95% | 30.24% |
| 31+ | 2217 | 61.34% | 5.59% | 7.28% | 0.809 | 8.43% | 21.34% |

## DTE × gamma regime

This cross-tab is the primary diagnostic for deciding whether range and pin behaviour differs by gamma regime.

| Group | N | Inside implied move | Median actual move | Median implied move | Actual/implied move | Pin within 1% | Realized IV > implied IV |
|---|---:|---:|---:|---:|---:|---:|---:|
| 01-05 / POSITIVE_GAMMA | 464 | 61.85% | 0.82% | 1.13% | 0.762 | 54.09% | n/a |
| 01-05 / NEGATIVE_GAMMA | 472 | 60.17% | 1.05% | 1.35% | 0.822 | 40.04% | n/a |
| 06-10 / POSITIVE_GAMMA | 573 | 60.03% | 1.60% | 2.04% | 0.788 | 28.62% | 23.73% |
| 06-10 / NEGATIVE_GAMMA | 525 | 65.33% | 1.64% | 2.29% | 0.749 | 23.05% | 29.66% |
| 11-30 / POSITIVE_GAMMA | 763 | 64.88% | 2.21% | 3.21% | 0.752 | 25.69% | 27.13% |
| 11-30 / NEGATIVE_GAMMA | 712 | 72.05% | 2.10% | 3.53% | 0.630 | 15.87% | 33.57% |
| 31+ / POSITIVE_GAMMA | 1007 | 63.75% | 5.03% | 7.12% | 0.788 | 11.62% | 26.02% |
| 31+ / NEGATIVE_GAMMA | 1210 | 59.34% | 5.86% | 7.43% | 0.832 | 5.79% | 17.44% |

## Interpretation

- Use the implied-move coverage as the first test for condor/butterfly range calibration.
- Use realized-to-implied volatility ratio as the first test for long- versus short-volatility selection.
- Treat pin rates as conditional on expiry, DTE, gamma regime, liquidity, and data quality.
- Rows with zero/unknown gamma or zero implied move are excluded from the calibration tables because they are data-quality failures, not market regimes.
- Do not fit production probabilities from this sample alone; it is too short and expiry outcomes overlap.
