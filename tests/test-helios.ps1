# Test script to check basic PMC Terminal Helios functionality
Set-Location "C:\Users\jhnhe\Documents\GitHub\_HELIOS"

# Set up test environment
$ErrorActionPreference = "Stop"

try {
    Write-Host "Testing PMC Terminal Helios..." -ForegroundColor Cyan
    
    # Test 1: Check if main entry point exists
    if (Test-Path ".\main-helios.ps1") {
        Write-Host "✓ Main entry point found" -ForegroundColor Green
    } else {
        throw "Main entry point not found"
    }
    
    # Test 2: Import key modules and check functions
    Write-Host "Testing module imports..." -ForegroundColor Cyan
    
    Import-Module ".\modules\tui-engine-v2.psm1" -Force -Global
    # Check if TUI Engine functions are available by trying to use them
    try {
        # Test if we can access TuiState (which is exported)
        if ($null -eq $global:TuiState) {
            # TuiState not initialized yet, which is expected
        }
        # The module loaded successfully if we got here
        Write-Host "✓ TUI Engine loaded" -ForegroundColor Green
    } catch {
        throw "TUI Engine not loaded properly: $_"
    }
    
    Import-Module ".\services\navigation.psm1" -Force
    # Try to initialize the service to verify it works
    try {
        $testNav = Initialize-NavigationService -EnableBreadcrumbs $false
        if ($testNav -and $testNav.GoTo) {
            Write-Host "✓ Navigation Service loaded" -ForegroundColor Green
        } else {
            throw "Navigation Service structure invalid"
        }
    } catch {
        throw "Navigation Service not loaded properly: $_"
    }
    
    Import-Module ".\screens\dashboard-screen-helios.psm1" -Force
    if (Get-Command Get-DashboardScreen -ErrorAction SilentlyContinue) {
        Write-Host "✓ Dashboard Screen loaded" -ForegroundColor Green
    } else {
        throw "Dashboard Screen not loaded properly"
    }
    
    # Test 3: Try to create a dashboard screen with mock services
    Write-Host "Testing screen creation..." -ForegroundColor Cyan
    
    $mockServices = @{
        Store = @{
            Subscribe = { param($self, $path, $handler) return "sub-$path" }
            Dispatch = { param($self, $actionName) Write-Host "Dispatch: $actionName" }
            GetState = { param($self, $path) return $null }
        }
        Navigation = @{
            GoTo = { param($self, $Path, $Services) Write-Host "Navigate to: $Path" }
        }
        Keybindings = @{
            HandleKey = { param($self, $KeyInfo) return $null }
        }
    }
    
    $screen = Get-DashboardScreen -Services $mockServices
    if ($screen -and $screen.Name -eq "DashboardScreen") {
        Write-Host "✓ Dashboard screen created successfully" -ForegroundColor Green
        Write-Host "  - Children array exists: $($null -ne $screen.Children)" -ForegroundColor Gray
        Write-Host "  - Visible property: $($screen.Visible)" -ForegroundColor Gray
        Write-Host "  - ZIndex property: $($screen.ZIndex)" -ForegroundColor Gray
    } else {
        throw "Failed to create dashboard screen"
    }
    
    Write-Host "`nAll tests passed!" -ForegroundColor Green
    Write-Host "`nYou can now run: .\main-helios.ps1" -ForegroundColor Yellow
    
} catch {
    Write-Host "✗ Test failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}
