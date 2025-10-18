# Australian Stocks Web App - Auto Startup Script with Auto-Restart
# This script starts both backend (FastAPI) and frontend (Next.js) services
# Based on the enhanced template from rag_stock_announcement_processor

param(
    [int]$BackendPort = 3101,
    [int]$FrontendPort = 3100,
    [string]$LogPath = ".\logs",
    [switch]$NoNewWindows,
    [int]$MaxRestarts = 5,
    [int]$RestartCooldown = 60
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

    Write-Log "Starting $ServiceName..."

    # Check if port is already in use
    if ($Port -gt 0) {
        $portCheck = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
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
            # Use PowerShell redirection for better compatibility
            $errorLogFile = $LogFile -replace '\.log$', '-error.log'
            $argumentString = if ($Arguments -is [Array]) { $Arguments -join ' ' } else { $Arguments }

            # Create a PowerShell script to handle the redirection
            $psScript = "& '$Command' $argumentString *> '$LogFile'"
            $redirectCmd = "powershell.exe"
            $redirectArgs = @("-Command", $psScript)

            if ($NoNewWindows) {
                $process = Start-Process -FilePath $redirectCmd -ArgumentList $redirectArgs -WorkingDirectory $WorkingDirectory -WindowStyle Hidden -PassThru
            } else {
                $process = Start-Process -FilePath $redirectCmd -ArgumentList $redirectArgs -WorkingDirectory $WorkingDirectory -PassThru
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
        try {
            $connection = Test-NetConnection -ComputerName "localhost" -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue
            return $connection
        }
        catch {
            return $false
        }
    }
    return $true
}

function Stop-ProcessOnPort {
    param([int]$Port, [string]$ServiceName)

    Write-Log "Checking for processes on port $Port for $ServiceName..."

    try {
        $connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        if ($connections) {
            $killedAny = $false
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
            if ($killedAny) {
                Write-Log "Waiting for port $Port to be released..."
                Start-Sleep -Seconds 5
                # Verify port is now free
                $stillInUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
                if ($stillInUse) {
                    Write-Log "WARNING: Port $Port may still be in use after cleanup"
                } else {
                    Write-Log "Port $Port is now free for $ServiceName"
                }
            }
        } else {
            Write-Log "Port $Port is free for $ServiceName"
        }
    }
    catch {
        Write-Log "Error checking port $Port for $ServiceName - $($_.Exception.Message)"
    }
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

        foreach ($serviceName in $global:ServiceProcesses.Keys) {
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
                }
            }
            # Additional health check for services with ports
            elseif ($serviceInfo.Port -gt 0) {
                $isHealthy = Test-ServiceHealth -ServiceName $serviceName -Port $serviceInfo.Port
                if (-not $isHealthy) {
                    Write-Log "WARNING: $serviceName is running but not responding on port $($serviceInfo.Port)"
                    # Optionally restart unresponsive services
                    # Restart-Service -ServiceName $serviceName
                }
            }
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

# Register cleanup on script exit or termination
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Cleanup-Processes
} | Out-Null

# Handle Ctrl+C and other termination signals (skip in non-interactive mode)
try {
    [Console]::TreatControlCAsInput = $false
    $null = [Console]::CancelKeyPress.Add({
        param($sender, $e)
        $e.Cancel = $true
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

# Start Backend Service (FastAPI with Python virtual environment)
Write-Log "--- Starting Backend Service ---"
Stop-ProcessOnPort -Port $BackendPort -ServiceName "Backend"

# Create timestamped log file for backend
$backendLogFile = Join-Path $AbsoluteLogPath "backend-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Write-Log "Backend logs will be written to: $backendLogFile"

$backendArgs = @("-m", "uvicorn", "app.main:app", "--reload", "--port", $BackendPort)
$backendSuccess = Start-ServiceWithMonitoring -ServiceName "Backend" -WorkingDirectory $backendWD -Command $python -Arguments $backendArgs -Port $BackendPort -LogFile $backendLogFile

if ($backendSuccess) {
    # Wait a moment for backend to initialize
    Start-Sleep -Seconds 5

    # Test backend health
    if (Test-ServiceHealth -ServiceName "Backend" -Port $BackendPort) {
        Write-Log "Backend service is responding on port $BackendPort"
    } else {
        Write-Log "WARNING: Backend service is not responding on port $BackendPort"
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

# Start Frontend Service (Next.js)
Write-Log "--- Starting Frontend Service ---"
Stop-ProcessOnPort -Port $FrontendPort -ServiceName "Frontend"

# Create timestamped log file for frontend
$frontendLogFile = Join-Path $AbsoluteLogPath "frontend-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Write-Log "Frontend logs will be written to: $frontendLogFile"

# Use the standard npm run dev approach with port modification
if ($FrontendPort -eq 3100) {
    # Use default package.json script
    $frontendArgs = @("run", "dev")
} else {
    # Create a custom script command with different port
    $frontendArgs = @("run", "dev", "--", "--port", $FrontendPort)
}
$frontendSuccess = Start-ServiceWithMonitoring -ServiceName "Frontend" -WorkingDirectory $frontendWD -Command $npm -Arguments $frontendArgs -Port $FrontendPort -LogFile $frontendLogFile

if ($frontendSuccess) {
    # Wait a moment for frontend to initialize
    Start-Sleep -Seconds 10

    # Check if the frontend process is still running
    $frontendProcess = $global:ServiceProcesses["Frontend"].Process
    if ($frontendProcess.HasExited) {
        Write-Log "ERROR: Frontend process has exited unexpectedly. Check logs for details:"
        Write-Log "Frontend log: $frontendLogFile"
    } else {
        # Check if frontend is responding on port
        if (Test-ServiceHealth -ServiceName "Frontend" -Port $FrontendPort) {
            Write-Log "Frontend service is responding on port $FrontendPort"
        } else {
            Write-Log "Frontend service started but is not responding on port $FrontendPort"
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
    Write-Log "Startup script terminated"
    Cleanup-Processes
}