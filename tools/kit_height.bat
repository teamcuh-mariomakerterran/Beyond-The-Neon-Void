@echo off
rem Drag a sheet or a folder of building-kit sheets onto me (or double-click for assets\incoming\rooms_props).
rem Prints the wall height (1, 2 or 3) each sheet was built at, measured against its stair piece. Only reads.
setlocal
if "%GODOT%"=="" set GODOT=godot
set IN=%~1
if "%IN%"=="" set IN=%~dp0..\assets\incoming\rooms_props
cd /d "%~dp0.."
"%GODOT%" --headless -s tools/art/kit_height.gd -- "%IN%"
pause
