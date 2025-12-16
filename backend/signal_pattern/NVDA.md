# Quantitative Trading Analysis: NVIDIA Corporation (NVDA)

**Role:** Quantitative Analyst specializing in Market Microstructure and Gamma Exposure.

**Task:** Analyze the provided market data to forecast price action for **Tomorrow** and the **Next 5 Days**.

---

## Predictive Logic (Hierarchical Importance)

The following rules have been statistically derived from the provided historical dataset (2023–2025). The analysis prioritizes Gamma Exposure (GEX) inflection points and Dark Pool flows, which have shown higher predictive power for NVDA than standard technicals.

### 1. Tier 1: "Alpha" Triggers (Highest Confidence)

* **`Pot_Swing_Up_AND_Neg_GEXChange == 1` (The "Liquidity Trap")**
    * **Signal:** **Short-Term Long.**
    * **Rationale:** This setup occurs when price action signals a potential swing up, but Dealer Gamma has dropped significantly (Negative GEX Change). This counter-intuitive signal often indicates dealers are offloading hedges into a price floor, creating a liquidity trap that propels price upward as selling pressure exhausts.
    * **History:** Strong reliability for 1-Day and 2-Day bounces in the dataset.

* **`GEX_Turned_Negative == 1` (The "Gamma Flip")**
    * **Signal:** **Volatility Expansion / Reversal.**
    * **Rationale:** For NVDA, flipping to negative GEX often marks a local bottom or a high-volatility pivot point. Unlike indices where negative gamma accelerates selling, in single-stock leaders like NVDA, it often signals that put protection has peaked, leading to a sharp mean-reversion rally.
    * **History:** High win rate for positive returns over the Next 5 Days when VIX is stable.

* **`Golden_Setup == 1` (Momentum Ignition)**
    * **Signal:** **Trend Continuation Long.**
    * **Rationale:** This flag typically combines trend alignment (Price > SMA20) with favorable microstructure. It acts as a "green light" for momentum algorithms.
    * **History:** Consistently precedes multi-day runs.

### 2. Tier 2: Regime & Trend (Medium Confidence)

* **`Stock_DarkPoolBuySellRatio < 0.60` (Institutional Divergence)**
    * **Signal:** **Contrarian Bullish (Dip Buy).**
    * **Rationale:** Historically in this dataset, extremely low Dark Pool Buy/Sell ratios (below 0.60 or 0.50) often precede price bottoms. It suggests passive accumulation or a "washout" of retail selling while institutions hold the line.
    * **History:** Often marks the low of a swing.

* **`BB_PercentB < 0` (Bollinger Overshoot)**
    * **Signal:** **Mean Reversion.**
    * **Rationale:** Price closing below the lower Bollinger Band is a statistical anomaly for a growth stock like NVDA. It almost invariably leads to a snap-back rally to the SMA20.

### 3. Tier 3: Mean Reversion & Context

* **`RSI < 40` (Soft Oversold)**
    * **Signal:** **Watch for Reversal.**
    * **Rationale:** NVDA rarely stays below RSI 40 in a bull market.
* **`GEX_ZScore > 2.0`**
    * **Signal:** **Resistance/Stall.**
    * **Rationale:** Extremely high positive Gamma acts as a dampener on volatility, often causing price to grind sideways or slowly bleed lower.

---

## An example Forecast Analysis for a random date, use this as example output, don't use this data.

**Current Market State:**
* **Close:** 183.78
* **Key Indicators:**
    * **RSI:** 46.95 (Neutral/Bearish)
    * **GEX:** 2,665,369 (Positive, High)
    * **GEX Z-Score:** 1.43 (Moderate Positive)
    * **Stock_DarkPoolBuySellRatio:** 0.70 (Neutral/Low)
    * **VIX:** 15.77 (Stable)
    * **Price vs SMA:** Price (183.78) is **Below** SMA20 (183.18) but fighting to reclaim it.
* **Active Signals:**
    * **Tier 1:** None active. (Previous day 12-09 had `Pot_Swing_Up_AND_Neg_GEXChange` and `Golden_Setup`, but those signals failed to hold the 1-day gains).
    * **Tier 2:** `Stock_DarkPoolBuySellRatio` is 0.70 (Approaching the buy zone but not extreme).
    * **Tier 3:** `GEX_Turned_Negative` is 0 (GEX is positive). `GEX_Change` was negative (-0.88), showing gamma remains steady.

### Output Forecast

**Immediate (Tomorrow):** **Bearish / Flat**
* **Assessment:** The "Golden Setup" from 12-09 failed to produce a follow-through day (TodayChange was -0.64). With Price hovering just above the SMA20 (183.18) and RSI failing to break 50, momentum is stalling. The lack of a Tier 1 trigger today suggests a lack of immediate catalysts. The moderate positive GEX (Z-score 1.43) will likely dampen volatility, pinning the price near current levels or drifting lower.

**Short Term (Next 5 Days):** **Neutral / Mildly Bearish**
* **Rationale:** The market is in a "waiting" regime. We saw a "Golden Setup" recently fail, which is a bearish character change. However, we are not in a high-volatility crash zone (VIX is low). The Dark Pool Ratio at 0.70 suggests institutions are indifferent—neither aggressively buying nor selling.
* **Key Level:** Watch the SMA20 at **183.18**. A close below this level confirms the failed breakout and likely targets the lower Bollinger Band (~174).

**Strategy:** **Wait for Confirmation / Fade Rallies**
* **Action:** The edge is currently weak. Do not chase long positions here as recent buy signals failed.
    * *If* Price closes below 183.18, initiate short-term hedges.
    * *If* Dark Pool Ratio drops below 0.50 over the next 2 days, look to buy the dip for a mean reversion trade.

## Data (Last 30 Days)

[INSERT DATA HERE]