[CmdletBinding()]
param(
    [string]$TaskName = "Pegasus SPX Map",
    [string]$TaskPath = "\pegasus\",
    [string]$Launcher = "C:\Repo\stocks_au_web\scripts\spx-map\run-spx-map-scheduler.py",
    [string]$Config = "C:\Repo\stocks_au_web\scripts\spx-map\config.json",
    [string]$Python = "C:\Repo\stocks_au_web\venv\Scripts\python.exe",
    [string]$UserId = "SYSTEM",
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
function Test-MissingTaskError($errorRecord) {
    for ($exception = $errorRecord.Exception; $null -ne $exception; $exception = $exception.InnerException) {
        if (('{0:X8}' -f $exception.HResult) -in @('80070002', '8004130F')) { return $true }
    }
    return $false
}
foreach ($file in @($Launcher, $Config, $Python)) {
    if (!(Test-Path -LiteralPath $file)) { throw "Scheduler file not found: $file" }
}

# Task Scheduler's host timezone must be Sydney so weekday boundaries and DST
# transitions remain aligned with the SPX Map job's current_time payload.
$sydneyTimeZoneId = "AUS Eastern Standard Time"
if ([TimeZoneInfo]::Local.Id -ne $sydneyTimeZoneId) {
    throw "Windows timezone is '$([TimeZoneInfo]::Local.Id)'. Set it to '$sydneyTimeZoneId' before registering this task."
}

$service = New-Object -ComObject Schedule.Service
$service.Connect()
$folder = $service.GetFolder("\")
$normalizedTaskPath = "\" + $TaskPath.Trim("\") + "\"
foreach ($part in $normalizedTaskPath.Trim("\").Split("\")) {
    if (!$part) { continue }
    try { $folder = $folder.GetFolder($part) }
    catch {
        if (-not (Test-MissingTaskError $_)) { throw }
        $folder = $folder.CreateFolder($part)
    }
}
if (!$Force) {
    try {
        $existing = $folder.GetTask($TaskName)
        if ($existing) { throw "Task already exists: $normalizedTaskPath$TaskName. Use -Force to update it." }
    } catch {
        if (-not (Test-MissingTaskError $_)) { throw }
    }
}

$definition = $service.NewTask(0)
$definition.RegistrationInfo.Description = "Check Market Flow GEX stock codes every 5 minutes; submit SPX Map once when SPXW appears"
$definition.Principal.UserId = $UserId
$definition.Principal.LogonType = 5 # TASK_LOGON_SERVICE_ACCOUNT
$definition.Principal.RunLevel = 0 # limited
$definition.Settings.Enabled = $true
$definition.Settings.StartWhenAvailable = $false # missed ticks must not submit outside the configured window
$definition.Settings.DisallowStartIfOnBatteries = $false
$definition.Settings.StopIfGoingOnBatteries = $false
$definition.Settings.MultipleInstances = 2 # TASK_INSTANCES_IGNORE_NEW
$definition.Settings.ExecutionTimeLimit = "PT15M" # ignore ticks while a slow check/submission is running

$trigger = $definition.Triggers.Create(3) # TASK_TRIGGER_WEEKLY
$trigger.StartBoundary = (Get-Date).Date.AddHours(17).ToString("yyyy-MM-ddTHH:mm:ss")
$trigger.DaysOfWeek = 62 # Monday=2, Tuesday=4, Wednesday=8, Thursday=16, Friday=32
$trigger.WeeksInterval = 1
$trigger.Repetition.Interval = "PT5M"
$trigger.Repetition.Duration = "PT6H46M" # 17:00, 17:05, ..., 23:45; never 23:50
$trigger.Repetition.StopAtDurationEnd = $false

$action = $definition.Actions.Create(0) # TASK_ACTION_EXEC
$action.Path = $Python
$action.Arguments = ('-B "{0}" --config "{1}"' -f $Launcher, $Config)
$action.WorkingDirectory = Split-Path -Parent $Launcher
$null = $folder.RegisterTaskDefinition($TaskName, $definition, 6, $UserId, $null, 5) # create or update

# Remove a task with the same name left at the Scheduler root by an older script.
if ($normalizedTaskPath -ne "\") {
    try {
        $legacy = $service.GetFolder("\").GetTask($TaskName)
        if ($legacy) {
            $service.GetFolder("\").DeleteTask($TaskName, 0)
            Write-Host "Removed legacy root task: $TaskName"
        }
    } catch {
        if (-not (Test-MissingTaskError $_)) { throw }
    }
}
Write-Host "Registered: $normalizedTaskPath$TaskName"
Write-Host "Weekdays 17:00-23:45 Australia/Sydney, every five minutes."
Write-Host "Checks Market Flow GEX codes for SPXW and submits at most once per observation date."
Write-Host "Launcher: $Launcher"
Write-Host "State/logs: $((Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json).processed_state_file), $((Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json).log_directory)"
