# HPE — Sell-Put Participation Weakness — 1.0.0-production

## Production status

- **Status:** IMPLEMENTABLE
- **Deployment target:** PRODUCTION
- **Enabled:** true
- **Mode:** NOTIFICATION_ONLY
- **Notifications:** enabled
- **Broker execution:** **HARD_DISABLED**
- **Execution workflow:** production signal → notification/report → user manually decides whether to trade.

## Exact signal

`HPE_SELL_PUT_PARTICIPATION_WEAKNESS`

- Direction: **SHORT**
- Entry: D1 **07:30 America/New_York Open**
- Scheduled exit: **D1 regular-session close**
- Trigger: `SPShareChgRank60 > 0.37`

HPE D1 weakness after sell-put GEX share increases meaningfully relative to its recent causal distribution.

## Readiness and leakage controls

At/after 07:30 ET, D0 must be the previous completed US trading session and all required capital-type/feature inputs must be complete. Missing or stale inputs produce **NOT_READY**, not NO_SIGNAL. Rank60 features use only the previous 60 valid observations and exclude the current observation, with at least 10 prior values.

Prohibited production predictors: `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, `Next20DaysChange`, the known full-partition `GEX_Vol_Percentile` family, and dark-pool fields until publication-time availability is proven.

## Historical interpretation

Resolved research instances: **29**; wins **21**; win rate **72.4%**; average direction-adjusted return **1.20%**; profit factor **3.72**.

These statistics use historical market prices, zero modeled transaction costs/slippage, and do not depend on manual trade records. Because the rule was selected after broad feature screening, the exact trigger is frozen from **2026-08-28** for genuine forward/OOS evaluation.
