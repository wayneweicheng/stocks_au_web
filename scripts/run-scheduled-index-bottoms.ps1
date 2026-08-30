[CmdletBinding()]
param(
    [string]$RunnerUrl = "http://192.168.20.112:3205",
    [string]$StateDirectory = "",
    [int]$TimeoutMinutes = 90,
    [int]$RetryWindowMinutes = 30,
    [switch]$DryRun,
    [datetime]$NowUtc
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $PSCommandPath
$RepoRoot = (Resolve-Path (Join-Path $ScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($StateDirectory)) {
    $StateDirectory = Join-Path $RepoRoot "logs\index-bottoms-scheduler"
}

function Write-SchedulerLog {
    param([string]$Message)
    $timestamp = [DateTime]::UtcNow.ToString("o")
    $line = "[$timestamp] $Message"
    Write-Host $line
    try {
        $logPath = Join-Path $StateDirectory "scheduler.log"
        Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    } catch {
        # Logging must never prevent the scheduled submission from being attempted.
    }
}

function Get-DotEnvValue {
    param([string]$Path, [string]$Name)
    if (!(Test-Path -LiteralPath $Path)) { return "" }
    foreach ($line in Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue) {
        $trimmed = $line.Trim()
        if (!$trimmed -or $trimmed.StartsWith("#")) { continue }
        $separator = $trimmed.IndexOf("=")
        if ($separator -lt 1) { continue }
        $key = $trimmed.Substring(0, $separator).Trim()
        if ($key -ne $Name) { continue }
        return $trimmed.Substring($separator + 1).Trim().Trim('"').Trim("'")
    }
    return ""
}

function Read-State {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { return @{} }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return @{} }
        $parsed = $raw | ConvertFrom-Json
        $state = @{}
        foreach ($property in $parsed.PSObject.Properties) {
            $state[$property.Name] = $property.Value
        }
        return $state
    } catch {
        Write-SchedulerLog "State file could not be read; continuing with an empty state. Error: $($_.Exception.Message)"
        return @{}
    }
}

function Write-State {
    param([string]$Path, [hashtable]$State)
    $temporaryPath = "$Path.$PID.tmp"
    $State | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null
$mutex = New-Object System.Threading.Mutex($false, "Global\PegasusFindIndexBottomsScheduler")
$hasMutex = $false
try {
    try { $hasMutex = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $hasMutex = $true }
    if (!$hasMutex) { exit 0 }

    $effectiveNowUtc = if ($PSBoundParameters.ContainsKey("NowUtc")) {
        $NowUtc.ToUniversalTime()
    } else {
        [DateTime]::UtcNow
    }
    $newYorkZone = [TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time")
    $nowNewYork = [TimeZoneInfo]::ConvertTimeFromUtc($effectiveNowUtc, $newYorkZone)
    $scheduleDate = $nowNewYork.ToString("yyyy-MM-dd")
    $scheduledCutoff = "$scheduleDate 16:30 America/New_York"
    $windowStart = [TimeSpan]::FromHours(16.5)
    $windowEnd = $windowStart.Add([TimeSpan]::FromMinutes($RetryWindowMinutes))

    if ($nowNewYork.DayOfWeek -eq [DayOfWeek]::Saturday -or $nowNewYork.DayOfWeek -eq [DayOfWeek]::Sunday) { exit 0 }
    if ($nowNewYork.TimeOfDay -lt $windowStart -or $nowNewYork.TimeOfDay -ge $windowEnd) { exit 0 }

    $statePath = Join-Path $StateDirectory "state.json"
    $state = Read-State $statePath
    $existingState = $state[$scheduleDate]
    if ($existingState -and $existingState.status -in @("submitted", "already_exists")) { exit 0 }

    $token = $env:SKILL_RUNNER_API_TOKEN
    if ([string]::IsNullOrWhiteSpace($token)) {
        $token = Get-DotEnvValue (Join-Path $RepoRoot "backend\.env") "SKILL_RUNNER_API_TOKEN"
    }
    if ([string]::IsNullOrWhiteSpace($token)) {
        Write-SchedulerLog "ERROR: SKILL_RUNNER_API_TOKEN is not configured."
        exit 3
    }

    $headers = @{
        Authorization = "Bearer $token"
        Accept = "application/json"
    }
    $jobsUri = "$($RunnerUrl.TrimEnd('/'))/api/jobs?job_type=find-index-bottoms"
    $existingJobs = @()
    try {
        $existingJobs = @(Invoke-RestMethod -Method Get -Uri $jobsUri -Headers $headers -TimeoutSec 20)
    } catch {
        Write-SchedulerLog "Runner job lookup failed; submission will still be attempted. Error: $($_.Exception.Message)"
    }

    $existingJob = $existingJobs |
        Where-Object { $_.job_type -eq "find-index-bottoms" -and $_.label -eq $scheduledCutoff -and $_.status -in @("queued", "running", "succeeded") } |
        Select-Object -First 1
    if ($existingJob) {
        $state[$scheduleDate] = @{
            status = "already_exists"
            job_id = [string]$existingJob.job_id
            submitted_at_utc = $effectiveNowUtc.ToString("o")
            as_at = $scheduledCutoff
        }
        Write-State $statePath $state
        Write-SchedulerLog "Existing index-bottom job $($existingJob.job_id) found for $scheduledCutoff; no duplicate submitted."
        exit 0
    }

    $payload = @{
        as_at = $scheduledCutoff
        timeout_minutes = $TimeoutMinutes
    }
    if ($DryRun) {
        $payload | ConvertTo-Json -Compress | Write-Output
        exit 0
    }

    $requestParameters = @{
        Method = "Post"
        Uri = "$($RunnerUrl.TrimEnd('/'))/api/jobs/find-index-bottoms"
        Headers = $headers
        ContentType = "application/json"
        Body = ($payload | ConvertTo-Json -Compress)
        TimeoutSec = 20
    }
    $response = Invoke-RestMethod @requestParameters
    if ([string]::IsNullOrWhiteSpace([string]$response.job_id)) {
        throw "Runner response did not contain a job_id"
    }

    $state[$scheduleDate] = @{
        status = "submitted"
        job_id = [string]$response.job_id
        submitted_at_utc = $effectiveNowUtc.ToString("o")
        as_at = $scheduledCutoff
    }
    Write-State $statePath $state
    Write-SchedulerLog "Submitted index-bottom job $($response.job_id) for $scheduledCutoff with timeout ${TimeoutMinutes}m."
} catch {
    Write-SchedulerLog "ERROR: scheduled index-bottom submission failed: $($_.Exception.Message)"
    exit 3
} finally {
    if ($hasMutex) {
        try { $mutex.ReleaseMutex() } catch {}
    }
    $mutex.Dispose()
}
