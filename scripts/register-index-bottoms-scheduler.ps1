[CmdletBinding()]
param(
    [string]$TaskName = "Pegasus Find Index Bottoms",
    [string]$Launcher = "C:\Repo\stocks_au_web\scripts\run-scheduled-index-bottoms.ps1",
    [string]$RunnerUrl = "http://192.168.20.112:3205",
    [string]$StateDirectory = "C:\Repo\stocks_au_web\logs\index-bottoms-scheduler",
    [string]$UserId = "SYSTEM",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if (!(Test-Path -LiteralPath $Launcher)) {
    throw "Scheduler launcher not found: $Launcher"
}
New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null

$powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$argumentList = @(
    "-NoLogo",
    "-NoProfile",
    "-NonInteractive",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$Launcher`"",
    "-RunnerUrl", "`"$RunnerUrl`"",
    "-StateDirectory", "`"$StateDirectory`""
)
$action = New-ScheduledTaskAction `
    -Execute $powerShell `
    -Argument ($argumentList -join " ") `
    -WorkingDirectory (Split-Path -Parent $Launcher)

# The launcher is intentionally woken frequently and performs the New York
# timezone, weekday, retry-window, and once-per-day checks itself. This avoids
# relying on the Windows host timezone or a DST-sensitive 16:30 trigger.
$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes 1) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
$settings.MultipleInstances = "IgnoreNew"

$principal = New-ScheduledTaskPrincipal `
    -UserId $UserId `
    -LogonType ServiceAccount `
    -RunLevel Limited

$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal
Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force:$Force -ErrorAction Stop | Out-Null

Write-Host "Registered scheduled task: $TaskName"
Write-Host "Runs as: $UserId"
Write-Host "Runner: $RunnerUrl"
Write-Host "Launcher: $Launcher"
Write-Host "State/logs: $StateDirectory"
Write-Host "The launcher gates execution at 16:30 America/New_York on weekdays."
