# Scheduled Ride Bullish Momentum analysis

The Ride Bullish Momentum analysis is submitted through the shared skill-runner launcher. Windows Task Scheduler runs it daily at 21:00 Sydney time.

## Register the task

Run PowerShell as Administrator on the Windows host that can reach the skill runner. The host timezone must be Sydney time (`AUS Eastern Standard Time`):

```powershell
Set-Location C:\Repo\stocks_au_web
Get-TimeZone
powershell -ExecutionPolicy Bypass -File .\scripts\ride-bullish-momentum\register-ride-bullish-momentum-scheduler.ps1 -Force
```

The task is registered under `\pegasus\` as `Pegasus Ride Bullish Momentum` and runs as `SYSTEM` by default. The launcher reads `SKILL_RUNNER_API_TOKEN` from the machine environment or `backend\.env`.

To inspect the task:

```powershell
Get-ScheduledTask -TaskPath "\pegasus\" -TaskName "Pegasus Ride Bullish Momentum"
Get-ScheduledTask -TaskPath "\pegasus\" -TaskName "Pegasus Ride Bullish Momentum" | Get-ScheduledTaskInfo
```

## Manual dry run

```powershell
& C:\Repo\stocks_au_web\venv\Scripts\python.exe `
  .\scripts\skill-runner\run-skill-runner-job.py `
  --config .\scripts\ride-bullish-momentum\config.json `
  --dry-run `
  --now-utc "2026-08-28T11:00:00Z"
```

The launcher submits `/api/jobs/ride-bullish-momentum` with the actual current Sydney time and a 90-minute timeout.
