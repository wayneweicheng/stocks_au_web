# Task 01: Freeze the Existing SPX Behavior

## Objective

Create a deterministic migration baseline before moving code. The output of this task is a set of fixtures and characterization tests that describe what the current SPX implementation does, including behavior that may look unusual but is relied upon.

This task must not refactor production code.

## Prerequisites

- None. Read `README.md`, `CONTEXT.md`, and `00-target-architecture.md` before beginning.
- Both repositories must be available locally; record their initial worktree state before any fixture or test edit.

## Repositories

- Primary: `C:\Repo\stocks_au_web`
- Fixture destination: `C:\Repo\stocks_collecting\tests\strategy_runtime\fixtures\spx_legacy`

## Existing source of truth

Read these files completely before adding fixtures:

- `backend/app/spx_gex_strategy/models.py`
- `backend/app/spx_gex_strategy/calendar.py`
- `backend/app/spx_gex_strategy/data.py`
- `backend/app/spx_gex_strategy/features.py`
- `backend/app/spx_gex_strategy/portfolio.py`
- `backend/app/spx_gex_strategy/simulation.py`
- `backend/app/spx_gex_strategy/storage.py`
- `backend/app/spx_gex_strategy/report.py`
- `backend/app/spx_gex_strategy/service.py`
- `backend/app/routers/spx_gex_strategy.py`
- `backend/tests/test_spx_gex_strategy.py`

Record the current git commit and whether either worktree is dirty in the fixture manifest. Fixtures must reflect the working tree the user intends to migrate, not an assumed clean `HEAD`.

## Required implementation

### 1. Establish the current test baseline

Run the full existing SPX test module before changing tests. Record:

- command;
- number of tests;
- pass/fail result;
- skipped tests;
- runtime;
- current strategy versions from `backend/app/spx_gex_strategy/__init__.py`.

Do not update expected values merely to make the baseline pass. A failing baseline is a stop condition.

### 2. Add a deterministic fixture exporter

Add a test-support exporter under:

```text
C:\Repo\stocks_au_web\backend\tests\support\export_spx_migration_fixtures.py
```

The exporter may call public/current SPX functions, but it must not connect to production SQL Server, IB, or Pushover. Construct inputs in memory or from checked-in fixture data.

Write JSON fixtures under:

```text
C:\Repo\stocks_collecting\tests\strategy_runtime\fixtures\spx_legacy\
```

Required files:

- `manifest.json`
- `classification_cases.json`
- `lifecycle_cases.json`
- `report_cases.json`
- `notification_cases.json`
- `calendar_cases.json`

Use stable ordering and UTF-8. Do not include absolute temporary paths, current timestamps, random UUIDs, credentials, or machine names.

### 3. Classification cases

Include at least one deterministic case for each classification:

- `NO_SIGNAL`
- `INSUFFICIENT_HISTORY`
- `STRONG_YELLOW`
- `RELIABLE_YELLOW`
- `MIXED_YELLOW`
- `WEAK_YELLOW`
- `REVERSAL_GREEN`
- `NORMAL_GREEN`

Each case must include:

- raw daily GEX observations and NQ inputs;
- expected causal history count;
- expected SC/SP thresholds and percentile values;
- expected classification;
- expected `trade_allowed` and skip reason;
- expected action date and actionable timestamp;
- strategy version.

Include cases proving:

- the current Observation is excluded from rolling thresholds;
- SC classification uses the SC GEX level, not SC GEX delta;
- Yellow A/B and production/shadow classifications are deterministic;
- missing required GEX levels fail closed;
- duplicate Observation dates are rejected.

### 4. Lifecycle cases

Capture complete expected event paths for:

- Strong/Reliable Yellow entry and TP;
- Yellow entry and SL;
- Yellow time exit;
- Reversal Green dip fill;
- Reversal Green D3 fallback when the dip does not fill;
- Normal Green deferred D3 entry;
- D5 cash-close exit;
- plan skipped because its Execution Book is occupied;
- stale planned work that must not reserve exposure early;
- conservative same-bar TP/SL handling;
- missing exact action bar;
- missing QQQ quote.

Each case must state all timestamps, proxy prices, QQQ prices, expected state transitions, expected return/P&L fields, and expected terminal state.

### 5. Calendar cases

Include:

- New York standard time and daylight-saving time dates;
- a weekend;
- a US market holiday;
- an early-close session;
- D1, D2, D3, and D5 offsets;
- the 03:30 action time across DST;
- official cash-close bar selection.

Expected values must be explicit ISO-8601 timestamps with offsets.

### 6. Report cases

Generate normalized HTML for at least:

- no trades/no Signal;
- Reliable Yellow;
- Reversal Green;
- a production/shadow comparison;
- a historical report with archive links.

Normalization may replace only nondeterministic metadata such as the exact generated timestamp, report UUID, and environment-specific URL token. It must not remove financial values, classifications, explanatory wording, strategy versions, thresholds, or table rows.

For each report store:

- normalized HTML or a checked-in HTML fixture;
- SHA-256 of normalized HTML;
- required text fragments;
- prohibited text fragments;
- expected report metadata.

### 7. Notification cases

Capture title, body, priority, URL title, and immutable report URL for:

- actionable Signal;
- skipped Signal;
- pending dip event;
- D3 fallback;
- TP, SL, and time exit;
- data error;
- monthly summary.

Secrets must be represented by placeholders.

### 8. Report route cases

Add route-level characterization for:

- `/api/spx-gex/report.html` latest stored/generated behavior and token check;
- `/api/spx-gex/reports` response shape and ordering;
- `/api/spx-gex/reports/spx-gex-report-<date>-<id>.html` filename lookup;
- `/api/spx-gex/reports/<date>.html?report_id=<id>` exact legacy lookup;
- `/api/spx-gex/reports/<date>.html` date-only fallback;
- `/api/spx-gex/live-nq` dependency/error behavior.

Record which URLs are immutable and which are mutable/latest aliases. Task 08 preserves compatibility but must stop generating or fetching live strategy state inside report routes.

### 9. Manifest

`manifest.json` must include:

- source repository commit;
- dirty-worktree flag and changed-file list, if any;
- production and shadow strategy versions;
- exporter version;
- fixture generation command;
- generated file hashes;
- explicit statement that fixtures do not contain production secrets or live data.

## Tests

Add a test that reruns the exporter logic in memory and compares it with the checked-in fixtures. The test must fail with a useful field-level difference when behavior changes.

Do not assert only whole-file hashes; retain readable structural comparisons.

## Acceptance criteria

- Existing SPX tests pass before and after fixture work.
- All required classification and lifecycle cases exist.
- Fixtures contain no nondeterministic timestamps or identifiers.
- Running the exporter twice produces byte-identical JSON files.
- No production SPX module changed except a narrowly justified testability seam approved in the handoff.
- The fixture manifest identifies the exact source behavior being migrated.

## Out of scope

- Creating `strategy_runtime` production code.
- Changing SPX rules, thresholds, report wording, or notifications.
- Reading production SQL/IB data.
- Deploying database objects.

## Verification

```powershell
Set-Location C:\Repo\stocks_au_web\backend
..\venv\Scripts\python.exe -m unittest tests.test_spx_gex_strategy
..\venv\Scripts\python.exe tests\support\export_spx_migration_fixtures.py --check

Set-Location C:\Repo\stocks_collecting
poetry run pytest tests\strategy_runtime\test_spx_legacy_fixtures.py -q
git diff --check
```

## Required handoff evidence

- Baseline and final test output.
- Fixture file list and hashes.
- Source commit and worktree state.
- Any current behavior that appears questionable but was intentionally frozen.
