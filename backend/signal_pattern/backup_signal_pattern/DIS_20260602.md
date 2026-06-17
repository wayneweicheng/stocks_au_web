# Quantitative Trading Analysis: DIS

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided DIS market data to forecast price action over the next 2 trading days. The 1-day, 2-day, and 5-day horizons were all researched during prompt generation; the signal strength classification must be based primarily on the selected horizon because it had the highest held-out feature-score test win rate for this ticker. Coverage is reported as a reliability caveat, not as the target-selection winner.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

**Runtime Source Of Truth:** For the live forecast, the only current market state is the latest row in the `Data (Last 30 Days)` section, identified by the greatest `ObservationDate`. Research validation metadata is training context only. Never use generated-at dates, research-summary rows, or any other non-data-section context to decide today's active signals.

**Hard Audit Rule:** The latest-row audit is mandatory and must be completed before the forecast. Any forecast that claims a signal is active when the audited latest row shows the opposite is invalid. In particular, if `Is_Swing_Up = 0`, `Is_Swing_Up` is inactive; if `Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", the setup must be described as swing-down/potential-swing-down, not swing-up.

---

## Research Validation Summary

This prompt was generated for `DIS.US` with requested as-of date `2026-05-26` from a fresh SQL Server extraction for this ticker. Candidate rules and the feature-score gate were evaluated separately on `TomorrowChange`, `Next2DaysChange`, and `Next5DaysChange`. The selected primary target for this ticker is `Next2DaysChange` (next 2 trading days). This section is research metadata only; do not use it as today's market state during live or historical replay analysis.

The effective features below are stock-specific. They were discovered during this generation run by scanning the available ticker history, creating chronological train/validation/test splits for each candidate target, testing single-feature and two-feature rules, comparing target performance, and training the selective feature-score model. Do not copy accepted patterns, thresholds, or model weights from another stock prompt.

- Daily feature rows: 642 total, 636 selected-target labeled rows from 2023-09-26 to 2026-05-20.
- Train split: 2023-09-26 to 2025-08-04, 445 rows.
- Validation split: 2025-08-05 to 2025-12-24, 95 rows.
- Test split: 2025-12-26 to 2026-05-20, 96 rows.
- Selected target: `Next2DaysChange` (next 2 trading days).
- Target selection summary, ordered by held-out feature-score test win rate:
- 2-day: feature-score test win 57.7%, coverage 26/96 (27.1%), selection rank value 580.10, accepted robust patterns 6.
- 1-day: feature-score test win 50.0%, coverage 28/96 (29.2%), selection rank value 503.25, accepted robust patterns 6.
- 5-day: feature-score test win 30.3%, coverage 33/95 (34.7%), selection rank value 305.42, accepted robust patterns 6.
- Baseline selected-target win rate: train 53.5%, validation 50.5%, test 41.7%.
- Baseline tomorrow win rate: train 51.2%, validation 45.8%, test 42.7%.
- Baseline 2-day win rate: train 53.5%, validation 50.5%, test 41.7%.
- Baseline 5-day win rate: train 51.9%, validation 49.5%, test 40.0%.
- Selective feature-score gate: threshold 0.50 on the trained probability score.
- Feature-score train performance on selected target: win 65.3%, coverage 262/445 (58.9%), avg selected return +0.543%.
- Feature-score validation performance on selected target: win 43.5%, coverage 46/95 (48.4%), avg selected return -0.347%.
- Feature-score test performance on selected target: win 57.7%, coverage 26/96 (27.1%), avg selected return +0.468%.
- Large option trade rows sampled: 264.
- Latest OI-change records sampled: 3. Positive call OI change 2066; positive put OI change 357; near-term call additions 2066; near-term put additions 0.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 158.
- Broad feature audit rules tested: 302 single-feature rules and 39 two-feature combinations.

### Accepted Patterns

- `Prev10DaysChange <= train_q10 (-5.718)` (2-day): train n=45, avg +0.502%, win 55.6%; validation n=12, avg +0.576%, win 58.3%; test n=7, avg +1.161%, win 100.0%; test 1-day avg +0.864%, test 2-day avg +1.161%, test 5-day avg +0.451%.
- `Prev10DaysChange >= train_q70 (3.254) AND SVix_DarkPoolBuyRatio <= train_q50 (0.825)` (2-day): train n=76, avg +0.808%, win 65.8%; validation n=12, avg +0.462%, win 83.3%; test n=6, avg +1.428%, win 83.3%; test 1-day avg +0.803%, test 2-day avg +1.428%, test 5-day avg +1.732%.
- `Prev10DaysChange >= train_q70 (3.254) AND SVix_DarkPoolIndex <= train_q50 (45.2)` (2-day): train n=76, avg +0.808%, win 65.8%; validation n=12, avg +0.462%, win 83.3%; test n=6, avg +1.428%, win 83.3%; test 1-day avg +0.803%, test 2-day avg +1.428%, test 5-day avg +1.732%.
- `BB_Bandwidth >= train_q60 (0.1163)` (2-day): train n=174, avg +0.342%, win 55.2%; validation n=25, avg +0.651%, win 72.0%; test n=23, avg +0.089%, win 47.8%; test 1-day avg +0.233%, test 2-day avg +0.089%, test 5-day avg +0.217%.
- `Prev10DaysChange >= train_q70 (3.254) AND GEX_Percentile >= train_q90 (58.71)` (2-day): train n=23, avg +1.244%, win 56.5%; validation n=11, avg +0.615%, win 81.8%; test n=15, avg +0.101%, win 46.7%; test 1-day avg +0.003%, test 2-day avg +0.101%, test 5-day avg +0.065%.
- `Prev10DaysChange >= train_q80 (4.976)` (2-day): train n=89, avg +0.807%, win 64.0%; validation n=9, avg +0.197%, win 66.7%; test n=10, avg +0.074%, win 50.0%; test 1-day avg +0.200%, test 2-day avg +0.074%, test 5-day avg -1.032%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 26/96 (27.1%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, avoid directional trading levels, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `Negative_GEX_AND_High_VIX`: model weight -0.5238
- `GEX_BigRise`: model weight -0.3717
- `GEX_Percentile`: model weight -0.3697
- `GEX_Volatility`: model weight +0.3559
- `GEX_Percentile_High`: model weight +0.3339
- `GEX_ZScore`: model weight +0.3334
- `Pot_Swing_Up_AND_Neg_GEXChange`: model weight +0.2960
- `GEX_Trending_Up`: model weight +0.2892
- `Prev2DaysChange`: model weight +0.2588
- `VIX`: model weight +0.2355
- `BB_Breakout_Lower`: model weight +0.2312
- `RSI`: model weight -0.2187

### Rejected Or Downgraded Patterns

- `BB_PercentB >= train_q90 (0.9469)` (2-day): train n=34, avg +1.784%, win 79.4%; validation n=2, avg -7.800%, win 0.0%; test n=8, avg -0.337%, win 37.5%; test 1-day avg -0.123%, test 2-day avg -0.337%, test 5-day avg -1.748%.
- `GEX_Percentile >= train_q90 (58.71) AND GEX_DayChange >= train_q90 (7.413e+04)` (2-day): train n=22, avg +1.351%, win 59.1%; validation n=9, avg +0.281%, win 66.7%; test n=10, avg -0.024%, win 30.0%; test 1-day avg +0.594%, test 2-day avg -0.024%, test 5-day avg +0.709%.
- `GEX_ZScore_60day >= train_q90 (0.7519) AND RSI >= train_q70 (63.33)` (2-day): train n=29, avg +1.346%, win 65.5%; validation n=6, avg +0.827%, win 83.3%; test n=17, avg -0.563%, win 29.4%; test 1-day avg -0.224%, test 2-day avg -0.563%, test 5-day avg -0.741%.
- `GEX_Percentile >= train_q90 (58.71) AND RSI >= train_q70 (63.33)` (2-day): train n=27, avg +1.184%, win 63.0%; validation n=6, avg +0.827%, win 83.3%; test n=17, avg -0.563%, win 29.4%; test 1-day avg -0.224%, test 2-day avg -0.563%, test 5-day avg -0.741%.
- `GEX_ZScore_60day >= train_q90 (0.7519)` (2-day): train n=45, avg +1.076%, win 64.4%; validation n=17, avg +0.304%, win 70.6%; test n=24, avg -0.549%, win 29.2%; test 1-day avg -0.312%, test 2-day avg -0.549%, test 5-day avg -0.610%.
- `BB_PercentB >= train_q80 (0.838)` (2-day): train n=67, avg +1.042%, win 70.1%; validation n=6, avg -2.700%, win 33.3%; test n=9, avg -0.096%, win 44.4%; test 1-day avg +0.046%, test 2-day avg -0.096%, test 5-day avg -0.991%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 2-day feature-score gate first, then use accepted 2-day rules, option flow, and 30-minute tape as confirmation or contradiction.

Accepted patterns are conditional rules, not automatically active. A rule is active only when the audited latest row satisfies that exact condition. Do not infer activity from the research-summary list, from older rows, or from option-flow tone.

#### Prev10DaysChange <= train_q10 (-5.718)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 2 trading days.
- **Historical Evidence:** `Prev10DaysChange <= train_q10 (-5.718)` (2-day): train n=45, avg +0.502%, win 55.6%; validation n=12, avg +0.576%, win 58.3%; test n=7, avg +1.161%, win 100.0%; test 1-day avg +0.864%, test 2-day avg +1.161%, test 5-day avg +0.451%.
- **Rationale:** Use this as an explainable stock-specific 2-day market-flow rule for DIS. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### Prev10DaysChange >= train_q70 (3.254) AND SVix_DarkPoolBuyRatio <= train_q50 (0.825)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 2 trading days.
- **Historical Evidence:** `Prev10DaysChange >= train_q70 (3.254) AND SVix_DarkPoolBuyRatio <= train_q50 (0.825)` (2-day): train n=76, avg +0.808%, win 65.8%; validation n=12, avg +0.462%, win 83.3%; test n=6, avg +1.428%, win 83.3%; test 1-day avg +0.803%, test 2-day avg +1.428%, test 5-day avg +1.732%.
- **Rationale:** Use this as an explainable stock-specific 2-day market-flow rule for DIS. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### Prev10DaysChange >= train_q70 (3.254) AND SVix_DarkPoolIndex <= train_q50 (45.2)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 2 trading days.
- **Historical Evidence:** `Prev10DaysChange >= train_q70 (3.254) AND SVix_DarkPoolIndex <= train_q50 (45.2)` (2-day): train n=76, avg +0.808%, win 65.8%; validation n=12, avg +0.462%, win 83.3%; test n=6, avg +1.428%, win 83.3%; test 1-day avg +0.803%, test 2-day avg +1.428%, test 5-day avg +1.732%.
- **Rationale:** Use this as an explainable stock-specific 2-day market-flow rule for DIS. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.

#### BB_Bandwidth >= train_q60 (0.1163)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 2 trading days.
- **Historical Evidence:** `BB_Bandwidth >= train_q60 (0.1163)` (2-day): train n=174, avg +0.342%, win 55.2%; validation n=25, avg +0.651%, win 72.0%; test n=23, avg +0.089%, win 47.8%; test 1-day avg +0.233%, test 2-day avg +0.089%, test 5-day avg +0.217%.
- **Rationale:** Use this as an explainable stock-specific 2-day market-flow rule for DIS. Cross-check the other horizons for timing, confirmation, or conflict.
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
8. Resolve conflicts in this order: audited latest row, selective 2-day feature-score gate, accepted Tier 1 2-day rules, near-term option walls close to spot, accepted Tier 2 rules, 30-minute tape, context rules.
9. Produce a 2-day forecast only if the confidence gate is active; otherwise state that there is no high-confidence edge.

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

Provide one decisive paragraph with the confidence-gate status first, based on the Latest Row Audit. If status is `NO_HIGH_CONFIDENCE_EDGE`, say plainly that the model does not have enough validated edge today and do not force a bullish or bearish call. If status is `HIGH_CONFIDENCE` or `LOW_CONFIDENCE`, provide the expected 2-day direction, expected magnitude, volatility expectation, cross-horizon risk, and main reason.

### Confidence Gate

Report:

- **Status:** `HIGH_CONFIDENCE`, `LOW_CONFIDENCE`, or `NO_HIGH_CONFIDENCE_EDGE`
- **Historical Test Coverage:** 26/96 (27.1%)
- **Historical Test Win Rate When Covered:** 57.7%
- **Why Covered Or Not Covered Today:** concise explanation using the latest row, accepted patterns, option flow, OI walls, and 30-minute tape.

### Active Signal Checklist

List active and inactive accepted Tier 1/Tier 2 2-day signals from the audited latest row. Do not infer active signals from the research summary, from older rows, or from option flow. For each accepted signal, include the audited row value that made it active or inactive.

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

Place this JSON at the very end of the markdown response. The classification must represent the expected directional edge over the selected target horizon, `Next2DaysChange` (next 2 trading days):

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
