# README Showcase Plan

If you want the GitHub page to feel stronger, use this order:

## Hero section

- Project name
- One-sentence pitch
- Short list of what it solves

## Screenshot block

Include:

1. Dashboard screenshot
2. iPhone Bark notification screenshot

## Quick start

Keep it to:

1. `Setup-CodexMonitor.ps1`
2. `Start-CodexTaskMonitor.ps1`
3. `Start-CodexTaskMonitorDashboard.ps1`

## Why not hooks

Short explanation:

- built-in hook path was unreliable in this real setup
- local session-log polling turned out to be simpler and more dependable

## Reliability notes

- state is persisted
- monitor survives single notification failures
- local dashboard includes a one-click notification test
