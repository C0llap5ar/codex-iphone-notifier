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
    $coreScriptPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "CodexMonitor.Core.ps1"
    . $coreScriptPath
    $config = Get-CodexBarkConfigFromPath -Path $ConfigPath
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

$defaultTitle = if (Get-Command Get-CodexMonitorDefaultNotificationTitle -ErrorAction SilentlyContinue) {
    Get-CodexMonitorDefaultNotificationTitle
}
else {
    [string]::Concat([char]0x5DF2, [char]0x5B8C, [char]0x6210, [char]0x4EFB, [char]0x52A1)
}

$resolvedTitle = if ($Title) { $Title } else { Get-ConfigValue -Config $config -Name "defaultTitle" -Fallback $defaultTitle }
$resolvedSubtitle = if ($Subtitle) { $Subtitle } else { Get-ConfigValue -Config $config -Name "defaultSubtitle" }
$resolvedBody = if ($Body) { $Body } else { Get-ConfigValue -Config $config -Name "defaultBody" }

if ($isHookInvocation) {
    $resolvedTitle = Get-ConfigValue -Config $config -Name "defaultTitle" -Fallback $defaultTitle
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
$jsonBody = $payload | ConvertTo-Json -Depth 4 -Compress
$utf8 = [System.Text.UTF8Encoding]::new($false)
$bodyBytes = $utf8.GetBytes($jsonBody)
$response = Invoke-RestMethod -Method Post -Uri $uri -ContentType "application/json; charset=utf-8" -Body $bodyBytes

if ($null -ne $response -and $null -ne $response.code -and $response.code -ne 200) {
    throw "Bark push failed: $($response.message)"
}

if ($isHookInvocation) {
    Write-Output "{}"
} else {
    Write-Output ("Sent Bark notification to {0}" -f $uri)
}
