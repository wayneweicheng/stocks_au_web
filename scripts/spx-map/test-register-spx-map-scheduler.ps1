$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'register-spx-map-scheduler.ps1'
$tokens = $null; $parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors) { throw "SPX Map scheduler script has PowerShell parse errors: $parseErrors" }
$source = Get-Content -LiteralPath $scriptPath -Raw
foreach ($pattern in @(
    'run-spx-map-scheduler\.py',
    '\$trigger\.Repetition\.Interval\s*=\s*"PT5M"',
    '\$trigger\.Repetition\.Duration\s*=\s*"PT6H46M"',
    '\$trigger\.DaysOfWeek\s*=\s*62',
    '\$definition\.Settings\.StartWhenAvailable\s*=\s*\$false',
    'SPXW appears'
)) {
    if ($source -notmatch $pattern) { throw "Missing expected SPX Map scheduler behavior: $pattern" }
}
Write-Host 'SPX Map scheduler registration parses and configures weekday five-minute checks: OK'
