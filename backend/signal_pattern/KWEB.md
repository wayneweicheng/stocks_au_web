# Quantitative Trading Analysis: KWEB

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided KWEB market data to forecast price action over the next 5 trading days. The 1-day, 2-day, and 5-day horizons were all researched during prompt generation; the signal strength classification must be based primarily on the selected horizon because it had the highest held-out feature-score test win rate for this ticker. Coverage is reported as a reliability caveat, not as the target-selection winner.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

**Runtime Source Of Truth:** For the live forecast, the only current market state is the latest row in the `Data (Last 30 Days)` section, identified by the greatest `ObservationDate`. Research validation metadata is training context only. Never use generated-at dates, research-summary rows, or any other non-data-section context to decide today's active signals.

**Hard Audit Rule:** The latest-row audit is mandatory and must be completed before the forecast. Any forecast that claims a signal is active when the audited latest row shows the opposite is invalid. In particular, if `Is_Swing_Up = 0`, `Is_Swing_Up` is inactive; if `Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", the setup must be described as swing-down/potential-swing-down, not swing-up.

---

## Research Validation Summary

This prompt was generated for `KWEB.US` with requested as-of date `2026-05-26` from a fresh SQL Server extraction for this ticker. Candidate rules and the feature-score gate were evaluated separately on `TomorrowChange`, `Next2DaysChange`, and `Next5DaysChange`. The selected primary target for this ticker is `Next5DaysChange` (next 5 trading days). This section is research metadata only; do not use it as today's market state during live or historical replay analysis.

The effective features below are stock-specific. They were discovered during this generation run by scanning the available ticker history, creating chronological train/validation/test splits for each candidate target, testing single-feature and two-feature rules, comparing target performance, and training the selective feature-score model. Do not copy accepted patterns, thresholds, or model weights from another stock prompt.

- Daily feature rows: 818 total, 802 selected-target labeled rows from 2023-01-04 to 2026-05-15.
- Train split: 2023-01-04 to 2025-05-21, 561 rows.
- Validation split: 2025-05-22 to 2025-11-13, 120 rows.
- Test split: 2025-11-14 to 2026-05-15, 121 rows.
- Selected target: `Next5DaysChange` (next 5 trading days).
- Target selection summary, ordered by held-out feature-score test win rate:
- 5-day: feature-score test win 39.0%, coverage 82/121 (67.8%), selection rank value 395.80, accepted robust patterns 5.
- 1-day: feature-score test win 37.8%, coverage 74/121 (61.2%), selection rank value 384.34, accepted robust patterns 1.
- 2-day: feature-score test win 33.3%, coverage 63/121 (52.1%), selection rank value 338.01, accepted robust patterns 4.
- Baseline selected-target win rate: train 46.0%, validation 56.7%, test 38.0%.
- Baseline tomorrow win rate: train 47.7%, validation 51.2%, test 36.4%.
- Baseline 2-day win rate: train 48.7%, validation 52.1%, test 36.4%.
- Baseline 5-day win rate: train 46.0%, validation 56.7%, test 38.0%.
- Selective feature-score gate: threshold 0.55 on the trained probability score.
- Feature-score train performance on selected target: win 77.1%, coverage 192/561 (34.2%), avg selected return +2.364%.
- Feature-score validation performance on selected target: win 50.0%, coverage 60/120 (50.0%), avg selected return +0.151%.
- Feature-score test performance on selected target: win 39.0%, coverage 82/121 (67.8%), avg selected return -1.224%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 70. Positive call OI change 68536; positive put OI change 12973; near-term call additions 9572; near-term put additions 2033.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 160.
- Broad feature audit rules tested: 300 single-feature rules and 5 two-feature combinations.

### Accepted Patterns

- `BB_PercentB >= train_q80 (0.7585) AND GEX_Percentile >= train_q50 (50)` (5-day): train n=73, avg -0.050%, win 67.1%; validation n=21, avg -0.405%, win 71.4%; test n=9, avg -4.428%, win 88.9%; test 1-day avg -0.864%, test 2-day avg -1.742%, test 5-day avg -4.428%.
- `BB_PercentB >= train_q80 (0.7585) AND GEX_Percentile >= train_q60 (50)` (5-day): train n=73, avg -0.050%, win 67.1%; validation n=21, avg -0.405%, win 71.4%; test n=9, avg -4.428%, win 88.9%; test 1-day avg -0.864%, test 2-day avg -1.742%, test 5-day avg -4.428%.
- `BB_PercentB >= train_q80 (0.7585)` (5-day): train n=97, avg -0.237%, win 66.0%; validation n=28, avg -0.264%, win 64.3%; test n=9, avg -4.428%, win 88.9%; test 1-day avg -0.864%, test 2-day avg -1.742%, test 5-day avg -4.428%.
- `GEX_Percentile >= train_q50 (50)` (5-day): train n=352, avg -0.003%, win 55.7%; validation n=38, avg -0.345%, win 63.2%; test n=37, avg -1.981%, win 67.6%; test 1-day avg -0.440%, test 2-day avg -0.819%, test 5-day avg -1.981%.
- `GEX_Percentile >= train_q60 (50)` (5-day): train n=352, avg -0.003%, win 55.7%; validation n=38, avg -0.345%, win 63.2%; test n=37, avg -1.981%, win 67.6%; test 1-day avg -0.440%, test 2-day avg -0.819%, test 5-day avg -1.981%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 82/121 (67.8%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, avoid directional trading levels, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `GEX_Volatility`: model weight +0.7637
- `GEX_ZScore_Moderate_Low`: model weight -0.6261
- `GEX_BigRise`: model weight -0.6127
- `GEX_ZScore_60day`: model weight -0.5927
- `GEX_ZScore_Low`: model weight -0.5120
- `RSI`: model weight -0.3985
- `Low_GEX_Z_AND_Pot_Swing_Up`: model weight -0.3129
- `Negative_GEX_AND_High_VIX`: model weight +0.3099
- `MACD_Line`: model weight -0.2950
- `GEX_Trending_Up`: model weight +0.2847
- `MACD_Positive`: model weight -0.2341
- `GEXChange`: model weight +0.2220

### Rejected Or Downgraded Patterns

- `RSI <= train_q10 (31.12)` (5-day): train n=56, avg +2.419%, win 75.0%; validation n=0, avg n/a, win n/a; test n=39, avg -0.304%, win 46.2%; test 1-day avg -0.078%, test 2-day avg +0.077%, test 5-day avg -0.304%.
- `GEX_ZScore <= train_q10 (-1.295)` (5-day): train n=56, avg -2.412%, win 78.6%; validation n=18, avg +1.603%, win 22.2%; test n=15, avg +0.197%, win 60.0%; test 1-day avg -0.344%, test 2-day avg -0.446%, test 5-day avg +0.197%.
- `GEX_ZScore_Moderate_Low = 1` (5-day): train n=48, avg -2.011%, win 79.2%; validation n=11, avg +2.535%, win 9.1%; test n=13, avg +0.502%, win 53.8%; test 1-day avg -0.168%, test 2-day avg +0.627%, test 5-day avg +0.502%.
- `Stock_DarkPoolBuySellRatio >= train_q90 (2.08)` (5-day): train n=59, avg +1.962%, win 49.2%; validation n=40, avg +0.381%, win 45.0%; test n=9, avg -1.266%, win 22.2%; test 1-day avg -0.764%, test 2-day avg -1.769%, test 5-day avg -1.266%.
- `Stock_DarkPoolIndex >= train_q90 (67.5)` (5-day): train n=60, avg +1.837%, win 48.3%; validation n=40, avg +0.381%, win 45.0%; test n=9, avg -1.266%, win 22.2%; test 1-day avg -0.764%, test 2-day avg -1.769%, test 5-day avg -1.266%.
- `VIX >= train_q90 (21.98)` (5-day): train n=57, avg +1.743%, win 75.4%; validation n=2, avg -0.055%, win 50.0%; test n=29, avg -0.325%, win 51.7%; test 1-day avg -0.036%, test 2-day avg -0.201%, test 5-day avg -0.325%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 5-day feature-score gate first, then use accepted 5-day rules, option flow, and 30-minute tape as confirmation or contradiction.

Accepted patterns are conditional rules, not automatically active. A rule is active only when the audited latest row satisfies that exact condition. Do not infer activity from the research-summary list, from older rows, or from option-flow tone.

#### BB_PercentB >= train_q80 (0.7585) AND GEX_Percentile >= train_q50 (50)
- **Tier:** Tier 1
- **Signal:** Bearish/Risk-Off for the next 5 trading days.
- **Historical Evidence:** `BB_PercentB >= train_q80 (0.7585) AND GEX_Percentile >= train_q50 (50)` (5-day): train n=73, avg -0.050%, win 67.1%; validation n=21, avg -0.405%, win 71.4%; test n=9, avg -4.428%, win 88.9%; test 1-day avg -0.864%, test 2-day avg -1.742%, test 5-day avg -4.428%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for KWEB. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### BB_PercentB >= train_q80 (0.7585) AND GEX_Percentile >= train_q60 (50)
- **Tier:** Tier 1
- **Signal:** Bearish/Risk-Off for the next 5 trading days.
- **Historical Evidence:** `BB_PercentB >= train_q80 (0.7585) AND GEX_Percentile >= train_q60 (50)` (5-day): train n=73, avg -0.050%, win 67.1%; validation n=21, avg -0.405%, win 71.4%; test n=9, avg -4.428%, win 88.9%; test 1-day avg -0.864%, test 2-day avg -1.742%, test 5-day avg -4.428%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for KWEB. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### BB_PercentB >= train_q80 (0.7585)
- **Tier:** Tier 2
- **Signal:** Bearish/Risk-Off for the next 5 trading days.
- **Historical Evidence:** `BB_PercentB >= train_q80 (0.7585)` (5-day): train n=97, avg -0.237%, win 66.0%; validation n=28, avg -0.264%, win 64.3%; test n=9, avg -4.428%, win 88.9%; test 1-day avg -0.864%, test 2-day avg -1.742%, test 5-day avg -4.428%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for KWEB. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.

#### GEX_Percentile >= train_q50 (50)
- **Tier:** Tier 2
- **Signal:** Bearish/Risk-Off for the next 5 trading days.
- **Historical Evidence:** `GEX_Percentile >= train_q50 (50)` (5-day): train n=352, avg -0.003%, win 55.7%; validation n=38, avg -0.345%, win 63.2%; test n=37, avg -1.981%, win 67.6%; test 1-day avg -0.440%, test 2-day avg -0.819%, test 5-day avg -1.981%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for KWEB. Cross-check the other horizons for timing, confirmation, or conflict.
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

Provide one decisive paragraph with the confidence-gate status first, based on the Latest Row Audit. If status is `NO_HIGH_CONFIDENCE_EDGE`, say plainly that the model does not have enough validated edge today and do not force a bullish or bearish call. If status is `HIGH_CONFIDENCE` or `LOW_CONFIDENCE`, provide the expected 5-day direction, expected magnitude, volatility expectation, cross-horizon risk, and main reason.

### Confidence Gate

Report:

- **Status:** `HIGH_CONFIDENCE`, `LOW_CONFIDENCE`, or `NO_HIGH_CONFIDENCE_EDGE`
- **Historical Test Coverage:** 82/121 (67.8%)
- **Historical Test Win Rate When Covered:** 39.0%
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
