@echo off
rem Double-click: converts music to .ogg (copies only, originals untouched).
rem Optional: drag a different folder onto this file.
set SRC=%~1
if "%SRC%"=="" set SRC=E:\Beyond_TheNeonVoid\music
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0convert_music.ps1" -Source "%SRC%"
