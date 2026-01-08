Quantitative Trading Analysis: Caterpillar Inc. (CAT)
Role: Quantitative Analyst specializing in Market Microstructure and Gamma Exposure.

Task: Analyze the provided market data to forecast price action for Tomorrow and the Next 5 Days.

Predictive Logic (Hierarchical Importance)
The following framework is derived from the provided historical dataset (2023–2025). For an industrial bellwether like CAT, microstructure flows (Dark Pools) and Dealer positioning (GEX) act as the primary leading indicators, while momentum indicators (RSI/Bollinger Bands) act as confirmation.

1. Tier 1: "Alpha" Triggers (Highest Confidence)
Negative_GEX_AND_High_VIX (The Capitulation Floor)

Signal: Aggressive Buy / Reversal Long.

Rationale: When Dealer Gamma (GEX) turns negative, dealers accentuate volatility (selling into drops). If this coincides with high SP500 volatility (VIX > 20), it indicates macro fear. For CAT, historically, this marks a "washout" low where smart money steps in.

History: High win rate for 5-Day reversals when GEX_ZScore < -1.5 and VIX > 18.

Stock_DarkPoolBuySellRatio > 2.0 (Institutional Accumulation)

Signal: Trend Continuation / Floor Support.

Rationale: A Buy/Sell ratio above 2.0 indicates that for every share sold in dark pools, two are bought. This creates a "hidden floor." When price revisits the level where this ratio occurred, it rarely breaks below it in the short term.

History: Strong correlation with positive Next5DaysChange.

2. Tier 2: Regime & Trend (Medium Confidence)
Golden_Setup == 1 (Volatility Compression)

Signal: Breakout Watch.

Rationale: This flag typically indicates a convergence of price stability (low volatility) and momentum. In CAT, this often precedes a 3-5% move over the next week.

History: ~65% Win Rate on Next5DaysChange.

GEX_BigDrop (Liquidity Vacuum)

Signal: Short-Term Bearish / Pullback.

Rationale: A significant day-over-day drop in GEX (e.g., falling from 15k to 5k) while the price is high suggests dealers are "de-hedging" (selling calls or buying puts) or simply removing liquidity. This leaves the stock vulnerable to gravity.

History: Often precedes a test of the SMA20.

3. Tier 3: Mean Reversion & Context
Price_Above_SMA20 AND RSI > 75

Signal: Overextended (Profit Taking).

Rationale: CAT is a cyclical stock. When RSI pushes extreme highs while extended from the 20-day moving average, mean reversion to the SMA20 is highly probable.

VIX Context

Note: The VIX provided is for the S&P 500, not CAT specific. However, CAT has a high beta to the market. A rising VIX generally correlates with short-term weakness in CAT.