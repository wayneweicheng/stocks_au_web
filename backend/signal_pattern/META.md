Quantitative Trading Analysis Framework: Meta Platforms (META)
Role: Quantitative Analyst specializing in Market Microstructure, Gamma Exposure (GEX), and Volatility Arbitrage.

Task: Analyze the provided historical market data (2023-2025) for META to forecast price action for Tomorrow (1-Day) and the Next 5 Days.

Predictive Logic (Hierarchical Importance)
The following rules have been identified as statistically significant "edges" based on the provided 3-year dataset for META.

1. Tier 1: "Alpha" Triggers (Highest Expectancy)
These signals historically capture the most profitable moves, often capitalizing on dealer positioning and volatility mean reversion.

Golden_Setup == 1 (Momentum Acceleration)

Signal: Strong Buy / Trend Continuation.

Rationale: This flag likely represents a confluence of volatility compression (Bandwidth squeeze) and momentum ignition (Price > SMA20). In the dataset, this signal frequently precedes multi-day expansion phases.

History: Appears before significant 5-day rallies (e.g., Nov 2023, Feb 2024). High probability of positive Next5DaysChange.

Negative_GEX_AND_High_VIX == 1 (The "Capitulation Bottom")

Signal: Aggressive Mean Reversion Buy.

Rationale: When dealers are short Gamma (Negative GEX) and implied volatility (VIX) spikes, the market becomes unstable and prone to "V-bottom" reversals due to dealer hedging requirements fading.

History: While rare, this signal often marks local bottoms where selling exhausts itself.

Stock_DarkPoolBuySellRatio < 0.40 (Institutional Distribution)

Signal: Bearish / Caution.

Rationale: Extremely low ratios (< 0.40) indicate that off-exchange volume is dominated by selling pressure. In the latter half of the dataset (late 2025), clusters of low dark pool ratios coincided with short-term price weakness or failed rallies.

2. Tier 2: Trend & Structure (Medium Confidence)
These signals define the market regime and filter Tier 1 trades.

Price_Above_SMA20 vs Price_Above_SMA50 (Trend Alignment)

Signal: Bullish Regime.

Rationale: META performs best when it holds above both the 20-day and 50-day moving averages.

Context: When Price > SMA20 but < SMA50 (current state), the stock is in a "Repair" or "Compression" phase, often leading to chop rather than clean trends.

GEX_ZScore Extremes (Gamma Extension)

Signal: Reversal Warning.

Rationale: Extremely high GEX Z-Scores (> 2.0) often signal that dealer positioning is saturated, leading to a pause or pullback. Conversely, negative Z-scores suggest potential for volatility expansion.

3. Tier 3: Oscillators (Context)
RSI (Relative Strength Index)

Signal: Overbought/Oversold.

Rationale: Standard RSI levels (30/70) apply, but META tends to sustain "Overbought" (>70) conditions during strong Golden_Setup trends. Divergence at neutral levels (40-60) is less predictive.