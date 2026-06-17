# Quantitative Trading Analysis: TLT

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided TLT market data to forecast price action over the next 2 trading days. The 1-day, 2-day, and 5-day horizons were all researched during prompt generation; the signal strength classification must be based primarily on the selected horizon because it had the highest held-out feature-score test win rate for this ticker. Coverage is reported as a reliability caveat, not as the target-selection winner.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

**Runtime Source Of Truth:** For the live forecast, the only current market state is the latest row in the `Data (Last 30 Days)` section, identified by the greatest `ObservationDate`. Research validation metadata is training context only. Never use generated-at dates, research-summary rows, or any other non-data-section context to decide today's active signals.

**Hard Audit Rule:** The latest-row audit is mandatory and must be completed before the forecast. Any forecast that claims a signal is active when the audited latest row shows the opposite is invalid. In particular, if `Is_Swing_Up = 0`, `Is_Swing_Up` is inactive; if `Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", the setup must be described as swing-down/potential-swing-down, not swing-up.

---

## Research Validation Summary

This prompt was generated for `TLT.US` with requested as-of date `2026-06-02` from a fresh SQL Server extraction for this ticker. Candidate rules and the feature-score gate were evaluated separately on `TomorrowChange`, `Next2DaysChange`, and `Next5DaysChange`. The selected primary target for this ticker is `Next2DaysChange` (next 2 trading days). This section is research metadata only; do not use it as today's market state during live or historical replay analysis.

The effective features below are stock-specific. They were discovered during this generation run by scanning the available ticker history, creating chronological train/validation/test splits for each candidate target, testing single-feature and two-feature rules, comparing target performance, and training the selective feature-score model. Do not copy accepted patterns, thresholds, or model weights from another stock prompt.

- Daily feature rows: 838 total, 834 selected-target labeled rows from 2023-01-04 to 2026-05-28.
- Train split: 2023-01-04 to 2025-05-19, 583 rows.
- Validation split: 2025-05-20 to 2025-11-18, 125 rows.
- Test split: 2025-11-19 to 2026-05-28, 126 rows.
- Selected target: `Next2DaysChange` (next 2 trading days).
- Target selection summary, ordered by held-out feature-score test win rate:
- 2-day: feature-score test win 44.4%, coverage 45/126 (35.7%), selection rank value 447.96, accepted robust patterns 6.
- 5-day: feature-score test win 41.8%, coverage 55/125 (44.0%), selection rank value 422.41, accepted robust patterns 6.
- 1-day: feature-score test win 40.6%, coverage 69/126 (54.8%), selection rank value 411.20, accepted robust patterns 6.
- Baseline selected-target win rate: train 45.5%, validation 54.4%, test 49.2%.
- Baseline tomorrow win rate: train 50.0%, validation 50.4%, test 47.6%.
- Baseline 2-day win rate: train 45.5%, validation 54.4%, test 49.2%.
- Baseline 5-day win rate: train 45.6%, validation 53.6%, test 42.4%.
- Selective feature-score gate: threshold 0.50 on the trained probability score.
- Feature-score train performance on selected target: win 65.1%, coverage 218/583 (37.4%), avg selected return +0.416%.
- Feature-score validation performance on selected target: win 55.8%, coverage 43/125 (34.4%), avg selected return +0.065%.
- Feature-score test performance on selected target: win 44.4%, coverage 45/126 (35.7%), avg selected return -0.060%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 100. Positive call OI change 75807; positive put OI change 57232; near-term call additions 24930; near-term put additions 19779.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 128.
- Broad feature audit rules tested: 300 single-feature rules and 36 two-feature combinations.

### Accepted Patterns

- `TodayChange >= train_q80 (0.8) AND GEXChange >= train_q80 (44.59)` (2-day): train n=29, avg -0.186%, win 69.0%; validation n=8, avg -0.280%, win 62.5%; test n=6, avg -0.563%, win 66.7%; test 1-day avg -0.333%, test 2-day avg -0.563%, test 5-day avg -0.362%.
- `TodayChange >= train_q80 (0.8) AND GEX_PctChange >= train_q80 (38.1)` (2-day): train n=42, avg -0.076%, win 61.9%; validation n=10, avg -0.392%, win 70.0%; test n=7, avg -0.351%, win 57.1%; test 1-day avg -0.233%, test 2-day avg -0.351%, test 5-day avg +0.001%.
- `TodayChange >= train_q80 (0.8) AND GEX_PctChange >= train_q70 (13.65)` (2-day): train n=58, avg -0.062%, win 62.1%; validation n=13, avg -0.521%, win 69.2%; test n=7, avg -0.351%, win 57.1%; test 1-day avg -0.233%, test 2-day avg -0.351%, test 5-day avg +0.001%.
- `TodayChange >= train_q80 (0.8) AND GEX_DayChange >= train_q80 (6.747e+05)` (2-day): train n=45, avg -0.200%, win 66.7%; validation n=13, avg -0.521%, win 69.2%; test n=7, avg -0.351%, win 57.1%; test 1-day avg -0.233%, test 2-day avg -0.351%, test 5-day avg +0.001%.
- `BB_PercentB <= train_q10 (0.09745)` (2-day): train n=58, avg +0.358%, win 58.6%; validation n=5, avg +0.700%, win 100.0%; test n=22, avg +0.047%, win 50.0%; test 1-day avg +0.045%, test 2-day avg +0.047%, test 5-day avg +0.212%.
- `TodayChange >= train_q80 (0.8)` (2-day): train n=120, avg -0.216%, win 60.0%; validation n=16, avg -0.423%, win 62.5%; test n=7, avg -0.351%, win 57.1%; test 1-day avg -0.233%, test 2-day avg -0.351%, test 5-day avg +0.001%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 45/126 (35.7%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, do not force a bullish or bearish forecast, still complete the mandatory Trading Levels section, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `Prev10DaysChange`: model weight -0.3064
- `Stock_DarkPoolBuySellRatio`: model weight -0.2985
- `Is_Potential_Swing_Down`: model weight -0.2937
- `Stock_DarkPoolIndex`: model weight +0.2931
- `TodayChange`: model weight -0.2906
- `GEX_Trending_Up`: model weight +0.2626
- `Is_Swing_Down`: model weight +0.2386
- `GEX_ZScore_60day`: model weight +0.2220
- `GEX_BigDrop`: model weight +0.2165
- `GEX_StableRegime`: model weight -0.1993
- `GEX_Percentile_VeryLow`: model weight +0.1980
- `GEX_Escaped_VeryLow_Zscore`: model weight -0.1968

### Rejected Or Downgraded Patterns

- `BB_Bandwidth <= train_q10 (0.04068)` (2-day): train n=59, avg +0.398%, win 59.3%; validation n=56, avg +0.238%, win 62.5%; test n=78, avg -0.172%, win 41.0%; test 1-day avg -0.086%, test 2-day avg -0.172%, test 5-day avg -0.307%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 2-day feature-score gate first, then use accepted 2-day rules, option flow, and 30-minute tape as confirmation or contradiction.

Accepted patterns are conditional rules, not automatically active. A rule is active only when the audited latest row satisfies that exact condition. Do not infer activity from the research-summary list, from older rows, or from option-flow tone.

#### TodayChange >= train_q80 (0.8) AND GEXChange >= train_q80 (44.59)
- **Tier:** Tier 1
- **Signal:** Bearish/Risk-Off for the next 2 trading days.
- **Historical Evidence:** `TodayChange >= train_q80 (0.8) AND GEXChange >= train_q80 (44.59)` (2-day): train n=29, avg -0.186%, win 69.0%; validation n=8, avg -0.280%, win 62.5%; test n=6, avg -0.563%, win 66.7%; test 1-day avg -0.333%, test 2-day avg -0.563%, test 5-day avg -0.362%.
- **Rationale:** Use this as an explainable stock-specific 2-day market-flow rule for TLT. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### TodayChange >= train_q80 (0.8) AND GEX_PctChange >= train_q80 (38.1)
- **Tier:** Tier 1
- **Signal:** Bearish/Risk-Off for the next 2 trading days.
- **Historical Evidence:** `TodayChange >= train_q80 (0.8) AND GEX_PctChange >= train_q80 (38.1)` (2-day): train n=42, avg -0.076%, win 61.9%; validation n=10, avg -0.392%, win 70.0%; test n=7, avg -0.351%, win 57.1%; test 1-day avg -0.233%, test 2-day avg -0.351%, test 5-day avg +0.001%.
- **Rationale:** Use this as an explainable stock-specific 2-day market-flow rule for TLT. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### TodayChange >= train_q80 (0.8) AND GEX_PctChange >= train_q70 (13.65)
- **Tier:** Tier 2
- **Signal:** Bearish/Risk-Off for the next 2 trading days.
- **Historical Evidence:** `TodayChange >= train_q80 (0.8) AND GEX_PctChange >= train_q70 (13.65)` (2-day): train n=58, avg -0.062%, win 62.1%; validation n=13, avg -0.521%, win 69.2%; test n=7, avg -0.351%, win 57.1%; test 1-day avg -0.233%, test 2-day avg -0.351%, test 5-day avg +0.001%.
- **Rationale:** Use this as an explainable stock-specific 2-day market-flow rule for TLT. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.

#### TodayChange >= train_q80 (0.8) AND GEX_DayChange >= train_q80 (6.747e+05)
- **Tier:** Tier 2
- **Signal:** Bearish/Risk-Off for the next 2 trading days.
- **Historical Evidence:** `TodayChange >= train_q80 (0.8) AND GEX_DayChange >= train_q80 (6.747e+05)` (2-day): train n=45, avg -0.200%, win 66.7%; validation n=13, avg -0.521%, win 69.2%; test n=7, avg -0.351%, win 57.1%; test 1-day avg -0.233%, test 2-day avg -0.351%, test 5-day avg +0.001%.
- **Rationale:** Use this as an explainable stock-specific 2-day market-flow rule for TLT. Cross-check the other horizons for timing, confirmation, or conflict.
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

Provide one decisive paragraph with the confidence-gate status first, based on the Latest Row Audit. If status is `NO_HIGH_CONFIDENCE_EDGE`, say plainly that the model does not have enough validated edge today and do not force a bullish or bearish call. If status is `HIGH_CONFIDENCE` or `LOW_CONFIDENCE`, provide the expected 2-day direction, expected magnitude, volatility expectation, cross-horizon risk, and main reason.

### Confidence Gate

Report:

- **Status:** `HIGH_CONFIDENCE`, `LOW_CONFIDENCE`, or `NO_HIGH_CONFIDENCE_EDGE`
- **Historical Test Coverage:** 45/126 (35.7%)
- **Historical Test Win Rate When Covered:** 44.4%
- **Why Covered Or Not Covered Today:** concise explanation using the latest row, accepted patterns, option flow, OI walls, and 30-minute tape.

### Active Signal Checklist

List active and inactive accepted Tier 1/Tier 2 2-day signals from the audited latest row. Do not infer active signals from the research summary, from older rows, or from option flow. For each accepted signal, include the audited row value that made it active or inactive.

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
