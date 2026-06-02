Quantitative Signal Framework: Occidental Petroleum (OXY)

**IMPORTANT INSTRUCTION:** When analyzing this data and providing your forecast, focus **primarily on tomorrow's (next trading day) expected price action**. While you may reference longer-term trends for context, your signal strength classification MUST be based on tomorrow's expected move, not multi-day projections.

---

Target Asset: OXY (Energy Sector / Exploration & Production) Data Regime: High sensitivity to institutional flows (Dark Pools) and Dealer Gamma hedging.

1. Tier 1: "Alpha" Signals (Highest Predictive Value)
These signals have shown the strongest correlation with Next5DaysChange in the dataset.

Signal A: The "Golden Setup"
Condition: Golden_Setup == 1

Predictive Direction: Bullish (Trend Continuation)

Detailed Logic: This binary flag likely represents a confluence of momentum indicators (e.g., price above SMA20/50, rising RSI, positive MACD). In the provided data, when this signal triggers, OXY rarely suffers a significant drawdown in the subsequent week. It captures the "sweet spot" of a trend.

Historical Evidence (from data):

Feb 2024 Streak: From Feb 15 to Feb 29, the Golden_Setup was active almost daily. The stock rallied from ~$57 to ~$61, consistently posting positive Next5DaysChange values (e.g., +2.08%, +4.43%, +5.62%).

Action: Execute Long positions or Hold existing trends.

Signal B: Deep Negative Gamma Reversion
Condition: GEX_ZScore < -2.0 (often coincides with Negative_GEX_AND_High_VIX == 1)

Predictive Direction: Bullish Mean Reversion (The "Snapback")

Detailed Logic: When the Gamma Exposure Z-Score drops below -2.0, dealer positioning is extremely short gamma (over-hedged). Dealers are forced to sell into drops, exacerbating the decline until it reaches a "washout" point. Once the selling exhausts, the need to buy back hedges triggers a sharp, violent rally.

Historical Evidence:

Oct 28-30, 2024: GEX_ZScore hit extreme lows of -2.52 and -3.20. While the immediate TomorrowChange was mixed, the Next5DaysChange turned positive (+1.89%) shortly after, marking a local floor before a stabilization phase.

Action: Look to accumulate on weakness ("Catch the falling knife" with tight stops) or sell Puts to harvest the high implied volatility.

Signal C: The Dark Pool "Capitulation" Buy
Condition: Stock_DarkPoolBuySellRatio < 0.40 (Extreme Low) followed by a Price Reversal

Predictive Direction: Contrarian Long

Detailed Logic: A ratio below 0.40 indicates panic selling or massive institutional distribution. In OXY, these extreme lows often mark the end of a selling climax rather than the beginning. The market runs out of sellers.

Historical Evidence:

Aug 13, 2024: Ratio dropped to 0.33. The stock price was ~$60. Over the next 10 days, the stock stabilized, avoiding further collapse.

Oct 24, 2024: Ratio dropped to 0.30. The stock bottomed near ~$19 and stabilized.

Action: Watch for this signal to print, then enter Long once the price closes green the following day.

2. Tier 2: Regime & Trend Filters (Context)
These signals determine the "weather" of the market (Volatility State).

Signal D: Negative Gamma Regime
Condition: GEX < 0 (or GEX_Turned_Negative == 1)

Market State: High Volatility / Expansion

Detailed Logic: When GEX is negative, market makers amplify price moves (selling lows, buying highs). This does not guarantee a crash, but it guarantees expanded range. OXY often sees its largest % moves (both up and down) in this regime.

Data Insight: The period in late 2025 (Dec 10-17) shows persistent Negative Gamma. This period saw erratic price swings and increased volatility compared to the stable Positive Gamma periods in early 2024.

Strategy: Switch from Trend Following to Mean Reversion (buy support, sell resistance) or long volatility strategies (Straddles/Strangles).

Signal E: Bollinger Band Squeeze (Low Volatility)
Condition: BB_Bandwidth is decreasing and GEX > 0

Market State: Accumulation / Compression

Detailed Logic: Positive Gamma suppresses volatility (dealers buy dips, sell rips). When combined with narrowing Bollinger Bands, OXY enters a "coiling" phase.

Strategy: Do not trade breakouts yet. Trade Delta-Neutral income strategies (Iron Condors) until GEX drops or bands expand.

3. Tier 3: Execution Triggers (Timing)
Used to refine entry/exit points.

RSI > 75 (Hyper-Extension): Unlike many stocks where RSI > 70 is a sell, in OXY's dataset, RSI > 75 often occurs during the Golden Setup runs (e.g., Feb 2024). Do not short solely on high RSI if the Golden_Setup is active.

MACD_Positive == 0 (Bearish Cross): A reliable filter to avoid Longs. If MACD is negative, avoid entering new Tier 1 Longs unless a Tier 1 Reversion signal (Signal B) triggers.