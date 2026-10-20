# ORCL — Put-Flow Rotation Breakdown — 2.0.0-production

## Production status

- **Status:** IMPLEMENTABLE
- **Classification:** PROMISING_SMALL_N
- **Deployment:** PRODUCTION / NOTIFICATION_ONLY
- **Broker execution:** **HARD_DISABLED**
- **Forward reserve:** September and October 2026 are intentionally excluded.

## Exact signal

`ORCL_PUT_FLOW_ROTATION_BREAKDOWN` — **SHORT**, entry D1 07:30 America/New_York Open, exit D3 regular-session close.

Trigger: `PutBuyShareChgAbsRank60 >= 0.65 AND BuyCall_GEXDeltaPerc_Rank60 <= 0.48`

## Data and leakage controls

Inputs are read from `StockDB_US` (`Transform.OptionGEXChangeCapitalType`, `Analysis.GEX_Features`, and `StockData.PriceHistoryTimeFrame`). Causal rank60 values compare D0 only with prior valid observations and exclude D0 from the reference window. Future-return fields and full-partition volatility percentiles are prohibited. Missing or stale inputs produce `NOT_READY`; no signal is silently downgraded.

## Research result through 2026-08-31

Resolved instances: **23**; win rate **82.6%**; mean direction-adjusted return **2.98%**; profit factor **3.272131517975249**. Validation and final-tail details are in `historical-performance.json`. These are selected-research estimates, not proof.
