# Quantitative Trading Analysis: SPXW

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided SPXW market data to forecast price action over the next 5 trading days. The 1-day, 2-day, and 5-day horizons were all researched during prompt generation; the signal strength classification must be based primarily on the selected horizon because it had the highest held-out feature-score test win rate for this ticker. Coverage is reported as a reliability caveat, not as the target-selection winner.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

**Runtime Source Of Truth:** For the live forecast, the only current market state is the latest row in the `Data (Last 30 Days)` section, identified by the greatest `ObservationDate`. Research validation metadata is training context only. Never use generated-at dates, research-summary rows, or any other non-data-section context to decide today's active signals.

**Hard Audit Rule:** The latest-row audit is mandatory and must be completed before the forecast. Any forecast that claims a signal is active when the audited latest row shows the opposite is invalid. In particular, if `Is_Swing_Up = 0`, `Is_Swing_Up` is inactive; if `Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", the setup must be described as swing-down/potential-swing-down, not swing-up.

---

## Research Validation Summary

This prompt was generated for `SPXW.US` with requested as-of date `2026-06-02` from a fresh SQL Server extraction for this ticker. Candidate rules and the feature-score gate were evaluated separately on `TomorrowChange`, `Next2DaysChange`, and `Next5DaysChange`. The selected primary target for this ticker is `Next5DaysChange` (next 5 trading days). This section is research metadata only; do not use it as today's market state during live or historical replay analysis.

The effective features below are stock-specific. They were discovered during this generation run by scanning the available ticker history, creating chronological train/validation/test splits for each candidate target, testing single-feature and two-feature rules, comparing target performance, and training the selective feature-score model. Do not copy accepted patterns, thresholds, or model weights from another stock prompt.

- Daily feature rows: 854 total, 849 selected-target labeled rows from 2022-12-09 to 2026-05-22.
- Train split: 2022-12-09 to 2025-05-13, 594 rows.
- Validation split: 2025-05-14 to 2025-11-12, 127 rows.
- Test split: 2025-11-13 to 2026-05-22, 128 rows.
- Selected target: `Next5DaysChange` (next 5 trading days).
- Target selection summary, ordered by held-out feature-score test win rate:
- 5-day: feature-score test win 73.0%, coverage 63/128 (49.2%), selection rank value 736.09, accepted robust patterns 6.
- 2-day: feature-score test win 66.1%, coverage 62/128 (48.4%), selection rank value 666.52, accepted robust patterns 6.
- 1-day: feature-score test win 59.0%, coverage 61/128 (47.7%), selection rank value 595.08, accepted robust patterns 6.
- Baseline selected-target win rate: train 60.6%, validation 68.5%, test 59.4%.
- Baseline tomorrow win rate: train 55.3%, validation 56.2%, test 56.2%.
- Baseline 2-day win rate: train 58.1%, validation 60.2%, test 57.8%.
- Baseline 5-day win rate: train 60.6%, validation 68.5%, test 59.4%.
- Selective feature-score gate: threshold 0.54 on the trained probability score.
- Feature-score train performance on selected target: win 75.1%, coverage 385/594 (64.8%), avg selected return +0.911%.
- Feature-score validation performance on selected target: win 67.7%, coverage 65/127 (51.2%), avg selected return +0.403%.
- Feature-score test performance on selected target: win 73.0%, coverage 63/128 (49.2%), avg selected return +1.010%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 100. Positive call OI change 95775; positive put OI change 148181; near-term call additions 87609; near-term put additions 113518.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 52.
- Broad feature audit rules tested: 302 single-feature rules and 2076 two-feature combinations.

### Accepted Patterns

- `GEXChange <= train_q20 (-112.9) AND BB_Bandwidth >= train_q60 (0.06004)` (5-day): train n=22, avg +1.575%, win 77.3%; validation n=5, avg +1.034%, win 80.0%; test n=9, avg +2.446%, win 100.0%; test 1-day avg +0.330%, test 2-day avg +0.472%, test 5-day avg +2.446%.
- `MACD_Line >= train_q90 (86.8) AND BuyCall_GEXDeltaPerc <= train_q40 (43.43)` (5-day): train n=26, avg +0.705%, win 69.2%; validation n=9, avg +0.834%, win 100.0%; test n=7, avg +1.820%, win 100.0%; test 1-day avg +0.400%, test 2-day avg +0.597%, test 5-day avg +1.820%.
- `GEXChange <= train_q20 (-112.9) AND BB_Bandwidth >= train_q50 (0.05383)` (5-day): train n=30, avg +1.396%, win 76.7%; validation n=6, avg +0.813%, win 66.7%; test n=14, avg +2.356%, win 100.0%; test 1-day avg +0.381%, test 2-day avg +0.732%, test 5-day avg +2.356%.
- `MACD_Line >= train_q90 (86.8) AND BuyPut_GEXDeltaPerc >= train_q60 (50.61)` (5-day): train n=27, avg +0.794%, win 63.0%; validation n=12, avg +0.603%, win 91.7%; test n=6, avg +1.745%, win 100.0%; test 1-day avg +0.287%, test 2-day avg +0.488%, test 5-day avg +1.745%.
- `Stock_DarkPoolIndex <= train_q50 (51.8) AND BuyCall_GEXDeltaPerc >= train_q80 (57.52)` (5-day): train n=35, avg +0.366%, win 57.1%; validation n=6, avg +1.503%, win 100.0%; test n=5, avg +1.338%, win 100.0%; test 1-day avg +0.482%, test 2-day avg +0.994%, test 5-day avg +1.338%.
- `Stock_DarkPoolBuySellRatio <= train_q50 (1.07) AND BuyCall_GEXDeltaPerc >= train_q80 (57.52)` (5-day): train n=35, avg +0.366%, win 57.1%; validation n=6, avg +1.503%, win 100.0%; test n=5, avg +1.338%, win 100.0%; test 1-day avg +0.482%, test 2-day avg +0.994%, test 5-day avg +1.338%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 63/128 (49.2%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, do not force a bullish or bearish forecast, still complete the mandatory Trading Levels section, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `GEX_Percentile`: model weight +0.6452
- `SVix_DarkPoolIndex`: model weight -0.6242
- `Price_Above_SMA20`: model weight +0.5069
- `GEX_Falling`: model weight +0.3962
- `Is_Potential_Swing_Down`: model weight -0.3836
- `BuyCall_GEXDeltaPerc`: model weight -0.3755
- `GEX_Rising`: model weight -0.3267
- `Is_Potential_Swing_Up`: model weight -0.2927
- `Pot_Swing_Up_AND_Neg_GEXChange`: model weight +0.2792
- `TodayChange`: model weight -0.2654
- `GEX_ZScore_60day`: model weight +0.2535
- `MACD_Line`: model weight -0.2515

### Rejected Or Downgraded Patterns

- `BB_Bandwidth <= train_q10 (0.03436) AND VIX >= train_q60 (17.48)` (5-day): train n=21, avg +1.317%, win 71.4%; validation n=11, avg +1.685%, win 100.0%; test n=25, avg -0.521%, win 36.0%; test 1-day avg -0.103%, test 2-day avg -0.215%, test 5-day avg -0.521%.
- `Negative_GEX_AND_High_VIX = 1 AND GEX_Trending_Up = 0` (5-day): train n=41, avg +1.113%, win 68.3%; validation n=8, avg +1.834%, win 100.0%; test n=29, avg -0.043%, win 41.4%; test 1-day avg +0.077%, test 2-day avg +0.095%, test 5-day avg -0.043%.
- `Prev10DaysChange <= train_q10 (-3.227)` (5-day): train n=60, avg +1.004%, win 65.0%; validation n=0, avg n/a, win n/a; test n=9, avg -0.424%, win 22.2%; test 1-day avg +0.329%, test 2-day avg +0.067%, test 5-day avg -0.424%.
- `Prev2DaysChange <= train_q10 (-1.484)` (5-day): train n=60, avg +0.856%, win 56.7%; validation n=4, avg +1.345%, win 100.0%; test n=14, avg -0.050%, win 50.0%; test 1-day avg +0.274%, test 2-day avg +0.297%, test 5-day avg -0.050%.
- `TodayChange <= train_q20 (-0.6) AND GEXChange_Positive = 1` (5-day): train n=29, avg +0.805%, win 65.5%; validation n=5, avg +0.960%, win 100.0%; test n=6, avg -0.052%, win 50.0%; test 1-day avg +0.170%, test 2-day avg +0.203%, test 5-day avg -0.052%.
- `TodayChange <= train_q20 (-0.6) AND GEXChange >= train_q60 (-3.32)` (5-day): train n=29, avg +0.805%, win 65.5%; validation n=5, avg +0.960%, win 100.0%; test n=6, avg -0.052%, win 50.0%; test 1-day avg +0.170%, test 2-day avg +0.203%, test 5-day avg -0.052%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 5-day feature-score gate first, then use accepted 5-day rules, option flow, and 30-minute tape as confirmation or contradiction.

Accepted patterns are conditional rules, not automatically active. A rule is active only when the audited latest row satisfies that exact condition. Do not infer activity from the research-summary list, from older rows, or from option-flow tone.

#### GEXChange <= train_q20 (-112.9) AND BB_Bandwidth >= train_q60 (0.06004)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `GEXChange <= train_q20 (-112.9) AND BB_Bandwidth >= train_q60 (0.06004)` (5-day): train n=22, avg +1.575%, win 77.3%; validation n=5, avg +1.034%, win 80.0%; test n=9, avg +2.446%, win 100.0%; test 1-day avg +0.330%, test 2-day avg +0.472%, test 5-day avg +2.446%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for SPXW. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### MACD_Line >= train_q90 (86.8) AND BuyCall_GEXDeltaPerc <= train_q40 (43.43)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `MACD_Line >= train_q90 (86.8) AND BuyCall_GEXDeltaPerc <= train_q40 (43.43)` (5-day): train n=26, avg +0.705%, win 69.2%; validation n=9, avg +0.834%, win 100.0%; test n=7, avg +1.820%, win 100.0%; test 1-day avg +0.400%, test 2-day avg +0.597%, test 5-day avg +1.820%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for SPXW. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### GEXChange <= train_q20 (-112.9) AND BB_Bandwidth >= train_q50 (0.05383)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `GEXChange <= train_q20 (-112.9) AND BB_Bandwidth >= train_q50 (0.05383)` (5-day): train n=30, avg +1.396%, win 76.7%; validation n=6, avg +0.813%, win 66.7%; test n=14, avg +2.356%, win 100.0%; test 1-day avg +0.381%, test 2-day avg +0.732%, test 5-day avg +2.356%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for SPXW. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.

#### MACD_Line >= train_q90 (86.8) AND BuyPut_GEXDeltaPerc >= train_q60 (50.61)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `MACD_Line >= train_q90 (86.8) AND BuyPut_GEXDeltaPerc >= train_q60 (50.61)` (5-day): train n=27, avg +0.794%, win 63.0%; validation n=12, avg +0.603%, win 91.7%; test n=6, avg +1.745%, win 100.0%; test 1-day avg +0.287%, test 2-day avg +0.488%, test 5-day avg +1.745%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for SPXW. Cross-check the other horizons for timing, confirmation, or conflict.
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

Use VWAP clusters, repeated highs/lows, late-session behavior, and high-volume nodes as timing confirmation. Treat repeated 30-minute lows/VWAP holds below spot as intraday support candidates, and repeated 30-minute highs/VWAP rejections above spot as intraday resistance candidates.

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

Provide one decisive paragraph with the confidence-gate status first, based on the Latest Row Audit. If status is `NO_HIGH_CONFIDENCE_EDGE`, say plainly that the model does not have enough validated edge today and do not force a bullish or bearish call. If status is `HIGH_CONFIDENCE` or `LOW_CONFIDENCE`, provide the expected 5-day direction, expected magnitude, volatility expectation, cross-horizon risk, and main reason.

### Confidence Gate

Report:

- **Status:** `HIGH_CONFIDENCE`, `LOW_CONFIDENCE`, or `NO_HIGH_CONFIDENCE_EDGE`
- **Historical Test Coverage:** 63/128 (49.2%)
- **Historical Test Win Rate When Covered:** 73.0%
- **Why Covered Or Not Covered Today:** concise explanation using the latest row, accepted patterns, option flow, OI walls, and 30-minute tape.

### Active Signal Checklist

List active and inactive accepted Tier 1/Tier 2 5-day signals from the audited latest row. Do not infer active signals from the research summary, from older rows, or from option flow. For each accepted signal, include the audited row value that made it active or inactive.

Mandatory examples:

- If the accepted signal is `Is_Swing_Up = 1` and the audited row has `Is_Swing_Up = 0`, write `Is_Swing_Up = 1: INACTIVE (latest row Is_Swing_Up = 0)`.
- If the audited row has `Is_Swing_Down = 1`, write `Is_Swing_Down: ACTIVE bearish/timing-risk context` even if it is not an accepted bullish rule.
- If `Golden_Setup = 1` but `Golden_Setup` is not listed under Accepted Patterns, write `Golden_Setup: CONTEXT ONLY, not a validated accepted trigger in this prompt`.

### Market Structure Analysis

Discuss GEX regime, VIX, RSI/momentum, dark-pool ratio, and price relative to SMA20/SMA50. Identify daily support/resistance from the latest 30 daily feature rows: recent swing lows/highs, repeated closes near the same level, SMA20/SMA50, Bollinger bands when present, and the latest close's position relative to those levels.

### Option Flow And Gamma Walls

Discuss latest option trades, fresh OI changes, primary put wall, primary call wall, and whether option flow confirms or contradicts the daily-feature signal.

### 30-Minute Tape

Discuss VWAP, intraday support/resistance, repeated highs/lows, high-volume nodes, and whether the last sessions confirm the forecast.

### Trading Levels

Provide this section every time, even when the confidence gate is `NO_HIGH_CONFIDENCE_EDGE`. Build the ranges from confluence, not from a single isolated level:

- **Buy-side inputs:** nearest eligible put wall or put-heavy OI zone below spot, 30-minute support from recent lows/VWAP clusters/high-volume nodes below spot, and daily support from the latest 30 daily rows.
- **Sell-side inputs:** nearest eligible call wall or call-heavy OI zone above spot, 30-minute resistance from recent highs/VWAP rejections/high-volume nodes above spot, and daily resistance from the latest 30 daily rows.
- Prefer tighter ranges where at least two of the three sources align. If only one source exists, keep the range conservative and say which sources are missing. If no valid below-spot buy confluence exists, write "Not Recommended" for Buy the Dip. If no valid above-spot sell confluence exists, write "Not Recommended" for Sell the Rip.

Required fields:

- **Buy the Dip Range:** price range or "Not Recommended", with the supporting gamma wall, 30-minute support, and daily support evidence. The range must be strictly below the latest current price/close; a put wall above current price is overhead/reclaim context, not dip support.
- **Sell the Rip Range:** price range or "Not Recommended", with the supporting gamma wall, 30-minute resistance, and daily resistance evidence. The range must be strictly above the latest current price/close; a call wall below current price is lower/past resistance, not a rip entry.
- **Invalidation:** price or condition that would invalidate the forecast.

Before finalizing trading levels, run a price-geometry sanity check against the latest current price/close. If Buy the Dip is not below current price, change it to "Not Recommended". If Sell the Rip is not above current price, change it to "Not Recommended". Percentages must match the direction: buy-dip distances are negative and sell-rip distances are positive. Do not omit either range field.

### Signal Strength JSON

Place this JSON at the very end of the markdown response. The classification must represent the expected directional edge over the selected target horizon, `Next5DaysChange` (next 5 trading days):

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
