# Model Builder Strategy Intake Contract

This is the contract to give to the AI strategy finder/model builder. The
model builder is responsible for supplying the complete strategy definition,
the complete signal catalogue, and the historical-performance evidence. The
runtime may verify, persist, and calculate future production outcomes, but it
must not guess missing rules or invent historical statistics.

The submission is not complete until every required section below is present.
If a value is genuinely unavailable, use `NOT_AVAILABLE` or `INSUFFICIENT`
with an explanation and the exact missing data. Never omit the field and never
fill it with a plausible-looking number.

## Deliverables

Provide all of these files in one versioned packet:

1. `strategy.md` — the human-readable research and implementation contract.
2. `strategy.descriptor.json` — the machine-readable registration descriptor.
3. `historical-performance.json` — reproducible statistics and, where
   possible, the per-instance outcome ledger.
4. `fixtures/` — small deterministic examples covering every rule branch,
   including no signal, missing data, ties, and each actionable signal.
5. `source-manifest.json` — the source tables/files, date range, revisions,
   query or extraction identity, and content hashes used to produce the
   research and performance results.

The packet must identify the exact implementation key and include enough
information for an engineer to implement the strategy without asking what a
signal name means.

## 1. Strategy identity and research provenance

Supply:

- `strategy_code` — stable immutable code, for example `META_GEX_PCR`;
- display name and concise purpose;
- semantic `version_code` and status (`RESEARCH_DRAFT`, `REVIEW_READY`,
  `IMPLEMENTABLE`, `FORWARD_PAPER_APPROVED`, or `RETIRED`);
- `implementation_key` and the strategy-local module/class entry point;
- owner, research date, change summary, and superseded version if any;
- research question, economic rationale, and known limitations;
- training/research date range, out-of-sample date range, and validation
  method;
- source snapshot identifiers and hashes;
- whether the result was selected after trying alternative rules, and how
  selection bias, survivorship bias, look-ahead bias, and multiple testing were
  controlled.

The implementation version, descriptor version, Markdown contract, and source
manifest must agree. A changed rule or changed source snapshot requires a new
strategy version.

## 2. Instruments and roles

List every instrument and its role, not just the instrument that receives the
notification:

| Role | Required information |
| --- | --- |
| `SUBJECT` | instrument code, market, exchange, currency, timezone |
| `SOURCE` | instrument/table/file providing each feature |
| `PROXY` | proxy symbol and the reason it is valid, if used |
| `EXECUTION` | the manually traded instrument and price convention |
| `BENCHMARK` | benchmark, if used for context or filtering |

State whether the strategy is `LONG`, `SHORT`, both, or `NONE` for each
signal. Specify the canonical market session, holiday calendar, daylight
saving behavior, early-close behavior, and the meaning of a market date.

## 3. Complete signal catalogue

Create one row/object for every possible emitted classification. This includes
`NO_SIGNAL`, `WATCH`, data-quality states if they are emitted as a report, and
every actionable class. Do not provide only the winning signal.

For each signal provide all of:

- stable `signal_code` and display name;
- direction: `LONG`, `SHORT`, or `NONE`;
- confidence and how it is calculated, or `null` with a reason;
- action: `NONE`, `WATCH`, or `PLAN_ENTRY`;
- notification level and whether notification is allowed in production;
- plain-language definition;
- exact Boolean trigger expression, with all variables and units;
- ordered precedence when more than one rule is true;
- entry/reference-bar rule and the price used (`open`, `close`, midpoint,
  next bar, or another explicitly defined value);
- exact holding horizon (`D1`, `D2`, `D3`, `D5`, or a custom duration);
- every exit condition: scheduled exit, take-profit, stop-loss, opposing
  signal, cancellation, stale-data cancellation, and end-of-data behavior;
- tie, boundary, same-bar TP/SL, gap, missing-bar, and partial-session rules;
- whether it creates a report, a paper plan, and/or a notification.

The rule table must be executable, not prose-only:

| Priority | Signal | Trigger predicate | Direction | Action | Entry | Exit | Notify |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `...` | exact expression | `LONG`/`SHORT`/`NONE` | `...` | exact rule | exact rule | yes/no |

Explicitly state what happens if no row matches. Usually that row is
`NO_SIGNAL` with `NONE` action and no notification.

## 4. Causal feature and formula specification

For every feature and derived value provide:

- source column/table and query identity;
- formula in notation that an engineer can translate directly into code;
- units, scale, sign convention, rounding, and null behavior;
- lookback window and minimum number of observations;
- whether the current bar/day is included or excluded;
- threshold/quantile calculation and tie behavior;
- treatment of duplicate, late, corrected, stale, or contradictory rows;
- the exact as-of timestamp used for each input;
- proof that no future bar, future open interest, future close, or revised
  value leaks into a decision.

Include worked examples for at least one true and one false evaluation of every
actionable rule. If a feature is not available at the decision time, it cannot
be used by that signal.

## 5. Upstream data and refresh gate

Define the data-readiness contract used by the two-minute runtime heartbeat:

- required source tables/files and columns;
- source database/schema and query/extraction identity;
- expected completed-session date;
- exact refresh marker proving that the day's source data is complete (for
  example the GEX open-interest revision/update marker used by Market Flow);
- all component-row completeness checks, not merely one latest-row check;
- timezone normalization and market calendar;
- behavior while data is absent, stale, partial, or revised;
- source revision/hash used in idempotency.

Before the refresh gate passes, the runtime must return `NOT_READY`: it must
create no observation, signal, report, plan, or notification. `NOT_READY` is
not `NO_SIGNAL`. After the gate passes, the runtime produces the report for
both a true/actionable result and a false/non-actionable result, but sends a
notification only for the contract's actionable signals.

Repeated heartbeats for the same instrument/date/source revision must be
idempotent. State exactly what source change constitutes a new revision and
requires re-evaluation.

## 6. Historical performance evidence — required from the model builder

For every actionable signal, provide statistics separately from other signals.
At minimum include:

- `status`: `AVAILABLE`, `NOT_AVAILABLE`, or `INSUFFICIENT`;
- as-of timestamp and source date range;
- eligible sample definition and total eligible days;
- number of signal instances;
- number of wins, losses, and unresolved/excluded cases;
- win rate percentage and its denominator;
- gross profit, gross loss, and profit factor, with the return/cost units;
- average and median return, if available;
- holding-period distribution and maximum adverse/favourable excursion, if
  available;
- direction, entry rule, exit rule, costs, slippage, and position sizing used;
- whether simultaneous signals, repeated same-day signals, and overlapping
  positions were included or suppressed;
- whether the statistics are for all rule candidates or only hypothetical
  entered signals;
- confidence interval or sample-size caveat;
- backtest engine/version and source snapshot hash;
- a reference to the per-instance ledger.

The per-instance ledger should contain one record per candidate:

```json
{
  "signal_code": "REVERSAL_GREEN",
  "market_date": "2026-08-11",
  "direction": "LONG",
  "triggered": true,
  "entry_timestamp": "2026-08-11T10:00:00+10:00",
  "entry_price": 123.45,
  "exit_timestamp": "2026-08-13T16:00:00+10:00",
  "exit_price": 125.67,
  "exit_reason": "D2_CLOSE",
  "return_pct": 1.7983,
  "source_revision": "<source revision>",
  "source_hash": "<sha256>"
}
```

Do not report a win rate or profit factor without stating its denominator and
its treatment of unresolved instances. Do not use “awaiting manual exit” for
research results. Research results use historical market prices and the
contracted exit rule; they do not depend on a human entering a broker order.

If the model builder cannot provide the evidence or ledger, the descriptor
must say `NOT_AVAILABLE`/`INSUFFICIENT` and explain why. The runtime will show
that status rather than calculate a statistic from an undocumented rule.

## 7. Async outcome and production-performance contract

Define how a triggered production notification is evaluated later using market
history:

- required 30-minute (or finer) source instrument and columns;
- exact reference/entry price rule;
- exact terminal exit rule and horizon;
- required bars and the condition for `PENDING`;
- gap, missing-bar, market-closed, correction, and opposing-signal behavior;
- return formula, costs, slippage, and direction convention;
- source revision/hash and calculation version.

The asynchronous outcome worker must remain `PENDING` until all required bars
exist, then persist one idempotent finalized outcome. It must never read
manually entered `TradePlan.Actual*` prices and must never require the user to
place or record a real trade. A source correction requires an explicit
revision; ordinary retries must not mutate a finalized outcome.

This calculated “simulated production performance” is distinct from the
model-builder's historical research performance. The admin page must display
both with clear labels.

## 8. Production and notification policy

Current policy is notification-only:

- broker execution is permanently hard-disabled;
- a human may manually place a trade, but that is not required for outcome
  calculation;
- production enablement is per strategy deployment/version;
- notification recipient, Pushover priority, retry policy, and deduplication
  key must be specified;
- the notification must link to the immutable HTML report using its public
  report ID;
- the report link must be usable after the website has authenticated the user,
  including when opened from a Pushover notification, without a second HTTP
  Basic Auth prompt;
- notification idempotency must be stable across scheduler retries and process
  restarts.

State explicitly whether a signal is enabled in `production`, `shadow`, or
`disabled`, and what change-control evidence is required to enable it.

## 9. Report and audit requirements

Specify the report kind, title, subject, instrument, market date, source
revision, strategy/version, signal classification, decision inputs, and
human-readable explanation. The report must contain enough provenance to
explain a later notification but must not contain credentials or secrets.

Specify which events are auditable: registration, deployment toggle, source
readiness, evaluation, report creation, notification enqueue/delivery,
correction, and outcome finalization.

## 10. JSON descriptor minimum shape

The machine descriptor must contain the equivalent of this structure. The
actual packet may add fields, but may not remove required information:

```json
{
  "descriptor_format": 2,
  "strategy_code": "<STABLE_CODE>",
  "display_name": "<name>",
  "version_code": "<semver-or-version>",
  "status": "REVIEW_READY",
  "implementation_key": "<runtime implementation key>",
  "definition": {
    "purpose": "<what edge is being tested>",
    "rationale": "<economic rationale>",
    "trigger_precedence": ["<signal code in priority order>"],
    "source_refresh_gate": "<exact refresh marker and completeness rule>",
    "timezone": "Australia/Sydney",
    "calendar": "<market calendar>"
  },
  "instruments": [
    {"role": "SUBJECT", "code": "<symbol>", "market": "<market>"}
  ],
  "signal_definitions": [
    {
      "signal_code": "NO_SIGNAL",
      "display_name": "No signal",
      "direction": "NONE",
      "action": "NONE",
      "notification_level": "NONE",
      "definition": "<complete definition>",
      "trigger_condition": "<exact predicate>",
      "entry_policy": "NONE",
      "exit_conditions": [],
      "holding_period": null,
      "historical_performance": {
        "status": "AVAILABLE",
        "instances": 0,
        "win_rate_pct": null,
        "profit_factor": null,
        "wins": 0,
        "losses": 0,
        "as_of": "<timestamp>",
        "source_reference": "<ledger/hash/reference>"
      }
    }
  ],
  "production_policy": {
    "mode": "NOTIFICATION_ONLY",
    "broker_execution": "HARD_DISABLED",
    "manual_trade_required_for_outcome": false,
    "pushover": {"enabled": false, "priority": 0}
  },
  "provenance": {
    "research_window": {"start": "<date>", "end": "<date>"},
    "out_of_sample_window": {"start": "<date>", "end": "<date>"},
    "source_manifest": "source-manifest.json",
    "source_hash": "<sha256>",
    "backtest_engine_version": "<version>"
  }
}
```

The example's `NO_SIGNAL` values are placeholders for the template only. The
submitted packet must populate the real statistics or explicitly use
`NOT_AVAILABLE`/`INSUFFICIENT` with an explanation.

## 11. Acceptance checklist

The packet is accepted only when:

- every emitted signal, including fallback, has a stable definition;
- every trigger and exit condition is exact and testable;
- every variable has a source, unit, timestamp, and null/stale rule;
- the refresh gate is explicit and fail-closed;
- the historical performance status and evidence are supplied per signal;
- the instance ledger can reproduce the reported counts and statistics;
- the async outcome rule is independent of manual trades;
- production policy is notification-only and broker execution is disabled;
- fixtures cover all branches and expected idempotency behavior;
- source and implementation versions/hashes are recorded;
- unresolved decisions are listed rather than hidden in prose.

The runtime and web admin may reject the packet if any required field is
missing, contradictory, unverifiable, or silently replaced with a guess.
