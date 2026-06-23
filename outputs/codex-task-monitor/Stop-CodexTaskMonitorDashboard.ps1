[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$dashboardPidPath = Join-Path $PSScriptRoot "dashboard.pid"

if (-not (Test-Path -LiteralPath $dashboardPidPath)) {
    Write-Output "Dashboard is not running."
    exit 0
}

$pidValue = (Get-Content -LiteralPath $dashboardPidPath -Raw).Trim()
if ($pidValue) {
    $process = Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue
    if ($process) {
        Stop-Process -Id $process.Id -Force
    }
}

Remove-Item -LiteralPath $dashboardPidPath -Force
Write-Output "Dashboard stopped."
