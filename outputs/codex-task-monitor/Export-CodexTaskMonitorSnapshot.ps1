[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

function Get-TodayTaskCompleteCount {
    param(
        [string]$SessionsRoot
    )

    if (-not (Test-Path -LiteralPath $SessionsRoot)) {
        return 0
    }

    $todayPath = Join-Path $SessionsRoot ((Get-Date).ToString("yyyy\\MM\\dd"))
    if (-not (Test-Path -LiteralPath $todayPath)) {
        return 0
    }

    $turnIds = @{}
    foreach ($file in Get-ChildItem -LiteralPath $todayPath -Filter *.jsonl -File -ErrorAction SilentlyContinue) {
        foreach ($line in Get-Content -LiteralPath $file.FullName) {
            if ($line -notmatch '"type":"task_complete"') {
                continue
            }

            $turnMatch = [regex]::Match($line, '"turn_id":"([^"]+)"')
            if ($turnMatch.Success) {
                $turnIds[$turnMatch.Groups[1].Value] = $true
            }
        }
    }

    return $turnIds.Count
}

function Convert-ToStringArray {
    param(
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) {
            return
        }

        if ($InputObject -is [System.Array] -or ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string]))) {
            foreach ($item in $InputObject) {
                if ($null -ne $item) {
                    [string]$item
                }
            }
            return
        }

        [string]$InputObject
    }
}

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $PSScriptRoot "CodexTaskMonitor.config.json"
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $PSScriptRoot "status.json"
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

$pidValue = $null
$running = $false
if (Test-Path -LiteralPath $config.pidPath) {
    $pidValue = (Get-Content -LiteralPath $config.pidPath -Raw).Trim()
    if ($pidValue) {
        $running = $null -ne (Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue)
    }
}

$logTail = @()
if (Test-Path -LiteralPath $config.logPath) {
    try {
        $logTail = @(Read-CodexMonitorLogTail -Path $config.logPath -TailLines 20 | Convert-ToStringArray)
    }
    catch {
        $logTail = @()
    }
}

$notifiedTurnIds = @()
if ($state) {
    $notifiedTurnIds = @($state.notifiedTurnIds | Convert-ToStringArray)
}

$lastNotifiedTurnId = $null
if ($notifiedTurnIds.Count -gt 0) {
    $lastNotifiedTurnId = $notifiedTurnIds[-1]
}

$payload = [pscustomobject]@{
    generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    running = $running
    pid = $pidValue
    startedAt = if ($state) { $state.startedAt } else { $null }
    lastSeenCompletedAt = if ($state) { $state.lastSeenCompletedAt } else { $null }
    todayCompletedCount = Get-TodayTaskCompleteCount -SessionsRoot $config.sessionsRoot
    notifiedCount = $notifiedTurnIds.Count
    lastNotifiedTurnId = $lastNotifiedTurnId
    notifiedTurnIds = $notifiedTurnIds
    logTail = $logTail
}

$json = $payload | ConvertTo-Json -Depth 6
Write-CodexMonitorFileAtomically -Path $OutputPath -Content $json
Write-Output ("Wrote snapshot to {0}" -f $OutputPath)
