# SPX Map Market Flow scheduler

Register or update the Windows Task Scheduler task from an elevated Sydney-time host:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Repo\stocks_au_web\scripts\spx-map\register-spx-map-scheduler.ps1" -Force
```

The task checks every five minutes **Monday–Friday, 17:00–23:45 Australia/Sydney**, following the Stock Map scheduler's window and missed-tick policy. Each tick requests the previous-business-day Market Flow GEX stock-code list (`/api/stock-codes?observation_date=YYYY-MM-DD&source_type=GEX`) and submits one SPX Map job when `SPXW` is present. Symbols such as `SPXW.US` are normalized to `SPXW`. If SPXW is absent or the list cannot be loaded, no job is submitted; an API failure is logged and checked again on the next tick.

A submission is remembered per Market Flow observation date in `logs/spx-map-scheduler/processed.json`. A confirmed runner job ID prevents later five-minute ticks from resubmitting. State is reserved before the POST: explicit rejection clears the reservation and may retry next tick, while a timeout or ambiguous response is retained as `uncertain` to avoid a duplicate. Review the runner and scheduler logs before manually clearing an uncertain entry. Removing the state file while a job may be pending can result in duplicate submission. A new Market Flow observation date permits a new SPX Map submission.

Configure `market_flow.base_url` in `config.json` to the FastAPI backend reachable from Task Scheduler (default `http://localhost:3101`). The scheduled account needs `ADMIN_USERNAME`, `ADMIN_PASSWORD`, and `SKILL_RUNNER_API_TOKEN` as environment variables or in `backend/.env`; do not put passwords in `config.json`. The SPX Map runner request uses `/api/jobs/spx-map` and the current Sydney as-at time.

Read-only eligibility check (only eligible during the configured weekday window):

```powershell
C:\Repo\stocks_au_web\venv\Scripts\python.exe C:\Repo\stocks_au_web\scripts\spx-map\run-spx-map-scheduler.py --config C:\Repo\stocks_au_web\scripts\spx-map\config.json --dry-run
```

Run the scheduler tests with:

```powershell
C:\Repo\stocks_au_web\venv\Scripts\python.exe C:\Repo\stocks_au_web\scripts\spx-map\test_run_spx_map_scheduler.py
```
