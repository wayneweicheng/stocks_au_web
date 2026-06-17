# AAII Sentiment and S&P 500 Findings

Generated from `sentiment.xls` using 2,027 valid weekly observations from 1987-07-24 through 2026-06-11.

## Executive conclusion

AAII sentiment is best used as a market-context and contrarian input, not as a standalone S&P 500 timing model. Very bearish readings have historically been followed by somewhat stronger returns, especially over multi-month horizons, but the relationship is noisy and unstable.

The fitted model has approximately zero improvement over a simple historical-average return forecast on held-out data. Its point estimates must therefore be read together with the wide prediction ranges, nearest historical analogs, and other market evidence.

## Latest reading

- Date: **2026-06-11**
- Bullish: **30.4%**
- Neutral: **22.0%**
- Bearish: **47.7%**
- Bull-bear spread: **-17.3%**
- Historical percentile: **10%**
- Classification: **extreme bearish sentiment (historically contrarian-positive)**

Interpretation: the reading is near the most bearish 10% of the full history. Historically this has been a contrarian-positive condition, but it does not imply that the S&P 500 must rise immediately.

## Model estimates

| Horizon | Predicted return | 10-90% range | Probability positive | Analog median | Analog positive rate | Validation skill |
|---:|---:|---:|---:|---:|---:|---:|
| 1 week | +0.3% | -2.5% to +2.9% | 64% | +0.7% | 56% | +0.2% |
| 4 weeks | +1.2% | -4.3% to +6.0% | 71% | +1.2% | 60% | -0.4% |
| 13 weeks | +3.3% | -5.9% to +11.8% | 76% | +3.7% | 70% | -0.4% |
| 26 weeks | +6.3% | -6.0% to +20.3% | 79% | +6.0% | 70% | -1.7% |

Validation skill is `1 - model MAE / baseline MAE`. Zero means the model merely matches the historical-average forecast; negative values mean it performs worse. The latest results show no meaningful edge.

## Historical reference

- Average bullish share: 37.6%
- Average neutral share: 31.0%
- Average bearish share: 31.4%
- Average bull-bear spread: +6.3%
- 10th/90th percentile spread: -17.1% / +28.3%

### Unconditional S&P 500 outcomes

| Horizon | Mean return | Median return | Positive rate | 10-90% range | Spread correlation |
|---:|---:|---:|---:|---:|---:|
| 1 week | +0.2% | +0.4% | 58% | -2.4% to +2.6% | -0.021 |
| 4 weeks | +0.7% | +1.2% | 63% | -4.2% to +5.1% | -0.079 |
| 13 weeks | +2.3% | +3.1% | 70% | -7.0% to +9.9% | -0.114 |
| 26 weeks | +4.8% | +5.7% | 74% | -8.1% to +16.8% | -0.130 |

A negative spread correlation is consistent with the contrarian interpretation: more bullish sentiment tends to precede slightly weaker returns. Correlation remains small, so sentiment explains only a limited part of subsequent market variation.

### Bull-bear spread regimes

| Sentiment regime | Spread range | 1-week median | 4-week median | 13-week median | 26-week median |
|---|---:|---:|---:|---:|---:|
| most bearish 20% | -54.0% to -9.0% | +0.3% | +1.7% | +4.1% | +6.9% |
| bearish 20-40% | -9.0% to +2.3% | +0.5% | +1.2% | +3.4% | +6.6% |
| middle 20% | +2.5% to +11.5% | +0.3% | +1.0% | +2.6% | +4.5% |
| bullish 60-80% | +11.6% to +21.4% | +0.4% | +1.2% | +3.1% | +6.2% |
| most bullish 20% | +21.4% to +62.9% | +0.3% | +1.0% | +2.5% | +4.2% |

## How to use this knowledge

1. Treat extreme bearish sentiment as a modest contrarian-positive context signal, strongest conceptually over 13-26 weeks.
2. Treat extreme bullish sentiment as a reason for caution, not an automatic sell signal.
3. Never use the point forecast without its prediction range. A positive estimate can still have a materially negative lower bound.
4. Combine sentiment with trend, breadth, volatility, liquidity, credit conditions, positioning, valuation, and macro regime.
5. Prefer changes and persistence in sentiment over one isolated weekly observation when building a larger decision system.
6. Re-run the generator after replacing `sentiment.xls`; do not assume that these exact numbers remain current.

## Methodology

- Inputs: weekly bullish, neutral, and bearish AAII shares.
- Targets: forward S&P 500 close-to-close returns at 1, 4, 13, and 26 weeks.
- Features: sentiment shares, bull-bear spread, absolute spread, squared bullish/bearish terms, and bullish-bearish interaction.
- Model: standardized ridge regression implemented with NumPy.
- Validation: chronological tuning and final held-out evaluation, with a horizon gap to reduce target leakage from overlapping returns.
- Uncertainty: 10th and 90th percentiles of held-out residuals.
- Analogs: 50 closest historical readings after standardizing the three sentiment shares.

## Limitations

- This is observational association, not causal evidence.
- Forward-return observations overlap, especially at 13 and 26 weeks.
- Market structure and survey behavior can change across decades.
- The S&P 500 has a positive long-run drift, which drives much of the reported probability of positive returns.
- Prediction intervals describe historical model errors and are not guaranteed bounds.
- Survey publication timing and the workbook's weekly close alignment may not match a live trading implementation exactly.
- Results exclude transaction costs, taxes, and execution constraints.

## Rebuild

```powershell
.\venv\Scripts\python.exe WebScraping\aaii_sentiment\generate_findings.py
```

The structured version of these findings is stored in `aaii_sentiment_knowledge.json` for use by other systems.
