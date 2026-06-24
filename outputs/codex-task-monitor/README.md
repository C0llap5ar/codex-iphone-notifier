# Codex task monitor

This monitor watches local Codex session logs and sends a Bark notification whenever a new `task_complete` event appears.

Scripts:

- `CodexTaskMonitor.config.example.json`: template config for GitHub and new setups
- `..\..\CodexMonitor.ps1`: one-console entry point for daily use
- `..\..\CodexMonitor.cmd`: double-click Windows launcher for the console menu
- `Start-CodexTaskMonitor.ps1`: start the monitor in the background
- `Stop-CodexTaskMonitor.ps1`: stop the monitor
- `Get-CodexTaskMonitorStatus.ps1`: inspect whether it is running
- `Run-CodexTaskMonitor.ps1`: foreground worker loop
- `Start-CodexTaskMonitorDashboard.ps1`: start a local dashboard
- `Stop-CodexTaskMonitorDashboard.ps1`: stop the local dashboard
- `Serve-CodexTaskMonitorDashboard.ps1`: local HTTP server for dashboard and test notification endpoint

Initialize local config first:

```powershell
powershell -ExecutionPolicy Bypass -File ..\..\Setup-CodexMonitor.ps1 -BarkUrl "https://api.day.app/your-device-key/"
```

Start:

```powershell
powershell -ExecutionPolicy Bypass -File ..\..\CodexMonitor.ps1 -Action start
```

Stop:

```powershell
powershell -ExecutionPolicy Bypass -File ..\..\CodexMonitor.ps1 -Action stop
```

Status:

```powershell
powershell -ExecutionPolicy Bypass -File ..\..\CodexMonitor.ps1 -Action status
```

Dashboard:

```powershell
powershell -ExecutionPolicy Bypass -File ..\..\CodexMonitor.ps1 -Action open
```

Then open:

`http://127.0.0.1:8754/`

Reliability notes:

- The monitor reloads `state.json` each loop, so manual recovery edits take effect without a full restart.
- A single Bark send failure is logged and skipped without killing the background monitor.
- The dashboard can now trigger a real test notification through the local Bark script.
