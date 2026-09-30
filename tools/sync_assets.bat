@echo off
rem Double-click me: copies your art into the game and uploads it to GitHub.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync_assets.ps1" %*
