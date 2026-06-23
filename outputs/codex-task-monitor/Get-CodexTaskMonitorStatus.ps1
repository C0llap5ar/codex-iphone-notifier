[CmdletBinding()]
param(
    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $PSScriptRoot "CodexTaskMonitor.config.json"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$state = $null
if (Test-Path -LiteralPath $config.statePath) {
    $state = Get-Content -LiteralPath $config.statePath -Raw | ConvertFrom-Json
}

$pidValue = $null
$running = $false
if (Test-Path -LiteralPath $config.pidPath) {
    $pidValue = (Get-Content -LiteralPath $config.pidPath -Raw).Trim()
    if ($pidValue) {
        $running = $null -ne (Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue)
    }
}

[pscustomobject]@{
    running = $running
    pid = $pidValue
    lastSeenCompletedAt = if ($state) { $state.lastSeenCompletedAt } else { $null }
    statePath = $config.statePath
    logPath = $config.logPath
} | ConvertTo-Json -Depth 4
