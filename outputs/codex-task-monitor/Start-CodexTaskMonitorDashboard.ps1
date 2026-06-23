[CmdletBinding()]
param(
    [int]$Port = 8754
)

$ErrorActionPreference = "Stop"

$serveScriptPath = Join-Path $PSScriptRoot "Serve-CodexTaskMonitorDashboard.ps1"
$dashboardPidPath = Join-Path $PSScriptRoot "dashboard.pid"

if (Test-Path -LiteralPath $dashboardPidPath) {
    $existingPid = (Get-Content -LiteralPath $dashboardPidPath -Raw).Trim()
    if ($existingPid) {
        $existingProcess = Get-Process -Id ([int]$existingPid) -ErrorAction SilentlyContinue
        if ($existingProcess) {
            Write-Output ("Dashboard already running (PID {0}) at http://127.0.0.1:{1}/" -f $existingProcess.Id, $Port)
            exit 0
        }
    }
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
Write-Output ("Started dashboard (PID {0}) at http://127.0.0.1:{1}/" -f $process.Id, $Port)
