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

if (-not (Test-Path -LiteralPath $config.pidPath)) {
    Write-Output "Monitor is not running."
    exit 0
}

$pidValue = (Get-Content -LiteralPath $config.pidPath -Raw).Trim()
if (-not $pidValue) {
    Write-Output "Monitor PID file is empty."
    exit 1
}

$process = Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue
if ($process) {
    Stop-Process -Id $process.Id -Force
}

if (Test-Path -LiteralPath $config.pidPath) {
    Remove-Item -LiteralPath $config.pidPath -Force -ErrorAction SilentlyContinue
}

Write-Output "Monitor stopped."
