@echo off
echo Starting PMC Terminal in Silent Mode...
echo.
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0main.ps1" -silent
