@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0tools\Apply-CrtMode.ps1" -Width 640 -Height 480 -RefreshRate 75
