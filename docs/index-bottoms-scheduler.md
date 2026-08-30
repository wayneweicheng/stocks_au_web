# Scheduled index-bottom analysis

The index-bottom analysis is scheduled outside FastAPI. Windows Task Scheduler wakes a short-lived launcher every minute; the launcher decides whether the 16:30 New York weekday window is due and submits the asynchronous job directly to the Midas Touch skill runner.

## Register the task

Run PowerShell as Administrator on the Windows host that can reach the skill runner:

```powershell
Set-Location C:\Repo\stocks_au_web
powershell -ExecutionPolicy Bypass -File .\scripts\register-index-bottoms-scheduler.ps1 -Force
```

The task runs as `SYSTEM` by default. The launcher reads `SKILL_RUNNER_API_TOKEN` from the machine environment when available, or from the existing `backend\.env` file as a fallback. Do not put the token in the scheduled-task action or source control. If the task account cannot read `backend\.env`, configure `SKILL_RUNNER_API_TOKEN` as a protected machine environment variable instead.

To inspect the task:

```powershell
Get-ScheduledTask -TaskName "Pegasus Find Index Bottoms"
Get-ScheduledTask -TaskName "Pegasus Find Index Bottoms" | Get-ScheduledTaskInfo
```

## Runtime behavior

- The task wakes every minute, independent of the web application process.
- The launcher uses the IANA-equivalent Windows timezone `Eastern Standard Time`, including DST changes.
- It accepts Monday-Friday executions from 16:30 through 16:59 New York time.
- It submits one job per New York calendar date, using the canonical cutoff `YYYY-MM-DD 16:30 America/New_York`.
- The request timeout is 90 minutes.
- A lookup of existing `find-index-bottoms` jobs prevents duplicates after a retry or ambiguous network response.
- Submission state and non-sensitive diagnostics are written to `logs\index-bottoms-scheduler`.
- The launcher exits after submission; the Midas runner owns the 90-minute job execution and persists the report.

The payload submitted by the launcher is equivalent to:

```json
{
  "as_at": "2026-08-28 16:30 America/New_York",
  "timeout_minutes": 90
}
```

## Manual verification

Use dry-run mode to verify timezone and payload construction without submitting a job:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-scheduled-index-bottoms.ps1 `
  -DryRun `
  -NowUtc "2026-08-28T20:30:00Z"
```

Expected output includes `16:30 America/New_York` and `timeout_minutes` equal to `90`.
