# SOXL — High-GEX-Volatility Continuation — 1.0.0-production

## Production status

- **Status:** IMPLEMENTABLE
- **Deployment target:** PRODUCTION
- **Enabled:** true
- **Mode:** NOTIFICATION_ONLY
- **Notifications:** enabled
- **Broker execution:** **HARD_DISABLED**
- **Execution workflow:** production signal → notification/report → user manually decides whether to trade.

## Exact signal

`SOXL_HIGH_GEX_VOL_CONTINUATION`

- Direction: **LONG**
- Entry: D1 **07:30 America/New_York Open**
- Scheduled exit: **D3 regular-session close**
- Trigger: `SafeGEXVolRank60 >= 0.65 AND QQQ_BB_Bandwidth > 0.081`

SOXL D3 upside regime when its causal dealer-GEX volatility is elevated and QQQ price volatility is sufficiently wide.

## Readiness and leakage controls

At/after 07:30 ET, D0 must be the previous completed US trading session and all required capital-type/feature inputs must be complete. Missing or stale inputs produce **NOT_READY**, not NO_SIGNAL. Rank60 features use only the previous 60 valid observations and exclude the current observation, with at least 10 prior values.

Prohibited production predictors: `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, `Next20DaysChange`, the known full-partition `GEX_Vol_Percentile` family, and dark-pool fields until publication-time availability is proven.

## Historical interpretation

Resolved research instances: **31**; wins **25**; win rate **80.6%**; average direction-adjusted return **8.80%**; profit factor **8.05**.

These statistics use historical market prices, zero modeled transaction costs/slippage, and do not depend on manual trade records. Because the rule was selected after broad feature screening, the exact trigger is frozen from **2026-08-28** for genuine forward/OOS evaluation.
