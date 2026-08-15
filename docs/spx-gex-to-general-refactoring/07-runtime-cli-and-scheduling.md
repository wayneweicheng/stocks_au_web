# Task 07: Add the Runtime CLI and Windows Scheduling Contract

## Objective

Provide a short-lived command-line application that safely discovers and processes due strategy work. Define the Windows Task Scheduler deployment without registering or enabling a production task in this implementation task.

## Prerequisites

- Tasks 04 and 06 are complete.
- The runtime can execute SPX through the SQL Server store in an integration environment.
- Production connection names and service-account conventions have been identified without copying secrets into source control.

## Repository and required files

Repository: `C:\Repo\stocks_collecting`

Create or update:

```text
src\strategy_runtime\__main__.py
src\strategy_runtime\cli.py
src\strategy_runtime\bootstrap.py
src\strategy_runtime\health.py
src\strategy_runtime\run_strategy_runtime.bat
src\strategy_runtime\windows-task-template.xml
tests\strategy_runtime\test_cli.py
tests\strategy_runtime\test_run_due.py
tests\strategy_runtime\test_health.py
docs\strategy-runtime-operations.md
```

The batch and XML files live with the new application as requested. Runtime logs may be written to a configured operational directory, but not inside the source tree by default.

## Commands

Implement these command contracts:

```text
python -m strategy_runtime run-due --worker-id VALUE [--now ISO8601] [--max-runs N]
python -m strategy_runtime rerun --run-id UUID --mode RETRY
python -m strategy_runtime rerun --run-id UUID --mode CORRECTION --reason TEXT
python -m strategy_runtime health [--json]
```

Rules:

- `--now` is test/operator tooling and must require an explicit non-production acknowledgement when it differs materially from system time.
- `run-due` calculates all due deployments through the runtime Interface; the CLI contains no SPX-specific clock branches.
- `--max-runs` is bounded to prevent one heartbeat from running indefinitely.
- ordinary recovery uses `RETRY`; `CORRECTION` requires a non-empty reason and follows Task 04 revision rules.
- commands write structured logs with run/deployment IDs, but never tokens, credentials, full source payloads, or tokenized report URLs.
- process output is concise; detailed diagnostics go to the configured rotating log.

## Exit codes

Use and document stable exit codes:

| Code | Meaning |
|---:|---|
| 0 | command completed, including no due work or already-completed work |
| 2 | invalid command/configuration/operator input |
| 3 | dependency unavailable or retryable work remains |
| 4 | one or more runs reached a terminal data/strategy failure |
| 5 | invariant, schema-version, or unsafe-correction failure |

When multiple runs are attempted, return the highest-severity outcome while preserving per-run results in logs.

## Bootstrap and configuration

`bootstrap.py` is the only composition root. It may construct concrete SQL Server, calendar, provider, publishing, and strategy registry objects. Other command modules depend on Interfaces.

Configuration must come from environment variables or the repository's established secure configuration mechanism. Validate at startup:

- SQL Server database/driver and expected schema version;
- enabled Strategy Deployments resolve to registered implementation keys;
- report base URL and optional report token;
- market-data credentials/contracts required by enabled deployments;
- log directory and retention settings;
- environment safety flags, including the absence of live-order capability.

Do not put passwords or tokens in the batch file, task XML, command arguments, or checked-in `.env` files.

## `run-due` behavior

One invocation must:

1. Capture one timezone-aware system time.
2. Read enabled deployments and schedules.
3. Produce canonical due Run Requests using Task 03 scheduling semantics.
4. Attempt SQL claims in deterministic `(scheduled effective UTC, deployment key, run kind)` order.
5. Execute at most `--max-runs` claims.
6. Commit each run independently so one Strategy failure does not roll back another deployment.
7. Emit a structured invocation summary and exit.

SQL leases and fencing are authoritative. The process must remain safe if Task Scheduler starts two processes, a previous process crashes, or an operator invokes the CLI manually.

## SPX schedules

Represent the existing SPX schedule in `TradingSignal.StrategySchedule`, not Python constants or batch logic:

- data check at 03:25 America/New_York;
- daily evaluation at 03:29;
- the historical 03:31 retry is the same canonical evaluation work, not a second Strategy Run;
- monitoring every 30 minutes during the characterized 03:00-16:00 window;
- monthly summary at 16:05 according to the characterized final-session rule.

Use the exchange calendar for trading sessions, holidays, early closes, DST, and last-session-of-month determination. Document exact due windows and catch-up policies in deployment seed data.

## Windows Task Scheduler definition

Define one generic heartbeat task:

```text
Trigger: every 1 minute
Action: C:\Repo\stocks_collecting\src\strategy_runtime\run_strategy_runtime.bat run-due
Start in: C:\Repo\stocks_collecting
```

Required settings:

- run whether the service account is logged on or not;
- `StartWhenAvailable=true`;
- multiple-instance policy `IgnoreNew`;
- bounded execution time longer than a normal run but shorter than an indefinite hang;
- restart only for process-launch failures, not as a substitute for runtime retry policy;
- no interactive window;
- least-privilege service account with execute/read permissions and required database grants only.

The batch file must resolve its own absolute location, activate the configured Poetry/venv command, forward only supported arguments, preserve the Python exit code, and not calculate market time. Quote every Windows path.

Do not register, alter, or enable the actual Windows task without explicit user approval.

## Health command

Report without mutating domain state:

- schema version and database reachability;
- enabled deployments and whether implementation keys resolve;
- last successful/failed run by deployment and run kind;
- expired leases and overdue due work;
- pending/retry/unknown notification counts;
- source/provider configuration presence without testing chargeable calls by default;
- application git/version metadata.

Human output must be readable; JSON output must have a versioned shape and stable field names.

## Tests

Cover:

- no due work;
- several due deployments in deterministic order;
- duplicate/overlapping invocations;
- one failed deployment does not suppress a later deployment;
- max-runs boundary;
- same SPX evaluation identity at 03:29 and the 03:31 retry wake-up;
- downtime catch-up inside and outside due windows;
- holiday, early-close, DST, and month-end sessions;
- invalid correction/retry arguments;
- exit-code aggregation;
- secrets redacted from logs and health output;
- batch path quoting and propagation of non-zero exit codes.

## Acceptance criteria

- `python -m strategy_runtime` works from the Poetry-installed package.
- The command process exits after bounded work and contains no perpetual strategy loop.
- No strategy or Instrument name appears in CLI scheduling branches.
- Duplicate processes remain safe through database claims.
- Scheduler artifacts contain no secret and are not enabled by this task.
- Health output is sufficient to diagnose stale runs and notification backlog.

## Out of scope

- Enabling the production task.
- Disabling FastAPI's existing scheduler.
- Serving reports.
- Adding META schedules.
- Any live order command.

## Verification

```powershell
Set-Location C:\Repo\stocks_collecting
poetry run python -m strategy_runtime --help
poetry run python -m strategy_runtime health --json
poetry run pytest tests\strategy_runtime\test_cli.py tests\strategy_runtime\test_run_due.py tests\strategy_runtime\test_health.py -q
poetry run pytest tests\strategy_runtime -q
git diff --check
```

Run SQL-backed health and concurrency cases only against an explicitly designated integration database.

## Required handoff evidence

- Help output and exit-code table.
- Seeded SPX schedule rows with due/catch-up policy explanation.
- Duplicate-invocation/concurrency test output.
- Sanitized health JSON.
- The exact Task Scheduler registration command for later use, clearly marked as not executed.

