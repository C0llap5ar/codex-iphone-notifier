[CmdletBinding()]
param(
    [switch]$SendNotification,
    [switch]$StartDashboard,
    [Nullable[int]]$DashboardPort
)

$ErrorActionPreference = "Stop"

function Read-JsonFile {
    param([string]$Path)

    Read-CodexMonitorJsonFile -Path $Path -Description "test config file"
}

$repoRoot = $PSScriptRoot
$coreScriptPath = Join-Path $repoRoot "CodexMonitor.Core.ps1"
$barkConfigPath = Join-Path $repoRoot "outputs\bark-notify\CodexBark.config.json"
$monitorConfigPath = Join-Path $repoRoot "outputs\codex-task-monitor\CodexTaskMonitor.config.json"
$monitorStatusScript = Join-Path $repoRoot "outputs\codex-task-monitor\Get-CodexTaskMonitorStatus.ps1"
$monitorStartScript = Join-Path $repoRoot "outputs\codex-task-monitor\Start-CodexTaskMonitor.ps1"
$dashboardStartScript = Join-Path $repoRoot "outputs\codex-task-monitor\Start-CodexTaskMonitorDashboard.ps1"
$snapshotScript = Join-Path $repoRoot "outputs\codex-task-monitor\Export-CodexTaskMonitorSnapshot.ps1"
$barkScript = Join-Path $repoRoot "outputs\bark-notify\Send-CodexBark.ps1"

. $coreScriptPath
$DashboardPort = Resolve-CodexMonitorDashboardPort -Port $DashboardPort

$barkConfig = Read-JsonFile -Path $barkConfigPath
$monitorConfig = Read-JsonFile -Path $monitorConfigPath

$checks = [ordered]@{
    barkConfigExists = Test-Path -LiteralPath $barkConfigPath
    barkUrlConfigured = $false
    monitorConfigExists = Test-Path -LiteralPath $monitorConfigPath
    sessionsRootExists = $false
    barkScriptExists = Test-Path -LiteralPath $barkScript
    monitorRunning = $false
    dashboardRequested = [bool]$StartDashboard
    notificationRequested = [bool]$SendNotification
    snapshotExported = $false
}

if ($barkConfig -and $barkConfig.barkUrl) {
    $checks.barkUrlConfigured = $true
}

if ($monitorConfig -and $monitorConfig.sessionsRoot) {
    $checks.sessionsRootExists = Test-Path -LiteralPath $monitorConfig.sessionsRoot
}

if ($monitorConfig) {
    & $snapshotScript -ConfigPath $monitorConfigPath | Out-Null
    $checks.snapshotExported = $true
}

$status = & $monitorStatusScript | ConvertFrom-Json
if (-not $status.running) {
    & $monitorStartScript | Out-Null
    Start-Sleep -Seconds 2
    $status = & $monitorStatusScript | ConvertFrom-Json
}
$checks.monitorRunning = [bool]$status.running

if ($StartDashboard) {
    & $dashboardStartScript -Port $DashboardPort | Out-Null
}

if ($SendNotification) {
    & $barkScript -Title "Codex test" -Body "Bark path is working." | Out-Null
}

[pscustomobject]@{
    ok = ($checks.barkConfigExists -and $checks.barkScriptExists -and $checks.monitorConfigExists -and $checks.sessionsRootExists -and $checks.monitorRunning)
    checks = $checks
    dashboardUrl = if ($StartDashboard) { "http://127.0.0.1:$DashboardPort/" } else { $null }
} | ConvertTo-Json -Depth 5
