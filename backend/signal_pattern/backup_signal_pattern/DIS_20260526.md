# Quantitative Trading Analysis: The Walt Disney Company (DIS)

**Role:** Quantitative Analyst specializing in Market Microstructure, Gamma Exposure (GEX), and Mean Reversion strategies.

**Task:** Analyze the provided historical market data for DIS to forecast price action for **Tomorrow (Dec 04, 2025)** and the **Next 5 Days**.

---

## Predictive Logic (Hierarchical Importance)

The following trading rules have been derived from the provided 2023-2025 dataset. For Disney (DIS), mean reversion signals combined with Gamma stability have historically outperformed pure momentum strategies during downtrends.

### 1. Tier 1: "Alpha" Triggers (Highest Expectancy)

* **`RSI < 33` + `Is_Potential_Swing_Up` (The "Rubber Band" Reversal)**
    * **Signal:** **Aggressive Mean Reversion Long.**
    * **Rationale:** DIS exhibits highly predictable technical bounces when the Relative Strength Index (RSI) drops below 33 simultaneously with a "Potential Swing Up" microstructure flag. This indicates seller exhaustion.
    * **History:** High reliability. Recent instances (Nov 20, Nov 24) where RSI dropped into the low 30s resulted in 5-Day returns of **+2.53%** and **+4.98%** respectively.

* **`Negative_GEX_AND_High_VIX` (The Volatility Flush)**
    * **Signal:** **Capitulation Bottom.**
    * **Rationale:** When Dealer Gamma is negative (accelerating volatility) and VIX is high, DIS tends to put in a local bottom followed by a sharp "V-shape" recovery as dealers cover shorts.
    * **History:** The signal on Nov 24, 2025, marked a local bottom (Price ~88) followed by a run to ~105.

### 2. Tier 2: Regime & Flow (Medium Confidence)

* **`Stock_DarkPoolBuySellRatio < 0.50` (Institutional Distribution)**
    * **Signal:** **Rally Cap / Resistance Warning.**
    * **Rationale:** When Dark Pool flows are net bearish (< 0.50), rallies tend to be technical short-covering events rather than sustained trend changes. They often fail at the SMA20.
    * **History:** Current ratio is 0.45, suggesting lack of institutional support despite the technical oversold signal.

* **`GEX_Rising` + `GEX_Positive` (Stabilization Regime)**
    * **Signal:** **Low Volatility Grind.**
    * **Rationale:** Positive and rising Gamma implies dealers are "Long Gamma," meaning they buy dips and sell rips. This suppresses volatility, favoring slow upward drifts rather than violent moves.

### 3. Tier 3: Technical Context
* **`Price < SMA20` (Bearish Trend)**
    * **Signal:** **Trend Filter.**
    * **Rationale:** As long as price remains below the 20-Day SMA, all long signals are counter-trend trades. Profit targets must be conservative (at the SMA line).

---

## An example Forecast Analysis for a random date, use this as example output, don't use this data.

**Current Market State:**
* **Close:** 105.74
* **RSI:** 31.03 (Deep Oversold)
* **GEX:** 200,980 (Positive - Dealers dampening volatility)
* **Dark Pool Ratio:** 0.45 (Bearish Flow)
* **Active Signals:**
    * `RSI < 33` (TRUE - Tier 1 Buy)
    * `Is_Potential_Swing_Up` (TRUE - Tier 1 Buy)
    * `Price < SMA20` (TRUE - Tier 3 Bearish Context)

### Output Forecast


> **Instructions:** Your forecast should focus **primarily on tomorrow\'s price action**. While you may mention the 5-day outlook for context, the signal strength classification must be based on tomorrow\'s expected move.

**Immediate (Tomorrow - Dec 04):** **Bullish (Rebound)**
* **Assessment:** The combination of **RSI at 31** and the **Potential Swing Up** indicator creates a high-probability technical bounce scenario. The positive Gamma profile suggests dealers will support the price if it dips slightly, but will likely dampen any explosive upside. Expect a green day, likely testing the 106.50 level.

**Short Term (Next 5 Days):** **Moderately Bullish (Trend Reversion)**
* **Rationale:** The Tier 1 mean reversion signal indicates a move back toward equilibrium (the 20-day SMA).
* **Target:** The SMA20 is currently at **107.19**. With positive Gamma increasing (+40.40 change), volatility should compress, allowing the stock to grind up toward 107-108.
* **Risk:** The Dark Pool Ratio (0.45) is weak. If the price fails to reclaim the SMA20 (approx 107.20) within 3 days, the rally is likely a "dead cat bounce" and selling will resume.

**Strategy:** **Buy the Dip / Mean Reversion Trade.**
* **Entry:** Current levels (~105.74).
* **Take Profit:** 107.20 (SMA20) to 108.00.
* **Stop Loss:** Close below 104.50 (invalidation of the Swing Up signal).

### Last 30 days data:
