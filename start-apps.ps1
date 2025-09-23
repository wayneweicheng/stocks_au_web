# start-apps-managed.ps1

param(
  [int]$BackendPort = 3101
)

$repo        = "C:\Repo\stocks_au_web"
$logs        = Join-Path $repo "logs"
$pidFile     = Join-Path $logs "pids.json"
$backendWD   = Join-Path $repo "backend"
$frontendWD  = Join-Path $repo "frontend"
$python      = Join-Path $repo "venv\Scripts\python.exe"
$npm         = "npm.cmd"    # or full path: C:\Program Files\nodejs\npm.cmd
$backendLog  = Join-Path $logs "backend.log"
$frontendLog = Join-Path $logs "frontend.log"

New-Item -ItemType Directory -Force -Path $logs | Out-Null

function Stop-ByPid {
  param([int]$Pid)
  if ($Pid) {
    try {
      if (Get-Process -Id $Pid -ErrorAction SilentlyContinue) {
        Stop-Process -Id $Pid -Force -ErrorAction SilentlyContinue
        Wait-Process -Id $Pid -ErrorAction SilentlyContinue
      }
    } catch {}
  }
}

function Kill-Backend-PortOwner {
  param([int]$Port)
  try {
    $owners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
              Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($op in $owners) {
      if ($op) {
        Stop-Process -Id $op -Force -ErrorAction SilentlyContinue
        Wait-Process -Id $op -ErrorAction SilentlyContinue
      }
    }
  } catch {}
}

# 1) Kill existing (from prior run via PID file)
$old = $null
if (Test-Path $pidFile) {
  try { $old = Get-Content $pidFile | ConvertFrom-Json } catch {}
}
if ($old) {
  Stop-ByPid -Pid $old.backendPid
  Stop-ByPid -Pid $old.frontendPid
}

# Extra safety: free backend port (if someone else is using it)
if ($BackendPort) {
  Kill-Backend-PortOwner -Port $BackendPort
}

# 2) Start backend (headless)
$backend = Start-Process -FilePath $python `
  -ArgumentList @("-m","uvicorn","app.main:app","--reload","--port",$BackendPort) `
  -WorkingDirectory $backendWD `
  -WindowStyle Hidden `
  -RedirectStandardOutput $backendLog `
  -RedirectStandardError  $backendLog `
  -PassThru

Start-Sleep -Seconds 3

# 3) Start frontend (headless)
$frontend = Start-Process -FilePath $npm `
  -ArgumentList @("run","dev") `
  -WorkingDirectory $frontendWD `
  -WindowStyle Hidden `
  -RedirectStandardOutput $frontendLog `
  -RedirectStandardError  $frontendLog `
  -PassThru

# 4) Save current PIDs
@{ backendPid = $backend.Id; frontendPid = $frontend.Id } |
  ConvertTo-Json | Set-Content $pidFile

Write-Host "Backend PID=$($backend.Id) (port $BackendPort), Frontend PID=$($frontend.Id). Logs in $logs"

# 5) Keep this script running as long as apps are alive (suitable for Task Scheduler)
try {
  Wait-Process -Id @($backend.Id, $frontend.Id)
} finally {
  # Optional: if one exits and the script is being torn down, stop the other
  foreach ($pid in @($backend.Id, $frontend.Id)) {
    Stop-ByPid -Pid $pid
  }
}