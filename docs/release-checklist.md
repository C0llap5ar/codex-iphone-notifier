# Release Checklist

Use this checklist when publishing the repository and the first GitHub release.

## 1. Create the GitHub repository

Create a new GitHub repository in the browser.

Suggested repository name:

`codex-iphone-notifier`

Suggested visibility:

- Public, if you want to share it broadly
- Private first, if you want to sanity-check the README and release page before opening it up

## 2. Add the remote and push

Replace `<your-github-url>` with the repository URL GitHub gives you.

```powershell
git remote add origin <your-github-url>
git push -u origin main
```

Examples:

```powershell
git remote add origin https://github.com/your-name/codex-iphone-notifier.git
git push -u origin main
```

or

```powershell
git remote add origin git@github.com:your-name/codex-iphone-notifier.git
git push -u origin main
```

## 3. Set repository metadata

Use the copy from `docs/github-home.md`.

### Description

Windows-first local monitor for Codex Desktop that sends iPhone push notifications through Bark when tasks complete.

### Suggested topics

`codex`, `openai`, `bark`, `iphone`, `notifications`, `powershell`, `windows`, `automation`, `developer-tools`

## 4. Create the first tag

```powershell
git tag v0.1.0
git push origin v0.1.0
```

## 5. Publish the GitHub release

In the GitHub web UI:

1. Open the repository.
2. Go to Releases.
3. Click "Draft a new release".
4. Choose tag `v0.1.0`.
5. Title it:

`v0.1.0`

6. Paste the release notes from `docs/releases/v0.1.0.md`.

## 6. Add screenshots

Recommended screenshots for the README and release page:

1. Dashboard overview
   Show monitor status, today count, and recent log together.

2. Test notification flow
   Show the dashboard button and the Bark notification on iPhone.

3. Quick start snippet
   Show the `Setup-CodexMonitor.ps1` and `Test-CodexMonitor.ps1` flow in the terminal.

## 7. Optional repo polish

- Add a social preview image in GitHub settings
- Pin the repository on your profile
- Add a short GIF showing the dashboard refresh and the Bark notification arrival
