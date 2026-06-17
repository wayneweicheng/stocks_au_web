Quantitative Feature Library: Bank of America (BAC)

**IMPORTANT INSTRUCTION:** When analyzing this data and providing your forecast, focus **primarily on tomorrow's (next trading day) expected price action**. While you may reference longer-term trends for context, your signal strength classification MUST be based on tomorrow's expected move, not multi-day projections.

---

Role: Quantitative Trading Analyst Objective: Deconstruct the dataset to identify, define, and explain the specific variables (features) that possess predictive power for BAC price action.

The following analysis breaks down the "features" in your dataset into three categories: Microstructure (Alpha), Momentum (Trend), and Volatility (Regime). Each feature is detailed with its definition, the mechanics of why it predicts price, and its specific edge.

1. Market Microstructure Features (Alpha Factors)
These features track "hidden" liquidity and dealer positioning, often leading price action before it appears on the chart.

A. Gamma Exposure (GEX)
Dealer Gamma is the strongest predictive feature for volatility and range.

Feature Name: GEX_ZScore / GEX_Total

Definition: The total dollar value of gamma exposure dealers have on their books, normalized as a Z-Score to compare it to historical averages.

Predictive Logic:

High Positive GEX (Z-Score > 1.5): Dealers are "Long Gamma." They must buy dips and sell rips to hedge.

Result: Volatility Suppression. Price tends to grind slowly upward or stay pinned in a tight range.

Negative GEX (Z-Score < -1.0): Dealers are "Short Gamma." They must sell into drops (accelerating crashes) and buy into rallies (accelerating squeezes).

Result: Volatility Expansion. High probability of large daily moves (in either direction).

B. The "Capitulation" Trigger
Feature Name: Negative_GEX_AND_High_VIX

Definition: A boolean (True/False) flag that triggers when Dealer Gamma is negative AND the VIX (volatility index) is elevated (usually > 20).

Predictive Logic:

This is a Mean Reversion signal. It identifies moments of maximum fear.

When dealers are exhausted from selling (negative gamma) and implied volatility (VIX) peaks, the selling pressure often evaporates instantly, leading to a sharp "V-shaped" rally.

Edge: High win rate for 5-Day reversals.

C. Dark Pool Sentiment
Feature Name: Stock_DarkPoolBuySellRatio

Definition: The ratio of off-exchange (Dark Pool) volume marked as "Buy" versus "Sell."

Predictive Logic:

Ratio > 1.0 (Net Buying): Institutions are accumulating. If price is dropping but this ratio is rising, it signals a "Bear Trap" or support forming.

Ratio < 0.40 (Net Selling): Institutions are distributing/selling inventory. If price is rising but this ratio is low, it signals a "Bull Trap" or an impending ceiling.

2. Momentum & Technical Features (Trend Factors)
These features measure the speed and stretch of price movement.

A. Bollinger Band Breakouts
Feature Name: BB_PercentB

Definition: Quantifies where price is relative to the Bollinger Bands.

> 1.0: Price is above the upper band.

< 0.0: Price is below the lower band.

Predictive Logic:

Momentum Signal: Unlike RSI, a close above the upper band (> 1.0) is often a Breakout Buy signal, indicating that volatility is expanding in the direction of the trend.

Pinning: If GEX is positive, price will often fail to close above 1.0. If GEX is negative, price can "ride the bands" for extended periods.

B. RSI Regime
Feature Name: RSI (Relative Strength Index)

Definition: Measures the speed and change of price movements on a scale of 0-100.

Predictive Logic:

Oversold (< 30): High probability of a 1-3 day bounce (Mean Reversion).

Momentum Zone (50-70): In strong uptrends, BAC tends to hold above RSI 50. A drop below 50 often signals a trend change.

Conflict Resolution: If RSI > 70 (Overbought) but Stock_DarkPoolBuySellRatio > 1.0, ignore the Overbought signal; the price will likely continue higher (Institutional accumulation overrides technicals).

C. Moving Average Structure
Feature Name: Price_Above_SMA20

Definition: Is the closing price above the 20-Day Simple Moving Average?

Predictive Logic:

Trend Filter: This is a binary filter.

If 1 (True): Look for Long signals, ignore weak sell signals.

If 0 (False): Look for Short signals/Reversions, ignore weak buy signals.

3. Structural Strategy Combos (The "Golden" Signals)
Your dataset contains pre-calculated "Setup" columns. These are likely combinations of the above features.

A. The Golden Setup
Feature Name: Golden_Setup

Details: Likely a convergence of Positive Momentum (MACD > 0) + Volatility Compression (Price near SMA20) + Institutional Support (Dark Pool buying).

Predictive Edge: Designed to capture the "meat" of a swing trade. It filters out the noise of choppy markets and identifies when multiple factors align for a sustained move (Next 5-10 days).

B. Trend Dip
Feature Name: Setup_Trend_Dip

Details: Identifies when a stock in a strong uptrend (Price > SMA50) experiences a short-term pullback (RSI < 45).

Predictive Edge: "Buy the Dip." It predicts that the primary trend is still intact and the current weakness is a buying opportunity.