# Quantitative Trading Analysis: GDX

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided GDX market data to forecast price action over the next 5 trading days. Tomorrow's expected behavior is used for entry timing and immediate risk; the next 2 trading days are used as early confirmation. The signal strength classification must be based primarily on the selective next-5-trading-day edge.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

---

## Research Validation Summary

This prompt was generated for `GDX.US` with requested as-of date `2026-05-22`. The latest feature row available was `2026-05-21`. Candidate rules and the feature-score gate were selected primarily on `Next5DaysChange`, with `TomorrowChange` retained for timing and `Next2DaysChange` retained for early confirmation.

- Daily feature rows: 825 total, 811 primary-target labeled rows from 2023-01-04 to 2026-05-14.
- Train split: 2023-01-04 to 2025-05-15, 567 rows.
- Validation split: 2025-05-16 to 2025-11-11, 122 rows.
- Test split: 2025-11-12 to 2026-05-14, 122 rows.
- Baseline 5-day win rate: train 51.0%, validation 67.2%, test 54.9%.
- Baseline tomorrow win rate: train 50.2%, validation 59.0%, test 53.7%.
- Baseline 2-day win rate: train 52.5%, validation 59.8%, test 55.3%.
- Selective feature-score gate: threshold 0.50 on the trained probability score.
- Feature-score train performance: win 70.0%, coverage 283/567 (49.9%), avg selected 5-day return +2.263%.
- Feature-score validation performance: win 59.2%, coverage 49/122 (40.2%), avg selected 5-day return +1.865%.
- Feature-score test performance: win 58.7%, coverage 63/122 (51.6%), avg selected 5-day return +1.075%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 29. Positive call OI change 35814; positive put OI change 6466; near-term call additions 3994; near-term put additions 0.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 128.

Latest feature context for `2026-05-21`: close 85.9900, VIX 16.7600, RSI 44.94104562460254317310259960854, GEX 403961.0, GEXChange 54.99, GEX_ZScore 0.19107196237111107, dark-pool ratio 0.41.

### Accepted Patterns

- `GEX positive AND low VIX (<18)` (5-day): train n=224, avg +0.693%, win 55.8%; validation n=89, avg +2.358%, win 70.8%; test n=55, avg +1.150%, win 58.2%; test tomorrow avg -0.018%, test 2-day avg -0.045%.
- `Golden_Setup = 1` (5-day): train n=23, avg +2.838%, win 52.2%; validation n=0, avg n/a, win n/a; test n=12, avg +2.203%, win 58.3%; test tomorrow avg -0.050%, test 2-day avg +0.222%.
- `GEX positive AND GEXChange positive` (5-day): train n=162, avg +0.806%, win 56.8%; validation n=68, avg +1.497%, win 60.3%; test n=61, avg +0.674%, win 57.4%; test tomorrow avg -0.065%, test 2-day avg +0.175%.
- `Is_Potential_Swing_Up = 1` (5-day): train n=74, avg +1.141%, win 55.4%; validation n=23, avg +2.664%, win 69.6%; test n=22, avg +0.433%, win 59.1%; test tomorrow avg -0.081%, test 2-day avg -0.621%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 63/122 (51.6%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, avoid directional trading levels, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `MACD_Positive`: model weight -0.5972
- `GEX_ZScore_60day`: model weight +0.5756
- `GEX_Percentile_VeryLow`: model weight -0.5426
- `VIX`: model weight +0.4532
- `GEXChange_Positive`: model weight +0.4432
- `GEX_Negative`: model weight +0.3954
- `GEX_Falling`: model weight +0.3795
- `Price_Above_SMA50`: model weight +0.3616
- `SMA20_Above_SMA50`: model weight -0.3381
- `GEX_Above_SMA20`: model weight -0.2844
- `SVix_DarkPoolIndex`: model weight -0.2642
- `GEXChange`: model weight -0.2524

### Rejected Or Downgraded Patterns

- `Price above SMA20 and SMA50` (5-day): train n=279, avg +0.123%, win 50.2%; validation n=92, avg +1.640%, win 67.4%; test n=73, avg +0.237%, win 54.8%; test tomorrow avg -0.129%, test 2-day avg -0.124%.
- `MACD positive AND Price above SMA20/SMA50` (5-day): train n=230, avg -0.535%, win 43.5%; validation n=78, avg +1.648%, win 69.2%; test n=61, avg +0.514%, win 55.7%; test tomorrow avg -0.044%, test 2-day avg +0.099%.
- `BB_PercentB > 0.8` (5-day): train n=151, avg +0.505%, win 51.7%; validation n=51, avg +1.394%, win 68.6%; test n=43, avg -0.726%, win 48.8%; test tomorrow avg +0.063%, test 2-day avg +0.116%.
- `RSI > 70` (5-day): train n=112, avg -0.284%, win 46.4%; validation n=46, avg +2.440%, win 80.4%; test n=29, avg -3.696%, win 27.6%; test tomorrow avg -0.458%, test 2-day avg -1.140%.
- `BB_PercentB < 0.2` (5-day): train n=109, avg +1.052%, win 48.6%; validation n=13, avg +2.138%, win 53.8%; test n=13, avg +0.904%, win 53.8%; test tomorrow avg -0.482%, test 2-day avg -1.487%.
- `DarkPool ratio > 1.5` (5-day): train n=104, avg -0.200%, win 46.2%; validation n=18, avg +1.729%, win 66.7%; test n=3, avg +3.230%, win 100.0%; test tomorrow avg +0.947%, test 2-day avg +1.230%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 5-day feature-score gate first, then use accepted 5-day rules, option flow, and 30-minute tape as confirmation or contradiction.

#### GEX positive AND low VIX (<18)
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `GEX positive AND low VIX (<18)` (5-day): train n=224, avg +0.693%, win 55.8%; validation n=89, avg +2.358%, win 70.8%; test n=55, avg +1.150%, win 58.2%; test tomorrow avg -0.018%, test 2-day avg -0.045%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for GDX. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### Golden_Setup = 1
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `Golden_Setup = 1` (5-day): train n=23, avg +2.838%, win 52.2%; validation n=0, avg n/a, win n/a; test n=12, avg +2.203%, win 58.3%; test tomorrow avg -0.050%, test 2-day avg +0.222%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for GDX. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### GEX positive AND GEXChange positive
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `GEX positive AND GEXChange positive` (5-day): train n=162, avg +0.806%, win 56.8%; validation n=68, avg +1.497%, win 60.3%; test n=61, avg +0.674%, win 57.4%; test tomorrow avg -0.065%, test 2-day avg +0.175%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for GDX. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** Medium; downgrade if current option flow strongly contradicts it.

#### Is_Potential_Swing_Up = 1
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `Is_Potential_Swing_Up = 1` (5-day): train n=74, avg +1.141%, win 55.4%; validation n=23, avg +2.664%, win 69.6%; test n=22, avg +0.433%, win 59.1%; test tomorrow avg -0.081%, test 2-day avg -0.621%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for GDX. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
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
- **Historical Test Coverage:** 63/122 (51.6%)
- **Historical Test Win Rate When Covered:** 58.7%
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
