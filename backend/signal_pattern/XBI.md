Quantitative Feature Dictionary: SPDR S&P Biotech ETF (XBI)Role: Quantitative Analyst specializing in Market Microstructure and Alpha Factor ConstructionTask: Deconstruct the predictive features identified in the XBI historical dataset. This report defines the specific "Alpha Factors"—measurable properties of the market that carry statistical predictive power—and details their mechanics and historical signal behavior.1. Microstructure & Gamma Factors (Dealer Positioning)These features track the positioning of Market Makers (Dealers). Dealers are obligated to hedge their options books, and their hedging flows can accelerate or dampen price moves.Net Gamma Exposure (GEX)Definition: The aggregate dollar value of Gamma exposure held by Market Makers across all option strikes.Mechanism:

**IMPORTANT INSTRUCTION:** When analyzing this data and providing your forecast, focus **primarily on tomorrow's (next trading day) expected price action**. While you may reference longer-term trends for context, your signal strength classification MUST be based on tomorrow's expected move, not multi-day projections.

---


Positive GEX (> $0): Dealers are "Long Gamma." They buy when price drops and sell when price rises to hedge. This dampens volatility and pins price.
Negative GEX (< $0): Dealers are "Short Gamma." They must sell when price drops (to hedge puts) and buy when price rises (to hedge calls). This accelerates volatility and trend extension.
Predictive Detail: In XBI, Negative GEX regimes often precede the largest 5-day directional moves (both crashes and "squeeze" rallies).Negative_GEX_AND_High_VIX (The Capitulation Flag)Signal Type: Contrarian Reversal (Bullish)Logic: When Dealer Gamma is negative (accelerating downside) AND Volatility (VIX) is already high, the market is typically in a state of panic selling.Edge: Historically marks local bottoms. Once the selling pressure exhausts, the "Short Gamma" dealers are forced to buy back aggressively, fueling a V-shaped recovery.Stock_DarkPoolBuySellRatioDefinition: The ratio of buying volume to selling volume executed in "Dark Pools" (off-exchange private venues used by institutions).Logic:

Ratio > 1.0: Net Institutional Accumulation
Ratio > 1.5: Aggressive Accumulation (Strong Buy Signal)
Ratio < 1.0: Net Distribution (Selling)
Predictive Detail: This is a leading indicator. Price often consolidates while this ratio climbs, followed by a breakout 2-5 days later as the public market catches up to the institutional flow.2. Momentum & Technical FactorsThese features identify the strength and sustainability of the current price trend.Golden_SetupDefinition: A proprietary boolean (True/False) flag indicating a perfect alignment of trend, momentum, and volatility. Typically involves Price > SMA20 > SMA50 and a rising MACD.Signal Type: Trend ContinuationEdge: When Golden_Setup == 1, the probability of the "Next 5 Days Change" being positive is statistically significantly higher than random. It suggests the stock is in a "markup" phase.RSI (Relative Strength Index)Definition: Momentum oscillator measuring the speed and change of price movements.Regime Specifics for XBI:

RSI > 70 (Standard): Overbought, but in a Negative GEX regime, this can sustain for weeks (Squeeze)
RSI > 80 (Extreme): "Climax Top." Historically, XBI struggles to sustain RSI > 80 without a 3-5% mean reversion pullback within the next 1-3 days
RSI < 30 (Oversold): "Panic Bottom." High win-rate buy signal when combined with Stock_DarkPoolBuySellRatio > 1.0
BB_PercentB (Bollinger Band %B)Definition: Quantifies where price is relative to the Bollinger Bands.

> 1.0: Price is above the upper band
< 0.0: Price is below the lower band
Predictive Detail:

Breakout (> 1.0): If accompanied by Volume, this signals a "Volatility Expansion" to the upside
Mean Reversion (> 1.1 or < -0.1): If price pushes too far past the bands (e.g., > 1.1), it acts as a rubber band snapping back to the mean (SMA 20)
3. Factor Hierarchy (Decision Matrix)When features conflict (e.g., "Bullish Trend" vs. "Overbought RSI"), use this hierarchy to determine the likely outcome.TierFactor CategoryPriorityRule of Thumb1Gamma (GEX)HighestVolatility trumps Direction. If GEX is highly Negative, expect large ranges and ignore minor overbought/oversold signals.2Dark Pool FlowHighFlow leads Price. If Price is falling but Dark Pool Ratio is > 1.5, expect a reversal (Bear Trap).3Golden SetupMediumTrend is your friend, until Tier 1 disagrees. Use this for directional bias in calm markets (Positive GEX).4RSI / MACDLowContext only. Use for timing entries/exits, but never trade these in isolation against Tier 1 or 2 factors.