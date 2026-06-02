# Quantitative Trading Analysis: TSLA

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided TSLA market data to forecast price action over the next 2 trading days. The 1-day, 2-day, and 5-day horizons were all researched during prompt generation; the signal strength classification must be based primarily on the selected horizon because it had the highest held-out feature-score test win rate for this ticker. Coverage is reported as a reliability caveat, not as the target-selection winner.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

**Runtime Source Of Truth:** For the live forecast, the only current market state is the latest row in the `Data (Last 30 Days)` section, identified by the greatest `ObservationDate`. Research validation metadata is training context only. Never use generated-at dates, research-summary rows, or any other non-data-section context to decide today's active signals.

**Hard Audit Rule:** The latest-row audit is mandatory and must be completed before the forecast. Any forecast that claims a signal is active when the audited latest row shows the opposite is invalid. In particular, if `Is_Swing_Up = 0`, `Is_Swing_Up` is inactive; if `Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", the setup must be described as swing-down/potential-swing-down, not swing-up.

---

## Research Validation Summary

This prompt was generated for `TSLA.US` with requested as-of date `2026-05-26` from a fresh SQL Server extraction for this ticker. Candidate rules and the feature-score gate were evaluated separately on `TomorrowChange`, `Next2DaysChange`, and `Next5DaysChange`. The selected primary target for this ticker is `Next2DaysChange` (next 2 trading days). This section is research metadata only; do not use it as today's market state during live or historical replay analysis.

The effective features below are stock-specific. They were discovered during this generation run by scanning the available ticker history, creating chronological train/validation/test splits for each candidate target, testing single-feature and two-feature rules, comparing target performance, and training the selective feature-score model. Do not copy accepted patterns, thresholds, or model weights from another stock prompt.

- Daily feature rows: 833 total, 830 selected-target labeled rows from 2023-01-04 to 2026-05-20.
- Train split: 2023-01-04 to 2025-05-19, 581 rows.
- Validation split: 2025-05-20 to 2025-11-13, 124 rows.
- Test split: 2025-11-14 to 2026-05-20, 125 rows.
- Selected target: `Next2DaysChange` (next 2 trading days).
- Target selection summary, ordered by held-out feature-score test win rate:
- 2-day: feature-score test win 52.4%, coverage 21/125 (16.8%), selection rank value 525.95, accepted robust patterns 2.
- 1-day: feature-score test win 47.5%, coverage 40/125 (32.0%), selection rank value 478.43, accepted robust patterns 4.
- 5-day: feature-score test win 43.6%, coverage 55/125 (44.0%), selection rank value 440.77, accepted robust patterns 6.
- Baseline selected-target win rate: train 50.1%, validation 54.0%, test 48.0%.
- Baseline tomorrow win rate: train 52.0%, validation 53.6%, test 51.2%.
- Baseline 2-day win rate: train 50.1%, validation 54.0%, test 48.0%.
- Baseline 5-day win rate: train 51.4%, validation 55.6%, test 41.6%.
- Selective feature-score gate: threshold 0.50 on the trained probability score.
- Feature-score train performance on selected target: win 61.2%, coverage 294/581 (50.6%), avg selected return +1.715%.
- Feature-score validation performance on selected target: win 59.3%, coverage 54/124 (43.5%), avg selected return +1.266%.
- Feature-score test performance on selected target: win 52.4%, coverage 21/125 (16.8%), avg selected return +0.465%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 100. Positive call OI change 147715; positive put OI change 144820; near-term call additions 117463; near-term put additions 135965.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 160.
- Broad feature audit rules tested: 292 single-feature rules and 0 two-feature combinations.

### Accepted Patterns

- `RSI >= train_q70 (64.87)` (2-day): train n=174, avg +1.647%, win 58.0%; validation n=28, avg +0.685%, win 60.7%; test n=24, avg +0.420%, win 54.2%; test 1-day avg +0.170%, test 2-day avg +0.420%, test 5-day avg +1.520%.
- `Prev2DaysChange <= train_q30 (-2.15)` (2-day): train n=175, avg +1.109%, win 55.4%; validation n=30, avg +0.989%, win 60.0%; test n=38, avg +0.392%, win 52.6%; test 1-day avg +0.216%, test 2-day avg +0.392%, test 5-day avg +0.282%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 21/125 (16.8%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, avoid directional trading levels, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `GEX_Percentile_High`: model weight +0.3387
- `BB_PercentB`: model weight +0.3326
- `GEX_ZScore_VeryHigh`: model weight -0.3087
- `TodayChange`: model weight -0.2799
- `GEX_BigDrop`: model weight +0.2461
- `SVix_DarkPoolIndex`: model weight -0.2453
- `GEX_Above_SMA20`: model weight -0.2421
- `GEX_ZScore_60day`: model weight +0.2387
- `Prev10DaysChange`: model weight -0.2357
- `SVix_DarkPoolBuyRatio`: model weight +0.2332
- `BB_Bandwidth`: model weight +0.2205
- `Setup_Dual_Squeeze`: model weight +0.2166

### Rejected Or Downgraded Patterns

- `BB_PercentB >= train_q80 (0.8674)` (2-day): train n=103, avg +1.971%, win 61.2%; validation n=14, avg +1.173%, win 42.9%; test n=13, avg -0.897%, win 38.5%; test 1-day avg -0.753%, test 2-day avg -0.897%, test 5-day avg -2.600%.
- `Prev2DaysChange >= train_q80 (4.49)` (2-day): train n=117, avg +1.669%, win 58.1%; validation n=21, avg -0.443%, win 42.9%; test n=12, avg -0.601%, win 50.0%; test 1-day avg -0.452%, test 2-day avg -0.601%, test 5-day avg -1.527%.
- `Prev10DaysChange >= train_q70 (7.5)` (2-day): train n=175, avg +1.430%, win 53.7%; validation n=29, avg +0.104%, win 44.8%; test n=17, avg -1.702%, win 35.3%; test 1-day avg -0.942%, test 2-day avg -1.702%, test 5-day avg -1.791%.
- `VIX >= train_q90 (21.98)` (2-day): train n=59, avg +1.422%, win 47.5%; validation n=2, avg +4.765%, win 100.0%; test n=29, avg -0.635%, win 41.4%; test 1-day avg -0.348%, test 2-day avg -0.635%, test 5-day avg -1.131%.
- `GEX_Positive = 1` (2-day): train n=113, avg +1.376%, win 49.6%; validation n=117, avg +0.145%, win 51.3%; test n=103, avg -0.163%, win 44.7%; test 1-day avg -0.026%, test 2-day avg -0.163%, test 5-day avg -0.361%.
- `Prev2DaysChange >= train_q70 (2.72)` (2-day): train n=175, avg +1.358%, win 57.1%; validation n=37, avg -0.126%, win 51.4%; test n=23, avg -1.340%, win 34.8%; test 1-day avg -0.980%, test 2-day avg -1.340%, test 5-day avg -2.519%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 2-day feature-score gate first, then use accepted 2-day rules, option flow, and 30-minute tape as confirmation or contradiction.

Accepted patterns are conditional rules, not automatically active. A rule is active only when the audited latest row satisfies that exact condition. Do not infer activity from the research-summary list, from older rows, or from option-flow tone.

#### RSI >= train_q70 (64.87)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 2 trading days.
- **Historical Evidence:** `RSI >= train_q70 (64.87)` (2-day): train n=174, avg +1.647%, win 58.0%; validation n=28, avg +0.685%, win 60.7%; test n=24, avg +0.420%, win 54.2%; test 1-day avg +0.170%, test 2-day avg +0.420%, test 5-day avg +1.520%.
- **Rationale:** Use this as an explainable stock-specific 2-day market-flow rule for TSLA. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### Prev2DaysChange <= train_q30 (-2.15)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 2 trading days.
- **Historical Evidence:** `Prev2DaysChange <= train_q30 (-2.15)` (2-day): train n=175, avg +1.109%, win 55.4%; validation n=30, avg +0.989%, win 60.0%; test n=38, avg +0.392%, win 52.6%; test 1-day avg +0.216%, test 2-day avg +0.392%, test 5-day avg +0.282%.
- **Rationale:** Use this as an explainable stock-specific 2-day market-flow rule for TSLA. Cross-check the other horizons for timing, confirmation, or conflict.
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
- **Historical Test Coverage:** 21/125 (16.8%)
- **Historical Test Win Rate When Covered:** 52.4%
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
