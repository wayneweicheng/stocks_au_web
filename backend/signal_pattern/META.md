# Quantitative Trading Analysis: META

**Role:** Quantitative Analyst specializing in market microstructure, gamma exposure, option-flow positioning, and short-horizon US equity/ETF behavior.

**Task:** Analyze the provided META market data to forecast price action over the next 5 trading days. Tomorrow's expected behavior is used for entry timing and immediate risk; the next 2 trading days are used as early confirmation. The signal strength classification must be based primarily on the selective next-5-trading-day edge.

**Critical Data Rule:** Use `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, or any other future-return fields only as historical research labels. Do not use them as runtime input signals when analyzing the latest row.

---

## Research Validation Summary

This prompt was generated for `META.US` with requested as-of date `2026-05-22`. The latest feature row available was `2026-05-21`. Candidate rules and the feature-score gate were selected primarily on `Next5DaysChange`, with `TomorrowChange` retained for timing and `Next2DaysChange` retained for early confirmation.

- Daily feature rows: 822 total, 816 primary-target labeled rows from 2023-01-04 to 2026-05-14.
- Train split: 2023-01-04 to 2025-05-08, 571 rows.
- Validation split: 2025-05-09 to 2025-11-05, 122 rows.
- Test split: 2025-11-06 to 2026-05-14, 123 rows.
- Baseline 5-day win rate: train 62.2%, validation 56.6%, test 47.2%.
- Baseline tomorrow win rate: train 53.3%, validation 49.6%, test 52.0%.
- Baseline 2-day win rate: train 57.6%, validation 52.8%, test 46.3%.
- Selective feature-score gate: threshold 0.61 on the trained probability score.
- Feature-score train performance: win 79.0%, coverage 314/571 (55.0%), avg selected 5-day return +3.213%.
- Feature-score validation performance: win 60.7%, coverage 61/122 (50.0%), avg selected 5-day return +0.478%.
- Feature-score test performance: win 48.5%, coverage 68/123 (55.3%), avg selected 5-day return +0.362%.
- Large option trade rows sampled: 1000.
- Latest OI-change records sampled: 80. Positive call OI change 42297; positive put OI change 13335; near-term call additions 27694; near-term put additions 8403.
- Top current OI records sampled: 50.
- 30-minute bars sampled: 128.

Latest feature context for `2026-05-21`: close 607.3800, VIX 16.7600, RSI 30.30912086349786885291600576483, GEX 102114.0, GEXChange 144.22, GEX_ZScore 0.9436156403543599, dark-pool ratio 0.36.

### Accepted Patterns

- `RSI < 30` (5-day): train n=25, avg +3.138%, win 80.0%; validation n=10, avg +0.582%, win 60.0%; test n=21, avg +3.950%, win 76.2%; test tomorrow avg +0.462%, test 2-day avg +0.934%.
- `GEX positive AND GEXChange positive` (5-day): train n=49, avg +2.059%, win 65.3%; validation n=61, avg +0.036%, win 59.0%; test n=45, avg +0.232%, win 48.9%; test tomorrow avg +0.078%, test 2-day avg +0.201%.

### Selective Feature-Score Model

Use the feature-score model as the primary high-confidence gate. A strong directional forecast should only be issued when the latest row strongly resembles the model's selected historical cases. If the latest row does not resemble the selected cases, return `Not Determined` or "No high-confidence edge" instead of forcing a prediction.

### Mandatory No-Edge Protocol

The model is intentionally selective. Historical test coverage was 68/123 (55.3%), which means many days did not qualify for a high-confidence forecast. In the live report, you must clearly label whether today's setup is inside or outside the validated high-confidence regime.

- If the latest row strongly matches the selected feature-score regime and option/tape context does not contradict it, classify the setup as `HIGH_CONFIDENCE`.
- If the latest row only partially matches the selected regime, or important features conflict, classify the setup as `LOW_CONFIDENCE`.
- If there is no clear directional edge, classify the setup as `NO_HIGH_CONFIDENCE_EDGE`, say this plainly in the Executive Forecast, avoid directional trading levels, and set the final JSON to `"Not Determined"`.
- Never upgrade to `STRONGLY_BULLISH` or `STRONGLY_BEARISH` unless the setup is clearly inside the high-confidence regime and confirmed by market structure.

Top model features by absolute weight:

- `GEX_Trending_Up`: model weight -0.6233
- `MACD_Positive`: model weight -0.5992
- `GEX_StableRegime`: model weight -0.5819
- `GEX_Negative`: model weight -0.5501
- `GEX_Percentile_High`: model weight +0.5436
- `GEXChange_Negative`: model weight -0.4590
- `GEX_BigRise`: model weight +0.4491
- `GEX_Escaped_VeryHigh_Zscore`: model weight -0.3947
- `GEX_Rising`: model weight -0.3538
- `GEX_Percentile_VeryLow`: model weight -0.3360
- `GEX_Above_SMA20`: model weight +0.3308
- `GEX_Percentile`: model weight +0.3094

### Rejected Or Downgraded Patterns

- `Price above SMA20 and SMA50` (5-day): train n=339, avg +1.455%, win 59.9%; validation n=39, avg -0.669%, win 56.4%; test n=37, avg -2.059%, win 27.0%; test tomorrow avg -0.275%, test 2-day avg -0.677%.
- `MACD positive AND Price above SMA20/SMA50` (5-day): train n=287, avg +1.082%, win 55.4%; validation n=30, avg -0.035%, win 60.0%; test n=25, avg -3.670%, win 8.0%; test tomorrow avg -0.904%, test 2-day avg -1.787%.
- `BB_PercentB > 0.8` (5-day): train n=185, avg +1.359%, win 55.1%; validation n=20, avg -3.054%, win 35.0%; test n=19, avg +0.505%, win 63.2%; test tomorrow avg -0.331%, test 2-day avg +0.425%.
- `RSI > 70` (5-day): train n=157, avg +1.839%, win 63.1%; validation n=15, avg +1.427%, win 53.3%; test n=15, avg -3.090%, win 26.7%; test tomorrow avg -0.192%, test 2-day avg -0.974%.
- `GEX positive AND low VIX (<18)` (5-day): train n=61, avg +0.910%, win 62.3%; validation n=83, avg -0.948%, win 45.8%; test n=49, avg -0.537%, win 46.9%; test tomorrow avg +0.044%, test 2-day avg -0.368%.
- `BB_PercentB < 0.2` (5-day): train n=41, avg +3.173%, win 82.9%; validation n=14, avg -0.357%, win 42.9%; test n=31, avg -0.788%, win 35.5%; test tomorrow avg -0.234%, test 2-day avg -0.292%.

---

## Predictive Logic (Hierarchical Importance)

Use the validated 5-day feature-score gate first, then use accepted 5-day rules, option flow, and 30-minute tape as confirmation or contradiction.

#### RSI < 30
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `RSI < 30` (5-day): train n=25, avg +3.138%, win 80.0%; validation n=10, avg +0.582%, win 60.0%; test n=21, avg +3.950%, win 76.2%; test tomorrow avg +0.462%, test 2-day avg +0.934%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for META. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** High; downgrade if current option flow strongly contradicts it.

#### GEX positive AND GEXChange positive
- **Tier:** Tier 1
- **Signal:** Bullish for the next 5 trading days.
- **Historical Evidence:** `GEX positive AND GEXChange positive` (5-day): train n=49, avg +2.059%, win 65.3%; validation n=61, avg +0.036%, win 59.0%; test n=45, avg +0.232%, win 48.9%; test tomorrow avg +0.078%, test 2-day avg +0.201%.
- **Rationale:** Use this as an explainable stock-specific 5-day market-flow rule for META. Use tomorrow behavior as timing risk and 2-day behavior as early confirmation.
- **Priority:** High; downgrade if current option flow strongly contradicts it.


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
- **Historical Test Win Rate When Covered:** 48.5%
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
