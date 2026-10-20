# AAPL — Call-Buy Leadership — 2.0.0-production

## Production status

- **Status:** IMPLEMENTABLE
- **Classification:** VALIDATED
- **Deployment:** PRODUCTION / NOTIFICATION_ONLY
- **Broker execution:** **HARD_DISABLED**
- **Forward reserve:** September and October 2026 are intentionally excluded.

## Exact signal

`AAPL_CALL_BUY_LEADERSHIP` — **LONG**, entry D1 07:30 America/New_York Open, exit D3 regular-session close.

Trigger: `BCShareRank60 >= 0.65 AND QQQ_TodayChange > 0`

## Data and leakage controls

Inputs are read from `StockDB_US` (`Transform.OptionGEXChangeCapitalType`, `Analysis.GEX_Features`, and `StockData.PriceHistoryTimeFrame`). Causal rank60 values compare D0 only with prior valid observations and exclude D0 from the reference window. Future-return fields and full-partition volatility percentiles are prohibited. Missing or stale inputs produce `NOT_READY`; no signal is silently downgraded.

## Research result through 2026-08-31

Resolved instances: **28**; win rate **67.9%**; mean direction-adjusted return **0.94%**; profit factor **3.0455020600761245**. Validation and final-tail details are in `historical-performance.json`. These are selected-research estimates, not proof.
