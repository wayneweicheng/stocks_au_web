# PRD — SPX GEX Signal Trading Assistant

**Version:** 1.0  
**Date:** 2026-08-10  
**Primary execution instrument:** QQQ  
**Price-path proxy:** NQMain 30-minute futures data  
**Notification channel:** Pushover  
**Execution mode:** Manual execution / automated signal generation  
**Primary timezone:** `America/New_York`

---

## 1. Product Summary

Build an automated trading-signal assistant that uses daily SPXW options GEX data to classify actionable signals, generate a concrete QQQ trade plan, send that plan through Pushover, and maintain an independent shadow account for forward testing.

The MVP does **not** submit broker orders automatically.

Core flow:

```text
SPXW Raw GEX Data
        ↓
Signal Calculation
        ↓
Strong / Reliable Yellow
Reversal / Normal Green
        ↓
Portfolio State Machine
        ↓
Trade Plan
        ↓
Pushover Notification
        ↓
User manually executes QQQ trade
        ↓
Shadow Account tracks theoretical trade
        ↓
Performance / Forward-test database
```

Primary goals:

1. Generate signals automatically.
2. Ensure all production features are causal and use no future information.
3. Apply portfolio-state and signal-conflict rules consistently.
4. Produce explicit Entry / TP / SL / Time Exit instructions.
5. Send actionable notifications through Pushover.
6. Maintain a theoretical shadow account independent of actual execution.
7. Accumulate at least 30–50 forward trades before considering IBKR semi-automation.

---

## 2. Product Goals

### G1 — Daily Signal Classification

The system must classify each completed observation date into one of:

```text
NO_SIGNAL
STRONG_YELLOW
RELIABLE_YELLOW
WEAK_YELLOW
MIXED_YELLOW
REVERSAL_GREEN
NORMAL_GREEN
```

Only these are tradable in v1:

```text
STRONG_YELLOW
RELIABLE_YELLOW
REVERSAL_GREEN
NORMAL_GREEN
```

### G2 — Correct Trading Time

All immediate D1 signals become actionable at:

```text
03:30 America/New_York
```

Do **not** use a fixed UTC offset. The system must correctly handle EDT/EST and US daylight-saving transitions.

### G3 — Pushover Notification

Every actionable or skipped signal should produce a structured notification containing, where applicable:

- Signal type
- Observation date
- Action date
- Action time
- Instrument
- Side
- Reference price
- Entry rule
- TP
- SL
- Time exit
- Signal metrics
- Current portfolio state
- Whether the trade is allowed
- Skip reason
- Shadow NAV
- Suggested QQQ quantity
- Strategy version

### G4 — Portfolio State

At most one directional position may be active at any time.

Baseline conflict rule:

```text
EXISTING_POSITION_PRIORITY
```

Examples:

```text
Existing Green Long + new Yellow
→ ignore new Yellow

Existing Yellow Short + new Green
→ ignore new Green

Existing Green + new Green
→ ignore new Green

Existing Yellow + new Yellow
→ ignore new Yellow
```

No stacking, no automatic leverage increase, no automatic extension of the existing Green D5 exit.

### G5 — Shadow Account

Maintain a theoretical account independent of the user's actual manual execution.

Default:

```yaml
shadow_account:
  initial_capital: 100000
  exposure_factor: 1.0
```

Position notional:

```text
current_shadow_NAV × exposure_factor
```

`exposure_factor` must be configurable, e.g.:

```text
0.50
0.75
1.00
```

---

## 3. Non-Goals — Version 1

Do not implement:

- Automatic IBKR order submission
- Automatic live-account position changes
- TQQQ execution
- Options execution
- 0DTE trading
- ML-based optimization
- Automatic threshold changes
- Dynamic TP/SL optimization
- Automatic leverage changes
- Signal stacking
- Automatic Green clock refresh
- Long/short hedged overlap

These may be considered in future phases.

---

## 4. Input Data

### 4.1 Signal Summary Data

Expected columns include:

```text
ObservationDate
ObservationDateUS_EST_0500
Ticker
BC_GEXDeltaPerc
Signal
SignalColor
Close
VWAP
CloseChangePct
PutCallRatio
PCRChangePct
TotalAbsGEXDelta
DailyBCAbsGEXDelta
DailyBPAbsGEXDelta
DailySCAbsGEXDelta
DailySPAbsGEXDelta
```

Mapping:

```text
BULLISH → GREEN
BEARISH → YELLOW
NULL    → NO_SIGNAL
```

### 4.2 Raw GEX Data

Expected schema:

```text
ObservationDate
ASXCode
GEXDelta
CapitalType
Close
VWAP
NoOfOption
GEX
```

`CapitalType`:

```text
BC = Buy Call
SC = Sell Call
BP = Buy Put
SP = Sell Put
```

`GEXDelta` definition:

```text
Current ObservationDate GEX
minus
Previous US trading day's GEX
```

### 4.3 NQ Futures Data

Primary historical price source:

```text
NQMain 30M
```

Used for:

- Reference prices
- MFE / MAE
- TP/SL first-touch simulation
- Green prior 5-day return
- QQQ percentage-move proxy
- Historical shadow P&L

Optional secondary source:

```text
ESMain 30M
```

---

## 5. QQQ Proxy Assumption

For v1 research and shadow simulation:

```text
QQQ percentage movement ≈ NQMain percentage movement
```

This assumption is permitted for the 03:30–04:00 New York interval where QQQ historical 30-minute bars may be unavailable but QQQ can still be traded.

Do **not** assume:

```text
QQQ price = NQ price
```

Only percentage movement is proxied.

Every shadow trade must store:

```text
price_source = NQ_PROXY
```

Actual live notification levels should use the available current QQQ price when practical.

---

## 6. US Trading Calendar

Use a US equity cash-market calendar.

Recommended libraries:

```python
exchange_calendars
```

or:

```python
pandas_market_calendars
```

Use `XNYS` or an equivalent US equity calendar.

Correctly handle:

- Weekends
- US market holidays
- Early closes
- DST changes
- Special closures

Definitions:

```text
D0 = ObservationDate
D1 = next US cash trading day
D2 = second US cash trading day after D0
D3 = third
D4 = fourth
D5 = fifth
```

Do not define these using calendar days or futures bars.

---

## 7. Signal Timing

If:

```text
ObservationDate = D0
```

then the first actionable time is:

```text
D1 03:30 America/New_York
```

Any price action before D1 03:30 must not be included in the signal's actionable performance.

---

# 8. Yellow Signal Classification

A Yellow signal is:

```text
Signal = BEARISH
```

Derived features are calculated from raw GEX data.

## 8.1 SP Delta Share

```text
SPDeltaShare =
abs(SP_GEXDelta)
/
(
abs(BC_GEXDelta)
+ abs(BP_GEXDelta)
+ abs(SC_GEXDelta)
+ abs(SP_GEXDelta)
)
```

## 8.2 Causal Rolling Thresholds

Production and forward-test logic must use only information available as of the observation date.

Default lookback:

```text
60 prior US trading days
```

### SC GEX Threshold

Compute:

```text
SC_GEX_rolling_median_60
```

using only dates strictly earlier than the current observation date.

Define:

```text
SC_LOW =
current_SC_GEX <= prior_60_day_SC_GEX_median
```

### SP Share Threshold

Compute the 75th percentile of prior 60-day `SPDeltaShare`.

Define:

```text
SP_HIGH =
current_SPDeltaShare > prior_60_day_SPDeltaShare_P75
```

Store:

```text
SC_GEX_current
SC_GEX_threshold
SC_GEX_percentile
SP_delta_share_current
SP_delta_share_threshold
SP_delta_share_percentile
```

## 8.3 Yellow Classification Logic

### Strong Yellow

```text
YELLOW
AND SC_LOW = TRUE
AND SP_HIGH = TRUE
```

→

```text
STRONG_YELLOW
```

### Reliable Yellow

```text
YELLOW
AND SC_LOW = TRUE
AND SP_HIGH = FALSE
```

→

```text
RELIABLE_YELLOW
```

### Mixed Yellow

```text
YELLOW
AND SC_LOW = FALSE
AND SP_HIGH = TRUE
```

→

```text
MIXED_YELLOW
```

No trade in v1.

### Weak Yellow

```text
YELLOW
AND SC_LOW = FALSE
AND SP_HIGH = FALSE
```

→

```text
WEAK_YELLOW
```

No trade in v1.

---

# 9. Yellow Trading Rules

## 9.1 Strong Yellow

Entry:

```text
D1 03:30 New York
SHORT QQQ
```

Historical shadow proxy:

```text
Short using NQ D1 03:30 Open
```

Target:

```text
-0.80%
```

Stop:

```text
+1.00%
```

For actual QQQ:

```text
TP = Entry × 0.992
SL = Entry × 1.010
```

## 9.2 Reliable Yellow

Entry:

```text
D1 03:30 New York
SHORT QQQ
```

Target:

```text
-0.40%
```

Stop:

```text
+0.80%
```

For actual QQQ:

```text
TP = Entry × 0.996
SL = Entry × 1.008
```

## 9.3 Yellow First-Touch Rules

For a short position on each 30-minute bar:

```text
TP hit if Low <= TP
SL hit if High >= SL
```

Gap-aware fills:

```text
If the bar opens beyond TP or SL,
fill at the bar Open.
```

If both TP and SL are touched in the same 30-minute bar:

```text
Use conservative assumption:
SL first
```

Store:

```text
ambiguous_bar = true
```

---

# 10. Green Signal Definition

A Green signal is:

```text
Signal = BULLISH
```

Do **not** treat Green as an immediate D1 long signal.

Interpret Green as a multi-day mean-reversion / rebound regime signal.

## 10.1 Green Prior 5-Day Return

For each Green observation date, compute:

```text
Prior5DReturn =
NQ_Close_D0 / NQ_Close_D_minus_5 - 1
```

using the prior five US cash trading days.

This calculation must be fully causal.

## 10.2 Reversal Green

Definition:

```text
GREEN
AND Prior5DReturn <= 0
```

Classification:

```text
REVERSAL_GREEN
```

## 10.3 Normal Green

Definition:

```text
GREEN
AND Prior5DReturn > 0
```

Classification:

```text
NORMAL_GREEN
```

---

# 11. Reversal Green Trading Rule

Reversal Green uses a two-stage entry.

## 11.1 D1 03:30 Reference

At:

```text
D1 03:30 New York
```

record:

```text
ReferencePrice
```

Create a buy-dip order:

```text
DipEntry = ReferencePrice × 0.99
```

Equivalent:

```text
-1.00% below D1 03:30 reference
```

## 11.2 Dip Order Validity

The dip order remains valid from:

```text
D1 03:30
```

until:

```text
D3 03:30
```

## 11.3 Scenario A — Dip Filled

If the price path touches the dip level before D3 03:30:

```text
LONG position becomes active
```

Gap handling:

```text
If bar opens below the limit:
fill at bar Open
otherwise:
fill at limit
```

Exit:

```text
D5 cash close
```

No fixed TP in the v1 baseline.

## 11.4 Scenario B — Dip Not Filled

If still not filled by:

```text
D3 03:30
```

then:

```text
BUY QQQ at D3 03:30
```

and hold until:

```text
D5 cash close
```

---

# 12. Normal Green Trading Rule

Entry:

```text
D3 03:30 New York
BUY QQQ
```

Primary target:

```text
+2.50%
```

Time exit:

```text
D5 cash close
```

Whichever occurs first.

```text
TP = Entry × 1.025
```

---

# 13. Portfolio State Machine

Required states:

```text
FLAT
PENDING_GREEN_DIP
LONG_GREEN
SHORT_YELLOW
```

## 13.1 FLAT

May accept a new tradable signal.

## 13.2 PENDING_GREEN_DIP

A Reversal Green dip order is active.

New Green:

```text
IGNORE
```

New Yellow:

```text
IGNORE
```

Record the skipped signal and skip reason.

## 13.3 LONG_GREEN

Any new Green:

```text
IGNORE
```

Any new Yellow:

```text
IGNORE
```

Do not:

```text
add position
refresh D5
increase leverage
```

## 13.4 SHORT_YELLOW

Any new Yellow:

```text
IGNORE
```

Any new Green:

```text
IGNORE
```

---

# 14. Same-Timestamp Conflict

If the account is `FLAT` and multiple actionable signals are generated for the same actionable timestamp, priority is:

```text
STRONG_YELLOW
>
RELIABLE_YELLOW
>
REVERSAL_GREEN
>
NORMAL_GREEN
```

Record all raw signals even if only one becomes tradable.

---

# 15. Position Sizing

Config:

```yaml
portfolio:
  exposure_factor: 1.0
  max_positions: 1
  conflict_policy: EXISTING_POSITION_PRIORITY
```

Notional:

```text
Notional = CurrentShadowNAV × ExposureFactor
```

Suggested QQQ quantity:

```text
floor(Notional / QQQPrice)
```

Notification should ideally show:

```text
Configured exposure quantity
50% exposure quantity
100% exposure quantity
```

---

# 16. Pushover Integration

Required environment variables:

```text
PUSHOVER_USER_KEY
PUSHOVER_API_TOKEN
```

Do not store credentials in:

- Source code
- Git
- Logs
- Plaintext database fields

---

# 17. Notification Types

Support at least:

```text
SIGNAL_READY
TRADE_SKIPPED
DIP_ORDER_UPDATE
D3_FALLBACK
TP_HIT
SL_HIT
TIME_EXIT
DATA_ERROR
SYSTEM_ERROR
DAILY_NO_SIGNAL
SHADOW_SUMMARY
```

---

# 18. Pushover Templates

## 18.1 Strong Yellow

Title:

```text
🔴 STRONG YELLOW — SHORT QQQ
```

Message example:

```text
Signal: STRONG_YELLOW
Observation Date: 2026-08-10
Action Date: 2026-08-11

Action Time:
03:30 New York

Action:
SHORT QQQ

QQQ Reference:
$xxx.xx

Target:
-0.80%
$xxx.xx

Stop:
+1.00%
$xxx.xx

SC GEX:
xx,xxx

SC 60D Percentile:
xx%

SP Delta Share:
x.xx%

SP 60D Percentile:
xx%

Shadow NAV:
$xxx,xxx

Exposure:
100%

Suggested Quantity:
xxx QQQ shares

Portfolio State:
FLAT

Trade Allowed:
YES
```

## 18.2 Reliable Yellow

Title:

```text
🟡 RELIABLE YELLOW — SHORT QQQ
```

Include:

```text
TP -0.40%
SL +0.80%
```

plus all classification metrics.

## 18.3 Reversal Green Initial

Title:

```text
🟢 REVERSAL GREEN — BUY DIP
```

Message:

```text
Signal: REVERSAL_GREEN

D1 Reference:
QQQ $xxx.xx

Buy Dip:
-1.00%

Limit Price:
$xxx.xx

Order Valid Until:
D3 03:30 New York

If not filled:
BUY at D3 03:30

Exit:
D5 cash close

Prior 5D NQ Return:
-x.xx%

Portfolio State:
FLAT
```

## 18.4 D3 Fallback

Title:

```text
🟢 REVERSAL GREEN — D3 FALLBACK BUY
```

Message:

```text
Dip order was NOT filled.

Action:
BUY QQQ NOW

Time:
D3 03:30 New York

Exit:
D5 cash close

No fixed TP.

Shadow NAV:
$xxx

Suggested QQQ quantity:
xxx
```

## 18.5 Normal Green

Title:

```text
🟢 NORMAL GREEN — D3 BUY
```

Message:

```text
BUY QQQ

Entry:
D3 03:30

TP:
+2.50%

Otherwise:
D5 cash close
```

## 18.6 Skipped Signal

Title:

```text
⚪ SIGNAL SKIPPED
```

Example:

```text
New STRONG_YELLOW detected

Current State:
LONG_GREEN

Existing-position priority active.

Action:
NO TRADE
```

---

# 19. Shadow Account

Maintain:

```text
shadow_nav
cash
position
entry_price
position_notional
unrealized_pnl
realized_pnl
```

The shadow account must proceed independently of whether the user actually executes the live trade.

---

# 20. Shadow Trade Record

Each trade should store at least:

```text
trade_id
signal_id
signal_type
observation_date
action_date
entry_timestamp
entry_price
entry_type
direction
tp_pct
tp_price
sl_pct
sl_price
planned_exit_date
exit_timestamp
exit_price
exit_reason
return_pct
pnl_usd
nav_before
nav_after
mfe_pct
mae_pct
bars_held
same_bar_ambiguity
price_source
strategy_version
environment_type
```

---

# 21. Signal Record

Store every signal, including skipped signals:

```text
signal_id
observation_date
signal_color
signal_raw
classification
BC_GEXDelta
BP_GEXDelta
SC_GEXDelta
SP_GEXDelta
BC_GEX
BP_GEX
SC_GEX
SP_GEX
SP_delta_share
SC_rolling_median_60
SC_percentile_60
SP_share_p75_60
SP_share_percentile_60
prior_5d_nq_return
actionable_at
trade_allowed
skip_reason
strategy_version
environment_type
```

---

# 22. Strategy Versioning

Required:

```text
strategy_version
```

Initial:

```text
v1.0.0
```

Any change to:

- Thresholds
- TP
- SL
- Green logic
- Conflict rules
- Position sizing
- Time exit
- Entry timing

must increment strategy version.

Do not silently mix performance from different versions.

---

# 23. Environment Separation

Every run/trade must be classified as:

```text
BACKTEST
FORWARD_PAPER
LIVE_MANUAL
```

Do not combine these when calculating forward performance.

---

# 24. Manual Execution Tracking

Pushover is one-way, so v1 cannot automatically know whether the user actually traded.

Provide CLI commands such as:

```bash
python app.py trade confirm <trade_id>
python app.py trade skip <trade_id>
python app.py trade close <trade_id> --price <price>
```

Store statuses such as:

```text
EXECUTED
SKIPPED_BY_USER
CLOSED_MANUALLY
```

Optional actual-trade fields:

```text
actual_entry
actual_exit
actual_quantity
actual_pnl
actual_commission
actual_slippage
actual_vs_model_entry_bps
actual_vs_model_exit_bps
actual_vs_model_return
```

---

# 25. Reporting

A minimal CLI / HTML / Markdown report is sufficient for v1.

Report:

```text
Total Signals
Tradable Signals
Executed Shadow Trades
Skipped Signals

Strong Yellow count
Reliable Yellow count
Reversal Green count
Normal Green count

Win Rate
Average Return
Median Return
Profit Factor

Max Drawdown
Longest Losing Streak

Average Holding Time

MFE
MAE

Monthly Return
Current NAV
```

Break out performance by signal type.

---

# 26. Monthly Pushover Summary

On the final US cash trading day of each month, send:

```text
📊 MONTHLY SIGNAL REPORT
```

Include:

```text
Month
Starting NAV
Ending NAV
Return
Trades
Wins
Losses
Strong Yellow count
Reliable Yellow count
Reversal Green count
Normal Green count
Max Drawdown
Forward trades accumulated / 50
```

---

# 27. Forward-Test Milestones

Track:

```text
10 trades
20 trades
30 trades
50 trades
```

At 30 and 50 forward trades, send a Pushover notification recommending strategy review.

---

# 28. Scheduling

All scheduling uses:

```text
America/New_York
```

Suggested workflow:

```text
03:15  Check latest source-data availability
03:20  Validate data
03:25  Calculate signal
03:27  Classify strategy
03:28  Check portfolio conflicts
03:29  Send Pushover notification
03:30  Actionable time
```

Config example:

```yaml
signal:
  timezone: America/New_York
  actionable_time: "03:30"
  notification_time: "03:29"
```

---

# 29. Data Freshness

The system must verify:

```text
ObservationDate = latest completed US cash trading day
```

If D1 is Tuesday and Monday was a normal session, use Monday's observation date. If Monday was a holiday, use Friday.

---

# 30. Fail Closed

If required data is incomplete or stale:

```text
trade_allowed = false
```

Examples:

- Missing SC GEX
- Missing SP GEXDelta
- Missing NQ data
- Missing observation date
- Insufficient rolling history
- Data validation failure

Pushover:

```text
⚠️ SIGNAL DATA INCOMPLETE
NO TRADE
```

---

# 31. Warm-Up

Yellow rolling thresholds require:

```text
minimum_history_days = 60
```

If fewer than 60 prior valid trading days exist:

```text
classification = INSUFFICIENT_HISTORY
trade_allowed = false
```

Do not silently reduce the warm-up window in v1.

---

# 32. Input Validation

For each observation date, require exactly one valid row for:

```text
BC
BP
SC
SP
```

A `NULL` aggregate row may exist but must not be used in the four-capital calculation.

Also verify:

```text
TotalAbsGEXDelta > 0
```

and validate date uniqueness.

---

# 33. NQ Continuous Contract Roll

Historical NQMain backtests must not count artificial quarterly contract-roll jumps as real market P&L.

The backtest engine must either:

- Detect and locally neutralize roll gaps, or
- Use a properly back-adjusted continuous series.

Typical roll months:

```text
March
June
September
December
```

Production live QQQ reference prices do not need this historical roll adjustment.

---

# 34. First-Touch Simulation Engine

Implement as a separate module.

Suggested:

```text
simulation/
    first_touch.py
```

Inputs:

```text
entry
side
tp
sl
bars
```

Outputs:

```text
exit_time
exit_price
exit_reason
mfe
mae
ambiguous
```

This module must be unit tested.

---

# 35. Recommended Architecture

Use:

```text
Python 3.12+
```

Suggested layout:

```text
src/
  config/
  data/
    gex_repository.py
    nq_repository.py
    trading_calendar.py

  signals/
    base_signal.py
    yellow_classifier.py
    green_classifier.py
    features.py

  strategy/
    yellow_strategy.py
    green_strategy.py
    state_machine.py

  portfolio/
    portfolio.py
    sizing.py

  notification/
    pushover.py
    templates.py

  shadow/
    execution_simulator.py
    performance.py

  storage/
    models.py
    repository.py

  jobs/
    daily_signal_job.py
    position_monitor_job.py
    monthly_report_job.py

tests/
```

---

# 36. Database

MVP recommendation:

```text
SQLite
```

Future:

```text
PostgreSQL
```

Core tables:

```text
raw_gex
market_bars
signals
trade_plans
shadow_trades
actual_trades
portfolio_state
strategy_versions
system_events
```

---

# 37. Configuration

Example:

```yaml
strategy:
  version: "1.0.0"

  yellow:
    lookback_days: 60
    sc_percentile_threshold: 0.50
    sp_share_percentile_threshold: 0.75

    strong:
      tp_pct: 0.008
      sl_pct: 0.010

    reliable:
      tp_pct: 0.004
      sl_pct: 0.008

  green:
    reversal:
      prior_return_days: 5
      dip_pct: 0.010
      dip_expire_day: 3
      exit_day: 5

    normal:
      entry_day: 3
      tp_pct: 0.025
      exit_day: 5

portfolio:
  exposure_factor: 1.0
  max_positions: 1
  conflict_policy: EXISTING_POSITION_PRIORITY

notifications:
  notify_no_signal: false
```

---

# 38. Pushover Priority

Default:

```text
normal
```

Strong Yellow may optionally use:

```text
high
```

System/data errors may use:

```text
high
```

Do not use repeating emergency notifications in v1.

---

# 39. Logging

Use structured JSON logs.

Fields:

```text
timestamp
job_id
observation_date
signal_type
strategy_version
portfolio_state
trade_allowed
notification_sent
error
duration_ms
```

Never log:

```text
Pushover token
Pushover user key
future broker credentials
```

---

# 40. Idempotency

A scheduler retry must not create duplicate:

- Signals
- Trade plans
- Pushover notifications
- Shadow positions
- Trade exits

Suggested idempotency key:

```text
ObservationDate + SignalType + StrategyVersion + ActionableTimestamp
```

---

# 41. Recovery

After restart, restore from persistent storage:

```text
portfolio_state
active_position
pending_dip_order
planned_D3
planned_D5
shadow_NAV
```

Do not keep critical state only in process memory.

---

# 42. Position Monitor

The daily signal job and active-position monitor must be separate.

Position monitor responsibilities:

```text
TP
SL
dip fill
D3 fallback
time exit
```

With 30-minute historical data, the shadow monitor may operate at 30-minute resolution. Future live-market monitoring can use finer granularity.

---

# 43. Exit Notifications

Examples:

```text
✅ STRONG YELLOW TP HIT
```

Include:

```text
Trade ID
Entry
Exit
Return
Shadow P&L
New Shadow NAV
```

Stop:

```text
❌ STRONG YELLOW STOP HIT
```

Time exit:

```text
⏰ GREEN D5 TIME EXIT
```

---

# 44. No-Signal Notification

Default:

```yaml
notifications:
  notify_no_signal: false
```

Optional health notification:

```text
System OK
Data current
No actionable signal
```

---

# 45. Testing Requirements

## 45.1 Unit Tests

Cover:

- SP Delta Share calculation
- Rolling median / percentile
- Causal feature slicing
- Trading calendar
- Yellow classification
- Green classification
- Strong Yellow TP/SL
- Reliable Yellow TP/SL
- Reversal Green dip
- D3 fallback
- D5 exit
- Normal Green +2.5% TP
- Gap execution
- Same-bar ambiguity
- Existing-position priority
- Idempotency
- Restart/recovery

## 45.2 Integration Tests

Use a small set of real historical records from supplied source data.

Validate that known raw GEX rows are parsed exactly and produce expected derived features.

---

# 46. Backtest Reproduction

Provide a CLI command such as:

```bash
python -m app.backtest   --start 2025-03-01   --end 2026-08-06   --initial-capital 100000   --exposure 1.0
```

Output:

```text
Trade count
Ending NAV
Total return
CAGR
Max drawdown
Win rate
Profit factor
Average trade
Median trade
Monthly returns
Performance by signal type
```

Do **not** hard-code any target historical result.

The output must be generated from the supplied data and strategy rules.

---

# 47. Reproducibility

Each backtest should output:

```text
strategy_version
git_commit
data_hash
config_hash
run_timestamp
```

This should make it possible to explain differences between two historical runs.

---

# 48. Data Leakage Protection

All rolling-feature APIs must take:

```text
as_of_date
```

Never compute production thresholds from the full dataset.

Incorrect:

```python
threshold = df["SC_GEX"].median()
```

Correct pattern:

```python
history = df[df["date"] < as_of_date].tail(60)
threshold = history["SC_GEX"].median()
```

The same rule applies to SP-share percentiles.

---

# 49. Forward-Test Lock

After deploying `v1.0.0`, do not automatically optimize:

```text
Strong TP = 0.8%
Strong SL = 1.0%

Reliable TP = 0.4%
Reliable SL = 0.8%

Reversal Dip = -1.0%

Normal Green TP = +2.5%
```

Any change requires a new strategy version.

---

# 50. Performance Metrics

Calculate:

```text
Total Return
CAGR
Max Drawdown
Win Rate
Profit Factor
Average Trade
Median Trade
MFE
MAE
Longest Losing Streak
Trades / Month
Trades / Year
Average Holding Time
```

Also report all metrics separately for:

```text
STRONG_YELLOW
RELIABLE_YELLOW
REVERSAL_GREEN
NORMAL_GREEN
```

---

# 51. Most Important Forward-Test Metrics

Do not focus only on win rate.

Prioritize:

```text
Expected Return / Trade
Profit Factor
Max Drawdown
MFE / MAE
Actual vs Model Slippage
Signal Frequency
```

Record conflicting ignored signals for later research:

```text
conflicting_signal_type
```

Do not change the existing-position baseline during the v1 forward test.

---

# 52. Security

Use `.env` or a secrets solution for:

```text
PUSHOVER_API_TOKEN
PUSHOVER_USER_KEY
```

Ensure `.env` is included in `.gitignore`.

Future broker credentials must also be stored outside source code.

---

# 53. Deployment

Recommended MVP:

```text
Docker
Docker Compose
SQLite persistent volume
```

A home-hosted service is sufficient initially.

Possible future GCP deployment:

```text
Cloud Run
Cloud Scheduler
Cloud SQL / Firestore
Secret Manager
```

Cloud deployment is not required for the MVP.

---

# 54. Health Check

Expose:

```text
/health
```

Example:

```json
{
  "status": "ok",
  "strategy_version": "1.0.0",
  "latest_gex_date": "2026-08-10",
  "latest_market_bar": "2026-08-11T03:00:00-04:00",
  "portfolio_state": "FLAT"
}
```

---

# 55. Daily Job Output

Every daily run should produce a machine-readable summary, e.g.:

```json
{
  "observation_date": "2026-08-10",
  "signal": "YELLOW",
  "classification": "STRONG_YELLOW",
  "actionable_at": "2026-08-11T03:30:00-04:00",
  "portfolio_state": "FLAT",
  "trade_allowed": true,
  "instrument": "QQQ",
  "side": "SHORT",
  "tp_pct": 0.008,
  "sl_pct": 0.010,
  "strategy_version": "1.0.0"
}
```

---

# 56. MVP Acceptance Criteria

### AC1
Read and validate BC/BP/SC/SP raw GEX data.

### AC2
Generate causal 60-day:

```text
STRONG_YELLOW
RELIABLE_YELLOW
MIXED_YELLOW
WEAK_YELLOW
```

### AC3
Generate:

```text
REVERSAL_GREEN
NORMAL_GREEN
```

### AC4
Correctly use:

```text
03:30 America/New_York
```

with DST handling.

### AC5
Correctly enforce:

```text
EXISTING_POSITION_PRIORITY
```

### AC6
Send Pushover notifications with:

```text
Entry
TP
SL
Time exit
classification
position size
portfolio state
```

### AC7
Maintain a persistent `$100,000` configurable shadow account.

### AC8
Correctly implement:

```text
Reversal Green -1% dip
→ if unfilled, D3 03:30 fallback
→ D5 exit
```

### AC9
Restore active state after restart.

### AC10
Prevent duplicate signals/trades/notifications on reruns.

### AC11
Fail closed on incomplete/stale/invalid data.

---

# 57. Phase 1 Success Criteria

Accumulate at least:

```text
30–50 forward position episodes
```

Then compare:

```text
Forward vs Backtest
```

Evaluate:

```text
Win-rate degradation
Expected-return degradation
Profit-factor degradation
Slippage
Maximum drawdown
Signal frequency
Operational reliability
```

---

# 58. Phase 2 — Future

If Phase 1 is satisfactory, add IBKR API support in **semi-automatic** mode:

```text
Signal
↓
Generate IBKR order
↓
User confirms
↓
Submit
```

---

# 59. Phase 3 — Future

Consider fully automated execution only after sufficient forward evidence.

Minimum research milestone:

```text
>= 50 forward trades
```

Required future controls:

- Broker reconciliation
- Kill switch
- Max daily loss
- Max exposure
- Connectivity monitor
- Duplicate-order protection
- Stale-quote detection
- Order acknowledgement
- Exchange-rejection handling

---

# 60. Recommended Codex Implementation Order

Implement in this order:

```text
1. Data models
2. Raw GEX parser
3. NQ parser
4. Trading calendar
5. Feature calculations
6. Yellow classifier
7. Green classifier
8. Historical backtester
9. Reproduce historical strategy behavior
10. Portfolio state machine
11. Shadow account
12. Pushover integration
13. Scheduler
14. Forward-paper mode
15. Manual-trade CLI
16. Reports
```

The most important checkpoint is between steps 8 and 9.

Before implementing Pushover or production scheduling, Codex must demonstrate that the same supplied raw GEX and NQMain data reproduces the intended strategy logic and produces a defensible historical equity curve without look-ahead leakage.

---

# 61. Strategy v1.0 Summary

## 🔴 Strong Yellow

```text
Condition:
Yellow
+ SC GEX <= prior 60D median
+ SP Delta Share > prior 60D P75

Entry:
D1 03:30 New York
SHORT QQQ

TP:
-0.8%

SL:
+1.0%
```

## 🟡 Reliable Yellow

```text
Condition:
Yellow
+ SC GEX <= prior 60D median
+ SP Delta Share <= prior 60D P75

Entry:
D1 03:30 New York
SHORT QQQ

TP:
-0.4%

SL:
+0.8%
```

## 🟢 Reversal Green

```text
Condition:
Green
+ prior 5D NQ return <= 0

D1 03:30:
set reference price

Buy Limit:
-1%

Valid:
until D3 03:30

If filled:
Hold until D5 cash close

If NOT filled:
Buy D3 03:30
Hold until D5 cash close
```

## 🟢 Normal Green

```text
Condition:
Green
+ prior 5D NQ return > 0

Entry:
D3 03:30 New York

TP:
+2.5%

Otherwise:
D5 cash close
```

## Portfolio

```text
Max active position:
1

Conflict rule:
EXISTING_POSITION_PRIORITY

No stacking
No Green refresh
No leverage increase
No opposite-position override
```

## Execution

```text
Instrument:
QQQ

Historical price proxy:
NQMain

Signal notification:
Pushover

Actual execution:
Manual

Shadow initial capital:
$100,000

Strategy Version:
v1.0.0
```

---

# 62. Codex Top-Level Instruction

Use this instruction when handing the PRD to Codex:

> **Do not optimize or change any strategy rules while implementing this PRD. First reproduce the historical results from the supplied data using only causal information available as of each observation date. Any discrepancy must be reported rather than silently fixed by changing thresholds, dates, signal definitions, trade rules, or execution assumptions. Preserve strategy versioning and explicitly identify any implementation assumption not specified by this PRD.**
