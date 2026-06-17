# Quantitative Trading Analysis: MCD

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided MCD market data to forecast price action over the next 1 trading day. The 1-day, 2-day, and 5-day horizons were all researched during prompt generation; the signal strength classification must be based primarily on the selected horizon because it had the highest held-out feature-score test win rate for this ticker. Coverage is reported as a reliability caveat, not as the target-selection winner.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

**Runtime Source Of Truth:** For the live forecast, the only current market state is the latest row in the `Data (Last 30 Days)` section, identified by the greatest `ObservationDate`. Research validation metadata is training context only. Never use generated-at dates, research-summary rows, or any other non-data-section context to decide today's active signals.

**Hard Audit Rule:** The latest-row audit is mandatory and must be completed before the forecast. Any forecast that claims a signal is active when the audited latest row shows the opposite is invalid. In particular, if `Is_Swing_Up = 0`, `Is_Swing_Up` is inactive; if `Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", the setup must be described as swing-down/potential-swing-down, not swing-up.

---

## Research Validation Summary

This prompt was generated for `MCD.US` with requested as-of date `2026-06-02` from a fresh SQL Server extraction for this ticker. Candidate rules and the feature-score gate were evaluated separately on `TomorrowChange`, `Next2DaysChange`, and `Next5DaysChange`. The selected primary target for this ticker is `TomorrowChange` (next 1 trading day). This section is research metadata only; do not use it as today's market state during live or historical replay analysis.

The effective features below are stock-specific. They were discovered during this generation run by scanning the available ticker history, creating chronological train/validation/test splits for each candidate target, testing single-feature and two-feature rules, comparing target performance, and training the selective feature-score model. Do not copy accepted patterns, thresholds, or model weights from another stock prompt.

- Daily feature rows: 627 total, 617 selected-target labeled rows from 2023-09-25 to 2026-05-29.
- Train split: 2023-09-25 to 2025-08-18, 431 rows.
- Validation split: 2025-08-19 to 2026-01-08, 93 rows.
- Test split: 2026-01-09 to 2026-05-29, 93 rows.
- Selected target: `TomorrowChange` (next 1 trading day).
- Target selection summary, ordered by held-out feature-score test win rate:
- 1-day: feature-score test win 52.0%, coverage 25/93 (26.9%), selection rank value 522.80, accepted robust patterns 3.
- 2-day: feature-score test win 46.2%, coverage 26/93 (28.0%), selection rank value 464.05, accepted robust patterns 5.
- 5-day: feature-score test win 40.7%, coverage 54/92 (58.7%), selection rank value 412.88, accepted robust patterns 6.
- Baseline selected-target win rate: train 52.0%, validation 51.6%, test 45.2%.
- Baseline tomorrow win rate: train 52.0%, validation 51.6%, test 45.2%.
- Baseline 2-day win rate: train 50.3%, validation 48.9%, test 45.2%.
- Baseline 5-day win rate: train 55.7%, validation 44.6%, test 41.3%.
- Selective feature-score gate: threshold 0.50 on the trained probability score.
- Feature-score train performance on selected target: win 69.4%, coverage 248/431 (57.5%), avg selected return +0.354%.
- Feature-score validation performance on selected target: win 51.2%, coverage 43/93 (46.2%), avg selected return +0.016%.
- Feature-score test performance on selected target: win 52.0%, coverage 25/93 (26.9%), avg selected return +0.107%.
- Large option trade rows sampled: 40.
- Latest OI-change records sampled: 7. Positive call OI change 1769; positive put OI change 1663; near-term call additions 1326; near-term put additions 1663.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 128.
- Broad feature audit rules tested: 300 single-feature rules and 26 two-feature combinations.

### Accepted Patterns

- `BuyPut_GEXDeltaPerc >= train_q90 (54.82)` (1-day): train n=33, avg -0.174%, win 57.6%; validation n=9, avg -0.071%, win 66.7%; test n=5, avg -0.400%, win 80.0%; test 1-day avg -0.400%, test 2-day avg +0.482%, test 5-day avg +0.004%.
- `BuyPut_GEXDeltaPerc >= train_q80 (45.41)` (1-day): train n=66, avg -0.117%, win 56.1%; validation n=20, avg -0.093%, win 60.0%; test n=21, avg -0.171%, win 52.4%; test 1-day avg -0.171%, test 2-day avg -0.133%, test 5-day avg -0.689%.
- `GEX_Trending_Up = 1` (1-day): train n=96, avg -0.048%, win 58.3%; validation n=41, avg -0.121%, win 58.5%; test n=40, avg -0.004%, win 50.0%; test 1-day avg -0.004%, test 2-day avg -0.030%, test 5-day avg -0.286%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 25/93 (26.9%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, do not force a bullish or bearish forecast, still complete the mandatory Trading Levels section, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `GEX_Percentile_VeryLow`: model weight +0.4305
- `RSI`: model weight +0.4084
- `GEX_ZScore_VeryHigh`: model weight -0.3737
- `GEX_ZScore_VeryLow`: model weight -0.3578
- `GEX_Above_SMA20`: model weight -0.3371
- `GEX_Volatility`: model weight +0.3332
- `GEX_Negative`: model weight -0.3207
- `GEX_PctChange`: model weight +0.3103
- `GEX_BigDrop`: model weight +0.3030
- `GEX_Trending_Up`: model weight -0.2917
- `GEX_Rising`: model weight -0.2722
- `GEX_DayChange`: model weight +0.2568

### Rejected Or Downgraded Patterns

- `Prev10DaysChange <= train_q30 (-1.5) AND SVix_DarkPoolBuyRatio <= train_q50 (0.83)` (1-day): train n=57, avg +0.469%, win 68.4%; validation n=16, avg +0.171%, win 62.5%; test n=11, avg -0.214%, win 27.3%; test 1-day avg -0.214%, test 2-day avg -1.036%, test 5-day avg -1.650%.
- `Prev10DaysChange <= train_q30 (-1.5) AND SVix_DarkPoolIndex <= train_q50 (45.5)` (1-day): train n=57, avg +0.469%, win 68.4%; validation n=16, avg +0.171%, win 62.5%; test n=11, avg -0.214%, win 27.3%; test 1-day avg -0.214%, test 2-day avg -1.036%, test 5-day avg -1.650%.
- `Prev10DaysChange <= train_q30 (-1.5) AND BuyPut_GEXDeltaPerc <= train_q40 (28.8)` (1-day): train n=46, avg +0.356%, win 67.4%; validation n=12, avg +0.107%, win 58.3%; test n=13, avg -0.402%, win 30.8%; test 1-day avg -0.402%, test 2-day avg -0.606%, test 5-day avg -1.693%.
- `Prev10DaysChange <= train_q40 (-0.53) AND SVix_DarkPoolBuyRatio <= train_q50 (0.83)` (1-day): train n=74, avg +0.315%, win 63.5%; validation n=20, avg +0.346%, win 70.0%; test n=19, avg -0.206%, win 26.3%; test 1-day avg -0.206%, test 2-day avg -0.724%, test 5-day avg -1.081%.
- `Prev10DaysChange <= train_q40 (-0.53) AND SVix_DarkPoolIndex <= train_q50 (45.5)` (1-day): train n=74, avg +0.315%, win 63.5%; validation n=20, avg +0.346%, win 70.0%; test n=19, avg -0.206%, win 26.3%; test 1-day avg -0.206%, test 2-day avg -0.724%, test 5-day avg -1.081%.
- `BB_Bandwidth >= train_q90 (0.1165)` (1-day): train n=44, avg +0.313%, win 68.2%; validation n=0, avg n/a, win n/a; test n=18, avg -0.071%, win 44.4%; test 1-day avg -0.071%, test 2-day avg -0.004%, test 5-day avg +0.101%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 1-day feature-score gate first, then use accepted 1-day rules, option flow, and 30-minute tape as confirmation or contradiction.

Accepted patterns are conditional rules, not automatically active. A rule is active only when the audited latest row satisfies that exact condition. Do not infer activity from the research-summary list, from older rows, or from option-flow tone.

#### BuyPut_GEXDeltaPerc >= train_q90 (54.82)
- **Tier:** Tier 1
- **Signal:** Bearish/Risk-Off for the next 1 trading day.
- **Historical Evidence:** `BuyPut_GEXDeltaPerc >= train_q90 (54.82)` (1-day): train n=33, avg -0.174%, win 57.6%; validation n=9, avg -0.071%, win 66.7%; test n=5, avg -0.400%, win 80.0%; test 1-day avg -0.400%, test 2-day avg +0.482%, test 5-day avg +0.004%.
- **Rationale:** Use this as an explainable stock-specific 1-day market-flow rule for MCD. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### BuyPut_GEXDeltaPerc >= train_q80 (45.41)
- **Tier:** Tier 1
- **Signal:** Bearish/Risk-Off for the next 1 trading day.
- **Historical Evidence:** `BuyPut_GEXDeltaPerc >= train_q80 (45.41)` (1-day): train n=66, avg -0.117%, win 56.1%; validation n=20, avg -0.093%, win 60.0%; test n=21, avg -0.171%, win 52.4%; test 1-day avg -0.171%, test 2-day avg -0.133%, test 5-day avg -0.689%.
- **Rationale:** Use this as an explainable stock-specific 1-day market-flow rule for MCD. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### GEX_Trending_Up = 1
- **Tier:** Tier 2
- **Signal:** Bearish/Risk-Off for the next 1 trading day.
- **Historical Evidence:** `GEX_Trending_Up = 1` (1-day): train n=96, avg -0.048%, win 58.3%; validation n=41, avg -0.121%, win 58.5%; test n=40, avg -0.004%, win 50.0%; test 1-day avg -0.004%, test 2-day avg -0.030%, test 5-day avg -0.286%.
- **Rationale:** Use this as an explainable stock-specific 1-day market-flow rule for MCD. Cross-check the other horizons for timing, confirmation, or conflict.
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

Provide one decisive paragraph with the confidence-gate status first, based on the Latest Row Audit. If status is `NO_HIGH_CONFIDENCE_EDGE`, say plainly that the model does not have enough validated edge today and do not force a bullish or bearish call. If status is `HIGH_CONFIDENCE` or `LOW_CONFIDENCE`, provide the expected 1-day direction, expected magnitude, volatility expectation, cross-horizon risk, and main reason.

### Confidence Gate

Report:

- **Status:** `HIGH_CONFIDENCE`, `LOW_CONFIDENCE`, or `NO_HIGH_CONFIDENCE_EDGE`
- **Historical Test Coverage:** 25/93 (26.9%)
- **Historical Test Win Rate When Covered:** 52.0%
- **Why Covered Or Not Covered Today:** concise explanation using the latest row, accepted patterns, option flow, OI walls, and 30-minute tape.

### Active Signal Checklist

List active and inactive accepted Tier 1/Tier 2 1-day signals from the audited latest row. Do not infer active signals from the research summary, from older rows, or from option flow. For each accepted signal, include the audited row value that made it active or inactive.

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
