# Dashboard Verification Script
# Verifies that the dashboard and tasks screens are working correctly

Write-Host "PMC Terminal Helios - Dashboard & Tasks Verification" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# Check if main-helios.ps1 exists
$mainPath = Join-Path $PSScriptRoot "main-helios.ps1"
if (-not (Test-Path $mainPath)) {
    Write-Host "Error: main-helios.ps1 not found at $mainPath" -ForegroundColor Red
    exit 1
}

# Run the main application
Write-Host "`nStarting PMC Terminal..." -ForegroundColor Yellow
Write-Host "Instructions:" -ForegroundColor Gray
Write-Host "1. The dashboard should display without errors" -ForegroundColor Gray
Write-Host "2. Quick Actions panel should show 6 items" -ForegroundColor Gray
Write-Host "3. Stats panel should show hours and task counts" -ForegroundColor Gray
Write-Host "4. Press '3' to navigate to Tasks screen" -ForegroundColor Gray
Write-Host "5. Tasks should display properly with columns" -ForegroundColor Gray
Write-Host "6. Press 'Q' to quit from any screen" -ForegroundColor Gray
Write-Host "`nPress any key to start..." -ForegroundColor Yellow

$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Start the application
& $mainPath
