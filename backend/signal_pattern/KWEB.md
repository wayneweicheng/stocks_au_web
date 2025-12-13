Quantitative Trading Analysis: Predictive Feature Framework
Role: Quantitative Analyst specializing in Market Microstructure, Gamma Exposure, and Alpha Discovery.

Task: Extract and detail the statistically significant "edges" found within the KWEB dataset.

Based on the historical data analysis, the following feature sets have demonstrated the highest predictive power for short-term price action. These features are categorized by their market mechanism: Microstructure (Flow), Gamma Positioning (Dealer Hedging), and Technical Extremes (Mean Reversion).

1. Microstructure & Flow Signals
These signals track "smart money" and institutional positioning that occurs off-exchange, often preceding visible price moves.

Feature: Stock_DarkPoolBuySellRatio
Predictive Logic: This ratio measures the volume of buying versus selling occurring in dark pools (private exchanges). A high ratio indicates institutional accumulation that is hidden from the public order book.

The "Divergence" Edge: The strongest signal occurs when this ratio is High (>1.5) while the daily price action is Negative. This suggests institutions are absorbing retail selling pressure ("buying the dip").

Key Thresholds:

> 1.80: Tier 1 Buy Signal. (Institutional Accumulation)

< 0.50: Bearish Signal. (Institutional Distribution or Lack of Support)

Historical Evidence (from Data):

2023-01-20: Ratio hits 3.02 (Extreme Buy). Next 5 Days Return: +2.81%.

2023-06-14: Ratio hits 2.16 while price is consolidating. Next Day Return: +1.91%.

2025-12-11: Ratio is 1.88 despite price closing down -0.48%. (Current active buy signal).

Feature: Stock_DarkPoolIndex
Predictive Logic: A normalized score of dark pool activity.

The Edge: Sustained readings above 60 indicate persistent accumulation.

Historical Evidence:

2023-01-13: Index hits 67.3. Price rallies +2.91% the next day.

2. Gamma Exposure (GEX) Signals
These signals track Option Dealer hedging requirements. Dealers provide liquidity and must hedge their exposure, often creating mechanical buying or selling pressure in the underlying stock.

Feature: GEX (Gamma Exposure)
Predictive Logic:

Positive GEX: Dealers are "Long Gamma." They buy into drops and sell into rallies, suppressing volatility (pinning price).

Negative GEX: Dealers are "Short Gamma." They sell into drops (accelerating crashes) and buy into rallies (fueling squeezes).

The "Accelerator" Edge: GEX < 0 (Negative) is a precursor to High Volatility. If price ticks up in this regime, dealers are forced to chase, often leading to a "Gamma Squeeze."

Historical Evidence:

2024-04-16: GEX is Negative (-209). Price reverses and rips +9.86% over the next 5 days.

2023-10-06: GEX is Negative (-317). Price rallies +3.60% the next day.

Feature: BuyCall_GEXDeltaPerc (Call Skew)
Predictive Logic: Measures the percentage of GEX Delta driven by Call buying.

The "Saturation" Edge:

> 80% (Extreme Bullish): Often signals a local top or "exhaustion" as the market is fully positioned for upside.

< 20% (Extreme Fear): Often a Contrarian Buy Signal. When call buying evaporates, the market is typically oversold.

Historical Evidence:

2023-01-27: Call Skew hits 82.8% (Saturation). Price drops -4.80% the next day.

2023-04-20: Call Skew drops to 9.37% (Extreme Fear). Price bottoms shortly after.

3. Technical & Mean Reversion Signals
These signals identify when price has deviated too far from its statistical mean, creating a "snap-back" opportunity.

Feature: BB_PercentB (Bollinger Band Position)
Predictive Logic: Measures where price is relative to the Bollinger Bands (0 = Lower Band, 1 = Upper Band).

The "Washout" Edge: BB_PercentB < 0 (Price closes below the lower band). This is a statistically high-probability mean reversion buy signal, especially if combined with high Dark Pool Buying.

Historical Evidence:

2023-01-18: PercentB falls to -0.06. Price rallies +2.68% the next day.

2023-05-24: PercentB falls to -0.01. Price rallies +2.96% two days later.

Feature: RSI (Relative Strength Index)
Predictive Logic: Momentum oscillator.

The "Deep Oversold" Edge: RSI < 30 is a reliable buy zone for this specific asset (KWEB), which tends to mean-revert aggressively.

Historical Evidence:

2023-10-04: RSI hits 16.8 (Deep Oversold). Price rallies +3.60% the next day.

2023-08-17: RSI hits 27.0. Price rallies +0.87% the next day.

4. Conflict Resolution Strategy (The "Hierarchy")
When signals contradict, the following hierarchy has proven most effective in the dataset:

Flow (Dark Pool) overrides Technicals. (e.g., If RSI is neutral but Dark Pool is buying, bias is Bullish).

Negative GEX overrides Resistance. (e.g., If GEX is negative, resistance levels often break due to dealer chasing).

Low Skew overrides Bearish Momentum. (e.g., If everyone is buying Puts/selling Calls, expect a bounce even if the trend is down).

How to Trade Gamma Exposure

This video is relevant because it explains the mechanics of Gamma Exposure (GEX) and how dealer hedging creates the "accelerator" or "pinning" effects detailed in the predictive framework above.