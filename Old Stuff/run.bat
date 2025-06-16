@echo off
echo PMC Terminal v3.0
echo =================
echo.
echo Checking console window size...
echo.
echo If you see an error about console size, please:
echo 1. Resize this window to be larger (at least 80 columns x 24 rows)
echo 2. Run this file again
echo.
echo Starting in 3 seconds...
timeout /t 3 /nobreak >nul
cls
powershell.exe -ExecutionPolicy Bypass -File start.ps1
pause
