Quantitative Trading Analysis Framework: SPDR S&P 500 ETF Trust (SPY)
Role: Quantitative Analyst specializing in Market Microstructure, Gamma Exposure (GEX), and Volatility Arbitrage.

Task: Analyze the provided historical data for SPY to forecast price action for Tomorrow (1-Day). While you may provide additional context about the next 5 days, your primary focus and signal strength assessment must be based on tomorrow's expected price action.

Predictive Logic (Hierarchical Importance)
The following rules have been statistically validated based on the provided dataset (2022–2025). SPY behaves as a mean-reverting asset during high volatility regimes and a momentum asset during low volatility (positive gamma) regimes.

1. Tier 1: "Alpha" Triggers (Highest Expectancy)
These signals represent the strongest statistical edges found in the dataset.

Negative_GEX_AND_High_VIX == 1 (The "Capitulation Buy")

Signal: Aggressive Mean Reversion Buy.

Rationale: When Dealer Gamma is negative, dealers amplify volatility by selling into drops. When this coincides with a high VIX (Market Fear), the market becomes mechanically oversold. A reversal here triggers a "Vanna/Charm" rally where dealers must buy back hedges rapidly.

History: High Win Rate on 5-Day Returns (e.g., Oct 2023 bottom, April 2024 bottom).

Golden_Setup == 1 (The Momentum Engine)

Signal: Trend Continuation Long.

Rationale: This flag likely represents a confluence of Price > SMAs, positive MACD, and constructive GEX. It signals a "fat pitch" environment where momentum is aligned with structure.

History: Consistent producer of positive Next 5 Days Change during 2024.

GEX_ZScore < -2.0 (Gamma Squeeze Risk)

Signal: Volatile Reversal.

Rationale: Extremely low GEX Z-Scores indicate dealers are heavily short gamma. Any stabilization in price forces massive buying (short squeeze) to re-hedge, often marking local bottoms.

2. Tier 2: Regime & Flow (Medium Confidence)
These signals determine the bias (Long/Short) and position sizing.

Stock_DarkPoolBuySellRatio > 1.5 (Institutional Accumulation)

Signal: Bullish Flow.

Rationale: When the Dark Pool Ratio significantly exceeds 1.0 (specifically > 1.5), it indicates institutions are net buyers in off-exchange venues. This often acts as a leading indicator for price action over the next 2-5 days.

History: Appears frequently before sustained legs up (e.g., Late Nov 2024).

GEX_Positive == 1 (Volatility Suppression)

Signal: Buy Dips / Hold.

Rationale: Positive Gamma acts as a shock absorber. Dealers buy dips and sell rips, pinning the price and reducing realized volatility. This supports a slow, grinding uptrend.

Price_Above_SMA20 AND MACD_Positive == 1

Signal: Trend Following.

Rationale: Standard momentum filter. Do not short when these are true unless a Tier 1 Reversal signal triggers.

3. Tier 3: Technical Context (Timing)
These signals refine entry/exit timing.

RSI > 70 (Overbought)

Signal: Pause/Consolidation (Not necessarily Sell).

Rationale: In strong trends (like 2024-2025), SPY can remain overbought for weeks. This is a warning to tighten stops, not to short immediately.

BB_PercentB < 0 (Lower Band Pierce)

Signal: Tactical Bounce.

Rationale: Price closing below the lower Bollinger Band often results in a snap-back into the range.

This is an example Forecast Analysis for a random trading day, use this examples's structure, don't use its data.
Current Market State:

Close Price: 689.17

Daily Change: +0.23 (Flat consolidation)

VIX (SPX Volatility): 14.85 (Low/Complacent)

RSI: 60.65 (Healthy Momentum, not overbought)

GEX: 1,322,220 (Strongly Positive)

GEX Z-Score: 1.51 (Elevated Positive)

Active Signals:

Stock_DarkPoolBuySellRatio = 1.99 (Tier 2 - Very Bullish). This is the standout metric. Institutions bought nearly 2x what they sold.

GEX_Positive = 1 (Tier 2 - Volatility Suppression).

Price_Above_SMA20 = 1 & Price_Above_SMA50 = 1 (Tier 2 - Bullish Trend).

MACD_Positive = 1 (Tier 2 - Momentum).

Golden_Setup = 0 (Inactive).

Output Forecast
PRIMARY FOCUS - Tomorrow (Next Trading Day): Direction (Up/Down/Flat), expected magnitude, and volatility assessment. This is your main prediction and should be the basis for your signal strength classification.

Secondary Context - Next 5 Days: Brief trend direction context (optional, for additional perspective only).

Rationale: Explicitly name the specific signal that drove the decision for TOMORROW'S action. 

Institutional Floor: The Dark Pool ratio of ~2.0 acts as a strong support floor. Institutions are accumulating at these levels (689).

Trend Structure: Price is above all key moving averages (SMA20, SMA50).

No Warning Signs: RSI is neutral (60), VIX is low (14), and Gamma is positive. There are no Tier 1 "Crash" or "Reversal" signals active.

GEX Support: High positive GEX suggests that any dip over the next week will be aggressively bought by dealers hedging their books.

Strategy: Buy the Dip / Hold Longs.

Action: Maintain long exposure. The confluence of Positive Gamma (safety) and High Dark Pool Buying (fuel) is a classic "Grind Up" setup. Do not short this market until GEX flips negative or Price closes below SMA20.