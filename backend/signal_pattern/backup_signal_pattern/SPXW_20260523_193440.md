# Quantitative Trading Analysis: SPXW

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided SPXW market data to forecast price action over the next 5 trading days. Tomorrow's expected behavior is used for entry timing and immediate risk; the next 2 trading days are used as early confirmation. The signal strength classification must be based primarily on the selective next-5-trading-day edge.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

**Runtime Source Of Truth:** For the live forecast, the only current market state is the latest row in the `Data (Last 30 Days)` section, identified by the greatest `ObservationDate`. Research validation metadata is training context only. Never use generated-at dates, research-summary rows, or any other non-data-section context to decide today's active signals.

**Hard Audit Rule:** The latest-row audit is mandatory and must be completed before the forecast. Any forecast that claims a signal is active when the audited latest row shows the opposite is invalid. In particular, if `Is_Swing_Up = 0`, `Is_Swing_Up` is inactive; if `Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", the setup must be described as swing-down/potential-swing-down, not swing-up.

---

## Research Validation Summary

This prompt was generated for `SPXW.US` with requested as-of date `2026-05-22`. Candidate rules and the feature-score gate were selected primarily on `Next5DaysChange`, with `TomorrowChange` retained for timing and `Next2DaysChange` retained for early confirmation. This section is research metadata only; do not use it as today's market state during live or historical replay analysis.

- Daily feature rows: 848 total, 843 primary-target labeled rows from 2022-12-09 to 2026-05-14.
- Train split: 2022-12-09 to 2025-05-07, 590 rows.
- Validation split: 2025-05-08 to 2025-11-05, 126 rows.
- Test split: 2025-11-06 to 2026-05-14, 127 rows.
- Baseline 5-day win rate: train 60.3%, validation 70.6%, test 56.7%.
- Baseline tomorrow win rate: train 54.9%, validation 59.1%, test 53.1%.
- Baseline 2-day win rate: train 57.8%, validation 63.8%, test 53.5%.
- Selective feature-score gate: threshold 0.53 on the trained probability score.
- Feature-score train performance: win 73.7%, coverage 388/590 (65.8%), avg selected 5-day return +0.850%.
- Feature-score validation performance: win 70.8%, coverage 65/126 (51.6%), avg selected 5-day return +0.609%.
- Feature-score test performance: win 67.7%, coverage 62/127 (48.8%), avg selected 5-day return +0.816%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 100. Positive call OI change 123742; positive put OI change 141612; near-term call additions 111030; near-term put additions 116160.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 52.
- Broad feature audit rules tested: 302 single-feature rules and 2012 two-feature combinations.

### Accepted Patterns

- `BB_Bandwidth >= train_q60 (0.0599) AND GEXChange <= train_q20 (-113.1)` (5-day): train n=23, avg +1.555%, win 78.3%; validation n=5, avg +1.034%, win 80.0%; test n=7, avg +2.694%, win 100.0%; test tomorrow avg +0.280%, test 2-day avg +0.534%.
- `BB_Bandwidth >= train_q50 (0.0537) AND GEXChange <= train_q20 (-113.1)` (5-day): train n=31, avg +1.328%, win 74.2%; validation n=6, avg +0.813%, win 66.7%; test n=12, avg +2.487%, win 100.0%; test tomorrow avg +0.361%, test 2-day avg +0.812%.
- `BB_Bandwidth >= train_q70 (0.06827) AND BuyCall_GEXDeltaPerc <= train_q40 (43.47)` (5-day): train n=56, avg +0.929%, win 67.9%; validation n=10, avg +1.332%, win 100.0%; test n=9, avg +2.187%, win 88.9%; test tomorrow avg +0.298%, test 2-day avg +0.807%.
- `BB_Bandwidth >= train_q70 (0.06827) AND BuyPut_GEXDeltaPerc >= train_q60 (50.57)` (5-day): train n=56, avg +0.665%, win 64.3%; validation n=13, avg +1.338%, win 92.3%; test n=9, avg +2.187%, win 88.9%; test tomorrow avg +0.298%, test 2-day avg +0.807%.
- `BB_Bandwidth >= train_q60 (0.0599) AND BuyCall_GEXDeltaPerc <= train_q40 (43.47)` (5-day): train n=83, avg +1.044%, win 74.7%; validation n=13, avg +1.160%, win 92.3%; test n=10, avg +1.978%, win 90.0%; test tomorrow avg +0.252%, test 2-day avg +0.686%.
- `BB_Bandwidth >= train_q50 (0.0537) AND BuyCall_GEXDeltaPerc <= train_q40 (43.47)` (5-day): train n=104, avg +0.880%, win 71.2%; validation n=13, avg +1.160%, win 92.3%; test n=14, avg +1.976%, win 85.7%; test tomorrow avg +0.305%, test 2-day avg +0.703%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 62/127 (48.8%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, avoid directional trading levels, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `GEX_Percentile`: model weight +0.6581
- `SVix_DarkPoolIndex`: model weight -0.5732
- `Price_Above_SMA20`: model weight +0.5223
- `GEX_Falling`: model weight +0.3984
- `Is_Potential_Swing_Down`: model weight -0.3757
- `BuyCall_GEXDeltaPerc`: model weight -0.3586
- `MACD_Line`: model weight -0.3521
- `GEX_Rising`: model weight -0.3284
- `TodayChange`: model weight -0.3083
- `Is_Potential_Swing_Up`: model weight -0.2876
- `Pot_Swing_Up_AND_Neg_GEXChange`: model weight +0.2721
- `GEX_BigRise`: model weight +0.2378

### Rejected Or Downgraded Patterns

- `VIX >= train_q60 (17.42) AND BB_Bandwidth <= train_q10 (0.03426)` (5-day): train n=21, avg +1.375%, win 76.2%; validation n=11, avg +1.685%, win 100.0%; test n=26, avg -0.505%, win 34.6%; test tomorrow avg -0.078%, test 2-day avg -0.219%.
- `Negative_GEX_AND_High_VIX = 1 AND GEX_Trending_Up = 0` (5-day): train n=41, avg +1.113%, win 68.3%; validation n=8, avg +1.834%, win 100.0%; test n=29, avg -0.043%, win 41.4%; test tomorrow avg +0.077%, test 2-day avg +0.095%.
- `Prev10DaysChange <= train_q10 (-3.23)` (5-day): train n=60, avg +1.004%, win 65.0%; validation n=0, avg n/a, win n/a; test n=9, avg -0.424%, win 22.2%; test tomorrow avg +0.329%, test 2-day avg +0.067%.
- `Prev2DaysChange <= train_q10 (-1.49)` (5-day): train n=60, avg +0.856%, win 56.7%; validation n=4, avg +1.345%, win 100.0%; test n=14, avg -0.050%, win 50.0%; test tomorrow avg +0.274%, test 2-day avg +0.297%.
- `BB_Bandwidth <= train_q10 (0.03426) AND TodayChange <= train_q40 (-0.09)` (5-day): train n=21, avg +0.801%, win 66.7%; validation n=11, avg +1.053%, win 81.8%; test n=20, avg -0.151%, win 55.0%; test tomorrow avg +0.107%, test 2-day avg +0.013%.
- `BB_Bandwidth <= train_q10 (0.03426) AND VIX >= train_q50 (16.23)` (5-day): train n=35, avg +0.765%, win 62.9%; validation n=22, avg +1.119%, win 86.4%; test n=32, avg -0.570%, win 31.2%; test tomorrow avg -0.101%, test 2-day avg -0.231%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 5-day feature-score gate first, then use accepted 5-day rules, option flow, and 30-minute tape as confirmation or contradiction.

Accepted patterns are conditional rules, not automatically active. A rule is active only when the audited latest row satisfies that exact condition. Do not infer activity from the research-summary list, from older rows, or from option-flow tone.

#### BB_Bandwidth >= train_q60 (0.0599) AND GEXChange <= train_q20 (-113.1)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `BB_Bandwidth >= train_q60 (0.0599) AND GEXChange <= train_q20 (-113.1)` (5-day): train n=23, avg +1.555%, win 78.3%; validation n=5, avg +1.034%, win 80.0%; test n=7, avg +2.694%, win 100.0%; test tomorrow avg +0.280%, test 2-day avg +0.534%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for SPXW. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### BB_Bandwidth >= train_q50 (0.0537) AND GEXChange <= train_q20 (-113.1)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `BB_Bandwidth >= train_q50 (0.0537) AND GEXChange <= train_q20 (-113.1)` (5-day): train n=31, avg +1.328%, win 74.2%; validation n=6, avg +0.813%, win 66.7%; test n=12, avg +2.487%, win 100.0%; test tomorrow avg +0.361%, test 2-day avg +0.812%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for SPXW. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### BB_Bandwidth >= train_q70 (0.06827) AND BuyCall_GEXDeltaPerc <= train_q40 (43.47)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `BB_Bandwidth >= train_q70 (0.06827) AND BuyCall_GEXDeltaPerc <= train_q40 (43.47)` (5-day): train n=56, avg +0.929%, win 67.9%; validation n=10, avg +1.332%, win 100.0%; test n=9, avg +2.187%, win 88.9%; test tomorrow avg +0.298%, test 2-day avg +0.807%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for SPXW. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.

#### BB_Bandwidth >= train_q70 (0.06827) AND BuyPut_GEXDeltaPerc >= train_q60 (50.57)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `BB_Bandwidth >= train_q70 (0.06827) AND BuyPut_GEXDeltaPerc >= train_q60 (50.57)` (5-day): train n=56, avg +0.665%, win 64.3%; validation n=13, avg +1.338%, win 92.3%; test n=9, avg +2.187%, win 88.9%; test tomorrow avg +0.298%, test 2-day avg +0.807%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for SPXW. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.


### Context Rules

#### RSI And Trend State
- **Signal:** Context only unless accepted above as a validated rule.
- **Rationale:** Overbought or oversold signals can behave differently by regime. Do not short only because RSI is high; do not buy only because RSI is low unless validated triggers and option structure agree.

#### Option Flow Confirmation
- **Signal:** Confirms, downgrades, or invalidates daily-feature rules.
- **Rationale:** Large near-term OI changes and top OI walls reveal dealer hedging zones and resistance/support levels.
- **Priority:** Near-term 0-7 DTE walls are highest priority, followed by 8-14 DTE, 15-30 DTE, then 30-90 DTE.

#### Non-Accepted Feature Fields
- **Signal:** Context only.
- **Rationale:** Feature fields that appear in the data but are not listed under Accepted Patterns are not validated alpha triggers for this prompt. They may explain context, but they must not justify `HIGH_CONFIDENCE` or a strong directional signal by themselves.

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

### Latest Row Audit

This must be the first output section. Report the exact latest-row values used for the forecast:

- `ObservationDate`
- `Close`
- `GEX`
- `GEX_ZScore`
- `VIX`
- `RSI`
- `Is_Swing_Up`
- `Is_Swing_Down`
- `PotentialSwingIndicator`
- `SwingIndicator`
- `Golden_Setup`
- `GEX_Turned_Positive`
- `GEX_Turned_Negative`

This section must be internally consistent with the `Data (Last 30 Days)` row with the greatest `ObservationDate`. If the latest row shows `Is_Swing_Down = 1` or `PotentialSwingIndicator = "Potential swing down"`, say so plainly and do not describe swing-up patterns as active. If `Is_Swing_Up = 0`, explicitly mark `Is_Swing_Up` inactive.

### Executive Forecast

Provide one decisive paragraph with the confidence-gate status first, based on the Latest Row Audit. If status is `NO_HIGH_CONFIDENCE_EDGE`, say plainly that the model does not have enough validated edge today and do not force a bullish or bearish call. If status is `HIGH_CONFIDENCE` or `LOW_CONFIDENCE`, provide the expected next-5-trading-day direction, expected magnitude, volatility expectation, tomorrow timing risk, and main reason.

### Confidence Gate

Report:

- **Status:** `HIGH_CONFIDENCE`, `LOW_CONFIDENCE`, or `NO_HIGH_CONFIDENCE_EDGE`
- **Historical Test Coverage:** 62/127 (48.8%)
- **Historical Test Win Rate When Covered:** 67.7%
- **Why Covered Or Not Covered Today:** concise explanation using the latest row, accepted patterns, option flow, OI walls, and 30-minute tape.

### Active Signal Checklist

List active and inactive accepted Tier 1/Tier 2 5-day signals from the audited latest row. Do not infer active signals from the research summary, from older rows, or from option flow. For each accepted signal, include the audited row value that made it active or inactive.

Mandatory examples:

- If the accepted signal is `Is_Swing_Up = 1` and the audited row has `Is_Swing_Up = 0`, write `Is_Swing_Up = 1: INACTIVE (latest row Is_Swing_Up = 0)`.
- If the audited row has `Is_Swing_Down = 1`, write `Is_Swing_Down: ACTIVE bearish/timing-risk context` even if it is not an accepted bullish rule.
- If `Golden_Setup = 1` but `Golden_Setup` is not listed under Accepted Patterns, write `Golden_Setup: CONTEXT ONLY, not a validated accepted trigger in this prompt`.

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
