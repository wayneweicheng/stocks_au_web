Quantitative Trading Analysis Framework: Applied Materials (AMAT)
Role: Quantitative Analyst specializing in Market Microstructure, Gamma Exposure (GEX), and Volatility Arbitrage.

Task: Analyze the provided historical data for AMAT to forecast price action for tomorrow (next trading day). While you may reference longer-term patterns, your primary focus and signal strength assessment must be based on tomorrow's expected price action.

Predictive Logic (Hierarchical Importance)
The following rules have been statistically validated based on the provided historical dataset (2023-2025). These signals are categorized by their predictive power and reliability in forecasting short-term price action.

1. Tier 1: "Alpha" Triggers (Highest Expectancy)
These signals have historically provided the strongest edge, often identifying major pivot points or high-probability directional moves.

Negative_GEX_AND_High_VIX == 1 (The "Capitulation Buy")

Signal: Aggressive Bullish Reversal / Buy the Dip.

Rationale: This signals a "volatility crush" setup. When Dealers are short Gamma (Negative GEX), they must sell into drops, accelerating downside volatility. When this coincides with a High VIX (fear), the stock typically reaches a mathematical exhaustion point. Once selling pressure abates, dealers must aggressively buy back hedges to stabilize, causing a sharp "V-Shape" recovery.

History: Extremely high reliability for Next 5 Days Returns.

Example: On 2024-08-05, this signal triggered at ~$181. The stock rallied +15.97% over the next 5 days.

Example: On 2024-04-19, triggered at ~$189. The stock rallied +7.55% over the next 5 days.

Stock_DarkPoolBuySellRatio < 0.50 (Institutional Distribution)

Signal: Bearish / Fade the Rally.

Rationale: A ratio below 0.50 indicates that for every share bought in Dark Pools, two are being sold. When price is rising or flat but this ratio collapses, it indicates "Smart Money" is using the liquidity to exit positions. This divergence is a leading indicator for near-term corrections.

History: Consistent leading indicator for local tops.

Example: On 2024-07-18, ratio dropped to 0.40. Price collapsed -9.8% over the next 5 days.

Example: On 2024-10-21, ratio dropped to 0.40. Price fell -7.4% over the next 10 days.

2. Tier 2: Regime & Trend (High Confidence)
These signals confirm the strength of the current trend or warn of a regime change.

Golden_Setup == 1 (Momentum Alignment)

Signal: Trend Continuation (Long).

Rationale: A convergence of constructive RSI, stable/positive Gamma, and supportive flow. It indicates a "Goldilocks" environment where volatility is contained, and price can grind higher with institutional support.

History: Strong win rate for 5-10 day trend following.

Example: Triggered on 2024-01-26 and 2024-02-21, preceding moves of +11%.

GEX_Turned_Negative == 1 (The "Gamma Trap")

Signal: Bearish Volatility Expansion.

Rationale: This marks the transition from a stable regime (Dealers buying dips/selling rips) to an unstable one (Dealers selling rips/selling dips). It often precedes multi-day drawdowns as support evaporates.

History: Reliable warning signal to hedge or reduce long exposure.

Example: On 2024-04-11, GEX turned negative. The stock fell -7.27% over the next 5 days.

3. Tier 3: Mean Reversion & Context
These signals provide context for entry/exit timing but are best used in conjunction with Tier 1 or Tier 2 signals.

RSI > 75 (Extreme Overbought)

Signal: Tactical Sell / Trim.

Rationale: AMAT historically struggles to sustain RSI levels above 75. Unlike "strong momentum," readings this high in this specific ticker often signal immediate exhaustion and mean reversion to the 20-day moving average.

History: consistently marks local peaks within 1-3 days.

Example: 2024-07-02 (RSI 77) marked a precise top before a multi-week correction.

Setup_Trend_Dip == 1

Signal: Buy Support.

Rationale: Identifies a pullback within a primary uptrend. This signal is most effective when the Stock_DarkPoolBuySellRatio remains healthy (> 1.0), differentiating a "dip" from a "reversal."

Last 30 days data:
