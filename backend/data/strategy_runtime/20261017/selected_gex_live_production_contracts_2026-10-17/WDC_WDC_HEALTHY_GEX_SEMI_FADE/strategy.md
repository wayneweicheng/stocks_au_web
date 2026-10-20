# WDC — Healthy-GEX Semi Fade — 2.0.0-production

## Production status

- **Status:** IMPLEMENTABLE
- **Classification:** PROMISING_SMALL_N
- **Deployment:** PRODUCTION / NOTIFICATION_ONLY
- **Broker execution:** **HARD_DISABLED**
- **Forward reserve:** September and October 2026 are intentionally excluded.

## Exact signal

`WDC_HEALTHY_GEX_SEMI_FADE` — **SHORT**, entry D1 07:30 America/New_York Open, exit D5 regular-session close.

Trigger: `GEX_Rank60 >= 0.20 AND QQQ_GEX_ZScore_60day > -1.5`

## Data and leakage controls

Inputs are read from `StockDB_US` (`Transform.OptionGEXChangeCapitalType`, `Analysis.GEX_Features`, and `StockData.PriceHistoryTimeFrame`). Causal rank60 values compare D0 only with prior valid observations and exclude D0 from the reference window. Future-return fields and full-partition volatility percentiles are prohibited. Missing or stale inputs produce `NOT_READY`; no signal is silently downgraded.

## Research result through 2026-08-31

Resolved instances: **15**; win rate **86.7%**; mean direction-adjusted return **11.34%**; profit factor **12.610474772890514**. Validation and final-tail details are in `historical-performance.json`. These are selected-research estimates, not proof.
