# Codex iPhone Notifier

A small Windows-first toolkit that watches Codex Desktop session logs and pushes task completion notifications to your iPhone.

The current default path uses Bark on iPhone because it was more reliable than `ntfy` on iOS in real use.

This repository is currently optimized for a practical Windows-first public release: stable local behavior first, structural cleanup second.

If you want Codex to finish a task and immediately ping your phone, this project is the simplest reliable path from local Codex Desktop activity to iPhone push notifications.

## What it does

- Watches `~/.codex/sessions` for new `task_complete` events
- Sends a Bark push when a Codex task finishes
- Exposes a small local dashboard at `http://127.0.0.1:8754/`
- Runs fully outside Codex Desktop hooks, which makes it more stable on Desktop builds where `notify` or `hooks.json` can be flaky

## Why it is useful

- You do not need to keep staring at Codex while a task runs
- You get a practical fallback when built-in desktop notifications are unreliable
- You can verify the whole pipeline locally with a dashboard and a test notification button

## Project layout

- `outputs/bark-notify`: Bark sender script and Bark config template
- `outputs/codex-task-monitor`: background monitor, local dashboard, and monitor config template
- `outputs/ntfy-notify`: older `ntfy` path kept as reference
- `Setup-CodexMonitor.ps1`: creates local machine config files from templates
- `Install-CodexMonitorStartup.ps1`: installs a Windows logon task for the monitor
- `Uninstall-CodexMonitorStartup.ps1`: removes the Windows logon task
- `Test-CodexMonitor.ps1`: runs a quick local health check

## Why this approach

- Codex Desktop hooks were not reliable enough in real use on this setup
- Bark on iPhone delivered more reliably than `ntfy` for the target workflow
- A local log-watching monitor keeps the system understandable and easy to debug

Architecture notes live in [docs/architecture.md](C:/Users/ASD/Documents/Codex/2026-06-23/you/docs/architecture.md).

## Quick start

1. Install the Bark app on iPhone and get your device URL.
2. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Setup-CodexMonitor.ps1 -BarkUrl "https://api.day.app/your-device-key/"
```

3. Start the monitor:

```powershell
powershell -ExecutionPolicy Bypass -File .\outputs\codex-task-monitor\Start-CodexTaskMonitor.ps1
```

4. Start the dashboard:

```powershell
powershell -ExecutionPolicy Bypass -File .\outputs\codex-task-monitor\Start-CodexTaskMonitorDashboard.ps1
```

5. Open:

`http://127.0.0.1:8754/`

## Nice extras

Install monitor autostart on Windows logon:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-CodexMonitorStartup.ps1
```

Run a local health check:

```powershell
powershell -ExecutionPolicy Bypass -File .\Test-CodexMonitor.ps1
```

Run a health check and send a real Bark test:

```powershell
powershell -ExecutionPolicy Bypass -File .\Test-CodexMonitor.ps1 -SendNotification -StartDashboard
```

## Public repo checklist

- `README.md`: overview and setup
- `CHANGELOG.md`: release history
- `CONTRIBUTING.md`: contribution guide
- `SECURITY.md`: secret-handling expectations
- `.github/`: issue and PR templates
- `LICENSE`: MIT

## Notes

- Local config files are ignored by `.gitignore` so your Bark device URL does not get committed by default.
- Runtime files like `state.json`, `status.json`, `*.pid`, and `monitor.log` are also ignored.
- If Bark send fails once, the monitor now logs the failure and keeps running instead of dying.
- The local dashboard now includes a test notification button and a "completed today" counter.
- The current `outputs/` folder layout is intentionally preserved in `0.1.x` to avoid breaking a working setup before the first public release.
