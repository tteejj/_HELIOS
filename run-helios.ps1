# Helios Dashboard Verification Script
# Runs the application and provides instructions for verification

Write-Host @"
========================================
PMC Terminal Helios - Dashboard Test
========================================

This will start the application to verify the dashboard is working correctly.

What to check:
1. Dashboard should load without errors
2. Quick Actions panel should show 6 menu items
3. Stats should show hours and task counts (may be 0)
4. No "Method invocation failed" errors in the log

Press F12 to view the debug log once the app starts.
Press Q to quit.

"@ -ForegroundColor Cyan

Write-Host "Press any key to start..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Start the application
& "$PSScriptRoot\main-helios.ps1"
