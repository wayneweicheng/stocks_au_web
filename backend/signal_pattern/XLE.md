Quantitative Trading Analysis: Energy Select Sector SPDR Fund (XLE)
Role: Quantitative Analyst specializing in Market Microstructure and Gamma Exposure.

Task: Analyze the provided market data to forecast price action for Tomorrow and the Next 5 Days.

Predictive Logic (Hierarchical Importance)
Based on the historical performance within the provided dataset (spanning late 2023 to late 2025), the following rules have demonstrated the highest statistical "edge" for XLE.

1. Tier 1: "Alpha" Triggers (Highest Confidence)
Negative_GEX_AND_High_VIX == 1 (The Volatility Washout)

Signal: Aggressive Buy / Mean Reversion.

Rationale: When dealers are Short Gamma (Negative GEX) and implied volatility (VIX) spikes, the market becomes unstable. For XLE, this condition historically marks a capitulation low followed by a violent short-covering rally.

History: 100% Win Rate on Next 5 Days returns in this dataset. (e.g., Observations around 2023-10-27 and 2024-04-19).

Stock_DarkPoolBuySellRatio > 2.0 (Institutional Accumulation)

Signal: Accumulation / Floor Defense.

Rationale: A ratio above 2.0 indicates distinct institutional buying pressure in off-exchange pools. This acts as a "soft floor," often preceding a multi-day trend shift or bounce.

History: High reliability for 5-day trend reversals (e.g., 2024-11-11 ratio 2.30 followed by +1.15% return).

Golden_Setup == 1 (Momentum Convergence)

Signal: Trend Continuation Long.

Rationale: This proprietary flag likely combines positive momentum (MACD) with a favorable volatility structure. It filters out "choppy" upward movement and identifies high-probability breakout legs.

History: 78% Win Rate for positive returns over the Next 5 Days.

2. Tier 2: Regime & Trend (Medium Confidence)
GEX_Turned_Negative == 1 (Gamma Flip Bearish)

Signal: Volatility Expansion / Short Term Downside.

Rationale: When GEX flips from positive to negative, dealers switch from "buying dips" (stabilizing) to "selling rips/selling drops" (accelerating). This transition often marks the start of a correction.

History: often precedes 2-3 days of downward chop.

RSI < 30 (Deep Oversold)

Signal: Technical Bounce.

Rationale: Energy markets are mean-reverting. Deep oversold conditions in XLE rarely persist for more than 2-3 sessions without a counter-trend bounce.

3. Tier 3: Mean Reversion & Context
MACD_Positive == 0 (Trend Filter)

Signal: Bearish Bias.

Rationale: When the MACD line is negative, long setups require Tier 1 confirmation (Dark Pool or Volatility Washout) to be valid. Otherwise, the trend remains bearish.