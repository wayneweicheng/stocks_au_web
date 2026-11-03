[CmdletBinding()]
param(
    [string]$TaskName = "Pegasus Stock Map",
    [string]$TaskPath = "\pegasus\",
    [string]$Launcher = "C:\Repo\stocks_au_web\scripts\stock-map\run-stock-map-scheduler.py",
    [string]$Config = "C:\Repo\stocks_au_web\scripts\stock-map\config.json",
    [string]$Python = "C:\Repo\stocks_au_web\venv\Scripts\python.exe",
    [string]$UserId = "SYSTEM",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
function Test-MissingTaskError($errorRecord) {
    # COM GetTask on a missing task can surface as FileNotFoundException
    # (0x80070002), not just COMException; method wrappers can add an inner error.
    for ($exception = $errorRecord.Exception; $null -ne $exception; $exception = $exception.InnerException) {
        if (('{0:X8}' -f $exception.HResult) -in @('80070002', '8004130F')) { return $true }
    }
    return $false
}
foreach ($file in @($Launcher, $Config, $Python)) {
    if (!(Test-Path -LiteralPath $file)) { throw "Scheduler file not found: $file" }
}

# The Task Scheduler host must use Sydney local time for Windows DST transitions.
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
        # Task does not exist yet.
    }
}

$definition = $service.NewTask(0)
$definition.RegistrationInfo.Description = "Check eligible Market Flow stocks every 5 minutes, weekdays 17:00-23:45 Sydney"
$definition.Principal.UserId = $UserId
$definition.Principal.LogonType = 5 # TASK_LOGON_SERVICE_ACCOUNT
$definition.Principal.RunLevel = 0 # limited
$definition.Settings.Enabled = $true
$definition.Settings.StartWhenAvailable = $false # missed ticks must never submit outside the window
$definition.Settings.DisallowStartIfOnBatteries = $false
$definition.Settings.StopIfGoingOnBatteries = $false
$definition.Settings.MultipleInstances = 2 # TASK_INSTANCES_IGNORE_NEW
$definition.Settings.ExecutionTimeLimit = "PT15M" # queued ticks are ignored while this batch is still running

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

# Migrate the old daily task if it was in the Task Scheduler root.
if ($normalizedTaskPath -ne "\") {
    try {
        $legacy = $service.GetFolder("\").GetTask($TaskName)
        if ($legacy) {
            $service.GetFolder("\").DeleteTask($TaskName, 0)
            Write-Host "Removed legacy root task: $TaskName"
        }
    } catch {
        if (-not (Test-MissingTaskError $_)) { throw }
        # No old root task to migrate.
    }
}
Write-Host "Registered: $normalizedTaskPath$TaskName"
Write-Host "Weekdays 17:00-23:45 Australia/Sydney, every five minutes."
Write-Host "Launcher: $Launcher"
Write-Host "State/logs: $((Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json).log_directory)"
