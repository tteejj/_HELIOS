# Comprehensive Dashboard Diagnostic Script
Write-Host "Dashboard Diagnostic Test" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host ""

# Load modules
Write-Host "Loading modules..." -ForegroundColor Yellow
. ".\main-helios.ps1"

try {
    $loadedModules = Initialize-PMCModules -Silent:$true
    Write-Host "✓ Modules loaded: $($loadedModules.Count)" -ForegroundColor Green
    
    # Initialize subsystems
    Write-Host "`nInitializing subsystems..." -ForegroundColor Yellow
    Initialize-Logger
    Initialize-EventSystem
    Initialize-ThemeManager
    Initialize-DataManager
    Initialize-TuiFramework
    Initialize-TuiEngine
    Initialize-DialogSystem
    Initialize-FocusManager
    Write-Host "✓ Subsystems initialized" -ForegroundColor Green
    
    # Load data
    Write-Host "`nLoading data..." -ForegroundColor Yellow
    Load-UnifiedData
    Write-Host "✓ Data loaded" -ForegroundColor Green
    
    # Initialize services
    Write-Host "`nInitializing services..." -ForegroundColor Yellow
    $services = Initialize-PMCServices -Silent:$true
    Write-Host "✓ Services initialized" -ForegroundColor Green
    
    # Test AppStore
    Write-Host "`nTesting AppStore..." -ForegroundColor Yellow
    
    # Test 1: Direct state update
    Write-Host "  Test 1: Direct state update" -ForegroundColor Cyan
    $testResult = & $services.Store.Dispatch -self $services.Store -actionName "UPDATE_STATE" -payload @{ 
        testValue = "Hello World" 
    }
    if ($testResult.Success) {
        $value = & $services.Store.GetState -self $services.Store -path "testValue"
        if ($value -eq "Hello World") {
            Write-Host "  ✓ Direct state update works" -ForegroundColor Green
        } else {
            Write-Host "  ✗ State update failed - value is: $value" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✗ Dispatch failed: $($testResult.Error)" -ForegroundColor Red
    }
    
    # Test 2: Subscription
    Write-Host "  Test 2: Subscription test" -ForegroundColor Cyan
    $subscriptionWorked = $false
    $subId = & $services.Store.Subscribe -self $services.Store -path "testValue2" -handler {
        param($data)
        $script:subscriptionWorked = $true
        Write-Host "    → Subscription fired with value: $($data.NewValue)" -ForegroundColor Green
    }
    
    & $services.Store.Dispatch -self $services.Store -actionName "UPDATE_STATE" -payload @{ 
        testValue2 = "Subscription Test" 
    }
    
    if ($subscriptionWorked) {
        Write-Host "  ✓ Subscriptions work" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Subscription did not fire" -ForegroundColor Red
    }
    
    # Test 3: Dashboard data actions
    Write-Host "  Test 3: Dashboard data actions" -ForegroundColor Cyan
    $result = & $services.Store.Dispatch -self $services.Store -actionName "LOAD_DASHBOARD_DATA"
    if ($result.Success) {
        Write-Host "  ✓ LOAD_DASHBOARD_DATA succeeded" -ForegroundColor Green
        
        # Check if data was set
        $quickActions = & $services.Store.GetState -self $services.Store -path "quickActions"
        if ($quickActions -and $quickActions.Count -gt 0) {
            Write-Host "    → quickActions loaded: $($quickActions.Count) items" -ForegroundColor Gray
        } else {
            Write-Host "    → WARNING: quickActions is empty or null" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ✗ LOAD_DASHBOARD_DATA failed: $($result.Error)" -ForegroundColor Red
    }
    
    # Load screens
    Write-Host "`nLoading screens..." -ForegroundColor Yellow
    Initialize-PMCScreens -Silent:$true
    Write-Host "✓ Screens loaded" -ForegroundColor Green
    
    # Create dashboard
    Write-Host "`nCreating dashboard screen..." -ForegroundColor Yellow
    $dashboard = Get-DashboardScreen -Services $services
    if ($dashboard) {
        Write-Host "✓ Dashboard created" -ForegroundColor Green
        
        # Initialize dashboard
        Write-Host "`nInitializing dashboard..." -ForegroundColor Yellow
        if ($dashboard.Init) {
            & $dashboard.Init -self $dashboard -services $services
            Write-Host "✓ Dashboard initialized" -ForegroundColor Green
            
            # Check components
            Write-Host "`nChecking dashboard components:" -ForegroundColor Yellow
            if ($dashboard.Children -and $dashboard.Children.Count -gt 0) {
                Write-Host "  ✓ Children array has $($dashboard.Children.Count) items" -ForegroundColor Green
            } else {
                Write-Host "  ✗ Children array is empty!" -ForegroundColor Red
            }
            
            if ($dashboard.Components.rootPanel) {
                Write-Host "  ✓ Root panel exists" -ForegroundColor Green
            } else {
                Write-Host "  ✗ Root panel missing!" -ForegroundColor Red
            }
            
            if ($dashboard._quickActions) {
                Write-Host "  ✓ Quick actions component stored" -ForegroundColor Green
                Write-Host "    → Data items: $($dashboard._quickActions.Data.Count)" -ForegroundColor Gray
            } else {
                Write-Host "  ✗ Quick actions component not stored!" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "✗ Failed to create dashboard" -ForegroundColor Red
    }
    
    Write-Host "`nDiagnostic complete." -ForegroundColor Cyan
    
    # Ask if user wants to run the app
    Write-Host "`nPress 'Y' to start the application, any other key to exit..." -ForegroundColor Yellow
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    if ($key.Character -eq 'Y' -or $key.Character -eq 'y') {
        Clear-Host
        Push-Screen -Screen $dashboard
        Start-TuiLoop
    }
    
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
} finally {
    if (Get-Command -Name "Stop-TuiEngine" -ErrorAction SilentlyContinue) {
        Stop-TuiEngine
    }
}