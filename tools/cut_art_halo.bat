@echo off
rem Same as cut_art.bat, and also erases the white outline round each item (see clean_halo.bat).
setlocal
if "%GODOT%"=="" set GODOT=godot
set IN=%~1
if "%IN%"=="" set IN=assets\incoming\rooms_props
set OUT=%~2
if "%OUT%"=="" set OUT=assets\props
cd /d "%~dp0.."
"%GODOT%" --headless -s tools/art/cut_art.gd -- "%CD%\%IN%" "%CD%\%OUT%" --halo
pause
