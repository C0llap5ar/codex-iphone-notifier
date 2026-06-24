[CmdletBinding()]
param(
    [string]$TaskName = "CodexTaskMonitor",
    [switch]$IncludeDashboard,
    [Nullable[int]]$DashboardPort
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$monitorStartScript = Join-Path $repoRoot "outputs\codex-task-monitor\Start-CodexTaskMonitor.ps1"
$dashboardStartScript = Join-Path $repoRoot "outputs\codex-task-monitor\Start-CodexTaskMonitorDashboard.ps1"
$coreScript = Join-Path $repoRoot "CodexMonitor.Core.ps1"

. $coreScript
$DashboardPort = Resolve-CodexMonitorDashboardPort -Port $DashboardPort

if (-not (Test-Path -LiteralPath $monitorStartScript)) {
    throw "Monitor start script not found: $monitorStartScript"
}

$commandParts = @(
    "powershell -ExecutionPolicy Bypass -File `"$monitorStartScript`""
)

if ($IncludeDashboard) {
    $commandParts += "powershell -ExecutionPolicy Bypass -File `"$dashboardStartScript`" -Port $DashboardPort"
}

$action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument ("/c " + ($commandParts -join " && "))
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description "Start Codex task monitor at logon." -Force | Out-Null
Write-Output ("Installed startup task '{0}'." -f $TaskName)
