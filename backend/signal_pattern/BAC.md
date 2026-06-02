# Quantitative Trading Analysis: BAC

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided BAC market data to forecast price action over the next 1 trading day. The 1-day, 2-day, and 5-day horizons were all researched during prompt generation; the signal strength classification must be based primarily on the selected horizon because it had the highest held-out feature-score test win rate for this ticker. Coverage is reported as a reliability caveat, not as the target-selection winner.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

**Runtime Source Of Truth:** For the live forecast, the only current market state is the latest row in the `Data (Last 30 Days)` section, identified by the greatest `ObservationDate`. Research validation metadata is training context only. Never use generated-at dates, research-summary rows, or any other non-data-section context to decide today's active signals.

**Hard Audit Rule:** The latest-row audit is mandatory and must be completed before the forecast. Any forecast that claims a signal is active when the audited latest row shows the opposite is invalid. In particular, if `Is_Swing_Up = 0`, `Is_Swing_Up` is inactive; if `Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", the setup must be described as swing-down/potential-swing-down, not swing-up.

---

## Research Validation Summary

This prompt was generated for `BAC.US` with requested as-of date `2026-05-26` from a fresh SQL Server extraction for this ticker. Candidate rules and the feature-score gate were evaluated separately on `TomorrowChange`, `Next2DaysChange`, and `Next5DaysChange`. The selected primary target for this ticker is `TomorrowChange` (next 1 trading day). This section is research metadata only; do not use it as today's market state during live or historical replay analysis.

The effective features below are stock-specific. They were discovered during this generation run by scanning the available ticker history, creating chronological train/validation/test splits for each candidate target, testing single-feature and two-feature rules, comparing target performance, and training the selective feature-score model. Do not copy accepted patterns, thresholds, or model weights from another stock prompt.

- Daily feature rows: 643 total, 638 selected-target labeled rows from 2023-09-26 to 2026-05-21.
- Train split: 2023-09-26 to 2025-08-04, 446 rows.
- Validation split: 2025-08-05 to 2025-12-29, 96 rows.
- Test split: 2025-12-30 to 2026-05-21, 96 rows.
- Selected target: `TomorrowChange` (next 1 trading day).
- Target selection summary, ordered by held-out feature-score test win rate:
- 1-day: feature-score test win 64.6%, coverage 48/96 (50.0%), selection rank value 651.06, accepted robust patterns 6.
- 5-day: feature-score test win 61.5%, coverage 52/96 (54.2%), selection rank value 622.07, accepted robust patterns 6.
- 2-day: feature-score test win 60.4%, coverage 53/96 (55.2%), selection rank value 609.59, accepted robust patterns 6.
- Baseline selected-target win rate: train 52.7%, validation 55.2%, test 56.2%.
- Baseline tomorrow win rate: train 52.7%, validation 55.2%, test 56.2%.
- Baseline 2-day win rate: train 53.9%, validation 60.4%, test 54.2%.
- Baseline 5-day win rate: train 60.3%, validation 66.3%, test 44.8%.
- Selective feature-score gate: threshold 0.50 on the trained probability score.
- Feature-score train performance on selected target: win 67.6%, coverage 250/446 (56.1%), avg selected return +0.454%.
- Feature-score validation performance on selected target: win 58.1%, coverage 43/96 (44.8%), avg selected return +0.217%.
- Feature-score test performance on selected target: win 64.6%, coverage 48/96 (50.0%), avg selected return +0.230%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 30. Positive call OI change 35324; positive put OI change 10358; near-term call additions 22408; near-term put additions 2852.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 160.
- Broad feature audit rules tested: 302 single-feature rules and 282 two-feature combinations.

### Accepted Patterns

- `VIX_Very_High = 1 AND Prev2DaysChange <= train_q40 (-0.32)` (1-day): train n=38, avg +1.020%, win 63.2%; validation n=7, avg +0.810%, win 85.7%; test n=15, avg +0.509%, win 80.0%; test 1-day avg +0.509%, test 2-day avg +0.771%, test 5-day avg -0.443%.
- `VIX >= train_q80 (19.58) AND Prev2DaysChange <= train_q40 (-0.32)` (1-day): train n=42, avg +0.899%, win 61.9%; validation n=8, avg +0.440%, win 75.0%; test n=15, avg +0.509%, win 80.0%; test 1-day avg +0.509%, test 2-day avg +0.771%, test 5-day avg -0.443%.
- `VIX_Very_High = 1 AND TodayChange >= train_q50 (0.09)` (1-day): train n=38, avg +0.482%, win 63.2%; validation n=7, avg +0.413%, win 71.4%; test n=19, avg +0.727%, win 73.7%; test 1-day avg +0.727%, test 2-day avg +0.605%, test 5-day avg +1.575%.
- `MACD_Line <= train_q20 (-0.2142) AND Prev2DaysChange <= train_q40 (-0.32)` (1-day): train n=28, avg +0.644%, win 60.7%; validation n=9, avg +1.284%, win 88.9%; test n=18, avg +0.455%, win 72.2%; test 1-day avg +0.455%, test 2-day avg +0.752%, test 5-day avg +1.213%.
- `MACD_Line <= train_q40 (0.01894) AND Prev2DaysChange <= train_q40 (-0.32)` (1-day): train n=78, avg +0.460%, win 59.0%; validation n=12, avg +1.062%, win 83.3%; test n=22, avg +0.385%, win 72.7%; test 1-day avg +0.385%, test 2-day avg +0.325%, test 5-day avg +0.840%.
- `MACD_Line <= train_q30 (-0.02424) AND GEX_Above_SMA10 = 1` (1-day): train n=32, avg +0.128%, win 62.5%; validation n=22, avg +0.709%, win 68.2%; test n=27, avg +0.358%, win 74.1%; test 1-day avg +0.358%, test 2-day avg +0.558%, test 5-day avg +1.608%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 48/96 (50.0%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, avoid directional trading levels, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `GEX_BigRise`: model weight -0.4732
- `MACD_Line`: model weight -0.3462
- `GEXChange_Negative`: model weight -0.3442
- `GEX_Percentile_VeryLow`: model weight +0.3135
- `GEX_ZScore_Moderate_Low`: model weight +0.2962
- `GEX_Percentile`: model weight -0.2947
- `SVix_DarkPoolIndex`: model weight -0.2773
- `Is_Swing_Down`: model weight +0.2553
- `GEX_BigDrop`: model weight +0.2402
- `GEX_Escaped_VeryLow_Zscore`: model weight -0.2344
- `Prev2DaysChange`: model weight -0.2321
- `BB_Bandwidth`: model weight +0.2252

### Rejected Or Downgraded Patterns

- `BB_PercentB <= train_q30 (0.4933) AND TodayChange >= train_q70 (0.71)` (1-day): train n=22, avg +0.962%, win 72.7%; validation n=5, avg +1.032%, win 80.0%; test n=12, avg -0.330%, win 58.3%; test 1-day avg -0.330%, test 2-day avg -0.675%, test 5-day avg -0.867%.
- `SVix_DarkPoolIndex <= train_q40 (42.6) AND Prev10DaysChange <= train_q40 (0.66)` (1-day): train n=53, avg +0.820%, win 75.5%; validation n=7, avg +0.096%, win 57.1%; test n=13, avg -0.062%, win 46.2%; test 1-day avg -0.062%, test 2-day avg -0.515%, test 5-day avg -0.627%.
- `GEX_Percentile <= train_q20 (30.75) AND SVix_DarkPoolIndex <= train_q40 (42.6)` (1-day): train n=26, avg +0.807%, win 80.8%; validation n=5, avg +0.172%, win 40.0%; test n=5, avg -0.896%, win 20.0%; test 1-day avg -0.896%, test 2-day avg -2.004%, test 5-day avg -1.950%.
- `SVix_DarkPoolBuyRatio <= train_q40 (0.74) AND Prev10DaysChange <= train_q40 (0.66)` (1-day): train n=54, avg +0.788%, win 74.1%; validation n=7, avg +0.096%, win 57.1%; test n=13, avg -0.062%, win 46.2%; test 1-day avg -0.062%, test 2-day avg -0.515%, test 5-day avg -0.627%.
- `SVix_DarkPoolBuyRatio <= train_q30 (0.61) AND Prev2DaysChange <= train_q50 (0.22)` (1-day): train n=50, avg +0.758%, win 66.0%; validation n=6, avg +0.683%, win 83.3%; test n=6, avg -0.157%, win 33.3%; test 1-day avg -0.157%, test 2-day avg +0.132%, test 5-day avg +0.088%.
- `SVix_DarkPoolIndex <= train_q30 (38) AND Prev2DaysChange <= train_q50 (0.22)` (1-day): train n=50, avg +0.758%, win 66.0%; validation n=6, avg +0.683%, win 83.3%; test n=6, avg -0.157%, win 33.3%; test 1-day avg -0.157%, test 2-day avg +0.132%, test 5-day avg +0.088%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 1-day feature-score gate first, then use accepted 1-day rules, option flow, and 30-minute tape as confirmation or contradiction.

Accepted patterns are conditional rules, not automatically active. A rule is active only when the audited latest row satisfies that exact condition. Do not infer activity from the research-summary list, from older rows, or from option-flow tone.

#### VIX_Very_High = 1 AND Prev2DaysChange <= train_q40 (-0.32)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 1 trading day.
- **Historical Evidence:** `VIX_Very_High = 1 AND Prev2DaysChange <= train_q40 (-0.32)` (1-day): train n=38, avg +1.020%, win 63.2%; validation n=7, avg +0.810%, win 85.7%; test n=15, avg +0.509%, win 80.0%; test 1-day avg +0.509%, test 2-day avg +0.771%, test 5-day avg -0.443%.
- **Rationale:** Use this as an explainable stock-specific 1-day market-flow rule for BAC. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### VIX >= train_q80 (19.58) AND Prev2DaysChange <= train_q40 (-0.32)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 1 trading day.
- **Historical Evidence:** `VIX >= train_q80 (19.58) AND Prev2DaysChange <= train_q40 (-0.32)` (1-day): train n=42, avg +0.899%, win 61.9%; validation n=8, avg +0.440%, win 75.0%; test n=15, avg +0.509%, win 80.0%; test 1-day avg +0.509%, test 2-day avg +0.771%, test 5-day avg -0.443%.
- **Rationale:** Use this as an explainable stock-specific 1-day market-flow rule for BAC. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### VIX_Very_High = 1 AND TodayChange >= train_q50 (0.09)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 1 trading day.
- **Historical Evidence:** `VIX_Very_High = 1 AND TodayChange >= train_q50 (0.09)` (1-day): train n=38, avg +0.482%, win 63.2%; validation n=7, avg +0.413%, win 71.4%; test n=19, avg +0.727%, win 73.7%; test 1-day avg +0.727%, test 2-day avg +0.605%, test 5-day avg +1.575%.
- **Rationale:** Use this as an explainable stock-specific 1-day market-flow rule for BAC. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.

#### MACD_Line <= train_q20 (-0.2142) AND Prev2DaysChange <= train_q40 (-0.32)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 1 trading day.
- **Historical Evidence:** `MACD_Line <= train_q20 (-0.2142) AND Prev2DaysChange <= train_q40 (-0.32)` (1-day): train n=28, avg +0.644%, win 60.7%; validation n=9, avg +1.284%, win 88.9%; test n=18, avg +0.455%, win 72.2%; test 1-day avg +0.455%, test 2-day avg +0.752%, test 5-day avg +1.213%.
- **Rationale:** Use this as an explainable stock-specific 1-day market-flow rule for BAC. Cross-check the other horizons for timing, confirmation, or conflict.
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
8. Resolve conflicts in this order: audited latest row, selective 1-day feature-score gate, accepted Tier 1 1-day rules, near-term option walls close to spot, accepted Tier 2 rules, 30-minute tape, context rules.
9. Produce a 1-day forecast only if the confidence gate is active; otherwise state that there is no high-confidence edge.

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

Provide one decisive paragraph with the confidence-gate status first, based on the Latest Row Audit. If status is `NO_HIGH_CONFIDENCE_EDGE`, say plainly that the model does not have enough validated edge today and do not force a bullish or bearish call. If status is `HIGH_CONFIDENCE` or `LOW_CONFIDENCE`, provide the expected 1-day direction, expected magnitude, volatility expectation, cross-horizon risk, and main reason.

### Confidence Gate

Report:

- **Status:** `HIGH_CONFIDENCE`, `LOW_CONFIDENCE`, or `NO_HIGH_CONFIDENCE_EDGE`
- **Historical Test Coverage:** 48/96 (50.0%)
- **Historical Test Win Rate When Covered:** 64.6%
- **Why Covered Or Not Covered Today:** concise explanation using the latest row, accepted patterns, option flow, OI walls, and 30-minute tape.

### Active Signal Checklist

List active and inactive accepted Tier 1/Tier 2 1-day signals from the audited latest row. Do not infer active signals from the research summary, from older rows, or from option flow. For each accepted signal, include the audited row value that made it active or inactive.

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

Place this JSON at the very end of the markdown response. The classification must represent the expected directional edge over the selected target horizon, `TomorrowChange` (next 1 trading day):

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
