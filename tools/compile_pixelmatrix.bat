@echo off
rem Double-click: files PixelMatrix exports (PM_*.png) from Downloads into the game.
rem Optional: drag nothing, or run  compile_pixelmatrix.bat netrunner  to name the character folder.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0compile_pixelmatrix.ps1" -Character "%~1"
pause
