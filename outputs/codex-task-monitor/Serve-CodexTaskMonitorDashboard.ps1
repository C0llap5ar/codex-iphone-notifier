[CmdletBinding()]
param(
    [int]$Port = 8754,
    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $PSScriptRoot "CodexTaskMonitor.config.json"
}

$snapshotScriptPath = Join-Path $PSScriptRoot "Export-CodexTaskMonitorSnapshot.ps1"
$dashboardPath = Join-Path $PSScriptRoot "dashboard.html"
$statusPath = Join-Path $PSScriptRoot "status.json"
$barkScriptPath = $null
$monitorConfig = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$barkScriptPath = $monitorConfig.barkScriptPath

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add(("http://127.0.0.1:{0}/" -f $Port))
$listener.Start()

try {
    while ($listener.IsListening) {
        & $snapshotScriptPath -ConfigPath $ConfigPath -OutputPath $statusPath | Out-Null

        $context = $listener.GetContext()
        $path = $context.Request.Url.AbsolutePath.Trim("/")

        switch ($path) {
            "" {
                $bytes = [System.IO.File]::ReadAllBytes($dashboardPath)
                $context.Response.ContentType = "text/html; charset=utf-8"
                $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            "status.json" {
                $bytes = [System.IO.File]::ReadAllBytes($statusPath)
                $context.Response.ContentType = "application/json; charset=utf-8"
                $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            "test-notification" {
                try {
                    & $barkScriptPath | Out-Null
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
                    $context.Response.ContentType = "application/json; charset=utf-8"
                    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                }
                catch {
                    $context.Response.StatusCode = 500
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json @{
                        ok = $false
                        error = $_.Exception.Message
                    }))
                    $context.Response.ContentType = "application/json; charset=utf-8"
                    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                }
            }
            default {
                $context.Response.StatusCode = 404
            }
        }

        $context.Response.Close()
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
