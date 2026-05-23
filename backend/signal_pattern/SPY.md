# Quantitative Trading Analysis: SPY

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided SPY market data to forecast price action over the next 5 trading days. Tomorrow's expected behavior is used for entry timing and immediate risk; the next 2 trading days are used as early confirmation. The signal strength classification must be based primarily on the selective next-5-trading-day edge.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

---

## Research Validation Summary

This prompt was generated for `SPY.US` with requested as-of date `2026-05-22`. The latest feature row available was `2026-05-21`. Candidate rules and the feature-score gate were selected primarily on `Next5DaysChange`, with `TomorrowChange` retained for timing and `Next2DaysChange` retained for early confirmation.

- Daily feature rows: 843 total, 837 primary-target labeled rows from 2022-12-13 to 2026-05-14.
- Train split: 2022-12-13 to 2025-04-29, 585 rows.
- Validation split: 2025-04-30 to 2025-10-29, 126 rows.
- Test split: 2025-10-31 to 2026-05-14, 126 rows.
- Baseline 5-day win rate: train 61.0%, validation 72.2%, test 57.1%.
- Baseline tomorrow win rate: train 56.3%, validation 57.9%, test 52.8%.
- Baseline 2-day win rate: train 57.5%, validation 63.5%, test 54.8%.
- Selective feature-score gate: threshold 0.51 on the trained probability score.
- Feature-score train performance: win 71.2%, coverage 413/585 (70.6%), avg selected 5-day return +0.736%.
- Feature-score validation performance: win 78.8%, coverage 66/126 (52.4%), avg selected 5-day return +1.030%.
- Feature-score test performance: win 66.7%, coverage 75/126 (59.5%), avg selected 5-day return +0.672%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 100. Positive call OI change 151828; positive put OI change 264250; near-term call additions 91641; near-term put additions 187719.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 128.

Latest feature context for `2026-05-21`: close None, VIX 16.7600, RSI 35.29409480968052106371331660470, GEX 402953.0, GEXChange 414.31, GEX_ZScore 1.1418349584916767, dark-pool ratio 1.43.

### Accepted Patterns

- `Is_Potential_Swing_Down = 1` (5-day): train n=92, avg +0.375%, win 60.9%; validation n=38, avg +0.376%, win 63.2%; test n=23, avg +0.500%, win 65.2%; test tomorrow avg -0.004%, test 2-day avg +0.027%.
- `Price above SMA20 and SMA50` (5-day): train n=370, avg +0.228%, win 61.6%; validation n=115, avg +0.657%, win 69.6%; test n=72, avg +0.274%, win 59.7%; test tomorrow avg -0.016%, test 2-day avg +0.001%.
- `GEX_Turned_Positive = 1` (5-day): train n=44, avg +0.290%, win 70.5%; validation n=18, avg +0.887%, win 72.2%; test n=12, avg +0.589%, win 58.3%; test tomorrow avg +0.347%, test 2-day avg +0.529%.

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

- `MACD positive AND Price above SMA20/SMA50` (5-day): train n=325, avg +0.209%, win 61.2%; validation n=114, avg +0.653%, win 69.3%; test n=59, avg +0.098%, win 55.9%; test tomorrow avg -0.053%, test 2-day avg -0.088%.
- `BB_PercentB > 0.8` (5-day): train n=199, avg +0.206%, win 56.8%; validation n=68, avg +0.099%, win 52.9%; test n=28, avg +0.514%, win 53.6%; test tomorrow avg +0.061%, test 2-day avg +0.217%.
- `GEX positive AND low VIX (<18)` (5-day): train n=175, avg +0.087%, win 60.6%; validation n=46, avg +0.191%, win 58.7%; test n=33, avg -0.283%, win 51.5%; test tomorrow avg -0.000%, test 2-day avg -0.186%.
- `RSI > 70` (5-day): train n=117, avg -0.013%, win 54.7%; validation n=30, avg +0.458%, win 60.0%; test n=26, avg +0.481%, win 65.4%; test tomorrow avg +0.048%, test 2-day avg +0.078%.
- `DarkPool ratio > 1.5` (5-day): train n=116, avg +0.104%, win 53.4%; validation n=52, avg +0.503%, win 63.5%; test n=21, avg -0.682%, win 28.6%; test tomorrow avg -0.098%, test 2-day avg -0.385%.
- `BB_PercentB < 0.2` (5-day): train n=82, avg +0.569%, win 62.2%; validation n=1, avg +1.740%, win 100.0%; test n=27, avg +0.200%, win 48.1%; test tomorrow avg +0.092%, test 2-day avg +0.201%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 5-day feature-score gate first, then use accepted 5-day rules, option flow, and 30-minute tape as confirmation or contradiction.

#### Is_Potential_Swing_Down = 1
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `Is_Potential_Swing_Down = 1` (5-day): train n=92, avg +0.375%, win 60.9%; validation n=38, avg +0.376%, win 63.2%; test n=23, avg +0.500%, win 65.2%; test tomorrow avg -0.004%, test 2-day avg +0.027%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for SPY. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### Price above SMA20 and SMA50
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `Price above SMA20 and SMA50` (5-day): train n=370, avg +0.228%, win 61.6%; validation n=115, avg +0.657%, win 69.6%; test n=72, avg +0.274%, win 59.7%; test tomorrow avg -0.016%, test 2-day avg +0.001%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for SPY. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### GEX_Turned_Positive = 1
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `GEX_Turned_Positive = 1` (5-day): train n=44, avg +0.290%, win 70.5%; validation n=18, avg +0.887%, win 72.2%; test n=12, avg +0.589%, win 58.3%; test tomorrow avg +0.347%, test 2-day avg +0.529%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for SPY. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.


### Context Rules

#### RSI And Trend State
- **Signal:** Context only unless accepted above as a validated rule.
- **Rationale:** Overbought or oversold signals can behave differently by regime. Do not short only because RSI is high; do not buy only because RSI is low unless validated triggers and option structure agree.

#### Option Flow Confirmation
- **Signal:** Confirms, downgrades, or invalidates daily-feature rules.
- **Rationale:** Large near-term OI changes and top OI walls reveal dealer hedging zones and resistance/support levels.
- **Priority:** Near-term 0-7 DTE walls are highest priority, followed by 8-14 DTE, 15-30 DTE, then 30-90 DTE.

---

## Live Analysis Procedure

1. Read the latest row in the Last 30 Days data section by greatest `ObservationDate`.
2. Ignore all future-return columns in the live row.
3. Identify active accepted patterns, rejected-pattern warnings, and context rules.
4. Decide the confidence-gate status: `HIGH_CONFIDENCE`, `LOW_CONFIDENCE`, or `NO_HIGH_CONFIDENCE_EDGE`.
5. Review latest option trades, OI changes, top OI walls, and 30-minute bars.
6. Resolve conflicts in this order: selective 5-day feature-score gate, accepted Tier 1 5-day rules, near-term option walls close to spot, accepted Tier 2 rules, 30-minute tape, context rules.
7. Produce a 5-day forecast only if the confidence gate is active; otherwise state that there is no high-confidence edge.

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

### Executive Forecast

Provide one decisive paragraph with the confidence-gate status first. If status is `NO_HIGH_CONFIDENCE_EDGE`, say plainly that the model does not have enough validated edge today and do not force a bullish or bearish call. If status is `HIGH_CONFIDENCE` or `LOW_CONFIDENCE`, provide the expected next-5-trading-day direction, expected magnitude, volatility expectation, tomorrow timing risk, and main reason.

### Confidence Gate

Report:

- **Status:** `HIGH_CONFIDENCE`, `LOW_CONFIDENCE`, or `NO_HIGH_CONFIDENCE_EDGE`
- **Historical Test Coverage:** 75/126 (59.5%)
- **Historical Test Win Rate When Covered:** 66.7%
- **Why Covered Or Not Covered Today:** concise explanation using the latest row, accepted patterns, option flow, OI walls, and 30-minute tape.

### Active Signal Checklist

List active and inactive accepted Tier 1/Tier 2 5-day signals from the latest row.

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

Place this JSON at the very end of the markdown response. The classification must represent the expected directional edge over the next 5 trading days, not just tomorrow:

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
