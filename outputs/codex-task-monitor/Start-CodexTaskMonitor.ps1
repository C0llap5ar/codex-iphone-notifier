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
$runScriptPath = Join-Path $PSScriptRoot "Run-CodexTaskMonitor.ps1"

if (Remove-CodexMonitorStalePidFile -PidPath $config.pidPath) {
    Write-Output "Removed stale monitor PID file."
}

$existingState = Get-CodexMonitorProcessState -PidPath $config.pidPath
if ($existingState.running) {
    Write-Output ("Monitor already running (PID {0})." -f $existingState.pid)
    exit 0
}

$process = Start-Process -FilePath "powershell" `
    -ArgumentList @(
        "-ExecutionPolicy", "Bypass",
        "-File", $runScriptPath,
        "-ConfigPath", $ConfigPath
    ) `
    -WindowStyle Hidden `
    -PassThru

Set-Content -LiteralPath $config.pidPath -Value $process.Id -Encoding ASCII

$started = $false
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 250
    $startedState = Get-CodexMonitorProcessState -PidPath $config.pidPath
    if ($startedState.running) {
        $started = $true
        break
    }
}

if (-not $started) {
    if (Test-Path -LiteralPath $config.pidPath) {
        Remove-Item -LiteralPath $config.pidPath -Force -ErrorAction SilentlyContinue
    }
    throw "Monitor process did not stay running after launch."
}

Write-Output ("Started monitor (PID {0})." -f $process.Id)
