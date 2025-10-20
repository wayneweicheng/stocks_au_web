# Register Windows Scheduled Tasks for Stocks AU Web (Backend & Frontend)

param(
    [string]$Repo = "C:\Repo\stocks_au_web",
    [string]$EnvFile = ".\.env",
    [switch]$Force,
    [switch]$BackendInteractive
)

$ScriptRoot = Split-Path -Parent $PSCommandPath
Set-Location $ScriptRoot

function Write-Log { param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts] $Message"
}

function Load-DotEnv {
    param([string]$Path)
    $vars = @{}
    if (!(Test-Path $Path)) { throw ".env not found at $Path" }
    Get-Content -Path $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line) { return }
        if ($line.StartsWith('#')) { return }
        $idx = $line.IndexOf('=')
        if ($idx -lt 1) { return }
        $k = $line.Substring(0,$idx).Trim()
        $v = $line.Substring($idx+1).Trim()
        $v = $v.Trim('"')
        $vars[$k] = $v
    }
    return $vars
}

function New-DailyHourlyTriggers {
    param([int]$IntervalHours = 1)
    $triggers = @()
    for ($h = 0; $h -lt 24; $h += $IntervalHours) {
        $at = [datetime]::Today.AddHours($h)
        $triggers += New-ScheduledTaskTrigger -Daily -At $at
    }
    return $triggers
}

function New-TaskSettings {
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Seconds 0)
    $settings.MultipleInstances = 'IgnoreNew'
    return $settings
}

function Register-ServiceTask {
    param(
        [string]$TaskName,
        [string]$ExePath,
        [string[]]$Arguments,
        [string]$WorkingDir,
        [string]$User,
        [string]$Password,
        [switch]$Interactive
    )

    $action = New-ScheduledTaskAction -Execute $ExePath -Argument ($Arguments -join ' ') -WorkingDirectory $WorkingDir
    $triggers = @()
    $triggers += (New-DailyHourlyTriggers -IntervalHours 1)
    if ($Interactive) {
        $triggers += (New-ScheduledTaskTrigger -AtLogOn)
    } else {
        $triggers += (New-ScheduledTaskTrigger -AtStartup)
    }
    $settings = New-TaskSettings
    if ($Interactive) {
        $principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel Highest
    } else {
        $principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Password -RunLevel Highest
    }
    $task = New-ScheduledTask -Action $action -Trigger $triggers -Settings $settings -Principal $principal

    Write-Log "Registering task '$TaskName'..."
    try {
        if ($Interactive) {
            Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force:$Force -ErrorAction Stop | Out-Null
        } else {
            Register-ScheduledTask -TaskName $TaskName -InputObject $task -User $User -Password $Password -Force:$Force -ErrorAction Stop | Out-Null
        }
    } catch {
        throw "Failed to register task ${TaskName}: $($_.Exception.Message)"
    }

    # Verify presence at root
    try {
        $null = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        Write-Log "Task '$TaskName' registered in Task Scheduler Library (root)."
    } catch {
        throw "Task '${TaskName}' not found after registration."
    }
}

Write-Log "Loading credentials from $EnvFile"
$envPath = if ([System.IO.Path]::IsPathRooted($EnvFile)) { $EnvFile } else { Join-Path $ScriptRoot $EnvFile }
$envVars = Load-DotEnv -Path $envPath

if (-not $envVars.ContainsKey('SCHED_USERNAME') -or -not $envVars.ContainsKey('SCHED_PASSWORD')) {
    throw "SCHED_USERNAME and SCHED_PASSWORD must be defined in $envPath"
}
$username = $envVars['SCHED_USERNAME']
$password = $envVars['SCHED_PASSWORD']

# Resolve paths
$backendScript = Join-Path $Repo 'start-backend.ps1'
$frontendScript = Join-Path $Repo 'start-frontend.ps1'
if (!(Test-Path $backendScript)) { throw "Missing $backendScript" }
if (!(Test-Path $frontendScript)) { throw "Missing $frontendScript" }

# Build actions
$pwsh = 'powershell.exe'
$commonArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File')

Register-ServiceTask -TaskName 'StocksAU Backend' -ExePath $pwsh -Arguments ($commonArgs + @($backendScript,'-NoNewWindows','-LogPath',"$Repo\\logs")) -WorkingDir $Repo -User $username -Password $password -Interactive:$BackendInteractive
# slight stagger to avoid COM flakiness under elevation
Start-Sleep -Seconds 1
Register-ServiceTask -TaskName 'StocksAU Frontend' -ExePath $pwsh -Arguments ($commonArgs + @($frontendScript,'-NoNewWindows','-LogPath',"$Repo\\logs")) -WorkingDir $Repo -User $username -Password $password

Write-Log "All tasks registered successfully."


