# QQQ Option-Flow Feature Calibration

This is a preliminary expiry-outcome calibration. It is descriptive, not a trading recommendation.
Only FULL_CHAIN rows with an exact underlying close on the expiry date are included.

- Usable observations: **6219**
- Observation range: **2025-06-03** to **2026-08-27**
- Pin candidate: `MaxAbsGammaStrike`
- Implied move: near-ATM call/put mid sum divided by spot

## Calibration summary

| Group | N | Inside implied move | Median actual move | Median implied move | Actual/implied move | Pin within 1% | Realized IV > implied IV |
|---|---:|---:|---:|---:|---:|---:|---:|
| ALL | 6219 | 58.42% | 2.39% | 3.55% | 0.761 | 20.47% | 25.24% |
| 01-05 | 940 | 60.74% | 0.94% | 1.20% | 0.800 | 47.02% | n/a |
| POSITIVE_GAMMA | 2937 | 60.20% | 2.20% | 3.22% | 0.764 | 25.77% | 25.95% |
| 06-10 | 1112 | 61.78% | 1.64% | 2.14% | 0.763 | 25.81% | 26.50% |
| NEGATIVE_GAMMA | 3001 | 61.91% | 2.63% | 3.93% | 0.757 | 16.89% | 24.45% |
| 11-30 | 1880 | 53.83% | 2.10% | 3.35% | 0.702 | 18.67% | 30.32% |
| ZERO_OR_UNKNOWN_GAMMA | 281 | 2.49% | 2.17% | 3.35% | 0.981 | 3.20% | 46.15% |
| 31+ | 2287 | 59.60% | 5.55% | 7.27% | 0.809 | 8.44% | 21.39% |

## DTE × gamma regime

This cross-tab is the primary diagnostic for deciding whether range and pin behaviour differs by gamma regime.

| Group | N | Inside implied move | Median actual move | Median implied move | Actual/implied move | Pin within 1% | Realized IV > implied IV |
|---|---:|---:|---:|---:|---:|---:|---:|
| 01-05 / POSITIVE_GAMMA | 466 | 61.59% | 0.82% | 1.13% | 0.762 | 53.86% | n/a |
| 01-05 / NEGATIVE_GAMMA | 474 | 59.92% | 1.05% | 1.35% | 0.822 | 40.30% | n/a |
| 06-10 / POSITIVE_GAMMA | 586 | 58.70% | 1.62% | 2.04% | 0.788 | 28.33% | 23.73% |
| 06-10 / NEGATIVE_GAMMA | 526 | 65.21% | 1.64% | 2.29% | 0.749 | 23.00% | 29.66% |
| 11-30 / POSITIVE_GAMMA | 865 | 57.23% | 2.18% | 3.21% | 0.752 | 25.66% | 27.13% |
| 11-30 / NEGATIVE_GAMMA | 782 | 65.60% | 2.07% | 3.53% | 0.630 | 15.86% | 33.57% |
| 11-30 / ZERO_OR_UNKNOWN_GAMMA | 233 | 1.72% | 1.99% | 3.32% | 1.143 | 2.15% | 44.44% |
| 31+ / POSITIVE_GAMMA | 1020 | 62.94% | 5.04% | 7.12% | 0.788 | 11.57% | 26.02% |
| 31+ / NEGATIVE_GAMMA | 1219 | 58.90% | 5.83% | 7.43% | 0.832 | 5.82% | 17.44% |
| 31+ / ZERO_OR_UNKNOWN_GAMMA | 48 | 6.25% | 3.56% | 5.93% | 0.329 | 8.33% | 50.00% |

## Interpretation

- Use the implied-move coverage as the first test for condor/butterfly range calibration.
- Use realized-to-implied volatility ratio as the first test for long- versus short-volatility selection.
- Treat pin rates as conditional on expiry, DTE, gamma regime, liquidity, and data quality.
- Do not fit production probabilities from this sample alone; it is too short and expiry outcomes overlap.
