param(
    [string]$Message = "Codex task finished.",
    [string]$Title,
    [ValidateSet("min", "low", "default", "high", "urgent")]
    [string]$Priority,
    [string]$Tags,
    [ValidateSet("success", "info", "warning", "error")]
    [string]$Status = "success",
    [string]$Topic,
    [string]$Server,
    [string]$Click,
    [string]$ConfigPath,
    [string]$TaskName,
    [string]$AuthToken,
    [switch]$IncludeContext = $true
)

$ErrorActionPreference = "Stop"

function Get-ConfigValue {
    param(
        [object]$Config,
        [string]$Name,
        [string]$Fallback = ""
    )

    if ($null -ne $Config -and $null -ne $Config.PSObject.Properties[$Name]) {
        $value = $Config.$Name
        if ($null -ne $value -and "$value".Trim().Length -gt 0) {
            return "$value"
        }
    }

    return $Fallback
}

function Resolve-StatusDefaults {
    param([string]$ResolvedStatus)

    switch ($ResolvedStatus) {
        "success" {
            return @{
                Title = "Codex Finished"
                Priority = "high"
                Tags = "computer,white_check_mark"
            }
        }
        "info" {
            return @{
                Title = "Codex Update"
                Priority = "default"
                Tags = "computer,information_source"
            }
        }
        "warning" {
            return @{
                Title = "Codex Warning"
                Priority = "high"
                Tags = "computer,warning"
            }
        }
        "error" {
            return @{
                Title = "Codex Failed"
                Priority = "urgent"
                Tags = "computer,x"
            }
        }
    }
}

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $PSScriptRoot "ntfy.config.json"
}

$config = $null
if (Test-Path -LiteralPath $ConfigPath) {
    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
}

$resolvedServer = if ($Server) { $Server } else { Get-ConfigValue -Config $config -Name "server" -Fallback "https://ntfy.sh" }
$resolvedTopic = if ($Topic) { $Topic } else { Get-ConfigValue -Config $config -Name "topic" }
$resolvedClick = if ($Click) { $Click } else { Get-ConfigValue -Config $config -Name "clickUrl" }
$resolvedStatus = if ($config -and $config.PSObject.Properties["defaultStatus"] -and $config.defaultStatus) { "$($config.defaultStatus)" } else { $Status }
$statusDefaults = Resolve-StatusDefaults -ResolvedStatus $resolvedStatus
$resolvedDefaultTitle = if ($Title) { $Title } else { Get-ConfigValue -Config $config -Name "defaultTitle" -Fallback $statusDefaults.Title }
$resolvedDefaultTags = if ($Tags) { $Tags } else { Get-ConfigValue -Config $config -Name "defaultTags" -Fallback $statusDefaults.Tags }
$resolvedDefaultPriority = if ($Priority) { $Priority } else { Get-ConfigValue -Config $config -Name "defaultPriority" -Fallback $statusDefaults.Priority }
$resolvedTaskName = if ($TaskName) { $TaskName } else { Get-ConfigValue -Config $config -Name "taskName" -Fallback "Task" }
$resolvedMachineName = Get-ConfigValue -Config $config -Name "machineName" -Fallback $env:COMPUTERNAME
$resolvedAuthToken = if ($AuthToken) { $AuthToken } else { Get-ConfigValue -Config $config -Name "authToken" }
$authTokenEnvVar = Get-ConfigValue -Config $config -Name "authTokenEnvVar"

if (-not $resolvedAuthToken -and $authTokenEnvVar) {
    $envToken = [Environment]::GetEnvironmentVariable($authTokenEnvVar)
    if ($envToken) {
        $resolvedAuthToken = $envToken
    }
}

if (-not $resolvedTopic) {
    throw "No topic configured. Add `"topic`" to ntfy.config.json or pass -Topic."
}

$uri = "{0}/{1}" -f $resolvedServer.TrimEnd("/"), $resolvedTopic
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
$body = $Message

if ($IncludeContext) {
    $contextLines = @(
        ""
        "Task: $resolvedTaskName"
        "Status: $resolvedStatus"
        "Time: $now"
        "Machine: $resolvedMachineName"
    )

    $body = ($body.TrimEnd(), ($contextLines -join [Environment]::NewLine)) -join [Environment]::NewLine
}

$headers = @{
    Title    = $resolvedDefaultTitle
    Priority = $resolvedDefaultPriority
    Tags     = $resolvedDefaultTags
}

if ($resolvedClick) {
    $headers["Click"] = $resolvedClick
}

if ($resolvedAuthToken) {
    $headers["Authorization"] = "Bearer $resolvedAuthToken"
}

$request = @{
    Method  = "POST"
    Uri     = $uri
    Headers = $headers
    Body    = $body
}

$response = Invoke-RestMethod @request

if ($null -ne $response.id) {
    Write-Output ("Sent notification to {0} (id: {1})" -f $uri, $response.id)
} else {
    Write-Output ("Sent notification to {0}" -f $uri)
}
