# Quantitative Trading Analysis: AMZN

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided AMZN market data to forecast price action over the next 5 trading days. Tomorrow's expected behavior is used for entry timing and immediate risk; the next 2 trading days are used as early confirmation. The signal strength classification must be based primarily on the selective next-5-trading-day edge.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

---

## Research Validation Summary

This prompt was generated for `AMZN.US` with requested as-of date `2026-05-22`. The latest feature row available was `2026-05-21`. Candidate rules and the feature-score gate were selected primarily on `Next5DaysChange`, with `TomorrowChange` retained for timing and `Next2DaysChange` retained for early confirmation.

- Daily feature rows: 822 total, 817 primary-target labeled rows from 2023-01-04 to 2026-05-14.
- Train split: 2023-01-04 to 2025-05-07, 571 rows.
- Validation split: 2025-05-08 to 2025-11-05, 123 rows.
- Test split: 2025-11-06 to 2026-05-14, 123 rows.
- Baseline 5-day win rate: train 59.0%, validation 59.3%, test 56.1%.
- Baseline tomorrow win rate: train 52.6%, validation 56.1%, test 54.0%.
- Baseline 2-day win rate: train 54.2%, validation 52.8%, test 54.5%.
- Selective feature-score gate: threshold 0.69 on the trained probability score.
- Feature-score train performance: win 86.7%, coverage 181/571 (31.7%), avg selected 5-day return +3.169%.
- Feature-score validation performance: win 60.0%, coverage 60/123 (48.8%), avg selected 5-day return +0.606%.
- Feature-score test performance: win 52.1%, coverage 71/123 (57.7%), avg selected 5-day return +0.091%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 92. Positive call OI change 53286; positive put OI change 39509; near-term call additions 25098; near-term put additions 14043.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 128.

Latest feature context for `2026-05-21`: close 268.4600, VIX 16.7600, RSI 52.72830926652771941037074714326, GEX 911868.0, GEXChange 40.54, GEX_ZScore 1.078048214053721, dark-pool ratio 0.57.

### Accepted Patterns

- `Is_Potential_Swing_Down = 1` (5-day): train n=20, avg +1.054%, win 55.0%; validation n=24, avg +0.844%, win 58.3%; test n=23, avg +1.423%, win 73.9%; test tomorrow avg -0.131%, test 2-day avg +0.409%.
- `RSI < 30` (5-day): train n=48, avg +0.581%, win 56.2%; validation n=5, avg +1.282%, win 40.0%; test n=14, avg +2.068%, win 78.6%; test tomorrow avg +0.485%, test 2-day avg +0.844%.
- `Golden_Setup = 1` (5-day): train n=23, avg +4.096%, win 73.9%; validation n=2, avg +4.325%, win 100.0%; test n=9, avg +2.970%, win 88.9%; test tomorrow avg +1.294%, test 2-day avg +1.823%.
- `BB_PercentB > 0.8` (5-day): train n=171, avg +0.091%, win 52.0%; validation n=18, avg +0.446%, win 50.0%; test n=25, avg +0.928%, win 64.0%; test tomorrow avg +0.534%, test 2-day avg +0.753%.
- `BB_PercentB < 0.2` (5-day): train n=41, avg +3.002%, win 75.6%; validation n=11, avg +1.511%, win 72.7%; test n=14, avg +0.231%, win 57.1%; test tomorrow avg -0.117%, test 2-day avg -0.134%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 71/123 (57.7%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, avoid directional trading levels, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `SVix_DarkPoolIndex`: model weight -0.7662
- `BB_PercentB`: model weight -0.7229
- `Price_Above_SMA50`: model weight +0.5309
- `GEX_ZScore`: model weight -0.4512
- `SMA20_Above_SMA50`: model weight -0.4511
- `RSI`: model weight -0.4476
- `SVix_DarkPoolBuyRatio`: model weight +0.4083
- `VIX`: model weight +0.3983
- `GEX_Percentile`: model weight +0.3773
- `TodayChange`: model weight +0.3764
- `BB_Bandwidth`: model weight -0.3465
- `GEXChange`: model weight +0.3362

### Rejected Or Downgraded Patterns

- `Price above SMA20 and SMA50` (5-day): train n=321, avg +0.793%, win 60.4%; validation n=46, avg -0.166%, win 52.2%; test n=54, avg -0.413%, win 51.9%; test tomorrow avg +0.202%, test 2-day avg +0.204%.
- `MACD positive AND Price above SMA20/SMA50` (5-day): train n=273, avg +0.581%, win 59.7%; validation n=36, avg -0.393%, win 55.6%; test n=47, avg -0.985%, win 48.9%; test tomorrow avg +0.082%, test 2-day avg +0.079%.
- `RSI > 70` (5-day): train n=78, avg +0.224%, win 53.8%; validation n=17, avg -0.679%, win 41.2%; test n=29, avg +0.040%, win 58.6%; test tomorrow avg +0.292%, test 2-day avg +0.529%.
- `GEX positive AND GEXChange positive` (5-day): train n=70, avg -0.277%, win 45.7%; validation n=71, avg +0.575%, win 57.7%; test n=63, avg +0.795%, win 57.1%; test tomorrow avg +0.363%, test 2-day avg +0.401%.
- `GEX positive AND low VIX (<18)` (5-day): train n=63, avg -0.087%, win 46.0%; validation n=89, avg +0.355%, win 58.4%; test n=57, avg -0.631%, win 47.4%; test tomorrow avg -0.088%, test 2-day avg -0.266%.
- `Is_Potential_Swing_Up = 1` (5-day): train n=29, avg -1.374%, win 34.5%; validation n=25, avg +0.893%, win 68.0%; test n=21, avg +0.353%, win 57.1%; test tomorrow avg +0.337%, test 2-day avg +0.567%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 5-day feature-score gate first, then use accepted 5-day rules, option flow, and 30-minute tape as confirmation or contradiction.

#### Is_Potential_Swing_Down = 1
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `Is_Potential_Swing_Down = 1` (5-day): train n=20, avg +1.054%, win 55.0%; validation n=24, avg +0.844%, win 58.3%; test n=23, avg +1.423%, win 73.9%; test tomorrow avg -0.131%, test 2-day avg +0.409%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for AMZN. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### RSI < 30
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `RSI < 30` (5-day): train n=48, avg +0.581%, win 56.2%; validation n=5, avg +1.282%, win 40.0%; test n=14, avg +2.068%, win 78.6%; test tomorrow avg +0.485%, test 2-day avg +0.844%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for AMZN. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### Golden_Setup = 1
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `Golden_Setup = 1` (5-day): train n=23, avg +4.096%, win 73.9%; validation n=2, avg +4.325%, win 100.0%; test n=9, avg +2.970%, win 88.9%; test tomorrow avg +1.294%, test 2-day avg +1.823%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for AMZN. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.

#### BB_PercentB > 0.8
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `BB_PercentB > 0.8` (5-day): train n=171, avg +0.091%, win 52.0%; validation n=18, avg +0.446%, win 50.0%; test n=25, avg +0.928%, win 64.0%; test tomorrow avg +0.534%, test 2-day avg +0.753%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for AMZN. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
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
2. Ignore all future-return columns in the live row.
3. Identify active accepted patterns, rejected-pattern warnings, and context rules.
4. Decide the confidence-gate status: `HIGH_CONFIDENCE`, `LOW_CONFIDENCE`, or `NO_HIGH_CONFIDENCE_EDGE`.
5. Review latest option trades, OI changes, top OI walls, and 30-minute bars.
6. Resolve conflicts in this order: selective 5-day feature-score gate, accepted Tier 1 5-day rules, near-term option walls close to spot, accepted Tier 2 rules, 30-minute tape, context rules.
7. Produce a 5-day forecast only if the confidence gate is active; otherwise state that there is no high-confidence edge.

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
- **Historical Test Coverage:** 71/123 (57.7%)
- **Historical Test Win Rate When Covered:** 52.1%
- **Why Covered Or Not Covered Today:** concise explanation using the latest row, accepted patterns, option flow, OI walls, and 30-minute tape.

### Active Signal Checklist

List active and inactive accepted Tier 1/Tier 2 5-day signals from the latest row.

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
