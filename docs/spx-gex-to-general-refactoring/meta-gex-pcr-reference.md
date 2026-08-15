# META GEX/PCR Normalized Strategy Reference

This document converts the supplied META research/notification specification into an implementable V1 contract. It preserves the supplied strategy and makes ambiguous boundaries, data quality, scheduling, and lifecycle behavior explicit. Historical statistics remain research observations, not expected future performance.

## Identity

| Field | Value |
|---|---|
| Strategy Code | `meta-gex-pcr` |
| Initial Version Code | `v1.0.0-forward-paper` |
| Implementation Key | `meta-gex-pcr-v1` |
| Subject/Execution Instrument | META equity |
| Initial Environment | `FORWARD_PAPER` |
| Broker order authority | None |
| Evaluation timezone | `America/New_York` |

`auto_entry=true` means create an idempotent paper/manual Trade Plan entry plus Pushover notification. It never means submit an order.

## Fixed interpretations of ambiguous source wording

1. Strong Bearish Continuation uses the normal negative-price condition **or** the flat-price exception:

   ```text
   ((CloseChangePct < 0 AND PCRChangePct < -5)
     OR
    (abs(CloseChangePct) < 0.10 AND PCRChangePct < -20))
   AND HistoryCount >= 20
   AND CloseMoveAbsPct60 <= 0.50
   ```

2. Percentage-change features use percentage-point values: `-5` means negative five percent, not `-0.05`. Percentile ranks use the closed interval `0..1`.
3. All threshold operators are exact as printed. For example `PCRChangePct = -5` does not satisfy `< -5`; `SCAbsPct60 = 0.40` does satisfy the strong bullish rule.
4. Daily Close, not VWAP, drives `CloseChangePct`. VWAP is stored/displayed for context only.
5. One common prior-history cohort is used for all three percentile features so `HistoryCount` has one meaning.
6. If `HistoryCount < 20`, percentile-dependent rules do not match. Quality is `WARNING/INSUFFICIENT_HISTORY`; `NO_EDGE` may still be recorded when its direct quadrant condition matches, otherwise classification is `NO_SIGNAL`. No entry is allowed.
7. `DATA_GAP`, stale/partial source, null PCR/PCR change, inconsistent Close, or invalid numeric input is `BLOCKED`. Research metrics may be persisted, but operational Action is never `PLAN_ENTRY`.
8. V1 forward paper uses one normalized share for lifecycle/P&L display because the supplied research contains no validated sizing rule. Adding capital/notional sizing is a new behavioral version.
9. On an early-close session, “15:55 exit” means five minutes before the official regular-session close. The reminder is ten minutes before that exit. Normal sessions remain 15:45/15:55 ET.
10. V1 production monitoring uses fresh IB last-trade quotes. Historical 30-minute-bar tests use stop-first when a single bar crosses both TP and SL, preventing optimistic ordering. This convention must be identified in research/backtest output.

## Sources and Instrument Roles

| Role | Instrument/source | Contract |
|---|---|---|
| SUBJECT | META | Daily GEX/price Observation |
| SOURCE | `StockDB_US.Transform.OptionGEXChangeCapitalType` | Filter `ASXCode='META'`; aggregate raw rows by Observation date before any lag |
| SOURCE | `StockDB_US.StockData.PriceHistoryTimeFrame` | Completed intraday bars for backtest and MFE/MAE, after confirming the repository's exact timeframe code and ET timestamp convention |
| EXECUTION | META | IB stock contract `symbol=META`, `secType=STK`, `exchange=SMART`, `currency=USD`, primary exchange NASDAQ where contract qualification requires it |
| CALENDAR | XNAS/US equity session calendar | D/D1/D2/D3/D5 and early-close calculations |

Do not use `Transform.v_OptionGexChangeCapitalType` as the strategy calculation source: its window behavior is not the required one-row-per-date causal calculation. A new strategy-local query Adapter must aggregate first.

Before the canonical contract is marked `IMPLEMENTABLE`, validate the SQL source against representative META dates, identify an authoritative upstream completion/finality marker, and record the exact timeframe code/timestamp convention. The presence of all four Capital Types is necessary but is not sufficient proof that a non-atomic upstream load is finished. If no authoritative completion marker or transactional publication contract exists, stop under the packet's global source-finality condition; do not silently replace it with a “same hash twice” timing heuristic. If the live database differs from the checked-in schema, stop rather than substituting a nearby view.

## Observation construction

For each `ObservationDate`, filter required `CapitalType` values `BC`, `BP`, `SC`, and `SP`. Multiple rows per type are intentionally aggregated. Convert `GEXDelta` to a wide decimal before applying absolute value.

```text
BCAbs = SUM(abs(GEXDelta)) for BC
BPAbs = SUM(abs(GEXDelta)) for BP
SCAbs = SUM(abs(GEXDelta)) for SC
SPAbs = SUM(abs(GEXDelta)) for SP

TotalAbsGEX = BCAbs + BPAbs + SCAbs + SPAbs
```

Require at least one non-null row for each of the four types. All rows for one date must agree on non-null Close and, when present, VWAP. Unexpected CapitalType taxonomy for META is source drift and blocks the Observation until reviewed.

`D` is the completed source Observation date. Evaluation occurs on the next expected US trading session `D1` at 03:30 ET. At that time the latest completed META GEX Observation must equal the previous exchange session. A later latest date is a causality/invariant failure; an older date is stale/data gap.

## Derived metrics

Compute after one-row-per-date aggregation and sort by Observation date ascending.

```text
BCShare = BCAbs / TotalAbsGEX
BPShare = BPAbs / TotalAbsGEX
SCShare = SCAbs / TotalAbsGEX
SPShare = SPAbs / TotalAbsGEX
BullShare = (BCAbs + SPAbs) / TotalAbsGEX
BearShare = (BPAbs + SCAbs) / TotalAbsGEX

PutCallRatio = BPAbs / BCAbs

CloseChangePct = 100 * (CurrentClose - PreviousClose) / PreviousClose
PCRChangePct = 100 * (CurrentPCR - PreviousPCR) / PreviousPCR
```

Validity rules:

- `TotalAbsGEX <= 0`: blocked; shares are null.
- `BCAbs = 0`: PCR is null and the Observation is blocked for this strategy. Never substitute a large value.
- `BPAbs = 0`: current PCR is valid zero, but it cannot serve as the denominator for the next Observation's PCR change.
- previous Close must be finite and greater than zero.
- previous PCR must be finite and greater than zero.
- all required raw values and resulting metrics must be finite; NaN/Infinity is prohibited.
- percentages are retained at sufficient precision for comparison and rounded only for display.

`PreviousObservationDate` is the most recent prior valid aggregate. If it is not the immediately preceding expected exchange session, set `DATA_GAP=true` and quality `BLOCKED`. Metrics may still be calculated for research and shown with the actual multi-session gap.

## Causal rolling cohort

For current Observation D:

- use at most the previous 60 valid aggregated Observations;
- exclude D;
- include only rows with finite historical `abs(CloseChangePct)`, `SCAbs`, and `SPShare` and no blocking source issue;
- use the same cohort for all ranks;
- set `HistoryCount` to its size;
- require at least 20 for every percentile-dependent rule.

Ranks use empirical weak rank with ties included:

```text
CloseMoveAbsPct60 = count(history abs(CloseChangePct) <= current abs(CloseChangePct)) / HistoryCount
SCAbsPct60        = count(history SCAbs <= current SCAbs) / HistoryCount
SPSharePct60      = count(history SPShare <= current SPShare) / HistoryCount
```

No full-dataset, centered, or current-row-inclusive percentile is allowed.

## Ordered rules

First match wins:

| Priority | Classification | Condition | Direction | Confidence | Action | Horizon |
|---:|---|---|---|---|---|---|
| 1 | `STRONG_BEARISH_CONTINUATION` | normal/flat exception expression above, history `>=20`, move rank `<=0.50` | SHORT | HIGH | PLAN_ENTRY | D1 |
| 2 | `STRONG_BULLISH_CONFIRMATION` | close change `>0.10`, PCR change `<-5`, history `>=20`, SC rank `<=0.40` | LONG | HIGH | PLAN_ENTRY | D2 |
| 3 | `STRONG_BEARISH_DIVERGENCE` | close change `>0.10`, PCR change `>5`, history `>=20`, SP-share rank `>=0.65` | SHORT | MEDIUM_HIGH | PLAN_ENTRY | D2 |
| 4 | `BULLISH_CONFIRMATION` | close change `>0.10`, PCR change `<-5`, history `>=20`, SC rank `>0.40` | LONG | MEDIUM | WATCH | none |
| 5 | `BEARISH_DIVERGENCE` | close change `>0.10`, PCR change `>5`, history `>=20`, SP-share rank `<0.65` | SHORT | LOW_MEDIUM | WATCH | none |
| 6 | `REVERSAL_WATCH` | close change `<0`, PCR change `<-5`, history `>=20`, move rank `>0.50` | NONE | LOW | WATCH | none |
| 7 | `NO_EDGE` | close change `<0`, PCR change `>5` | NONE | NONE | NONE | none |
| 8 | `NO_SIGNAL` | no prior rule matched | NONE | NONE | NONE | none |

At close change exactly `+0.10`, neither the `>0.10` rules nor flat `<0.10` exception matches. At close change zero, the flat exception may match when PCR change is `<-20`. This is deliberate and must have fixtures.

If quality is blocked after a research classification is calculable, persist `research_classification` in metrics, set operational Action to `WATCH` for an otherwise actionable/watch classification (or `NONE` for no-edge/no-signal), and emit one data-quality warning. Never create a plan.

## Detection and entry

- Evaluation target: 03:30 ET on D1; due window through 03:50.
- An optional 03:25 `DATA_CHECK` may record readiness, but a failed early check is not a second Signal and does not change the canonical 03:30 evaluation identity.
- Persist a daily Report Snapshot for every evaluation.
- Strong classes create one `WAITING_ENTRY` plan and DETECTED notification when no conflicting active META plan exists.
- Watch classes send one watch notification.
- No Edge/No Signal persist only.
- Entry target: 04:00 ET; accept the first fresh positive IB real-time last-trade quote timestamped at/after 04:00 and no later than 04:05.
- If data becomes blocked, source is corrected without approval, a conflicting plan exists, or no eligible quote arrives by 04:05, cancel before entry and notify once with the reason/report.
- Entry records one normalized share, exact quote/timestamp, Signal ID, Observation date, classification, and target exit session.
- Duplicate heartbeat/quote processing must reuse the same ENTER event and notification.

The runtime records paper/manual state only and does not call an IB order method.

## Monitoring and exits

Monitor active plans every minute through the generic heartbeat using a fresh positive IB last-trade quote. A quote older than the configured freshness limit is unavailable, not a price.

Directional returns:

```text
SHORT = 100 * (EntryPrice - CurrentPrice) / EntryPrice
LONG  = 100 * (CurrentPrice - EntryPrice) / EntryPrice
```

For `STRONG_BEARISH_CONTINUATION`:

- TP when short return `>= +1.0%` (`CurrentPrice <= EntryPrice * 0.99`);
- SL when short return `<= -1.5%` (`CurrentPrice >= EntryPrice * 1.015`);
- otherwise time exit five minutes before D1 regular-session close.

For `STRONG_BULLISH_CONFIRMATION` and `STRONG_BEARISH_DIVERGENCE`:

- no signal-specific TP/SL;
- reminder 15 minutes before regular-session close on D2 (normally 15:45);
- time exit five minutes before close on D2 (normally 15:55).

The reminder's catch-up window ends when the exit becomes due; never send a stale reminder at or after the exit effective time. The time-exit quote recovery window ends at the official regular-session close. After that, retain an overdue active plan and escalate for operator resolution.

Each transition is atomic and idempotent. Once terminal, all later exit attempts are no-ops. If the scheduled-exit quote is unavailable, emit one deduplicated data error, retry only inside the configured bounded recovery window, and leave the plan visibly overdue/operator-owned rather than fabricate a price or silently close it.

While a plan is active:

- a new opposite actionable Signal creates an `OPPOSING_SIGNAL` event/notification; no reversal;
- a same-direction Signal is persisted but creates no second plan/ENTER and normally no repeated signal notification;
- watch/no-edge observations do not alter the plan, and watch notifications are suppressed while the plan is active so position management remains actionable.

## Notifications and reports

| Event | Pushover policy |
|---|---|
| `NO_EDGE`, `NO_SIGNAL` | persist only |
| watch classifications | normal priority WATCH |
| strong detection | high priority DETECTED |
| entry | high priority ENTER |
| TP/SL/time exit | high priority actionable exit |
| D2 reminder | normal priority position management |
| opposing Signal | high priority review notification |
| stale/gap/bad data affecting action | high priority data warning, deduplicated |

Every delivered event links to its exact immutable HTML Report Snapshot through Task 05. Message text includes Instrument, classification/event, Direction, Confidence, Observation date, key price/PCR/rank facts, planned/actual times, horizon, and TP/SL only where validated. It does not claim the research hit rates are expected win rates.

Daily reports include raw aggregates/shares, Close/VWAP, previous dates/values, formulas/results, history cohort dates/count, causal ranks, quality issues, ordered-rule match, operational downgrade, schedule, research caveats, source/config hashes, and plan state. Lifecycle reports additionally include quote identity/freshness, entry/current/exit price, return, events, and next expected action.

## Forward validation

For every strong or watch classification, use the research-consistent D1 04:00 ET completed-bar open as the Signal Outcome reference price whether or not a plan entered. Collect D1/D2/D3/D5 close plus MFE/MAE from the validated completed intraday-bar source through each horizon. For LONG/SHORT Signals calculate directional return/excursions from that reference price. For `REVERSAL_WATCH` (`Direction=NONE`), retain raw forward close returns and raw high/low excursions while directional-return/MFE/MAE fields remain null with an explicit reason. A missing exact reference bar blocks that outcome; do not substitute the daily open or an actual later entry. Store source provenance in `SignalOutcome`.

For entered plans, separately store actual Entry/Exit prices/times, realized directional return, exit reason, and plan-specific MFE/MAE. Review the P50/P40/P65 thresholds only after a meaningful new out-of-sample sample. Any threshold or actionability change creates a new Strategy Version.

## Research evidence supplied

- Strong Bearish Continuation: approximately 18 cases, D1 directional correctness approximately 88.9%, average directional return approximately +1.12%.
- Strong Bullish Confirmation: approximately 17 cases, D2 directional correctness approximately 82.4%, average directional return approximately +1.95%.
- Strong Bearish Divergence: approximately 11 cases, D2 directional correctness approximately 81.8%, average directional short return approximately +2.15%.

These are small, research-selected samples. They justify forward paper observation, not capital deployment or a future-win-rate claim.

## Mandatory fixture set

Before activation include:

- every class in the rule table;
- both branches of Strong Bearish Continuation;
- overlap showing priority 1 wins;
- each threshold exactly/below/above: `-20`, `-5`, `0`, `0.10`, `5`, `0.40`, `0.50`, `0.65`;
- history counts 19, 20, and 60 with current-row exclusion and ties;
- missing capital type, multiple rows/type, inconsistent Close/VWAP, unexpected type, all-zero GEX, BC zero, BP zero, previous PCR zero, previous Close zero;
- missing expected session/data gap, holiday, DST, and early close;
- delayed/corrected source and no-lookahead mutation;
- fresh/stale/missing IB quote and entry-window expiry;
- duplicate DETECTED/ENTER/TP/SL/time-exit processing;
- both-hit 30-minute bar stop-first convention;
- D2 reminder/exit and opposing Signal;
- D1/D2/D3/D5 outcomes and report/notification golden facts.
