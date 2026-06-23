[CmdletBinding()]
param(
    [string]$Title,
    [string]$Subtitle,
    [string]$Body,
    [string]$BarkUrl,
    [string]$ConfigPath
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

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $PSScriptRoot "CodexBark.config.json"
}

$config = $null
if (Test-Path -LiteralPath $ConfigPath) {
    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
}

$stdinText = ""
if ([Console]::IsInputRedirected) {
    $stdinText = [Console]::In.ReadToEnd()
}
$hookPayload = $null
$isHookInvocation = $false

if ($stdinText -and $stdinText.Trim().StartsWith("{")) {
    $hookPayload = $stdinText | ConvertFrom-Json
    if ($hookPayload.hook_event_name -eq "Stop") {
        $isHookInvocation = $true
    }
}

$resolvedBarkUrl = if ($BarkUrl) { $BarkUrl } else { Get-ConfigValue -Config $config -Name "barkUrl" }
if (-not $resolvedBarkUrl) {
    throw "No Bark URL configured. Add `"barkUrl`" to CodexBark.config.json or pass -BarkUrl."
}

$resolvedTitle = if ($Title) { $Title } else { Get-ConfigValue -Config $config -Name "defaultTitle" -Fallback "Task done" }
$resolvedSubtitle = if ($Subtitle) { $Subtitle } else { Get-ConfigValue -Config $config -Name "defaultSubtitle" }
$resolvedBody = if ($Body) { $Body } else { Get-ConfigValue -Config $config -Name "defaultBody" }

if ($isHookInvocation) {
    $resolvedTitle = Get-ConfigValue -Config $config -Name "defaultTitle" -Fallback "Task done"
    $resolvedSubtitle = Get-ConfigValue -Config $config -Name "defaultSubtitle"
    $resolvedBody = Get-ConfigValue -Config $config -Name "defaultBody"
}

$payload = @{
    title = $resolvedTitle
    group = Get-ConfigValue -Config $config -Name "defaultGroup" -Fallback "codex"
    sound = Get-ConfigValue -Config $config -Name "defaultSound" -Fallback "alarm"
    level = Get-ConfigValue -Config $config -Name "defaultLevel" -Fallback "timeSensitive"
}

if ($resolvedSubtitle) {
    $payload.subtitle = $resolvedSubtitle
}

if ($resolvedBody) {
    $payload.body = $resolvedBody
}

$uri = $resolvedBarkUrl.TrimEnd("/") + "/"
$response = Invoke-RestMethod -Method Post -Uri $uri -Body $payload

if ($null -ne $response -and $null -ne $response.code -and $response.code -ne 200) {
    throw "Bark push failed: $($response.message)"
}

if ($isHookInvocation) {
    Write-Output "{}"
} else {
    Write-Output ("Sent Bark notification to {0}" -f $uri)
}
