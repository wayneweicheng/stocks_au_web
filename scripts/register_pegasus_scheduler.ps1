param(
    [string]$TaskName = "Pegasus Apps",
    [string]$TaskPath = "\pegasus\",
    [string]$SourceTaskName = "StocksAU Backend",
    [string]$SourceTaskPath = "\",
    [string]$StartScript = "C:\Repo\stocks_au_web\start-apps.ps1",
    [string]$WorkingDirectory = "C:\Repo\stocks_au_web",
    [string]$LogPath = "C:\Repo\stocks_au_web\logs",
    [int]$BackendPort = 3101,
    [int]$FrontendPort = 3100,
    [switch]$FrontendBuild,
    [switch]$FrontendDev
)

$ErrorActionPreference = "Stop"

function Ensure-TaskFolder {
    param([string]$Path)

    $normalized = $Path.Trim("\")
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return
    }

    $service = New-Object -ComObject Schedule.Service
    $service.Connect()
    $folder = $service.GetFolder("\")

    foreach ($part in $normalized.Split("\")) {
        if ([string]::IsNullOrWhiteSpace($part)) {
            continue
        }

        try {
            $folder = $folder.GetFolder($part)
        } catch {
            $folder = $folder.CreateFolder($part)
        }
    }
}

if (!(Test-Path -LiteralPath $StartScript)) {
    throw "Start script not found: $StartScript"
}

if (!(Test-Path -LiteralPath $WorkingDirectory)) {
    throw "Working directory not found: $WorkingDirectory"
}

if (!(Test-Path -LiteralPath $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$sourceXmlText = Export-ScheduledTask -TaskPath $SourceTaskPath -TaskName $SourceTaskName
[xml]$taskXml = $sourceXmlText

$namespace = New-Object System.Xml.XmlNamespaceManager($taskXml.NameTable)
$namespace.AddNamespace("task", "http://schemas.microsoft.com/windows/2004/02/mit/task")

$normalizedTaskPath = "\" + $TaskPath.Trim("\") + "\"
$uriNode = $taskXml.SelectSingleNode("/task:Task/task:RegistrationInfo/task:URI", $namespace)
if ($uriNode) {
    $uriNode.InnerText = "$normalizedTaskPath$TaskName"
}

$execNode = $taskXml.SelectSingleNode("/task:Task/task:Actions/task:Exec", $namespace)
if (!$execNode) {
    throw "Source task does not contain an Exec action."
}

$commandNode = $execNode.SelectSingleNode("task:Command", $namespace)
if (!$commandNode) {
    $commandNode = $taskXml.CreateElement("Command", $taskXml.Task.NamespaceURI)
    $execNode.AppendChild($commandNode) | Out-Null
}
$commandNode.InnerText = "powershell.exe"

$argumentParts = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$StartScript`"",
    "-BackendPort", $BackendPort,
    "-FrontendPort", $FrontendPort,
    "-LogPath", "`"$LogPath`"",
    "-NoNewWindows"
)
if ($FrontendBuild) {
    $argumentParts += "-FrontendBuild"
}
if ($FrontendDev) {
    $argumentParts += "-FrontendDev"
}

$argumentsNode = $execNode.SelectSingleNode("task:Arguments", $namespace)
if (!$argumentsNode) {
    $argumentsNode = $taskXml.CreateElement("Arguments", $taskXml.Task.NamespaceURI)
    $execNode.AppendChild($argumentsNode) | Out-Null
}
$argumentsNode.InnerText = ($argumentParts -join " ")

$workingDirectoryNode = $execNode.SelectSingleNode("task:WorkingDirectory", $namespace)
if (!$workingDirectoryNode) {
    $workingDirectoryNode = $taskXml.CreateElement("WorkingDirectory", $taskXml.Task.NamespaceURI)
    $execNode.AppendChild($workingDirectoryNode) | Out-Null
}
$workingDirectoryNode.InnerText = $WorkingDirectory

Ensure-TaskFolder -Path $normalizedTaskPath

try {
    Register-ScheduledTask `
        -TaskPath $normalizedTaskPath `
        -TaskName $TaskName `
        -Xml $taskXml.OuterXml `
        -Force `
        -ErrorAction Stop | Out-Null
} catch {
    throw "Failed to register scheduled task '$normalizedTaskPath$TaskName'. Run PowerShell as Administrator and try again. Original error: $($_.Exception.Message)"
}

Write-Host "Registered scheduled task: $normalizedTaskPath$TaskName"
Write-Host "Action: powershell.exe $($argumentsNode.InnerText)"
Write-Host "Start in: $WorkingDirectory"
