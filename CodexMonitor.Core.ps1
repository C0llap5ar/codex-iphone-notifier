$script:CodexMonitorRepoRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($ScriptRoot) { $ScriptRoot } else { (Get-Location).Path }
$script:CodexMonitorMonitorDir = Join-Path $script:CodexMonitorRepoRoot "outputs\codex-task-monitor"
$script:CodexMonitorPaths = @{
    MonitorConfig = Join-Path $script:CodexMonitorMonitorDir "CodexTaskMonitor.config.json"
    BarkConfig = Join-Path $script:CodexMonitorRepoRoot "outputs\bark-notify\CodexBark.config.json"
    MonitorStart = Join-Path $script:CodexMonitorMonitorDir "Start-CodexTaskMonitor.ps1"
    MonitorStop = Join-Path $script:CodexMonitorMonitorDir "Stop-CodexTaskMonitor.ps1"
    MonitorStatus = Join-Path $script:CodexMonitorMonitorDir "Get-CodexTaskMonitorStatus.ps1"
    DashboardStart = Join-Path $script:CodexMonitorMonitorDir "Start-CodexTaskMonitorDashboard.ps1"
    DashboardStop = Join-Path $script:CodexMonitorMonitorDir "Stop-CodexTaskMonitorDashboard.ps1"
    DashboardPid = Join-Path $script:CodexMonitorMonitorDir "dashboard.pid"
    ExportSnapshot = Join-Path $script:CodexMonitorMonitorDir "Export-CodexTaskMonitorSnapshot.ps1"
    StatusJson = Join-Path $script:CodexMonitorMonitorDir "status.json"
    TestScript = Join-Path $script:CodexMonitorRepoRoot "Test-CodexMonitor.ps1"
    StartupInstall = Join-Path $script:CodexMonitorRepoRoot "Install-CodexMonitorStartup.ps1"
    StartupUninstall = Join-Path $script:CodexMonitorRepoRoot "Uninstall-CodexMonitorStartup.ps1"
    ArchiveDir = Join-Path $script:CodexMonitorMonitorDir "archive"
}

function Test-CodexMonitorTransientFileMessage {
    param(
        [string]$Message
    )

    if ([string]::IsNullOrWhiteSpace($Message)) {
        return $false
    }

    $normalized = $Message.ToLowerInvariant()
    foreach ($pattern in @(
        "*stream was not readable*",
        "*used by another process*",
        "*process cannot access the file*",
        "*cannot access the file*",
        "*because it is being used*",
        "*sharing violation*",
        "*the handle is invalid*",
        "*unexpected end*",
        "*unterminated string*",
        "*after parsing a value an unexpected character*",
        "*additional text encountered after finished reading json content*"
    )) {
        if ($normalized -like $pattern) {
            return $true
        }
    }

    return $false
}

function Invoke-CodexMonitorRetry {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Operation,
        [int]$MaxAttempts = 4,
        [int]$RetryDelayMs = 80,
        [scriptblock]$ShouldRetry
    )

    $attempt = 0
    while ($attempt -lt $MaxAttempts) {
        $attempt++
        try {
            return & $Operation
        }
        catch {
            $canRetry = $attempt -lt $MaxAttempts
            if ($canRetry -and $ShouldRetry -and (& $ShouldRetry $_)) {
                Start-Sleep -Milliseconds $RetryDelayMs
                continue
            }

            throw
        }
    }
}

function Write-CodexMonitorFileAtomically {
    param(
        [string]$Path,
        [string]$Content,
        [System.Text.Encoding]$Encoding = $null
    )

    if (-not $Encoding) {
        $Encoding = [System.Text.UTF8Encoding]::new($false)
    }

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }

    $fileName = [System.IO.Path]::GetFileName($Path)
    $tempPath = Join-Path $parent ("{0}.{1}.tmp" -f $fileName, [System.Guid]::NewGuid().ToString("N"))
    $backupPath = Join-Path $parent ("{0}.{1}.bak" -f $fileName, [System.Guid]::NewGuid().ToString("N"))

    try {
        [System.IO.File]::WriteAllText($tempPath, $Content, $Encoding)
        if (Test-Path -LiteralPath $Path) {
            [System.IO.File]::Replace($tempPath, $Path, $backupPath, $false)
            if (Test-Path -LiteralPath $backupPath) {
                Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
            }
        }
        else {
            [System.IO.File]::Move($tempPath, $Path)
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $backupPath) {
            Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Read-CodexMonitorTextFile {
    param(
        [string]$Path,
        [string]$Description = "file",
        [int]$MaxAttempts = 4,
        [int]$RetryDelayMs = 80
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    try {
        Invoke-CodexMonitorRetry -MaxAttempts $MaxAttempts -RetryDelayMs $RetryDelayMs -ShouldRetry {
            param($ErrorRecord)
            Test-CodexMonitorTransientFileMessage -Message $ErrorRecord.Exception.Message
        } -Operation {
            $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
            [System.IO.File]::ReadAllText($Path, $utf8)
        }
    }
    catch {
        throw "Could not read $Description '$Path'. $($_.Exception.Message)"
    }
}

function Read-CodexMonitorJsonFile {
    param(
        [string]$Path,
        [string]$Description = "JSON file",
        [switch]$RetryOnInvalidJson,
        [int]$MaxAttempts = 4,
        [int]$RetryDelayMs = 80
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $attempt = 0
    while ($attempt -lt $MaxAttempts) {
        $attempt++
        $rawContent = Read-CodexMonitorTextFile -Path $Path -Description $Description -MaxAttempts $MaxAttempts -RetryDelayMs $RetryDelayMs

        if ([string]::IsNullOrWhiteSpace($rawContent)) {
            if ($attempt -lt $MaxAttempts -and $RetryOnInvalidJson) {
                Start-Sleep -Milliseconds $RetryDelayMs
                continue
            }

            throw "Invalid JSON in $Description '$Path'. The file is empty."
        }

        try {
            return $rawContent | ConvertFrom-Json
        }
        catch {
            $message = $_.Exception.Message
            if ($attempt -lt $MaxAttempts -and $RetryOnInvalidJson -and (Test-CodexMonitorTransientFileMessage -Message $message)) {
                Start-Sleep -Milliseconds $RetryDelayMs
                continue
            }

            throw "Invalid JSON in $Description '$Path'. $message"
        }
    }
}

function Write-CodexMonitorJsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }

    $json = $Value | ConvertTo-Json -Depth 8
    Write-CodexMonitorFileAtomically -Path $Path -Content $json
}

function Read-CodexMonitorLogTail {
    param(
        [string]$Path,
        [int]$TailLines = 20,
        [int]$MaxAttempts = 4,
        [int]$RetryDelayMs = 80
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    try {
        $lines = Invoke-CodexMonitorRetry -MaxAttempts $MaxAttempts -RetryDelayMs $RetryDelayMs -ShouldRetry {
            param($ErrorRecord)
            Test-CodexMonitorTransientFileMessage -Message $ErrorRecord.Exception.Message
        } -Operation {
            $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
            try {
                $content = [System.IO.File]::ReadAllText($Path, $utf8)
            }
            catch {
                # Fall back to a replacement-based decode so older mixed-encoding
                # log files remain readable instead of disappearing entirely.
                $fallbackUtf8 = [System.Text.UTF8Encoding]::new($false, $false)
                $content = [System.IO.File]::ReadAllText($Path, $fallbackUtf8)
            }
            if ([string]::IsNullOrEmpty($content)) {
                return @()
            }

            $normalized = $content -replace "`r`n", "`n"
            $allLines = @($normalized -split "`n")
            if ($allLines.Count -gt 0 -and $allLines[-1] -eq "") {
                $allLines = @($allLines | Select-Object -SkipLast 1)
            }

            if ($allLines.Count -le $TailLines) {
                return @($allLines)
            }

            @($allLines | Select-Object -Last $TailLines)
        }
        return @($lines)
    }
    catch {
        throw "Could not read monitor log '$Path'. $($_.Exception.Message)"
    }
}

function ConvertTo-CodexMonitorWritableObject {
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject
    )

    $result = [ordered]@{}

    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($key in $InputObject.Keys) {
            $result[[string]$key] = $InputObject[$key]
        }
        return $result
    }

    foreach ($property in $InputObject.PSObject.Properties) {
        if ($property.MemberType -ne "NoteProperty" -and $property.MemberType -ne "Property") {
            continue
        }

        $result[$property.Name] = $property.Value
    }

    return $result
}

function Get-CodexMonitorDefaultMonitorConfig {
    [ordered]@{
        sessionsRoot = (Join-Path $HOME ".codex\sessions")
        barkScriptPath = (Join-Path $script:CodexMonitorRepoRoot "outputs\bark-notify\Send-CodexBark.ps1")
        dashboardPort = 8754
        pollSeconds = 3
        recentFilesToScan = 20
        tailLinesPerFile = 120
        statePath = (Join-Path $script:CodexMonitorMonitorDir "state.json")
        pidPath = (Join-Path $script:CodexMonitorMonitorDir "monitor.pid")
        logPath = (Join-Path $script:CodexMonitorMonitorDir "monitor.log")
    }
}

function Get-CodexMonitorDefaultBarkConfig {
    [ordered]@{
        barkUrl = ""
        defaultTitle = Get-CodexMonitorDefaultNotificationTitle
        defaultSubtitle = ""
        defaultBody = ""
        defaultGroup = "codex"
        defaultSound = "alarm"
        defaultLevel = "timeSensitive"
    }
}

function Get-CodexMonitorDefaultNotificationTitle {
    return [string]::Concat(
        [char]0x5DF2,
        [char]0x5B8C,
        [char]0x6210,
        [char]0x4EFB,
        [char]0x52A1
    )
}

function Test-CodexMonitorDefaultNotificationTitleNeedsRepair {
    param(
        [AllowEmptyString()]
        [string]$Title
    )

    if ([string]::IsNullOrWhiteSpace($Title)) {
        return $true
    }

    $defaultTitle = Get-CodexMonitorDefaultNotificationTitle
    if ($Title -eq $defaultTitle) {
        return $false
    }

    if ($Title -eq "Task done") {
        return $true
    }

    if ($Title.IndexOf([char]0xFFFD) -ge 0) {
        return $true
    }

    foreach ($suspiciousChar in @("鍔", "鎴", "宸", "浠", "诲")) {
        if ($Title.Contains($suspiciousChar)) {
            return $true
        }
    }

    return $false
}

function Test-CodexMonitorPlaceholderPath {
    param(
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $normalized = $Path.Replace("/", "\")
    foreach ($pattern in @(
        "*\Users\YourName\*",
        "C:\path\to\*",
        "*\path\to\repo\*",
        "*\path\to\CodexMonitor\*"
    )) {
        if ($normalized -like $pattern) {
            return $true
        }
    }

    return $false
}

function Repair-CodexMonitorMonitorConfigPlaceholders {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Config
    )

    $repaired = ConvertTo-CodexMonitorWritableObject -InputObject $Config
    $defaults = Get-CodexMonitorDefaultMonitorConfig
    $changed = $false

    foreach ($field in @("sessionsRoot", "barkScriptPath", "statePath", "pidPath", "logPath")) {
        if (Test-CodexMonitorPlaceholderPath -Path ([string]$repaired[$field])) {
            $repaired[$field] = $defaults[$field]
            $changed = $true
        }
    }

    foreach ($field in @("barkScriptPath", "statePath", "pidPath", "logPath")) {
        $currentPath = [string]$repaired[$field]
        if (-not [string]::IsNullOrWhiteSpace($currentPath) -and -not [System.IO.Path]::IsPathRooted($currentPath)) {
            $repaired[$field] = $defaults[$field]
            $changed = $true
        }
    }

    [pscustomobject]@{
        Config = $repaired
        Changed = $changed
    }
}

function Merge-CodexMonitorConfigWithDefaults {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Config,
        [Parameter(Mandatory = $true)]
        [hashtable]$Defaults
    )

    $source = ConvertTo-CodexMonitorWritableObject -InputObject $Config
    $merged = [ordered]@{}
    $changed = $false

    foreach ($name in $Defaults.Keys) {
        if ($source.Contains($name)) {
            $value = $source[$name]
            if ($null -eq $value -or ($value -is [string] -and [string]::IsNullOrWhiteSpace($value))) {
                $merged[$name] = $Defaults[$name]
                $changed = $true
            }
            else {
                $merged[$name] = $value
            }
        }
        else {
            $merged[$name] = $Defaults[$name]
            $changed = $true
        }
    }

    foreach ($name in $source.Keys) {
        if (-not $merged.Contains($name)) {
            $merged[$name] = $source[$name]
        }
    }

    [pscustomobject]@{
        Config = $merged
        Changed = $changed
    }
}

function Assert-CodexMonitorRequiredStringField {
    param(
        [hashtable]$Config,
        [string]$Name
    )

    if (-not $Config.Contains($Name) -or [string]::IsNullOrWhiteSpace([string]$Config[$Name])) {
        throw "Config field '$Name' is required."
    }
}

function Assert-CodexMonitorIntField {
    param(
        [hashtable]$Config,
        [string]$Name,
        [int]$Minimum,
        [int]$Maximum
    )

    $value = 0
    if (-not [int]::TryParse([string]$Config[$Name], [ref]$value)) {
        throw "Config field '$Name' must be an integer."
    }

    if ($value -lt $Minimum -or $value -gt $Maximum) {
        throw "Config field '$Name' must be between $Minimum and $Maximum."
    }

    $Config[$Name] = $value
}

function Assert-CodexMonitorUriField {
    param(
        [hashtable]$Config,
        [string]$Name
    )

    $value = [string]$Config[$Name]
    if ([string]::IsNullOrWhiteSpace($value)) {
        return
    }

    $uri = $null
    if (-not [System.Uri]::TryCreate($value, [System.UriKind]::Absolute, [ref]$uri)) {
        throw "Config field '$Name' must be a valid absolute URL."
    }

    if ($uri.Scheme -notin @("http", "https")) {
        throw "Config field '$Name' must start with http:// or https://."
    }
}

function Assert-CodexMonitorConfigValid {
    param(
        [hashtable]$Config
    )

    Assert-CodexMonitorRequiredStringField -Config $Config -Name "sessionsRoot"
    Assert-CodexMonitorRequiredStringField -Config $Config -Name "barkScriptPath"
    Assert-CodexMonitorRequiredStringField -Config $Config -Name "statePath"
    Assert-CodexMonitorRequiredStringField -Config $Config -Name "pidPath"
    Assert-CodexMonitorRequiredStringField -Config $Config -Name "logPath"
    Assert-CodexMonitorIntField -Config $Config -Name "dashboardPort" -Minimum 1 -Maximum 65535
    Assert-CodexMonitorIntField -Config $Config -Name "pollSeconds" -Minimum 1 -Maximum 3600
    Assert-CodexMonitorIntField -Config $Config -Name "recentFilesToScan" -Minimum 1 -Maximum 5000
    Assert-CodexMonitorIntField -Config $Config -Name "tailLinesPerFile" -Minimum 1 -Maximum 5000
}

function Assert-CodexBarkConfigValid {
    param(
        [hashtable]$Config
    )

    Assert-CodexMonitorRequiredStringField -Config $Config -Name "defaultTitle"
    Assert-CodexMonitorRequiredStringField -Config $Config -Name "defaultGroup"
    Assert-CodexMonitorRequiredStringField -Config $Config -Name "defaultSound"
    Assert-CodexMonitorRequiredStringField -Config $Config -Name "defaultLevel"
    Assert-CodexMonitorUriField -Config $Config -Name "barkUrl"
}

function Get-CodexMonitorConfigFromPath {
    param(
        [string]$Path,
        [switch]$SkipWriteBack
    )

    $config = Read-CodexMonitorJsonFile -Path $Path -Description "config file"
    if (-not $config) {
        throw "Missing monitor config. Run .\Setup-CodexMonitor.ps1 first."
    }

    $merged = Merge-CodexMonitorConfigWithDefaults -Config $config -Defaults (Get-CodexMonitorDefaultMonitorConfig)
    $repair = Repair-CodexMonitorMonitorConfigPlaceholders -Config $merged.Config
    if ($repair.Changed) {
        $merged.Config = $repair.Config
        $merged.Changed = $true
    }
    Assert-CodexMonitorConfigValid -Config $merged.Config

    if ($merged.Changed -and -not $SkipWriteBack) {
        Write-CodexMonitorJsonFile -Path $Path -Value $merged.Config
    }

    return [pscustomobject]$merged.Config
}

function Get-CodexBarkConfigFromPath {
    param(
        [string]$Path,
        [switch]$SkipWriteBack
    )

    $config = Read-CodexMonitorJsonFile -Path $Path -Description "config file"
    if (-not $config) {
        throw "Missing Bark config. Run .\Setup-CodexMonitor.ps1 first."
    }

    $merged = Merge-CodexMonitorConfigWithDefaults -Config $config -Defaults (Get-CodexMonitorDefaultBarkConfig)
    if (Test-CodexMonitorDefaultNotificationTitleNeedsRepair -Title ([string]$merged.Config["defaultTitle"])) {
        $merged.Config["defaultTitle"] = Get-CodexMonitorDefaultNotificationTitle
        $merged.Changed = $true
    }
    Assert-CodexBarkConfigValid -Config $merged.Config

    if ($merged.Changed -and -not $SkipWriteBack) {
        Write-CodexMonitorJsonFile -Path $Path -Value $merged.Config
    }

    return [pscustomobject]$merged.Config
}

function Get-CodexMonitorPaths {
    return $script:CodexMonitorPaths
}

function Get-CodexMonitorConfig {
    Get-CodexMonitorConfigFromPath -Path $script:CodexMonitorPaths.MonitorConfig
}

function Get-CodexBarkConfig {
    Get-CodexBarkConfigFromPath -Path $script:CodexMonitorPaths.BarkConfig
}

function Resolve-CodexMonitorDashboardPort {
    param(
        [Nullable[int]]$Port
    )

    if ($Port.HasValue -and $Port.Value -gt 0) {
        return $Port.Value
    }

    $config = Get-CodexMonitorConfig
    if ($null -ne $config.PSObject.Properties["dashboardPort"] -and [int]$config.dashboardPort -gt 0) {
        return [int]$config.dashboardPort
    }

    return 8754
}

function Get-CodexMonitorAppSettings {
    $monitorConfig = Get-CodexMonitorConfig
    $barkConfig = Get-CodexBarkConfig

    [pscustomobject]@{
        dashboardPort = Resolve-CodexMonitorDashboardPort
        barkUrl = if ($barkConfig.barkUrl) { [string]$barkConfig.barkUrl } else { "" }
        sessionsRoot = [string]$monitorConfig.sessionsRoot
        monitorConfigPath = $script:CodexMonitorPaths.MonitorConfig
        barkConfigPath = $script:CodexMonitorPaths.BarkConfig
    }
}

function Test-CodexMonitorConfiguration {
    $monitorConfig = Get-CodexMonitorConfig
    $barkConfig = Get-CodexBarkConfig
    $dashboardPort = Resolve-CodexMonitorDashboardPort

    [pscustomobject]@{
        ok = $true
        monitorConfigPath = $script:CodexMonitorPaths.MonitorConfig
        barkConfigPath = $script:CodexMonitorPaths.BarkConfig
        dashboardPort = $dashboardPort
        barkUrlConfigured = -not [string]::IsNullOrWhiteSpace([string]$barkConfig.barkUrl)
        sessionsRootExists = Test-Path -LiteralPath $monitorConfig.sessionsRoot
        barkScriptExists = Test-Path -LiteralPath $monitorConfig.barkScriptPath
        stateDirectoryExists = Test-Path -LiteralPath (Split-Path -Parent $monitorConfig.statePath)
        logDirectoryExists = Test-Path -LiteralPath (Split-Path -Parent $monitorConfig.logPath)
    }
}

function Get-CodexMonitorDiagnosticSummary {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$ActionLabel,
        [Nullable[int]]$Port
    )

    $message = ""
    if ($ErrorRecord -and $ErrorRecord.Exception) {
        $message = [string]$ErrorRecord.Exception.Message
    }

    $portValue = Resolve-CodexMonitorDashboardPort -Port $Port
    $normalized = $message.ToLowerInvariant()

    if ($normalized -like "*port $portValue is already in use*") {
        return [pscustomobject]@{
            Title = "Dashboard port is already in use"
            UserMessage = "Port $portValue is occupied by another process. Change the dashboard port in settings or close the app that is already using it."
            RecoveryHint = "Open Notification Settings, choose a different Dashboard Port, save, then start services again."
        }
    }

    if ($normalized -like "*did not start listening on port*") {
        return [pscustomobject]@{
            Title = "Dashboard did not come online"
            UserMessage = "The dashboard process started, but nothing began listening on port $portValue."
            RecoveryHint = "Try Restart Services. If it still fails, switch to another port and try again."
        }
    }

    if ($normalized -like "*monitor process did not stay running*") {
        return [pscustomobject]@{
            Title = "Monitor process exited too early"
            UserMessage = "The background monitor launched and then stopped immediately."
            RecoveryHint = "Check the recent log and config paths, then try Start again."
        }
    }

    if ($normalized -like "*invalid json in config file*") {
        return [pscustomobject]@{
            Title = "A config file is damaged"
            UserMessage = "One of the local config files contains invalid JSON and could not be read."
            RecoveryHint = "Open the config file mentioned in System Notes, fix the JSON, or restore it from a backup."
        }
    }

    if (
        $normalized -like "*invalid json in status snapshot*" -or
        $normalized -like "*could not read status snapshot*" -or
        $normalized -like "*invalid json in monitor state file*" -or
        $normalized -like "*could not read monitor state file*" -or
        $normalized -like "*could not read monitor log*"
    ) {
        return [pscustomobject]@{
            Title = if ($ActionLabel) { "$ActionLabel delayed" } else { "Status refresh delayed" }
            UserMessage = "The app hit a temporary file access conflict while refreshing live status."
            RecoveryHint = "Wait a moment and refresh again. If it keeps happening, restart the monitor services."
        }
    }

    if ($normalized -like "*missing monitor config*") {
        return [pscustomobject]@{
            Title = "Monitor config is missing"
            UserMessage = "The monitor config file does not exist yet."
            RecoveryHint = "Run Setup-CodexMonitor.ps1 or save settings from the GUI to recreate the config."
        }
    }

    if ($normalized -like "*missing bark config*") {
        return [pscustomobject]@{
            Title = "Bark config is missing"
            UserMessage = "The Bark config file does not exist yet."
            RecoveryHint = "Save a Bark URL in Notification Settings, then send a test notification again."
        }
    }

    if ($normalized -like "*bark url cannot be empty*") {
        return [pscustomobject]@{
            Title = "Bark URL is empty"
            UserMessage = "A Bark device URL is required before notifications can be sent."
            RecoveryHint = "Paste your Bark URL into Notification Settings and save."
        }
    }

    if ($normalized -like "*must be a valid absolute url*" -or $normalized -like "*must start with http:// or https://*") {
        return [pscustomobject]@{
            Title = "Bark URL format is invalid"
            UserMessage = "The saved Bark URL is not a valid absolute address."
            RecoveryHint = "Use the full Bark device URL, for example https://api.day.app/your-device-key/."
        }
    }

    if ($normalized -like "*dashboard port must be*" -or $normalized -like "*config field 'dashboardport'*") {
        return [pscustomobject]@{
            Title = "Dashboard port is invalid"
            UserMessage = "The dashboard port value is missing or outside the valid range."
            RecoveryHint = "Choose a port between 1 and 65535, then save settings again."
        }
    }

    if ($normalized -like "*bark push failed*" -or $normalized -like "*no bark url configured*") {
        return [pscustomobject]@{
            Title = "Notification delivery failed"
            UserMessage = "The monitor could not deliver a Bark push with the current configuration."
            RecoveryHint = "Verify the Bark URL, then use Send Test Notification again."
        }
    }

    if ($normalized -like "*dashboard process stopped, but port*" -or $normalized -like "*port * is open, but no dashboard pid file was found*") {
        return [pscustomobject]@{
            Title = "Dashboard state is inconsistent"
            UserMessage = "The dashboard process and the dashboard port disagree about the current state."
            RecoveryHint = "Stop Services, wait a few seconds, then Start again. If needed, change the port."
        }
    }

    [pscustomobject]@{
        Title = if ($ActionLabel) { "$ActionLabel failed" } else { "Codex Monitor error" }
        UserMessage = if ($message) { $message } else { "An unexpected error occurred." }
        RecoveryHint = "Review System Notes and Recent Log, then try the action again."
    }
}

function Save-CodexMonitorAppSettings {
    param(
        [string]$BarkUrl,
        [int]$DashboardPort
    )

    $trimmedBarkUrl = if ($null -ne $BarkUrl) { $BarkUrl.Trim() } else { "" }
    if (-not $trimmedBarkUrl) {
        throw "Bark URL cannot be empty."
    }

    if ($DashboardPort -lt 1 -or $DashboardPort -gt 65535) {
        throw "Dashboard port must be between 1 and 65535."
    }

    $monitorConfig = ConvertTo-CodexMonitorWritableObject -InputObject (Get-CodexMonitorConfig)
    $barkConfig = Read-CodexMonitorJsonFile -Path $script:CodexMonitorPaths.BarkConfig -Description "Bark config file"

    if (-not $barkConfig) {
        $barkConfig = [ordered]@{
            barkUrl = $trimmedBarkUrl
            defaultTitle = Get-CodexMonitorDefaultNotificationTitle
            defaultSubtitle = ""
            defaultBody = ""
            defaultGroup = "codex"
            defaultSound = "alarm"
            defaultLevel = "timeSensitive"
        }
    }
    else {
        $barkConfig = ConvertTo-CodexMonitorWritableObject -InputObject $barkConfig
        $barkConfig["barkUrl"] = $trimmedBarkUrl
        if (Test-CodexMonitorDefaultNotificationTitleNeedsRepair -Title ([string]$barkConfig["defaultTitle"])) {
            $barkConfig["defaultTitle"] = Get-CodexMonitorDefaultNotificationTitle
        }
    }

    $monitorConfig["dashboardPort"] = $DashboardPort

    Write-CodexMonitorJsonFile -Path $script:CodexMonitorPaths.BarkConfig -Value $barkConfig
    Write-CodexMonitorJsonFile -Path $script:CodexMonitorPaths.MonitorConfig -Value $monitorConfig

    Get-CodexMonitorAppSettings
}

function Get-CodexMonitorStartupTaskName {
    return "CodexTaskMonitor"
}

function Get-CodexMonitorDashboardUrl {
    param(
        [Nullable[int]]$Port
    )

    $Port = Resolve-CodexMonitorDashboardPort -Port $Port
    return "http://127.0.0.1:$Port/"
}

function Test-CodexMonitorTcpPort {
    param(
        [int]$Port,
        [string]$TargetHost = "127.0.0.1",
        [int]$TimeoutMs = 800
    )

    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $async = $client.BeginConnect($TargetHost, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMs)) {
            return $false
        }

        $client.EndConnect($async)
        return $true
    }
    catch {
        return $false
    }
    finally {
        $client.Dispose()
    }
}

function Wait-CodexMonitorTcpPortState {
    param(
        [int]$Port,
        [bool]$ExpectedOpen,
        [int]$TimeoutMs = 5000,
        [int]$PollIntervalMs = 250
    )

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMs)
    while ([DateTime]::UtcNow -lt $deadline) {
        $isOpen = Test-CodexMonitorTcpPort -Port $Port
        if ($isOpen -eq $ExpectedOpen) {
            return $true
        }

        Start-Sleep -Milliseconds $PollIntervalMs
    }

    return $false
}

function Remove-CodexMonitorStalePidFile {
    param(
        [string]$PidPath
    )

    if (-not (Test-Path -LiteralPath $PidPath)) {
        return $false
    }

    $pidValue = (Get-Content -LiteralPath $PidPath -Raw -ErrorAction SilentlyContinue).Trim()
    if (-not $pidValue) {
        Remove-Item -LiteralPath $PidPath -Force -ErrorAction SilentlyContinue
        return $true
    }

    $process = Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue
    if (-not $process) {
        Remove-Item -LiteralPath $PidPath -Force -ErrorAction SilentlyContinue
        return $true
    }

    return $false
}

function Get-CodexMonitorProcessState {
    param(
        [string]$PidPath
    )

    $pidValue = $null
    $running = $false

    if (Test-Path -LiteralPath $PidPath) {
        $pidRaw = Get-Content -LiteralPath $PidPath -Raw -ErrorAction SilentlyContinue
        if ($null -ne $pidRaw) {
            $pidValue = $pidRaw.Trim()
        }
        if ($pidValue) {
            $running = $null -ne (Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue)
        }
    }

    [pscustomobject]@{
        pidPath = $PidPath
        pid = $pidValue
        running = $running
    }
}

function Get-CodexMonitorDashboardState {
    param(
        [Nullable[int]]$Port
    )

    $Port = Resolve-CodexMonitorDashboardPort -Port $Port
    $state = Get-CodexMonitorProcessState -PidPath $script:CodexMonitorPaths.DashboardPid
    $portOpen = Test-CodexMonitorTcpPort -Port $Port

    [pscustomobject]@{
        pidPath = $state.pidPath
        pid = $state.pid
        running = ($state.running -and $portOpen)
        processRunning = $state.running
        portOpen = $portOpen
        port = $Port
    }
}

function Export-CodexMonitorStatusSnapshot {
    param(
        [string]$OutputPath
    )

    $configPath = $script:CodexMonitorPaths.MonitorConfig
    if (-not $OutputPath) {
        $OutputPath = $script:CodexMonitorPaths.StatusJson
    }

    & $script:CodexMonitorPaths.ExportSnapshot -ConfigPath $configPath -OutputPath $OutputPath | Out-Null
    Read-CodexMonitorJsonFile -Path $OutputPath -Description "status snapshot" -RetryOnInvalidJson
}

function Get-CodexMonitorStatusData {
    param(
        [Nullable[int]]$Port,
        [int]$TailLines = 20
    )

    $config = Get-CodexMonitorConfig
    $Port = Resolve-CodexMonitorDashboardPort -Port $Port
    $monitorState = Get-CodexMonitorProcessState -PidPath $config.pidPath
    $dashboardState = Get-CodexMonitorDashboardState -Port $Port
    $snapshot = Export-CodexMonitorStatusSnapshot
    $startup = Get-CodexMonitorStartupStatus
    $recentLog = @()

    if ($snapshot -and $snapshot.logTail) {
        $recentLog = @($snapshot.logTail | Select-Object -Last $TailLines)
    }

    [pscustomobject]@{
        config = $config
        monitorState = $monitorState
        dashboardState = $dashboardState
        snapshot = $snapshot
        startup = $startup
        recentLog = $recentLog
        dashboardUrl = Get-CodexMonitorDashboardUrl -Port $Port
    }
}

function Move-CodexMonitorFileToArchive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$ArchiveRoot
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    if (-not (Test-Path -LiteralPath $ArchiveRoot)) {
        New-Item -ItemType Directory -Path $ArchiveRoot | Out-Null
    }

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $extension = [System.IO.Path]::GetExtension($Path)
    $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $archivePath = Join-Path $ArchiveRoot ("{0}-{1}{2}" -f $baseName, $timestamp, $extension)
    $suffix = 1
    while (Test-Path -LiteralPath $archivePath) {
        $archivePath = Join-Path $ArchiveRoot ("{0}-{1}-{2}{3}" -f $baseName, $timestamp, $suffix, $extension)
        $suffix++
    }

    Move-Item -LiteralPath $Path -Destination $archivePath -Force
    return $archivePath
}

function Invoke-CodexMonitorCleanupAndRebuild {
    param(
        [Nullable[int]]$Port
    )

    $config = Get-CodexMonitorConfig
    $Port = Resolve-CodexMonitorDashboardPort -Port $Port
    $monitorState = Get-CodexMonitorProcessState -PidPath $config.pidPath
    $dashboardState = Get-CodexMonitorDashboardState -Port $Port
    $restoreMonitor = [bool]$monitorState.running
    $restoreDashboard = [bool]$dashboardState.processRunning
    $archivedPaths = @()
    $hadRunningServices = $restoreMonitor -or $restoreDashboard

    if ($hadRunningServices) {
        Stop-CodexMonitorServices
    }

    try {
        foreach ($path in @($config.logPath, $config.statePath, $script:CodexMonitorPaths.StatusJson)) {
            $archivedPath = Move-CodexMonitorFileToArchive -Path $path -ArchiveRoot $script:CodexMonitorPaths.ArchiveDir
            if ($archivedPath) {
                $archivedPaths += $archivedPath
            }
        }

        if ($restoreMonitor) {
            & $script:CodexMonitorPaths.MonitorStart -ConfigPath $script:CodexMonitorPaths.MonitorConfig | Out-Null
        }

        if ($restoreDashboard) {
            & $script:CodexMonitorPaths.DashboardStart -Port $Port | Out-Null
        }

        if ($restoreMonitor -or $restoreDashboard) {
            Start-Sleep -Milliseconds 600
        }

        $snapshot = Export-CodexMonitorStatusSnapshot
        return [pscustomobject]@{
            archivedPaths = @($archivedPaths)
            archivedCount = @($archivedPaths).Count
            archiveDirectory = $script:CodexMonitorPaths.ArchiveDir
            monitorRestored = $restoreMonitor
            dashboardRestored = $restoreDashboard
            snapshotGeneratedAt = if ($snapshot) { $snapshot.generatedAt } else { $null }
        }
    }
    catch {
        if ($restoreMonitor) {
            try {
                $currentMonitorState = Get-CodexMonitorProcessState -PidPath $config.pidPath
                if (-not $currentMonitorState.running) {
                    & $script:CodexMonitorPaths.MonitorStart -ConfigPath $script:CodexMonitorPaths.MonitorConfig | Out-Null
                }
            }
            catch {
            }
        }

        if ($restoreDashboard) {
            try {
                $currentDashboardState = Get-CodexMonitorDashboardState -Port $Port
                if (-not $currentDashboardState.processRunning) {
                    & $script:CodexMonitorPaths.DashboardStart -Port $Port | Out-Null
                }
            }
            catch {
            }
        }

        throw
    }
}

function Start-CodexMonitorServices {
    param(
        [Nullable[int]]$Port
    )

    $Port = Resolve-CodexMonitorDashboardPort -Port $Port
    & $script:CodexMonitorPaths.MonitorStart -ConfigPath $script:CodexMonitorPaths.MonitorConfig
    & $script:CodexMonitorPaths.DashboardStart -Port $Port
}

function Stop-CodexMonitorServices {
    & $script:CodexMonitorPaths.DashboardStop
    & $script:CodexMonitorPaths.MonitorStop -ConfigPath $script:CodexMonitorPaths.MonitorConfig
    Start-Sleep -Milliseconds 500
}

function Restart-CodexMonitorServices {
    param(
        [Nullable[int]]$Port
    )

    $Port = Resolve-CodexMonitorDashboardPort -Port $Port
    Stop-CodexMonitorServices
    Start-Sleep -Milliseconds 500
    Start-CodexMonitorServices -Port $Port
}

function Open-CodexMonitorDashboard {
    param(
        [Nullable[int]]$Port
    )

    $Port = Resolve-CodexMonitorDashboardPort -Port $Port
    $dashboardState = Get-CodexMonitorProcessState -PidPath $script:CodexMonitorPaths.DashboardPid
    if (-not $dashboardState.running) {
        & $script:CodexMonitorPaths.DashboardStart -Port $Port | Out-Null
    }

    $url = Get-CodexMonitorDashboardUrl -Port $Port
    Start-Process $url
    return $url
}

function Invoke-CodexMonitorHealthCheck {
    param(
        [Nullable[int]]$Port
    )

    $Port = Resolve-CodexMonitorDashboardPort -Port $Port
    & $script:CodexMonitorPaths.TestScript -SendNotification -StartDashboard -DashboardPort $Port | ConvertFrom-Json
}

function Get-CodexMonitorLogTail {
    param(
        [int]$TailLines = 20
    )

    $config = Get-CodexMonitorConfig
    if (-not (Test-Path -LiteralPath $config.logPath)) {
        return @()
    }

    Read-CodexMonitorLogTail -Path $config.logPath -TailLines $TailLines
}

function Get-CodexMonitorStartupStatus {
    $taskName = Get-CodexMonitorStartupTaskName
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

    [pscustomobject]@{
        taskName = $taskName
        installed = ($null -ne $task)
        state = if ($task) { [string]$task.State } else { "NotInstalled" }
        description = if ($task) { [string]$task.Description } else { "" }
    }
}

function Install-CodexMonitorStartup {
    param(
        [switch]$IncludeDashboard,
        [Nullable[int]]$DashboardPort
    )

    $DashboardPort = Resolve-CodexMonitorDashboardPort -Port $DashboardPort
    $parameters = @{
        TaskName = Get-CodexMonitorStartupTaskName
        DashboardPort = $DashboardPort
    }

    if ($IncludeDashboard) {
        $parameters.IncludeDashboard = $true
    }

    & $script:CodexMonitorPaths.StartupInstall @parameters

    Get-CodexMonitorStartupStatus
}

function Uninstall-CodexMonitorStartup {
    & $script:CodexMonitorPaths.StartupUninstall -TaskName (Get-CodexMonitorStartupTaskName)
    Get-CodexMonitorStartupStatus
}

