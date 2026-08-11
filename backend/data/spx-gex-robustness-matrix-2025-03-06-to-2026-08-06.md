# SPX GEX robustness matrix

Window: **2025-03-06 through 2026-08-06**.

This is a Yellow-only sensitivity study with portfolio conflicts disabled. No combination was selected by NAV or profit factor, and SC remains P50.

| SC | SP | Threshold | Strong n | Strong win | Strong avg | Strong PF | Reliable n | Reliable win | Reliable avg | Reliable PF | Yellow n | Combined win | Combined avg | Combined PF | 2025 PF | 2026 PF |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 60 | 60 | P60 | 15 | 86.67% | 0.59% | 5.4069 | 16 | 81.25% | 0.18% | 2.1667 | 31 | 83.87% | 0.37% | 3.6395 | 2.8621 | 5.0000 |
| 60 | 60 | P75 | 10 | 80.00% | 0.48% | 3.4069 | 21 | 85.71% | 0.23% | 3.0000 | 31 | 83.87% | 0.31% | 3.1850 | 2.5764 | 4.2500 |
| 60 | 120 | P60 | 15 | 86.67% | 0.59% | 5.4069 | 16 | 81.25% | 0.18% | 2.1667 | 31 | 83.87% | 0.37% | 3.6395 | 2.7192 | 5.2500 |
| 60 | 120 | P75 | 10 | 90.00% | 0.66% | 7.6138 | 21 | 85.71% | 0.23% | 3.0000 | 31 | 87.10% | 0.37% | 4.3570 | 4.4521 | 4.2500 |
| 60 | 180 | P60 | 14 | 92.86% | 0.70% | 10.8138 | 11 | 81.82% | 0.18% | 2.2500 | 25 | 88.00% | 0.47% | 5.5438 | 5.6138 | 5.5000 |
| 60 | 180 | P75 | 10 | 100.00% | 0.84% | n/a | 15 | 86.67% | 0.24% | 3.2500 | 25 | 92.00% | 0.48% | 8.5086 | n/a | 5.2500 |
| 120 | 60 | P60 | 12 | 91.67% | 0.68% | 9.2138 | 21 | 85.71% | 0.23% | 3.0000 | 33 | 87.88% | 0.39% | 4.8276 | 5.3410 | 4.2500 |
| 120 | 60 | P75 | 9 | 88.89% | 0.65% | 6.8138 | 24 | 87.50% | 0.25% | 3.5000 | 33 | 87.88% | 0.36% | 4.4747 | 5.1188 | 3.7500 |
| 120 | 120 | P60 | 14 | 92.86% | 0.70% | 10.8138 | 19 | 84.21% | 0.21% | 2.6667 | 33 | 87.88% | 0.42% | 5.0629 | 5.3410 | 4.7500 |
| 120 | 120 | P75 | 9 | 100.00% | 0.85% | n/a | 24 | 87.50% | 0.25% | 3.5000 | 33 | 90.91% | 0.41% | 6.6724 | 12.5173 | 3.7500 |
| 120 | 180 | P60 | 13 | 92.31% | 0.69% | 10.0138 | 15 | 86.67% | 0.24% | 3.2500 | 28 | 89.29% | 0.45% | 5.8515 | 7.6138 | 4.7500 |
| 120 | 180 | P75 | 10 | 100.00% | 0.84% | n/a | 18 | 88.89% | 0.27% | 4.0000 | 28 | 92.86% | 0.47% | 9.2586 | n/a | 4.7500 |
| 180 | 60 | P60 | 10 | 90.00% | 0.66% | 7.6138 | 13 | 84.62% | 0.22% | 2.7500 | 23 | 86.96% | 0.41% | 4.6207 | 5.2138 | 4.2500 |
| 180 | 60 | P75 | 7 | 85.71% | 0.60% | 5.2138 | 16 | 87.50% | 0.25% | 3.5000 | 23 | 86.96% | 0.36% | 4.1592 | 4.8138 | 3.7500 |
| 180 | 120 | P60 | 12 | 91.67% | 0.68% | 9.2138 | 11 | 81.82% | 0.18% | 2.2500 | 23 | 86.96% | 0.44% | 4.9284 | 5.2138 | 4.7500 |
| 180 | 120 | P75 | 7 | 100.00% | 0.86% | n/a | 16 | 87.50% | 0.25% | 3.5000 | 23 | 91.30% | 0.44% | 7.2586 | n/a | 3.7500 |
| 180 | 180 | P60 | 12 | 91.67% | 0.68% | 9.2138 | 11 | 81.82% | 0.18% | 2.2500 | 23 | 86.96% | 0.44% | 4.9284 | 5.2138 | 4.7500 |
| 180 | 180 | P75 | 9 | 100.00% | 0.85% | n/a | 14 | 85.71% | 0.23% | 3.0000 | 23 | 91.30% | 0.47% | 7.7586 | n/a | 4.7500 |

## Interpretation

All cells use a common causal warm-up sufficient for the maximum 180-session lookback. The SQL runner loads 190 prior US sessions. This avoids treating the first six research-window Yellow dates as insufficient merely because the 60-session production query warm-up is shorter.

P60 versus P75 changes the Strong/Reliable split, but it does not change the underlying SC_LOW gate; within a common lookback pair, the total tradable Yellow count is therefore unchanged.

SC lookback changes the number of Yellow candidates because SC_LOW is the tradability gate. The 2025 and 2026 columns must be read together: isolated `n/a` PF values mean there were no losses in that sub-period, not that the parameter is proven superior.

Use the `stability_by_sp_threshold` and `stability_by_sc_lookback` sections in the JSON to inspect ranges across the matrix. The study intentionally does not identify a best parameter combination.

The full JSON also contains Strong and Reliable win rate, average return, PF, completed-outcome counts, separate 2025/2026 results, and NQ roll-gap metadata.
