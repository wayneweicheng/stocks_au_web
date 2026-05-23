IMPORTANT: At the end of your analysis, you MUST provide a signal strength classification in the following JSON format:

```json
{
  "signal_strength": "STRONGLY_BULLISH" | "MILDLY_BULLISH" | "NEUTRAL" | "MILDLY_BEARISH" | "STRONGLY_BEARISH" | "Not Determined"
}
```

Signal Strength Definitions:
- STRONGLY_BULLISH: Multiple strong buy signals, positive trend alignment, high conviction upside
- MILDLY_BULLISH: Some bullish indicators, positive bias but with caveats or mixed signals
- NEUTRAL: Conflicting signals, unclear direction, or market in transition/consolidation
- MILDLY_BEARISH: Some bearish indicators, negative bias but not overwhelming
- STRONGLY_BEARISH: Multiple strong sell signals, negative trend alignment, high conviction downside
- Not Determined: The setup is outside the validated high-confidence regime, or evidence is too conflicted to make a directional call

CRITICAL: Your signal strength classification must follow the primary horizon defined in the stock-specific prompt.
If the stock prompt defines a selective multi-day model or confidence gate, use that model's horizon and no-edge
protocol. Use "Not Determined" when the prompt says the setup is outside the validated high-confidence regime.

GAMMA EXPOSURE (GEX) FLIP ANALYSIS:
You MUST calculate and report the approximate price change that would cause GEX to flip regimes:
- If current GEX is POSITIVE: Calculate the price drop (in dollars and percentage) needed to flip GEX negative.
  This shows how much downside would shift from mean-reverting regime to trend-following regime.
- If current GEX is NEGATIVE: Calculate the price increase (in dollars and percentage) needed to flip GEX positive.
  This shows how much upside would shift from trend-following regime to mean-reverting regime.

This is a critical risk assessment for understanding regime change thresholds.
Include this calculation in your analysis section before the signal strength JSON.

Example formats:
"**GEX Flip Level:** Current GEX is positive. A price drop to approximately $XXX (-X.XX% from current) would likely
flip GEX negative, changing the market regime from mean-reverting to trend-following."

"**GEX Flip Level:** Current GEX is negative. A price increase to approximately $XXX (+X.XX% from current) would likely
flip GEX positive, changing the market regime from trend-following to mean-reverting."

TRADING LEVELS RECOMMENDATION:
You MUST provide actionable trading levels based on your analysis.
Use MULTIPLE DATA SOURCES to identify key support and resistance levels:

**PRIMARY SOURCES (in order of importance):**
1. **Option Open Interest Data (Part 1 & Part 2) - HIGHEST PRIORITY**:
   - **Gamma Walls are the MOST IMPORTANT factor** for determining buy/sell ranges
   - **Call Wall (Resistance)**: Strikes with HIGH call OI concentration (e.g., 10,000+ OI at a specific strike) create strong resistance
     * Dealers hedging short calls must SELL stock as price approaches these strikes
     * The higher the OI concentration, the stronger the resistance
   - **Put Wall (Support)**: Strikes with HIGH put OI concentration (e.g., 10,000+ OI at a specific strike) create strong support
     * Dealers hedging short puts must BUY stock as price approaches these strikes
     * The higher the OI concentration, the stronger the support
   - **FOCUS ON NEAR-TERM EXPIRIES (0-7 DTE)**: Options expiring this week or next week have exponentially higher gamma
     * Near-term gamma walls have IMMEDIATE price impact through forced dealer hedging
     * Far-dated options (30+ DTE) have minimal immediate impact
   - **OI Changes (Part 1)**: Large increases in OI indicate NEW institutional positioning
     * +5,000 OI in near-term puts = new put wall forming (support)
     * +5,000 OI in near-term calls = new call wall forming (resistance)

2. **30-Minute Price Bar Data** (Secondary confirmation):
   - Intraday support/resistance from VWAP clusters
   - High-volume price zones from recent days
   - Recurring intraday lows (support) and highs (resistance)

3. **Daily Technical Levels** (Tertiary confirmation):
   - Bollinger Bands, moving averages (SMA20, SMA50)
   - GEX levels and regime thresholds

**CRITICAL INSTRUCTION:**
Your trading ranges MUST be anchored to SPECIFIC STRIKES with STRONG OI CONCENTRATION from Part 2 data.
DO NOT rely primarily on technical indicators or VWAP levels.
Gamma Walls are CONCRETE, MEASURABLE dealer hedging obligations that create predictable price behavior.
A strike with 50,000+ OI in 0-7 DTE options will have stronger support/resistance than any technical level.**

1. **Buy the Dip Range**: If conditions support buying on weakness, specify:
   - Price range for buy entry (e.g., "$XXX - $YYY")
   - Percentage drop from current price
   - **PRICE GEOMETRY CHECK - MANDATORY**:
     * Buy the Dip must be STRICTLY BELOW the latest current price/close from the data
     * The percentage from current price must be negative
     * A put wall above the current price is NOT a buy-the-dip support level; treat it as overhead structure or a reclaim/magnet level, or state "Not Recommended"
     * If the proposed range is at or above current price, you MUST output "Not Recommended" for Buy the Dip
   - **MANDATORY GAMMA WALL ANALYSIS**:
     * **YOU MUST identify the strongest Put Wall from Part 2 data**
     * Look for strikes with the HIGHEST put OI concentration (typically 20,000+ OI)
     * PRIORITIZE strikes in 0-7 DTE expiries (this week/next week)
     * Example: "Part 2 shows 45,000 put OI at $600 strike expiring 2026-02-21 (2 DTE) - this is the primary Put Wall"
     * State the EXACT strike, OI amount, and expiry date from the data
   - Secondary confirmation (if applicable):
     * Intraday support from 30M bars (VWAP at this level, high-volume zones)
     * Daily technical levels (Bollinger Bands, moving averages)
   - **If NO strong Put Wall exists** (no strikes with 15,000+ OI in 0-7 DTE), state "Not Recommended" and explain:
     * "No significant Put Wall identified in near-term options to provide strong support"
     * Specify what the data shows instead (e.g., "highest put OI is only 5,000 at $590")

2. **Sell the Rip Range**: If conditions support selling on strength, specify:
   - Price range for sell/short entry (e.g., "$XXX - $YYY")
   - Percentage gain from current price
   - **PRICE GEOMETRY CHECK - MANDATORY**:
     * Sell the Rip must be STRICTLY ABOVE the latest current price/close from the data
     * The percentage from current price must be positive
     * A call wall below the current price is NOT a sell-the-rip resistance level; treat it as lower support/past resistance, or state "Not Recommended"
     * If the proposed range is at or below current price, you MUST output "Not Recommended" for Sell the Rip
   - **MANDATORY GAMMA WALL ANALYSIS**:
     * **YOU MUST identify the strongest Call Wall from Part 2 data**
     * Look for strikes with the HIGHEST call OI concentration (typically 20,000+ OI)
     * PRIORITIZE strikes in 0-7 DTE expiries (this week/next week)
     * Example: "Part 2 shows 52,000 call OI at $610 strike expiring 2026-02-21 (2 DTE) - this is the primary Call Wall"
     * State the EXACT strike, OI amount, and expiry date from the data
   - Secondary confirmation (if applicable):
     * Intraday resistance from 30M bars (VWAP at this level, high-volume zones)
     * Daily technical levels (Bollinger Bands, moving averages)
   - **If NO strong Call Wall exists** (no strikes with 15,000+ OI in 0-7 DTE), state "Not Recommended" and explain:
     * "No significant Call Wall identified in near-term options to provide strong resistance"
     * Specify what the data shows instead (e.g., "highest call OI is only 8,000 at $615")

Example format (WITH gamma wall - recommended):
"**Buy the Dip Range:** $598 - $600 (-1.2% to -2.0% from current). **PRIMARY SUPPORT: Put Wall at $600 strike** - Part 2 data shows 42,500 put OI expiring 2026-02-21 (2 DTE), the highest put OI concentration in near-term options. Dealers hedging these short puts MUST buy stock as price approaches $600, creating strong mechanical support. Secondary confirmation: 30M bars show VWAP cluster at $599 and high-volume zone at $598. Positive GEX regime reinforces mean-reversion at support."

"**Sell the Rip Range:** $610 - $615 (+1.5% to +2.5% from current). **PRIMARY RESISTANCE: Call Wall at $610 strike** - Part 2 data shows 38,200 call OI expiring 2026-02-21 (2 DTE), creating a strong gamma wall. Dealers hedging these short calls MUST sell stock as price approaches $610. Secondary resistance from 30M bars shows VWAP resistance at $612."

Example format (WITHOUT gamma wall - not recommended):
"**Buy the Dip Range:** Not Recommended. No significant Put Wall identified in near-term options (0-7 DTE). Part 2 data shows highest put OI is only 8,500 at $595 strike (14 DTE), insufficient to create strong support through dealer hedging. Without a gamma wall anchor, relying solely on technical levels ($598 Bollinger Band) is too speculative in current negative GEX environment."

"**Sell the Rip Range:** Not Recommended. No Call Wall resistance in near-term options. Part 2 data shows scattered call OI with no concentration above 12,000 in 0-7 DTE expiries. Current heavy call buying (+15,000 OI at $615 in 3 DTE) suggests bullish positioning with gamma squeeze potential. Selling into strength without a gamma wall barrier would be counter-trend."

LATE OPTION TRADE ANALYSIS:
The "Latest Option Trades" data shows large option transactions (size > 300 contracts) for the observation date.
Incorporate this data into your overall signal strength assessment:
- Evaluate the put/call balance: heavy put buying suggests bearish institutional positioning; heavy call buying suggests bullish positioning
- Look for strike clustering near the current price, which may indicate key levels where dealers will need to hedge
- Unusually large individual trades may signal directional bets or hedging activity by institutions
- Factor this institutional flow data into your signal strength classification alongside the GEX and technical indicators

**CRITICAL - LOGICAL CONSISTENCY CHECK:**
Your Buy the Dip Range and Sell the Rip Range recommendations MUST be logically consistent with your signal strength classification:

- **If STRONGLY_BEARISH or MILDLY_BEARISH:**
  - Sell the Rip Range SHOULD be recommended (with specific price levels based on Call Wall resistance)
  - Buy the Dip Range should typically be "Not Recommended" UNLESS there's a very strong Put Wall providing exceptional tactical support
  - Rationale: If you're bearish, you should recommend selling rallies, not avoiding them

- **If STRONGLY_BULLISH or MILDLY_BULLISH:**
  - Buy the Dip Range SHOULD be recommended (with specific price levels based on Put Wall support)
  - Sell the Rip Range should typically be "Not Recommended" UNLESS there's a very strong Call Wall providing clear resistance
  - Rationale: If you're bullish, you should recommend buying dips, not avoiding them

- **If NEUTRAL:**
  - Either provide BOTH ranges (range-bound trading strategy) OR recommend "Not Recommended" for both
  - Rationale: Neutral means unclear direction, so either trade the range or stay flat

- **If Not Determined:**
  - Recommend "Not Recommended" for directional Buy the Dip and Sell the Rip ranges unless explicitly presenting non-directional range context
  - Rationale: Not Determined means the setup is outside the validated high-confidence regime, so do not manufacture a trade

**AVOID CONTRADICTIONS:** Do NOT say "overwhelming bearish flow" or "rallies will be short-lived" and then recommend "Sell the Rip: Not Recommended". This is logically inconsistent. If rallies will be short-lived, that is EXACTLY when you should sell the rip.

**FINAL TRADING LEVEL SANITY CHECK:** Before writing the final answer, compare every Buy the Dip and Sell the Rip price to the latest current price/close. If Buy the Dip is not below current price, change it to "Not Recommended". If Sell the Rip is not above current price, change it to "Not Recommended". Do not publish contradictory percentages such as a buy-dip range with positive distance from current price.

Place this JSON at the very end of your markdown response after all analysis.
---

Role: You are a quantitative trading analyst and data scientist specializing in market microstructure, gamma exposure (GEX), and mean reversion strategies for the S&P 500 (SPXW).

Task: Analyze the provided 30-day market data snippet to forecast price action for Tomorrow (1-Day). While you may provide additional context about the next 5 days, your primary focus and signal strength assessment must be based on tomorrow's expected price action.

Predictive Logic (Hierarchical Importance)
Use the following statistically validated rules to determine your forecast. Do not deviate from these historical probabilities.

1. Tier 1: "Alpha" Triggers (Highest Confidence)
Golden_Setup OR Setup_Trend_Dip == 1:

Signal: Strong Buy.

History: 5-Day Average Return +2.18% (82% Win Rate).

Is_Swing_Down == 1 AND GEX < 0 (The "Crash Short"):

Signal: Strong Short/Bearish.

History: 1-Day Average Return -0.58% (64% Win Rate).

GEX_ZScore > 2.0:

Signal: Extreme Support / Bullish Bounce.

History: 5-Day Average Return +1.87% (100% Win Rate historically).

2. Tier 2: Regime & Trend (Medium Confidence)
GEX < 0 AND VIX > 20:

Signal: Capitulation Buy (Volatile but bullish).

History: 20-Day Average Return +3.58%.

Is_Swing_Up == 1 ("Confirmed Swing Up"):

Signal: Steady Uptrend.

History: 20-Day Average Return +3.06%.

Stock_DarkPoolBuySellRatio > 2.0:

Signal: Institutional Accumulation. Supports bullish trend over 10-20 days.

GEX_Turned_Negative == 1:

Signal: Bearish Shift. Expect negative returns next day.

3. Tier 3: Mean Reversion & Context
RSI > 70: Market is Overbought. Expect Consolidation or Minor Pullback (Next 1-2 days).

RSI < 30: Market is Oversold. Expect Bullish Bounce.

MACD_Positive == 0: Contrarian Bullish. Historically performs better than when MACD is positive.

Instructions
Analyze the Last Row(with the greatest Observation Date): Identify which of the Tier 1, 2, or 3 signals are currently active.

Resolve Conflicts:

If RSI > 70 (Bearish) but Golden Setup (Bullish) is active, prioritize Golden Setup.

If RSI > 70 and no Alpha triggers are active, forecast a Pullback.

Output Forecast:

PRIMARY FOCUS - Tomorrow (Next Trading Day): Direction (Up/Down/Flat), expected magnitude, and volatility assessment. This is your main prediction and should be the basis for your signal strength classification.

Secondary Context - Next 5 Days: Brief trend direction context (optional, for additional perspective only).

Rationale: Explicitly name the specific signal (e.g., "Forecast is Bullish because 'Confirmed Swing Up' is active...") that drove the decision for TOMORROW'S action.

Data (Last 30 Days)

## Data (Last 30 Days)

[
  {
    "ObservationDate": "2026-04-07",
    "Close": "6616.8501",
    "TodayChange": "0.08",
    "VIX": "25.7800",
    "RSI": "44.87181042077141978242006136871",
    "GEX": 142470.0,
    "Prev1GEX": 3134.0,
    "GEXChange": "4445.95",
    "GEX_ZScore": 2.92,
    "Stock_DarkPoolBuySellRatio": "1.32",
    "MACD_Positive": 0,
    "MACD_Line": "-117.144153",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": null,
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 1,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 1,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.55,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 0
  },
  {
    "ObservationDate": "2026-04-08",
    "Close": "6782.8101",
    "TodayChange": "2.51",
    "VIX": "21.0400",
    "RSI": "58.70920004442890075219450279064",
    "GEX": 84442.0,
    "Prev1GEX": 142470.0,
    "GEXChange": "-40.73",
    "GEX_ZScore": 1.77,
    "Stock_DarkPoolBuySellRatio": "1.29",
    "MACD_Positive": 0,
    "MACD_Line": "-90.316259",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 1,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": "swing down",
    "PotentialSwingIndicator": "Potential swing down",
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 1,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 1,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.92,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-04-09",
    "Close": "6824.6602",
    "TodayChange": "0.62",
    "VIX": "19.4900",
    "RSI": "61.51760704166219308848525989662",
    "GEX": 99042.0,
    "Prev1GEX": 84442.0,
    "GEXChange": "17.29",
    "GEX_ZScore": 1.71,
    "Stock_DarkPoolBuySellRatio": "1.33",
    "MACD_Positive": 0,
    "MACD_Line": "-70.320101",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": null,
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 1,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.99,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-04-10",
    "Close": "6816.8901",
    "TodayChange": "-0.11",
    "VIX": "19.2300",
    "RSI": "67.96406849922873494911893179391",
    "GEX": -5278.0,
    "Prev1GEX": 99042.0,
    "GEXChange": "-105.33",
    "GEX_ZScore": 0.33,
    "Stock_DarkPoolBuySellRatio": "1.29",
    "MACD_Positive": 0,
    "MACD_Line": "-46.586643",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 1,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": null,
    "PotentialSwingIndicator": "Potential swing down",
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.92,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-04-13",
    "Close": "6886.2402",
    "TodayChange": "1.02",
    "VIX": "19.1200",
    "RSI": "67.64927675105568497642117536001",
    "GEX": 138726.0,
    "Prev1GEX": -5278.0,
    "GEXChange": "-2728.38",
    "GEX_ZScore": 1.86,
    "Stock_DarkPoolBuySellRatio": "1.42",
    "MACD_Positive": 0,
    "MACD_Line": "-24.194061",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 1,
    "SwingIndicator": null,
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 1,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.98,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-04-14",
    "Close": "6967.3799",
    "TodayChange": "1.18",
    "VIX": "18.3600",
    "RSI": "72.15102942327288342950047022987",
    "GEX": 119492.0,
    "Prev1GEX": 138726.0,
    "GEXChange": "-13.86",
    "GEX_ZScore": 1.44,
    "Stock_DarkPoolBuySellRatio": "1.28",
    "MACD_Positive": 1,
    "MACD_Line": "7.912968",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 1,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": "swing down",
    "PotentialSwingIndicator": "Potential swing down",
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 1.02,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-04-15",
    "Close": "7022.9502",
    "TodayChange": "0.80",
    "VIX": "18.1700",
    "RSI": "72.65736506683086830365199169222",
    "GEX": 129989.0,
    "Prev1GEX": 119492.0,
    "GEXChange": "8.78",
    "GEX_ZScore": 1.39,
    "Stock_DarkPoolBuySellRatio": "1.19",
    "MACD_Positive": 1,
    "MACD_Line": "53.692080",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": null,
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 1.02,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-04-16",
    "Close": "7041.2798",
    "TodayChange": "0.26",
    "VIX": "17.9400",
    "RSI": "83.07331691219384708299085011220",
    "GEX": 131422.0,
    "Prev1GEX": 129989.0,
    "GEXChange": "1.10",
    "GEX_ZScore": 1.27,
    "Stock_DarkPoolBuySellRatio": "1.15",
    "MACD_Positive": 1,
    "MACD_Line": "101.829747",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": null,
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.96,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-04-17",
    "Close": "7126.0601",
    "TodayChange": "1.20",
    "VIX": "17.4800",
    "RSI": "95.95144536032197021454060261036",
    "GEX": 53603.0,
    "Prev1GEX": 131422.0,
    "GEXChange": "-59.21",
    "GEX_ZScore": 0.39,
    "Stock_DarkPoolBuySellRatio": "1.56",
    "MACD_Positive": 1,
    "MACD_Line": "138.153205",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 1,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": "swing down",
    "PotentialSwingIndicator": "Potential swing down",
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.98,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-04-20",
    "Close": "7109.1401",
    "TodayChange": "-0.24",
    "VIX": "18.8700",
    "RSI": "97.13114565976764574927590116453",
    "GEX": 90832.0,
    "Prev1GEX": 53603.0,
    "GEXChange": "69.45",
    "GEX_ZScore": 0.72,
    "Stock_DarkPoolBuySellRatio": "0.71",
    "MACD_Positive": 1,
    "MACD_Line": "165.848999",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 1,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": "swing up",
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.9,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-04-21",
    "Close": "7064.0098",
    "TodayChange": "-0.63",
    "VIX": "19.5000",
    "RSI": "90.12096093017870588934962531769",
    "GEX": 75211.0,
    "Prev1GEX": 90832.0,
    "GEXChange": "-17.20",
    "GEX_ZScore": 0.48,
    "Stock_DarkPoolBuySellRatio": "1.06",
    "MACD_Positive": 1,
    "MACD_Line": "189.350533",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": null,
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.82,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-04-22",
    "Close": "7137.8999",
    "TodayChange": "1.05",
    "VIX": "18.9200",
    "RSI": "90.43901280512575996701841857257",
    "GEX": 56399.0,
    "Prev1GEX": 75211.0,
    "GEXChange": "-25.01",
    "GEX_ZScore": 0.23,
    "Stock_DarkPoolBuySellRatio": "0.60",
    "MACD_Positive": 1,
    "MACD_Line": "216.323529",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 1,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": "swing down",
    "PotentialSwingIndicator": "Potential swing down",
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.85,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-04-23",
    "Close": "7108.3999",
    "TodayChange": "-0.41",
    "VIX": "19.3100",
    "RSI": "86.82471388548673722998568636917",
    "GEX": 80771.0,
    "Prev1GEX": 56399.0,
    "GEXChange": "43.21",
    "GEX_ZScore": 0.43,
    "Stock_DarkPoolBuySellRatio": "1.17",
    "MACD_Positive": 1,
    "MACD_Line": "242.197162",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 1,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": "swing up",
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.79,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-04-24",
    "Close": "7165.0801",
    "TodayChange": "0.80",
    "VIX": "18.7100",
    "RSI": "87.25947481007062073112777854929",
    "GEX": 74427.0,
    "Prev1GEX": 80771.0,
    "GEXChange": "-7.85",
    "GEX_ZScore": 0.27,
    "Stock_DarkPoolBuySellRatio": "0.94",
    "MACD_Positive": 1,
    "MACD_Line": "253.269153",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 1,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": "swing down",
    "PotentialSwingIndicator": "Potential swing down",
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.81,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-04-27",
    "Close": "7173.9102",
    "TodayChange": "0.12",
    "VIX": "18.0200",
    "RSI": "87.30601206309673643917136185546",
    "GEX": 9484.0,
    "Prev1GEX": 74427.0,
    "GEXChange": "-87.26",
    "GEX_ZScore": -0.84,
    "Stock_DarkPoolBuySellRatio": "1.69",
    "MACD_Positive": 1,
    "MACD_Line": "260.549474",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 1,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": "swing down",
    "PotentialSwingIndicator": "Potential swing down",
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.79,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-04-28",
    "Close": "7138.7998",
    "TodayChange": "-0.49",
    "VIX": "17.8300",
    "RSI": "78.94743933494118756652609170159",
    "GEX": 39313.0,
    "Prev1GEX": 9484.0,
    "GEXChange": "314.52",
    "GEX_ZScore": -0.5,
    "Stock_DarkPoolBuySellRatio": "1.22",
    "MACD_Positive": 1,
    "MACD_Line": "263.055290",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 1,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": "swing up",
    "PotentialSwingIndicator": "Potential swing up",
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.75,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-04-29",
    "Close": "7135.9502",
    "TodayChange": "-0.04",
    "VIX": "18.8100",
    "RSI": "77.00607085717228937215996232675",
    "GEX": 62916.0,
    "Prev1GEX": 39313.0,
    "GEXChange": "60.04",
    "GEX_ZScore": -0.08,
    "Stock_DarkPoolBuySellRatio": "1.05",
    "MACD_Positive": 1,
    "MACD_Line": "262.520218",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 1,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": "swing up",
    "PotentialSwingIndicator": "Potential swing up",
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.72,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-04-30",
    "Close": "7209.0098",
    "TodayChange": "1.02",
    "VIX": "16.8900",
    "RSI": "80.45362446486910378695388892734",
    "GEX": 125000.0,
    "Prev1GEX": 62916.0,
    "GEXChange": "98.68",
    "GEX_ZScore": 1.03,
    "Stock_DarkPoolBuySellRatio": "1.17",
    "MACD_Positive": 1,
    "MACD_Line": "257.554516",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": null,
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.79,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-05-01",
    "Close": "7230.1201",
    "TodayChange": "0.29",
    "VIX": "16.9900",
    "RSI": "78.78086296957154530699529168569",
    "GEX": 37128.0,
    "Prev1GEX": 125000.0,
    "GEXChange": "-70.30",
    "GEX_ZScore": -0.88,
    "Stock_DarkPoolBuySellRatio": "1.24",
    "MACD_Positive": 1,
    "MACD_Line": "250.271743",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 1,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": "swing down",
    "PotentialSwingIndicator": "Potential swing down",
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.79,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-05-06",
    "Close": "7365.1201",
    "TodayChange": "1.46",
    "VIX": "17.3900",
    "RSI": "79.45525189504756520081258587705",
    "GEX": 112955.0,
    "Prev1GEX": 37128.0,
    "GEXChange": "204.23",
    "GEX_ZScore": 0.7,
    "Stock_DarkPoolBuySellRatio": "0.97",
    "MACD_Positive": 1,
    "MACD_Line": "243.106132",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": null,
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.94,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-05-07",
    "Close": "7337.1099",
    "TodayChange": "-0.38",
    "VIX": "17.0800",
    "RSI": "73.89755678521265268950439030044",
    "GEX": 114410.0,
    "Prev1GEX": 112955.0,
    "GEXChange": "1.29",
    "GEX_ZScore": 0.8,
    "Stock_DarkPoolBuySellRatio": "1.72",
    "MACD_Positive": 1,
    "MACD_Line": "223.452853",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 1,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": "swing up",
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.9,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-05-11",
    "Close": "7412.8398",
    "TodayChange": "0.19",
    "VIX": "18.3800",
    "RSI": "73.67794864883646004207316687970",
    "GEX": 28863.0,
    "Prev1GEX": 114410.0,
    "GEXChange": "-74.77",
    "GEX_ZScore": -1.16,
    "Stock_DarkPoolBuySellRatio": "1.38",
    "MACD_Positive": 1,
    "MACD_Line": "207.641177",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 1,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": "swing down",
    "PotentialSwingIndicator": "Potential swing down",
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.96,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-05-12",
    "Close": "7400.9600",
    "TodayChange": "-0.16",
    "VIX": "17.9900",
    "RSI": "67.71974541208811605655371482784",
    "GEX": 61140.0,
    "Prev1GEX": 28863.0,
    "GEXChange": "111.83",
    "GEX_ZScore": -0.37,
    "Stock_DarkPoolBuySellRatio": "0.96",
    "MACD_Positive": 1,
    "MACD_Line": "202.164976",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 1,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": "swing up",
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.91,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-05-13",
    "Close": "7444.2500",
    "TodayChange": "0.58",
    "VIX": "17.8700",
    "RSI": "72.30972349597494140737491748298",
    "GEX": 113133.0,
    "Prev1GEX": 61140.0,
    "GEXChange": "85.04",
    "GEX_ZScore": 0.78,
    "Stock_DarkPoolBuySellRatio": "0.60",
    "MACD_Positive": 1,
    "MACD_Line": "194.273758",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": null,
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.94,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-05-14",
    "Close": "7501.2402",
    "TodayChange": "0.77",
    "VIX": "17.2600",
    "RSI": "80.92785962904686978496161731751",
    "GEX": 7514.0,
    "Prev1GEX": 113133.0,
    "GEXChange": "-93.36",
    "GEX_ZScore": -1.72,
    "Stock_DarkPoolBuySellRatio": "0.94",
    "MACD_Positive": 1,
    "MACD_Line": "191.681593",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 1,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": "swing down",
    "PotentialSwingIndicator": "Potential swing down",
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 1,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.98,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-05-15",
    "Close": "7408.5000",
    "TodayChange": "-1.24",
    "VIX": "18.4300",
    "RSI": "65.78620896825576040492705961890",
    "GEX": -3408.0,
    "Prev1GEX": 7514.0,
    "GEXChange": "-145.36",
    "GEX_ZScore": -1.74,
    "Stock_DarkPoolBuySellRatio": "1.41",
    "MACD_Positive": 1,
    "MACD_Line": "181.325434",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 1,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": null,
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 1,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.8,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-05-18",
    "Close": "7403.0498",
    "TodayChange": "-0.07",
    "VIX": "17.8200",
    "RSI": "68.72533210569836958901333426741",
    "GEX": -22683.0,
    "Prev1GEX": -3408.0,
    "GEXChange": "565.58",
    "GEX_ZScore": -1.91,
    "Stock_DarkPoolBuySellRatio": "1.05",
    "MACD_Positive": 1,
    "MACD_Line": "170.181951",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": null,
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 1,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.77,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-05-19",
    "Close": "7353.6099",
    "TodayChange": "-0.67",
    "VIX": "18.0600",
    "RSI": "59.22456540522423023115186117433",
    "GEX": 23367.0,
    "Prev1GEX": -22683.0,
    "GEXChange": "-203.02",
    "GEX_ZScore": -0.8,
    "Stock_DarkPoolBuySellRatio": "1.47",
    "MACD_Positive": 1,
    "MACD_Line": "166.128954",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 1,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 1,
    "SwingIndicator": "swing up",
    "PotentialSwingIndicator": "Potential swing up",
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 1,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.67,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-05-20",
    "Close": "7432.9702",
    "TodayChange": "1.08",
    "VIX": "17.4400",
    "RSI": "63.86257080225815567570849236814",
    "GEX": 23697.0,
    "Prev1GEX": 23367.0,
    "GEXChange": "1.41",
    "GEX_ZScore": -0.74,
    "Stock_DarkPoolBuySellRatio": "1.07",
    "MACD_Positive": 1,
    "MACD_Line": "167.484082",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": null,
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.78,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  },
  {
    "ObservationDate": "2026-05-21",
    "Close": "7445.7202",
    "TodayChange": "0.17",
    "VIX": "16.7600",
    "RSI": "68.47287658518376529696028086884",
    "GEX": 88812.0,
    "Prev1GEX": 23697.0,
    "GEXChange": "274.78",
    "GEX_ZScore": 0.78,
    "Stock_DarkPoolBuySellRatio": "1.43",
    "MACD_Positive": 1,
    "MACD_Line": "163.024176",
    "Golden_Setup": 0,
    "Setup_Trend_Dip": 0,
    "Is_Swing_Down": 0,
    "Is_Swing_Up": 0,
    "GEX_Turned_Negative": 0,
    "GEX_Turned_Positive": 0,
    "SwingIndicator": null,
    "PotentialSwingIndicator": null,
    "GEX_ZScore_VeryLow": 0,
    "GEX_ZScore_Low": 0,
    "GEX_ZScore_High": 0,
    "GEX_ZScore_VeryHigh": 0,
    "Pot_Swing_Up_AND_Neg_GEXChange": 0,
    "Low_GEX_Z_AND_Pot_Swing_Up": 0,
    "VIX_Very_High": 0,
    "Negative_GEX_AND_High_VIX": 0,
    "BB_PercentB": 0.77,
    "Price_Above_SMA20": 1,
    "Price_Above_SMA50": 1
  }
]

## Latest Option Trades (Size > 300)

Underlying|OptionSymbol|SaleTime|ExpiryDate|Strike|PutOrCall|Price|Size|Exchange|SpecialConditions
SPXW|SPXW260522C07575000|2026-05-21 09:30:39|2026-05-22|7575.0000|C|0.3100|2410|CBOE|f
SPXW|SPXW260522C07635000|2026-05-21 09:30:39|2026-05-22|7635.0000|C|0.1100|2410|CBOE|f
SPXW|SPXW260522C07635000|2026-05-21 09:31:37|2026-05-22|7635.0000|C|0.1100|500|CBOE|m
SPXW|SPXW260522C07635000|2026-05-21 09:31:37|2026-05-22|7635.0000|C|0.1100|2000|CBOE|m
SPXW|SPXW260522C07575000|2026-05-21 09:31:37|2026-05-22|7575.0000|C|0.3100|500|CBOE|m
SPXW|SPXW260522C07575000|2026-05-21 09:31:37|2026-05-22|7575.0000|C|0.3100|2000|CBOE|m
SPXW|SPXW260522P07100000|2026-05-21 09:31:57|2026-05-22|7100.0000|P|0.5600|1449|CBOE|f
SPXW|SPXW260522P07200000|2026-05-21 09:31:57|2026-05-22|7200.0000|P|1.6600|1449|CBOE|f
SPXW|SPXW260522C07640000|2026-05-21 09:31:58|2026-05-22|7640.0000|C|0.1100|745|CBOE|f
SPXW|SPXW260522C07575000|2026-05-21 09:31:58|2026-05-22|7575.0000|C|0.2600|745|CBOE|f
SPXW|SPXW260522C07625000|2026-05-21 09:33:31|2026-05-22|7625.0000|C|0.1500|2461|CBOE|f
SPXW|SPXW260522C07550000|2026-05-21 09:33:31|2026-05-22|7550.0000|C|0.6500|2461|CBOE|f
SPXW|SPXW260522C07560000|2026-05-21 09:34:55|2026-05-22|7560.0000|C|0.4300|500|CBOE|m
SPXW|SPXW260522C07560000|2026-05-21 09:34:55|2026-05-22|7560.0000|C|0.4300|1000|CBOE|m
SPXW|SPXW260522C07640000|2026-05-21 09:34:55|2026-05-22|7640.0000|C|0.1300|500|CBOE|m
SPXW|SPXW260522P07175000|2026-05-21 09:35:45|2026-05-22|7175.0000|P|0.9200|1004|CBOE|f
SPXW|SPXW260522P07075000|2026-05-21 09:35:45|2026-05-22|7075.0000|P|0.4200|1004|CBOE|f
SPXW|SPXW260522C07560000|2026-05-21 09:36:24|2026-05-22|7560.0000|C|0.4300|800|CBOE|m
SPXW|SPXW260522C07490000|2026-05-21 09:36:56|2026-05-22|7490.0000|C|4.7500|475|CBOE|m
SPXW|SPXW260601C07350000|2026-05-21 09:36:56|2026-06-01|7350.0000|C|103.1400|475|CBOE|m
SPXW|SPXW260618P06400000|2026-05-21 09:36:56|2026-06-18|6400.0000|P|7.2500|475|CBOE|m
SPXW|SPXW260618P07000000|2026-05-21 09:36:56|2026-06-18|7000.0000|P|31.2300|475|CBOE|m
SPXW|SPXW260522C07640000|2026-05-21 09:37:42|2026-05-22|7640.0000|C|0.1300|900|CBOE|m
SPXW|SPXW260522C07640000|2026-05-21 09:38:03|2026-05-22|7640.0000|C|0.1300|400|CBOE|m
SPXW|SPXW260526C07500000|2026-05-21 09:47:54|2026-05-26|7500.0000|C|9.2000|500|CBOE|t
SPXW|SPXW260522P07075000|2026-05-21 09:48:22|2026-05-22|7075.0000|P|0.4800|1500|CBOE|m
SPXW|SPXW260522P07075000|2026-05-21 09:48:22|2026-05-22|7075.0000|P|0.4800|500|CBOE|m
SPXW|SPXW260522P07175000|2026-05-21 09:48:22|2026-05-22|7175.0000|P|0.9800|500|CBOE|m
SPXW|SPXW260522P07175000|2026-05-21 09:48:22|2026-05-22|7175.0000|P|0.9800|1500|CBOE|m
SPXW|SPXW260522C07640000|2026-05-21 09:50:43|2026-05-22|7640.0000|C|0.1200|2299|CBOE|f
SPXW|SPXW260522C07560000|2026-05-21 09:50:43|2026-05-22|7560.0000|C|0.4700|2299|CBOE|f
SPXW|SPXW260605P06575000|2026-05-21 09:53:12|2026-06-05|6575.0000|P|2.4200|305|CBOE|f
SPXW|SPXW260605P06600000|2026-05-21 09:53:12|2026-06-05|6600.0000|P|2.6200|305|CBOE|f
SPXW|SPXW260605P06960000|2026-05-21 09:56:36|2026-06-05|6960.0000|P|8.7500|442|CBOE|f
SPXW|SPXW260522P06995000|2026-05-21 09:56:36|2026-05-22|6995.0000|P|0.3000|442|CBOE|f
SPXW|SPXW260522P06995000|2026-05-21 09:56:36|2026-05-22|6995.0000|P|0.3100|305|CBOE|f
SPXW|SPXW260605P06960000|2026-05-21 09:56:37|2026-06-05|6960.0000|P|8.7100|305|CBOE|f
SPXW|SPXW260522P07210000|2026-05-21 09:59:07|2026-05-22|7210.0000|P|1.0500|500|CBOE|m
SPXW|SPXW260522P07210000|2026-05-21 09:59:07|2026-05-22|7210.0000|P|1.0500|1000|CBOE|m
SPXW|SPXW260522P07120000|2026-05-21 09:59:07|2026-05-22|7120.0000|P|0.5000|500|CBOE|m
SPXW|SPXW260522P07120000|2026-05-21 09:59:07|2026-05-22|7120.0000|P|0.5000|1000|CBOE|m
SPXW|SPXW260522C07655000|2026-05-21 10:08:59|2026-05-22|7655.0000|C|0.1200|416|CBOE|m
SPXW|SPXW260522C07655000|2026-05-21 10:08:59|2026-05-22|7655.0000|C|0.1200|417|CBOE|m
SPXW|SPXW260522C07655000|2026-05-21 10:08:59|2026-05-22|7655.0000|C|0.1200|1000|CBOE|m
SPXW|SPXW260522C07565000|2026-05-21 10:08:59|2026-05-22|7565.0000|C|0.5400|1000|CBOE|m
SPXW|SPXW260522C07565000|2026-05-21 10:08:59|2026-05-22|7565.0000|C|0.5400|417|CBOE|m
SPXW|SPXW260522C07565000|2026-05-21 10:08:59|2026-05-22|7565.0000|C|0.5400|416|CBOE|m
SPXW|SPXW260522C07565000|2026-05-21 10:10:12|2026-05-22|7565.0000|C|0.5600|1000|CBOE|m
SPXW|SPXW260522C07565000|2026-05-21 10:10:12|2026-05-22|7565.0000|C|0.5600|675|CBOE|m
SPXW|SPXW260522C07655000|2026-05-21 10:10:12|2026-05-22|7655.0000|C|0.1200|675|CBOE|m
SPXW|SPXW260522C07655000|2026-05-21 10:10:12|2026-05-22|7655.0000|C|0.1200|1000|CBOE|m
SPXW|SPXW260522C07435000|2026-05-21 10:11:32|2026-05-22|7435.0000|C|25.2000|400|CBOE|m
SPXW|SPXW260522C07435000|2026-05-21 10:13:26|2026-05-22|7435.0000|C|23.1500|522|CBOE|m
SPXW|SPXW260522P07085000|2026-05-21 10:13:37|2026-05-22|7085.0000|P|0.4500|2440|CBOE|f
SPXW|SPXW260522P07185000|2026-05-21 10:13:37|2026-05-22|7185.0000|P|0.8500|2440|CBOE|f
SPXW|SPXW260522P07075000|2026-05-21 10:13:44|2026-05-22|7075.0000|P|0.4300|2500|CBOE|f
SPXW|SPXW260522P07175000|2026-05-21 10:13:44|2026-05-22|7175.0000|P|0.7800|2500|CBOE|f
SPXW|SPXW260522P07185000|2026-05-21 10:16:54|2026-05-22|7185.0000|P|0.8600|790|CBOE|m
SPXW|SPXW260522P07085000|2026-05-21 10:16:54|2026-05-22|7085.0000|P|0.4600|790|CBOE|m
SPXW|SPXW260526P07300000|2026-05-21 10:33:29|2026-05-26|7300.0000|P|13.4900|400|CBOE|m
SPXW|SPXW260522C07440000|2026-05-21 10:33:43|2026-05-22|7440.0000|C|16.4400|376|CBOE|f
SPXW|SPXW260522C07465000|2026-05-21 10:33:43|2026-05-22|7465.0000|C|9.0400|376|CBOE|f
SPXW|SPXW260522P07090000|2026-05-21 10:34:24|2026-05-22|7090.0000|P|0.4500|500|CBOE|e
SPXW|SPXW260522C07640000|2026-05-21 10:39:03|2026-05-22|7640.0000|C|0.1200|2180|CBOE|m
SPXW|SPXW260522C07560000|2026-05-21 10:39:03|2026-05-22|7560.0000|C|0.4200|2180|CBOE|m
SPXW|SPXW260522P07200000|2026-05-21 10:45:35|2026-05-22|7200.0000|P|0.9000|858|CBOE|f
SPXW|SPXW260522P07150000|2026-05-21 10:45:35|2026-05-22|7150.0000|P|0.5500|858|CBOE|f
SPXW|SPXW260527C07560000|2026-05-21 10:45:59|2026-05-27|7560.0000|C|3.6000|469|CBOE|f
SPXW|SPXW260527C07565000|2026-05-21 10:45:59|2026-05-27|7565.0000|C|3.2000|469|CBOE|f
SPXW|SPXW260527P07195000|2026-05-21 10:45:59|2026-05-27|7195.0000|P|6.2500|469|CBOE|f
SPXW|SPXW260527P07200000|2026-05-21 10:45:59|2026-05-27|7200.0000|P|6.5500|469|CBOE|f
SPXW|SPXW260522P07215000|2026-05-21 10:50:57|2026-05-22|7215.0000|P|1.3000|492|CBOE|m
SPXW|SPXW260522P07215000|2026-05-21 10:50:57|2026-05-22|7215.0000|P|1.3000|984|CBOE|m
SPXW|SPXW260522P07115000|2026-05-21 10:50:57|2026-05-22|7115.0000|P|0.5500|492|CBOE|m
SPXW|SPXW260522P07115000|2026-05-21 10:50:57|2026-05-22|7115.0000|P|0.5500|984|CBOE|m
SPXW|SPXW260630P06690000|2026-05-21 10:51:22|2026-06-30|6690.0000|P|22.6300|334|CBOE|m
SPXW|SPXW260630P06690000|2026-05-21 10:51:22|2026-06-30|6690.0000|P|22.6300|333|CBOE|m
SPXW|SPXW260630P06700000|2026-05-21 10:51:22|2026-06-30|6700.0000|P|23.0700|334|CBOE|m
SPXW|SPXW260630P06700000|2026-05-21 10:51:22|2026-06-30|6700.0000|P|23.0700|333|CBOE|m
SPXW|SPXW260630C07900000|2026-05-21 10:51:22|2026-06-30|7900.0000|C|7.7700|334|CBOE|m
SPXW|SPXW260630C07900000|2026-05-21 10:51:22|2026-06-30|7900.0000|C|7.7700|333|CBOE|m
SPXW|SPXW260630C07910000|2026-05-21 10:51:22|2026-06-30|7910.0000|C|7.2100|333|CBOE|m
SPXW|SPXW260630C07910000|2026-05-21 10:51:22|2026-06-30|7910.0000|C|7.2100|334|CBOE|m
SPXW|SPXW260522C07640000|2026-05-21 10:55:20|2026-05-22|7640.0000|C|0.1200|2027|CBOE|f
SPXW|SPXW260522C07570000|2026-05-21 10:55:20|2026-05-22|7570.0000|C|0.3200|2027|CBOE|f
SPXW|SPXW260522C07500000|2026-05-21 12:26:59|2026-05-22|7500.0000|C|2.0500|400|CBOE|
SPXW|SPXW260522C07560000|2026-05-21 12:37:25|2026-05-22|7560.0000|C|0.3500|400|CBOE|m
SPXW|SPXW260522C07560000|2026-05-21 12:37:25|2026-05-22|7560.0000|C|0.3500|500|CBOE|m
SPXW|SPXW260522C07560000|2026-05-21 12:37:25|2026-05-22|7560.0000|C|0.3500|1600|CBOE|m
SPXW|SPXW260522C07630000|2026-05-21 12:37:25|2026-05-22|7630.0000|C|0.1500|500|CBOE|m
SPXW|SPXW260522C07630000|2026-05-21 12:37:25|2026-05-22|7630.0000|C|0.1500|1600|CBOE|m
SPXW|SPXW260522C07500000|2026-05-21 12:53:06|2026-05-22|7500.0000|C|1.7500|384|CBOE|
SPXW|SPXW260731P05650000|2026-05-21 13:20:35|2026-07-31|5650.0000|P|12.0800|364|CBOE|f
SPXW|SPXW260731P05700000|2026-05-21 13:20:35|2026-07-31|5700.0000|P|12.7800|364|CBOE|f
SPXW|SPXW260522C07500000|2026-05-21 13:42:11|2026-05-22|7500.0000|C|9.1500|741|CBOE|f
SPXW|SPXW260522C07505000|2026-05-21 13:42:11|2026-05-22|7505.0000|C|7.9500|741|CBOE|f
SPXW|SPXW260522C07485000|2026-05-21 13:45:23|2026-05-22|7485.0000|C|14.1200|316|CBOE|f
SPXW|SPXW260522C07440000|2026-05-21 13:45:23|2026-05-22|7440.0000|C|36.1200|316|CBOE|f
SPXW|SPXW260526C07455000|2026-05-21 13:45:23|2026-05-26|7455.0000|C|40.3300|465|CBOE|f
SPXW|SPXW260526C07480000|2026-05-21 13:45:23|2026-05-26|7480.0000|C|27.8100|465|CBOE|f
SPXW|SPXW260526C07475000|2026-05-21 14:01:38|2026-05-26|7475.0000|C|31.8500|500|CBOE|f
SPXW|SPXW260526C07500000|2026-05-21 14:01:38|2026-05-26|7500.0000|C|21.0000|500|CBOE|f
SPXW|SPXW260731P04000000|2026-05-21 14:06:25|2026-07-31|4000.0000|P|2.2900|700|CBOE|m
SPXW|SPXW260731P04000000|2026-05-21 14:06:25|2026-07-31|4000.0000|P|2.2900|880|CBOE|m
SPXW|SPXW260731P05000000|2026-05-21 14:06:25|2026-07-31|5000.0000|P|6.2400|700|CBOE|m
SPXW|SPXW260731P05000000|2026-05-21 14:06:25|2026-07-31|5000.0000|P|6.2400|1580|CBOE|m
SPXW|SPXW260529P06960000|2026-05-21 14:07:21|2026-05-29|6960.0000|P|1.7000|691|CBOE|e
SPXW|SPXW260529P06960000|2026-05-21 14:07:21|2026-05-29|6960.0000|P|1.7000|1000|CBOE|e
SPXW|SPXW260618C07700000|2026-05-21 14:14:00|2026-06-18|7700.0000|C|27.8500|414|CBOE|f
SPXW|SPXW260601C07400000|2026-05-21 14:17:29|2026-06-01|7400.0000|C|97.9400|800|CBOE|t
SPXW|SPXW260601P07400000|2026-05-21 14:17:29|2026-06-01|7400.0000|P|42.9700|1000|CBOE|t
SPXW|SPXW260526C07500000|2026-05-21 14:28:52|2026-05-26|7500.0000|C|19.3300|427|CBOE|f
SPXW|SPXW260526C07475000|2026-05-21 14:28:52|2026-05-26|7475.0000|C|29.6100|427|CBOE|f
SPXW|SPXW260630C08000000|2026-05-21 14:30:28|2026-06-30|8000.0000|C|5.3800|500|CBOE|t
SPXW|SPXW260630C08000000|2026-05-21 14:38:15|2026-06-30|8000.0000|C|5.3200|700|CBOE|t
SPXW|SPXW260529P06450000|2026-05-21 14:43:44|2026-05-29|6450.0000|P|0.3500|500|CBOE|e
SPXW|SPXW260522P07395000|2026-05-21 14:57:49|2026-05-22|7395.0000|P|16.7400|375|CBOE|m
SPXW|SPXW260522P07400000|2026-05-21 14:57:49|2026-05-22|7400.0000|P|18.2900|375|CBOE|m
SPXW|SPXW260522P07220000|2026-05-21 15:05:24|2026-05-22|7220.0000|P|0.6600|477|CBOE|m
SPXW|SPXW260522C07585000|2026-05-21 15:05:24|2026-05-22|7585.0000|C|0.3200|385|CBOE|m
SPXW|SPXW260522P06400000|2026-05-21 15:07:54|2026-05-22|6400.0000|P|0.0500|410|CBOE|
SPXW|SPXW260522C07500000|2026-05-21 15:20:13|2026-05-22|7500.0000|C|6.6100|380|CBOE|f
SPXW|SPXW260522P07240000|2026-05-21 15:20:13|2026-05-22|7240.0000|P|0.6000|380|CBOE|f
SPXW|SPXW260605C07510000|2026-05-21 15:20:13|2026-06-05|7510.0000|C|52.8000|380|CBOE|f
SPXW|SPXW260605P07250000|2026-05-21 15:20:13|2026-06-05|7250.0000|P|26.4100|380|CBOE|f
SPXW|SPXW260527C07625000|2026-05-21 15:23:08|2026-05-27|7625.0000|C|1.0500|500|CBOE|t
SPXW|SPXW260527P07000000|2026-05-21 15:23:08|2026-05-27|7000.0000|P|0.7300|500|CBOE|t
SPXW|SPXW260522P07360000|2026-05-21 15:23:51|2026-05-22|7360.0000|P|4.2300|500|CBOE|m
SPXW|SPXW260522P07365000|2026-05-21 15:23:51|2026-05-22|7365.0000|P|4.6700|500|CBOE|m
SPXW|SPXW260522C07525000|2026-05-21 15:23:51|2026-05-22|7525.0000|C|2.6200|500|CBOE|m
SPXW|SPXW260522C07530000|2026-05-21 15:23:51|2026-05-22|7530.0000|C|2.2100|500|CBOE|m
SPXW|SPXW260522C07575000|2026-05-21 15:30:33|2026-05-22|7575.0000|C|0.4500|2985|CBOE|m
SPXW|SPXW260522C07645000|2026-05-21 15:30:33|2026-05-22|7645.0000|C|0.1500|2985|CBOE|m
SPXW|SPXW260522P07350000|2026-05-21 15:32:36|2026-05-22|7350.0000|P|3.3300|500|CBOE|m
SPXW|SPXW260522P07375000|2026-05-21 15:32:36|2026-05-22|7375.0000|P|5.5800|500|CBOE|m
SPXW|SPXW260526C07600000|2026-05-21 15:40:13|2026-05-26|7600.0000|C|1.0800|625|CBOE|t
SPXW|SPXW260522P07240000|2026-05-21 15:41:32|2026-05-22|7240.0000|P|0.5100|999|CBOE|m
SPXW|SPXW260522P07140000|2026-05-21 15:41:32|2026-05-22|7140.0000|P|0.3100|999|CBOE|m
SPXW|SPXW260601P07025000|2026-05-21 15:43:23|2026-06-01|7025.0000|P|3.3000|608|CBOE|f
SPXW|SPXW260601P07050000|2026-05-21 15:43:23|2026-06-01|7050.0000|P|3.8000|608|CBOE|f
SPXW|SPXW260604P06375000|2026-05-21 15:50:48|2026-06-04|6375.0000|P|0.8200|414|CBOE|m
SPXW|SPXW260604P06475000|2026-05-21 15:50:48|2026-06-04|6475.0000|P|1.0200|414|CBOE|m
SPXW|SPXW260604P06525000|2026-05-21 15:50:48|2026-06-04|6525.0000|P|1.1500|414|CBOE|m
SPXW|SPXW260604P06675000|2026-05-21 15:50:48|2026-06-04|6675.0000|P|1.7700|414|CBOE|m
SPXW|SPXW260604P06775000|2026-05-21 15:50:48|2026-06-04|6775.0000|P|2.4500|414|CBOE|m
SPXW|SPXW260604P06825000|2026-05-21 15:50:48|2026-06-04|6825.0000|P|2.8700|414|CBOE|m
SPXW|SPXW260604P06900000|2026-05-21 15:50:48|2026-06-04|6900.0000|P|3.8000|414|CBOE|m
SPXW|SPXW260604P06975000|2026-05-21 15:50:48|2026-06-04|6975.0000|P|5.2000|414|CBOE|m
SPXW|SPXW260528P06450000|2026-05-21 15:50:50|2026-05-28|6450.0000|P|0.1600|414|CBOE|m
SPXW|SPXW260528P06600000|2026-05-21 15:50:50|2026-05-28|6600.0000|P|0.2500|414|CBOE|m
SPXW|SPXW260528P06750000|2026-05-21 15:50:50|2026-05-28|6750.0000|P|0.4500|414|CBOE|m
SPXW|SPXW260528P06850000|2026-05-21 15:50:50|2026-05-28|6850.0000|P|0.5100|414|CBOE|m
SPXW|SPXW260528P06900000|2026-05-21 15:50:50|2026-05-28|6900.0000|P|0.7400|414|CBOE|m
SPXW|SPXW260528P06975000|2026-05-21 15:50:50|2026-05-28|6975.0000|P|0.9900|414|CBOE|m
SPXW|SPXW260528P07050000|2026-05-21 15:50:50|2026-05-28|7050.0000|P|1.4500|414|CBOE|m
SPXW|SPXW260522P07360000|2026-05-21 15:54:02|2026-05-22|7360.0000|P|4.0900|716|CBOE|f
SPXW|SPXW260522P07360000|2026-05-21 15:54:02|2026-05-22|7360.0000|P|4.1000|694|CBOE|f
SPXW|SPXW260522P07370000|2026-05-21 15:54:02|2026-05-22|7370.0000|P|5.0900|716|CBOE|f
SPXW|SPXW260522P07370000|2026-05-21 15:54:02|2026-05-22|7370.0000|P|5.1000|694|CBOE|f
SPXW|SPXW260522P07370000|2026-05-21 15:55:18|2026-05-22|7370.0000|P|5.3500|400|CBOE|m
SPXW|SPXW260522P07370000|2026-05-21 15:55:18|2026-05-22|7370.0000|P|5.3500|720|CBOE|m
SPXW|SPXW260522P07360000|2026-05-21 15:55:18|2026-05-22|7360.0000|P|4.3500|400|CBOE|m
SPXW|SPXW260522P07360000|2026-05-21 15:55:18|2026-05-22|7360.0000|P|4.3500|720|CBOE|m
SPXW|SPXW260522P07360000|2026-05-21 15:55:53|2026-05-22|7360.0000|P|4.0000|500|CBOE|m
SPXW|SPXW260522P07370000|2026-05-21 15:55:53|2026-05-22|7370.0000|P|5.0000|500|CBOE|m
SPXW|SPXW260522P07360000|2026-05-21 15:56:10|2026-05-22|7360.0000|P|4.0000|500|CBOE|m

## 30-Minute Price Bars (Last 5 Days)

TimeIntervalStart|Open|High|Low|Close|Volume|NumOfSale|VWAP
2026-05-18 08:30:00|7415.0700|7434.0600|7394.1100|7424.9800|0|1781|0.000000
2026-05-18 09:00:00|7425.7400|7427.6000|7405.9100|7413.8500|0|1781|0.000000
2026-05-18 09:30:00|7413.6800|7417.2400|7383.3100|7402.4100|0|1780|0.000000
2026-05-18 10:00:00|7401.8500|7409.6100|7374.3400|7375.0800|0|1766|0.000000
2026-05-18 10:30:00|7375.0100|7392.0500|7371.7500|7380.1700|0|1347|0.000000
2026-05-18 11:00:00|7382.3800|7397.9300|7364.9300|7366.4800|0|1760|0.000000
2026-05-18 11:30:00|7366.7700|7392.2600|7361.4700|7384.3100|0|1754|0.000000
2026-05-18 12:00:00|7384.4100|7392.9800|7379.5100|7392.6800|0|1751|0.000000
2026-05-18 12:30:00|7392.8500|7393.2100|7381.8000|7389.6500|0|1743|0.000000
2026-05-18 13:00:00|7389.4600|7390.1700|7356.1000|7365.4200|0|1747|0.000000
2026-05-18 13:30:00|7365.6300|7370.1100|7353.1700|7355.3500|0|1755|0.000000
2026-05-18 14:00:00|7355.3400|7397.3200|7355.0000|7373.6800|0|1769|0.000000
2026-05-18 14:30:00|7373.7400|7406.0400|7371.6900|7403.1000|0|1763|0.000000
2026-05-19 08:30:00|7375.7500|7381.6400|7349.5000|7371.8200|0|1786|0.000000
2026-05-19 09:00:00|7372.5400|7372.5400|7335.0500|7341.4800|0|1785|0.000000
2026-05-19 09:30:00|7341.5900|7352.2300|7333.6800|7349.3200|0|1775|0.000000
2026-05-19 10:00:00|7349.7300|7358.1100|7335.8500|7341.4600|0|1758|0.000000
2026-05-19 10:30:00|7341.1000|7357.6100|7339.5100|7356.0600|0|1329|0.000000
2026-05-19 11:00:00|7348.0500|7366.0000|7341.7600|7363.7200|0|1748|0.000000
2026-05-19 11:30:00|7363.6000|7381.9400|7362.3600|7380.5500|0|1755|0.000000
2026-05-19 12:00:00|7380.3500|7395.3200|7378.8100|7388.8100|0|1747|0.000000
2026-05-19 12:30:00|7388.7900|7394.5700|7378.5600|7386.8000|0|1751|0.000000
2026-05-19 13:00:00|7386.8800|7391.5400|7377.5700|7377.6700|0|1738|0.000000
2026-05-19 13:30:00|7377.7100|7382.6600|7362.0800|7363.5300|0|1743|0.000000
2026-05-19 14:00:00|7363.3300|7379.5900|7357.6700|7365.7800|0|1748|0.000000
2026-05-19 14:30:00|7365.7200|7368.7500|7343.9000|7354.9600|0|1756|0.000000
2026-05-20 08:30:00|7369.1900|7391.6000|7360.9600|7379.8800|0|1776|0.000000
2026-05-20 09:00:00|7380.8700|7402.1800|7357.4600|7396.7500|0|1782|0.000000
2026-05-20 09:30:00|7397.5600|7413.1900|7394.4000|7411.8500|0|1757|0.000000
2026-05-20 10:00:00|7411.2900|7435.6900|7404.5000|7410.6200|0|1758|0.000000
2026-05-20 10:30:00|7410.9800|7427.6400|7410.9800|7427.6400|0|1342|0.000000
2026-05-20 11:00:00|7421.1600|7423.4400|7404.8400|7408.3700|0|1746|0.000000
2026-05-20 11:30:00|7408.2300|7418.4200|7404.3900|7412.2400|0|1751|0.000000
2026-05-20 12:00:00|7412.3100|7421.5500|7406.6300|7420.3000|0|1737|0.000000
2026-05-20 12:30:00|7420.3500|7425.8200|7415.1800|7417.4000|0|1716|0.000000
2026-05-20 13:00:00|7417.4800|7422.7500|7412.3600|7419.2600|0|1720|0.000000
2026-05-20 13:30:00|7419.3400|7427.2200|7416.3100|7419.8500|0|1718|0.000000
2026-05-20 14:00:00|7419.8700|7427.9500|7419.1200|7426.3700|0|1732|0.000000
2026-05-20 14:30:00|7426.5300|7433.5800|7424.5800|7432.7700|0|1749|0.000000
2026-05-21 08:30:00|7410.7800|7418.8600|7392.0300|7416.5700|0|1786|0.000000
2026-05-21 09:00:00|7416.0800|7424.4300|7392.0200|7401.7600|0|1776|0.000000
2026-05-21 09:30:00|7402.1600|7409.9200|7394.3500|7406.7000|0|1766|0.000000
2026-05-21 10:00:00|7406.6300|7410.9300|7389.4800|7405.4600|0|1764|0.000000
2026-05-21 10:30:00|7405.4000|7415.1400|7396.3300|7412.4400|0|1321|0.000000
2026-05-21 11:00:00|7410.0900|7417.0300|7401.9800|7405.6200|0|1725|0.000000
2026-05-21 11:30:00|7405.5700|7409.1600|7398.8200|7407.0800|0|1724|0.000000
2026-05-21 12:00:00|7406.9600|7447.2900|7406.9600|7438.8000|0|1750|0.000000
2026-05-21 12:30:00|7438.7200|7465.9600|7438.2600|7454.2800|0|1765|0.000000
2026-05-21 13:00:00|7454.1600|7458.6200|7444.2100|7451.0500|0|1735|0.000000
2026-05-21 13:30:00|7451.0600|7454.1900|7420.0500|7427.2800|0|1753|0.000000
2026-05-21 14:00:00|7427.3800|7446.1400|7427.3800|7444.2400|0|1725|0.000000
2026-05-21 14:30:00|7444.1600|7448.8500|7437.5000|7446.0500|0|1735|0.000000

## Part 1: Option OI Changes (Yesterday vs Today)
The data below shows option open interest (OI) changes between yesterday and today. Each row represents an option contract where OI changed by more than 300 contracts (top 50 by absolute change).

OIChanges|Strike|PorC|ExpiryDate|Expiry|ASXCode|ObservationDate|OptionSymbol|Bid|BidSize|Ask|AskSize|IV|OpenInterest|Volume|Delta|Gamma|Theta|RHO|Vega|Theo|Change|Open|High|Low|Tick|LastTradePrice|LastTradeTime|PrevDayClose|CreateDate|PrevOpenInterest|PrevLastTradePrice
12897.0000|7640.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07640000|0.0500|132.0000|0.1500|134.0000|0.2357|13675.0000|13648.0000|0.0051|0.0002|-0.1000|0.0000|0.0453|0.1000|-0.1250|0.0500|0.2500|0.0500|no_change|0.1000|2026-05-21 16:09:00|0.150000002235174|2026-05-22 18:31:00|778.0000|0.2500
12258.0000|7560.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07560000|0.5500|71.0000|0.6500|69.0000|0.1725|14221.0000|14889.0000|0.0328|0.0016|-0.6000|0.0000|0.2198|0.6001|0.0250|0.5200|2.1000|0.3000|down|0.5500|2026-05-21 16:14:00|0.575000017881394|2026-05-22 18:31:00|1963.0000|1.9200
10356.0000|7575.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07575000|0.2500|141.0000|0.3500|88.0000|0.1768|12562.0000|11684.0000|0.0175|0.0009|-0.3000|0.0000|0.1327|0.3000|-0.0500|0.3200|1.3000|0.2000|down|0.3400|2026-05-21 16:14:00|0.399999991059303|2026-05-22 18:31:00|2206.0000|1.2700
7950.0000|7075.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07075000|0.0000|0.0000|0.1000|89.0000|0.4994|9088.0000|8401.0000|-0.0014|0.0000|-0.0500|0.0000|0.0129|0.0500|-0.5000|0.4500|0.4800|0.0500|up|0.1500|2026-05-21 16:11:00|0.200000002980232|2026-05-22 18:31:00|1138.0000|0.6500
7416.0000|7175.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07175000|0.0500|155.0000|0.1000|1.0000|0.3951|9934.0000|9677.0000|-0.0024|0.0001|-0.0750|0.0000|0.0223|0.0750|-0.2250|1.1500|1.1500|0.1500|no_change|0.2500|2026-05-21 16:12:00|0.325000002980232|2026-05-22 18:31:00|2518.0000|1.3100
6402.0000|7360.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07360000|1.4000|1.0000|1.4500|48.0000|0.2528|7439.0000|9343.0000|-0.0502|0.0015|-1.4499|0.0000|0.2982|1.4499|-2.4500|19.9900|20.1100|3.1000|down|3.4000|2026-05-21 16:14:00|4.0|2026-05-22 18:31:00|1037.0000|15.1500
6264.0000|7370.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07370000|1.7500|1.0000|1.8000|56.0000|0.2457|7082.0000|9655.0000|-0.0619|0.0018|-1.7999|0.0000|0.3497|1.7999|-3.0000|19.8400|23.0400|3.9700|down|4.1000|2026-05-21 16:14:00|4.95000004768372|2026-05-22 18:31:00|818.0000|17.1800
-5632.0000|7095.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07095000|0.0500|16.0000|0.1000|65.0000|0.4931|1828.0000|463.0000|-0.0020|0.0000|-0.0750|0.0000|0.0183|0.0750|-0.6500|0.4900|0.5100|0.0500|no_change|0.1500|2026-05-21 16:09:00|0.225000001490116|2026-05-22 18:31:00|7460.0000|0.6300
-5551.0000|7195.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07195000|0.1000|12.0000|0.1500|71.0000|0.3898|1217.0000|1208.0000|-0.0039|0.0001|-0.1250|0.0000|0.0341|0.1250|-1.6200|1.4200|1.5000|0.1500|up|0.3200|2026-05-21 16:14:00|0.350000008940697|2026-05-22 18:31:00|6768.0000|1.6300
5386.0000|7635.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07635000|0.0500|115.0000|0.1500|131.0000|0.2295|5766.0000|5459.0000|0.0052|0.0002|-0.1000|0.0000|0.0464|0.1000|0.0000|0.1000|0.3000|0.1000|down|0.1000|2026-05-21 16:09:00|0.150000002235174|2026-05-22 18:31:00|380.0000|0.3000
5321.0000|7500.0000|C|2026-05-26|20260526|SPXW.US|2026-05-21|SPXW260526C07500000|22.9000|7.0000|23.1000|7.0000|0.1044|7362.0000|8598.0000|0.3792|0.0044|-3.8600|0.0769|3.1665|22.5802|9.0000|9.3000|24.7000|6.5700|up|17.0000|2026-05-21 16:14:00|14.2000002861023|2026-05-22 18:31:00|2041.0000|18.3000
5172.0000|7565.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07565000|0.4500|64.0000|0.5000|16.0000|0.1725|5878.0000|6043.0000|0.0255|0.0013|-0.4500|0.0000|0.1804|0.4500|0.0200|0.3500|1.7700|0.2500|no_change|0.5000|2026-05-21 16:14:00|0.5|2026-05-22 18:31:00|706.0000|1.7000
5050.0000|7375.0000|P|2026-05-26|20260526|SPXW.US|2026-05-21|SPXW260526P07375000|9.8000|12.0000|10.0000|13.0000|0.1279|5404.0000|5896.0000|-0.1761|0.0024|-3.0476|-0.0360|2.2030|10.0019|-5.9000|33.8000|36.5500|12.9700|down|14.9000|2026-05-21 16:12:00|15.5999999046326|2026-05-22 18:31:00|354.0000|28.2700
4809.0000|7210.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07210000|0.1000|87.0000|0.1500|46.0000|0.3704|5404.0000|5698.0000|-0.0041|0.0001|-0.1250|0.0000|0.0357|0.1250|-0.2500|1.9000|2.0300|0.1500|no_change|0.3000|2026-05-21 16:09:00|0.399999991059303|2026-05-22 18:31:00|595.0000|1.9500
4801.0000|7655.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07655000|0.0500|89.0000|0.1500|131.0000|0.2542|5293.0000|4927.0000|0.0048|0.0002|-0.1000|0.0000|0.0422|0.1000|-0.1050|0.1500|0.2100|0.0500|no_change|0.1000|2026-05-21 16:09:00|0.12500000372529|2026-05-22 18:31:00|492.0000|0.2000
4452.0000|7550.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07550000|0.9000|106.0000|1.0000|59.0000|0.1695|8522.0000|10464.0000|0.0484|0.0022|-0.9250|0.0000|0.2970|0.9250|0.0750|0.6800|3.0500|0.3500|up|0.8500|2026-05-21 16:14:00|0.825000017881394|2026-05-22 18:31:00|4070.0000|2.7800
4423.0000|7085.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07085000|0.0500|14.0000|0.1000|102.0000|0.5053|4778.0000|4600.0000|-0.0020|0.0000|-0.0750|0.0000|0.0178|0.0750|-0.6000|0.5000|0.5000|0.0500|no_change|0.1000|2026-05-21 16:09:00|0.225000001490116|2026-05-22 18:31:00|355.0000|0.6500
4385.0000|7120.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07120000|0.0500|36.0000|0.1000|59.0000|0.4625|5780.0000|5563.0000|-0.0021|0.0000|-0.0750|0.0000|0.0193|0.0750|-0.8250|0.6200|0.6500|0.0800|no_change|0.1500|2026-05-21 16:09:00|0.250000007450581|2026-05-22 18:31:00|1395.0000|0.7000
4245.0000|7185.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07185000|0.0500|159.0000|0.1500|88.0000|0.3937|5108.0000|5661.0000|-0.0032|0.0001|-0.1000|0.0000|0.0283|0.1000|-0.2000|1.2200|1.3500|0.1000|up|0.3000|2026-05-21 16:14:00|0.350000008940697|2026-05-22 18:31:00|863.0000|1.4000
4030.0000|7500.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07500000|9.2000|17.0000|9.4000|29.0000|0.1816|10889.0000|27634.0000|0.2910|0.0069|-9.0510|0.0000|0.9464|9.0510|3.9500|3.7000|13.4200|1.6500|up|6.2000|2026-05-21 16:14:00|4.95000004768372|2026-05-22 18:31:00|6859.0000|10.8000
3958.0000|7540.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07540000|1.5000|64.0000|1.6000|55.0000|0.1689|5211.0000|7474.0000|0.0732|0.0030|-1.5002|0.0000|0.4040|1.5002|0.4250|0.9500|4.2000|0.4500|up|1.2500|2026-05-21 16:14:00|1.125|2026-05-22 18:31:00|1253.0000|3.6900
3722.0000|7435.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07435000|47.0000|1.0000|47.7000|2.0000|0.2146|4138.0000|6594.0000|0.7401|0.0055|-9.2503|0.0000|0.8962|46.6801|17.4000|19.2000|47.0000|13.0000|down|32.9700|2026-05-21 16:12:00|29.6999998092651|2026-05-22 18:31:00|416.0000|34.1000
3687.0000|7350.0000|P|2026-05-26|20260526|SPXW.US|2026-05-21|SPXW260526P07350000|7.0000|24.0000|7.2000|15.0000|0.1335|5801.0000|6240.0000|-0.1308|0.0019|-2.5345|-0.0267|1.8274|7.1703|-3.4000|26.4000|28.4000|9.3300|up|10.9900|2026-05-21 16:12:00|11.4000000953674|2026-05-22 18:31:00|2114.0000|22.8000
3500.0000|7350.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07350000|1.0500|59.0000|1.1500|70.0000|0.2590|6257.0000|11361.0000|-0.0403|0.0012|-1.1500|0.0000|0.2508|1.1500|-2.1300|15.2000|17.4000|2.4200|down|2.7000|2026-05-21 16:14:00|3.19999992847443|2026-05-22 18:31:00|2757.0000|13.1600
3491.0000|7375.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07375000|1.9500|24.0000|2.0500|61.0000|0.2433|4281.0000|6649.0000|-0.0697|0.0020|-2.0498|0.0000|0.3824|2.0499|-3.4000|24.2400|25.0000|4.4000|down|4.7000|2026-05-21 16:14:00|5.5|2026-05-22 18:31:00|790.0000|18.4300
3184.0000|7240.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07240000|0.1500|53.0000|0.2000|70.0000|0.3440|4747.0000|6306.0000|-0.0060|0.0002|-0.1750|0.0000|0.0497|0.1750|-0.3000|2.8000|2.9800|0.2500|up|0.4500|2026-05-21 16:13:00|0.5|2026-05-22 18:31:00|1563.0000|3.0100
3107.0000|7570.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07570000|0.3500|76.0000|0.4500|127.0000|0.1752|4677.0000|4425.0000|0.0214|0.0011|-0.3750|0.0000|0.1568|0.3750|-0.0750|0.3400|1.5000|0.2500|no_change|0.4000|2026-05-21 16:14:00|0.424999997019768|2026-05-22 18:31:00|1570.0000|1.3000
3054.0000|7215.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07215000|0.1000|118.0000|0.1500|46.0000|0.3640|3709.0000|3831.0000|-0.0042|0.0001|-0.1250|0.0000|0.0362|0.1250|-0.2500|1.9300|1.9500|0.2000|no_change|0.3000|2026-05-21 16:09:00|0.399999991059303|2026-05-22 18:31:00|655.0000|2.1500
3030.0000|7645.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07645000|0.0500|82.0000|0.1500|125.0000|0.2419|4118.0000|3202.0000|0.0050|0.0002|-0.1000|0.0000|0.0442|0.1000|-0.1250|0.1500|0.2500|0.0900|no_change|0.1000|2026-05-21 16:09:00|0.175000004470348|2026-05-22 18:31:00|1088.0000|0.2500
2898.0000|5000.0000|P|2026-07-31|20260731|SPXW.US|2026-05-21|SPXW260731P05000000|5.7000|154.0000|6.1000|90.0000|0.4274|7028.0000|2933.0000|-0.0120|0.0000|-0.3000|-0.1760|1.0553|5.9445|-0.6000|6.9000|6.9000|6.1000|down|6.1000|2026-05-21 14:25:00|6.04999995231628|2026-05-22 18:31:00|4130.0000|6.9000
2880.0000|4000.0000|C|2026-07-31|20260731|SPXW.US|2026-05-21|SPXW260731C04000000|3484.9000|1.0000|3503.6000|2.0000|0.5522|2885.0000|2880.0000|0.9969|0.0000|-0.1335|7.4574|0.3625|3494.4753|16.4400|3470.4900|3470.4900|3470.4900|no_change|3470.4900|2026-05-21 14:06:00|3465.15002441406|2026-05-22 18:31:00|5.0000|3420.6000
2880.0000|5000.0000|C|2026-07-31|20260731|SPXW.US|2026-05-21|SPXW260731C05000000|2500.7000|1.0000|2510.3000|1.0000|0.4234|6381.0000|2880.0000|0.9885|0.0000|-0.3000|9.2090|1.0553|2505.9296|16.3900|2482.4900|2482.4900|2482.4900|no_change|2482.4900|2026-05-21 14:06:00|2476.79992675781|2026-05-22 18:31:00|3501.0000|2434.3800
2876.0000|4000.0000|P|2026-07-31|20260731|SPXW.US|2026-05-21|SPXW260731P04000000|2.0500|151.0000|2.2500|32.0000|0.5615|3308.0000|2880.0000|-0.0036|0.0000|-0.1335|-0.0530|0.3624|2.0683|-0.2600|2.2900|2.2900|2.2900|no_change|2.2900|2026-05-21 14:06:00|2.25|2026-05-22 18:31:00|432.0000|3.1500
2804.0000|6960.0000|P|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529P06960000|1.2000|8.0000|1.3000|34.0000|0.2305|3331.0000|2957.0000|-0.0145|0.0001|-0.5194|-0.0175|0.4250|1.2232|-1.3950|2.8900|3.1700|1.2000|up|1.3800|2026-05-21 16:02:00|1.47499996423721|2026-05-22 18:31:00|527.0000|2.9000
2778.0000|7475.0000|C|2026-05-26|20260526|SPXW.US|2026-05-21|SPXW260526C07475000|35.1000|7.0000|35.4000|7.0000|0.1085|3414.0000|3802.0000|0.4923|0.0044|-4.2428|0.0997|3.3065|34.7515|12.4000|15.5800|35.2500|11.6700|down|26.4800|2026-05-21 16:14:00|23.0|2026-05-22 18:31:00|636.0000|28.2500
2592.0000|7400.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07400000|3.7000|3.0000|3.8000|45.0000|0.2303|7603.0000|13032.0000|-0.1231|0.0032|-3.8497|0.0000|0.5735|3.8497|-5.7000|31.1000|35.4000|7.2000|down|8.0000|2026-05-21 16:14:00|9.5|2026-05-22 18:31:00|5011.0000|25.4000
2454.0000|7505.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07505000|7.6000|18.0000|7.8000|30.0000|0.1795|3128.0000|5830.0000|0.2550|0.0065|-7.4988|0.0000|0.8899|7.4988|3.8500|3.1800|11.5000|1.4300|no_change|5.2000|2026-05-21 16:14:00|4.14999985694885|2026-05-22 18:31:00|674.0000|9.3700
2443.0000|7630.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07630000|0.1000|1.0000|0.1500|107.0000|0.2289|3238.0000|2778.0000|0.0064|0.0003|-0.1250|0.0000|0.0552|0.1250|-0.0500|0.1500|0.3000|0.1000|up|0.2000|2026-05-21 16:14:00|0.150000002235174|2026-05-22 18:31:00|795.0000|0.3000
2419.0000|7625.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07625000|0.0500|123.0000|0.1500|102.0000|0.2171|5330.0000|3389.0000|0.0055|0.0003|-0.1000|0.0000|0.0488|0.1000|-0.0250|0.1000|0.3500|0.1000|up|0.1800|2026-05-21 16:12:00|0.175000004470348|2026-05-22 18:31:00|2911.0000|0.3500
2417.0000|7115.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07115000|0.0500|33.0000|0.1000|60.0000|0.4686|2968.0000|2673.0000|-0.0021|0.0000|-0.0750|0.0000|0.0191|0.0750|-0.7250|0.5900|0.6200|0.1000|no_change|0.1500|2026-05-21 16:09:00|0.250000007450581|2026-05-22 18:31:00|551.0000|0.6500
2324.0000|5600.0000|P|2026-05-27|20260527|SPXW.US|2026-05-21|SPXW260527P05600000|0.0000|0.0000|0.1000|176.0000|0.6997|3164.0000|2352.0000|-0.0002|0.0000|-0.0285|-0.0001|0.0083|0.0343|-0.0450|0.0500|0.0800|0.0300|down|0.0300|2026-05-21 15:47:00|0.025000000372529|2026-05-22 18:31:00|840.0000|0.1500
2290.0000|7300.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07300000|0.3500|136.0000|0.4500|74.0000|0.2921|9344.0000|10900.0000|-0.0144|0.0005|-0.4000|0.0000|0.1076|0.4000|-0.7750|7.1400|8.1200|0.7500|no_change|1.0500|2026-05-21 16:14:00|1.17500001192093|2026-05-22 18:31:00|7054.0000|6.8000
2273.0000|7140.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07140000|0.0500|45.0000|0.1000|58.0000|0.4380|3471.0000|3570.0000|-0.0022|0.0001|-0.0750|0.0000|0.0203|0.0750|-0.2050|0.7900|0.8100|0.1000|no_change|0.1500|2026-05-21 16:09:00|0.275000005960464|2026-05-22 18:31:00|1198.0000|0.8500
2249.0000|7150.0000|P|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529P07150000|3.5000|45.0000|3.7000|69.0000|0.1846|14509.0000|3387.0000|-0.0452|0.0005|-1.1593|-0.0550|1.0791|3.6084|-0.9500|9.7000|10.0000|4.0600|down|4.3500|2026-05-21 16:11:00|4.54999995231628|2026-05-22 18:31:00|12260.0000|8.6600
2175.0000|6450.0000|P|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529P06450000|0.2500|13.0000|0.3000|12.0000|0.3698|4252.0000|2540.0000|-0.0026|0.0000|-0.1601|-0.0030|0.0897|0.2867|-0.1500|0.4500|0.4600|0.3500|no_change|0.3500|2026-05-21 14:43:00|0.325000002980232|2026-05-22 18:31:00|2077.0000|0.5100
2100.0000|7300.0000|P|2026-05-26|20260526|SPXW.US|2026-05-21|SPXW260526P07300000|3.7000|3.0000|3.9000|28.0000|0.1451|4459.0000|4713.0000|-0.0725|0.0011|-1.6859|-0.0147|1.2116|3.8097|-2.0500|15.6800|16.9700|5.0500|no_change|5.8000|2026-05-21 16:14:00|6.04999995231628|2026-05-22 18:31:00|2359.0000|13.5000
2050.0000|7145.0000|P|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529P07145000|3.4000|25.0000|3.5000|22.0000|0.1859|2351.0000|2183.0000|-0.0437|0.0005|-1.1314|-0.0531|1.0498|3.4850|-3.9700|9.1000|9.4000|3.9500|down|3.9500|2026-05-21 15:57:00|4.40000009536743|2026-05-22 18:31:00|301.0000|8.4500
1989.0000|7910.0000|C|2026-06-30|20260630|SPXW.US|2026-05-21|SPXW260630C07910000|12.0000|32.0000|12.5000|51.0000|0.1209|2023.0000|2006.0000|0.0920|0.0006|-0.6096|0.6572|4.3020|12.2390|0.7500|7.2100|11.1500|7.2100|up|11.1500|2026-05-21 14:04:00|9.2999997138977|2026-05-22 18:31:00|34.0000|9.8700
1981.0000|7605.0000|C|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529C07605000|8.6000|16.0000|8.9000|12.0000|0.1109|2163.0000|2243.0000|0.1447|0.0019|-1.7782|0.1748|2.5404|8.6236|3.3000|3.6000|9.6000|2.8400|up|4.9200|2026-05-21 15:54:00|5.20000004768372|2026-05-22 18:31:00|182.0000|7.7000
1968.0000|7530.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07530000|2.5000|49.0000|2.6000|27.0000|0.1701|2906.0000|5311.0000|0.1095|0.0040|-2.4503|0.0000|0.5359|2.4503|0.9000|1.2900|5.7000|0.6300|up|1.9000|2026-05-21 16:14:00|1.65000003576279|2026-05-22 18:31:00|938.0000|5.0000

## Part 2: 

The data below shows the top 50 option contracts by current open interest, filtered to options expiring within 90 days.
**CRITICAL: Use this data to identify Gamma Walls (Call Wall/Put Wall).** Analyze the concentration of open interest at specific strikes to determine key support and resistance levels.

Strike|PorC|ExpiryDate|Expiry|ASXCode|ObservationDate|OptionSymbol|Bid|BidSize|Ask|AskSize|IV|OpenInterest|Volume|Delta|Gamma|Theta|RHO|Vega|Theo|Change|Open|High|Low|Tick|LastTradePrice|LastTradeTime|PrevDayClose|CreateDate
6000.0000|P|2026-06-30|20260630|SPXW.US|2026-05-21|SPXW260630P06000000|5.2000|153.0000|5.5000|87.0000|0.3305|65542.0000|51.0000|-0.0182|0.0000|-0.4386|-0.1357|1.1399|5.3520|-0.9000|7.0000|7.0000|5.6000|no_change|5.6000|2026-05-21 15:58:00|5.65000009536743|2026-05-22 18:31:00
5900.0000|P|2026-06-30|20260630|SPXW.US|2026-05-21|SPXW260630P05900000|4.5000|133.0000|4.8000|92.0000|0.3448|54483.0000|8.0000|-0.0155|0.0000|-0.3984|-0.1159|0.9953|4.6713|0.1000|5.7000|5.7000|5.7000|no_change|5.7000|2026-05-21 10:00:00|4.95000004768372|2026-05-22 18:31:00
5900.0000|P|2026-06-26|20260626|SPXW.US|2026-05-21|SPXW260626P05900000|3.7000|183.0000|4.0000|93.0000|0.3540|52670.0000|8.0000|-0.0136|0.0000|-0.3842|-0.0955|0.8423|3.9123|-0.5500|5.0000|5.0000|4.2000|down|4.2000|2026-05-21 14:16:00|4.09999990463257|2026-05-22 18:31:00
5800.0000|P|2026-06-26|20260626|SPXW.US|2026-05-21|SPXW260626P05800000|3.2000|164.0000|3.5000|98.0000|0.3691|50107.0000|6.0000|-0.0116|0.0000|-0.3468|-0.0810|0.7304|3.4007|0.2100|4.3000|4.3100|4.3000|up|4.3100|2026-05-21 11:05:00|3.60000002384186|2026-05-22 18:31:00
5750.0000|P|2026-06-18|20260618|SPXW.US|2026-05-21|SPXW260618P05750000|1.6500|230.0000|1.8500|55.0000|0.3972|49083.0000|2.0000|-0.0069|0.0000|-0.2678|-0.0382|0.4102|1.8098|-0.1500|1.9500|2.0500|1.9500|up|2.0500|2026-05-21 15:18:00|1.94999998807907|2026-05-22 18:31:00
5850.0000|P|2026-06-18|20260618|SPXW.US|2026-05-21|SPXW260618P05850000|1.9500|199.0000|2.2000|128.0000|0.3817|49055.0000|0.0000|-0.0083|0.0000|-0.3029|-0.0458|0.4827|2.1261|0.0000|0.0000|0.0000|0.0000|down|2.6500|2026-05-20 15:17:00|2.27499997615814|2026-05-22 18:31:00
5600.0000|P|2026-06-12|20260612|SPXW.US|2026-05-21|SPXW260612P05600000|0.6000|148.0000|0.7500|83.0000|0.4410|48533.0000|33.0000|-0.0027|0.0000|-0.1384|-0.0110|0.1591|0.6284|-0.1250|0.9500|0.9500|0.7500|down|0.7500|2026-05-21 13:41:00|0.775000005960464|2026-05-22 18:31:00
5580.0000|P|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529P05580000|0.0500|17.0000|0.1000|36.0000|0.6246|47303.0000|1.0000|-0.0005|0.0000|-0.0540|-0.0006|0.0192|0.0819|0.0000|0.1500|0.1500|0.1500|up|0.1500|2026-05-21 10:34:00|0.100000003352761|2026-05-22 18:31:00
5480.0000|P|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529P05480000|0.0500|16.0000|0.1000|69.0000|0.6608|47251.0000|1.0000|-0.0004|0.0000|-0.0490|-0.0005|0.0167|0.0734|-0.0750|0.0500|0.0500|0.0500|down|0.0500|2026-05-21 10:34:00|0.100000003352761|2026-05-22 18:31:00
5700.0000|P|2026-06-12|20260612|SPXW.US|2026-05-21|SPXW260612P05700000|0.7000|141.0000|0.8500|60.0000|0.4222|46629.0000|27.0000|-0.0033|0.0000|-0.1593|-0.0135|0.1900|0.7473|-0.1550|1.1000|1.1000|0.8700|down|0.8700|2026-05-21 15:29:00|0.900000005960464|2026-05-22 18:31:00
5600.0000|P|2026-06-05|20260605|SPXW.US|2026-05-21|SPXW260605P05600000|0.1500|207.0000|0.3500|218.0000|0.4889|42011.0000|16.0000|-0.0012|0.0000|-0.0826|-0.0031|0.0613|0.2298|-0.0500|0.3500|0.3500|0.3000|down|0.3000|2026-05-21 13:47:00|0.325000002980232|2026-05-22 18:31:00
8200.0000|C|2026-07-31|20260731|SPXW.US|2026-05-21|SPXW260731C08200000|11.0000|7.0000|11.5000|81.0000|0.1269|40364.0000|0.0000|0.0645|0.0003|-0.3650|0.8765|4.4536|11.1512|0.0000|0.0000|0.0000|0.0000|no_change|9.7300|2026-05-20 16:05:00|9.0499997138977|2026-05-22 18:31:00
5700.0000|P|2026-06-05|20260605|SPXW.US|2026-05-21|SPXW260605P05700000|0.1500|196.0000|0.3500|127.0000|0.4612|39784.0000|103.0000|-0.0014|0.0000|-0.0919|-0.0036|0.0713|0.2611|-0.1250|0.4000|0.4000|0.3000|no_change|0.3000|2026-05-21 16:03:00|0.325000002980232|2026-05-22 18:31:00
8400.0000|C|2026-07-31|20260731|SPXW.US|2026-05-21|SPXW260731C08400000|4.0000|73.0000|4.4000|158.0000|0.1286|37178.0000|0.0000|0.0273|0.0001|-0.1825|0.3694|2.3238|4.1582|0.0000|0.0000|0.0000|0.0000|down|3.6500|2026-05-20 15:45:00|3.35000002384186|2026-05-22 18:31:00
5000.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P05000000|0.0000|0.0000|0.0500|464.0000|3.0608|31085.0000|60.0000|0.0000|0.0000|-0.0016|0.0000|0.0001|0.0016|0.0250|0.0500|0.0500|0.0500|no_change|0.0500|2026-05-21 14:03:00|0.025000000372529|2026-05-22 18:31:00
5100.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P05100000|0.0000|0.0000|0.0500|455.0000|2.9173|29096.0000|19.0000|0.0000|0.0000|-0.0043|0.0000|0.0003|0.0043|0.0250|0.0500|0.0500|0.0500|no_change|0.0500|2026-05-21 15:47:00|0.025000000372529|2026-05-22 18:31:00
8600.0000|C|2026-07-31|20260731|SPXW.US|2026-05-21|SPXW260731C08600000|1.7000|99.0000|1.9500|61.0000|0.1345|26357.0000|0.0000|0.0130|0.0001|-0.1006|0.1745|1.2769|1.8737|0.0000|0.0000|0.0000|0.0000|up|1.5700|2026-05-20 15:19:00|1.47499996423721|2026-05-22 18:31:00
6800.0000|P|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529P06800000|0.6500|12.0000|0.7500|121.0000|0.2738|24276.0000|394.0000|-0.0073|0.0001|-0.3232|-0.0088|0.2330|0.6720|-0.1250|1.3900|1.3900|0.6500|no_change|0.8200|2026-05-21 16:11:00|0.824999988079071|2026-05-22 18:31:00
8300.0000|C|2026-07-31|20260731|SPXW.US|2026-05-21|SPXW260731C08300000|6.6000|57.0000|7.0000|71.0000|0.1273|22140.0000|0.0000|0.0418|0.0002|-0.2576|0.5667|3.2261|6.7174|0.0000|0.0000|0.0000|0.0000|up|5.6000|2026-05-20 14:17:00|5.45000004768372|2026-05-22 18:31:00
6900.0000|P|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529P06900000|0.9000|26.0000|1.0000|8.0000|0.2462|21426.0000|413.0000|-0.0110|0.0001|-0.4270|-0.0132|0.3331|0.9526|-1.0050|2.3000|2.3400|1.0000|no_change|1.1000|2026-05-21 16:00:00|1.17500001192093|2026-05-22 18:31:00
7000.0000|P|2026-06-30|20260630|SPXW.US|2026-05-21|SPXW260630P07000000|33.3000|16.0000|33.8000|23.0000|0.1945|20615.0000|125.0000|-0.1370|0.0005|-1.3157|-1.0324|5.5064|33.6400|-2.5300|46.8600|48.4900|35.5500|down|35.5500|2026-05-21 15:59:00|36.3500003814697|2026-05-22 18:31:00
6000.0000|C|2026-06-30|20260630|SPXW.US|2026-05-21|SPXW260630C06000000|1491.0000|1.0000|1499.2000|1.0000|0.3311|19800.0000|4.0000|0.9821|0.0000|-0.4386|5.7586|1.1400|1494.1373|13.8000|1430.9900|1477.6500|1430.9900|down|1469.8500|2026-05-21 15:48:00|1465.79998779297|2026-05-22 18:31:00
6180.0000|P|2026-06-30|20260630|SPXW.US|2026-05-21|SPXW260630P06180000|6.8000|74.0000|7.1000|78.0000|0.3047|18875.0000|23.0000|-0.0245|0.0001|-0.5227|-0.1832|1.4676|6.9056|-1.1000|9.2000|9.2000|7.3000|down|7.3000|2026-05-21 15:36:00|7.34999990463257|2026-05-22 18:31:00
5200.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P05200000|0.0000|0.0000|0.0500|453.0000|2.7764|18439.0000|1.0000|-0.0001|0.0000|-0.0107|0.0000|0.0007|0.0107|0.0050|0.0300|0.0300|0.0300|down|0.0300|2026-05-21 11:31:00|0.025000000372529|2026-05-22 18:31:00
7000.0000|C|2026-06-30|20260630|SPXW.US|2026-05-21|SPXW260630C07000000|525.7000|4.0000|528.6000|4.0000|0.1942|17305.0000|7.0000|0.8633|0.0005|-1.3157|5.8436|5.5064|526.3628|11.7000|466.7800|509.1500|466.7800|down|508.9000|2026-05-21 14:48:00|501.350006103516|2026-05-22 18:31:00
5350.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P05350000|0.0000|0.0000|0.0500|440.0000|2.5695|16926.0000|8.0000|-0.0002|0.0000|-0.0250|0.0000|0.0016|0.0250|0.0250|0.0500|0.0500|0.0500|no_change|0.0500|2026-05-21 10:50:00|0.025000000372529|2026-05-22 18:31:00
5250.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P05250000|0.0000|0.0000|0.0500|446.0000|2.7068|16731.0000|0.0000|-0.0001|0.0000|-0.0164|0.0000|0.0011|0.0164|0.0000|0.0000|0.0000|0.0000|no_change|0.0200|2026-05-18 15:44:00|0.025000000372529|2026-05-22 18:31:00
6200.0000|P|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529P06200000|0.1500|14.0000|0.2500|161.0000|0.4462|15373.0000|88.0000|-0.0015|0.0000|-0.1106|-0.0017|0.0532|0.1857|-0.1250|0.3100|0.3100|0.2000|no_change|0.2000|2026-05-21 15:55:00|0.225000008940697|2026-05-22 18:31:00
6000.0000|P|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529P06000000|0.1000|12.0000|0.2000|165.0000|0.5053|14683.0000|50.0000|-0.0010|0.0000|-0.0856|-0.0012|0.0371|0.1382|-0.1000|0.1500|0.2000|0.1500|no_change|0.1500|2026-05-21 15:40:00|0.175000000745058|2026-05-22 18:31:00
6300.0000|P|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529P06300000|0.1500|84.0000|0.2500|57.0000|0.4109|14563.0000|186.0000|-0.0018|0.0000|-0.1272|-0.0021|0.0650|0.2186|-0.1250|0.3500|0.3500|0.2500|down|0.2500|2026-05-21 15:55:00|0.274999998509884|2026-05-22 18:31:00
7150.0000|P|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529P07150000|3.5000|45.0000|3.7000|69.0000|0.1846|14509.0000|3387.0000|-0.0452|0.0005|-1.1593|-0.0550|1.0791|3.6084|-0.9500|9.7000|10.0000|4.0600|down|4.3500|2026-05-21 16:11:00|4.54999995231628|2026-05-22 18:31:00
6400.0000|P|2026-06-30|20260630|SPXW.US|2026-05-21|SPXW260630P06400000|9.6000|80.0000|9.9000|64.0000|0.2734|14226.0000|19.0000|-0.0363|0.0001|-0.6548|-0.2718|2.0321|9.7182|-1.6700|13.0500|13.0500|10.3300|down|10.3300|2026-05-21 13:52:00|10.3499999046326|2026-05-22 18:31:00
7560.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07560000|0.5500|71.0000|0.6500|69.0000|0.1725|14221.0000|14889.0000|0.0328|0.0016|-0.6000|0.0000|0.2198|0.6001|0.0250|0.5200|2.1000|0.3000|down|0.5500|2026-05-21 16:14:00|0.575000017881394|2026-05-22 18:31:00
7640.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07640000|0.0500|132.0000|0.1500|134.0000|0.2357|13675.0000|13648.0000|0.0051|0.0002|-0.1000|0.0000|0.0453|0.1000|-0.1250|0.0500|0.2500|0.0500|no_change|0.1000|2026-05-21 16:09:00|0.150000002235174|2026-05-22 18:31:00
7000.0000|P|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529P07000000|1.4500|12.0000|1.5500|28.0000|0.2201|12942.0000|1202.0000|-0.0179|0.0002|-0.6006|-0.0216|0.5060|1.4764|-1.7200|3.5900|3.9000|1.6000|no_change|1.7500|2026-05-21 16:13:00|1.82499998807907|2026-05-22 18:31:00
7575.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07575000|0.2500|141.0000|0.3500|88.0000|0.1768|12562.0000|11684.0000|0.0175|0.0009|-0.3000|0.0000|0.1327|0.3000|-0.0500|0.3200|1.3000|0.2000|down|0.3400|2026-05-21 16:14:00|0.399999991059303|2026-05-22 18:31:00
7200.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07200000|0.1000|8.0000|0.1500|56.0000|0.3833|12412.0000|7853.0000|-0.0040|0.0001|-0.1250|0.0000|0.0346|0.1250|-0.2750|1.5500|1.8100|0.1500|no_change|0.3500|2026-05-21 16:13:00|0.375|2026-05-22 18:31:00
5300.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P05300000|0.0000|0.0000|0.0500|442.0000|2.6378|12402.0000|2.0000|-0.0002|0.0000|-0.0250|0.0000|0.0015|0.0250|0.0050|0.0500|0.0500|0.0300|down|0.0300|2026-05-21 11:31:00|0.025000000372529|2026-05-22 18:31:00
7100.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07100000|0.0500|20.0000|0.1000|59.0000|0.4870|12187.0000|3649.0000|-0.0020|0.0000|-0.0750|0.0000|0.0185|0.0750|-0.1800|0.5400|0.5700|0.0500|up|0.2000|2026-05-21 16:10:00|0.250000007450581|2026-05-22 18:31:00
5650.0000|P|2026-06-05|20260605|SPXW.US|2026-05-21|SPXW260605P05650000|0.1500|208.0000|0.3500|130.0000|0.4750|12157.0000|13.0000|-0.0013|0.0000|-0.0871|-0.0034|0.0660|0.2447|-0.0800|0.3200|0.3200|0.3200|down|0.3200|2026-05-21 14:04:00|0.299999997019768|2026-05-22 18:31:00
6250.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P06250000|0.0000|0.0000|0.0500|243.0000|1.4234|11962.0000|0.0000|-0.0003|0.0000|-0.0250|0.0000|0.0027|0.0250|0.0000|0.0000|0.0000|0.0000|down|0.0500|2026-05-20 15:53:00|0.025000000372529|2026-05-22 18:31:00
6000.0000|C|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529C06000000|1466.5000|1.0000|1485.2000|2.0000|0.5395|11708.0000|0.0000|0.9991|0.0000|-0.0856|0.9839|0.0371|1475.6700|0.0000|0.0000|0.0000|0.0000|no_change|1455.4000|2026-05-13 13:28:00|1447.85003662109|2026-05-22 18:31:00
7200.0000|P|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529P07200000|5.0000|37.0000|5.3000|36.0000|0.1741|11522.0000|1771.0000|-0.0648|0.0007|-1.4864|-0.0791|1.4231|5.1994|-1.5600|13.4000|14.6300|6.0200|no_change|6.5000|2026-05-21 16:12:00|6.70000004768372|2026-05-22 18:31:00
5700.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P05700000|0.0000|0.0000|0.0500|304.0000|2.1060|11442.0000|0.0000|-0.0002|0.0000|-0.0250|0.0000|0.0019|0.0250|0.0000|0.0000|0.0000|0.0000|no_change|0.0500|2026-05-19 15:52:00|0.025000000372529|2026-05-22 18:31:00
7200.0000|C|2026-05-29|20260529|SPXW.US|2026-05-21|SPXW260529C07200000|271.7000|1.0000|291.3000|3.0000|0.1740|10897.0000|75.0000|0.9352|0.0007|-1.4864|1.1029|1.4231|281.5105|2.7000|218.9000|276.3600|213.8000|down|252.0500|2026-05-21 15:54:00|255.900001525879|2026-05-22 18:31:00
7500.0000|C|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522C07500000|9.2000|17.0000|9.4000|29.0000|0.1816|10889.0000|27634.0000|0.2910|0.0069|-9.0510|0.0000|0.9464|9.0510|3.9500|3.7000|13.4200|1.6500|up|6.2000|2026-05-21 16:14:00|4.95000004768372|2026-05-22 18:31:00
6150.0000|P|2026-05-28|20260528|SPXW.US|2026-05-21|SPXW260528P06150000|0.0500|56.0000|0.1500|89.0000|0.4697|10079.0000|0.0000|-0.0009|0.0000|-0.0746|-0.0005|0.0324|0.1116|0.0000|0.0000|0.0000|0.0000|no_change|0.2000|2026-05-20 14:58:00|0.150000002235174|2026-05-22 18:31:00
6225.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P06225000|0.0000|0.0000|0.0500|245.0000|1.4534|10029.0000|5.0000|-0.0003|0.0000|-0.0250|0.0000|0.0027|0.0250|0.0000|0.0500|0.0500|0.0500|no_change|0.0500|2026-05-21 15:26:00|0.025000000372529|2026-05-22 18:31:00
7450.0000|C|2026-06-30|20260630|SPXW.US|2026-05-21|SPXW260630C07450000|164.3000|7.0000|165.3000|7.0000|0.1441|9942.0000|183.0000|0.5595|0.0011|-1.7811|3.9583|9.6953|164.2417|0.4100|130.5600|157.7700|129.1800|down|149.1100|2026-05-21 15:37:00|146.650001525879|2026-05-22 18:31:00
7175.0000|P|2026-05-22|20260522|SPXW.US|2026-05-21|SPXW260522P07175000|0.0500|155.0000|0.1000|1.0000|0.3951|9934.0000|9677.0000|-0.0024|0.0001|-0.0750|0.0000|0.0223|0.0750|-0.2250|1.1500|1.1500|0.1500|no_change|0.2500|2026-05-21 16:12:00|0.325000002980232|2026-05-22 18:31:00
