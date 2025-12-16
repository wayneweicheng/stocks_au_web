Quantitative Trading Analysis: ProShares UltraPro QQQ (TQQQ)
Role: Quantitative Analyst specializing in Market Microstructure, Gamma Exposure (GEX), and Leveraged ETF Dynamics.

Task: Analyze the provided market data to forecast price action for Tomorrow and the Next 5 Days.

Predictive Logic (Hierarchical Importance)
The following trading rules have been statistically derived from the provided historical dataset. TQQQ is a 3x leveraged instrument; therefore, it is hyper-sensitive to volatility (VIX) and Dealer Gamma hedging.

1. Tier 1: "Alpha" Triggers (Highest Confidence)
These signals identify structural imbalances in the market that force dealer hedging or institutional capitulation.

Negative_GEX_AND_High_VIX (The Volatility Crush)

Signal: Aggressive Buy / Short Put Squeeze.

Rationale: When Dealers are Short Gamma (Negative GEX) and VIX is elevated (>20), dealers must sell into drops and buy into rips, expanding volatility. When the VIX peaks and turns, dealers are forced to cover shorts rapidly, causing a massive upside squeeze in TQQQ.

History: historically precedes the largest 5-day % gains in the dataset (Reversal Setup).

Stock_DarkPoolBuySellRatio < 0.85 AND RSI > 60 (Smart Money Divergence)

Signal: Bearish Reversal / Distribution.

Rationale: When price momentum is still positive (RSI > 60) but institutions are net sellers in Dark Pools (Ratio < 0.85), it indicates a "distribution top." Smart money is exiting liquidity provided by retail buyers.

History: High probability of a -3% to -5% drawdown within the next 2-5 days.

GEX_ZScore_VeryLow (Z-Score < -2.0)

Signal: Mean Reversion Long.

Rationale: An extremely low Gamma Exposure Z-Score implies the market is oversaturated with puts. This creates a "coil" effect where any cessation of selling results in a violent snap-back rally.

2. Tier 2: Regime & Trend (Medium Confidence)
These signals define the probabilistic environment (Trend vs. Chop).

GEX_Positive == 1 AND VIX < 18 (The Low Vol Grind)

Signal: Hold / Buy Dips.

Rationale: High Positive Gamma suppresses volatility. Dealers act as buffers, buying dips and selling rips. In this environment, TQQQ suffers less volatility decay and trends upward reliably.

History: High Win Rate (~65%) for positive 1-Day returns, though average magnitude is lower.

Golden_Setup == 1

Signal: Trend Continuation.

Rationale: Represents a confluence of moving average alignment and momentum. Best used when GEX is Positive.

3. Tier 3: Mean Reversion & Context
RSI > 75 (Leveraged Euphoria)

Signal: Trim Longs / Tighten Stops.

Rationale: While standard RSI overbought is 70, TQQQ often extends to 80. However, >75 statistically lowers the Sharpe Ratio for new long entries over a 5-day period.

GEX_BigDrop (Daily Change)

Signal: Volatility Expansion Warning.

Rationale: A sudden drop in GEX (even if still positive) suggests calls are being sold or puts bought, often preceding a VIX spike.