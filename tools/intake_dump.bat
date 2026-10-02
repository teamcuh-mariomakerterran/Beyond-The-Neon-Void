@echo off
rem Double-click me: copies your asset dump into the game (assets\incoming) and uploads it.
rem Your original folder is never moved or changed. Safe to run again: only new/changed files go up.
set SRC=%~1
if "%SRC%"=="" set SRC=E:\Beyond_TheNeonVoid
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync_assets.ps1" -Dump "%SRC%"
