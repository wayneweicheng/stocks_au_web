# DIA — GEX Washout Reversal — 2.0.0-production

## Production status

- **Status:** IMPLEMENTABLE
- **Classification:** STRONG_VALIDATED
- **Deployment:** PRODUCTION / NOTIFICATION_ONLY
- **Broker execution:** **HARD_DISABLED**
- **Forward reserve:** September and October 2026 are intentionally excluded.

## Exact signal

`DIA_GEX_WASHOUT_REVERSAL` — **LONG**, entry D1 07:30 America/New_York Open, exit D5 regular-session close.

Trigger: `GEX_ZScore < -1.0`

## Data and leakage controls

Inputs are read from `StockDB_US` (`Transform.OptionGEXChangeCapitalType`, `Analysis.GEX_Features`, and `StockData.PriceHistoryTimeFrame`). Causal rank60 values compare D0 only with prior valid observations and exclude D0 from the reference window. Future-return fields and full-partition volatility percentiles are prohibited. Missing or stale inputs produce `NOT_READY`; no signal is silently downgraded.

## Research result through 2026-08-31

Resolved instances: **23**; win rate **87.0%**; mean direction-adjusted return **1.25%**; profit factor **8.674968798254667**. Validation and final-tail details are in `historical-performance.json`. These are selected-research estimates, not proof.
