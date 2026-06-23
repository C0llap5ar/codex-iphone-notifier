# Security

## Secrets

Do not commit these local files:

- `outputs/bark-notify/CodexBark.config.json`
- `outputs/ntfy-notify/ntfy.config.json`
- `outputs/codex-task-monitor/CodexTaskMonitor.config.json`

These may contain device URLs, local absolute paths, or other machine-specific details.

## Runtime files

Do not commit runtime output such as:

- `monitor.log`
- `state.json`
- `status.json`
- `*.pid`

## Reporting

If you find a security issue that could expose notification targets, local paths, or Codex session data, please report it privately before opening a public issue.
