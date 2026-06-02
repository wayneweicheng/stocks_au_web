# Quantitative Trading Analysis: AMD

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided AMD market data to forecast price action over the next 5 trading days. The 1-day, 2-day, and 5-day horizons were all researched during prompt generation; the signal strength classification must be based primarily on the selected horizon because it had the highest held-out feature-score test win rate for this ticker. Coverage is reported as a reliability caveat, not as the target-selection winner.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

**Runtime Source Of Truth:** For the live forecast, the only current market state is the latest row in the `Data (Last 30 Days)` section, identified by the greatest `ObservationDate`. Research validation metadata is training context only. Never use generated-at dates, research-summary rows, or any other non-data-section context to decide today's active signals.

**Hard Audit Rule:** The latest-row audit is mandatory and must be completed before the forecast. Any forecast that claims a signal is active when the audited latest row shows the opposite is invalid. In particular, if `Is_Swing_Up = 0`, `Is_Swing_Up` is inactive; if `Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", the setup must be described as swing-down/potential-swing-down, not swing-up.

---

## Research Validation Summary

This prompt was generated for `AMD.US` with requested as-of date `2026-06-02` from a fresh SQL Server extraction for this ticker. Candidate rules and the feature-score gate were evaluated separately on `TomorrowChange`, `Next2DaysChange`, and `Next5DaysChange`. The selected primary target for this ticker is `Next5DaysChange` (next 5 trading days). This section is research metadata only; do not use it as today's market state during live or historical replay analysis.

The effective features below are stock-specific. They were discovered during this generation run by scanning the available ticker history, creating chronological train/validation/test splits for each candidate target, testing single-feature and two-feature rules, comparing target performance, and training the selective feature-score model. Do not copy accepted patterns, thresholds, or model weights from another stock prompt.

- Daily feature rows: 650 total, 645 selected-target labeled rows from 2023-09-25 to 2026-05-22.
- Train split: 2023-09-25 to 2025-08-01, 451 rows.
- Validation split: 2025-08-04 to 2025-12-26, 97 rows.
- Test split: 2025-12-29 to 2026-05-22, 97 rows.
- Selected target: `Next5DaysChange` (next 5 trading days).
- Target selection summary, ordered by held-out feature-score test win rate:
- 5-day: feature-score test win 73.5%, coverage 34/97 (35.1%), selection rank value 743.44, accepted robust patterns 6.
- 2-day: feature-score test win 67.9%, coverage 53/98 (54.1%), selection rank value 686.63, accepted robust patterns 6.
- 1-day: feature-score test win 56.1%, coverage 66/98 (67.3%), selection rank value 567.62, accepted robust patterns 2.
- Baseline selected-target win rate: train 53.9%, validation 62.9%, test 63.9%.
- Baseline tomorrow win rate: train 50.9%, validation 47.4%, test 54.1%.
- Baseline 2-day win rate: train 53.2%, validation 52.6%, test 62.2%.
- Baseline 5-day win rate: train 53.9%, validation 62.9%, test 63.9%.
- Selective feature-score gate: threshold 0.75 on the trained probability score.
- Feature-score train performance on selected target: win 90.3%, coverage 62/451 (13.7%), avg selected return +5.037%.
- Feature-score validation performance on selected target: win 60.4%, coverage 48/97 (49.5%), avg selected return +1.487%.
- Feature-score test performance on selected target: win 73.5%, coverage 34/97 (35.1%), avg selected return +4.645%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 89. Positive call OI change 25879; positive put OI change 42049; near-term call additions 8067; near-term put additions 16099.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 128.
- Broad feature audit rules tested: 300 single-feature rules and 546 two-feature combinations.

### Accepted Patterns

- `BuyPut_GEXDeltaPerc <= train_q30 (28.13) AND BB_PercentB >= train_q50 (0.5784)` (5-day): train n=35, avg +1.859%, win 65.7%; validation n=10, avg +16.394%, win 90.0%; test n=5, avg +16.312%, win 100.0%; test 1-day avg +2.478%, test 2-day avg +3.540%, test 5-day avg +16.312%.
- `BuyPut_GEXDeltaPerc <= train_q30 (28.13) AND Stock_DarkPoolBuySellRatio >= train_q60 (1.04)` (5-day): train n=34, avg +1.225%, win 64.7%; validation n=11, avg +1.497%, win 63.6%; test n=6, avg +14.662%, win 100.0%; test 1-day avg +2.575%, test 2-day avg +4.232%, test 5-day avg +14.662%.
- `BuyPut_GEXDeltaPerc <= train_q30 (28.13) AND Stock_DarkPoolIndex >= train_q60 (50.9)` (5-day): train n=34, avg +1.225%, win 64.7%; validation n=11, avg +1.497%, win 63.6%; test n=6, avg +14.662%, win 100.0%; test 1-day avg +2.575%, test 2-day avg +4.232%, test 5-day avg +14.662%.
- `BuyPut_GEXDeltaPerc <= train_q30 (28.13) AND GEXChange_Negative = 0` (5-day): train n=78, avg +1.341%, win 57.7%; validation n=20, avg +7.322%, win 70.0%; test n=5, avg +14.116%, win 100.0%; test 1-day avg +3.870%, test 2-day avg +6.178%, test 5-day avg +14.116%.
- `BuyPut_GEXDeltaPerc <= train_q30 (28.13) AND Stock_DarkPoolBuySellRatio >= train_q50 (0.96)` (5-day): train n=47, avg +1.410%, win 63.8%; validation n=14, avg +0.560%, win 57.1%; test n=7, avg +13.854%, win 100.0%; test 1-day avg +1.786%, test 2-day avg +3.729%, test 5-day avg +13.854%.
- `BuyPut_GEXDeltaPerc <= train_q30 (28.13) AND Stock_DarkPoolIndex >= train_q50 (48.9)` (5-day): train n=47, avg +1.410%, win 63.8%; validation n=14, avg +0.560%, win 57.1%; test n=7, avg +13.854%, win 100.0%; test 1-day avg +1.786%, test 2-day avg +3.729%, test 5-day avg +13.854%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 34/97 (35.1%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, do not force a bullish or bearish forecast, still complete the mandatory Trading Levels section, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `GEX_HighVolatility`: model weight -0.5644
- `GEX_Percentile_VeryLow`: model weight -0.5248
- `GEX_Volatility`: model weight -0.4939
- `Golden_Setup`: model weight +0.4025
- `GEX_Above_SMA20`: model weight +0.3781
- `GEX_Turned_Positive`: model weight -0.3713
- `BB_Bandwidth`: model weight -0.3472
- `GEX_Escaped_VeryLow_Zscore`: model weight +0.3288
- `GEX_StableRegime`: model weight -0.3233
- `Pot_Swing_Up_AND_Neg_GEXChange`: model weight +0.3206
- `GEX_Percentile_VeryHigh`: model weight -0.3037
- `GEX_ZScore_Low`: model weight +0.2952

### Rejected Or Downgraded Patterns

- `VIX >= train_q50 (16.09) AND Is_Potential_Swing_Up = 1` (5-day): train n=24, avg +2.991%, win 79.2%; validation n=14, avg +3.081%, win 78.6%; test n=5, avg -3.188%, win 40.0%; test 1-day avg +0.144%, test 2-day avg -2.660%, test 5-day avg -3.188%.
- `VIX >= train_q50 (16.09) AND PotentialSwingIndicator = "Potential swing up"` (5-day): train n=24, avg +2.991%, win 79.2%; validation n=14, avg +3.081%, win 78.6%; test n=5, avg -3.188%, win 40.0%; test 1-day avg +0.144%, test 2-day avg -2.660%, test 5-day avg -3.188%.
- `Is_Potential_Swing_Up = 1 AND GEX_Percentile_VeryHigh = 0` (5-day): train n=28, avg +2.298%, win 71.4%; validation n=21, avg +2.092%, win 71.4%; test n=6, avg -0.305%, win 50.0%; test 1-day avg +0.490%, test 2-day avg -0.757%, test 5-day avg -0.305%.
- `Is_Potential_Swing_Up = 1 AND GEX_Percentile_High = 0` (5-day): train n=28, avg +2.298%, win 71.4%; validation n=21, avg +2.092%, win 71.4%; test n=6, avg -0.305%, win 50.0%; test 1-day avg +0.490%, test 2-day avg -0.757%, test 5-day avg -0.305%.
- `PotentialSwingIndicator = "Potential swing up" AND GEX_Percentile_VeryHigh = 0` (5-day): train n=28, avg +2.298%, win 71.4%; validation n=21, avg +2.092%, win 71.4%; test n=6, avg -0.305%, win 50.0%; test 1-day avg +0.490%, test 2-day avg -0.757%, test 5-day avg -0.305%.
- `PotentialSwingIndicator = "Potential swing up" AND GEX_Percentile_High = 0` (5-day): train n=28, avg +2.298%, win 71.4%; validation n=21, avg +2.092%, win 71.4%; test n=6, avg -0.305%, win 50.0%; test 1-day avg +0.490%, test 2-day avg -0.757%, test 5-day avg -0.305%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 5-day feature-score gate first, then use accepted 5-day rules, option flow, and 30-minute tape as confirmation or contradiction.

Accepted patterns are conditional rules, not automatically active. A rule is active only when the audited latest row satisfies that exact condition. Do not infer activity from the research-summary list, from older rows, or from option-flow tone.

#### BuyPut_GEXDeltaPerc <= train_q30 (28.13) AND BB_PercentB >= train_q50 (0.5784)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `BuyPut_GEXDeltaPerc <= train_q30 (28.13) AND BB_PercentB >= train_q50 (0.5784)` (5-day): train n=35, avg +1.859%, win 65.7%; validation n=10, avg +16.394%, win 90.0%; test n=5, avg +16.312%, win 100.0%; test 1-day avg +2.478%, test 2-day avg +3.540%, test 5-day avg +16.312%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for AMD. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### BuyPut_GEXDeltaPerc <= train_q30 (28.13) AND Stock_DarkPoolBuySellRatio >= train_q60 (1.04)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `BuyPut_GEXDeltaPerc <= train_q30 (28.13) AND Stock_DarkPoolBuySellRatio >= train_q60 (1.04)` (5-day): train n=34, avg +1.225%, win 64.7%; validation n=11, avg +1.497%, win 63.6%; test n=6, avg +14.662%, win 100.0%; test 1-day avg +2.575%, test 2-day avg +4.232%, test 5-day avg +14.662%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for AMD. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### BuyPut_GEXDeltaPerc <= train_q30 (28.13) AND Stock_DarkPoolIndex >= train_q60 (50.9)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `BuyPut_GEXDeltaPerc <= train_q30 (28.13) AND Stock_DarkPoolIndex >= train_q60 (50.9)` (5-day): train n=34, avg +1.225%, win 64.7%; validation n=11, avg +1.497%, win 63.6%; test n=6, avg +14.662%, win 100.0%; test 1-day avg +2.575%, test 2-day avg +4.232%, test 5-day avg +14.662%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for AMD. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.

#### BuyPut_GEXDeltaPerc <= train_q30 (28.13) AND GEXChange_Negative = 0
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `BuyPut_GEXDeltaPerc <= train_q30 (28.13) AND GEXChange_Negative = 0` (5-day): train n=78, avg +1.341%, win 57.7%; validation n=20, avg +7.322%, win 70.0%; test n=5, avg +14.116%, win 100.0%; test 1-day avg +3.870%, test 2-day avg +6.178%, test 5-day avg +14.116%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for AMD. Cross-check the other horizons for timing, confirmation, or conflict.
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
- **Historical Test Coverage:** 34/97 (35.1%)
- **Historical Test Win Rate When Covered:** 73.5%
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
- Gamma walls are preferred evidence, not a prerequisite. If there is no valid below-spot put wall, build Buy the Dip from 30-minute support plus daily support. If there is no valid above-spot call wall, build Sell the Rip from 30-minute resistance plus daily resistance.
- Prefer tighter ranges where at least two of the three sources align. If only one source exists, keep the range conservative and say which sources are missing. Use "Not Recommended" only when there is no valid level on the correct side of spot from gamma walls, 30-minute bars, or daily support/resistance.
- Consistency check: if Market Structure Analysis, 30-Minute Tape, or Invalidation names a valid support level below spot, Buy the Dip must use that level or a narrow range around it when no put wall is available. If those sections name a valid resistance level above spot, Sell the Rip must use that level or a narrow range around it when no call wall is available. Do not cite a 30-minute/daily support or resistance level and then ignore it in Trading Levels.

Required fields:

- **Buy the Dip Range:** price range or "Not Recommended", with the supporting gamma wall, 30-minute support, and daily support evidence. If gamma-wall support is unavailable, explicitly cite the 30-minute and/or daily support levels used instead. The range must be strictly below the latest current price/close; a put wall above current price is overhead/reclaim context, not dip support.
- **Sell the Rip Range:** price range or "Not Recommended", with the supporting gamma wall, 30-minute resistance, and daily resistance evidence. If gamma-wall resistance is unavailable, explicitly cite the 30-minute and/or daily resistance levels used instead. The range must be strictly above the latest current price/close; a call wall below current price is lower/past resistance, not a rip entry.
- **Invalidation:** price or condition that would invalidate the forecast.
- **Fallback Audit:** one sentence confirming whether gamma-wall, 30-minute, and daily levels were available for each side. If a range is "Not Recommended", this sentence must explicitly say that no valid gamma-wall, 30-minute, or daily level exists on the correct side of spot.

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
