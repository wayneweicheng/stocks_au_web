# Quantitative Trading Analysis: IWM

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided IWM market data to forecast price action over the next 5 trading days. The 1-day, 2-day, and 5-day horizons were all researched during prompt generation; the signal strength classification must be based primarily on the selected horizon because it had the strongest held-out support for this ticker.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

**Runtime Source Of Truth:** For the live forecast, the only current market state is the latest row in the `Data (Last 30 Days)` section, identified by the greatest `ObservationDate`. Research validation metadata is training context only. Never use generated-at dates, research-summary rows, or any other non-data-section context to decide today's active signals.

**Hard Audit Rule:** The latest-row audit is mandatory and must be completed before the forecast. Any forecast that claims a signal is active when the audited latest row shows the opposite is invalid. In particular, if `Is_Swing_Up = 0`, `Is_Swing_Up` is inactive; if `Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", the setup must be described as swing-down/potential-swing-down, not swing-up.

---

## Research Validation Summary

This prompt was generated for `IWM.US` with requested as-of date `2026-05-22` from a fresh SQL Server extraction for this ticker. Candidate rules and the feature-score gate were evaluated separately on `TomorrowChange`, `Next2DaysChange`, and `Next5DaysChange`. The selected primary target for this ticker is `Next5DaysChange` (next 5 trading days). This section is research metadata only; do not use it as today's market state during live or historical replay analysis.

The effective features below are stock-specific. They were discovered during this generation run by scanning the available ticker history, creating chronological train/validation/test splits for each candidate target, testing single-feature and two-feature rules, comparing target performance, and training the selective feature-score model. Do not copy accepted patterns, thresholds, or model weights from another stock prompt.

- Daily feature rows: 847 total, 841 selected-target labeled rows from 2022-12-13 to 2026-05-14.
- Train split: 2022-12-13 to 2025-05-05, 588 rows.
- Validation split: 2025-05-06 to 2025-11-04, 126 rows.
- Test split: 2025-11-05 to 2026-05-14, 127 rows.
- Selected target: `Next5DaysChange` (next 5 trading days).
- Target selection summary:
- 5-day: target-selection score 75.71; feature-score test win 60.3%, coverage 63/127 (49.6%), accepted robust patterns 6.
- 1-day: target-selection score 30.42; feature-score test win 58.6%, coverage 70/127 (55.1%), accepted robust patterns 6.
- 2-day: target-selection score 22.73; feature-score test win 54.5%, coverage 66/127 (52.0%), accepted robust patterns 6.
- Baseline selected-target win rate: train 51.4%, validation 65.1%, test 54.3%.
- Baseline tomorrow win rate: train 51.1%, validation 55.1%, test 56.7%.
- Baseline 2-day win rate: train 51.0%, validation 50.4%, test 52.0%.
- Baseline 5-day win rate: train 51.4%, validation 65.1%, test 54.3%.
- Selective feature-score gate: threshold 0.51 on the trained probability score.
- Feature-score train performance on selected target: win 67.1%, coverage 301/588 (51.2%), avg selected return +0.817%.
- Feature-score validation performance on selected target: win 80.0%, coverage 45/126 (35.7%), avg selected return +1.535%.
- Feature-score test performance on selected target: win 60.3%, coverage 63/127 (49.6%), avg selected return +1.152%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 100. Positive call OI change 98431; positive put OI change 426703; near-term call additions 56200; near-term put additions 57193.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 128.
- Broad feature audit rules tested: 298 single-feature rules and 392 two-feature combinations.

### Accepted Patterns

- `GEX_Percentile <= train_q20 (38.32) AND GEX_Volatility >= train_q60 (1.183e+06)` (5-day): train n=73, avg +0.558%, win 65.8%; validation n=12, avg +2.332%, win 100.0%; test n=5, avg +5.624%, win 100.0%; test 1-day avg +0.954%, test 2-day avg +1.642%, test 5-day avg +5.624%.
- `GEX_Volatility >= train_q60 (1.183e+06) AND GEX_ZScore_60day <= train_q10 (-1.11)` (5-day): train n=46, avg +0.809%, win 65.2%; validation n=7, avg +2.329%, win 100.0%; test n=5, avg +4.928%, win 100.0%; test 1-day avg +0.448%, test 2-day avg +1.054%, test 5-day avg +4.928%.
- `GEX_Volatility >= train_q70 (1.389e+06) AND GEX_ZScore_60day <= train_q30 (-0.06089)` (5-day): train n=75, avg +0.689%, win 62.7%; validation n=12, avg +2.771%, win 100.0%; test n=6, avg +4.853%, win 100.0%; test 1-day avg -0.067%, test 2-day avg +1.112%, test 5-day avg +4.853%.
- `Prev2DaysChange <= train_q20 (-1.396) AND GEX_Volatility >= train_q60 (1.183e+06)` (5-day): train n=54, avg +0.006%, win 55.6%; validation n=6, avg +1.505%, win 100.0%; test n=7, avg +4.416%, win 100.0%; test 1-day avg +0.754%, test 2-day avg +1.333%, test 5-day avg +4.416%.
- `Prev2DaysChange <= train_q20 (-1.396) AND GEX_Volatility >= train_q70 (1.389e+06)` (5-day): train n=44, avg +0.420%, win 56.8%; validation n=5, avg +1.622%, win 100.0%; test n=5, avg +4.458%, win 100.0%; test 1-day avg +0.294%, test 2-day avg +0.978%, test 5-day avg +4.458%.
- `GEX_Volatility >= train_q70 (1.389e+06) AND Prev2DaysChange <= train_q30 (-0.83)` (5-day): train n=55, avg +0.519%, win 58.2%; validation n=7, avg +2.090%, win 100.0%; test n=5, avg +4.458%, win 100.0%; test 1-day avg +0.294%, test 2-day avg +0.978%, test 5-day avg +4.458%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 63/127 (49.6%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, avoid directional trading levels, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `GEX_StableRegime`: model weight -0.4988
- `SVix_DarkPoolIndex`: model weight -0.4942
- `MACD_Line`: model weight -0.4493
- `GEX_Positive`: model weight -0.3314
- `VIX_Very_High`: model weight +0.3191
- `TodayChange`: model weight -0.2944
- `GEX_BigRise`: model weight -0.2750
- `GEX_ZScore_VeryHigh`: model weight -0.2668
- `Prev2DaysChange`: model weight -0.2621
- `GEX_Negative`: model weight +0.2307
- `MACD_Positive`: model weight +0.2307
- `GEX_HighVolatility`: model weight -0.2221

### Rejected Or Downgraded Patterns

- `Negative_GEX_AND_High_VIX = 1 AND BB_Bandwidth >= train_q70 (0.1079)` (5-day): train n=33, avg +2.117%, win 87.9%; validation n=5, avg +4.030%, win 100.0%; test n=5, avg -0.168%, win 40.0%; test 1-day avg +0.478%, test 2-day avg +0.466%, test 5-day avg -0.168%.
- `VIX >= train_q80 (20) AND BB_Bandwidth >= train_q70 (0.1079)` (5-day): train n=50, avg +1.786%, win 86.0%; validation n=5, avg +4.030%, win 100.0%; test n=5, avg -0.168%, win 40.0%; test 1-day avg +0.478%, test 2-day avg +0.466%, test 5-day avg -0.168%.
- `VIX_Very_High = 1 AND BB_Bandwidth >= train_q70 (0.1079)` (5-day): train n=50, avg +1.786%, win 86.0%; validation n=5, avg +4.030%, win 100.0%; test n=5, avg -0.168%, win 40.0%; test 1-day avg +0.478%, test 2-day avg +0.466%, test 5-day avg -0.168%.
- `VIX >= train_q50 (16.13) AND GEX_Percentile <= train_q10 (26.08)` (5-day): train n=41, avg +1.444%, win 68.3%; validation n=12, avg +1.064%, win 66.7%; test n=23, avg -0.079%, win 30.4%; test 1-day avg -0.149%, test 2-day avg -0.230%, test 5-day avg -0.079%.
- `VIX >= train_q60 (17.3) AND GEX_Percentile <= train_q10 (26.08)` (5-day): train n=38, avg +1.344%, win 68.4%; validation n=6, avg +1.200%, win 83.3%; test n=23, avg -0.079%, win 30.4%; test 1-day avg -0.149%, test 2-day avg -0.230%, test 5-day avg -0.079%.
- `BB_PercentB <= train_q30 (0.3351) AND GEX_Percentile <= train_q10 (26.08)` (5-day): train n=30, avg +1.311%, win 70.0%; validation n=5, avg +2.070%, win 100.0%; test n=22, avg -0.063%, win 31.8%; test 1-day avg -0.075%, test 2-day avg -0.184%, test 5-day avg -0.063%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 5-day feature-score gate first, then use accepted 5-day rules, option flow, and 30-minute tape as confirmation or contradiction.

Accepted patterns are conditional rules, not automatically active. A rule is active only when the audited latest row satisfies that exact condition. Do not infer activity from the research-summary list, from older rows, or from option-flow tone.

#### GEX_Percentile <= train_q20 (38.32) AND GEX_Volatility >= train_q60 (1.183e+06)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `GEX_Percentile <= train_q20 (38.32) AND GEX_Volatility >= train_q60 (1.183e+06)` (5-day): train n=73, avg +0.558%, win 65.8%; validation n=12, avg +2.332%, win 100.0%; test n=5, avg +5.624%, win 100.0%; test 1-day avg +0.954%, test 2-day avg +1.642%, test 5-day avg +5.624%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for IWM. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### GEX_Volatility >= train_q60 (1.183e+06) AND GEX_ZScore_60day <= train_q10 (-1.11)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `GEX_Volatility >= train_q60 (1.183e+06) AND GEX_ZScore_60day <= train_q10 (-1.11)` (5-day): train n=46, avg +0.809%, win 65.2%; validation n=7, avg +2.329%, win 100.0%; test n=5, avg +4.928%, win 100.0%; test 1-day avg +0.448%, test 2-day avg +1.054%, test 5-day avg +4.928%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for IWM. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### GEX_Volatility >= train_q70 (1.389e+06) AND GEX_ZScore_60day <= train_q30 (-0.06089)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `GEX_Volatility >= train_q70 (1.389e+06) AND GEX_ZScore_60day <= train_q30 (-0.06089)` (5-day): train n=75, avg +0.689%, win 62.7%; validation n=12, avg +2.771%, win 100.0%; test n=6, avg +4.853%, win 100.0%; test 1-day avg -0.067%, test 2-day avg +1.112%, test 5-day avg +4.853%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for IWM. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.

#### Prev2DaysChange <= train_q20 (-1.396) AND GEX_Volatility >= train_q60 (1.183e+06)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `Prev2DaysChange <= train_q20 (-1.396) AND GEX_Volatility >= train_q60 (1.183e+06)` (5-day): train n=54, avg +0.006%, win 55.6%; validation n=6, avg +1.505%, win 100.0%; test n=7, avg +4.416%, win 100.0%; test 1-day avg +0.754%, test 2-day avg +1.333%, test 5-day avg +4.416%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for IWM. Cross-check the other horizons for timing, confirmation, or conflict.
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
- **Historical Test Coverage:** 63/127 (49.6%)
- **Historical Test Win Rate When Covered:** 60.3%
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
