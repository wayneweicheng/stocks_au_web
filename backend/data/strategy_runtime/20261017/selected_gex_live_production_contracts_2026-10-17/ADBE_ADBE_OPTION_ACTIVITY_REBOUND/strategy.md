# ADBE — Option Activity Rebound — 2.0.0-production

## Production status

- **Status:** IMPLEMENTABLE
- **Classification:** STRONG_VALIDATED
- **Deployment:** PRODUCTION / NOTIFICATION_ONLY
- **Broker execution:** **HARD_DISABLED**
- **Forward reserve:** September and October 2026 are intentionally excluded.

## Exact signal

`ADBE_OPTION_ACTIVITY_REBOUND` — **LONG**, entry D1 07:30 America/New_York Open, exit D5 regular-session close.

Trigger: `BPOptionCount_Rank60 <= 0.70 AND TotalOptionCount_Rank60 <= 0.70`

## Data and leakage controls

Inputs are read from `StockDB_US` (`Transform.OptionGEXChangeCapitalType`, `Analysis.GEX_Features`, and `StockData.PriceHistoryTimeFrame`). Causal rank60 values compare D0 only with prior valid observations and exclude D0 from the reference window. Future-return fields and full-partition volatility percentiles are prohibited. Missing or stale inputs produce `NOT_READY`; no signal is silently downgraded.

## Research result through 2026-08-31

Resolved instances: **48**; win rate **79.2%**; mean direction-adjusted return **3.46%**; profit factor **5.273660527324492**. Validation and final-tail details are in `historical-performance.json`. These are selected-research estimates, not proof.
