[CmdletBinding()]
param(
    [string]$BarkUrl,
    [string]$SessionsRoot = (Join-Path $HOME ".codex\sessions"),
    [int]$PollSeconds = 3,
    [int]$RecentFilesToScan = 20,
    [int]$TailLinesPerFile = 120,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Read-JsonFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }

    $Value | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding UTF8
}

$repoRoot = $PSScriptRoot
$barkDir = Join-Path $repoRoot "outputs\bark-notify"
$monitorDir = Join-Path $repoRoot "outputs\codex-task-monitor"

$barkConfigPath = Join-Path $barkDir "CodexBark.config.json"
$monitorConfigPath = Join-Path $monitorDir "CodexTaskMonitor.config.json"

if ((Test-Path -LiteralPath $barkConfigPath) -and -not $Force) {
    Write-Output ("Keeping existing Bark config: {0}" -f $barkConfigPath)
} else {
    $barkConfig = [ordered]@{
        barkUrl = $BarkUrl
        defaultTitle = "\u5df2\u5b8c\u6210\u4efb\u52a1"
        defaultSubtitle = ""
        defaultBody = ""
        defaultGroup = "codex"
        defaultSound = "alarm"
        defaultLevel = "timeSensitive"
    }

    Write-JsonFile -Path $barkConfigPath -Value $barkConfig
    Write-Output ("Wrote Bark config: {0}" -f $barkConfigPath)
}

if ((Test-Path -LiteralPath $monitorConfigPath) -and -not $Force) {
    Write-Output ("Keeping existing monitor config: {0}" -f $monitorConfigPath)
} else {
    $monitorConfig = [ordered]@{
        sessionsRoot = $SessionsRoot
        barkScriptPath = (Join-Path $barkDir "Send-CodexBark.ps1")
        pollSeconds = $PollSeconds
        recentFilesToScan = $RecentFilesToScan
        tailLinesPerFile = $TailLinesPerFile
        statePath = (Join-Path $monitorDir "state.json")
        pidPath = (Join-Path $monitorDir "monitor.pid")
        logPath = (Join-Path $monitorDir "monitor.log")
    }

    Write-JsonFile -Path $monitorConfigPath -Value $monitorConfig
    Write-Output ("Wrote monitor config: {0}" -f $monitorConfigPath)
}

$existingBarkConfig = Read-JsonFile -Path $barkConfigPath
if (-not $BarkUrl -and (-not $existingBarkConfig -or -not $existingBarkConfig.barkUrl)) {
    Write-Warning "No Bark URL was provided. Add it to outputs\\bark-notify\\CodexBark.config.json before sending notifications."
}
