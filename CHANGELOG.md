# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-06-23

### Added

- Bark-based iPhone notification path for Codex task completion
- Local Windows monitor that watches `~/.codex/sessions` for `task_complete` events
- Local dashboard with monitor status, recent log view, today count, and test notification button
- `Setup-CodexMonitor.ps1` bootstrap script for generating local configs
- `Test-CodexMonitor.ps1` health check script
- Windows logon startup installer and uninstaller
- Example config files for Bark and the monitor
- Root repository docs, MIT license, and git ignore rules for local secrets and runtime files

### Changed

- Monitor now reloads persisted state during polling so manual recovery edits take effect without restart
- Monitor now logs Bark send failures without crashing the background process
- Bark sender now supports optional subtitle and body fields

### Notes

- The folder layout still uses `outputs/` to avoid breaking a working local setup during the first public release
- A future release may move runtime and source files into a cleaner top-level `src/` or `tools/` structure
