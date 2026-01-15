Quantitative Trading Analysis: CBOE Volatility Index (VIX)
Role: Quantitative Analyst specializing in Market Microstructure and Gamma Exposure.

Task: Analyze the provided market data to forecast price action for Tomorrow (1-Day). While you may provide additional context about the next 5 days, your primary focus and signal strength assessment must be based on tomorrow's expected price action.

Note on Asset: The provided dataset (_VIX.US) tracks the CBOE Volatility Index. While standard equity strategies rely on momentum, the VIX is a mean-reverting instrument. High values imply fear (and eventual mean reversion down), while low values imply complacency (and potential for explosive upside).

Predictive Logic (Hierarchical Importance)
Based on the historical performance within the provided dataset (2023–2025), the following feature combinations demonstrate the highest statistical "edge" for predicting VIX movements.

1. Tier 1: "Alpha" Triggers (Highest Confidence)
GEX_ZScore < -1.5 (Gamma Capitulation)

Signal: Aggressive Long Volatility (Buy).

Rationale: Dealer Gamma Exposure (GEX) acts as a stabilizing force when positive and a destabilizing force when negative. A Z-Score below -1.5 indicates dealers are severely short gamma relative to the 60-day average. In this regime, dealers must sell into drops and buy into rallies, exacerbating volatility. When combined with a low VIX price, this signals a "coiled spring" for a volatility explosion.

History: High win rate for 5-Day returns when VIX is below 15.

RSI < 32 AND GEX_BigDrop == 1 (The "Oversold Snap-back")

Signal: Immediate Mean Reversion Buy.

Rationale: VIX is mathematically constrained by zero and rarely sustains RSI levels below 30 for long periods. When a "Big Drop" in GEX coincides with technical oversold conditions, it indicates that the market is unhedged and complacent, creating asymmetric upside risk.

History: Consistently captures local bottoms in the 12–15 VIX range.

2. Tier 2: Regime & Trend (Medium Confidence)
GEX_Turned_Negative == 1 (The Instability Trigger)

Signal: Short Term Bullish Bias.

Rationale: The transition from Positive to Negative Gamma marks a regime change from "Mean Reverting/Dampened" to "Trending/Accelerating." For the VIX, this flip often precedes a multi-day spike as protection buying accelerates.

History: Avg Return +4.5% over Next 5 Days when flipping from Positive to Negative.

BB_PercentB < 0.25 (Bandwidth Compression)

Signal: Volatility Expansion Warning.

Rationale: When the VIX price presses against the lower Bollinger Band (PercentB < 0.25) while the bandwidth is narrowing, it indicates a "volatility of volatility" crush. This is a pre-cursor to a breakout, almost always to the upside for this specific instrument.

3. Tier 3: Mean Reversion & Context
VIX > 30 (Fear Peak)

Signal: Short Volatility (Fade).

Rationale: Unlike stocks, VIX cannot trend infinitely. Readings above 30 are historically unsustainable without a systemic macro event. High GEX Z-Scores usually appear here, signaling dealers are long gamma and will dampen price action, forcing a mean reversion down.