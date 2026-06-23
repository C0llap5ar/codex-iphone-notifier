# Contributing

Thanks for helping improve this project.

## Local setup

1. Clone the repository on Windows.
2. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Setup-CodexMonitor.ps1 -BarkUrl "https://api.day.app/your-device-key/"
```

3. Run the health check:

```powershell
powershell -ExecutionPolicy Bypass -File .\Test-CodexMonitor.ps1
```

## Development guidelines

- Keep runtime secrets out of git.
- Prefer ASCII in scripts unless Unicode is clearly needed.
- Preserve the current local-monitor architecture unless a change is clearly worth the migration cost.
- If you touch monitor logic, verify:
  - monitor start and stop still work
  - `Test-CodexMonitor.ps1` still returns `ok: true`
  - the dashboard still loads at `http://127.0.0.1:8754/`

## Pull requests

- Keep changes focused.
- Update `README.md` when user-facing behavior changes.
- Update `CHANGELOG.md` for notable changes.
- If a change affects setup or migration, document the upgrade path clearly.
