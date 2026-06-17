# Quantitative Trading Analysis: QQQ

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided QQQ market data to forecast price action over the next 5 trading days. Tomorrow's expected behavior is used for entry timing and immediate risk; the next 2 trading days are used as early confirmation. The signal strength classification must be based primarily on the selective next-5-trading-day edge.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

**Runtime Source Of Truth:** For the live forecast, the only current market state is the latest row in the `Data (Last 30 Days)` section, identified by the greatest `ObservationDate`. Research validation metadata is training context only. Never use generated-at dates, research-summary rows, or any other non-data-section context to decide today's active signals.

---

## Research Validation Summary

This prompt was generated for `QQQ.US` with requested as-of date `2026-05-22`. Candidate rules and the feature-score gate were selected primarily on `Next5DaysChange`, with `TomorrowChange` retained for timing and `Next2DaysChange` retained for early confirmation. This section is research metadata only; do not use it as today's market state during live or historical replay analysis.

- Daily feature rows: 850 total, 845 primary-target labeled rows from 2022-12-09 to 2026-05-14.
- Train split: 2022-12-09 to 2025-05-05, 591 rows.
- Validation split: 2025-05-06 to 2025-11-05, 127 rows.
- Test split: 2025-11-06 to 2026-05-14, 127 rows.
- Baseline 5-day win rate: train 59.9%, validation 70.9%, test 55.1%.
- Baseline tomorrow win rate: train 56.1%, validation 61.4%, test 54.7%.
- Baseline 2-day win rate: train 56.7%, validation 64.6%, test 55.5%.
- Selective feature-score gate: threshold 0.50 on the trained probability score.
- Feature-score train performance: win 71.1%, coverage 426/591 (72.1%), avg selected 5-day return +1.099%.
- Feature-score validation performance: win 75.0%, coverage 64/127 (50.4%), avg selected 5-day return +1.202%.
- Feature-score test performance: win 61.8%, coverage 76/127 (59.8%), avg selected 5-day return +0.617%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 100. Positive call OI change 61736; positive put OI change 184807; near-term call additions 38335; near-term put additions 88496.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 128.

### Accepted Patterns

- `BB_PercentB > 0.8` (5-day): train n=198, avg +0.315%, win 57.6%; validation n=66, avg +0.251%, win 56.1%; test n=27, avg +1.469%, win 66.7%; test tomorrow avg +0.369%, test 2-day avg +0.624%.
- `RSI > 70` (5-day): train n=124, avg +0.204%, win 55.6%; validation n=53, avg +0.766%, win 66.0%; test n=25, avg +1.360%, win 72.0%; test tomorrow avg +0.287%, test 2-day avg +0.559%.
- `DarkPool ratio > 2.0` (5-day): train n=88, avg +0.498%, win 61.4%; validation n=20, avg +0.501%, win 60.0%; test n=19, avg +1.690%, win 68.4%; test tomorrow avg +0.273%, test 2-day avg +0.686%.
- `DarkPool ratio > 1.5` (5-day): train n=229, avg +0.593%, win 61.6%; validation n=70, avg +0.640%, win 67.1%; test n=69, avg +1.028%, win 60.9%; test tomorrow avg +0.134%, test 2-day avg +0.352%.
- `Golden_Setup = 1` (5-day): train n=37, avg +1.750%, win 70.3%; validation n=0, avg n/a, win n/a; test n=10, avg +2.340%, win 80.0%; test tomorrow avg +0.465%, test 2-day avg +0.662%.
- `Is_Swing_Down = 1` (5-day): train n=50, avg +0.409%, win 60.0%; validation n=20, avg +0.218%, win 60.0%; test n=21, avg +1.084%, win 57.1%; test tomorrow avg +0.002%, test 2-day avg +0.391%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 76/127 (59.8%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, avoid directional trading levels, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `SVix_DarkPoolIndex`: model weight -0.6275
- `GEX_ZScore`: model weight -0.6080
- `MACD_Line`: model weight -0.5724
- `GEX_ZScore_60day`: model weight +0.4943
- `GEX_Percentile`: model weight +0.4726
- `SVix_DarkPoolBuyRatio`: model weight +0.4180
- `Price_Above_SMA20`: model weight +0.3775
- `RSI`: model weight -0.3018
- `BuyCall_GEXDeltaPerc`: model weight -0.2968
- `GEX_Percentile_Low`: model weight -0.2929
- `GEX_StableRegime`: model weight -0.2678
- `Stock_DarkPoolIndex`: model weight +0.2533

### Rejected Or Downgraded Patterns

- `MACD positive AND Price above SMA20/SMA50` (5-day): train n=326, avg +0.331%, win 58.9%; validation n=115, avg +0.829%, win 67.8%; test n=47, avg +0.011%, win 53.2%; test tomorrow avg -0.024%, test 2-day avg +0.010%.
- `GEX positive AND low VIX (<18)` (5-day): train n=192, avg +0.191%, win 59.9%; validation n=63, avg +0.271%, win 60.3%; test n=42, avg -0.366%, win 47.6%; test tomorrow avg +0.017%, test 2-day avg -0.085%.
- `Is_Potential_Swing_Down = 1` (5-day): train n=87, avg +0.263%, win 58.6%; validation n=37, avg +0.798%, win 67.6%; test n=30, avg +0.605%, win 50.0%; test tomorrow avg -0.005%, test 2-day avg +0.248%.
- `Is_Potential_Swing_Up = 1` (5-day): train n=55, avg +0.669%, win 61.8%; validation n=17, avg +1.286%, win 76.5%; test n=17, avg -0.176%, win 35.3%; test tomorrow avg -0.333%, test 2-day avg -0.161%.
- `Negative_GEX_AND_High_VIX = 1` (5-day): train n=52, avg +1.286%, win 63.5%; validation n=10, avg +2.202%, win 100.0%; test n=37, avg +0.525%, win 48.6%; test tomorrow avg +0.084%, test 2-day avg +0.209%.
- `GEX < 0 AND VIX > 20` (5-day): train n=52, avg +1.286%, win 63.5%; validation n=10, avg +2.202%, win 100.0%; test n=37, avg +0.525%, win 48.6%; test tomorrow avg +0.084%, test 2-day avg +0.209%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 5-day feature-score gate first, then use accepted 5-day rules, option flow, and 30-minute tape as confirmation or contradiction.

#### BB_PercentB > 0.8
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `BB_PercentB > 0.8` (5-day): train n=198, avg +0.315%, win 57.6%; validation n=66, avg +0.251%, win 56.1%; test n=27, avg +1.469%, win 66.7%; test tomorrow avg +0.369%, test 2-day avg +0.624%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for QQQ. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### RSI > 70
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `RSI > 70` (5-day): train n=124, avg +0.204%, win 55.6%; validation n=53, avg +0.766%, win 66.0%; test n=25, avg +1.360%, win 72.0%; test tomorrow avg +0.287%, test 2-day avg +0.559%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for QQQ. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### DarkPool ratio > 2.0
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `DarkPool ratio > 2.0` (5-day): train n=88, avg +0.498%, win 61.4%; validation n=20, avg +0.501%, win 60.0%; test n=19, avg +1.690%, win 68.4%; test tomorrow avg +0.273%, test 2-day avg +0.686%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for QQQ. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.

#### DarkPool ratio > 1.5
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `DarkPool ratio > 1.5` (5-day): train n=229, avg +0.593%, win 61.6%; validation n=70, avg +0.640%, win 67.1%; test n=69, avg +1.028%, win 60.9%; test tomorrow avg +0.134%, test 2-day avg +0.352%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for QQQ. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.


### Context Rules

#### RSI And Trend State
- **Signal:** Context only unless accepted above as a validated rule.
- **Rationale:** Overbought or oversold signals can behave differently by regime. Do not short only because RSI is high; do not buy only because RSI is low unless validated triggers and option structure agree.

#### Option Flow Confirmation
- **Signal:** Confirms, downgrades, or invalidates daily-feature rules.
- **Rationale:** Large near-term OI changes and top OI walls reveal dealer hedging zones and resistance/support levels.
- **Priority:** Near-term 0-7 DTE walls are highest priority, followed by 8-14 DTE, 15-30 DTE, then 30-90 DTE.

---

## Live Analysis Procedure

1. Read the latest row in the Last 30 Days data section by greatest `ObservationDate`.
2. Begin by creating a Latest Row Audit using only that row. Echo `ObservationDate`, `Close`, `GEX`, `GEX_ZScore`, `VIX`, `RSI`, `Is_Swing_Up`, `Is_Swing_Down`, `PotentialSwingIndicator`, `SwingIndicator`, `GEX_Turned_Positive`, and `GEX_Turned_Negative`.
3. Ignore all future-return columns in the live row.
4. Identify active accepted patterns, rejected-pattern warnings, and context rules from the audited latest row only.
5. If the latest row has `Is_Swing_Up = 0`, you must mark `Is_Swing_Up` inactive. If the latest row has `Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", you must not claim a swing-up/potential-swing-up pattern is active.
6. Decide the confidence-gate status: `HIGH_CONFIDENCE`, `LOW_CONFIDENCE`, or `NO_HIGH_CONFIDENCE_EDGE`.
7. Review latest option trades, OI changes, top OI walls, and 30-minute bars.
8. Resolve conflicts in this order: audited latest row, selective 5-day feature-score gate, accepted Tier 1 5-day rules, near-term option walls close to spot, accepted Tier 2 rules, 30-minute tape, context rules.
9. Produce a 5-day forecast only if the confidence gate is active; otherwise state that there is no high-confidence edge.

---

## Option Flow Interpretation

### Latest Option Trades

Analyze the latest option trades section for call versus put size/premium, strike clustering, late-day concentration, and near-spot urgency.

### Option OI Changes

Analyze the option OI changes section as newly built positioning. If fresh put OI additions dominate fresh call OI additions by more than 2:1, treat the tape as defensive unless daily features show a clear reversal setup.

### Top Options By Current Open Interest

Identify the primary put wall and primary call wall. Anchor buy-dip and sell-rip levels to specific strikes when available.

### 30-Minute Price Bars

Use VWAP clusters, repeated highs/lows, and late-session behavior as timing confirmation.

---

## Output Format

### Executive Forecast

Provide one decisive paragraph with the confidence-gate status first. If status is `NO_HIGH_CONFIDENCE_EDGE`, say plainly that the model does not have enough validated edge today and do not force a bullish or bearish call. If status is `HIGH_CONFIDENCE` or `LOW_CONFIDENCE`, provide the expected next-5-trading-day direction, expected magnitude, volatility expectation, tomorrow timing risk, and main reason.

### Confidence Gate

Report:

- **Status:** `HIGH_CONFIDENCE`, `LOW_CONFIDENCE`, or `NO_HIGH_CONFIDENCE_EDGE`
- **Historical Test Coverage:** 76/127 (59.8%)
- **Historical Test Win Rate When Covered:** 61.8%
- **Why Covered Or Not Covered Today:** concise explanation using the latest row, accepted patterns, option flow, OI walls, and 30-minute tape.

### Latest Row Audit

Report the exact latest-row values used for the forecast. This section must be internally consistent with the `Data (Last 30 Days)` row with the greatest `ObservationDate`. If the latest row shows `Is_Swing_Down = 1` or `PotentialSwingIndicator = "Potential swing down"`, say so plainly and do not describe swing-up patterns as active.

### Active Signal Checklist

List active and inactive accepted Tier 1/Tier 2 5-day signals from the audited latest row. Do not infer active signals from the research summary or from older rows.

### Market Structure Analysis

Discuss GEX regime, VIX, RSI/momentum, dark-pool ratio, and price relative to SMA20/SMA50.

### Option Flow And Gamma Walls

Discuss latest option trades, fresh OI changes, primary put wall, primary call wall, and whether option flow confirms or contradicts the daily-feature signal.

### 30-Minute Tape

Discuss VWAP, intraday support/resistance, and whether the last sessions confirm the forecast.

### Trading Levels

Provide:

- **Buy the Dip Range:** price range or "Not Recommended", with strike/OI support if available. The range must be strictly below the latest current price/close; a put wall above current price is overhead/reclaim context, not dip support.
- **Sell the Rip Range:** price range or "Not Recommended", with strike/OI resistance if available. The range must be strictly above the latest current price/close; a call wall below current price is lower/past resistance, not a rip entry.
- **Invalidation:** price or condition that would invalidate the forecast.

Before finalizing trading levels, run a price-geometry sanity check against the latest current price/close. If Buy the Dip is not below current price, change it to "Not Recommended". If Sell the Rip is not above current price, change it to "Not Recommended". Percentages must match the direction: buy-dip distances are negative and sell-rip distances are positive.

### Signal Strength JSON

Place this JSON at the very end of the markdown response. The classification must represent the expected directional edge over the next 5 trading days, not just tomorrow:

If `Confidence Gate` status is `NO_HIGH_CONFIDENCE_EDGE`, the JSON must be:

```json
{
  "signal_strength": "Not Determined"
}
```

Otherwise use:

```json
{
  "signal_strength": "STRONGLY_BULLISH" | "MILDLY_BULLISH" | "NEUTRAL" | "MILDLY_BEARISH" | "STRONGLY_BEARISH" | "Not Determined"
}
```

---

## Data (Last 30 Days)

{{ recent_data }}

## Latest Option Trades (Size > 300)

{{ option_trades }}

## 30-Minute Price Bars (Last 5 Days)

{{ price_bars_30m }}

## Part 1: Option OI Changes (Yesterday vs Today)

{{ option_oi_changes }}

## Part 2: Top 50 Options By Current Open Interest

{{ top_options_oi }}
