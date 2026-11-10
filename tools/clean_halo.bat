@echo off
rem Drag a sprite or a folder of sprites onto me: erases the white outline round each one.
rem Only pixels reached from the empty space, at most 2 px in, so white inside the art stays.
rem Cleaned copies go to a "_clean" folder next to it; your originals are never changed.
setlocal
if "%GODOT%"=="" set GODOT=godot
set IN=%~1
if "%IN%"=="" (echo Drag a file or folder onto me. & pause & exit /b 1)
set OUT=%~dpn1_clean
if exist "%~1\" set OUT=%~1_clean
cd /d "%~dp0.."
"%GODOT%" --headless -s tools/art/clean_halo.gd -- "%IN%" "%OUT%"
pause
