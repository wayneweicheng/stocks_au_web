# QQQ Walk-Forward Option-Flow Calibration

This evaluates simple historical median adjustments without writing production scores.
Training observations are restricted to rows whose expiry outcome was known by the training cutoff.

## Split sizes

| Split | Observation rows | Date range |
|---|---:|---|
| Train | 3724 | 2025-06-03 → 2026-03-30 |
| Validation | 999 | 2026-04-01 → 2026-06-30 |
| Test | 452 | 2026-07-01 → 2026-08-27 |

## Walk-forward results

| Evaluation | N | Raw metric | Calibrated metric |
|---|---:|---:|---:|
| Validation range coverage | 999 | 50.15% | 35.74% |
| Validation range MAE | 999 | 3.265% | 3.446% |
| Validation volatility MAE | 763 | 0.060 | 0.073 |
| Validation pin Brier score | 999 | n/a | 0.139 |
| Test range coverage | 452 | 63.27% | 46.02% |
| Test range MAE | 452 | 1.700% | 1.518% |
| Test volatility MAE | 295 | 0.035 | 0.042 |
| Test pin Brier score | 452 | n/a | 0.185 |

## Test results by DTE and gamma regime

| Group | N | Learned range ratio | Range coverage | Pin probability / observed | Learned vol ratio |
|---|---:|---:|---:|---:|---:|
| 01-05 / POSITIVE_GAMMA | 53 | 0.691 | 41.51% | 58.36% / 41.51% | n/a |
| 06-10 / NEGATIVE_GAMMA | 88 | 0.718 | 43.18% | 21.87% / 26.14% | 0.747 |
| 11-30 / NEGATIVE_GAMMA | 77 | 0.582 | 27.27% | 15.97% / 14.29% | 0.797 |
| 11-30 / POSITIVE_GAMMA | 72 | 0.645 | 44.44% | 33.54% / 13.89% | 0.791 |
| 31+ / POSITIVE_GAMMA | 7 | 0.539 | 100.00% | 15.46% / 71.43% | 0.795 |
| 31+ / NEGATIVE_GAMMA | 32 | 0.730 | 90.62% | 5.15% / 3.12% | 0.817 |
| 01-05 / NEGATIVE_GAMMA | 72 | 0.790 | 43.06% | 39.81% / 51.39% | n/a |
| 06-10 / POSITIVE_GAMMA | 51 | 0.680 | 54.90% | 31.52% / 13.73% | 0.747 |

## Decision

- These results are diagnostic only; no production score columns were updated.
- A calibrated range multiplier should only be promoted if it improves coverage and MAE in both validation and test periods.
- Pin probabilities should be promoted only after checking confidence intervals and expiry-level dependence.
- Volatility selection requires actual strategy P&L, including spreads and transaction costs; forecast error alone is insufficient.
