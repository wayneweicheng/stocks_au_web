# High-frequency candidate reduction test

## Policy tested

The requested target is approximately 25% signal frequency. I tested stricter thresholds for the same rule family for the 13 highest-frequency candidates. A reduction was eligible only when it had:

- 15%–30% frequency;
- at least 8 train signals and 4 validation signals;
- positive train and validation mean return;
- train and validation profit factor above 1;
- no use of September or October 2026 data.

Threshold selection used only the train/validation partitions. The final August research tail was reported afterward.

A total of 125 stricter variants were tested.

## Results

| Symbol | Current | Reduced rule | New rate | Train mean | Validation mean / PF | August final tail | Result |
|---|---:|---|---:|---:|---:|---:|---|
| S | 44.7% | None passed | — | — | — | — | Do not force reduction |
| MOD | 44.4% | None passed | — | — | — | — | Do not force reduction |
| IGV | 40.8% | SafeGEXVolRank60 >= 0.90 AND PriceDistSMA50Pct >= 2.5 | 28.6% | 0.23% | 2.13% / 57.1 | N=0 | Insufficient final data |
| ADBE | 40.5% | None passed | — | — | — | — | Do not force reduction |
| FCX | 38.5% | None passed | — | — | — | — | Do not force reduction |
| ZS | 37.0% | None passed | — | — | — | — | Do not force reduction |
| COHR | 34.7% | None passed | — | — | — | — | Do not force reduction |
| INTC | 33.8% | None passed | — | — | — | — | Do not force reduction |
| GDX | 33.6% | None passed | — | — | — | — | Do not force reduction |
| TXN | 33.3% | None passed | — | — | — | — | Do not force reduction |
| SPXU | 31.1% | PutBuyShareChgAbsRank60 >= 0.85 | 28.9% | 0.48% | 0.54% / 37.2 | N=0 | Insufficient final data |
| QCOM | 31.1% | None passed | — | — | — | — | Do not force reduction |
| PANW | 29.7% | GEX_ZScore <= -1.25 | 20.3% | 5.24% | 0.68% / 1.33 | N=2, mean +4.73% | Too small to confirm |

## Decision

No reduced rule is ready for production promotion. IGV and SPXU have no final-tail observations, while PANW has only two. The other ten symbols did not produce a same-family reduction meeting the train/validation profitability and sample requirements.

This does not prove that the underlying ideas are unprofitable. It means that, with the available August-only sample, tightening the same predicates to approximately 25% does not provide enough chronological evidence to promote them. September and October remain untouched for forward validation.

## Reversion

No tightening was applied to `best-by-ticker.csv`, any strategy descriptor, or any production contract. The original high-frequency candidate rules remain the baseline. The reduction files below are research-only sensitivity results and are not active strategies.

Outputs:

- `high-frequency-reduction-all-variants.csv`
- `high-frequency-reduction-selected.csv`
- `high-frequency-reduction-summary.csv`
