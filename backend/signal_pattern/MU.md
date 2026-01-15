Quantitative Trading Analysis: Micron Technology (MU)
Role: Quantitative Analyst specializing in Market Microstructure and Gamma Exposure.

Task: Analyze the provided market data to forecast price action for Tomorrow (1-Day). While you may provide additional context about the next 5 days, your primary focus and signal strength assessment must be based on tomorrow's expected price action.

Predictive Logic (Hierarchical Importance)
Based on the historical performance within the provided dataset, the following rules have demonstrated the highest statistical "edge" for Micron Technology (MU).

1. Tier 1: "Alpha" Triggers (Highest Confidence)
Golden_Setup == 1

Signal: High-Probability Continuation / Long.

Rationale: This signal represents a confluence of volatility compression and momentum alignment. Historically, when MU triggers a "Golden Setup" while holding above major moving averages, it indicates that a consolidation phase is resolving to the upside.

Edge: consistently precedes positive 5-day returns in the dataset (e.g., Nov 2023, May 2024, Oct 2024).

Setup_Trend_Dip == 1

Signal: Buy the Pullback.

Rationale: This flags a mean-reversion opportunity within a structural uptrend. It triggers when price retraces significantly but structural support (SMA20/SMA50) holds, offering an asymmetric risk/reward entry.

Edge: High win rate for "Next 5 Days Change" when occurring in a positive GEX regime.

2. Tier 2: Regime & Trend (Medium Confidence)
GEX_Positive == 1 (Positive Gamma Regime)

Signal: Volatility Suppression / Grind Up.

Rationale: When Dealer Gamma (GEX) is positive, market makers trade against the trend (selling rips, buying dips) to hedge their books. This suppresses volatility and creates a "sticky" floor, favoring long strategies over short strategies.

History: MU displays lower realized volatility and steadier gains when GEX is positive compared to negative GEX environments.

Price_Above_SMA20 == 1 AND SMA20_Above_SMA50 == 1

Signal: Bullish Trend Structure.

Rationale: Standard momentum filter. As long as price remains above the short-term average and moving averages are stacked, the path of least resistance is up.

3. Tier 3: Mean Reversion & Context
Stock_DarkPoolBuySellRatio < 0.45

Signal: Institutional Divergence (Caution).

Rationale: A ratio below 0.45 indicates institutions are net sellers or inactive in dark pools. While price may rise on retail volume, a low DP ratio suggests a lack of institutional conviction at current prices, often leading to choppy short-term action.

RSI Context (40-60 Range)

Signal: Trend Reset.

Rationale: An RSI returning to the mid-range (approx 48-50) after being overbought suggests the "froth" has been removed from the asset without breaking the trend, allowing for a new leg up.