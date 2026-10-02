@echo off
rem Double-click: converts music + SFX in E:\Beyond_TheNeonVoid to .ogg (copies only, originals untouched).
rem Or drag any folder onto this file to convert just that one.
if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0convert_music.ps1"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0convert_music.ps1" -Source "%~1"
)
