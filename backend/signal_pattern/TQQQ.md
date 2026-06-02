# Quantitative Trading Analysis: TQQQ

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided TQQQ market data to forecast price action over the next 2 trading days. The 1-day, 2-day, and 5-day horizons were all researched during prompt generation; the signal strength classification must be based primarily on the selected horizon because it had the highest held-out feature-score test win rate for this ticker. Coverage is reported as a reliability caveat, not as the target-selection winner.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

**Runtime Source Of Truth:** For the live forecast, the only current market state is the latest row in the `Data (Last 30 Days)` section, identified by the greatest `ObservationDate`. Research validation metadata is training context only. Never use generated-at dates, research-summary rows, or any other non-data-section context to decide today's active signals.

**Hard Audit Rule:** The latest-row audit is mandatory and must be completed before the forecast. Any forecast that claims a signal is active when the audited latest row shows the opposite is invalid. In particular, if `Is_Swing_Up = 0`, `Is_Swing_Up` is inactive; if `Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", the setup must be described as swing-down/potential-swing-down, not swing-up.

---

## Research Validation Summary

This prompt was generated for `TQQQ.US` with requested as-of date `2026-05-26` from a fresh SQL Server extraction for this ticker. Candidate rules and the feature-score gate were evaluated separately on `TomorrowChange`, `Next2DaysChange`, and `Next5DaysChange`. The selected primary target for this ticker is `Next2DaysChange` (next 2 trading days). This section is research metadata only; do not use it as today's market state during live or historical replay analysis.

The effective features below are stock-specific. They were discovered during this generation run by scanning the available ticker history, creating chronological train/validation/test splits for each candidate target, testing single-feature and two-feature rules, comparing target performance, and training the selective feature-score model. Do not copy accepted patterns, thresholds, or model weights from another stock prompt.

- Daily feature rows: 649 total, 645 selected-target labeled rows from 2023-09-25 to 2026-05-20.
- Train split: 2023-09-25 to 2025-07-31, 451 rows.
- Validation split: 2025-08-01 to 2025-12-24, 97 rows.
- Test split: 2025-12-26 to 2026-05-20, 97 rows.
- Selected target: `Next2DaysChange` (next 2 trading days).
- Target selection summary, ordered by held-out feature-score test win rate:
- 2-day: feature-score test win 90.0%, coverage 10/97 (10.3%), selection rank value 905.49, accepted robust patterns 6.
- 1-day: feature-score test win 54.5%, coverage 44/97 (45.4%), selection rank value 550.33, accepted robust patterns 6.
- 5-day: feature-score test win 37.5%, coverage 40/97 (41.2%), selection rank value 378.02, accepted robust patterns 6.
- Baseline selected-target win rate: train 57.9%, validation 58.8%, test 56.7%.
- Baseline tomorrow win rate: train 58.2%, validation 56.7%, test 55.7%.
- Baseline 2-day win rate: train 57.9%, validation 58.8%, test 56.7%.
- Baseline 5-day win rate: train 61.5%, validation 66.7%, test 51.5%.
- Selective feature-score gate: threshold 0.50 on the trained probability score.
- Feature-score train performance on selected target: win 65.7%, coverage 350/451 (77.6%), avg selected return +1.127%.
- Feature-score validation performance on selected target: win 66.7%, coverage 51/97 (52.6%), avg selected return +1.365%.
- Feature-score test performance on selected target: win 90.0%, coverage 10/97 (10.3%), avg selected return +4.460%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 64. Positive call OI change 21016; positive put OI change 40670; near-term call additions 15961; near-term put additions 26004.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 160.
- Broad feature audit rules tested: 298 single-feature rules and 2117 two-feature combinations.

### Accepted Patterns

- `GEX_Percentile >= train_q50 (50) AND Prev2DaysChange >= train_q80 (4.12)` (2-day): train n=72, avg +1.588%, win 77.8%; validation n=6, avg +2.192%, win 100.0%; test n=15, avg +3.005%, win 86.7%; test 1-day avg +0.942%, test 2-day avg +3.005%, test 5-day avg +8.139%.
- `GEX_Percentile >= train_q60 (50) AND Prev2DaysChange >= train_q80 (4.12)` (2-day): train n=72, avg +1.588%, win 77.8%; validation n=6, avg +2.192%, win 100.0%; test n=15, avg +3.005%, win 86.7%; test 1-day avg +0.942%, test 2-day avg +3.005%, test 5-day avg +8.139%.
- `GEX_Percentile >= train_q70 (50) AND Prev2DaysChange >= train_q80 (4.12)` (2-day): train n=72, avg +1.588%, win 77.8%; validation n=6, avg +2.192%, win 100.0%; test n=15, avg +3.005%, win 86.7%; test 1-day avg +0.942%, test 2-day avg +3.005%, test 5-day avg +8.139%.
- `GEX_Percentile >= train_q80 (50) AND Prev2DaysChange >= train_q80 (4.12)` (2-day): train n=72, avg +1.588%, win 77.8%; validation n=6, avg +2.192%, win 100.0%; test n=15, avg +3.005%, win 86.7%; test 1-day avg +0.942%, test 2-day avg +3.005%, test 5-day avg +8.139%.
- `GEX_Percentile >= train_q90 (60.39) AND SVix_DarkPoolBuyRatio >= train_q50 (0.83)` (2-day): train n=25, avg +0.310%, win 60.0%; validation n=6, avg +3.165%, win 100.0%; test n=11, avg +3.703%, win 81.8%; test 1-day avg +2.155%, test 2-day avg +3.703%, test 5-day avg +9.445%.
- `GEX_Percentile >= train_q90 (60.39) AND SVix_DarkPoolIndex >= train_q50 (45.35)` (2-day): train n=25, avg +0.310%, win 60.0%; validation n=5, avg +3.032%, win 100.0%; test n=11, avg +3.703%, win 81.8%; test 1-day avg +2.155%, test 2-day avg +3.703%, test 5-day avg +9.445%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 10/97 (10.3%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, avoid directional trading levels, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `GEX_ZScore_60day`: model weight +0.5549
- `GEXChange`: model weight -0.4332
- `GEX_Turned_Positive`: model weight -0.4178
- `Setup_Dual_Squeeze`: model weight -0.3335
- `GEX_StableRegime`: model weight +0.3034
- `Is_Potential_Swing_Up`: model weight +0.2763
- `GEX_Volatility`: model weight -0.2675
- `GEX_Above_SMA20`: model weight -0.2480
- `GEX_Above_SMA10`: model weight +0.2342
- `GEX_Percentile_High`: model weight -0.2308
- `GEX_Negative`: model weight -0.2299
- `Is_Potential_Swing_Down`: model weight -0.2297

### Rejected Or Downgraded Patterns

- `Stock_DarkPoolBuySellRatio <= train_q30 (0.92) AND Prev10DaysChange <= train_q40 (0.68)` (2-day): train n=43, avg +3.192%, win 74.4%; validation n=5, avg +0.812%, win 80.0%; test n=14, avg -1.505%, win 28.6%; test 1-day avg -0.246%, test 2-day avg -1.505%, test 5-day avg -0.364%.
- `Stock_DarkPoolIndex <= train_q30 (48) AND Prev10DaysChange <= train_q40 (0.68)` (2-day): train n=43, avg +3.192%, win 74.4%; validation n=5, avg +0.812%, win 80.0%; test n=14, avg -1.505%, win 28.6%; test 1-day avg -0.246%, test 2-day avg -1.505%, test 5-day avg -0.364%.
- `RSI <= train_q30 (48.54) AND Stock_DarkPoolBuySellRatio <= train_q40 (1.02)` (2-day): train n=36, avg +2.828%, win 69.4%; validation n=7, avg -0.407%, win 57.1%; test n=17, avg -0.067%, win 52.9%; test 1-day avg +0.364%, test 2-day avg -0.067%, test 5-day avg +0.251%.
- `RSI <= train_q30 (48.54) AND Stock_DarkPoolIndex <= train_q40 (50.4)` (2-day): train n=36, avg +2.828%, win 69.4%; validation n=7, avg -0.407%, win 57.1%; test n=17, avg -0.067%, win 52.9%; test 1-day avg +0.364%, test 2-day avg -0.067%, test 5-day avg +0.251%.
- `Stock_DarkPoolBuySellRatio <= train_q30 (0.92) AND GEXChange_Positive = 1` (2-day): train n=21, avg +2.692%, win 66.7%; validation n=16, avg +0.152%, win 75.0%; test n=11, avg -1.510%, win 45.5%; test 1-day avg -0.780%, test 2-day avg -1.510%, test 5-day avg -0.304%.
- `Stock_DarkPoolIndex <= train_q30 (48) AND GEXChange_Positive = 1` (2-day): train n=21, avg +2.692%, win 66.7%; validation n=16, avg +0.152%, win 75.0%; test n=11, avg -1.510%, win 45.5%; test 1-day avg -0.780%, test 2-day avg -1.510%, test 5-day avg -0.304%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 2-day feature-score gate first, then use accepted 2-day rules, option flow, and 30-minute tape as confirmation or contradiction.

Accepted patterns are conditional rules, not automatically active. A rule is active only when the audited latest row satisfies that exact condition. Do not infer activity from the research-summary list, from older rows, or from option-flow tone.

#### GEX_Percentile >= train_q50 (50) AND Prev2DaysChange >= train_q80 (4.12)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 2 trading days.
- **Historical Evidence:** `GEX_Percentile >= train_q50 (50) AND Prev2DaysChange >= train_q80 (4.12)` (2-day): train n=72, avg +1.588%, win 77.8%; validation n=6, avg +2.192%, win 100.0%; test n=15, avg +3.005%, win 86.7%; test 1-day avg +0.942%, test 2-day avg +3.005%, test 5-day avg +8.139%.
- **Rationale:** Use this as an explainable stock-specific 2-day market-flow rule for TQQQ. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### GEX_Percentile >= train_q60 (50) AND Prev2DaysChange >= train_q80 (4.12)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 2 trading days.
- **Historical Evidence:** `GEX_Percentile >= train_q60 (50) AND Prev2DaysChange >= train_q80 (4.12)` (2-day): train n=72, avg +1.588%, win 77.8%; validation n=6, avg +2.192%, win 100.0%; test n=15, avg +3.005%, win 86.7%; test 1-day avg +0.942%, test 2-day avg +3.005%, test 5-day avg +8.139%.
- **Rationale:** Use this as an explainable stock-specific 2-day market-flow rule for TQQQ. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### GEX_Percentile >= train_q70 (50) AND Prev2DaysChange >= train_q80 (4.12)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 2 trading days.
- **Historical Evidence:** `GEX_Percentile >= train_q70 (50) AND Prev2DaysChange >= train_q80 (4.12)` (2-day): train n=72, avg +1.588%, win 77.8%; validation n=6, avg +2.192%, win 100.0%; test n=15, avg +3.005%, win 86.7%; test 1-day avg +0.942%, test 2-day avg +3.005%, test 5-day avg +8.139%.
- **Rationale:** Use this as an explainable stock-specific 2-day market-flow rule for TQQQ. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.

#### GEX_Percentile >= train_q80 (50) AND Prev2DaysChange >= train_q80 (4.12)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 2 trading days.
- **Historical Evidence:** `GEX_Percentile >= train_q80 (50) AND Prev2DaysChange >= train_q80 (4.12)` (2-day): train n=72, avg +1.588%, win 77.8%; validation n=6, avg +2.192%, win 100.0%; test n=15, avg +3.005%, win 86.7%; test 1-day avg +0.942%, test 2-day avg +3.005%, test 5-day avg +8.139%.
- **Rationale:** Use this as an explainable stock-specific 2-day market-flow rule for TQQQ. Cross-check the other horizons for timing, confirmation, or conflict.
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
- **Historical Test Coverage:** 10/97 (10.3%)
- **Historical Test Win Rate When Covered:** 90.0%
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
