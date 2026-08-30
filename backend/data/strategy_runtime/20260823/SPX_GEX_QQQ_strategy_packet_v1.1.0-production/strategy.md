# SPXW GEX → QQQ Strategy — 1.1.0-production

## Production status

**IMPLEMENTABLE / PRODUCTION / ENABLED.** The strategy runs for production signal generation and sends production notifications. The user decides manually whether to place an order. Broker execution is **HARD_DISABLED**.

## v1.1 change

Only the Reversal Green classification is changed. Strong Yellow, Reliable Yellow, Mixed/Weak Yellow and Normal Green base/execution mechanics remain unchanged.

### Reversal Green HIGH — actionable
`REVERSAL_GREEN base AND (SPXW.GEX_Trending_Up=1 OR SPXW.GEX_Falling=1 OR QQQ.GEX_Above_SMA20=1)`

Historical resolved candidates: **21/21 winners**, average directional NQ-proxy return **+2.32%**.

### Reversal Green STANDARD — actionable
Base Reversal Green, not HIGH, and `(SPXW.Price_Above_SMA50=1 OR QQQ.MACD_Positive=1)`.

Historical resolved candidates: **9/11 winners (81.8%)**, average **+1.35%**.

### Reversal Green WEAK — WATCH
Base Reversal Green failing both HIGH and STANDARD confirmations. Production notification/report is still emitted, but the strategy creates no planned position. Historical resolved candidates: **3/10 winners (30.0%)**, average **-0.24%**.

HIGH and STANDARD retain the v1.0.2 execution: at D1 03:30 record QQQ reference; plan a buy limit 1% below reference through D3 03:30; if unfilled, fallback at D3 03:30; exit D5 cash close.

## Production data readiness
Require completed D0 SPXW capital-type rows plus same-D0 `StockDB_US.Analysis.GEX_Features` rows for SPXW and QQQ. Missing tier fields is `NOT_READY`; do not silently classify missing data as STANDARD/WEAK. NQMain remains the historical percentage-path proxy; live execution/reference is QQQ.

## Leakage controls
Future target columns (`TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, `Next20DaysChange`) and the current leaking full-partition `GEX_Vol_Percentile` family are forbidden inputs. Dark-pool fields remain excluded pending publication-time proof.

## Historical portfolio rerun
Re-running the frozen portfolio state machine with HIGH+STANDARD actionable and WEAK watch-only yields **60 resolved trades, 54 wins (90.0%), PF 10.34**, theoretical NQ-proxy compounded NAV from $100,000 to approximately **$197,448 (+97.45%)**, with exit-to-exit max drawdown about **3.05%**. These are gross historical proxy results and were used during feature discovery; they are not untouched OOS estimates. Exact v1.1 predicates are now frozen for forward production validation.
