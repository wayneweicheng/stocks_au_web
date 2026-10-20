# TXN — Sell-Call Macro Breakdown — 2.0.0-production

## Production status

- **Status:** IMPLEMENTABLE
- **Classification:** VALIDATED
- **Deployment:** PRODUCTION / NOTIFICATION_ONLY
- **Broker execution:** **HARD_DISABLED**
- **Forward reserve:** September and October 2026 are intentionally excluded.

## Exact signal

`TXN_SELL_CALL_MACRO_BREAKDOWN` — **SHORT**, entry D1 07:30 America/New_York Open, exit D5 regular-session close.

Trigger: `SCShare >= 0.0284 AND QQQ_BuyCall_GEXDeltaPerc_Rank60 <= 0.65 AND Gold_chg5 >= -1.0`

## Data and leakage controls

Inputs are read from `StockDB_US` (`Transform.OptionGEXChangeCapitalType`, `Analysis.GEX_Features`, and `StockData.PriceHistoryTimeFrame`). Causal rank60 values compare D0 only with prior valid observations and exclude D0 from the reference window. Future-return fields and full-partition volatility percentiles are prohibited. Missing or stale inputs produce `NOT_READY`; no signal is silently downgraded.

## Research result through 2026-08-31

Resolved instances: **23**; win rate **73.9%**; mean direction-adjusted return **2.95%**; profit factor **6.953624085691349**. Validation and final-tail details are in `historical-performance.json`. These are selected-research estimates, not proof.
