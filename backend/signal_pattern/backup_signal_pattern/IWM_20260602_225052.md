# Quantitative Trading Analysis: IWM

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided IWM market data to forecast price action over the next 5 trading days. The 1-day, 2-day, and 5-day horizons were all researched during prompt generation; the signal strength classification must be based primarily on the selected horizon because it had the highest held-out feature-score test win rate for this ticker. Coverage is reported as a reliability caveat, not as the target-selection winner.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

**Runtime Source Of Truth:** For the live forecast, the only current market state is the latest row in the `Data (Last 30 Days)` section, identified by the greatest `ObservationDate`. Research validation metadata is training context only. Never use generated-at dates, research-summary rows, or any other non-data-section context to decide today's active signals.

**Hard Audit Rule:** The latest-row audit is mandatory and must be completed before the forecast. Any forecast that claims a signal is active when the audited latest row shows the opposite is invalid. In particular, if `Is_Swing_Up = 0`, `Is_Swing_Up` is inactive; if `Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", the setup must be described as swing-down/potential-swing-down, not swing-up.

---

## Research Validation Summary

This prompt was generated for `IWM.US` with requested as-of date `2026-06-02` from a fresh SQL Server extraction for this ticker. Candidate rules and the feature-score gate were evaluated separately on `TomorrowChange`, `Next2DaysChange`, and `Next5DaysChange`. The selected primary target for this ticker is `Next5DaysChange` (next 5 trading days). This section is research metadata only; do not use it as today's market state during live or historical replay analysis.

The effective features below are stock-specific. They were discovered during this generation run by scanning the available ticker history, creating chronological train/validation/test splits for each candidate target, testing single-feature and two-feature rules, comparing target performance, and training the selective feature-score model. Do not copy accepted patterns, thresholds, or model weights from another stock prompt.

- Daily feature rows: 853 total, 847 selected-target labeled rows from 2022-12-13 to 2026-05-22.
- Train split: 2022-12-13 to 2025-05-09, 592 rows.
- Validation split: 2025-05-12 to 2025-11-11, 127 rows.
- Test split: 2025-11-12 to 2026-05-22, 128 rows.
- Selected target: `Next5DaysChange` (next 5 trading days).
- Target selection summary, ordered by held-out feature-score test win rate:
- 5-day: feature-score test win 62.7%, coverage 67/128 (52.3%), selection rank value 633.26, accepted robust patterns 6.
- 2-day: feature-score test win 57.7%, coverage 71/128 (55.5%), selection rank value 583.45, accepted robust patterns 6.
- 1-day: feature-score test win 57.7%, coverage 71/128 (55.5%), selection rank value 583.21, accepted robust patterns 6.
- Baseline selected-target win rate: train 51.7%, validation 61.4%, test 58.6%.
- Baseline tomorrow win rate: train 51.3%, validation 53.9%, test 57.0%.
- Baseline 2-day win rate: train 51.1%, validation 48.0%, test 55.5%.
- Baseline 5-day win rate: train 51.7%, validation 61.4%, test 58.6%.
- Selective feature-score gate: threshold 0.50 on the trained probability score.
- Feature-score train performance on selected target: win 69.9%, coverage 306/592 (51.7%), avg selected return +0.961%.
- Feature-score validation performance on selected target: win 75.5%, coverage 49/127 (38.6%), avg selected return +1.200%.
- Feature-score test performance on selected target: win 62.7%, coverage 67/128 (52.3%), avg selected return +1.163%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 100. Positive call OI change 65125; positive put OI change 174707; near-term call additions 24334; near-term put additions 55352.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 128.
- Broad feature audit rules tested: 298 single-feature rules and 365 two-feature combinations.

### Accepted Patterns

- `GEX_Volatility >= train_q60 (1.171e+06) AND GEX_Percentile <= train_q20 (38.43)` (5-day): train n=73, avg +0.558%, win 65.8%; validation n=13, avg +2.295%, win 100.0%; test n=5, avg +5.624%, win 100.0%; test 1-day avg +0.954%, test 2-day avg +1.642%, test 5-day avg +5.624%.
- `GEX_Volatility >= train_q70 (1.387e+06) AND GEX_ZScore_60day <= train_q30 (-0.05481)` (5-day): train n=76, avg +0.708%, win 63.2%; validation n=12, avg +2.771%, win 100.0%; test n=6, avg +4.853%, win 100.0%; test 1-day avg -0.067%, test 2-day avg +1.112%, test 5-day avg +4.853%.
- `GEX_Volatility >= train_q70 (1.387e+06) AND Prev2DaysChange <= train_q20 (-1.398)` (5-day): train n=45, avg +0.458%, win 57.8%; validation n=5, avg +1.622%, win 100.0%; test n=5, avg +4.458%, win 100.0%; test 1-day avg +0.294%, test 2-day avg +0.978%, test 5-day avg +4.458%.
- `GEX_Volatility >= train_q70 (1.387e+06) AND Prev2DaysChange <= train_q30 (-0.83)` (5-day): train n=56, avg +0.547%, win 58.9%; validation n=7, avg +2.090%, win 100.0%; test n=5, avg +4.458%, win 100.0%; test 1-day avg +0.294%, test 2-day avg +0.978%, test 5-day avg +4.458%.
- `GEX_Volatility >= train_q70 (1.387e+06) AND Prev2DaysChange <= train_q40 (-0.446)` (5-day): train n=72, avg +0.651%, win 61.1%; validation n=9, avg +2.149%, win 100.0%; test n=7, avg +4.091%, win 100.0%; test 1-day avg +0.264%, test 2-day avg +1.374%, test 5-day avg +4.091%.
- `TodayChange <= train_q20 (-1) AND GEX_StableRegime = 0` (5-day): train n=53, avg +0.542%, win 60.4%; validation n=6, avg +1.087%, win 83.3%; test n=7, avg +3.824%, win 100.0%; test 1-day avg +0.606%, test 2-day avg +1.550%, test 5-day avg +3.824%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 67/128 (52.3%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, do not force a bullish or bearish forecast, still complete the mandatory Trading Levels section, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `SVix_DarkPoolIndex`: model weight -0.5197
- `GEX_StableRegime`: model weight -0.5044
- `MACD_Line`: model weight -0.4722
- `VIX_Very_High`: model weight +0.3937
- `TodayChange`: model weight -0.3478
- `GEX_Positive`: model weight -0.3131
- `GEX_BigRise`: model weight -0.3067
- `Prev2DaysChange`: model weight -0.2658
- `GEX_Percentile_High`: model weight +0.2489
- `GEX_ZScore_VeryHigh`: model weight -0.2435
- `GEX_Negative`: model weight +0.2410
- `GEX_HighVolatility`: model weight -0.2390

### Rejected Or Downgraded Patterns

- `GEX_Trending_Up = 1 AND MACD_Line >= train_q90 (5.169)` (5-day): train n=20, avg +1.354%, win 75.0%; validation n=13, avg -0.243%, win 46.2%; test n=22, avg -0.454%, win 45.5%; test 1-day avg -0.203%, test 2-day avg -0.588%, test 5-day avg -0.454%.
- `GEX_DayChange <= train_q30 (-9.611e+04) AND GEX_ZScore_Moderate_Low = 1` (5-day): train n=23, avg +0.839%, win 69.6%; validation n=8, avg +1.047%, win 50.0%; test n=5, avg -0.626%, win 40.0%; test 1-day avg -0.664%, test 2-day avg -0.848%, test 5-day avg -0.626%.
- `SVix_DarkPoolBuyRatio <= train_q50 (0.75) AND MACD_Line >= train_q90 (5.169)` (5-day): train n=29, avg +0.803%, win 69.0%; validation n=6, avg -1.238%, win 33.3%; test n=10, avg -0.751%, win 40.0%; test 1-day avg -0.292%, test 2-day avg -0.407%, test 5-day avg -0.751%.
- `SVix_DarkPoolIndex <= train_q50 (42.75) AND MACD_Line >= train_q90 (5.169)` (5-day): train n=29, avg +0.803%, win 69.0%; validation n=6, avg -1.238%, win 33.3%; test n=10, avg -0.751%, win 40.0%; test 1-day avg -0.292%, test 2-day avg -0.407%, test 5-day avg -0.751%.
- `GEX_Volatility >= train_q60 (1.171e+06) AND MACD_Line >= train_q90 (5.169)` (5-day): train n=25, avg +0.764%, win 64.0%; validation n=11, avg -0.539%, win 45.5%; test n=5, avg -0.160%, win 40.0%; test 1-day avg -0.144%, test 2-day avg -0.354%, test 5-day avg -0.160%.
- `GEXChange >= train_q90 (105.2)` (5-day): train n=40, avg -0.717%, win 60.0%; validation n=18, avg +0.496%, win 50.0%; test n=14, avg +1.220%, win 21.4%; test 1-day avg +0.346%, test 2-day avg +0.716%, test 5-day avg +1.220%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 5-day feature-score gate first, then use accepted 5-day rules, option flow, and 30-minute tape as confirmation or contradiction.

Accepted patterns are conditional rules, not automatically active. A rule is active only when the audited latest row satisfies that exact condition. Do not infer activity from the research-summary list, from older rows, or from option-flow tone.

#### GEX_Volatility >= train_q60 (1.171e+06) AND GEX_Percentile <= train_q20 (38.43)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `GEX_Volatility >= train_q60 (1.171e+06) AND GEX_Percentile <= train_q20 (38.43)` (5-day): train n=73, avg +0.558%, win 65.8%; validation n=13, avg +2.295%, win 100.0%; test n=5, avg +5.624%, win 100.0%; test 1-day avg +0.954%, test 2-day avg +1.642%, test 5-day avg +5.624%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for IWM. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### GEX_Volatility >= train_q70 (1.387e+06) AND GEX_ZScore_60day <= train_q30 (-0.05481)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `GEX_Volatility >= train_q70 (1.387e+06) AND GEX_ZScore_60day <= train_q30 (-0.05481)` (5-day): train n=76, avg +0.708%, win 63.2%; validation n=12, avg +2.771%, win 100.0%; test n=6, avg +4.853%, win 100.0%; test 1-day avg -0.067%, test 2-day avg +1.112%, test 5-day avg +4.853%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for IWM. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### GEX_Volatility >= train_q70 (1.387e+06) AND Prev2DaysChange <= train_q20 (-1.398)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `GEX_Volatility >= train_q70 (1.387e+06) AND Prev2DaysChange <= train_q20 (-1.398)` (5-day): train n=45, avg +0.458%, win 57.8%; validation n=5, avg +1.622%, win 100.0%; test n=5, avg +4.458%, win 100.0%; test 1-day avg +0.294%, test 2-day avg +0.978%, test 5-day avg +4.458%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for IWM. Cross-check the other horizons for timing, confirmation, or conflict.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.

#### GEX_Volatility >= train_q70 (1.387e+06) AND Prev2DaysChange <= train_q30 (-0.83)
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `GEX_Volatility >= train_q70 (1.387e+06) AND Prev2DaysChange <= train_q30 (-0.83)` (5-day): train n=56, avg +0.547%, win 58.9%; validation n=7, avg +2.090%, win 100.0%; test n=5, avg +4.458%, win 100.0%; test 1-day avg +0.294%, test 2-day avg +0.978%, test 5-day avg +4.458%.
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
- **Historical Test Coverage:** 67/128 (52.3%)
- **Historical Test Win Rate When Covered:** 62.7%
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
- Prefer tighter ranges where at least two of the three sources align. If only one source exists, keep the range conservative and say which sources are missing. If no valid below-spot buy confluence exists, write "Not Recommended" for Buy the Dip. If no valid above-spot sell confluence exists, write "Not Recommended" for Sell the Rip.

Required fields:

- **Buy the Dip Range:** price range or "Not Recommended", with the supporting gamma wall, 30-minute support, and daily support evidence. The range must be strictly below the latest current price/close; a put wall above current price is overhead/reclaim context, not dip support.
- **Sell the Rip Range:** price range or "Not Recommended", with the supporting gamma wall, 30-minute resistance, and daily resistance evidence. The range must be strictly above the latest current price/close; a call wall below current price is lower/past resistance, not a rip entry.
- **Invalidation:** price or condition that would invalidate the forecast.

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
