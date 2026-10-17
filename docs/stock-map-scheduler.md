# Scheduled Stock Map analysis

Windows Task Scheduler starts the shared skill-runner launcher daily at 21:00 Sydney time. The launcher submits one Stock Map job at a time in the order configured, waiting five minutes between API submissions.

With the default configuration, submissions occur at approximately:

| Time (Sydney) | Stock |
|---|---|
| 21:00 | QQQ |
| 21:05 | SOXL |
| 21:10 | NVDA |
| 21:15 | TSLA |
| 21:20 | MU |
| 21:25 | META |

All jobs in a batch use the batch's 21:00 `as_at` value so the reports represent a consistent snapshot. API response time can make later submission times slightly later than shown.

## Configure stocks and pacing

Edit `scripts\stock-map\config.json`:

```json
"batch": {
  "placeholder": "stock_code",
  "values": [
    "QQQ",
    "SOXL",
    "NVDA",
    "TSLA",
    "MU",
    "META"
  ],
  "delay_seconds": 300
}
```

Add, remove, or reorder symbols in `values`. `delay_seconds` controls the pause between submissions; `300` is five minutes. The Task Scheduler execution limit is two hours, so increase it in the registration script if the configured list will take longer.

## Register the task

Run PowerShell as Administrator on the Windows host that can reach the skill runner. The host timezone must be Sydney time (`AUS Eastern Standard Time`):

```powershell
Set-Location C:\Repo\stocks_au_web
Get-TimeZone
powershell -ExecutionPolicy Bypass -File .\scripts\stock-map\register-stock-map-scheduler.ps1 -Force
```

The task is registered under `\pegasus\` as `Pegasus Stock Map`, runs as `SYSTEM`, and uses `SKILL_RUNNER_API_TOKEN` from the machine environment or `backend\.env`.

To inspect the task:

```powershell
Get-ScheduledTask -TaskPath "\pegasus\" -TaskName "Pegasus Stock Map"
Get-ScheduledTask -TaskPath "\pegasus\" -TaskName "Pegasus Stock Map" | Get-ScheduledTaskInfo
```

## Manual dry run

This validates and prints every expanded payload without sending requests or waiting between items:

```powershell
& C:\Repo\stocks_au_web\venv\Scripts\python.exe `
  .\scripts\skill-runner\run-skill-runner-job.py `
  --config .\scripts\stock-map\config.json `
  --dry-run `
  --now-utc "2026-08-28T11:00:00Z"
```

Each real execution writes a timestamped log under `logs\stock-map-scheduler`. If one submission fails, the launcher records the failure, waits for the configured delay, and continues with the remaining stocks; it exits non-zero after the batch completes.
