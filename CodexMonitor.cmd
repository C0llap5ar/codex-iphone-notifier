@echo off
setlocal

if "%~1"=="" (
    powershell -NoLogo -ExecutionPolicy Bypass -File "%~dp0CodexMonitor.ps1" -Action menu
    pause
    exit /b %errorlevel%
)

powershell -NoLogo -ExecutionPolicy Bypass -File "%~dp0CodexMonitor.ps1" %*
