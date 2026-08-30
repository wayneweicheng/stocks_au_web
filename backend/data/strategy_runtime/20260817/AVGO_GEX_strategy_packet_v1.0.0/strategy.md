# AVGO GEX Capital-Type Strategy Contract

## 1. Strategy identity

- **strategy_code:** `GEX_AVGO_CAPITALTYPE`
- **display_name:** AVGO GEX Capital-Type Strategy
- **version_code:** `1.0.0`
- **implementation_key:** `gex.avgo.capital_type.v1_0_0`
- **status:** `REVIEW_READY`
- **purpose:** Use prior-session AVGO option-GEX capital-type structure to classify next-session directional opportunities; runtime is notification-only.
- **economic/research rationale:** AVGO rallies while the all-four-capital-type intent becomes even more bullish; the combination behaves as crowding/exhaustion rather than confirmation.
- **owner:** Wayne Cheng
- **research date:** 2026-08-16
- **change summary:** Initial full-period implementation contract derived from the research rules selected before this packet build. No post-packet optimization is permitted without a new version.
- **superseded strategy/version:** NOT_AVAILABLE — initial contract version.
- **research data range:** GEX 2023-09-25 through 2026-08-13; 30-minute execution data 2025-10-20 through 2026-08-14.
- **out-of-sample date range:** NOT_AVAILABLE. Rule discovery and selection inspected the same historical period. Chronological half-splits and Wilson intervals are diagnostics, not untouched OOS validation.
- **validation method:** deterministic causal backtest using D0 GEX, previous-60-only percentiles, D1 07:30 ET entry, fixed Dn close exits, complete per-instance ledger, chronological half split, Wilson 95% binomial interval.
- **known limitations:** data-snooping and multiple-testing risk; manually selected ticker universe creates selection bias; no formal survivorship-bias control; live source publication timestamp is not independently audited; historical costs/slippage are zero; 30-minute OHLC cannot reconstruct sub-bar execution.
- **source snapshot identifiers/hashes:** see `source-manifest.json`; combined source hash `5c79a3cf8de4f787043149fc199de61d082ce91a09cc2cf6fe366825d1ae457f`.
- **bias controls:** Look-ahead is prevented by excluding D0 from percentile histories and entering no earlier than D1 07:30 ET. Survivorship bias is NOT controlled because the research universe was manually selected. Data snooping and multiple testing are explicitly NOT fully controlled because rules were discovered on the available sample; therefore status is REVIEW_READY, not FORWARD_PAPER_APPROVED. Selection bias remains because tickers were chosen by the research process. Any future logic/data/exit change requires a new version.

## 2. Instruments

| Role | Code | Market | Currency | Timezone | Market-date convention | Calendar / holidays / DST / early close | Signal direction |
|---|---|---|---|---|---|---|---|
| SUBJECT | AVGO | NASDAQ | USD | America/New_York | US market date of source observation | NASDAQ regular US equity calendar; exchange holidays skipped; America/New_York DST; early close uses last regular-session bar | SHORT |
| SOURCE | AVGO option GEX capital type | internal/Drive snapshot | USD-derived GEX | America/New_York | ObservationDate = completed US session | Previous US trading session is D0; four capital types BC/BP/SC/SP required | NONE |
| EXECUTION | AVGO | NASDAQ | USD | America/New_York | D1/D2/... are US trading sessions after D0 | Exchange calendar; 07:30 premarket reference; early-close exit uses last regular bar | SHORT |
| BENCHMARK | QQQ | NASDAQ | USD | America/New_York | Same D1-to-Dn dates | Same US calendar alignment | NONE |
| PROXY | NOT_AVAILABLE | NOT_AVAILABLE | NOT_AVAILABLE | NOT_AVAILABLE | No proxy is used in this single-stock contract | NOT_AVAILABLE | NONE |

## 3. Complete signal catalogue

**Co-emission policy:** all actionable predicates are evaluated independently. If multiple predicates are true, all matching signals are emitted, ordered by the priority below; priority controls deterministic ordering and does **not** suppress a lower-priority signal. VST intentionally permits opposite-direction D1 and D5 signals from the same observation. If no predicate matches, emit exactly `NO_SIGNAL`. `NOT_READY` is a runtime gate state and creates no Observation, Signal, report, plan, or notification.

| Priority | Signal | Exact trigger | Direction | Action | Entry rule | Exit rule | Notify |
|---:|---|---|---|---|---|---|---|
| 1 | `AVGO_BULLISH_INTENT_RALLY_EXHAUSTION` | `PriceChangePct > 0.10 AND IntentRatioChangePct < -10.0` | SHORT | PLAN_ENTRY | D1 07:30 ET bar Open; signal must be ready before/reference at that time | D5 final regular-session 30m bar Close; no TP/SL | yes |
| 2 | `DATA_ERROR` | readiness passed but deterministic evaluation encounters impossible/non-finite derived state not caught by gate | NONE | NONE | none | none | no |
| 3 | `NO_SIGNAL` | no actionable/WATCH predicate true after readiness | NONE | NONE | none | none | no |

For every actionable signal: confidence is the fixed research label in the descriptor; it is **not** recalculated from live P/L. Notification level is NORMAL. WATCH signals have INFO level and no Pushover notification. `NO_SIGNAL` and `DATA_ERROR` create an authenticated immutable report after readiness, but no paper plan and no strategy Pushover notification.

**Exit semantics:** v1.0.0 uses time exits only. Take-profit = NONE. Stop-loss = NONE. Same-bar TP/SL = NOT_APPLICABLE. Opposing signals do not cancel, reverse, or modify an existing simulated outcome; each signal outcome is independent. Manual trades never change research/production outcome records. Cancellation occurs only before a planned entry if the D1 07:30 reference bar is missing/corrected invalid, the market is unexpectedly closed, or source revision invalidates the trigger. Gaps are accepted at the observed bar Open/Close; no synthetic fill is inserted. Missing required bars keep outcome PENDING. Partial sessions use the official final regular-session bar.

## 4. Feature and formula specification

Source extraction identity is the exact GEX CSV and 30-minute CSV named in `source-manifest.json`. Production must use equivalent columns and formulas; source table/database identity beyond the provided snapshots is `NOT_AVAILABLE`.

### Raw features

| Feature | File/column | Formula/meaning | Units | Scale/sign | Rounding | Null behavior | Lookback/current |
|---|---|---|---|---|---|---|---|
| Close | `AVGO-20230922-20260813.csv` / `Close` | Observation-day underlying close | USD | raw; positive price | no rounding | NOT_READY if null | D0; current D0 included |
| VWAP | `AVGO-20230922-20260813.csv` / `VWAP` | Observation-day source VWAP | USD | raw; positive price | no rounding | NOT_READY if null | D0; current D0 included |
| BCAbs | `AVGO-20230922-20260813.csv` / `GEXDelta where CapitalType=BC` | ABS(GEXDelta) | GEX-delta units | absolute; nonnegative | no rounding | NOT_READY if missing | D0; current D0 included |
| BPAbs | `AVGO-20230922-20260813.csv` / `GEXDelta where CapitalType=BP` | ABS(GEXDelta) | GEX-delta units | absolute; nonnegative | no rounding | NOT_READY if missing | D0; current D0 included |
| SCAbs | `AVGO-20230922-20260813.csv` / `GEXDelta where CapitalType=SC` | ABS(GEXDelta) | GEX-delta units | absolute; nonnegative | no rounding | NOT_READY if missing | D0; current D0 included |
| SPAbs | `AVGO-20230922-20260813.csv` / `GEXDelta where CapitalType=SP` | ABS(GEXDelta) | GEX-delta units | absolute; nonnegative | no rounding | NOT_READY if missing | D0; current D0 included |

### Derived features

- **TotalAbsGEX:** `BCAbs + BPAbs + SCAbs + SPAbs`; units=GEX-delta units; sign=as formula; lookback=D0 or previous 60 as specified; null=NOT_READY if any component missing or total=0; minimum observations=as formula; current included=D0 for non-percentile feature; tie behavior=not applicable. No feature is rounded before trigger comparison.
- **BCShare/BPShare/SCShare/SPShare:** `corresponding Abs / TotalAbsGEX`; units=fraction [0,1]; sign=as formula; lookback=D0 or previous 60 as specified; null=NOT_READY when TotalAbsGEX=0; minimum observations=as formula; current included=D0 for non-percentile feature; tie behavior=not applicable. No feature is rounded before trigger comparison.
- **BullShare:** `(BCAbs + SPAbs) / TotalAbsGEX`; units=fraction [0,1]; sign=as formula; lookback=D0 or previous 60 as specified; null=NOT_READY when TotalAbsGEX=0; minimum observations=as formula; current included=D0 for non-percentile feature; tie behavior=not applicable. No feature is rounded before trigger comparison.
- **BearShare:** `(BPAbs + SCAbs) / TotalAbsGEX`; units=fraction [0,1]; sign=as formula; lookback=D0 or previous 60 as specified; null=NOT_READY when TotalAbsGEX=0; minimum observations=as formula; current included=D0 for non-percentile feature; tie behavior=not applicable. No feature is rounded before trigger comparison.
- **NetBullShare:** `BullShare - BearShare`; units=fraction [-1,1]; sign=as formula; lookback=D0 or previous 60 as specified; null=NOT_READY when component null; minimum observations=as formula; current included=D0 for non-percentile feature; tie behavior=not applicable. No feature is rounded before trigger comparison.
- **IntentRatio:** `BearShare / BullShare`; units=ratio; sign=as formula; lookback=D0 or previous 60 as specified; null=NOT_READY when BullShare=0; minimum observations=as formula; current included=D0 for non-percentile feature; tie behavior=not applicable. No feature is rounded before trigger comparison.
- **PutCallRatio:** `BPAbs / BCAbs`; units=ratio; sign=as formula; lookback=D0 or previous 60 as specified; null=NOT_READY when BCAbs=0; minimum observations=as formula; current included=D0 for non-percentile feature; tie behavior=not applicable. No feature is rounded before trigger comparison.
- **CallBuyShare:** `BCAbs / (BCAbs + SCAbs)`; units=fraction [0,1]; sign=as formula; lookback=D0 or previous 60 as specified; null=NOT_READY when denominator=0; minimum observations=as formula; current included=D0 for non-percentile feature; tie behavior=not applicable. No feature is rounded before trigger comparison.
- **PutBuyShare:** `BPAbs / (BPAbs + SPAbs)`; units=fraction [0,1]; sign=as formula; lookback=D0 or previous 60 as specified; null=NOT_READY when denominator=0; minimum observations=as formula; current included=D0 for non-percentile feature; tie behavior=not applicable. No feature is rounded before trigger comparison.
- **GEXConcentration:** `MAX(BCShare,BPShare,SCShare,SPShare)`; units=fraction [0,1]; sign=as formula; lookback=D0 or previous 60 as specified; null=NOT_READY when component null; minimum observations=as formula; current included=D0 for non-percentile feature; tie behavior=not applicable. No feature is rounded before trigger comparison.
- **PriceChangePct:** `100 * (Close_D0 / Close_previous_complete_observation - 1)`; units=percent; sign=positive=price rose; lookback=previous complete GEX observation; null=NOT_READY if required input null; minimum observations=as formula; current included=D0 for non-percentile feature; tie behavior=not applicable. No feature is rounded before trigger comparison.
- **PCRChangePct:** `100 * (PutCallRatio_D0 / PutCallRatio_previous_complete_observation - 1)`; units=percent; sign=positive=PCR rose; lookback=previous complete GEX observation; null=NOT_READY if required input null; minimum observations=as formula; current included=D0 for non-percentile feature; tie behavior=not applicable. No feature is rounded before trigger comparison.
- **IntentRatioChangePct:** `100 * (IntentRatio_D0 / IntentRatio_previous_complete_observation - 1)`; units=percent; sign=positive=more bearish intent ratio; lookback=previous complete GEX observation; null=NOT_READY if required input null; minimum observations=as formula; current included=D0 for non-percentile feature; tie behavior=not applicable. No feature is rounded before trigger comparison.
- **VWAPDiffPct:** `100 * (Close_D0 / VWAP_D0 - 1)`; units=percent; sign=positive=close above VWAP; lookback=D0 or previous 60 as specified; null=NOT_READY if required input null; minimum observations=as formula; current included=D0 for non-percentile feature; tie behavior=not applicable. No feature is rounded before trigger comparison.
- **Momentum3Pct:** `100 * (Close_D0 / Close_three_complete_GEX_observations_ago - 1)`; units=percent; sign=positive=uptrend; lookback=D0 or previous 60 as specified; null=NOT_READY if required input null; minimum observations=as formula; current included=D0 for non-percentile feature; tie behavior=not applicable. No feature is rounded before trigger comparison.
- **ShareChange:** `Share_D0 - Share_previous_complete_observation`; units=fraction points; sign=positive=share increased; lookback=D0 or previous 60 as specified; null=NOT_READY if required input null; minimum observations=as formula; current included=D0 for non-percentile feature; tie behavior=not applicable. No feature is rounded before trigger comparison.
- **CausalPct60(metric):** `COUNT(previous 60 complete observations where metric <= current metric)/60`; units=fraction [0,1]; sign=as formula; lookback=D0 or previous 60 as specified; null=NOT_READY if required input null; minimum observations=60; current included=False; tie behavior=inclusive (<=). No feature is rounded before trigger comparison.
- **CausalAbsShockPct60(change):** `COUNT(previous 60 complete observations where ABS(change) <= ABS(current change))/60`; units=fraction [0,1]; sign=as formula; lookback=D0 or previous 60 as specified; null=NOT_READY if required input null; minimum observations=60; current included=False; tie behavior=inclusive (<=). No feature is rounded before trigger comparison.

**Duplicate rows:** for a market date, exactly one row per BC/BP/SC/SP is required in the production gate. A duplicate capital-type row is PARTIAL/ERROR and fails readiness; the backtest source snapshots contain one row per type on complete dates. **Late/corrected rows:** canonical decision-source hash covers D0 plus the prior 60 complete rows used by the decision. Any change to those rows creates a new source revision, invalidates the old evaluation, and requires reevaluation/audit. **Stale:** if the latest complete ObservationDate is not the expected previous US trading session, gate returns NOT_READY. **As-of:** decision as-of is the first scheduled runtime heartbeat at or after 07:30 America/New_York on D1 for which the gate passes. Future information cannot enter because D1 price outcomes are not read by trigger functions and percentile windows end at D-1 relative to D0.

### Worked examples

- **AVGO_BULLISH_INTENT_RALLY_EXHAUSTION TRUE:** historical ObservationDate `2025-10-24`; relevant inputs `{"IntentRatioChangePct": -20.72974104, "PriceChangePct": 2.85805571}`; predicate TRUE.
  - FALSE example: ObservationDate `2023-12-25`; inputs `{"IntentRatioChangePct": 33.35862838, "PriceChangePct": null}`; predicate FALSE.
  - Missing example: any required trigger input = NULL => NOT_READY before evaluation, not NO_SIGNAL.
  - Stale example: latest complete ObservationDate older than expected previous US session => NOT_READY.
  - Tie/quantile example: percentile uses `<=`, so a current value equal to a prior value counts as less-than-or-equal; threshold comparison itself is inclusive when written `>=`/`<=`.
  - Boundary example: strict `>`/`<` thresholds do not trigger at equality; inclusive `>=`/`<=` thresholds do trigger at equality. Exact fixture supplied in `fixtures.json`.

## 5. Data-refresh/readiness contract

- Runtime cadence: every 2 minutes. Evaluation window begins no earlier than **07:30 America/New_York on a US trading day**.
- Required GEX source snapshot/equivalent: `AVGO-20230922-20260813.csv`; columns `ObservationDate, ASXCode, GEXDelta, CapitalType, Close, VWAP`. Source database/schema: `NOT_AVAILABLE` from supplied artifacts; extraction identity is file id `1QmEYTz4VfDqJAzVRwLOj7NfDVcLm0dPU` and exact file hash in manifest.
- Required outcome source/equivalent: `AVGO-20251020-20260814.csv`; columns `TimeIntervalStart, Open, High, Low, Close, Volume, VWAP`.
- Expected completed-session date D0 = immediately previous US trading session according to the subject exchange calendar.
- Refresh marker: latest complete `ObservationDate == D0`, with exactly one BC, BP, SC, SP row, all four GEXDelta non-null, common non-null Close/VWAP, and at least 60 prior complete observations. No separate open-interest revision marker exists in the supplied data: `NOT_AVAILABLE`/not required by these rules.
- Timezone normalization: source dates are US market dates; intraday timestamps are interpreted in `America/New_York`. Runtime display timezone may be Australia/Sydney, but calendar logic is New York.
- Stale threshold: any source whose latest complete observation is older than D0 is stale. A future ObservationDate > D0 is an error and fails closed.
- Before gate passes: return `NOT_READY`; create no Observation, no Signal, no report, no trade/paper plan, no notification.
- After gate passes: create one immutable Evaluation/Observation; evaluate every signal predicate; if none match create one NO_SIGNAL record and report; if matches exist create records/report for each; create paper plan and Pushover enqueue only for PLAN_ENTRY signals.
- Idempotency revision = SHA-256 of canonical D0 plus prior-60 decision input rows. Repeated 2-minute heartbeats with the same strategy version, market date and source revision reuse the existing evaluation. Any change to D0 or any prior-60 row used by a feature changes the revision and requires reevaluation. Source corrections never silently overwrite audit history.

## 6. Historical performance

Results below use the **whole supplied executable overlap**, not only Aug-13. They are theoretical/gross because transaction costs and slippage are 0 in v1.0.0. Full reconciliation is in `historical-performance.json` and `historical-instance-ledger.csv`.
| Signal | Status | Resolved N | W-L | Win rate | Avg % | Median % | Profit factor | 95% Wilson CI |
|---|---|---:|---:|---:|---:|---:|---:|---|
| `AVGO_BULLISH_INTENT_RALLY_EXHAUSTION` | AVAILABLE | 53 | 36-17 | 67.9% | 0.93 | 1.49 | 1.46 | 54.5%–78.9% |

Win-rate denominator is resolved wins+losses only. Unresolved triggers are listed and excluded from the denominator. Signals whose required entry bar is absent are excluded rather than assigned a synthetic fill. Overlapping signal codes are counted independently. These are **research historical results**, not production simulated outcomes.

## 7. Future production outcome calculation

- Required source: `AVGO` 30-minute or finer OHLC source equivalent to `1.46`.
- Required columns: timestamp/start, Open, High, Low, Close; market date must be derivable in America/New_York.
- Entry/reference price: Open of D1 07:30 ET 30-minute bar. If this bar is absent, outcome stays PENDING and the paper plan is flagged ENTRY_BAR_MISSING; no manual price substitutes are allowed.
- Terminal exit: Close of final regular-session 30-minute bar on signal-specific D1/D2/D3/D5. Official early closes use the last regular-session bar. No TP/SL in v1.0.0.
- Outcome remains PENDING until both entry bar and terminal exit bar exist. Market-closed days do not count as Dn sessions. Missing intermediate bars do not change the terminal rule, but missing required entry/exit bars prevent finalization.
- Gap behavior: use observed Open/Close; no interpolation. Opposing signals do not modify an existing outcome. Corrections to source bars create a new outcome-source hash and explicit OUTCOME_REVISED audit event; otherwise finalized outcomes are immutable/idempotent.
- Return formula LONG = `100*(exit_price/entry_price - 1)`; SHORT = `100*(entry_price-exit_price)/entry_price`. Costs=0; slippage=0 in calculation version `gex-outcome/1.0.0`.
- Outcome worker never reads `TradePlan.Actual*`, manual order records, broker fills, or requires a broker connection. Historical research performance and production-simulated outcomes are stored separately.

## 8. Production and notification policy

- Deployment state in this packet: **SHADOW / disabled for user notification until explicit version approval**. Mode is `NOTIFICATION_ONLY`; broker execution is `HARD_DISABLED`; manual trading is optional and irrelevant to outcome calculation.
- Recipient: Wayne Cheng, resolved by runtime Pushover recipient configuration; recipient credentials/user keys are secrets and must never be rendered in report/notification.
- Pushover priority: `0` (normal). Channel is Pushover. Enabled flag defaults false in this REVIEW_READY packet.
- Title: `[GEX AVGO] {signal_code} — {market_date}`. Body: `{direction} | {holding_period} | trigger inputs {key_values} | report {report_url}`.
- Authenticated report-link format: `/reports/strategy/{strategy_code}/{version_code}/{public_report_id}`; site authentication must preserve the return URL so a user opening from Pushover lands on the immutable report after login.
- Retry: enqueue once; delivery attempts at 0, +2, +5, +15 minutes; after final failure audit NOTIFICATION_FAILED. Deduplication key = SHA-256(strategy_code|version_code|market_date|signal_code|source_revision).
- Enablement/change control: per deployment + exact strategy version. Logic/source/exit changes require a new strategy version, review, and explicit enable action. No credentials, tokens, API keys or connection strings may appear in reports.

## 9. Reports and audit

- Report kind: `GEX_STRATEGY_EVALUATION`; title: `AVGO GEX Strategy Evaluation — {market_date}`; subject/instrument `AVGO`; contains strategy/version, source revision, every signal classification, exact decision inputs, trigger evaluations, entry/exit policy, historical-context reference and provenance.
- Immutable public report id = random/opaque UUID generated once at report creation; report content is append-only/immutable. Corrections create a new report linked to the superseded report.
- Required audit events: STRATEGY_REGISTERED, DEPLOYMENT_CHANGED, STRATEGY_ENABLED, STRATEGY_DISABLED, SOURCE_NOT_READY, SOURCE_READY, EVALUATION_CREATED, SIGNAL_CLASSIFIED, REPORT_CREATED, NOTIFICATION_ENQUEUED, NOTIFICATION_DELIVERED, NOTIFICATION_FAILED, OUTCOME_PENDING, OUTCOME_FINALIZED, SOURCE_CORRECTED, OUTCOME_REVISED.

## 10. Descriptor / machine contract

The complete machine-readable contract is `strategy.descriptor.json`; its strategy logic hash is tied to the included `strategy_logic.py`. All source snapshot hashes are in `source-manifest.json`.

## 11. Acceptance criteria status

- Every emitted signal: defined — PASS.
- Exact triggers/exits/variables/readiness/idempotency: defined — PASS.
- Historical statistics and per-instance ledger: supplied — PASS, subject to sample-size/data-snooping limitations.
- Async outcomes independent of manual trades; notification-only; broker hard-disabled — PASS.
- Deterministic fixtures for signal/no-signal/readiness/boundary/idempotency/correction branches — supplied.
- Untouched out-of-sample validation: **NOT_AVAILABLE** — this is the primary reason status remains REVIEW_READY.
