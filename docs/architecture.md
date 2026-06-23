# Architecture

## Overview

This project avoids relying on Codex Desktop `notify` and `hooks.json` for delivery because those paths proved unreliable in real Desktop usage.

Instead, it uses a local monitor that reads Codex session logs directly and sends phone notifications through Bark.

## Main pieces

### Bark sender

- Path: `outputs/bark-notify/Send-CodexBark.ps1`
- Responsibility: send one Bark push using local config or explicit parameters

### Task monitor

- Path: `outputs/codex-task-monitor/Run-CodexTaskMonitor.ps1`
- Responsibility: poll recent Codex session files, detect new `task_complete` events, and call the Bark sender

### Dashboard

- Paths:
  - `outputs/codex-task-monitor/Serve-CodexTaskMonitorDashboard.ps1`
  - `outputs/codex-task-monitor/dashboard.html`
- Responsibility: expose a small local status page and a test notification endpoint

## State model

The monitor persists:

- `lastSeenCompletedAt`
- `notifiedTurnIds`
- `startedAt`

The monitor also reloads state during each polling cycle so manual recovery changes can take effect without a process restart.

## Tradeoffs

### Why session-log polling

Pros:

- Works even when Desktop hook plumbing is unreliable
- Easy to understand and debug
- No external service besides Bark

Cons:

- Desktop-internal event shape could change in future versions
- Polling is less elegant than a first-class event hook
- Current implementation is Windows and PowerShell first

## Future cleanup

- Move scripts out of `outputs/` into a cleaner source layout
- Add automated tests around event parsing and state transitions
- Support more push providers behind one common interface
