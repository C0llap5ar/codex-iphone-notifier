[CmdletBinding()]
param(
    [ValidateSet("menu", "start", "stop", "restart", "status", "open", "test", "tail")]
    [string]$Action = "menu",
    [Nullable[int]]$Port,
    [int]$TailLines = 20
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "CodexMonitor.Core.ps1")

function Write-Section {
    param(
        [string]$Title
    )

    Write-Host ""
    Write-Host $Title
    Write-Host ("-" * $Title.Length)
}

function Show-Status {
    $status = Get-CodexMonitorStatusData -Port $Port -TailLines $TailLines
    $config = $status.config
    $monitorState = $status.monitorState
    $dashboardState = $status.dashboardState
    $snapshot = $status.snapshot

    Write-Section "Codex Monitor Status"
    Write-Host ("Monitor   : {0}" -f $(if ($monitorState.running) { "running (PID $($monitorState.pid))" } else { "stopped" }))
    Write-Host ("Dashboard : {0}" -f $(if ($dashboardState.running) { "running (PID $($dashboardState.pid))" } else { "stopped" }))
    Write-Host ("URL       : {0}" -f $status.dashboardUrl)
    Write-Host ("Sessions  : {0}" -f $config.sessionsRoot)
    Write-Host ("Log       : {0}" -f $config.logPath)

    if ($snapshot) {
        Write-Host ("Completed : {0} today" -f $snapshot.todayCompletedCount)
        Write-Host ("Notified  : {0}" -f $snapshot.notifiedCount)
        Write-Host ("Last turn : {0}" -f $(if ($snapshot.lastNotifiedTurnId) { $snapshot.lastNotifiedTurnId } else { "-" }))

        $recentLog = @($status.recentLog)
        if ($recentLog.Count -gt 0) {
            Write-Section "Recent Log"
            foreach ($line in $recentLog) {
                Write-Host $line
            }
        }
    }
}

function Start-All {
    Write-Section "Starting Services"
    Start-CodexMonitorServices -Port $Port
    Write-Host ("Dashboard URL: {0}" -f (Get-CodexMonitorDashboardUrl -Port $Port))
}

function Stop-All {
    Write-Section "Stopping Services"
    Stop-CodexMonitorServices
}

function Restart-All {
    Restart-CodexMonitorServices -Port $Port
}

function Open-Dashboard {
    $url = Open-CodexMonitorDashboard -Port $Port
    Write-Output ("Opened {0}" -f $url)
}

function Run-Test {
    Write-Section "Running Health Check"
    $result = Invoke-CodexMonitorHealthCheck -Port $Port

    Write-Host ("OK        : {0}" -f $result.ok)
    Write-Host ("Dashboard : {0}" -f $(if ($result.dashboardUrl) { $result.dashboardUrl } else { "-" }))

    foreach ($property in $result.checks.PSObject.Properties) {
        Write-Host ("{0,-12}: {1}" -f $property.Name, $property.Value)
    }
}

function Show-LogTail {
    $recentLog = @(Get-CodexMonitorLogTail -TailLines $TailLines)
    if ($recentLog.Count -eq 0) {
        Write-Output "Monitor log not found yet."
        return
    }

    Write-Section "Monitor Log Tail"
    $recentLog
}

function Show-Menu {
    Write-Host ""
    Write-Host "Codex Monitor Console"
    Write-Host "1. Start monitor + dashboard"
    Write-Host "2. Stop monitor + dashboard"
    Write-Host "3. Restart monitor + dashboard"
    Write-Host "4. Show status"
    Write-Host "5. Open dashboard in browser"
    Write-Host "6. Send test notification"
    Write-Host "7. Show recent log"
    Write-Host "Q. Quit"
    Write-Host ""

    $choice = (Read-Host "Choose an action").Trim().ToLowerInvariant()
    switch ($choice) {
        "1" { return "start" }
        "2" { return "stop" }
        "3" { return "restart" }
        "4" { return "status" }
        "5" { return "open" }
        "6" { return "test" }
        "7" { return "tail" }
        "q" { return $null }
        default { throw "Unknown menu choice: $choice" }
    }
}

if ($Action -eq "menu") {
    $selectedAction = Show-Menu
    if (-not $selectedAction) {
        exit 0
    }
    $Action = $selectedAction
}

switch ($Action) {
    "start" { Start-All; Show-Status }
    "stop" { Stop-All; Show-Status }
    "restart" { Restart-All; Show-Status }
    "status" { Show-Status }
    "open" { Open-Dashboard; Show-Status }
    "test" { Run-Test; Show-Status }
    "tail" { Show-LogTail }
}
