# CNN Fear & Greed Index and S&P 500 Findings

Generated from CNN chart data using 1,353 usable daily observations from 2021-01-22 through 2026-06-12.

Sources:

- https://edition.cnn.com/markets/fear-and-greed
- https://production.dataviz.cnn.io/index/fearandgreed/graphdata/

## Executive conclusion

The CNN Fear & Greed Index is useful as a coincident market-state and contrarian context indicator. In this sample, extreme fear was followed by stronger typical S&P 500 returns mainly around 20 to 63 trading days. The effect is weak at short horizons and does not persist cleanly to 126 trading days, so this is not a dependable timing tool.

The history available from CNN is short and begins with synthetic neutral placeholders. The analysis starts on January 22, 2021, excluding 90 pre-cutoff rows, including 83 exact-50 observations. Conclusions are therefore less robust than studies based on several complete cycles.

## Latest reading

- Date: **2026-06-12**
- Score: **34.0 / 100**
- CNN rating: **fear**
- Historical percentile: **27%**
- Interpretation: **contrarian-positive**

## Model estimates

| Horizon | Predicted return | 10-90% range | Probability positive | Analog median | Analog positive rate | Validation skill |
|---:|---:|---:|---:|---:|---:|---:|
| 1 trading days | +0.0% | -0.8% to +0.9% | 59% | -0.1% | 47% | +0.6% |
| 5 trading days | +0.2% | -1.6% to +2.5% | 66% | +0.5% | 64% | -1.3% |
| 20 trading days | +1.1% | -1.3% to +6.7% | 82% | +0.8% | 57% | -3.6% |
| 63 trading days | +2.1% | -1.4% to +10.3% | 84% | +4.4% | 63% | +2.5% |
| 126 trading days | +5.4% | +3.0% to +21.0% | 93% | +7.3% | 75% | -11.9% |

Validation skill is `1 - model MAE / historical-mean baseline MAE`. Near-zero or negative skill means the score does not add a reliable forecasting edge in the held-out period.

The positive lower bound shown for 126 trading days should not be treated as strong evidence: that model has negative validation skill and its held-out period occurred within a limited market sample.

## Historical reference

- Mean score: 47.6
- Median score: 48.4
- 10th/90th percentile: 22.1 / 72.0

### Unconditional S&P 500 outcomes

| Horizon | Mean return | Median return | Positive rate | 10-90% range | Score correlation |
|---:|---:|---:|---:|---:|---:|
| 1 days | +0.1% | +0.1% | 54% | -1.2% to +1.2% | -0.048 |
| 5 days | +0.3% | +0.4% | 59% | -2.5% to +2.9% | -0.082 |
| 20 days | +1.1% | +1.7% | 66% | -4.8% to +5.7% | -0.134 |
| 63 days | +3.1% | +4.3% | 72% | -6.3% to +10.3% | -0.061 |
| 126 days | +6.1% | +7.6% | 76% | -7.3% to +16.3% | -0.024 |

### Outcomes by CNN rating

| Rating | Observations | 1-day median | 5-day median | 20-day median | 63-day median | 126-day median |
|---|---:|---:|---:|---:|---:|---:|
| extreme fear | 188 | +0.2% | +1.0% | +3.0% | +5.3% | +8.1% |
| fear | 416 | +0.1% | +0.5% | +1.9% | +4.1% | +7.4% |
| neutral | 221 | +0.1% | +0.2% | +0.7% | +4.2% | +6.8% |
| greed | 448 | +0.0% | +0.3% | +1.4% | +4.4% | +7.8% |
| extreme greed | 80 | +0.0% | +0.2% | +1.9% | +2.5% | +8.7% |

## How to use this knowledge

1. Use extreme fear as a contrarian-positive context signal, mainly for multi-week or multi-month horizons rather than the next session.
2. Use extreme greed as a caution flag, not an automatic short signal.
3. Distinguish level from direction: a low but rising score can describe a different regime from a low and still-falling score.
4. Require confirmation from trend, breadth, volatility, credit, liquidity, positioning, and macro conditions.
5. Always carry the uncertainty range and validation skill into any downstream system using the point estimate.
6. Refresh the history before reuse because CNN may revise both current and historical values.

## Methodology

- CNN's chart endpoint supplies both daily index scores and aligned S&P 500 closes.
- Duplicate dates are reduced to the last observation.
- Two long early runs fixed at exactly 50 are treated as placeholders.
- Forward close-to-close returns use 1, 5, 20, 63, and 126 trading days.
- A nonlinear ridge model uses score level, distance from neutral, squared score, and cubic score.
- Hyperparameters and final evaluation use chronological splits with a horizon gap to reduce overlap leakage.
- Prediction ranges use held-out residuals; analogs use the 50 nearest historical scores.

## Limitations

- Usable history begins in 2021 and does not span many full market cycles.
- Forward returns overlap, particularly at 63 and 126 trading days.
- The index embeds market-price and volatility inputs, so association with subsequent returns is not independent of recent price action.
- CNN can change methodology, category thresholds, endpoint structure, or historical values without notice.
- Historical residual ranges are not guaranteed future bounds.
- Results exclude costs, taxes, execution constraints, and live timing.

## Refresh

```powershell
.\venv\Scripts\python.exe WebScraping\Fear_and_Greed\download_history.py
.\venv\Scripts\python.exe WebScraping\Fear_and_Greed\generate_findings.py
```

Structured knowledge is stored in `fear_greed_knowledge.json`.
