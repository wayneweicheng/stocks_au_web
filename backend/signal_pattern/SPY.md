# Quantitative Trading Analysis: SPY

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided SPY market data to forecast price action over the next 5 trading days. The 1-day, 2-day, and 5-day horizons were all researched during prompt generation; the signal strength classification must be based primarily on the selected horizon because it had the strongest held-out support for this ticker.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

**Runtime Source Of Truth:** For the live forecast, the only current market state is the latest row in the `Data (Last 30 Days)` section, identified by the greatest `ObservationDate`. Research validation metadata is training context only. Never use generated-at dates, research-summary rows, or any other non-data-section context to decide today's active signals.

**Hard Audit Rule:** The latest-row audit is mandatory and must be completed before the forecast. Any forecast that claims a signal is active when the audited latest row shows the opposite is invalid. In particular, if `Is_Swing_Up = 0`, `Is_Swing_Up` is inactive; if `Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", the setup must be described as swing-down/potential-swing-down, not swing-up.

---

## Research Validation Summary

This prompt was generated for `SPY.US` with requested as-of date `2026-05-22` from a fresh SQL Server extraction for this ticker. Candidate rules and the feature-score gate were evaluated separately on `TomorrowChange`, `Next2DaysChange`, and `Next5DaysChange`. The selected primary target for this ticker is `Next5DaysChange` (next 5 trading days). This section is research metadata only; do not use it as today's market state during live or historical replay analysis.

The effective features below are stock-specific. They were discovered during this generation run by scanning the available ticker history, creating chronological train/validation/test splits for each candidate target, testing single-feature and two-feature rules, comparing target performance, and training the selective feature-score model. Do not copy accepted patterns, thresholds, or model weights from another stock prompt.

- Daily feature rows: 843 total, 837 selected-target labeled rows from 2022-12-13 to 2026-05-14.
- Train split: 2022-12-13 to 2025-04-29, 585 rows.
- Validation split: 2025-04-30 to 2025-10-29, 126 rows.
- Test split: 2025-10-31 to 2026-05-14, 126 rows.
- Selected target: `Next5DaysChange` (next 5 trading days).
- Target selection summary:
- 5-day: target-selection score 62.86; feature-score test win 66.7%, coverage 75/126 (59.5%), accepted robust patterns 6.
- 2-day: target-selection score 45.25; feature-score test win 63.8%, coverage 69/126 (54.8%), accepted robust patterns 6.
- 1-day: target-selection score 40.38; feature-score test win 61.9%, coverage 63/127 (49.6%), accepted robust patterns 6.
- Baseline selected-target win rate: train 61.0%, validation 72.2%, test 57.1%.
- Baseline tomorrow win rate: train 56.3%, validation 57.9%, test 52.8%.
- Baseline 2-day win rate: train 57.5%, validation 63.5%, test 54.8%.
- Baseline 5-day win rate: train 61.0%, validation 72.2%, test 57.1%.
- Selective feature-score gate: threshold 0.51 on the trained probability score.
- Feature-score train performance on selected target: win 71.2%, coverage 413/585 (70.6%), avg selected return +0.736%.
- Feature-score validation performance on selected target: win 78.8%, coverage 66/126 (52.4%), avg selected return +1.030%.
- Feature-score test performance on selected target: win 66.7%, coverage 75/126 (59.5%), avg selected return +0.672%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 100. Positive call OI change 151828; positive put OI change 264250; near-term call additions 91641; near-term put additions 187719.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 128.
- Broad feature audit rules tested: 302 single-feature rules and 2049 two-feature combinations.

### Accepted Patterns

- `VIX_Very_High = 1 AND GEX_Volatility >= train_q50 (6.924e+05)` (5-day): train n=42, avg +0.211%, win 59.5%; validation n=9, avg +1.792%, win 100.0%; test n=9, avg +3.129%, win 100.0%; test 1-day avg +0.512%, test 2-day avg +1.183%, test 5-day avg +3.129%.
- `Negative_GEX_AND_High_VIX = 1 AND GEX_Volatility >= train_q50 (6.924e+05)` (5-day): train n=41, avg +0.119%, win 58.5%; validation n=8, avg +1.868%, win 100.0%; test n=8, avg +3.077%, win 100.0%; test 1-day avg +0.504%, test 2-day avg +1.268%, test 5-day avg +3.077%.
- `GEX_Volatility >= train_q50 (6.924e+05) AND BB_Bandwidth >= train_q60 (0.06117)` (5-day): train n=104, avg +0.866%, win 76.0%; validation n=6, avg +1.273%, win 100.0%; test n=13, avg +2.409%, win 100.0%; test 1-day avg +0.600%, test 2-day avg +1.090%, test 5-day avg +2.409%.
- `GEX_Volatility >= train_q50 (6.924e+05) AND BB_Bandwidth >= train_q70 (0.06849)` (5-day): train n=76, avg +1.057%, win 78.9%; validation n=6, avg +1.273%, win 100.0%; test n=13, avg +2.409%, win 100.0%; test 1-day avg +0.600%, test 2-day avg +1.090%, test 5-day avg +2.409%.
- `GEX_ZScore <= train_q10 (-1.138) AND GEX_Volatility >= train_q50 (6.924e+05)` (5-day): train n=54, avg +0.344%, win 63.0%; validation n=6, avg +2.415%, win 100.0%; test n=5, avg +2.226%, win 100.0%; test 1-day avg -0.158%, test 2-day avg +0.238%, test 5-day avg +2.226%.
- `GEX_Volatility >= train_q50 (6.924e+05) AND GEX_Percentile <= train_q30 (50)` (5-day): train n=122, avg +0.081%, win 56.6%; validation n=8, avg +1.462%, win 87.5%; test n=6, avg +2.392%, win 100.0%; test 1-day avg +0.113%, test 2-day avg +0.603%, test 5-day avg +2.392%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 75/126 (59.5%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, avoid directional trading levels, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `GEX_Volatility`: model weight +0.5567
- `SVix_DarkPoolIndex`: model weight -0.5091
- `Price_Above_SMA20`: model weight +0.4918
- `GEX_Above_SMA20`: model weight -0.4060
- `GEX_StableRegime`: model weight +0.4012
- `GEX_Percentile`: model weight +0.4002
- `RSI`: model weight -0.3920
- `BB_Bandwidth`: model weight +0.3406
- `GEX_ZScore`: model weight -0.3076
- `Is_Potential_Swing_Up`: model weight -0.2869
- `GEX_Percentile_Low`: model weight -0.2733
- `Pot_Swing_Up_AND_Neg_GEXChange`: model weight +0.2626

### Rejected Or Downgraded Patterns

- `VIX >= train_q80 (19.9) AND GEX_Above_SMA20 = 0` (5-day): train n=101, avg +1.036%, win 70.3%; validation n=11, avg +1.815%, win 100.0%; test n=33, avg -0.065%, win 42.4%; test 1-day avg -0.044%, test 2-day avg -0.090%, test 5-day avg -0.065%.
- `VIX >= train_q80 (19.9) AND GEX_ZScore <= train_q30 (0)` (5-day): train n=101, avg +1.036%, win 70.3%; validation n=11, avg +1.815%, win 100.0%; test n=33, avg -0.065%, win 42.4%; test 1-day avg -0.044%, test 2-day avg -0.090%, test 5-day avg -0.065%.
- `VIX >= train_q80 (19.9) AND GEX_ZScore <= train_q40 (0)` (5-day): train n=101, avg +1.036%, win 70.3%; validation n=11, avg +1.815%, win 100.0%; test n=33, avg -0.065%, win 42.4%; test 1-day avg -0.044%, test 2-day avg -0.090%, test 5-day avg -0.065%.
- `VIX >= train_q80 (19.9) AND GEX_ZScore <= train_q50 (0)` (5-day): train n=101, avg +1.036%, win 70.3%; validation n=11, avg +1.815%, win 100.0%; test n=33, avg -0.065%, win 42.4%; test 1-day avg -0.044%, test 2-day avg -0.090%, test 5-day avg -0.065%.
- `GEX_Above_SMA20 = 0 AND Pot_Swing_Up_AND_Neg_GEXChange = 1` (5-day): train n=27, avg +1.009%, win 70.4%; validation n=5, avg +0.964%, win 100.0%; test n=17, avg -0.146%, win 47.1%; test 1-day avg +0.126%, test 2-day avg +0.120%, test 5-day avg -0.146%.
- `GEX_ZScore <= train_q30 (0) AND Pot_Swing_Up_AND_Neg_GEXChange = 1` (5-day): train n=27, avg +1.009%, win 70.4%; validation n=5, avg +0.964%, win 100.0%; test n=17, avg -0.146%, win 47.1%; test 1-day avg +0.126%, test 2-day avg +0.120%, test 5-day avg -0.146%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 5-day feature-score gate first, then use accepted 5-day rules, option flow, and 30-minute tape as confirmation or contradiction.

Accepted patterns are conditional rules, not automatically active. A rule is active only when the audited latest row satisfies that exact condition. Do not infer activity from the research-summary list, from older rows, or from option-flow tone.

#### VIX_Very_High = 1 AND GEX_Volatility >= train_q50 (6.924e+05)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `VIX_Very_High = 1 AND GEX_Volatility >= train_q50 (6.924e+05)` (5-day): train n=42, avg +0.211%, win 59.5%; validation n=9, avg +1.792%, win 100.0%; test n=9, avg +3.129%, win 100.0%; test 1-day avg +0.512%, test 2-day avg +1.183%, test 5-day avg +3.129%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for SPY. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### Negative_GEX_AND_High_VIX = 1 AND GEX_Volatility >= train_q50 (6.924e+05)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `Negative_GEX_AND_High_VIX = 1 AND GEX_Volatility >= train_q50 (6.924e+05)` (5-day): train n=41, avg +0.119%, win 58.5%; validation n=8, avg +1.868%, win 100.0%; test n=8, avg +3.077%, win 100.0%; test 1-day avg +0.504%, test 2-day avg +1.268%, test 5-day avg +3.077%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for SPY. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### GEX_Volatility >= train_q50 (6.924e+05) AND BB_Bandwidth >= train_q60 (0.06117)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `GEX_Volatility >= train_q50 (6.924e+05) AND BB_Bandwidth >= train_q60 (0.06117)` (5-day): train n=104, avg +0.866%, win 76.0%; validation n=6, avg +1.273%, win 100.0%; test n=13, avg +2.409%, win 100.0%; test 1-day avg +0.600%, test 2-day avg +1.090%, test 5-day avg +2.409%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for SPY. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.

#### GEX_Volatility >= train_q50 (6.924e+05) AND BB_Bandwidth >= train_q70 (0.06849)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `GEX_Volatility >= train_q50 (6.924e+05) AND BB_Bandwidth >= train_q70 (0.06849)` (5-day): train n=76, avg +1.057%, win 78.9%; validation n=6, avg +1.273%, win 100.0%; test n=13, avg +2.409%, win 100.0%; test 1-day avg +0.600%, test 2-day avg +1.090%, test 5-day avg +2.409%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for SPY. Cross-check the other horizons for timing, confirmation, or conflict.
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
- **Historical Test Coverage:** 75/126 (59.5%)
- **Historical Test Win Rate When Covered:** 66.7%
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
