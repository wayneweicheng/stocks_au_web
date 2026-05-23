# Quantitative Trading Analysis: AAPL

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided AAPL market data to forecast price action over the next 5 trading days. Tomorrow's expected behavior is used for entry timing and immediate risk; the next 2 trading days are used as early confirmation. The signal strength classification must be based primarily on the selective next-5-trading-day edge.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

---

## Research Validation Summary

This prompt was generated for `AAPL.US` with requested as-of date `2026-05-22`. The latest feature row available was `2026-05-21`. Candidate rules and the feature-score gate were selected primarily on `Next5DaysChange`, with `TomorrowChange` retained for timing and `Next2DaysChange` retained for early confirmation.

- Daily feature rows: 824 total, 819 primary-target labeled rows from 2023-01-04 to 2026-05-14.
- Train split: 2023-01-04 to 2025-05-07, 573 rows.
- Validation split: 2025-05-08 to 2025-11-05, 123 rows.
- Test split: 2025-11-06 to 2026-05-14, 123 rows.
- Baseline 5-day win rate: train 58.3%, validation 63.4%, test 52.0%.
- Baseline tomorrow win rate: train 55.4%, validation 54.5%, test 51.6%.
- Baseline 2-day win rate: train 55.5%, validation 54.5%, test 53.2%.
- Selective feature-score gate: threshold 0.56 on the trained probability score.
- Feature-score train performance: win 73.6%, coverage 345/573 (60.2%), avg selected 5-day return +1.563%.
- Feature-score validation performance: win 62.9%, coverage 62/123 (50.4%), avg selected 5-day return +1.107%.
- Feature-score test performance: win 50.0%, coverage 68/123 (55.3%), avg selected 5-day return +0.081%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 100. Positive call OI change 98954; positive put OI change 71905; near-term call additions 39567; near-term put additions 24748.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 128.

Latest feature context for `2026-05-21`: close 304.9900, VIX 16.7600, RSI 87.28230000113187529989926309831, GEX 1322210.0, GEXChange 16.88, GEX_ZScore 1.2416869677431808, dark-pool ratio 0.96.

### Accepted Patterns

- `BB_PercentB > 0.8` (5-day): train n=170, avg +0.428%, win 60.0%; validation n=29, avg +0.678%, win 65.5%; test n=34, avg +0.484%, win 61.8%; test tomorrow avg -0.096%, test 2-day avg +0.290%.
- `Golden_Setup = 1` (5-day): train n=28, avg +1.322%, win 64.3%; validation n=5, avg +6.448%, win 100.0%; test n=11, avg +1.002%, win 63.6%; test tomorrow avg +0.314%, test 2-day avg +0.675%.
- `MACD positive AND Price above SMA20/SMA50` (5-day): train n=237, avg +0.831%, win 65.8%; validation n=57, avg +0.539%, win 57.9%; test n=46, avg +0.355%, win 52.2%; test tomorrow avg +0.050%, test 2-day avg +0.110%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 68/123 (55.3%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, avoid directional trading levels, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `GEX_Percentile`: model weight +0.6744
- `SVix_DarkPoolIndex`: model weight -0.6490
- `SVix_DarkPoolBuyRatio`: model weight +0.5546
- `Price_Above_SMA50`: model weight +0.5038
- `GEX_Turned_Positive`: model weight -0.3997
- `MACD_Line`: model weight -0.3984
- `Is_Swing_Up`: model weight +0.3747
- `VIX`: model weight +0.3246
- `GEX_Above_SMA10`: model weight +0.3056
- `Stock_DarkPoolBuySellRatio`: model weight -0.3051
- `GEX_Rising`: model weight -0.2926
- `BB_Breakout_Upper`: model weight -0.2925

### Rejected Or Downgraded Patterns

- `Price above SMA20 and SMA50` (5-day): train n=295, avg +0.922%, win 66.1%; validation n=63, avg +0.733%, win 60.3%; test n=50, avg +0.282%, win 52.0%; test tomorrow avg +0.106%, test 2-day avg +0.199%.
- `RSI > 70` (5-day): train n=132, avg +0.451%, win 63.6%; validation n=26, avg -0.075%, win 50.0%; test n=16, avg -1.125%, win 37.5%; test tomorrow avg -0.371%, test 2-day avg -0.669%.
- `RSI < 30` (5-day): train n=73, avg +0.837%, win 63.0%; validation n=5, avg +1.874%, win 60.0%; test n=21, avg -0.173%, win 38.1%; test tomorrow avg -0.043%, test 2-day avg -0.094%.
- `GEX positive AND low VIX (<18)` (5-day): train n=63, avg +0.940%, win 66.7%; validation n=88, avg +0.950%, win 59.1%; test n=57, avg -0.028%, win 42.1%; test tomorrow avg +0.056%, test 2-day avg -0.108%.
- `GEX positive AND GEXChange positive` (5-day): train n=60, avg -0.221%, win 61.7%; validation n=70, avg +1.369%, win 67.1%; test n=64, avg +0.765%, win 57.8%; test tomorrow avg +0.229%, test 2-day avg +0.330%.
- `BB_PercentB < 0.2` (5-day): train n=58, avg +1.116%, win 65.5%; validation n=5, avg +5.610%, win 100.0%; test n=24, avg -0.213%, win 37.5%; test tomorrow avg -0.127%, test 2-day avg +0.008%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 5-day feature-score gate first, then use accepted 5-day rules, option flow, and 30-minute tape as confirmation or contradiction.

#### BB_PercentB > 0.8
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `BB_PercentB > 0.8` (5-day): train n=170, avg +0.428%, win 60.0%; validation n=29, avg +0.678%, win 65.5%; test n=34, avg +0.484%, win 61.8%; test tomorrow avg -0.096%, test 2-day avg +0.290%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for AAPL. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### Golden_Setup = 1
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `Golden_Setup = 1` (5-day): train n=28, avg +1.322%, win 64.3%; validation n=5, avg +6.448%, win 100.0%; test n=11, avg +1.002%, win 63.6%; test tomorrow avg +0.314%, test 2-day avg +0.675%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for AAPL. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### MACD positive AND Price above SMA20/SMA50
- **Tier:** Tier 2
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `MACD positive AND Price above SMA20/SMA50` (5-day): train n=237, avg +0.831%, win 65.8%; validation n=57, avg +0.539%, win 57.9%; test n=46, avg +0.355%, win 52.2%; test tomorrow avg +0.050%, test 2-day avg +0.110%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for AAPL. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
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
- **Historical Test Coverage:** 68/123 (55.3%)
- **Historical Test Win Rate When Covered:** 50.0%
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
