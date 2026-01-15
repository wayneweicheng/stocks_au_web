# Quantitative Trading Analysis Framework: Tesla, Inc. (TSLA)

**Role:** Quantitative Analyst specializing in Market Microstructure, Gamma Exposure (GEX), and Volatility Arbitrage.

**Task:** Analyze the provided recent market data snippet for TSLA to forecast price action for **Tomorrow (1-Day)**. While you may provide additional context about the next 5 days, your primary focus and signal strength assessment must be based on tomorrow's expected price action.

---

## Predictive Logic (Hierarchical Importance)

The following rules have been statistically validated based on 2 years of historical data. Note that for TSLA, certain signals (like Negative Gamma) behave inversely to broad market indices, acting as aggressive buy signals rather than crash indicators.

### 1. Tier 1: "Alpha" Triggers (Highest Expectancy)

These signals have historically provided the strongest edge and highest win rates.

* **`Negative_GEX_AND_High_VIX == 1` (The "Capitulation Buy")**
    * **Signal:** **Extreme Buy.**
    * **Rationale:** When Dealer Gamma is negative and Volatility is high, TSLA consistently bottoms and rips higher due to short covering and mean reversion.
    * **Reliability:** Historically 100% Win Rate. 5-Day Average Return: >+10%.

* **`GEX_Turned_Negative == 1` (The "Bear Trap")**
    * **Signal:** **Bullish Reversal.**
    * **Rationale:** Unlike indices where negative GEX implies crashing, for TSLA this signal often marks a local washout where dealers hedging puts marks the low.
    * **Reliability:** ~67% Win Rate. Strong 1-Day upside expectancy.

* **`RSI < 30` (Deep Oversold)**
    * **Signal:** **Mean Reversion Buy.**
    * **Rationale:** TSLA is highly responsive to deep oversold conditions.
    * **Reliability:** ~70% Win Rate.
    * **Booster:** If `Stock_DarkPoolBuySellRatio > 1.5` coincides with `RSI < 30`, the signal confidence increases to near 100%.

### 2. Tier 2: Momentum & Breakouts (High Confidence)

These signals confirm trend strength and continuation.

* **`BB_PercentB > 1.0` (Bollinger Breakout)**
    * **Signal:** **Momentum Long.**
    * **Rationale:** Price closing above the Upper Bollinger Band signals a volatility expansion breakout, typically indicating further upside rather than a top.
    * **Reliability:** Strong 5-Day trend continuation stats.

* **`Golden_Setup == 1` (Trend Continuation)**
    * **Signal:** **Steady Accumulation.**
    * **Rationale:** A convergence of momentum and volatility compression.
    * **Reliability:** ~71% Win Rate for 5-Day returns.

* **`RSI > 75` (Hyper-Momentum)**
    * **Signal:** **Trend Extension (Do Not Short).**
    * **Rationale:** Contrary to standard RSI rules, TSLA entering "extreme overbought" (>75) territory often signals a squeeze phase.
    * **Reliability:** Positive expectancy for 5-Day returns; shorting here is historically dangerous.

### 3. Tier 3: Support & Flow (Context)

These signals provide context for support levels and potential floors.

* **`Stock_DarkPoolBuySellRatio > 2.0`**
    * **Signal:** **Institutional Floor.**
    * **Rationale:** Indicates strong net buying pressure in dark pools, often acting as a soft floor for price action.

* **`MACD_Positive == 0` (Bearish MACD)**
    * **Signal:** **Contrarian Buy.**
    * **Rationale:** Historically, TSLA performs better on average when recovering from a negative MACD than when the MACD is already positive.

---

## Instructions for Analysis

1.  **Analyze the Last Row:** Examine the data for the most recent observation date.
2.  **Identify Active Signals:** Check Tier 1, Tier 2, and Tier 3 triggers.
3.  **Resolve Conflicts:**
    * *Conflict:* High RSI (>70) vs. Bullish Dark Pool Flow.
    * *Resolution:* Unless a Tier 1 Reversal signal (like `GEX_Turned_Negative`) is active, favor the Trend/Momentum.
4.  **Output Forecast:**
    * **Immediate (Tomorrow):** Direction (Up/Down/Flat) and Volatility assessment.
    * **Short Term (Next 5 Days):** Trend direction (Bullish/Bearish/Neutral).
5.  **Rationale:** Explicitly name the specific signal(s) driving the forecast.

---

## Data (Last 30 Days)

[INSERT DATA HERE]