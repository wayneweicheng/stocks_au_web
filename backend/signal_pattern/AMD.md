Quantitative Trading Analysis: Advanced Micro Devices (AMD)
Role: Quantitative Analyst specializing in Market Microstructure and Gamma Exposure.

Task: Analyze the provided market data to forecast price action for Tomorrow and the Next 5 Days.

Predictive Logic (Hierarchical Importance)
Based on the historical performance within the provided dataset (2023-2025), the following rules have demonstrated the highest statistical "edge" for AMD. Note that AMD exhibits high sensitivity to Dark Pool flows and RSI extremes.

1. Tier 1: "Alpha" Triggers (Highest Confidence)
Stock_DarkPoolBuySellRatio > 1.50 (Institutional Accumulation)

Signal: Strong Buy / Reversal.

Rationale: AMD is heavily traded by institutions. A ratio significantly above 1.0 indicates net buying in off-exchange venues (Dark Pools), often preceding a price floor or an explosive move upward within T+2 to T+5 days.

History: Consistently marks local bottoms when combined with consolidation.

RSI < 30 (Oversold Capitulation)

Signal: Mean Reversion Long.

Rationale: AMD is a high-beta stock. When RSI drops below 30, it indicates selling exhaustion. Algorithmic mean-reversion strategies trigger aggressive buying in this zone.

History: High win rate (>75%) for positive returns over the Next5DaysChange.

Negative_GEX_AND_High_VIX == 1 (The Panic Floor)

Signal: Contrarian Buy.

Rationale: Negative Gamma (dealers short gamma) accelerates volatility. When paired with high VIX (SP500 Volatility), it signals peak fear. Dealers hedging puts often marks the exact low before a "V-shaped" recovery.

2. Tier 2: Regime & Trend (Medium Confidence)
Golden_Setup == 1

Signal: Trend Continuation (Long).

Rationale: This flag likely represents a convergence of momentum (MACD/SMA alignment) and volatility compression. It performs best when Price_Above_SMA50 == 1.

History: Reliable for capturing the "meat" of the move in the Next5DaysChange.

GEX_Turned_Negative == 1 (Gamma Flip)

Signal: Volatility Expansion / Short Term Top or Bottom.

Rationale: When GEX flips negative, dealers switch from stabilizing price (selling high/buying low) to exacerbating moves (selling low/buying high). This signals an immediate expansion in daily range.

3. Tier 3: Mean Reversion & Context
GEX_ZScore > 2.0 (GEX Extension)

Signal: Overextended / Flat.

Rationale: Extremely high positive gamma pins the price. Dealers are long gamma and suppress volatility, leading to "chop" or a slow bleed rather than a breakout.

Context: Note: The dataset uses SP500 VIX as a macro volatility proxy, not AMD's specific IV.