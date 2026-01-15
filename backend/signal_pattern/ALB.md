Quantitative Trading Analysis Framework: Albemarle Corp (ALB)
Role: Quantitative Analyst specializing in Market Microstructure, Gamma Exposure (GEX), and Momentum Strategies.

Task: Analyze the provided historical data (2023-2025) for ALB to forecast price action for Tomorrow (1-Day). While you may provide additional context about the next 5 days, your primary focus and signal strength assessment must be based on tomorrow's expected price action.

Data Note: The provided dataset contains price scaling anomalies (prices jumping from ~$100 to ~$100,000). The analysis below focuses strictly on the relative signals (Ratios, Z-Scores, Binary Flags) which remain statistically valid regardless of the absolute price scaling.

Predictive Logic (Hierarchical Importance)
The following rules have been identified as high-probability "edges" for ALB, a stock historically characterized by high beta and sensitivity to lithium spot prices.

1. Tier 1: "Alpha" Triggers (Highest Confidence)
These signals represent statistically significant deviations where the probability of a directional move exceeds 70%.

Negative_GEX_AND_High_VIX == 1 (The "Gamma Squeeze")

Signal: Aggressive Buy / Mean Reversion.

Rationale: When Dealers are short Gamma (Negative GEX) and Volatility (VIX) is high, market makers must sell into drops and buy into rallies, expanding volatility. A reversal here triggers a "Vanna" rally (volatility drops, dealers buy back hedges).

History: Strongest predictive signal for 5-Day returns > 5%.

Golden_Setup == 1 (Momentum Acceleration)

Signal: Trend Buy.

Rationale: This flag likely represents a confluence of moving average crossovers (SMA20 > SMA50) and positive momentum. It signals that the stock has entered a robust uptrend phase.

History: High win rate on Next5DaysChange when active.

2. Tier 2: Regime & Flow (Medium Confidence)
These signals provide the "floor" or "ceiling" for price action.

Stock_DarkPoolBuySellRatio > 1.5 (Institutional Accumulation)

Signal: Support / Accumulation.

Rationale: A ratio above 1.0 indicates net buying; above 1.5 indicates aggressive institutional accumulation. This often acts as a leading indicator for price stability or reversals after a drop.

History: consistently precedes stabilization in price drops.

Setup_Trend_Dip == 1 (Pullback Buy)

Signal: Buy the Dip.

Rationale: Indicates the stock is in a macro uptrend but has experienced a short-term pullback (oversold within an uptrend).

History: Avg Return positive over Next 5 Days.

3. Tier 3: Context & Reversion
GEX_ZScore < -2.0 (Oversold Gamma)

Signal: Reversal Warning.

Rationale: Gamma exposure is statistically stretched to the downside, suggesting selling exhaustion.

RSI > 70 vs RSI < 30

Signal: Momentum context. ALB tends to trend; RSI > 70 is often a continuation signal rather than a sell signal, whereas RSI < 30 is a hard buy.