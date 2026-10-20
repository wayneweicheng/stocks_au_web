# GDX — GEX-Vol Weak-NASDAQ Reversal — 2.0.0-production

## Production status

- **Status:** IMPLEMENTABLE
- **Classification:** STRONG_VALIDATED
- **Deployment:** PRODUCTION / NOTIFICATION_ONLY
- **Broker execution:** **HARD_DISABLED**
- **Forward reserve:** September and October 2026 are intentionally excluded.

## Exact signal

`GDX_GEX_VOL_WEAK_NASDAQ_REVERSAL` — **LONG**, entry D1 07:30 America/New_York Open, exit D5 regular-session close.

Trigger: `SafeGEXVolRank60 >= 0.40 AND NASDAQ_chg5 <= -1.0`

## Data and leakage controls

Inputs are read from `StockDB_US` (`Transform.OptionGEXChangeCapitalType`, `Analysis.GEX_Features`, and `StockData.PriceHistoryTimeFrame`). Causal rank60 values compare D0 only with prior valid observations and exclude D0 from the reference window. Future-return fields and full-partition volatility percentiles are prohibited. Missing or stale inputs produce `NOT_READY`; no signal is silently downgraded.

## Research result through 2026-08-31

Resolved instances: **30**; win rate **83.3%**; mean direction-adjusted return **4.68%**; profit factor **15.846040888693738**. Validation and final-tail details are in `historical-performance.json`. These are selected-research estimates, not proof.
