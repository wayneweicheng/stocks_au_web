# Stock Map scheduler

Register from an elevated **Sydney-time Windows host** (the runner and local backend must both be reachable from the Task Scheduler `SYSTEM` account):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Repo\stocks_au_web\scripts\stock-map\register-stock-map-scheduler.ps1" -Force
```

This replaces the old once-daily Stock Map task. It checks every five minutes **Monday–Friday, 17:00–23:45 Australia/Sydney**. The script includes the full final 23:45 minute (Task Scheduler starts a few seconds after the trigger); a manual run outside the window cannot submit jobs. Each tick checks `batch.values` in `config.json` against the Market Flow page's default **previous business day** (`/api/stock-codes?observation_date=YYYY-MM-DD&source_type=GEX`). Only eligible symbols without a **scheduler-owned** submitted, uncertain, or reported job are sent to the skill runner. A same-Sydney-day HTML report created elsewhere (for example a manual report) does not count as this scheduler's submission; the scheduler retains its job ID as `external_report_job_id` for audit and sends its own job when eligible. Actual submission attempts are spaced by `batch.delay_seconds` (30 seconds by default); skipped symbols do not add a wait. If a batch lasts longer than five minutes, overlapping Task Scheduler ticks are ignored. A new Market Flow date permits new reports.

Configure `market_flow.base_url` to the running FastAPI backend (default `http://localhost:3101`) and `runner_url` to the skill runner. `ADMIN_USERNAME`, `ADMIN_PASSWORD`, and `SKILL_RUNNER_API_TOKEN` must be available as environment variables or in `backend/.env` for the scheduled account. Do not put passwords in `config.json`. If a source or report listing is unavailable, the tick fails **without submitting**.

`logs/stock-map-scheduler/processed.json` stores observation-date/stock, submission time, job ID, and eventual HTML report confirmation. An older `reported` entry with no `submitted_at` was adopted from an external report; it is not proof of scheduler submission and is eligible again. A scheduler-owned job is reconciled only to its **own** HTML report job ID, never another same-day report. Per-run logs are alongside it. An explicit runner rejection (including HTTP errors and queue-full responses) removes the pre-submit reservation and is retried at the next eligible tick. A POST timeout or malformed success response is recorded as `uncertain` and will **not** be retried automatically because the runner may already have accepted it; check its reports/job logs before clearing that stock's state entry. Confirmed failed jobs become eligible for a retry on the next tick. Deleting the state file while jobs are pending risks duplicate submissions.

Read-only eligibility check during the window:

```powershell
C:\Repo\stocks_au_web\venv\Scripts\python.exe C:\Repo\stocks_au_web\scripts\stock-map\run-stock-map-scheduler.py --config C:\Repo\stocks_au_web\scripts\stock-map\config.json --dry-run
```
