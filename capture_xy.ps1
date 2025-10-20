# 1) Set these
$backend = "http://localhost:3101"
$pair = "waynecheng:denistone2025!ntegr!ty"  # ADMIN_USERNAME:ADMIN_PASSWORD
$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))

# 2) Ask backend to focus IBKR window
try {
  Invoke-RestMethod -Method POST -Uri "$backend/api/ib-gateway/calibration/start" -Headers @{ Authorization = "Basic $auth" } | Out-Null
  Start-Sleep -Milliseconds 800
} catch { }

# 3) Helper to get cursor vs active window (compiled C#). Compile once into WinCap namespace
$ns = "WinCap"
$typeDef = @"
using System;
using System.Runtime.InteropServices;
using System.Text;
namespace $ns {
  public struct POINT { public int X; public int Y; }
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  public static class U32 {
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr hWnd, StringBuilder sb, int maxCount);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextLengthW(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
  }
}
"@
try { $null = [type]"$ns.U32"; $loaded = $true } catch { $loaded = $false }
if (-not $loaded) { Add-Type -TypeDefinition $typeDef | Out-Null }
$POINTName = "$ns.POINT"
$RECTName = "$ns.RECT"

function Get-Rel {
  $p = New-Object $POINTName
  $r = New-Object $RECTName
  $h = [WinCap.U32]::GetForegroundWindow()
  [void][WinCap.U32]::GetCursorPos([ref]$p)
  [void][WinCap.U32]::GetWindowRect($h, [ref]$r)
  $w = [Math]::Max(1, $r.Right - $r.Left)
  $hgt = [Math]::Max(1, $r.Bottom - $r.Top)
  $xRel = [Math]::Max(0, $p.X - $r.Left)
  $yRel = [Math]::Max(0, $p.Y - $r.Top)
  $len = [WinCap.U32]::GetWindowTextLengthW($h)
  $sb = New-Object System.Text.StringBuilder ([int]($len + 1))
  [void][WinCap.U32]::GetWindowTextW($h, $sb, $sb.Capacity)
  $title = $sb.ToString()
  [pscustomobject]@{ x = [int]$xRel; y = [int]$yRel; w = [int]$w; h = [int]$hgt; title = $title }
}

Write-Host "Ensure the IBKR Gateway window is active (front)."
# Quick wait loop to see if IBKR is already frontmost
for ($i=0; $i -lt 10; $i++) {
  $t = (Get-Rel).title
  if ($t -match 'IBKR Gateway') { break }
  Start-Sleep -Milliseconds 300
}
Write-Host "Move the mouse to the center of the Username box in IBKR Gateway, then LEFT-CLICK"
# Wait for left mouse click while IBKR is the foreground window
while ($true) {
  $t = (Get-Rel).title
  $state = [WinCap.U32]::GetAsyncKeyState(0x01) # VK_LBUTTON
  if (($state -band 0x8000) -ne 0 -and $t -match 'IBKR Gateway') { $u = Get-Rel; Start-Sleep -Milliseconds 200; break }
  Start-Sleep -Milliseconds 30
}
Write-Host "Captured Username at $($u.x),$($u.y) within $($u.w)x$($u.h) (window: '$($u.title)')"

Write-Host "Move the mouse to the center of the Password box in IBKR Gateway, then LEFT-CLICK"
while ($true) {
  $t = (Get-Rel).title
  $state = [WinCap.U32]::GetAsyncKeyState(0x01) # VK_LBUTTON
  if (($state -band 0x8000) -ne 0 -and $t -match 'IBKR Gateway') { $p = Get-Rel; Start-Sleep -Milliseconds 200; break }
  Start-Sleep -Milliseconds 30
}
Write-Host "Captured Password at $($p.x),$($p.y) (window: '$($p.title)')"

# Optional: capture Live Trading and Paper Trading tabs
$live = $null
$paper = $null
Write-Host "OPTIONAL: Move mouse to the center of 'Live Trading' tab, then LEFT-CLICK (or press ESC to skip)"
while ($true) {
  $stateEsc = [WinCap.U32]::GetAsyncKeyState(0x1B) # VK_ESCAPE
  if (($stateEsc -band 0x8000) -ne 0) { break }
  $t = (Get-Rel).title
  $state = [WinCap.U32]::GetAsyncKeyState(0x01) # VK_LBUTTON
  if (($state -band 0x8000) -ne 0 -and $t -match 'IBKR Gateway') { $live = Get-Rel; Start-Sleep -Milliseconds 200; break }
  Start-Sleep -Milliseconds 30
}
if ($live) { Write-Host "Captured Live tab at $($live.x),$($live.y)" } else { Write-Host "Skipped Live tab capture" }

Write-Host "OPTIONAL: Move mouse to the center of 'Paper Trading' tab, then LEFT-CLICK (or press ESC to skip)"
while ($true) {
  $stateEsc = [WinCap.U32]::GetAsyncKeyState(0x1B)
  if (($stateEsc -band 0x8000) -ne 0) { break }
  $t = (Get-Rel).title
  $state = [WinCap.U32]::GetAsyncKeyState(0x01)
  if (($state -band 0x8000) -ne 0 -and $t -match 'IBKR Gateway') { $paper = Get-Rel; Start-Sleep -Milliseconds 200; break }
  Start-Sleep -Milliseconds 30
}
if ($paper) { Write-Host "Captured Paper tab at $($paper.x),$($paper.y)" } else { Write-Host "Skipped Paper tab capture" }

$body = @{
  username_x = $u.x
  username_y = $u.y
  password_x = $p.x
  password_y = $p.y
  window_width = $u.w
  window_height = $u.h
}
if ($live) {
  $body.live_tab_x = $live.x
  $body.live_tab_y = $live.y
}
if ($paper) {
  $body.paper_tab_x = $paper.x
  $body.paper_tab_y = $paper.y
}
$bodyJson = $body | ConvertTo-Json

Invoke-RestMethod -Method POST -Uri "$backend/api/ib-gateway/calibration/save" `
  -Headers @{ Authorization = "Basic $auth" } `
  -ContentType "application/json" -Body $bodyJson

# Also print ENV lines for manual copy/paste
function ToPct([double]$num, [double]$den) {
  if ($den -le 0) { return "0.000000" }
  $v = $num / $den
  if ($v -lt 0) { $v = 0 } elseif ($v -gt 1) { $v = 1 }
  return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0:F6}", $v)
}

$uxp = ToPct $u.x $u.w
$uyp = ToPct $u.y $u.h
$pxp = ToPct $p.x $u.w
$pyp = ToPct $p.y $u.h

Write-Host ""
Write-Host "Copy/paste these into backend\\.env:" -ForegroundColor Cyan
Write-Host ("IBG_USERNAME_X_PCT={0}" -f $uxp)
Write-Host ("IBG_USERNAME_Y_PCT={0}" -f $uyp)
Write-Host ("IBG_PASSWORD_X_PCT={0}" -f $pxp)
Write-Host ("IBG_PASSWORD_Y_PCT={0}" -f $pyp)

if ($live) {
  $lxp = ToPct $live.x $u.w
  $lyp = ToPct $live.y $u.h
  Write-Host ("IBG_LIVE_TAB_X_PCT={0}" -f $lxp)
  Write-Host ("IBG_LIVE_TAB_Y_PCT={0}" -f $lyp)
}
if ($paper) {
  $px2 = ToPct $paper.x $u.w
  $py2 = ToPct $paper.y $u.h
  Write-Host ("IBG_PAPER_TAB_X_PCT={0}" -f $px2)
  Write-Host ("IBG_PAPER_TAB_Y_PCT={0}" -f $py2)
}