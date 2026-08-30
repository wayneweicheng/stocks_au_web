# TLT — Sell-Call Trend Exhaustion — 1.0.0-production

## Production status

- **Status:** IMPLEMENTABLE
- **Deployment target:** PRODUCTION
- **Enabled:** true
- **Mode:** NOTIFICATION_ONLY
- **Notifications:** enabled
- **Broker execution:** **HARD_DISABLED**
- **Execution workflow:** production signal → notification/report → user manually decides whether to trade.

## Exact signal

`TLT_SELL_CALL_TREND_EXHAUSTION`

- Direction: **SHORT**
- Entry: D1 **07:30 America/New_York Open**
- Scheduled exit: **D5 regular-session close**
- Trigger: `PriceDistSMA50Pct >= -1.0 AND SCShareChgRank60 >= 0.60`

TLT bearish exhaustion when price is near/above its 50-observation trend and sell-call share is rotating upward relative to recent history.

## Readiness and leakage controls

At/after 07:30 ET, D0 must be the previous completed US trading session and all required capital-type/feature inputs must be complete. Missing or stale inputs produce **NOT_READY**, not NO_SIGNAL. Rank60 features use only the previous 60 valid observations and exclude the current observation, with at least 10 prior values.

Prohibited production predictors: `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, `Next20DaysChange`, the known full-partition `GEX_Vol_Percentile` family, and dark-pool fields until publication-time availability is proven.

## Historical interpretation

Resolved research instances: **35**; wins **28**; win rate **80.0%**; average direction-adjusted return **0.69%**; profit factor **5.98**.

These statistics use historical market prices, zero modeled transaction costs/slippage, and do not depend on manual trade records. Because the rule was selected after broad feature screening, the exact trigger is frozen from **2026-08-28** for genuine forward/OOS evaluation.
