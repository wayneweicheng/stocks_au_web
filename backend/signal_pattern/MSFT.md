# Quantitative Trading Analysis: MSFT

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided MSFT market data to forecast price action over the next 1 trading day. The 1-day, 2-day, and 5-day horizons were all researched during prompt generation; the signal strength classification must be based primarily on the selected horizon because it had the highest held-out feature-score test win rate for this ticker. Coverage is reported as a reliability caveat, not as the target-selection winner.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

**Runtime Source Of Truth:** For the live forecast, the only current market state is the latest row in the `Data (Last 30 Days)` section, identified by the greatest `ObservationDate`. Research validation metadata is training context only. Never use generated-at dates, research-summary rows, or any other non-data-section context to decide today's active signals.

**Hard Audit Rule:** The latest-row audit is mandatory and must be completed before the forecast. Any forecast that claims a signal is active when the audited latest row shows the opposite is invalid. In particular, if `Is_Swing_Up = 0`, `Is_Swing_Up` is inactive; if `Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", the setup must be described as swing-down/potential-swing-down, not swing-up.

---

## Research Validation Summary

This prompt was generated for `MSFT.US` with requested as-of date `2026-05-26` from a fresh SQL Server extraction for this ticker. Candidate rules and the feature-score gate were evaluated separately on `TomorrowChange`, `Next2DaysChange`, and `Next5DaysChange`. The selected primary target for this ticker is `TomorrowChange` (next 1 trading day). This section is research metadata only; do not use it as today's market state during live or historical replay analysis.

The effective features below are stock-specific. They were discovered during this generation run by scanning the available ticker history, creating chronological train/validation/test splits for each candidate target, testing single-feature and two-feature rules, comparing target performance, and training the selective feature-score model. Do not copy accepted patterns, thresholds, or model weights from another stock prompt.

- Daily feature rows: 827 total, 826 selected-target labeled rows from 2023-01-04 to 2026-05-21.
- Train split: 2023-01-04 to 2025-05-16, 578 rows.
- Validation split: 2025-05-19 to 2025-11-17, 124 rows.
- Test split: 2025-11-18 to 2026-05-21, 124 rows.
- Selected target: `TomorrowChange` (next 1 trading day).
- Target selection summary, ordered by held-out feature-score test win rate:
- 1-day: feature-score test win 52.6%, coverage 97/124 (78.2%), selection rank value 533.63, accepted robust patterns 3.
- 5-day: feature-score test win 48.1%, coverage 77/124 (62.1%), selection rank value 486.70, accepted robust patterns 6.
- 2-day: feature-score test win 42.9%, coverage 84/124 (67.7%), selection rank value 435.23, accepted robust patterns 6.
- Baseline selected-target win rate: train 54.0%, validation 53.2%, test 47.6%.
- Baseline tomorrow win rate: train 54.0%, validation 53.2%, test 47.6%.
- Baseline 2-day win rate: train 55.1%, validation 57.3%, test 41.9%.
- Baseline 5-day win rate: train 59.5%, validation 67.5%, test 45.2%.
- Selective feature-score gate: threshold 0.54 on the trained probability score.
- Feature-score train performance on selected target: win 64.6%, coverage 268/578 (46.4%), avg selected return +0.261%.
- Feature-score validation performance on selected target: win 50.0%, coverage 62/124 (50.0%), avg selected return -0.007%.
- Feature-score test performance on selected target: win 52.6%, coverage 97/124 (78.2%), avg selected return +0.032%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 70. Positive call OI change 36614; positive put OI change 12373; near-term call additions 17478; near-term put additions 8614.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 160.
- Broad feature audit rules tested: 290 single-feature rules and 41 two-feature combinations.

### Accepted Patterns

- `Is_Potential_Swing_Down = 1` (1-day): train n=21, avg +0.014%, win 61.9%; validation n=18, avg +0.083%, win 55.6%; test n=18, avg +0.209%, win 55.6%; test 1-day avg +0.209%, test 2-day avg -0.073%, test 5-day avg -0.945%.
- `PotentialSwingIndicator = "Potential swing down"` (1-day): train n=21, avg +0.014%, win 61.9%; validation n=18, avg +0.083%, win 55.6%; test n=18, avg +0.209%, win 55.6%; test 1-day avg +0.209%, test 2-day avg -0.073%, test 5-day avg -0.945%.
- `VIX >= train_q60 (17.21)` (1-day): train n=233, avg +0.287%, win 55.8%; validation n=49, avg +0.104%, win 55.1%; test n=79, avg +0.003%, win 48.1%; test 1-day avg +0.003%, test 2-day avg +0.007%, test 5-day avg +0.378%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 97/124 (78.2%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, avoid directional trading levels, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `GEX_ZScore_60day`: model weight +0.3841
- `GEX_Percentile_High`: model weight -0.2868
- `GEX_Percentile`: model weight +0.2713
- `GEX_Percentile_VeryLow`: model weight +0.2504
- `GEXChange_Positive`: model weight +0.2457
- `GEX_Falling`: model weight +0.2425
- `RSI`: model weight +0.2290
- `GEX_Rising`: model weight -0.2168
- `BB_PercentB`: model weight +0.2112
- `Stock_DarkPoolIndex`: model weight -0.2084
- `GEX_Escaped_VeryHigh_Zscore`: model weight +0.2073
- `VIX`: model weight -0.2008

### Rejected Or Downgraded Patterns

- `GEX_Negative = 1` (1-day): train n=21, avg +0.587%, win 57.1%; validation n=9, avg -0.244%, win 33.3%; test n=23, avg -0.414%, win 47.8%; test 1-day avg -0.414%, test 2-day avg -0.176%, test 5-day avg +0.147%.
- `VIX >= train_q90 (21.99)` (1-day): train n=58, avg +0.574%, win 62.1%; validation n=3, avg +0.007%, win 66.7%; test n=28, avg -0.459%, win 32.1%; test 1-day avg -0.459%, test 2-day avg -0.800%, test 5-day avg -1.153%.
- `BB_PercentB <= train_q10 (0.1623)` (1-day): train n=52, avg +0.539%, win 57.7%; validation n=8, avg +0.218%, win 62.5%; test n=30, avg -0.354%, win 43.3%; test 1-day avg -0.354%, test 2-day avg -0.390%, test 5-day avg -0.417%.
- `BB_PercentB <= train_q20 (0.3106) AND VIX >= train_q60 (17.21)` (1-day): train n=51, avg +0.539%, win 60.8%; validation n=6, avg +0.350%, win 66.7%; test n=38, avg -0.138%, win 44.7%; test 1-day avg -0.138%, test 2-day avg -0.183%, test 5-day avg -0.097%.
- `Golden_Setup = 1` (1-day): train n=31, avg +0.526%, win 67.7%; validation n=0, avg n/a, win n/a; test n=24, avg -0.038%, win 45.8%; test 1-day avg -0.038%, test 2-day avg +0.079%, test 5-day avg +0.849%.
- `VIX_Very_High = 1 AND Price_Above_SMA50 = 0` (1-day): train n=65, avg +0.422%, win 60.0%; validation n=8, avg +0.614%, win 75.0%; test n=40, avg -0.170%, win 40.0%; test 1-day avg -0.170%, test 2-day avg -0.289%, test 5-day avg -0.286%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 1-day feature-score gate first, then use accepted 1-day rules, option flow, and 30-minute tape as confirmation or contradiction.

Accepted patterns are conditional rules, not automatically active. A rule is active only when the audited latest row satisfies that exact condition. Do not infer activity from the research-summary list, from older rows, or from option-flow tone.

#### Is_Potential_Swing_Down = 1
- **Tier:** Tier 1
- **Signal:** Bullish for the next 1 trading day.
- **Historical Evidence:** `Is_Potential_Swing_Down = 1` (1-day): train n=21, avg +0.014%, win 61.9%; validation n=18, avg +0.083%, win 55.6%; test n=18, avg +0.209%, win 55.6%; test 1-day avg +0.209%, test 2-day avg -0.073%, test 5-day avg -0.945%.
- **Rationale:** Use this as an explainable stock-specific 1-day market-flow rule for MSFT. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### PotentialSwingIndicator = "Potential swing down"
- **Tier:** Tier 1
- **Signal:** Bullish for the next 1 trading day.
- **Historical Evidence:** `PotentialSwingIndicator = "Potential swing down"` (1-day): train n=21, avg +0.014%, win 61.9%; validation n=18, avg +0.083%, win 55.6%; test n=18, avg +0.209%, win 55.6%; test 1-day avg +0.209%, test 2-day avg -0.073%, test 5-day avg -0.945%.
- **Rationale:** Use this as an explainable stock-specific 1-day market-flow rule for MSFT. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### VIX >= train_q60 (17.21)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 1 trading day.
- **Historical Evidence:** `VIX >= train_q60 (17.21)` (1-day): train n=233, avg +0.287%, win 55.8%; validation n=49, avg +0.104%, win 55.1%; test n=79, avg +0.003%, win 48.1%; test 1-day avg +0.003%, test 2-day avg +0.007%, test 5-day avg +0.378%.
- **Rationale:** Use this as an explainable stock-specific 1-day market-flow rule for MSFT. Cross-check the other horizons for timing, confirmation, or conflict.
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
- **Historical Test Coverage:** 97/124 (78.2%)
- **Historical Test Win Rate When Covered:** 52.6%
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
