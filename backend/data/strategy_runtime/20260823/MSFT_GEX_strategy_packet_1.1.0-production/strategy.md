# MSFT GEX Capital-Type Feature-Aware Strategy — 1.1.0-production

## Production status

- **Status:** IMPLEMENTABLE
- **Deployment target:** PRODUCTION
- **Enabled:** true
- **Mode:** NOTIFICATION_ONLY
- **Notifications:** enabled; every emitted actionable or WATCH classification produces an immutable report and production notification subject to deduplication.
- **Order handling:** user manually decides whether to place an order after receiving the notification.
- **Broker execution:** **HARD_DISABLED**.

## v1.1 feature change

Base capital-type triggers are unchanged except for confidence/gating of `MSFT_BEARISH_CROWDING_SQUEEZE_WATCH`.

**HIGH predicate:** `QQQ.TodayChange > 1.0 OR MSFT.GEXChange < -10.0`

- `MSFT_BEARISH_CROWDING_SQUEEZE_CONFIRMED` → PLAN_ENTRY / production notification.
- `MSFT_BEARISH_CROWDING_SQUEEZE_WEAK` → WATCH / production notification.

The prior LONG crowding-squeeze WATCH is promoted to an actionable LONG plan only when benchmark strength or a large negative signed MSFT GEXChange confirms the setup. Direction remains LONG; this is not a short signal.

## Data readiness

At D1 07:30 America/New_York, require the previous XNYS session D0 to be complete in `StockDB_US.Transform.OptionGEXChangeCapitalType` and require D0 feature rows in `StockDB_US.Analysis.GEX_Features` for **MSFT** and **QQQ**. Missing/null feature inputs are **NOT_READY**; do not silently downgrade HIGH to STANDARD/WEAK. Source correction creates a new immutable evaluation revision.

## Leakage controls

Allowed tier fields are causal D0-or-earlier values. Production/training inputs MUST exclude `TomorrowChange`, `Next2DaysChange`, `Next5DaysChange`, `Next10DaysChange`, `Next20DaysChange`, and the current full-partition `GEX_Vol_Percentile` family (`GEX_HighVolatility`, `GEX_StableRegime`, `Setup_Dual_Squeeze`). Dark-pool fields remain excluded until publication-time availability is proven.

## Entry/exit

Existing v1.0.0 direction, D1 07:30 entry policy, holding horizon and exit mechanics are unchanged for every base strategy. Feature tiers alter only confidence/actionability as stated above.

## Historical interpretation

Historical tier statistics are reclassifications of the existing reconciled v1.0.0 instances. They were discovered on the available sample and are not untouched OOS estimates; the exact predicates above are frozen in this production version for forward validation.
