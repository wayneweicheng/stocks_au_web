# New Strategy Research-to-Production Contract Template

Complete every section. Use `TBD` only while status is `RESEARCH_DRAFT` or `REVIEW_READY`. A contract cannot be `IMPLEMENTABLE` while any mandatory decision or fixture remains unresolved.

## 1. Identity and status

| Field | Required value |
|---|---|
| Contract format version | `<version>` |
| Completeness status | `RESEARCH_DRAFT / REVIEW_READY / IMPLEMENTABLE / FORWARD_PAPER_APPROVED / RETIRED` |
| Strategy Code | `<stable-kebab-case-code>` |
| Display name | `<name>` |
| Version Code | `<immutable behavioral version>` |
| Implementation Key | `<registered implementation key>` |
| Research owner/source | `<person, model, notebook, report, or repository>` |
| Contract owner | `<owner>` |
| Created/reviewed date | `<ISO dates>` |
| Replaces/supersedes | `<version or none>` |
| Change rationale | `<why this version exists>` |

## 2. Research provenance and limitations

- Hypothesis and economic/market interpretation:
- Research dataset/source versions:
- Sample start/end and number of valid observations:
- Train/selection/validation/out-of-sample split:
- Label and horizon definitions:
- Transaction-cost/slippage assumptions:
- Missing/survivorship/corporate-action handling:
- Multiple-testing, feature-selection, and threshold-selection caveats:
- Stability/regime checks:
- Reported sample counts, hit rates, returns, dispersion, drawdown, and confidence intervals where available:
- Known limitations and conditions that invalidate the claim:

Historical performance must be labelled as research, not a promise.

## 3. Instrument Roles

| Role | Instrument code | Kind | Market/exchange | Currency | Provider identity/contract | Purpose |
|---|---|---|---|---|---|---|
| SUBJECT | | | | | | |
| SOURCE | | | | | | |
| EXECUTION | | | | | | |

Add PROXY/BENCHMARK roles only when used. State whether Subject and Execution are intentionally the same or different.

## 4. Source data contract

For every source provide:

| Source name | Database/API/provider | Exact object/endpoint | Required fields | Key/granularity | Source timezone | Finality rule | Freshness limit |
|---|---|---|---|---|---|---|---|
| | | | | | | | |

Also specify:

- query/filter and aggregation semantics;
- duplicate-key policy;
- missing-field/category policy;
- inconsistent-value policy;
- source revision/correction detection;
- permissions and credentials needed, without including secrets;
- expected row counts/ranges;
- provenance fields and source-content hash method;
- authoritative versus cross-check sources;
- behavior when any source is unavailable, stale, partial, or revised.

## 5. Observation semantics and data quality

- Observation market-date definition (`D`):
- Calendar and timezone:
- Processing/finality time:
- Expected previous Observation:
- Gap detection:
- Validity states (`VALID`, `WARNING`, `BLOCKED`) and exact triggers:
- Whether metrics are still calculated under each warning/block:
- Action downgrade under each issue:
- Data-error notification and deduplication:
- Correction process for revised completed data:

Never let an unstated fallback make a blocked Observation actionable.

## 6. Exact derived features

Define every feature independently. For each include formula, input fields, units, numeric type/precision, rounding point, null/zero/negative/infinite handling, and a worked example.

| Feature | Exact formula | Units/domain | Null/zero behavior | Rounding | Used by rules |
|---|---|---|---|---|---|
| | | | | | |

Specify operation order. In particular, state whether aggregation occurs before lag/window functions.

## 7. Causal history and percentiles

- Eligible historical Observation definition:
- Window length and whether current Observation is excluded:
- Minimum history:
- Missing values inside window:
- Tie/rank definition, including `<=` versus `<`:
- Whether features share one history cohort or have separate counts:
- Behavior below minimum history:
- Proof/fixture that future rows cannot change a past Signal:

## 8. Ordered Signal rules

Use explicit operators and units. Rules are evaluated top-to-bottom; first match wins.

| Priority | Classification | Complete boolean condition | Direction | Confidence | Action (`NONE/WATCH/PLAN_ENTRY`) | Holding period | Notification level |
|---:|---|---|---|---|---|---|---|
| 1 | | | | | | | |
| fallback | `NO_SIGNAL` | no prior rule matched | `NONE` | `NONE` | `NONE` | none | information/persist only |

Boundary checklist:

- exact equality at every threshold;
- overlapping conditions and precedence;
- null feature behavior;
- insufficient history;
- warning/blocked Observation downgrade;
- Direction for watch-only classifications;
- whether displayed “raw research class” differs from operational Action.

## 9. Scheduling

| Run Kind | Exchange-session relationship | Local time/timezone | Due window | Cadence | Catch-up/expiry policy |
|---|---|---|---|---|---|
| EVALUATE | | | | | |
| MONITOR | | | | | |
| SUMMARY/outcome | | | | | |

Define holiday, early-close, DST, delayed-source, repeated-heartbeat, and month-end behavior. Use exchange sessions, not weekday arithmetic.

## 10. Trade Plan and Execution Book policy

- Eligible classifications:
- Environment(s) allowed:
- Execution Book/occupancy key:
- Existing-plan conflict rule:
- Planned entry session/time and due-window expiry:
- Entry quote/bar provider, contract, field, freshness, and fallback:
- Quantity/capital/exposure calculation and rounding:
- Entry cancellation conditions:
- Broker-order authority: `NONE` for this runtime unless a separately approved project changes it.
- Slippage/fees for research and forward paper:

“Auto entry” means an idempotent paper/manual lifecycle event and notification, not an order.

## 11. Monitoring and exits

For every actionable classification:

| Classification | Monitor source/cadence | TP | SL | Scheduled exit | Price unavailable behavior | Same-bar ambiguity policy |
|---|---|---|---|---|---|---|
| | | | | | | |

Also define:

- D1/D2 session counting;
- TP/SL operator boundaries and Direction-specific return formula;
- priority when multiple exits appear crossed;
- market close/early close handling;
- reminder timing;
- opposing Signal behavior;
- process crash/retry/idempotency behavior;
- overdue active-plan recovery and operator escalation.

## 12. Notification matrix

| Domain event/classification | Recipient | Level/priority | Title/body required facts | Immutable report kind | Deduplication identity | Default send? |
|---|---|---|---|---|---|---|
| | | | | | | |

Specify DETECTED, WATCH, ENTER, TP, SL, scheduled exit, reminder, opposing Signal, cancellation, and data error as applicable. Repeated monitoring with no transition must not notify.

## 13. Report contract

- Report kinds and when generated:
- Required identity/version/Environment fields:
- Required source/provenance/data-quality facts:
- Required features and explanations:
- Signal rule/precedence explanation:
- Trade Plan/lifecycle/output facts:
- Research caveats/statistics and as-of date:
- Forward outcomes:
- HTML escaping/CSP constraints:
- Supersession/correction behavior:
- Golden report fixtures and normalization allowances:

Every user-facing notification must link to the exact immutable Report Snapshot explaining it.

## 14. Forward validation and governance

| Horizon | Exact exchange-session date | Price field/source | Directional-return formula | MFE/MAE window |
|---|---|---|---|---|
| D1 | | | | |
| D2 | | | | |
| D3 | | | | |
| D5 | | | | |

Define outcome collection for entered and non-entered Signals, review cadence, minimum new out-of-sample count, drift/data monitors, and the approval needed to change a threshold. A threshold change creates a new Strategy Version.

## 15. Failure, retry, and correction policy

- Retryable dependency failures:
- Terminal data/invariant failures:
- Normal retry identity/output reuse:
- Explicit correction trigger/reason/authorization:
- Corrected report supersession:
- Notification behavior for corrected versus already-delivered information:
- Recovery from ambiguous provider delivery:

## 16. Deterministic acceptance fixtures

List sanitized fixture files and expected output files. Include:

- one case for every classification;
- every equality/just-below/just-above threshold;
- every overlapping-rule precedence case;
- minimum-history-minus-one/exact/fully populated windows;
- missing, zero, duplicate, stale, inconsistent, gap, and revised data;
- no-lookahead mutation;
- holiday, DST, and early-close scheduling;
- duplicate evaluation/entry/exit invocations;
- quote unavailable/stale;
- all plan transitions and opposing Signal;
- notification/report content and immutable URL;
- D1/D2/D3/D5 outcomes.

For each fixture specify exact expected Classification, Direction, Confidence, Action, quality, metrics, scheduled times, events, notification types, and normalized report hash/facts.

## 17. Deployment and rollback

- Supported Environments and initial Deployment:
- Required configuration (names only):
- Database/source grants:
- Health checks and alerts:
- Historical replay/dual-run gate:
- Cutover watermark rule:
- Pre-side-effect rollback:
- Post-side-effect reconciliation:
- Explicit approver and approval record:

## 18. Unresolved decisions and declarations

List every unresolved item. For an `IMPLEMENTABLE` contract, write `None` and confirm:

- all calculations are causal and current/future execution prices are excluded from detection;
- exact source and timing semantics are known;
- every null/boundary/overlap has a declared outcome;
- no live broker order is authorized;
- research statistics are caveated;
- fixtures are attached and independently reproducible.

