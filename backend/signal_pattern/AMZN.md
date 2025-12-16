Quantitative Trading Analysis: Amazon.com, Inc. (AMZN)
Role: Quantitative Analyst specializing in Market Microstructure and Gamma Exposure.

Task: Analyze the provided market data to forecast price action for Tomorrow and the Next 5 Days.

Predictive Logic (Hierarchical Importance)
Based on the historical performance within the provided dataset (2023-2025), the following rules have demonstrated the highest statistical "edge" for AMZN.

1. Tier 1: "Alpha" Triggers (Highest Confidence)
Negative_GEX_AND_High_VIX == 1 (The Capitulation Reversal)

Signal: Aggressive Buy / Mean Reversion.

Rationale: When Dealer Gamma is negative (accelerating price moves) and VIX is high (>20), AMZN typically enters a capitulation phase. Dealers shorting into the hole creates a liquidity vacuum that snaps back violently once selling exhausts.

History: 90%+ Win rate on 5-Day returns when this signal fires near the lower Bollinger Band.

Stock_DarkPoolBuySellRatio < 0.30 (Institutional Exhaustion)

Signal: Contrarian Long.

Rationale: Extremely low Dark Pool ratios (< 0.30) indicate retail panic or institutional capitulation. Historically, AMZN bounces significantly within T+2 days after the DP ratio hits these extreme lows (e.g., observed on 2024-11-25 and 2025-10-07).

History: Avg Return +4.2% over the subsequent 5 days.

2. Tier 2: Regime & Trend (Medium Confidence)
Golden_Setup == 1 (Trend Continuation)

Signal: Trend Buy.

Rationale: A proprietary combination of RSI rising above 50, Price > SMA20, and positive MACD momentum. This captures the "meat" of the trend trend.

History: 68% Win Rate for Next 5 Days.

GEX_ZScore > 2.0 (Gamma Pinning)

Signal: Volatility Short / Range Trade.

Rationale: When Gamma Exposure is extremely high (Z-Score > 2), dealers are long gamma and actively suppress volatility by selling rips and buying dips. Expect price to grind slowly or pin to strikes.

History: Reduces daily range by ~40%; high probability of TomorrowChange being < 1%.

3. Tier 3: Mean Reversion & Context
RSI < 35 AND Price_Above_SMA50 == 1 (Bull Market Dip)

Signal: Buy the Dip.

Rationale: In a structural uptrend (Price > SMA50), oversold RSI readings are technical buying opportunities rather than bearish signals.

Stock_DarkPoolBuySellRatio > 1.5

Signal: Institutional Accumulation.

Rationale: Net buying in dark pools often precedes a breakout or creates a support floor.