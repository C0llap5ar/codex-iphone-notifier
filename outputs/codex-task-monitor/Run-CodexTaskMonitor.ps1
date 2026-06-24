[CmdletBinding()]
param(
    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"

function Read-JsonFile {
    param([string]$Path)

    Read-CodexMonitorJsonFile -Path $Path -Description "monitor state file" -RetryOnInvalidJson
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 6
    Write-CodexMonitorFileAtomically -Path $Path -Content $json
}

function Write-MonitorLog {
    param(
        [object]$Config,
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $directory = Split-Path -Parent $Config.logPath
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }

    $line = "[{0}] {1}{2}" -f $timestamp, $Message, [Environment]::NewLine
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    $bytes = $utf8.GetBytes($line)
    $stream = [System.IO.File]::Open($Config.logPath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
    }
    finally {
        $stream.Dispose()
    }
}

function Get-RecentSessionFiles {
    param([object]$Config)

    if (-not (Test-Path -LiteralPath $Config.sessionsRoot)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $Config.sessionsRoot -Recurse -Filter *.jsonl -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First ([int]$Config.recentFilesToScan))
}

function Get-TaskCompleteEvents {
    param([object]$Config)

    $events = @()

    foreach ($file in Get-RecentSessionFiles -Config $Config) {
        try {
            $content = Read-CodexMonitorTextFile -Path $file.FullName -Description "session file" -MaxAttempts 3 -RetryDelayMs 60
        }
        catch {
            # Codex can still be appending to the newest session file. Skip it for
            # this polling pass instead of killing the whole background monitor.
            continue
        }

        if ([string]::IsNullOrEmpty($content)) {
            continue
        }

        $normalized = $content -replace "`r`n", "`n"
        $allLines = @($normalized -split "`n")
        if ($allLines.Count -gt 0 -and $allLines[-1] -eq "") {
            $allLines = @($allLines | Select-Object -SkipLast 1)
        }
        if ($allLines.Count -gt [int]$Config.tailLinesPerFile) {
            $lines = @($allLines | Select-Object -Last ([int]$Config.tailLinesPerFile))
        }
        else {
            $lines = @($allLines)
        }
        foreach ($line in $lines) {
            if ($line -notmatch '"type":"task_complete"') {
                continue
            }

            $turnMatch = [regex]::Match($line, '"turn_id":"([^"]+)"')
            $completedMatch = [regex]::Match($line, '"completed_at":(\d+)')
            if (-not $turnMatch.Success -or -not $completedMatch.Success) {
                continue
            }

            $events += [pscustomobject]@{
                TurnId      = $turnMatch.Groups[1].Value
                CompletedAt = [int64]$completedMatch.Groups[1].Value
                FilePath    = $file.FullName
            }
        }
    }

    return @($events | Sort-Object CompletedAt, TurnId -Unique)
}

function New-InitialState {
    param([object]$Config)

    $currentMax = 0
    $events = Get-TaskCompleteEvents -Config $Config
    if ($events.Count -gt 0) {
        $currentMax = ($events | Measure-Object -Property CompletedAt -Maximum).Maximum
    }

    return [pscustomobject]@{
        lastSeenCompletedAt = [int64]$currentMax
        notifiedTurnIds = @()
        startedAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    }
}

function Trim-NotifiedTurnIds {
    param([object[]]$TurnIds)

    if ($TurnIds.Count -le 200) {
        return @($TurnIds)
    }

    return @($TurnIds | Select-Object -Last 200)
}

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $PSScriptRoot "CodexTaskMonitor.config.json"
}

$coreScriptPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "CodexMonitor.Core.ps1"
. $coreScriptPath
$config = Get-CodexMonitorConfigFromPath -Path $ConfigPath

$pidDirectory = Split-Path -Parent $config.pidPath
if ($pidDirectory -and -not (Test-Path -LiteralPath $pidDirectory)) {
    New-Item -ItemType Directory -Path $pidDirectory | Out-Null
}

Set-Content -LiteralPath $config.pidPath -Value $PID -Encoding ASCII

$state = Read-JsonFile -Path $config.statePath
if ($null -eq $state) {
    $state = New-InitialState -Config $config
    Write-JsonFile -Path $config.statePath -Value $state
}

Write-MonitorLog -Config $config -Message ("Monitor started. PID={0}" -f $PID)

try {
    while ($true) {
        # Reload persisted state each cycle so manual state corrections or recovery
        # after test events take effect without requiring a full process restart.
        $latestState = Read-JsonFile -Path $config.statePath
        if ($null -ne $latestState) {
            $state = $latestState
        }

        $events = Get-TaskCompleteEvents -Config $config
        $knownTurnIds = @($state.notifiedTurnIds)
        $newEvents = @(
            $events |
            Where-Object {
                ($_.CompletedAt -gt [int64]$state.lastSeenCompletedAt) -or
                ($_.CompletedAt -eq [int64]$state.lastSeenCompletedAt -and $_.TurnId -notin $knownTurnIds)
            } |
            Sort-Object CompletedAt, TurnId
        )

        foreach ($event in $newEvents) {
            try {
                & $config.barkScriptPath | Out-Null
                Write-MonitorLog -Config $config -Message ("Sent Bark for turn {0}" -f $event.TurnId)

                $knownTurnIds += $event.TurnId
                $state.lastSeenCompletedAt = [int64]$event.CompletedAt
                $state.notifiedTurnIds = Trim-NotifiedTurnIds -TurnIds $knownTurnIds
                Write-JsonFile -Path $config.statePath -Value $state
            }
            catch {
                Write-MonitorLog -Config $config -Message ("Failed Bark for turn {0}: {1}" -f $event.TurnId, $_.Exception.Message)
            }
        }

        Start-Sleep -Seconds ([int]$config.pollSeconds)
    }
}
finally {
    if (Test-Path -LiteralPath $config.pidPath) {
        Remove-Item -LiteralPath $config.pidPath -Force
    }
    Write-MonitorLog -Config $config -Message "Monitor stopped."
}
