# Unregister Windows Scheduled Tasks for Stocks AU Web

param(
    [string]$TaskFolder = "\\",
    [switch]$Force
)

function Write-Log { param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts] $Message"
}

$tasks = @(
    'StocksAU Backend',
    'StocksAU Frontend'
)

foreach ($name in $tasks) {
    try {
        Write-Log "Unregistering task '$name'..."
        Unregister-ScheduledTask -TaskName $name -TaskPath $TaskFolder -Confirm:(!$Force)
    } catch {
        Write-Log "WARN: Failed to unregister '$name': $($_.Exception.Message)"
    }
}

Write-Log "Done."


