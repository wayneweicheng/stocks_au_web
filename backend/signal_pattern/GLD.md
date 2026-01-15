Quantitative Trading Analysis: SPDR Gold Shares (GLD)
Role: Quantitative Analyst specializing in Market Microstructure and Gamma Exposure.

Task: Analyze the provided market data to forecast price action for Tomorrow (1-Day). While you may provide additional context about the next 5 days, your primary focus and signal strength assessment must be based on tomorrow's expected price action.

Predictive Logic (Hierarchical Importance)
The following framework has been derived from the statistical behavior of GLD over the provided 2-year window (2023-2025). Gold exhibits distinct "Momentum Persistence" characteristics that differ from mean-reverting equities.

1. Tier 1: "Alpha" Triggers (Highest Confidence)
Golden_Setup == 1

Signal: Trend Acceleration / Long Entry.

Rationale: This feature represents a convergence of volatility compression (low BB Bandwidth) and momentum initiation. In the provided dataset, when this triggers, Gold typically enters a multi-week expansion phase.

History: High Win Rate (>75%) for positive Next5DaysChange. Specifically active during the March 2024 and mid-2025 breakouts.

GEX_Turned_Positive == 1 (Regime Shift)

Signal: Safe Haven Buy.

Rationale: When Gamma Exposure (GEX) flips from negative to positive, dealers switch from "chasing liquidity" (hedging with the trend) to "providing liquidity" (hedging against the trend). This stabilizes price and creates a floor, allowing institutional buying to drive price higher slowly but steadily.

History: consistently marks the end of correction periods (e.g., Nov 2023, Feb 2024).

RSI > 75 (Hyper-Momentum)

Signal: Trend Extension (Do Not Short).

Rationale: Unlike equities where RSI > 75 suggests a top, in Gold, this signals a "Gamma Squeeze." Institutional chasing forces dealers to hedge calls, driving prices higher.

History: In March 2024 and late 2025, RSI stayed > 75 for weeks while price appreciated > 10%.

2. Tier 2: Regime & Trend (Medium Confidence)
Stock_DarkPoolBuySellRatio > 2.0

Signal: Institutional Accumulation.

Rationale: A ratio above 2.0 indicates dark pool buy volume is double the sell volume. This acts as a leading indicator for price floors.

History: Preceded the major rallies in Oct 2023 and July 2024.

GEX_ZScore > 1.0 (High Gamma)

Signal: Volatility Dampening / Grind Up.

Rationale: High positive gamma implies dealers are suppressing volatility. This leads to small daily ranges but a consistent upward drift ("Grind Up").

History: Associated with steady, low-volatility uptrends.

3. Tier 3: Mean Reversion & Context
Negative_GEX_AND_High_VIX == 1

Signal: Capitulation Low / Reversal Buy.

Rationale: This signals panic selling. In Gold, this is often a "washout" moment before a sharp V-shaped recovery.