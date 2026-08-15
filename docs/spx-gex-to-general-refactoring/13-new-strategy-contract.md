# Task 13: Publish the Research-to-Production Strategy Contract

## Objective

Create the mandatory intake contract that future research/ML work must complete before a Strategy Implementation is added. Make completeness machine-checkable while keeping behavioral rules in reviewed Python rather than inventing a generic rule engine.

## Prerequisites

- Tasks 03 and 06 are complete.
- The SPX implementation demonstrates the actual runtime Interface and source/report boundaries.
- Read [new-strategy-contract-template.md](new-strategy-contract-template.md) and [CONTEXT.md](CONTEXT.md).

## Repository and required files

Repository: `C:\Repo\stocks_collecting`

Create:

```text
docs\strategy-runtime\new-strategy-contract.md
docs\strategy-runtime\contracts\spx-gex.md
docs\strategy-runtime\contracts\meta-gex-pcr.md
src\strategy_runtime\contracts\strategy-descriptor.schema.json
src\strategy_runtime\contracts\validate_contract.py
tests\strategy_runtime\contracts\test_contract_validation.py
```

Use this packet's template as the starting point. The checked-in runtime copy becomes canonical after implementation.

## Two-layer contract

Use two complementary artifacts per strategy:

1. A Markdown research contract containing formulas, precedence, timing, edge cases, research provenance, operational policy, reports, and fixtures.
2. A small machine-readable Strategy Descriptor containing identity and bounded metadata required for registration/deployment.

The descriptor may contain:

- Strategy Code, display name, Version Code, Implementation Key;
- declared Instrument Roles;
- supported Environments;
- run kinds and named schedule requirements;
- report kinds;
- required source Adapter names;
- execution-enabled capability and outcome horizons;
- contract-format version and Markdown path/hash.

It must not contain executable Python, SQL fragments, templating code, arbitrary boolean expressions, secrets, provider credentials, or an unreviewed generic rules DSL.

## Required Markdown sections

The validator must require all template sections and reject unresolved placeholders for a contract marked `IMPLEMENTABLE`. At minimum require:

- identity/version/change rationale;
- research owner, source, sample window, sample count, selection caveats, and known limitations;
- Instrument Roles with exact market/provider identities;
- Observation date/finality and source provenance;
- exact formulas, units, null/zero behavior, rounding, and lag ordering;
- data-validity, stale-data, duplicates, gaps, and fail-closed behavior;
- causal history/window definitions and minimum sample;
- ordered Signal rules with boundary operators and fallback;
- Direction, Confidence, Action, and notification policy per class;
- schedule/due window/catch-up/calendar semantics;
- entry, monitoring, exit, overlap, occupancy, and opposing-Signal behavior;
- execution-price source and outage behavior;
- report content and immutable-link policy;
- forward outcome measurements and review cadence;
- correction/versioning policy;
- deterministic acceptance fixtures and expected outputs;
- unresolved decisions and production-approval status.

An empty section, `TBD`, contradictory unit, or unresolved item blocks `IMPLEMENTABLE` status.

## Completeness states

Support:

- `RESEARCH_DRAFT`: incomplete and not registrable;
- `REVIEW_READY`: complete enough for technical/research review but not deployable;
- `IMPLEMENTABLE`: all mandatory decisions and fixtures supplied; code may be built;
- `FORWARD_PAPER_APPROVED`: implementation passed tests and explicit approval exists;
- `RETIRED`: retained for audit, no new Deployment.

The validator checks structure and cross-field consistency; it does not assert that the research edge is valid.

## Versioning rules

A new Strategy Version is mandatory when any of these change:

- formula, input field/source meaning, lookback, threshold, operator, precedence, classification, Direction, Confidence, Action;
- entry/exit timing, catch-up policy, execution-price convention, TP/SL, holding period, occupancy, or opposing-Signal behavior;
- data-quality downgrade that can alter actionability;
- materially displayed decision explanation.

Infrastructure-only fixes may retain the Version only when golden decisions and financially meaningful report content are unchanged. Record the code commit and implementation release separately.

Research statistics may be updated without changing behavior only when stored as a dated research metadata revision and not used by classification.

## Review gates

Before `IMPLEMENTABLE`, require sign-off evidence for:

- research/data review: causality, source fidelity, sample selection, leakage, and outcome labels;
- engineering review: formulas, edge cases, scheduling, idempotency, failure policy, and fixtures;
- operations review: credentials, dependencies, monitoring, report links, Pushover level, and rollback;
- safety review: no live-order authority and no strategy can bypass Execution Book/quality gates.

One person/model may prepare multiple sections, but the handoff must identify assumptions rather than silently self-approving uncertain research semantics.

## Validator behavior

`validate_contract.py` must:

- validate descriptor JSON against the checked-in schema;
- locate and hash the referenced Markdown;
- verify mandatory headings and tables exist;
- reject placeholder markers for `IMPLEMENTABLE` or later states;
- verify every classification in the ordered rule table has Direction, Confidence, Action, notification level, and lifecycle policy;
- verify declared report/run kinds and outcome horizons use supported values;
- verify Strategy Code/Version/Implementation Key agree between descriptor and Markdown;
- report all errors in one run with stable codes;
- perform no network or database operation.

Do not make Markdown parsing so clever that formatting becomes the product. Validate durable structure and identity; enforce behavioral truth through fixture tests.

## Filled examples

- Backfill an SPX contract from the characterized/migrated behavior. It must describe both current production and shadow versions or use one file per version if clarity requires it.
- Fill META from [meta-gex-pcr-reference.md](meta-gex-pcr-reference.md). Mark it `IMPLEMENTABLE` only after the exact source object/fields/finality/timeframe semantics are verified and deterministic fixture inputs plus expected outputs are attached. Task 14 materializes those specifications as executable tests.
- Keep research result caveats and sample sizes; do not present historical rates as guarantees.

## Adding a future strategy

Document the intended change surface:

```text
contracts/<strategy>.md and descriptor
strategies/<strategy>/ implementation, private source Adapters, report template
tests/strategy_runtime/<strategy>/ golden and edge fixtures
deployment seed/configuration
one declarative registry entry
```

Adding a strategy must not require an Instrument branch in runtime, SQL schema changes for ordinary metrics, a new FastAPI route/page, or a new Pushover transport.

Schema changes are justified only by a genuinely new cross-strategy invariant, not by strategy-specific fields that fit facts/metrics/research metadata JSON.

## Tests

Cover:

- valid draft and implementable examples;
- every missing mandatory section;
- unresolved placeholder in an implementable contract;
- descriptor/Markdown identity mismatch;
- duplicate/non-ordered classifications;
- missing fallback rule;
- unknown Direction/Action/Environment/report kind;
- executable content or SQL in forbidden descriptor fields;
- contract hash change;
- SPX and META filled examples.

## Acceptance criteria

- A research model can fill the template without reading runtime internals.
- An implementation model can identify all required formulas, boundaries, source/timing rules, lifecycle behavior, and fixtures without guessing.
- Validation blocks incomplete contracts but does not pretend to validate research quality.
- SPX and META examples pass at their honest completeness states.
- Future additions use strategy-local code and declarative registration only.

## Out of scope

- A no-code strategy/rules engine.
- Automatically deploying a validated contract.
- Automatically accepting research claims.
- Live broker order specifications.
- Hiding unresolved choices behind defaults.

## Verification

```powershell
Set-Location C:\Repo\stocks_collecting
poetry run python -m strategy_runtime.contracts.validate_contract docs\strategy-runtime\contracts\spx-gex.md
poetry run python -m strategy_runtime.contracts.validate_contract docs\strategy-runtime\contracts\meta-gex-pcr.md
poetry run pytest tests\strategy_runtime\contracts -q
git diff --check
```

## Required handoff evidence

- Canonical template and descriptor schema.
- Validator error-code list and test output.
- Filled SPX and META validation reports.
- One walkthrough showing how a hypothetical new Instrument/strategy fits without core/web/schema branching.
- Explicit unresolved research or source decisions, if any.
