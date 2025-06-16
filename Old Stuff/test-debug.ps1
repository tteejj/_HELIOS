# Debug script to find the exact error location
$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$script:BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== DEBUG: Testing initialization sequence ===" -ForegroundColor Yellow

try {
    # Test 1: Load event system
    Write-Host "Loading event-system..." -ForegroundColor Cyan
    Import-Module "$BasePath\modules\event-system.psm1" -Force -Global
    Write-Host "  ✓ Event system loaded" -ForegroundColor Green
    
    # Test 2: Initialize event system
    Write-Host "Initializing event system..." -ForegroundColor Cyan
    Initialize-EventSystem
    Write-Host "  ✓ Event system initialized" -ForegroundColor Green
    
    # Test 3: Load theme manager
    Write-Host "Loading theme-manager..." -ForegroundColor Cyan
    Import-Module "$BasePath\modules\theme-manager.psm1" -Force -Global
    Write-Host "  ✓ Theme manager loaded" -ForegroundColor Green
    
    # Test 4: Initialize theme manager
    Write-Host "Initializing theme manager..." -ForegroundColor Cyan
    Initialize-ThemeManager
    Write-Host "  ✓ Theme manager initialized" -ForegroundColor Green
    
    # Test 5: Load data manager
    Write-Host "Loading data-manager..." -ForegroundColor Cyan
    Import-Module "$BasePath\modules\data-manager.psm1" -Force -Global
    Write-Host "  ✓ Data manager loaded" -ForegroundColor Green
    
    # Test 6: Initialize data manager
    Write-Host "Initializing data manager..." -ForegroundColor Cyan
    Initialize-DataManager
    Write-Host "  ✓ Data manager initialized" -ForegroundColor Green
    
    # Test 7: Load TUI engine
    Write-Host "Loading tui-engine-v2..." -ForegroundColor Cyan
    Import-Module "$BasePath\modules\tui-engine-v2.psm1" -Force -Global
    Write-Host "  ✓ TUI engine loaded" -ForegroundColor Green
    
    # Test 8: Initialize TUI engine with detailed debugging
    Write-Host "Initializing TUI engine (this is where it fails)..." -ForegroundColor Cyan
    
    # Let's check console dimensions first
    Write-Host "  Console dimensions: $([Console]::WindowWidth) x $([Console]::WindowHeight)" -ForegroundColor Gray
    
    # Try to initialize
    Initialize-TuiEngine
    Write-Host "  ✓ TUI engine initialized" -ForegroundColor Green
    
} catch {
    Write-Host "`n=== ERROR DETAILS ===" -ForegroundColor Red
    Write-Host "Error at stage: $($_.InvocationInfo.MyCommand.Name)" -ForegroundColor Yellow
    Write-Host "Error message: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "`nStack trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace
    
    Write-Host "`nException details:" -ForegroundColor Gray
    $_ | Format-List -Force
}

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
