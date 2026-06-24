Option Explicit

Dim shell
Dim scriptDir
Dim command

Set shell = CreateObject("WScript.Shell")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
command = "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File """ & scriptDir & "\CodexMonitorGui.ps1"""

' 0 = hidden window, False = do not wait
shell.Run command, 0, False
