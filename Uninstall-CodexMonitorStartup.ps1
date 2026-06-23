[CmdletBinding()]
param(
    [string]$TaskName = "CodexTaskMonitor"
)

$ErrorActionPreference = "Stop"

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Output ("Startup task '{0}' is not installed." -f $TaskName)
    exit 0
}

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
Write-Output ("Removed startup task '{0}'." -f $TaskName)
