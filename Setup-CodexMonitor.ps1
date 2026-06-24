[CmdletBinding()]
param(
    [string]$BarkUrl,
    [string]$SessionsRoot = (Join-Path $HOME ".codex\sessions"),
    [int]$DashboardPort = 8754,
    [int]$PollSeconds = 3,
    [int]$RecentFilesToScan = 20,
    [int]$TailLinesPerFile = 120,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Read-JsonFile {
    param([string]$Path)

    Read-CodexMonitorJsonFile -Path $Path -Description "setup config file"
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    Write-CodexMonitorJsonFile -Path $Path -Value $Value
}

$repoRoot = $PSScriptRoot
$coreScriptPath = Join-Path $repoRoot "CodexMonitor.Core.ps1"
. $coreScriptPath
$barkDir = Join-Path $repoRoot "outputs\bark-notify"
$monitorDir = Join-Path $repoRoot "outputs\codex-task-monitor"

$barkConfigPath = Join-Path $barkDir "CodexBark.config.json"
$monitorConfigPath = Join-Path $monitorDir "CodexTaskMonitor.config.json"

if ((Test-Path -LiteralPath $barkConfigPath) -and -not $Force) {
    Write-Output ("Keeping existing Bark config: {0}" -f $barkConfigPath)
} else {
    $barkConfig = [ordered]@{
        barkUrl = $BarkUrl
        defaultTitle = "已完成任务"
        defaultSubtitle = ""
        defaultBody = ""
        defaultGroup = "codex"
        defaultSound = "alarm"
        defaultLevel = "timeSensitive"
    }

    Write-JsonFile -Path $barkConfigPath -Value $barkConfig
    Write-Output ("Wrote Bark config: {0}" -f $barkConfigPath)
}

if ((Test-Path -LiteralPath $monitorConfigPath) -and -not $Force) {
    Write-Output ("Keeping existing monitor config: {0}" -f $monitorConfigPath)
} else {
    $monitorConfig = [ordered]@{
        sessionsRoot = $SessionsRoot
        barkScriptPath = (Join-Path $barkDir "Send-CodexBark.ps1")
        dashboardPort = $DashboardPort
        pollSeconds = $PollSeconds
        recentFilesToScan = $RecentFilesToScan
        tailLinesPerFile = $TailLinesPerFile
        statePath = (Join-Path $monitorDir "state.json")
        pidPath = (Join-Path $monitorDir "monitor.pid")
        logPath = (Join-Path $monitorDir "monitor.log")
    }

    Write-JsonFile -Path $monitorConfigPath -Value $monitorConfig
    Write-Output ("Wrote monitor config: {0}" -f $monitorConfigPath)
}

$existingBarkConfig = Read-JsonFile -Path $barkConfigPath
if (-not $BarkUrl -and (-not $existingBarkConfig -or -not $existingBarkConfig.barkUrl)) {
    Write-Warning "No Bark URL was provided. Add it to outputs\\bark-notify\\CodexBark.config.json before sending notifications."
}
