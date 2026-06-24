[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CodexMonitorWin32 {
  [DllImport("user32.dll")]
  public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

  [DllImport("user32.dll")]
  public static extern bool SetForegroundWindow(IntPtr hWnd);
}
'@

$process = Get-Process powershell -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -eq "Codex Monitor" } |
    Select-Object -First 1

if (-not $process -or $process.MainWindowHandle -eq 0) {
    throw "Could not find a running Codex Monitor window."
}

[CodexMonitorWin32]::ShowWindowAsync($process.MainWindowHandle, 9) | Out-Null
[CodexMonitorWin32]::SetForegroundWindow($process.MainWindowHandle) | Out-Null

Write-Output "Restored Codex Monitor window."
