# Quick Helios UI Test
# Tests the fixes for theme colors, navigation, and rendering

Write-Host "Testing Helios UI Fixes..." -ForegroundColor Cyan
Write-Host ""

# Test 1: Theme Colors
Write-Host "1. Testing Theme System..." -ForegroundColor Yellow
try {
    Import-Module .\modules\theme-manager.psm1 -Force
    Initialize-ThemeManager
    
    $theme = Get-TuiTheme
    if ($theme) {
        Write-Host "   ✓ Theme loaded: $($theme.Name)" -ForegroundColor Green
        Write-Host "   ✓ Border color: $($theme.Colors.Border)" -ForegroundColor Green
        Write-Host "   ✓ Background color: $($theme.Colors.Background)" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Theme not loaded!" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ Theme system error: $_" -ForegroundColor Red
}

# Test 2: Panel Rendering
Write-Host "`n2. Testing Panel Colors..." -ForegroundColor Yellow
try {
    Import-Module .\layout\panels.psm1 -Force
    
    $panel = New-TuiStackPanel -Props @{
        Title = " Test Panel "
        ShowBorder = $true
        X = 0; Y = 0; Width = 20; Height = 5
    }
    
    if ($panel.BorderColor -eq "Border") {
        Write-Host "   ✓ Panel border color property set correctly" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Panel border color incorrect: $($panel.BorderColor)" -ForegroundColor Red
    }
    
    if ($panel.Children -is [array]) {
        Write-Host "   ✓ Panel has Children array for Z-index rendering" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Panel missing Children array!" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ Panel system error: $_" -ForegroundColor Red
}

# Test 3: Keybinding Service
Write-Host "`n3. Testing Keybinding Service..." -ForegroundColor Yellow
try {
    Import-Module .\services\keybindings.psm1 -Force
    $kb = Initialize-KeybindingService
    
    # Test number key bindings
    $testKey = [System.ConsoleKeyInfo]::new('3', [ConsoleKey]::D3, $false, $false, $false)
    $action = & $kb.HandleKey -self $kb -KeyInfo $testKey
    
    if ($action -eq "QuickNav.3") {
        Write-Host "   ✓ Number key '3' mapped to QuickNav.3" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Number key '3' returned: $action" -ForegroundColor Red
    }
    
    # Test F12 binding
    $f12Key = [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::F12, $false, $false, $false)
    $f12Action = & $kb.HandleKey -self $kb -KeyInfo $f12Key
    
    if ($f12Action -eq "App.DebugLog") {
        Write-Host "   ✓ F12 mapped to App.DebugLog" -ForegroundColor Green
    } else {
        Write-Host "   ✗ F12 returned: $f12Action" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ Keybinding service error: $_" -ForegroundColor Red
}

# Test 4: AppStore State
Write-Host "`n4. Testing AppStore..." -ForegroundColor Yellow
try {
    Import-Module .\services\app-store.psm1 -Force
    $store = Initialize-AppStore
    
    if ($store._state._subscribers) {
        Write-Host "   ✓ AppStore has _subscribers initialized" -ForegroundColor Green
    } else {
        Write-Host "   ✗ AppStore missing _subscribers!" -ForegroundColor Red
    }
    
    if ($store._state._changeQueue -is [array]) {
        Write-Host "   ✓ AppStore has _changeQueue initialized" -ForegroundColor Green
    } else {
        Write-Host "   ✗ AppStore missing _changeQueue!" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ AppStore error: $_" -ForegroundColor Red
}

Write-Host "`n✓ UI tests complete. Start the application to see the fixes in action." -ForegroundColor Green
Write-Host "  Run: .\main-helios.ps1" -ForegroundColor Cyan
