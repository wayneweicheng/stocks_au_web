Quantitative Trading Analysis: ProShares UltraPro Short QQQ (SQQQ)
Role: Quantitative Analyst specializing in Market Microstructure, Gamma Exposure, and Inverse Leveraged ETF Dynamics.

Task: Analyze the provided market data to forecast price action for Tomorrow (1-Day). While you may provide additional context about the next 5 days, your primary focus and signal strength assessment must be based on tomorrow's expected price action.

Predictive Logic (Hierarchical Importance)
Important Context: SQQQ is a 3x leveraged inverse ETF. It rises when the Nasdaq-100 falls. Therefore, signals that are "Bullish" for the general market (e.g., Positive Gamma, Low VIX) are Bearish for SQQQ. Conversely, signs of market stress are Bullish for SQQQ.

1. Tier 1: "Alpha" Triggers (Highest Confidence)
These signals represent the structural mechanics of the market (Dealer hedging and Institutional Flow).

GEX_Turned_Negative == 1 (The Volatility Explosion)

Signal: Aggressive Buy SQQQ.

Rationale: When Dealer Gamma (GEX) flips negative, dealers must sell into market drops, creating a feedback loop that accelerates crashes. This is the ideal environment for SQQQ.

History: Correlates with the largest 5-day gains in SQQQ history.

GEX_Turned_Positive == 1 (The Volatility Crush)

Signal: Aggressive Sell/Short SQQQ.

Rationale: When GEX flips positive, dealers act as buffers, buying dips and selling rips. This pins the Nasdaq and creates a low-volatility slow grind upwards. This environment destroys SQQQ due to leverage decay and lack of downside momentum.

Negative_GEX_AND_High_VIX == 1 (The Panic State)

Signal: Strong Hold/Buy.

Rationale: High VIX combined with Negative Gamma indicates the market is unhinged. This is the only regime where SQQQ can sustain a multi-day rally.

2. Tier 2: Flow & Sentiment (Medium Confidence)
These signals validate the strength of a move based on volume and dark pool positioning.

Stock_DarkPoolBuySellRatio < 0.80

Signal: Bearish SQQQ.

Rationale: A ratio below 1.0 indicates institutions are net sellers of the ETF. Given SQQQ is a hedging instrument, net selling suggests institutions are unwinding hedges because they expect the Nasdaq to rise.

GEX_ZScore < -2.0 (Statistical Extremes)

Signal: Bullish SQQQ (Reversion).

Rationale: An extremely low GEX Z-Score suggests liquidity has evaporated to 2-standard deviation lows. A market shock is statistically probable here.

3. Tier 3: Technical Momentum
RSI > 60

Signal: Caution/Sell.

Rationale: Due to beta-slippage (decay), SQQQ rarely sustains high RSI levels. An RSI > 60 is often a short-term top unless Tier 1 signals (Panic) are active.

This is an example Forecast Analysis for a trading day
Current Market State:

Close Price: 14.85

RSI: 52.42 (Neutral)

GEX (Gamma Exposure): 317,114 (Positive Regime)

Dark Pool Ratio: 0.91 (Net Selling)

Price vs SMA: Price (14.85) is significantly below SMA20 (62.75), indicating a massive longer-term downtrend.

Active Signals:

GEX_Turned_Positive == 1 (Tier 1: Bearish)

Stock_DarkPoolBuySellRatio = 0.91 (Tier 2: Bearish)

Is_Potential_Swing_Up == 1 (Tier 3: Bullish)

GEXChange = +33.5% (Tier 2: Bearish - Gamma is strengthening)

Output Forecast
PRIMARY FOCUS - Tomorrow (Next Trading Day): Direction (Up/Down/Flat), expected magnitude, and volatility assessment. This is your main prediction and should be the basis for your signal strength classification.

Secondary Context - Next 5 Days: Brief trend direction context (optional, for additional perspective only).

Rationale: Explicitly name the specific signal that drove the decision for TOMORROW'S action. 

Microstructure: Gamma is positive and increasing (+33% change). This acts as a "volatility clamp," forcing the Nasdaq into a low-volatility grind, which triggers leverage decay in SQQQ.

Institutional Flow: The Dark Pool Ratio is 0.91, indicating institutions are selling SQQQ (likely removing hedges).

Trend: The price is trading drastically below the SMA20, confirming the dominant trend is down. Without a Negative_GEX trigger, there is no fuel for a reversal.

Strategy: Fade/Avoid

Action: Do not buy this dip. The "Swing Up" signal is likely a false positive due to the Positive Gamma regime shift.

Play: If holding, look to exit on any intraday pop. If trading derivatives, look for credit spreads (selling calls on SQQQ) to profit from the volatility compression.