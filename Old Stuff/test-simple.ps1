# Simple test main to isolate the issue

$ErrorActionPreference = "Stop"

try {
    # Test 1: Basic module loading
    Write-Host "Test 1: Loading core modules..." -ForegroundColor Cyan
    Import-Module ".\event-system.psm1" -Force -Global
    Write-Host "✓ Event system loaded" -ForegroundColor Green
    
    Import-Module ".\tui-engine-v2.psm1" -Force -Global
    Write-Host "✓ TUI engine loaded" -ForegroundColor Green
    
    Import-Module ".\tui-components.psm1" -Force -Global
    Write-Host "✓ Components loaded" -ForegroundColor Green
    
    Import-Module ".\data-manager.psm1" -Force -Global
    Write-Host "✓ Data manager loaded" -ForegroundColor Green
    
    # Test 2: Load dashboard screen specifically
    Write-Host "`nTest 2: Loading dashboard screen..." -ForegroundColor Cyan
    Import-Module ".\screens\dashboard-screen.psm1" -Force -Global -Verbose
    Write-Host "✓ Dashboard screen loaded" -ForegroundColor Green
    
    # Test 3: Check if function exists
    Write-Host "`nTest 3: Testing Get-DashboardScreen..." -ForegroundColor Cyan
    if (Get-Command Get-DashboardScreen -ErrorAction SilentlyContinue) {
        Write-Host "✓ Get-DashboardScreen exists" -ForegroundColor Green
        
        # Try to create the screen
        $screen = Get-DashboardScreen
        Write-Host "✓ Dashboard screen created successfully" -ForegroundColor Green
        Write-Host "  Name: $($screen.Name)" -ForegroundColor Gray
        Write-Host "  Has Render: $($null -ne $screen.Render)" -ForegroundColor Gray
        Write-Host "  Has HandleInput: $($null -ne $screen.HandleInput)" -ForegroundColor Gray
    } else {
        Write-Host "✗ Get-DashboardScreen not found" -ForegroundColor Red
    }
    
} catch {
    Write-Host "`nError occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`nStack trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
    
    if ($_.Exception.InnerException) {
        Write-Host "`nInner exception:" -ForegroundColor Yellow
        Write-Host $_.Exception.InnerException.Message -ForegroundColor Yellow
    }
}

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
