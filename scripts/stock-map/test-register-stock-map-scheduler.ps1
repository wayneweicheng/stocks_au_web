# Exercise the real legacy-task cleanup block without creating a scheduled task.
$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'register-stock-map-scheduler.ps1'
$source = Get-Content -LiteralPath $scriptPath -Raw
$tokens = $null; $parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors) { throw "Scheduler script has PowerShell parse errors: $parseErrors" }
$helper = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-MissingTaskError' }, $false)
if (-not $helper) { throw 'Cannot find missing-task error handler' }
. ([scriptblock]::Create($helper.Extent.Text))
$match = [regex]::Match($source, '(?s)# Migrate the old daily task.*?(?=Write-Host "Registered:)')
if (-not $match.Success) { throw 'Cannot find the legacy task cleanup block' }
$cleanup = [scriptblock]::Create($match.Value)

function Test-Cleanup($existing) {
    $root = [pscustomobject]@{ Existing = $existing; Removed = $false }
    $root | Add-Member -MemberType ScriptMethod -Name GetTask -Value {
        param($name)
        if (-not $this.Existing) { throw [System.IO.FileNotFoundException]::new('The system cannot find the file specified.') }
        return [pscustomobject]@{ Name = $name }
    }
    $root | Add-Member -MemberType ScriptMethod -Name DeleteTask -Value { param($name, $flags) $this.Removed = $true }
    $service = [pscustomobject]@{ Root = $root }
    $service | Add-Member -MemberType ScriptMethod -Name GetFolder -Value { param($path) return $this.Root }
    $normalizedTaskPath = '\pegasus\'
    $TaskName = 'Pegasus Stock Map'
    & $cleanup | Out-Null
    if ([bool]$root.Removed -ne [bool]$existing) { throw "Incorrect legacy task cleanup: existing=$existing removed=$($root.Removed)" }
}

Test-Cleanup $false
Test-Cleanup $true
try { throw [System.UnauthorizedAccessException]::new('Access denied') } catch {
    if (Test-MissingTaskError $_) { throw 'Access denied must not be mistaken for a missing task' }
}
Write-Host 'Legacy task cleanup handles missing and existing root tasks: OK'
