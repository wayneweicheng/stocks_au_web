# Frontend Supervisor - Next.js (single service)

param(
    [int]$Port = 3100,
    [string]$Repo = "C:\Repo\stocks_au_web",
    [string]$LogPath = ".\logs",
    [switch]$Build,
    [switch]$Dev,
    [switch]$NoNewWindows
)

$ScriptRoot = Split-Path -Parent $PSCommandPath
$AbsoluteLogPath = if ([System.IO.Path]::IsPathRooted($LogPath)) { $LogPath } else { Join-Path $ScriptRoot $LogPath }
if (!(Test-Path $AbsoluteLogPath)) { New-Item -ItemType Directory -Path $AbsoluteLogPath -Force | Out-Null }
$StartupLog = Join-Path $AbsoluteLogPath "frontend-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log { param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $msg = "[$ts] $Message"
    Write-Host $msg
    try { Add-Content -Path $StartupLog -Value $msg -ErrorAction SilentlyContinue } catch {}
}

function Get-PortOwnerPid { param([int]$Port)
    try {
        $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($conn -and $conn.OwningProcess -gt 0) { return [int]$conn.OwningProcess }
    } catch {}
    try {
        $lines = netstat -ano -p tcp | Select-String ":$Port" | ForEach-Object { $_.ToString() }
        foreach ($l in $lines) { if ($l -match "LISTENING") { $parts = $l -split "\s+" | Where-Object { $_ -ne "" }; return [int]$parts[-1] } }
    } catch {}
    return 0
}

function Stop-ProcessOnPort { param([int]$Port)
    try {
        $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        if ($conns) {
            foreach ($c in $conns) { Start-Process taskkill.exe -ArgumentList "/F","/T","/PID","$($c.OwningProcess)" -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null }
            Start-Sleep -Seconds 3
            return
        }
    } catch {}
    try {
        $pid = Get-PortOwnerPid -Port $Port
        if ($pid -gt 0) { Start-Process taskkill.exe -ArgumentList "/F","/T","/PID","$pid" -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null; Start-Sleep -Seconds 2 }
    } catch {}
}

function Invoke-FrontendBuild {
    Write-Log "Building frontend for production"
    $previousLocation = Get-Location
    try {
        Set-Location $frontendWD
        & $npm run build 2>&1 | ForEach-Object { Write-Log $_.ToString() }
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            Write-Log "ERROR: frontend build failed with code $exitCode"
            exit 1
        }
    }
    finally {
        Set-Location $previousLocation
    }
    Write-Log "Frontend build completed"
}

# Job object interop
$jobCSharp = @"
using System; using System.Runtime.InteropServices;
public static class JobHelper {
  [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr CreateJobObject(IntPtr a,string n);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetInformationJobObject(IntPtr h,int c,IntPtr p,uint l);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool AssignProcessToJobObject(IntPtr j, IntPtr p);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint d,bool i,int pid);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
  [StructLayout(LayoutKind.Sequential)] public struct BLI{public long a,b;public uint f;public UIntPtr c,d;public uint e;public long g;public uint h,i;}
  [StructLayout(LayoutKind.Sequential)] public struct IOC{public ulong a,b,c,d,e,f;}
  [StructLayout(LayoutKind.Sequential)] public struct ELI{public BLI b; public IOC io; public UIntPtr p1,p2,p3,p4;}
  public const int Ext = 9; public const uint KillOnClose = 0x2000; public const uint All = 0x001F0FFF;
  public static IntPtr CreateKillJob(){ var j=CreateJobObject(IntPtr.Zero,null); if(j==IntPtr.Zero)return IntPtr.Zero; var info=new ELI(); info.b.f=KillOnClose; int sz=Marshal.SizeOf(typeof(ELI)); var mem=Marshal.AllocHGlobal(sz); try{ Marshal.StructureToPtr(info,mem,false); if(!SetInformationJobObject(j,Ext,mem,(uint)sz)){ CloseHandle(j); return IntPtr.Zero; } } finally { Marshal.FreeHGlobal(mem);} return j; }
  public static bool AddPid(IntPtr j,int pid){ var p=OpenProcess(All,false,pid); if(p==IntPtr.Zero) return false; try { return AssignProcessToJobObject(j,p);} finally { CloseHandle(p);} }
}
"@
try { Add-Type -TypeDefinition $jobCSharp -ErrorAction SilentlyContinue | Out-Null } catch {}
$Job = [JobHelper]::CreateKillJob()

# Paths
$frontendWD = Join-Path $Repo "frontend"
# Locate npm
$npm = "npm"
if (Get-Command "npm.cmd" -ErrorAction SilentlyContinue) { $npm = "npm.cmd" } elseif (Get-Command "npm.exe" -ErrorAction SilentlyContinue) { $npm = "npm.exe" }
$node = "node"
if (Get-Command "node.exe" -ErrorAction SilentlyContinue) { $node = "node.exe" }
$nextBin = Join-Path $frontendWD "node_modules\next\dist\bin\next"
if (!(Test-Path $frontendWD) -or !(Get-Command $npm -ErrorAction SilentlyContinue) -or !(Get-Command $node -ErrorAction SilentlyContinue) -or !(Test-Path $nextBin)) { Write-Log "ERROR: paths invalid or npm/node/next missing"; exit 1 }

# Singleton mutex
try { $mutex = New-Object System.Threading.Mutex($true, "Global/StocksAUWebFrontend", [ref]$created); if (-not $created) { Write-Log "Already running"; exit 0 } } catch {}

Write-Log "Starting frontend on port $Port"
Stop-ProcessOnPort -Port $Port

$outLog = Join-Path $AbsoluteLogPath "frontend-out-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$errLog = $outLog -replace '\.log$','-error.log'
$command = $npm
if ($Dev) {
    Write-Log "Using Next.js development server"
    if ($Port -eq 3100) { $args = @("run","dev") } else { $args = @("run","dev","--","--port",$Port) }
} else {
    if ($Build) {
        Invoke-FrontendBuild
    } else {
        Write-Log "Using existing production build"
    }
    $command = $node
    $args = @($nextBin, "start", "-p", $Port)
}

try {
    $proc = Start-Process -FilePath $command -ArgumentList $args -WorkingDirectory $frontendWD -PassThru -RedirectStandardOutput $outLog -RedirectStandardError $errLog
    if ($Job -ne [IntPtr]::Zero) { [JobHelper]::AddPid($Job, $proc.Id) | Out-Null }
    Write-Log "Frontend PID $($proc.Id) started"
} catch { Write-Log "ERROR: failed to start frontend: $($_.Exception.Message)"; exit 1 }

try {
    while (-not $proc.HasExited) { Start-Sleep -Seconds 20 }
    Write-Log "Frontend exited with code $($proc.ExitCode)"
}
finally {
    Stop-ProcessOnPort -Port $Port
}


