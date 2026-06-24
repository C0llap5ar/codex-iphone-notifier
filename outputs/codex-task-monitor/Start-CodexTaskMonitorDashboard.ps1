[CmdletBinding()]
param(
    [Nullable[int]]$Port
)

$ErrorActionPreference = "Stop"

$serveScriptPath = Join-Path $PSScriptRoot "Serve-CodexTaskMonitorDashboard.ps1"
$dashboardPidPath = Join-Path $PSScriptRoot "dashboard.pid"
$configPath = Join-Path $PSScriptRoot "CodexTaskMonitor.config.json"
$coreScriptPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "CodexMonitor.Core.ps1"

. $coreScriptPath

if (-not $Port.HasValue) {
    $Port = Resolve-CodexMonitorDashboardPort
}

if (Remove-CodexMonitorStalePidFile -PidPath $dashboardPidPath) {
    Write-Output "Removed stale dashboard PID file."
}

$existingState = Get-CodexMonitorDashboardState -Port $Port
if ($existingState.running) {
    Write-Output ("Dashboard already running (PID {0}) at http://127.0.0.1:{1}/" -f $existingState.pid, $Port)
    exit 0
}

if ($existingState.portOpen -and -not $existingState.processRunning) {
    throw "Port $Port is already in use by another process."
}

$process = Start-Process -FilePath "powershell" `
    -ArgumentList @(
        "-ExecutionPolicy", "Bypass",
        "-File", $serveScriptPath,
        "-Port", $Port
    ) `
    -WindowStyle Hidden `
    -PassThru

Set-Content -LiteralPath $dashboardPidPath -Value $process.Id -Encoding ASCII

if (-not (Wait-CodexMonitorTcpPortState -Port $Port -ExpectedOpen $true -TimeoutMs 5000 -PollIntervalMs 250)) {
    if (Test-Path -LiteralPath $dashboardPidPath) {
        Remove-Item -LiteralPath $dashboardPidPath -Force -ErrorAction SilentlyContinue
    }
    throw "Dashboard did not start listening on port $Port."
}

Write-Output ("Started dashboard (PID {0}) at http://127.0.0.1:{1}/" -f $process.Id, $Port)
