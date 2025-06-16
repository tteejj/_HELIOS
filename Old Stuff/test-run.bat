@echo off
echo Starting PMC Terminal Test Mode...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "test-minimal.ps1"
echo.
echo Test completed.
pause