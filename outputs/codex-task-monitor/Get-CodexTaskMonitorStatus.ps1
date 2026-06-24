[CmdletBinding()]
param(
    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $PSScriptRoot "CodexTaskMonitor.config.json"
}

$coreScriptPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "CodexMonitor.Core.ps1"
. $coreScriptPath
$config = Get-CodexMonitorConfigFromPath -Path $ConfigPath
$state = $null
if (Test-Path -LiteralPath $config.statePath) {
    try {
        $state = Read-CodexMonitorJsonFile -Path $config.statePath -Description "monitor state file" -RetryOnInvalidJson
    }
    catch {
        $state = $null
    }
}

$monitorState = Get-CodexMonitorProcessState -PidPath $config.pidPath

[pscustomobject]@{
    running = $monitorState.running
    pid = $monitorState.pid
    lastSeenCompletedAt = if ($state) { $state.lastSeenCompletedAt } else { $null }
    statePath = $config.statePath
    logPath = $config.logPath
} | ConvertTo-Json -Depth 4
