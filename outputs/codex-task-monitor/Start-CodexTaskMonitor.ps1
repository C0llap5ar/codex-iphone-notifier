[CmdletBinding()]
param(
    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $PSScriptRoot "CodexTaskMonitor.config.json"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$runScriptPath = Join-Path $PSScriptRoot "Run-CodexTaskMonitor.ps1"

if (Test-Path -LiteralPath $config.pidPath) {
    $existingPid = (Get-Content -LiteralPath $config.pidPath -Raw -ErrorAction SilentlyContinue).Trim()
    if ($existingPid) {
        $existingProcess = Get-Process -Id ([int]$existingPid) -ErrorAction SilentlyContinue
        if ($existingProcess) {
            Write-Output ("Monitor already running (PID {0})." -f $existingProcess.Id)
            exit 0
        }
    }
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
Write-Output ("Started monitor (PID {0})." -f $process.Id)
