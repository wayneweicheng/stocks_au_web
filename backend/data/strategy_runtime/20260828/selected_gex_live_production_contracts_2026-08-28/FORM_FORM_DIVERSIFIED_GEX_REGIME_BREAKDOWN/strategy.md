# FORM — Diversified GEX Regime Breakdown — 1.0.0-production

## Production status

- **Status:** IMPLEMENTABLE
- **Deployment target:** PRODUCTION
- **Enabled:** true
- **Mode:** NOTIFICATION_ONLY
- **Notifications:** enabled
- **Broker execution:** **HARD_DISABLED**
- **Execution workflow:** production signal → notification/report → user manually decides whether to trade.

## Exact signal

`FORM_DIVERSIFIED_GEX_REGIME_BREAKDOWN`

- Direction: **SHORT**
- Entry: D1 **07:30 America/New_York Open**
- Scheduled exit: **D5 regular-session close**
- Trigger: `GEX_SMA5 >= -814.3 AND ConcentrationHHI <= 0.5445`

FORM bearish D5 setup when short-term aggregate GEX is not deeply negative and capital-type positioning is relatively diversified rather than concentrated.

## Readiness and leakage controls

At/after 07:30 ET, D0 must be the previous completed US trading session and all required capital-type/feature inputs must be complete. Missing or stale inputs produce **NOT_READY**, not NO_SIGNAL. Rank60 features use only the previous 60 valid observations and exclude the current observation, with at least 10 prior values.

Prohibited production predictors: `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, `Next20DaysChange`, the known full-partition `GEX_Vol_Percentile` family, and dark-pool fields until publication-time availability is proven.

## Historical interpretation

Resolved research instances: **15**; wins **14**; win rate **93.3%**; average direction-adjusted return **9.60%**; profit factor **136.91**.

These statistics use historical market prices, zero modeled transaction costs/slippage, and do not depend on manual trade records. Because the rule was selected after broad feature screening, the exact trigger is frozen from **2026-08-28** for genuine forward/OOS evaluation.
