[CmdletBinding()]
param(
    [string]$TaskName = "Pegasus Stock Map",
    [string]$TaskPath = "\pegasus\",
    [string]$Launcher = "C:\Repo\stocks_au_web\scripts\skill-runner\run-skill-runner-job.py",
    [string]$Config = "C:\Repo\stocks_au_web\scripts\stock-map\config.json",
    [string]$Python = "C:\Repo\stocks_au_web\venv\Scripts\python.exe",
    [string]$UserId = "SYSTEM",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Ensure-TaskFolder {
    param([string]$Path)

    $normalized = $Path.Trim("\")
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return
    }

    $service = New-Object -ComObject Schedule.Service
    $service.Connect()
    $folder = $service.GetFolder("\")
    foreach ($part in $normalized.Split("\")) {
        if ([string]::IsNullOrWhiteSpace($part)) { continue }
        try {
            $folder = $folder.GetFolder($part)
        } catch {
            $folder = $folder.CreateFolder($part)
        }
    }
}

if (!(Test-Path -LiteralPath $Launcher)) {
    throw "Scheduler launcher not found: $Launcher"
}
if (!(Test-Path -LiteralPath $Config)) {
    throw "Scheduler config not found: $Config"
}
if (!(Test-Path -LiteralPath $Python)) {
    throw "Python executable not found: $Python"
}
$argumentList = @(
    "-B",
    "`"$Launcher`"",
    "--config", "`"$Config`""
)
$action = New-ScheduledTaskAction `
    -Execute $Python `
    -Argument ($argumentList -join " ") `
    -WorkingDirectory (Split-Path -Parent $Launcher)

# Task Scheduler uses the Windows host's local timezone. Refuse to register
# when it is not Sydney time, otherwise the task would silently run at the
# wrong hour. Windows handles Sydney daylight-saving changes automatically.
$sydneyTimeZoneId = "AUS Eastern Standard Time"
if ([TimeZoneInfo]::Local.Id -ne $sydneyTimeZoneId) {
    throw "Windows timezone is '$([TimeZoneInfo]::Local.Id)'. Set it to '$sydneyTimeZoneId' before registering this task."
}
$firstRun = (Get-Date).Date.AddDays(1).AddHours(21)
$trigger = New-ScheduledTaskTrigger `
    -Daily `
    -At $firstRun

# Six configured submissions with five-minute gaps currently take at least
# 25 minutes. Leave headroom for adding more symbols or slow API responses.
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2)
$settings.MultipleInstances = "IgnoreNew"

$principal = New-ScheduledTaskPrincipal `
    -UserId $UserId `
    -LogonType ServiceAccount `
    -RunLevel Limited

$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal
$normalizedTaskPath = "\" + $TaskPath.Trim("\") + "\"
Ensure-TaskFolder -Path $normalizedTaskPath
Register-ScheduledTask -TaskPath $normalizedTaskPath -TaskName $TaskName -InputObject $task -Force:$Force -ErrorAction Stop | Out-Null

# Migrate a task with the same name from the Task Scheduler root.
$legacyTask = Get-ScheduledTask -TaskPath "\" -TaskName $TaskName -ErrorAction SilentlyContinue
if ($legacyTask -and $normalizedTaskPath -ne "\") {
    Unregister-ScheduledTask -TaskPath "\" -TaskName $TaskName -Confirm:$false
    Write-Host "Removed legacy root task: $TaskName"
}

Write-Host "Registered scheduled task: $normalizedTaskPath$TaskName"
Write-Host "Runs as: $UserId"
Write-Host "Python: $Python"
Write-Host "Launcher: $Launcher"
Write-Host "Config: $Config"
Write-Host "Logs are configured by: $Config"
Write-Host "Starts daily at 21:00 Sydney time. Stock Map jobs are submitted in config order with the configured delay."
