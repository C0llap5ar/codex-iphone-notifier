# Bark setup for Codex

This setup sends Codex completion notifications to your iPhone through Bark.

Files:

- `Send-CodexBark.ps1`: the script Codex calls when a turn completes
- `CodexBark.config.example.json`: template config for GitHub and new setups
- `CodexBark.config.json`: local Bark URL and notification settings generated on your machine

Manual test:

```powershell
powershell -ExecutionPolicy Bypass -File .\Send-CodexBark.ps1 `
  -Title "Codex test" `
  -Subtitle "Manual send" `
  -Body "If you receive this, Bark is working."
```

Recommended setup:

Run the repo bootstrap script from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\Setup-CodexMonitor.ps1 -BarkUrl "https://api.day.app/your-device-key/"
```

Notes:

- `CodexBark.config.json` is intentionally ignored by git because it contains your personal device URL.
- The current local monitor path no longer depends on Codex Desktop hooks to deliver task-complete pushes.
