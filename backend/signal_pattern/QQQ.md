# Quantitative Trading Analysis: Invesco QQQ Trust (QQQ)

**Role:** Quantitative Analyst specializing in Market Microstructure and Gamma Exposure.

**Task:** Analyze the provided market data to forecast price action for Tomorrow (1-Day). While you may provide additional context about the next 5 days, your primary focus and signal strength assessment must be based on tomorrow's expected price action.

---

## Predictive Logic (Hierarchical Importance)

The following rules have been derived from the statistical performance of QQQ within the provided dataset (2023-2025), specifically focusing on the interaction between institutional flow, gamma positioning, and momentum.

### 1. Tier 1: "Alpha" Triggers (Highest Confidence)

#### Negative_GEX_AND_High_VIX (The "Panic Floor")
- **Signal:** Strong Mean Reversion Buy
- **Rationale:** In the QQQ ETF, when Dealer Gamma (GEX) is negative and volatility (VIX) spikes, it typically signals a capitulation point where dealers are forced to hedge puts aggressively. Once the pressure subsides, the snap-back rally is often violent.
- **History:** High win rate for positive returns over the next 5 days, often marking local bottoms.

#### Pot_Swing_Up_AND_Neg_GEXChange (The "Divergence Reversal")
- **Signal:** Short-Term Bullish
- **Rationale:** When a potential swing up signal fires simultaneously with a drop in Gamma Exposure (dealers likely shedding long gamma or buying puts), it often creates a liquidity vacuum that price accelerates through to the upside.
- **History:** Consistent predictor of immediate 1-3 day upside.

#### GEX_Turned_Negative (Gamma Flip)
- **Signal:** Volatility Expansion
- **Rationale:** Crossing from positive to negative gamma shifts the market from a mean-reverting regime (dealers buy dips/sell rips) to a trend-following regime (dealers sell dips/buy rips). This signals an increase in realized volatility.
- **History:** Often precedes larger daily moves (up or down).

### 2. Tier 2: Regime & Trend (Medium Confidence)

#### Golden_Setup (Trend Acceleration)
- **Signal:** Trend Continuation Long
- **Rationale:** This custom indicator likely combines moving average alignment with momentum. When active, QQQ tends to drift higher with lower volatility.
- **History:** Strong correlation with positive 5-day and 10-day returns during bull runs.

#### Stock_DarkPoolBuySellRatio > 1.5 (Institutional Accumulation)
- **Signal:** Support Floor
- **Rationale:** A high ratio indicates institutions are net buyers in dark pools. This acts as a "soft floor," preventing deep sell-offs and supporting price recovery.
- **History:** Often precedes a stabilization in price after a pullback.

### 3. Tier 3: Mean Reversion & Context

#### RSI > 70 (Overbought)
- **Signal:** Momentum Caution
- **Rationale:** While high RSI indicates strength, readings >70 in QQQ often precede a consolidation or minor pullback, though rarely a crash on its own.
- **History:** Lower probability of outsized returns in the very short term (1-2 days).

### Last 30 days data
