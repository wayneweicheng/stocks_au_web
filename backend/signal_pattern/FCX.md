Quantitative Trading Analysis Framework: Freeport-McMoRan Inc. (FCX)
Role: Quantitative Analyst specializing in Market Microstructure, Gamma Exposure (GEX), and Momentum Strategies.

Task: Analyze the provided historical data (ending 2025-12-11) to forecast price action for Tomorrow and the Next 5 Days.

Data Note: The VIX included in the dataset represents the S&P 500 Volatility Index, serving as a macro risk proxy, not the implied volatility of FCX specifically.

Predictive Logic (Hierarchical Importance)
The following signals have been isolated as statistically significant "edges" based on the provided multi-year dataset for FCX. This stock exhibits strong momentum characteristics, often extending gains well past traditional "overbought" levels when specific microstructure conditions are met.

1. Tier 1: "Alpha" Triggers (Highest Expectancy)
Golden_Setup == 1 (Momentum Acceleration)

Signal: Aggressive Long.

Rationale: This proprietary flag appears to identify the convergence of trend alignment (SMA20 > SMA50) and volatility expansion. In the provided history, this signal frequently precedes multi-day expansion phases (the "fat tails" of the distribution).

History: High correlation with top-quartile Next5DaysChange returns.

RSI > 80 + BB_Breakout_Upper == 1 (The "Parabolic Squeeze")

Signal: Momentum Continuation (Blow-off Top).

Rationale: While traditional analysis suggests shorting RSI > 70, FCX demonstrates a "Hyper-Momentum" regime. When Price breaks the Upper Bollinger Band while RSI is already elevated, it indicates a gamma squeeze or FOMO chase where price rips higher rapidly before a crash.

History: Consistently leads to positive TomorrowChange despite extreme overbought readings.

2. Tier 2: Regime & Gamma (Medium Confidence)
GEX_ZScore_High == 1 (Positive Gamma Regime)

Signal: Buy Dips / Hold.

Rationale: When GEX Z-Score is high (Positive Gamma), Market Makers are long gamma and trade against price moves (buying dips, selling rips). This dampens volatility but creates a steady "drift" upward if macro flows (VIX < 20) are benign.

Context: Currently active. High GEX suggests a "Grind Up" rather than a choppy range.

Stock_DarkPoolBuySellRatio < 1.0 + Price > SMA20 (Divergence Warning)

Signal: Caution / Trailing Stop.

Rationale: When price is rising but Dark Pool flows are net selling (< 1.0), institutions are providing liquidity to retail buyers (distributing). This suggests the trend is nearing exhaustion, though price may drift higher on inertia.

3. Tier 3: Macro & Support
VIX < 20 (Risk-On Context)

Signal: Risk-On.

Rationale: FCX (Copper/Mining) is a high-beta asset. It historically underperforms significantly when SP500 VIX spikes above 20. Current low VIX supports long exposure.