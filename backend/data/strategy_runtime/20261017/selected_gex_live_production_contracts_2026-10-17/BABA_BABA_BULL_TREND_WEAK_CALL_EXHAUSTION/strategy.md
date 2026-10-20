# BABA — Bull-Trend Weak-Call Exhaustion — 2.0.0-production

## Production status

- **Status:** IMPLEMENTABLE
- **Classification:** STRONG_VALIDATED
- **Deployment:** PRODUCTION / NOTIFICATION_ONLY
- **Broker execution:** **HARD_DISABLED**
- **Forward reserve:** September and October 2026 are intentionally excluded.

## Exact signal

`BABA_BULL_TREND_WEAK_CALL_EXHAUSTION` — **SHORT**, entry D1 07:30 America/New_York Open, exit D5 regular-session close.

Trigger: `Price_SMA20 > Price_SMA50 AND BuyCall_GEXDeltaPerc_Rank60 <= 0.80`

## Data and leakage controls

Inputs are read from `StockDB_US` (`Transform.OptionGEXChangeCapitalType`, `Analysis.GEX_Features`, and `StockData.PriceHistoryTimeFrame`). Causal rank60 values compare D0 only with prior valid observations and exclude D0 from the reference window. Future-return fields and full-partition volatility percentiles are prohibited. Missing or stale inputs produce `NOT_READY`; no signal is silently downgraded.

## Research result through 2026-08-31

Resolved instances: **33**; win rate **75.8%**; mean direction-adjusted return **2.72%**; profit factor **5.560620923135908**. Validation and final-tail details are in `historical-performance.json`. These are selected-research estimates, not proof.
