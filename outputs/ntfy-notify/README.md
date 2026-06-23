# ntfy reminder setup

1. Install the `ntfy` app on your phone.
2. Subscribe to topic `codex-db7351737c8b429e9505` on server `https://ntfy.sh`.
3. Edit `ntfy.config.json` if you want a custom task name, machine name, click link, or auth token.
4. Send a test notification:

```powershell
powershell -ExecutionPolicy Bypass -File .\Send-CodexNtfy.ps1 -Message "Test from Codex"
```

Recommended usage:

```powershell
powershell -ExecutionPolicy Bypass -File .\Send-CodexNtfy.ps1 `
  -TaskName "Bugfix run" `
  -Status success `
  -Message "The requested change is done."
```

For failures or warnings:

```powershell
powershell -ExecutionPolicy Bypass -File .\Send-CodexNtfy.ps1 `
  -TaskName "Deploy check" `
  -Status error `
  -Message "The task stopped and needs attention."
```

You can also override everything directly:

```powershell
powershell -ExecutionPolicy Bypass -File .\Send-CodexNtfy.ps1 `
  -Topic "codex-db7351737c8b429e9505" `
  -Title "Codex Finished" `
  -Priority high `
  -Tags "computer,rocket" `
  -Message "Your task is done."
```

For a private ntfy server, set either `authToken` in the config or `authTokenEnvVar` to an environment variable name that stores your bearer token.

If you want me to send this automatically at the end of future tasks in this thread, tell me to "send an ntfy reminder when you finish" and I can call this script as the last step.
