# Scheduled SPX Map analysis

The SPX Map analysis is submitted through the shared skill-runner launcher. Windows Task Scheduler runs it daily at 19:00 Sydney time.

## Register the task

Run PowerShell as Administrator on the Windows host that can reach the skill runner. The host timezone must be Sydney time (`AUS Eastern Standard Time`):

```powershell
Set-Location C:\Repo\stocks_au_web
Get-TimeZone
powershell -ExecutionPolicy Bypass -File .\scripts\spx-map\register-spx-map-scheduler.ps1 -Force
```

The task is registered under `\pegasus\` as `Pegasus SPX Map` and runs as `SYSTEM` by default. The launcher reads `SKILL_RUNNER_API_TOKEN` from the machine environment or `backend\.env`.

To inspect the task:

```powershell
Get-ScheduledTask -TaskPath "\pegasus\" -TaskName "Pegasus SPX Map"
Get-ScheduledTask -TaskPath "\pegasus\" -TaskName "Pegasus SPX Map" | Get-ScheduledTaskInfo
```

## Manual dry run

```powershell
& C:\Repo\stocks_au_web\venv\Scripts\python.exe `
  .\scripts\skill-runner\run-skill-runner-job.py `
  --config .\scripts\spx-map\config.json `
  --dry-run `
  --now-utc "2026-08-28T09:00:00Z"
```

The launcher submits `/api/jobs/spx-map` with the actual current Sydney time and a 120-minute timeout.
