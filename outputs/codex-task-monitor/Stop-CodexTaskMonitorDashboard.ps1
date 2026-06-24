[CmdletBinding()]
param(
    [Nullable[int]]$Port
)

$ErrorActionPreference = "Stop"

$dashboardPidPath = Join-Path $PSScriptRoot "dashboard.pid"
$coreScriptPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "CodexMonitor.Core.ps1"

. $coreScriptPath
$Port = Resolve-CodexMonitorDashboardPort -Port $Port

if (-not (Test-Path -LiteralPath $dashboardPidPath)) {
    if (-not (Test-CodexMonitorTcpPort -Port $Port)) {
        Write-Output "Dashboard is not running."
        exit 0
    }

    throw "Dashboard port $Port is open, but no dashboard PID file was found."
}

$pidValue = (Get-Content -LiteralPath $dashboardPidPath -Raw).Trim()
if ($pidValue) {
    $process = Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue
    if ($process) {
        Stop-Process -Id $process.Id -Force
    }
}

if (-not (Wait-CodexMonitorTcpPortState -Port $Port -ExpectedOpen $false -TimeoutMs 5000 -PollIntervalMs 250)) {
    throw "Dashboard process stopped, but port $Port is still open."
}

Remove-Item -LiteralPath $dashboardPidPath -Force -ErrorAction SilentlyContinue
Write-Output "Dashboard stopped."
