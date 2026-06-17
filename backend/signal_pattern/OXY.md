# Quantitative Trading Analysis: OXY

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided OXY market data to forecast price action over the next 1 trading day. The 1-day, 2-day, and 5-day horizons were all researched during prompt generation; the signal strength classification must be based primarily on the selected horizon because it had the highest held-out feature-score test win rate for this ticker. Coverage is reported as a reliability caveat, not as the target-selection winner.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

**Runtime Source Of Truth:** For the live forecast, the only current market state is the latest row in the `Data (Last 30 Days)` section, identified by the greatest `ObservationDate`. Research validation metadata is training context only. Never use generated-at dates, research-summary rows, or any other non-data-section context to decide today's active signals.

**Hard Audit Rule:** The latest-row audit is mandatory and must be completed before the forecast. Any forecast that claims a signal is active when the audited latest row shows the opposite is invalid. In particular, if `Is_Swing_Up = 0`, `Is_Swing_Up` is inactive; if `Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", the setup must be described as swing-down/potential-swing-down, not swing-up.

---

## Research Validation Summary

This prompt was generated for `OXY.US` with requested as-of date `2026-06-02` from a fresh SQL Server extraction for this ticker. Candidate rules and the feature-score gate were evaluated separately on `TomorrowChange`, `Next2DaysChange`, and `Next5DaysChange`. The selected primary target for this ticker is `TomorrowChange` (next 1 trading day). This section is research metadata only; do not use it as today's market state during live or historical replay analysis.

The effective features below are stock-specific. They were discovered during this generation run by scanning the available ticker history, creating chronological train/validation/test splits for each candidate target, testing single-feature and two-feature rules, comparing target performance, and training the selective feature-score model. Do not copy accepted patterns, thresholds, or model weights from another stock prompt.

- Daily feature rows: 640 total, 633 selected-target labeled rows from 2023-09-25 to 2026-05-29.
- Train split: 2023-09-25 to 2025-08-12, 443 rows.
- Validation split: 2025-08-13 to 2026-01-06, 95 rows.
- Test split: 2026-01-07 to 2026-05-29, 95 rows.
- Selected target: `TomorrowChange` (next 1 trading day).
- Target selection summary, ordered by held-out feature-score test win rate:
- 1-day: feature-score test win 80.0%, coverage 15/95 (15.8%), selection rank value 802.54, accepted robust patterns 1.
- 5-day: feature-score test win 78.3%, coverage 23/95 (24.2%), selection rank value 787.38, accepted robust patterns 6.
- 2-day: feature-score test win 62.9%, coverage 35/95 (36.8%), selection rank value 633.12, accepted robust patterns 3.
- Baseline selected-target win rate: train 48.1%, validation 47.4%, test 54.7%.
- Baseline tomorrow win rate: train 48.1%, validation 47.4%, test 54.7%.
- Baseline 2-day win rate: train 49.5%, validation 50.5%, test 56.8%.
- Baseline 5-day win rate: train 46.4%, validation 48.9%, test 68.4%.
- Selective feature-score gate: threshold 0.50 on the trained probability score.
- Feature-score train performance on selected target: win 63.7%, coverage 193/443 (43.6%), avg selected return +0.574%.
- Feature-score validation performance on selected target: win 50.0%, coverage 44/95 (46.3%), avg selected return +0.121%.
- Feature-score test performance on selected target: win 80.0%, coverage 15/95 (15.8%), avg selected return +0.959%.
- Large option trade rows sampled: 687.
- Latest OI-change records sampled: 28. Positive call OI change 22574; positive put OI change 8694; near-term call additions 11037; near-term put additions 879.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 128.
- Broad feature audit rules tested: 300 single-feature rules and 40 two-feature combinations.

### Accepted Patterns

- `Is_Potential_Swing_Down = 1` (1-day): train n=37, avg +0.275%, win 56.8%; validation n=13, avg +0.238%, win 53.8%; test n=15, avg +0.113%, win 60.0%; test 1-day avg +0.113%, test 2-day avg +0.463%, test 5-day avg +1.372%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 15/95 (15.8%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, do not force a bullish or bearish forecast, still complete the mandatory Trading Levels section, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `GEX_ZScore`: model weight +0.4734
- `GEX_Rising`: model weight -0.4178
- `Low_GEX_Z_AND_Pot_Swing_Up`: model weight -0.3718
- `SVix_DarkPoolBuyRatio`: model weight -0.3592
- `GEX_Escaped_VeryLow_Zscore`: model weight +0.3428
- `Prev10DaysChange`: model weight -0.3408
- `GEX_ZScore_VeryLow`: model weight +0.3243
- `GEX_Falling`: model weight +0.3176
- `GEXChange`: model weight -0.3146
- `GEX_Percentile_Low`: model weight -0.2973
- `GEX_Percentile`: model weight -0.2763
- `SVix_DarkPoolIndex`: model weight +0.2628

### Rejected Or Downgraded Patterns

- `SVix_DarkPoolBuyRatio >= train_q80 (1.21) AND VIX >= train_q80 (19.61)` (1-day): train n=29, avg -2.018%, win 79.3%; validation n=6, avg -0.297%, win 50.0%; test n=15, avg +0.765%, win 40.0%; test 1-day avg +0.765%, test 2-day avg +1.149%, test 5-day avg +4.647%.
- `SVix_DarkPoolIndex >= train_q80 (54.7) AND VIX >= train_q80 (19.61)` (1-day): train n=29, avg -2.018%, win 79.3%; validation n=6, avg -0.297%, win 50.0%; test n=15, avg +0.765%, win 40.0%; test 1-day avg +0.765%, test 2-day avg +1.149%, test 5-day avg +4.647%.
- `SVix_DarkPoolBuyRatio >= train_q70 (1.09) AND VIX >= train_q80 (19.61)` (1-day): train n=36, avg -1.688%, win 75.0%; validation n=8, avg -0.286%, win 50.0%; test n=17, avg +0.584%, win 41.2%; test 1-day avg +0.584%, test 2-day avg +1.146%, test 5-day avg +4.811%.
- `VIX >= train_q80 (19.61) AND SVix_DarkPoolIndex >= train_q70 (52.2)` (1-day): train n=36, avg -1.688%, win 75.0%; validation n=8, avg -0.286%, win 50.0%; test n=17, avg +0.584%, win 41.2%; test 1-day avg +0.584%, test 2-day avg +1.146%, test 5-day avg +4.811%.
- `VIX >= train_q80 (19.61) AND SVix_DarkPoolIndex >= train_q60 (49.4)` (1-day): train n=44, avg -1.472%, win 70.5%; validation n=9, avg -0.534%, win 55.6%; test n=19, avg +0.754%, win 42.1%; test 1-day avg +0.754%, test 2-day avg +1.300%, test 5-day avg +4.763%.
- `VIX >= train_q80 (19.61) AND SVix_DarkPoolBuyRatio >= train_q60 (0.98)` (1-day): train n=44, avg -1.472%, win 70.5%; validation n=9, avg -0.534%, win 55.6%; test n=19, avg +0.754%, win 42.1%; test 1-day avg +0.754%, test 2-day avg +1.300%, test 5-day avg +4.763%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 1-day feature-score gate first, then use accepted 1-day rules, option flow, and 30-minute tape as confirmation or contradiction.

Accepted patterns are conditional rules, not automatically active. A rule is active only when the audited latest row satisfies that exact condition. Do not infer activity from the research-summary list, from older rows, or from option-flow tone.

#### Is_Potential_Swing_Down = 1
- **Tier:** Tier 1
- **Signal:** Bullish for the next 1 trading day.
- **Historical Evidence:** `Is_Potential_Swing_Down = 1` (1-day): train n=37, avg +0.275%, win 56.8%; validation n=13, avg +0.238%, win 53.8%; test n=15, avg +0.113%, win 60.0%; test 1-day avg +0.113%, test 2-day avg +0.463%, test 5-day avg +1.372%.
- **Rationale:** Use this as an explainable stock-specific 1-day market-flow rule for OXY. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.


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
- **Historical Test Coverage:** 15/95 (15.8%)
- **Historical Test Win Rate When Covered:** 80.0%
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
- Prefer tighter ranges where at least two of the three sources align. If only one source exists, keep the range conservative and say which sources are missing. If no valid below-spot buy confluence exists, write "Not Recommended" for Buy the Dip. If no valid above-spot sell confluence exists, write "Not Recommended" for Sell the Rip.

Required fields:

- **Buy the Dip Range:** price range or "Not Recommended", with the supporting gamma wall, 30-minute support, and daily support evidence. The range must be strictly below the latest current price/close; a put wall above current price is overhead/reclaim context, not dip support.
- **Sell the Rip Range:** price range or "Not Recommended", with the supporting gamma wall, 30-minute resistance, and daily resistance evidence. The range must be strictly above the latest current price/close; a call wall below current price is lower/past resistance, not a rip entry.
- **Invalidation:** price or condition that would invalidate the forecast.

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
