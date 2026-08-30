# Scheduled index-bottom analysis

The index-bottom analysis is scheduled outside FastAPI. Windows Task Scheduler starts the shared Python skill-runner launcher at 07:00 Sydney time on weekdays. The launcher reads the index-bottom configuration and submits the asynchronous job directly to the Midas Touch skill runner using the actual current Sydney time.

## Register the task

Run PowerShell as Administrator on the Windows host that can reach the skill runner. The host timezone must be Sydney time; verify it with `Get-TimeZone` (the expected ID is `AUS Eastern Standard Time`):

```powershell
Set-Location C:\Repo\stocks_au_web
Get-TimeZone
powershell -ExecutionPolicy Bypass -File .\scripts\index-bottoms\register-index-bottoms-scheduler.ps1 -Force
```

The task runs as `SYSTEM` by default. The launcher reads `SKILL_RUNNER_API_TOKEN` from the machine environment when available, or from the existing `backend\.env` file as a fallback. Do not put the token in the scheduled-task action or source control. If the task account cannot read `backend\.env`, configure `SKILL_RUNNER_API_TOKEN` as a protected machine environment variable instead.

The task is registered under the `\pegasus\` Task Scheduler folder. To inspect it:

```powershell
Get-ScheduledTask -TaskPath "\pegasus\" -TaskName "Pegasus Find Index Bottoms"
Get-ScheduledTask -TaskPath "\pegasus\" -TaskName "Pegasus Find Index Bottoms" | Get-ScheduledTaskInfo
```

## Runtime behavior

- The task runs Monday-Friday at 07:00 according to the Windows host's local timezone.
- Configure the Windows host timezone as **(UTC+10:00) Canberra, Melbourne, Sydney**. Windows handles the Sydney daylight-saving changes automatically.
- The launcher submits one job whenever Task Scheduler starts it; there is no retry window or date-based gating.
- `as_at` is set to the launcher's actual current time in `Australia/Sydney`.
- The request timeout is 90 minutes.
- Every launcher execution creates a separate timestamped log such as `logs\index-bottoms-scheduler\scheduler-20260830-112937-4124.log`, containing lifecycle messages (`START`, `RUN`, `SUBMIT`, `SUCCESS`, `ERROR`, and `END`).
- The launcher exits after submission; the Midas runner owns the 90-minute job execution and persists the report. Task Scheduler's own execution history can also be viewed with `Get-ScheduledTaskInfo`.

The payload submitted by the launcher is equivalent to:

```json
{
  "as_at": "2026-08-28 07:00 Australia/Sydney",
  "timeout_minutes": 90
}
```

## Manual verification

Use the shared Python launcher in dry-run mode to verify timezone and payload construction without submitting a job:

```powershell
& C:\Repo\stocks_au_web\venv\Scripts\python.exe `
  .\scripts\skill-runner\run-skill-runner-job.py `
  --config .\scripts\index-bottoms\config.json `
  --dry-run `
  --now-utc "2026-08-28T20:30:00Z"
```

Expected output includes the current `Australia/Sydney` time and `timeout_minutes` equal to `90`. A new timestamped log file is also created in `logs\index-bottoms-scheduler`.

## Historical backfill (manual, not Windows Scheduler)

To process a date range chronologically with at most two active jobs, run:

```powershell
& C:\Repo\stocks_au_web\venv\Scripts\python.exe `
  .\scripts\index-bottoms\run-index-bottoms-backfill.py `
  --start-date 2026-01-06 `
  --end-date 2026-08-27 `
  --at 17:00 `
  --max-concurrent 2
```

The backfill skips weekends, waits for an active job to finish before submitting the next one, and writes a separate timestamped `backfill-*.log` file. Existing queued, running, or successful jobs with the same `as_at` label are skipped.

## Adding another scheduled skill job

Copy `scripts\index-bottoms\config.json` to a new job directory and change its `name`, `runner_url`, `endpoint`, `payload`, and log directory. Payload values may use `{{current_time}}`, `{{current_date}}`, or `{{current_datetime}}`. Register another Windows task using the same `scripts\skill-runner\run-skill-runner-job.py` launcher and a job-specific config.
