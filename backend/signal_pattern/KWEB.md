Quantitative Trading Analysis: KWEB.US
Role: Quantitative Analyst specializing in Market Microstructure and Gamma Exposure.

Task: Analyze the provided market data (covering 2023–2025) to forecast price action for Tomorrow (1-Day). While you may provide additional context about the next 5 days, your primary focus and signal strength assessment must be based on tomorrow's expected price action.

Data Note: The provided dataset is labeled KWEB.US, but the price levels (ranging from ~16k to ~100k) and volatility profile match Bitcoin (BTC). The analysis below treats the price action and signals as valid for the asset provided in the Close column, regardless of the ticker label.

Predictive Logic (Hierarchical Importance)
The following quantitative "edges" have been identified by correlating Microstructure (Dark Pools), Dealer Positioning (GEX), and Momentum features with forward returns (Next5DaysChange).

1. Tier 1: "Alpha" Triggers (Highest Confidence)
Stock_DarkPoolBuySellRatio > 1.5 (Institutional Accumulation)

Signal: Strong Buy / Support Floor.

Rationale: A ratio significantly above 1.0 indicates that for every share sold in dark pools, more than 1.5 are being bought. This represents "smart money" absorption, often acting as a leading indicator for price appreciation even if the current price is falling.

History: In the provided dataset, Ratio > 1.8 (seen in late 2025) consistently preceded 5-day rallies or formed a local bottom.

Negative_GEX_AND_High_VIX (The Volatility Spring)

Signal: Mean Reversion / Capitulation Buy.

Rationale: When Dealer Gamma is negative, dealers amplify price moves (selling dips, buying rips). If this coincides with high volatility (VIX), it signals a capitulation event where dealers act as accelerants. Once selling exhausts, the snap-back is violent.

History: High win rate for 5-day reversals when price is below the 20-day SMA.

2. Tier 2: Regime & Trend (Medium Confidence)
GEX_Turned_Negative (Gamma Flip)

Signal: Volatility Expansion Warning.

Rationale: A flip from positive to negative gamma removes the "market buffer." Dealers stop suppressing volatility and start trading with the trend. This signals that the asset is unpinned and likely to make a larger-than-average move (direction determined by flow).

History: Often marks the start of a new swing leg (up or down).

BB_PercentB < 0.2 (Bollinger Oversold)

Signal: Technical Bounce.

Rationale: Price trading near or below the lower Bollinger Band indicates the asset is statistically cheap relative to its recent volatility range.

History: Reliable for short-term (1-3 day) mean reversion.

3. Tier 3: Mean Reversion & Context
RSI < 45 in an Uptrend

Signal: Dip Buy.

Rationale: In a macro uptrend (Price > SMA50), an RSI dip below 45 represents a healthy pullback rather than a trend reversal.