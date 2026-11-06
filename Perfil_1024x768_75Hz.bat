@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0tools\Apply-CrtMode.ps1" -Width 1024 -Height 768 -RefreshRate 75
