@echo off
rem Double-click me: cuts the art in assets\incoming\rooms_props into game sprites.
rem   rooms_props\<folder>\...  ->  assets\props\<folder>\...
rem Pink/magenta backgrounds become transparent, sheets split into one PNG per item,
rem folders named *screen* or *sign* also get living-signage corners (.screen.json).
rem Your originals are never moved or changed. Safe to run again.
rem Needs Godot on your PATH as "godot" (or set GODOT=C:\path\to\Godot.exe first).
setlocal
if "%GODOT%"=="" set GODOT=godot
set IN=%~1
if "%IN%"=="" set IN=assets\incoming\rooms_props
set OUT=%~2
if "%OUT%"=="" set OUT=assets\props
cd /d "%~dp0.."
"%GODOT%" --headless -s tools/art/cut_art.gd -- "%CD%\%IN%" "%CD%\%OUT%"
pause
