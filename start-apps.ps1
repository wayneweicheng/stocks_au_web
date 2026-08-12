# Australian Stocks Web App - Auto Startup Script with Auto-Restart
# This script starts both backend (FastAPI) and frontend (Next.js) services
# Based on the enhanced template from rag_stock_announcement_processor

param(
    [int]$BackendPort = 3101,
    [int]$FrontendPort = 3100,
    [string]$LogPath = ".\logs",
    [switch]$FrontendBuild,
    [switch]$FrontendDev,
    [switch]$NoNewWindows,
    [int]$MaxRestarts = 5,
    [int]$RestartCooldown = 60,
    [int]$StartupTimeoutSeconds = 90,
    [int]$StartupHealthPollSeconds = 2
)

# Resolve script root and log path to absolute (robust for Task Scheduler)
$ScriptRoot = Split-Path -Parent $PSCommandPath
$AbsoluteLogPath = if ([System.IO.Path]::IsPathRooted($LogPath)) { $LogPath } else { Join-Path $ScriptRoot $LogPath }

# Create logs directory if it doesn't exist
if (!(Test-Path $AbsoluteLogPath)) {
    New-Item -ItemType Directory -Path $AbsoluteLogPath -Force | Out-Null
}

$LogFile = Join-Path $AbsoluteLogPath "startup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Define paths
$repo = "C:\Repo\stocks_au_web"
$backendWD = Join-Path $repo "backend"
$frontendWD = Join-Path $repo "frontend"
$python = Join-Path $repo "venv\Scripts\python.exe"
# Find npm executable
$npm = "npm"
if (Get-Command "npm.cmd" -ErrorAction SilentlyContinue) {
    $npm = "npm.cmd"
} elseif (Get-Command "npm.exe" -ErrorAction SilentlyContinue) {
    $npm = "npm.exe"
} elseif (Get-Command "npm" -ErrorAction SilentlyContinue) {
    $npm = "npm"
}
$node = "node"
if (Get-Command "node.exe" -ErrorAction SilentlyContinue) {
    $node = "node.exe"
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage
    try {
        Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
    } catch {
        # Silently ignore logging errors to prevent script interruption
    }
}

# Legacy Windows Job Object helpers; services are intentionally not assigned to a kill-on-close job
function Initialize-JobObject {
    if ($global:JobInitialized) { return }
    $csharp = @"
using System;
using System.Runtime.InteropServices;

public static class JobHelper {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr CreateJobObject(IntPtr lpJobAttributes, string lpName);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetInformationJobObject(IntPtr hJob, int JobObjectInfoClass, IntPtr lpJobObjectInfo, uint cbJobObjectInfoLength);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);

    // Structures for extended limit info
    [StructLayout(LayoutKind.Sequential)]
    public struct JOBOBJECT_BASIC_LIMIT_INFORMATION {
        public long PerProcessUserTimeLimit;
        public long PerJobUserTimeLimit;
        public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize;
        public UIntPtr MaximumWorkingSetSize;
        public uint ActiveProcessLimit;
        public long Affinity;
        public uint PriorityClass;
        public uint SchedulingClass;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct IO_COUNTERS {
        public ulong ReadOperationCount;
        public ulong WriteOperationCount;
        public ulong OtherOperationCount;
        public ulong ReadTransferCount;
        public ulong WriteTransferCount;
        public ulong OtherTransferCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION {
        public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
        public IO_COUNTERS IoInfo;
        public UIntPtr ProcessMemoryLimit;
        public UIntPtr JobMemoryLimit;
        public UIntPtr PeakProcessMemoryUsed;
        public UIntPtr PeakJobMemoryUsed;
    }

    public const int JobObjectExtendedLimitInformation = 9;
    public const uint JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000;
    public const uint PROCESS_ALL_ACCESS = 0x001F0FFF;

    public static IntPtr CreateKillOnCloseJob() {
        IntPtr hJob = CreateJobObject(IntPtr.Zero, null);
        if (hJob == IntPtr.Zero) return IntPtr.Zero;
        JOBOBJECT_EXTENDED_LIMIT_INFORMATION info = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
        info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        int length = Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
        IntPtr ptr = Marshal.AllocHGlobal(length);
        try {
            Marshal.StructureToPtr(info, ptr, false);
            if (!SetInformationJobObject(hJob, JobObjectExtendedLimitInformation, ptr, (uint)length)) {
                CloseHandle(hJob);
                return IntPtr.Zero;
            }
        } finally {
            Marshal.FreeHGlobal(ptr);
        }
        return hJob;
    }

    public static bool AddProcessToJob(IntPtr hJob, int pid) {
        IntPtr hProc = OpenProcess(PROCESS_ALL_ACCESS, false, pid);
        if (hProc == IntPtr.Zero) return false;
        try {
            return AssignProcessToJobObject(hJob, hProc);
        } finally {
            CloseHandle(hProc);
        }
    }
}
"@
    try {
        Add-Type -TypeDefinition $csharp -ErrorAction SilentlyContinue | Out-Null
        $global:JobHandle = [JobHelper]::CreateKillOnCloseJob()
        if ($global:JobHandle -ne [IntPtr]::Zero) {
            Write-Log "Job object initialized (KillOnJobClose)"
        } else {
            Write-Log "WARNING: Failed to initialize job object"
        }
    } catch {
        Write-Log "WARNING: Could not load JobHelper type: $($_.Exception.Message)"
    }
    $global:JobInitialized = $true
}

function Add-ProcessToJobObject {
    param([int]$ProcessId)
    if (-not $global:JobHandle) { return }
    try {
        $null = [JobHelper]::AddProcessToJob($global:JobHandle, $ProcessId)
    } catch { }
}

function Add-ProcessTreeToJobObject {
    param([int]$RootPid)
    try {
        $root = Get-Process -Id $RootPid -ErrorAction SilentlyContinue
        if (-not $root) { return }
        Add-ProcessToJobObject -ProcessId $RootPid
        $queue = New-Object System.Collections.Generic.Queue[System.Diagnostics.Process]
        $queue.Enqueue($root)
        while ($queue.Count -gt 0) {
            $p = $queue.Dequeue()
            $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)"
            foreach ($child in $children) {
                try {
                    $cp = Get-Process -Id $child.ProcessId -ErrorAction SilentlyContinue
                    if ($cp) {
                        Add-ProcessToJobObject -ProcessId $cp.Id
                        $queue.Enqueue($cp)
                    }
                } catch {}
            }
        }
    } catch { }
}

function Get-PortOwnerPid {
    param(
        [int]$Port,
        [int]$Attempts = 10,
        [int]$DelayMs = 300
    )

    for ($i = 0; $i -lt $Attempts; $i++) {
        try {
            $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($conn -and $conn.OwningProcess -gt 0) {
                return [int]$conn.OwningProcess
            }
        } catch { }
        Start-Sleep -Milliseconds $DelayMs
    }
    # Fallback using netstat parsing (covers cases where Get-NetTCPConnection is unreliable)
    try {
        $lines = netstat -ano -p tcp | Select-String ":$Port" | ForEach-Object { $_.ToString() }
        foreach ($line in $lines) {
            if ($line -match "LISTENING") {
                # netstat columns end with PID
                $parts = $line -split "\s+" | Where-Object { $_ -ne "" }
                $pidStr = $parts[-1]
                if ([int]::TryParse($pidStr, [ref]([int]$null))) {
                    return [int]$pidStr
                }
            }
        }
    } catch { }
    return 0
}

function Write-PidFile {
    try {
        $map = @{}
        foreach ($name in $global:ServiceProcesses.Keys) {
            $info = $global:ServiceProcesses[$name]
            $map[$name] = [pscustomobject]@{
                WrapperPid   = if ($info.Process) { $info.Process.Id } else { $null }
                Port         = $info.Port
                PortOwnerPid = $info.PortOwnerPid
                LogFile      = $info.LogFile
                StartTime    = $info.StartTime
            }
        }
        $json = $map | ConvertTo-Json -Depth 4
        $pidFilePath = Join-Path $AbsoluteLogPath "pids.json"
        Set-Content -Path $pidFilePath -Value $json -Encoding UTF8 -ErrorAction SilentlyContinue
        Write-Log "PID file written: $pidFilePath"
    } catch {
        Write-Log "Failed to write PID file: $($_.Exception.Message)"
    }
}

function Start-ServiceWithMonitoring {
    param(
        [string]$ServiceName,
        [string]$WorkingDirectory,
        [string]$Command,
        [string]$Arguments = "",
        [int]$Port = 0,
        [string]$LogFile = ""
    )

    $previousBackendErrorLogFile = $null
    $backendErrorLogFileWasSet = $false

    Write-Log "Starting $ServiceName..."

    # If a previous supervisor instance survived while this one was stopped,
    # adopt its healthy listener instead of taking the site down to restart it.
    if ($Port -gt 0) {
        $portCheck = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        if ($portCheck -and (Test-ServiceHttpHealth -ServiceName $ServiceName -Port $Port)) {
            $existingPid = Get-PortOwnerPid -Port $Port -Attempts 3 -DelayMs 200
            $existingProcess = if ($existingPid -gt 0) { Get-Process -Id $existingPid -ErrorAction SilentlyContinue } else { $null }
            if ($existingProcess) {
                Write-Log "Adopting healthy $ServiceName listener on port $Port (PID: $existingPid)"
                $global:ServiceProcesses[$ServiceName] = @{
                    Process = $existingProcess
                    Port = $Port
                    WorkingDirectory = $WorkingDirectory
                    Command = $Command
                    Arguments = $Arguments
                    LogFile = $LogFile
                    PortOwnerPid = $existingPid
                    RestartCount = 0
                    LastRestartTime = $null
                    HealthFailureCount = 0
                    StartTime = $existingProcess.StartTime
                }
                return $true
            }
        }
        if ($portCheck) {
            Write-Log "WARNING: Port $Port is already in use. $ServiceName may fail to start."
        }
    }

    try {
        # Change to working directory
        if (!(Test-Path $WorkingDirectory)) {
            Write-Log "ERROR: Working directory $WorkingDirectory does not exist for $ServiceName"
            return $false
        }

        # Store current location before changing directory
        $previousLocation = Get-Location
        Set-Location $WorkingDirectory

        if ($LogFile) {
            $errorLogFile = $LogFile -replace '\.log$', '-error.log'
            $previousBackendErrorLogFile = $env:BACKEND_ERROR_LOG_FILE
            if ($ServiceName -eq "Backend") {
                $env:BACKEND_ERROR_LOG_FILE = $errorLogFile
                $backendErrorLogFileWasSet = $true
            }
            if ($NoNewWindows) {
                $process = Start-Process -FilePath $Command -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -PassThru -NoNewWindow -RedirectStandardOutput $LogFile -RedirectStandardError $errorLogFile
            } else {
                $process = Start-Process -FilePath $Command -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -PassThru -RedirectStandardOutput $LogFile -RedirectStandardError $errorLogFile
            }
            if ($ServiceName -eq "Backend") {
                if ($null -eq $previousBackendErrorLogFile) {
                    Remove-Item Env:\BACKEND_ERROR_LOG_FILE -ErrorAction SilentlyContinue
                } else {
                    $env:BACKEND_ERROR_LOG_FILE = $previousBackendErrorLogFile
                }
            }
        } else {
            # No logging, start directly
            if ($NoNewWindows) {
                $process = Start-Process -FilePath $Command -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -PassThru -NoNewWindow
            } else {
                $process = Start-Process -FilePath $Command -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -PassThru
            }
        }

        if ($process) {
            Write-Log "$ServiceName started successfully (PID: $($process.Id))"
            # Do not place services in a kill-on-close job. If this supervisor is
            # terminated externally, the web services must remain available until
            # the next supervisor instance can take ownership.
            # Store process info for monitoring
            $global:ServiceProcesses[$ServiceName] = @{
                Process = $process
                Port = $Port
                WorkingDirectory = $WorkingDirectory
                Command = $Command
                Arguments = $Arguments
                LogFile = $LogFile
                PortOwnerPid = 0
                RestartCount = 0
                LastRestartTime = $null
                HealthFailureCount = 0
                StartTime = Get-Date
            }
            # Return to previous location
            Set-Location $previousLocation
            return $true
        } else {
            Write-Log "ERROR: Failed to start $ServiceName"
            # Return to previous location
            Set-Location $previousLocation
            return $false
        }
    }
    catch {
        if ($backendErrorLogFileWasSet) {
            if ($null -eq $previousBackendErrorLogFile) {
                Remove-Item Env:\BACKEND_ERROR_LOG_FILE -ErrorAction SilentlyContinue
            } else {
                $env:BACKEND_ERROR_LOG_FILE = $previousBackendErrorLogFile
            }
        }
        Write-Log "ERROR: Exception starting $ServiceName - $($_.Exception.Message)"
        # Ensure we return to previous location even on error
        if ($previousLocation) {
            Set-Location $previousLocation
        }
        return $false
    }
}

function Test-ServiceHealth {
    param([string]$ServiceName, [int]$Port)

    if ($Port -gt 0) {
        $client = $null
        try {
            $client = [System.Net.Sockets.TcpClient]::new()
            $connectTask = $client.ConnectAsync("127.0.0.1", $Port)
            return $connectTask.Wait(3000) -and $client.Connected
        }
        catch {
            return $false
        }
        finally {
            if ($client) {
                $client.Close()
                $client.Dispose()
            }
        }
    }
    return $true
}

function Get-ServiceHealthUri {
    param([string]$ServiceName, [int]$Port)

    if ($Port -le 0) { return $null }
    switch ($ServiceName) {
        "Backend" { return "http://127.0.0.1:$Port/healthz" }
        "Frontend" { return "http://127.0.0.1:$Port/" }
        default { return "http://127.0.0.1:$Port/" }
    }
}

function Test-ServiceHttpHealth {
    param([string]$ServiceName, [int]$Port)

    $uri = Get-ServiceHealthUri -ServiceName $ServiceName -Port $Port
    if (!$uri) { return $true }

    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $uri -Method Get -TimeoutSec 5 -ErrorAction Stop
        return $response.StatusCode -ge 200 -and $response.StatusCode -lt 400
    } catch {
        return $false
    }
}

function Wait-ServiceHealth {
    param(
        [string]$ServiceName,
        [int]$Port,
        [int]$TimeoutSeconds = $StartupTimeoutSeconds,
        [int]$PollSeconds = $StartupHealthPollSeconds
    )

    $deadline = (Get-Date).AddSeconds([Math]::Max(1, $TimeoutSeconds))
    while ((Get-Date) -lt $deadline) {
        $serviceInfo = $global:ServiceProcesses[$ServiceName]
        if ($serviceInfo -and $serviceInfo.Process -and $serviceInfo.Process.HasExited) {
            Write-Log "ERROR: $ServiceName process exited before becoming HTTP-ready (PID: $($serviceInfo.Process.Id))"
            return $false
        }

        if (Test-ServiceHttpHealth -ServiceName $ServiceName -Port $Port) {
            return $true
        }

        Start-Sleep -Seconds ([Math]::Max(1, $PollSeconds))
    }

    return $false
}

function Stop-ProcessOnPort {
    param([int]$Port, [string]$ServiceName)

    Write-Log "Checking for processes on port $Port for $ServiceName..."
    $killedAny = $false

    try {
        $connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        if ($connections) {
            foreach ($connection in $connections) {
                $processId = $connection.OwningProcess
                if ($processId -gt 0) {
                    try {
                        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
                        if ($process) {
                            Write-Log "Killing tree for $($process.ProcessName) (PID: $processId) on port $Port"
                            Start-Process -FilePath "taskkill.exe" -ArgumentList "/F","/T","/PID","$processId" -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
                            $killedAny = $true
                        }
                    }
                    catch {
                        Write-Log "Could not kill process with PID $processId on port $Port"
                    }
                }
            }
        } else {
            # Fallback to netstat parsing if Get-NetTCPConnection returned nothing
            try {
                $lines = netstat -ano -p tcp | Select-String ":$Port" | ForEach-Object { $_.ToString() }
                foreach ($line in $lines) {
                    if ($line -match "LISTENING") {
                        $parts = $line -split "\s+" | Where-Object { $_ -ne "" }
                        $pidStr = $parts[-1]
                        if ([int]::TryParse($pidStr, [ref]([int]$null))) {
                            Write-Log "Killing PID $pidStr on port $Port (fallback)"
                            Start-Process -FilePath "taskkill.exe" -ArgumentList "/F","/T","/PID","$pidStr" -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
                            $killedAny = $true
                        }
                    }
                }
            } catch {
                Write-Log "Fallback netstat check failed for port $Port"
            }
        }

        if ($killedAny) {
            Write-Log "Waiting for port $Port to be released..."
            Start-Sleep -Seconds 5
        }

        $stillInUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        if ($stillInUse) {
            Write-Log "WARNING: Port $Port may still be in use after cleanup"
        } else {
            Write-Log "Port $Port is free for $ServiceName"
        }
    }
    catch {
        Write-Log "Error checking port $Port for $ServiceName - $($_.Exception.Message)"
    }
}

function Invoke-FrontendBuild {
    Write-Log "Building frontend for production"
    $previousLocation = Get-Location
    try {
        Set-Location $frontendWD
        & $npm run build 2>&1 | ForEach-Object { Write-Log $_.ToString() }
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            Write-Log "ERROR: Frontend build failed with code $exitCode"
            exit 1
        }
    }
    finally {
        Set-Location $previousLocation
    }
    Write-Log "Frontend build completed"
}

function Restart-Service {
    param([string]$ServiceName)

    $serviceInfo = $global:ServiceProcesses[$ServiceName]

    # Check restart limits
    if ($serviceInfo.RestartCount -ge $MaxRestarts) {
        Write-Log "ERROR: $ServiceName has exceeded maximum restart limit ($MaxRestarts). Not restarting."
        return $false
    }

    # Check cooldown period
    if ($serviceInfo.LastRestartTime) {
        $timeSinceLastRestart = (Get-Date) - $serviceInfo.LastRestartTime
        if ($timeSinceLastRestart.TotalSeconds -lt $RestartCooldown) {
            Write-Log "WARNING: $ServiceName is in cooldown period. Waiting before restart..."
            return $false
        }
    }

    Write-Log "RESTARTING: $ServiceName (Attempt $($serviceInfo.RestartCount + 1)/$MaxRestarts)"

    # Clean up port if specified
    if ($serviceInfo.Port -gt 0) {
        Stop-ProcessOnPort -Port $serviceInfo.Port -ServiceName $ServiceName
        Start-Sleep -Seconds 3
    }

    # Restart the service
    $restartSuccess = Start-ServiceWithMonitoring -ServiceName $ServiceName -WorkingDirectory $serviceInfo.WorkingDirectory -Command $serviceInfo.Command -Arguments $serviceInfo.Arguments -Port $serviceInfo.Port -LogFile $serviceInfo.LogFile

    if ($restartSuccess) {
        $global:ServiceProcesses[$ServiceName].RestartCount += 1
        $global:ServiceProcesses[$ServiceName].LastRestartTime = Get-Date
        # Re-resolve port owner PID after restart
        $newPort = $global:ServiceProcesses[$ServiceName].Port
        if ($newPort -gt 0) {
            $newOwner = Get-PortOwnerPid -Port $newPort
            if ($newOwner -gt 0) {
                $global:ServiceProcesses[$ServiceName].PortOwnerPid = $newOwner
                Write-Log "$ServiceName port owner PID after restart: $newOwner"
            }
        }
        Write-PidFile
        Write-Log "SUCCESS: $ServiceName restarted successfully"
        return $true
    } else {
        Write-Log "ERROR: Failed to restart $ServiceName"
        return $false
    }
}

function Monitor-Services {
    Write-Log "Starting service monitoring loop..."

    while ($true) {
        Start-Sleep -Seconds 30

        $shouldShutdown = $false
        $serviceNames = @($global:ServiceProcesses.Keys)
        foreach ($serviceName in $serviceNames) {
            try {
                $serviceInfo = $global:ServiceProcesses[$serviceName]
                $proc = $serviceInfo.Process

                # Check if process has exited
                if ($proc.HasExited) {
                    $exitCode = $proc.ExitCode
                    $runTime = (Get-Date) - $serviceInfo.StartTime
                    Write-Log "WARNING: $serviceName has exited unexpectedly (Exit Code: $exitCode, Runtime: $($runTime.ToString('hh\:mm\:ss')))"

                    # Attempt restart
                    $restartResult = Restart-Service -ServiceName $serviceName
                    if ($restartResult) {
                        # Update start time for the new process
                        $global:ServiceProcesses[$serviceName].StartTime = Get-Date
                    } else {
                        # If we've hit max restarts, mark for shutdown so scheduler can re-launch
                        if ($global:ServiceProcesses[$serviceName].RestartCount -ge $MaxRestarts) {
                            Write-Log "ERROR: $serviceName cannot be restarted (max restarts reached). Supervisor will exit."
                            $shouldShutdown = $true
                        }
                    }
                }
                # Additional health check for services with ports
                elseif ($serviceInfo.Port -gt 0) {
                    $isHealthy = Test-ServiceHealth -ServiceName $serviceName -Port $serviceInfo.Port
                    if (-not $isHealthy) {
                        $previousFailures = if ($serviceInfo.ContainsKey("HealthFailureCount")) { [int]$serviceInfo.HealthFailureCount } else { 0 }
                        $serviceInfo.HealthFailureCount = $previousFailures + 1
                        if ($serviceInfo.HealthFailureCount -eq 3) {
                            Write-Log "WARNING: $serviceName is running but failed $($serviceInfo.HealthFailureCount) consecutive health checks on port $($serviceInfo.Port)"
                        } elseif ($serviceInfo.HealthFailureCount -gt 3) {
                            Write-Log "WARNING: $serviceName is still not responding on port $($serviceInfo.Port) after $($serviceInfo.HealthFailureCount) consecutive health checks"
                        }
                    } elseif ($serviceInfo.ContainsKey("HealthFailureCount") -and $serviceInfo.HealthFailureCount -gt 0) {
                        Write-Log "$serviceName health check recovered on port $($serviceInfo.Port) after $($serviceInfo.HealthFailureCount) failed check(s)"
                        $serviceInfo.HealthFailureCount = 0
                    }
                }
            } catch {
                Write-Log "ERROR: Monitoring error for $serviceName - $($_.Exception.Message)"
                # Never let monitoring errors terminate the supervisor
            }
        }

        if ($shouldShutdown) {
            Write-Log "One or more services failed permanently. Exiting supervisor so Task Scheduler can restart it."
            $global:ExpectedShutdown = $true
            break
        }
    }
}

function Cleanup-Processes {
    Write-Log "Cleaning up services..."
    foreach ($serviceName in $global:ServiceProcesses.Keys) {
        $proc = $global:ServiceProcesses[$serviceName].Process
        $port = $global:ServiceProcesses[$serviceName].Port
        $portOwnerPid = $global:ServiceProcesses[$serviceName].PortOwnerPid

        # Attempt to kill the port owner first (entire tree)
        if ($portOwnerPid -and $portOwnerPid -gt 0) {
            Write-Log "Stopping port-owner PID $portOwnerPid for $serviceName"
            try {
                Start-Process -FilePath "taskkill.exe" -ArgumentList "/F","/T","/PID", "$portOwnerPid" -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
            } catch { }
        }

        # Also clean up any listener on the recorded port
        if ($port -gt 0) {
            Stop-ProcessOnPort -Port $port -ServiceName $serviceName
        }

        if ($proc -and !$proc.HasExited) {
            Write-Log "Stopping $serviceName (PID: $($proc.Id))"
            try {
                # Kill the entire tree for the wrapper process as well
                Start-Process -FilePath "taskkill.exe" -ArgumentList "/F","/T","/PID", "$($proc.Id)" -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
                Wait-Process -Id $proc.Id -Timeout 5 -ErrorAction SilentlyContinue
            }
            catch {
                Write-Log "Could not stop $serviceName gracefully"
            }
        }
    }

    # Clean up PID file if it exists
    $pidFile = Join-Path $AbsoluteLogPath "pids.json"
    if (Test-Path $pidFile) {
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    }

    Write-Log "Cleanup completed."
}

# Initialize global variables
$global:ServiceProcesses = @{}
$global:ExpectedShutdown = $false

# An external task/session termination must not take healthy services down with
# it. Explicit shutdown paths set ExpectedShutdown and perform cleanup below.
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    if ($global:ExpectedShutdown) {
        Cleanup-Processes
    } else {
        Write-Log "Supervisor process exited unexpectedly; leaving managed services running."
    }
} | Out-Null

# Handle Ctrl+C and other termination signals (skip in non-interactive mode)
try {
    [Console]::TreatControlCAsInput = $false
    $null = [Console]::CancelKeyPress.Add({
        param($sender, $e)
        $e.Cancel = $true
        $global:ExpectedShutdown = $true
        Write-Host "`nReceived termination signal. Shutting down..."
        Cleanup-Processes
        exit 0
    })
} catch {
    Write-Log "Console event handling not available in this mode"
}

Write-Log "=== Australian Stocks Web App Startup Script Started ==="
Write-Log "Log file: $LogFile"
Write-Log "Backend will run on port $BackendPort"
Write-Log "Frontend will run on port $FrontendPort"
Write-Log "Max restarts per service: $MaxRestarts"
Write-Log "Restart cooldown: $RestartCooldown seconds"
Write-Log "Startup readiness timeout: $StartupTimeoutSeconds seconds"

# Keep browser API calls same-origin while letting the Next.js server proxy to
# the private FastAPI backend. Start-Process inherits these values.
$env:BACKEND_URL = "http://127.0.0.1:$BackendPort"
$env:NEXT_PUBLIC_BACKEND_URL = ""
$env:NEXT_PUBLIC_CHART_BASE_URL = "/charts"
Write-Log "Frontend proxy BACKEND_URL=$env:BACKEND_URL"

# Ensure only one supervisor instance runs
try {
    $createdNew = $false
    $global:SupervisorMutex = New-Object System.Threading.Mutex($true, "Global/StocksAUWebSupervisor", [ref]$createdNew)
    if (-not $createdNew) {
        Write-Log "Another supervisor instance is already running. Exiting."
        exit 0
    } else {
        Write-Log "Singleton mutex acquired."
    }
} catch {
    Write-Log "WARNING: Could not create/acquire singleton mutex: $($_.Exception.Message)"
}

# Log elevation state for diagnostics in scheduled task context
try {
    $isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-Log "Running elevated: $isElevated; User: $env:USERNAME"
} catch { }

# Verify required directories exist
if (!(Test-Path $repo)) {
    Write-Log "ERROR: Base directory $repo does not exist!"
    exit 1
}

if (!(Test-Path $backendWD)) {
    Write-Log "ERROR: Backend directory $backendWD does not exist!"
    exit 1
}

if (!(Test-Path $frontendWD)) {
    Write-Log "ERROR: Frontend directory $frontendWD does not exist!"
    exit 1
}

if (!(Test-Path $python)) {
    Write-Log "ERROR: Python executable not found at $python"
    Write-Log "Please ensure the virtual environment is set up correctly"
    exit 1
}

# Verify npm is available
Write-Log "Using npm executable: $npm"
if (!(Get-Command $npm -ErrorAction SilentlyContinue)) {
    Write-Log "ERROR: npm executable not found: $npm"
    Write-Log "Please ensure Node.js is installed and npm is in PATH"
    exit 1
}
if (!(Get-Command $node -ErrorAction SilentlyContinue)) {
    Write-Log "ERROR: node executable not found: $node"
    Write-Log "Please ensure Node.js is installed and node is in PATH"
    exit 1
}
$nextBin = Join-Path $frontendWD "node_modules\next\dist\bin\next"
if (!(Test-Path $nextBin)) {
    Write-Log "ERROR: Next.js CLI not found at $nextBin"
    Write-Log "Please ensure frontend dependencies are installed"
    exit 1
}

# Services are deliberately independent of the supervisor process lifecycle.
Write-Log "Service processes will survive an unexpected supervisor exit."

# Start Backend Service (FastAPI with Python virtual environment)
Write-Log "--- Starting Backend Service ---"
Stop-ProcessOnPort -Port $BackendPort -ServiceName "Backend"

# Create timestamped log file for backend
$backendLogFile = Join-Path $AbsoluteLogPath "backend-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Write-Log "Backend logs will be written to: $backendLogFile"

$backendArgs = @("-m", "uvicorn", "app.main:app", "--reload", "--reload-dir", "app", "--host", "127.0.0.1", "--port", $BackendPort, "--timeout-keep-alive", "620")
$backendSuccess = Start-ServiceWithMonitoring -ServiceName "Backend" -WorkingDirectory $backendWD -Command $python -Arguments $backendArgs -Port $BackendPort -LogFile $backendLogFile

if ($backendSuccess) {
    # Backend startup can include Uvicorn reload-process creation and database
    # initialization. Wait for the actual health endpoint instead of treating
    # an open TCP port after five seconds as the readiness deadline.
    if (Wait-ServiceHealth -ServiceName "Backend" -Port $BackendPort) {
        Write-Log "Backend HTTP health check passed on port $BackendPort"
    } else {
        Write-Log "WARNING: Backend service did not become HTTP-ready within $StartupTimeoutSeconds seconds on port $BackendPort"
    }

    # Resolve and record the port owner PID for reliable shutdown
    $backendPortOwner = Get-PortOwnerPid -Port $BackendPort
    if ($backendPortOwner -gt 0) {
        $global:ServiceProcesses["Backend"].PortOwnerPid = $backendPortOwner
        Write-Log "Backend port owner PID: $backendPortOwner"
    } else {
        Write-Log "WARNING: Could not resolve backend port owner PID"
    }
    Write-PidFile
}

Write-Log "--- Starting Frontend Service ---"
Stop-ProcessOnPort -Port $FrontendPort -ServiceName "Frontend"

# Create timestamped log file for frontend
$frontendLogFile = Join-Path $AbsoluteLogPath "frontend-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Write-Log "Frontend logs will be written to: $frontendLogFile"

$frontendCommand = $npm
# Serve the public frontend with Next.js production mode.
if ($FrontendDev) {
    Write-Log "Using Next.js development server for frontend"
    if ($FrontendPort -eq 3100) {
        $frontendArgs = @("run", "dev")
    } else {
        $frontendArgs = @("run", "dev", "--", "--port", $FrontendPort)
    }
} else {
    if ($FrontendBuild) {
        Invoke-FrontendBuild
    } else {
        Write-Log "Using existing frontend production build"
    }
    $frontendCommand = $node
    $frontendArgs = @($nextBin, "start", "-p", $FrontendPort)
}
$frontendSuccess = Start-ServiceWithMonitoring -ServiceName "Frontend" -WorkingDirectory $frontendWD -Command $frontendCommand -Arguments $frontendArgs -Port $FrontendPort -LogFile $frontendLogFile

if ($frontendSuccess) {
    # Check if the frontend process is still running
    $frontendProcess = $global:ServiceProcesses["Frontend"].Process
    if ($frontendProcess.HasExited) {
        Write-Log "ERROR: Frontend process has exited unexpectedly. Check logs for details:"
        Write-Log "Frontend log: $frontendLogFile"
    } else {
        # Next.js production startup can take 30+ seconds on this machine.
        if (Wait-ServiceHealth -ServiceName "Frontend" -Port $FrontendPort) {
            Write-Log "Frontend HTTP health check passed on port $FrontendPort"
        } else {
            Write-Log "WARNING: Frontend service did not become HTTP-ready within $StartupTimeoutSeconds seconds on port $FrontendPort"
            Write-Log "Check frontend logs: $frontendLogFile"
        }
    }

    # Resolve and record the port owner PID for reliable shutdown
    $frontendPortOwner = Get-PortOwnerPid -Port $FrontendPort
    if ($frontendPortOwner -gt 0) {
        $global:ServiceProcesses["Frontend"].PortOwnerPid = $frontendPortOwner
        Write-Log "Frontend port owner PID: $frontendPortOwner"
    } else {
        Write-Log "WARNING: Could not resolve frontend port owner PID"
    }
    Write-PidFile
}

Write-Log "=== Startup Complete ==="
Write-Log "Services started:"
foreach ($service in $global:ServiceProcesses.Keys) {
    $proc = $global:ServiceProcesses[$service].Process
    if ($proc -and !$proc.HasExited) {
        Write-Log "  - $service (PID: $($proc.Id))"
    } else {
        Write-Log "  - $service (FAILED or EXITED)"
    }
}

Write-Log ""
Write-Log "To monitor services, use: Get-Process python,node"
Write-Log "To view this log: Get-Content `"$LogFile`" -Tail 20 -Wait"
Write-Log "To view backend logs: Get-Content `"$backendLogFile`" -Tail 20 -Wait"
Write-Log "To view frontend logs: Get-Content `"$frontendLogFile`" -Tail 20 -Wait"
Write-Log ""
Write-Log "Auto-restart enabled with max $MaxRestarts restarts per service"

# Keep script running and monitor services
Write-Log "Starting monitoring mode. Press Ctrl+C to exit."
try {
    Monitor-Services
}
catch {
    Write-Log "Startup script terminated with error: $($_.Exception.Message)"
}
finally {
    if ($global:ExpectedShutdown) {
        Cleanup-Processes
    } else {
        Write-Log "Supervisor exited without an explicit shutdown request; services were preserved."
    }
}
