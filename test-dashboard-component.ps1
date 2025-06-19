# Dashboard Component Test
# Tests dashboard initialization without running full TUI

Write-Host "Dashboard Component Test" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

# Load required modules
$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "`nLoading modules..." -ForegroundColor Yellow
try {
    Import-Module "$basePath\modules\logger.psm1" -Force
    Import-Module "$basePath\modules\event-system.psm1" -Force
    Import-Module "$basePath\modules\tui-framework.psm1" -Force
    Import-Module "$basePath\services\app-store.psm1" -Force
    Import-Module "$basePath\screens\dashboard-screen-helios.psm1" -Force
    Write-Host "Modules loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "Failed to load modules: $_" -ForegroundColor Red
    exit 1
}

# Initialize minimal services
Write-Host "`nInitializing services..." -ForegroundColor Yellow
$services = @{}

# Create a minimal store
$services.Store = Initialize-AppStore -InitialData @{
    quickActions = @()
    activeTimers = @()
    todaysTasks = @()
    stats = @{
        todayHours = 0
        weekHours = 0
        activeTasks = 0
        runningTimers = 0
    }
} -EnableDebugLogging $true

# Register the actions that dashboard expects
& $services.Store.RegisterAction -self $services.Store -actionName "LOAD_DASHBOARD_DATA" -scriptBlock {
    param($Context)
    Write-Host "LOAD_DASHBOARD_DATA action called" -ForegroundColor Magenta
    $quickActions = @(
        @{ Action = "[1] New Time Entry" },
        @{ Action = "[2] Start Timer" },
        @{ Action = "[3] View Tasks" },
        @{ Action = "[4] View Projects" },
        @{ Action = "[5] Reports" },
        @{ Action = "[6] Settings" }
    )
    $Context.UpdateState(@{ quickActions = $quickActions })
    Write-Host "Updated quickActions with $($quickActions.Count) items" -ForegroundColor Green
}

& $services.Store.RegisterAction -self $services.Store -actionName "DASHBOARD_REFRESH" -scriptBlock {
    param($Context)
    Write-Host "DASHBOARD_REFRESH action called" -ForegroundColor Magenta
    & $Context.Dispatch -actionName "LOAD_DASHBOARD_DATA"
}

& $services.Store.RegisterAction -self $services.Store -actionName "TASKS_REFRESH" -scriptBlock {
    param($Context)
    Write-Host "TASKS_REFRESH action called" -ForegroundColor Magenta
}

& $services.Store.RegisterAction -self $services.Store -actionName "TIMERS_REFRESH" -scriptBlock {
    param($Context)
    Write-Host "TIMERS_REFRESH action called" -ForegroundColor Magenta
}

# Create mock navigation service
$services.Navigation = @{
    GoTo = { param($self, $Path, $Services) 
        Write-Host "Navigation requested to: $Path" -ForegroundColor Cyan 
    }
}

# Create mock keybindings service
$services.Keybindings = @{
    HandleKey = { param($self, $KeyInfo) 
        return $null 
    }
}

# Global services for fallback
$global:Services = $services

Write-Host "`nCreating dashboard screen..." -ForegroundColor Yellow
$dashboardScreen = Get-DashboardScreen -Services $services

Write-Host "`nInitializing dashboard..." -ForegroundColor Yellow
try {
    # Call Init
    & $dashboardScreen.Init -self $dashboardScreen -services $services
    
    Write-Host "`nDashboard initialization complete!" -ForegroundColor Green
    
    # Check what was created
    Write-Host "`nChecking dashboard state:" -ForegroundColor Yellow
    Write-Host "- Children count: $($dashboardScreen.Children.Count)" -ForegroundColor Cyan
    Write-Host "- Components count: $($dashboardScreen.Components.Count)" -ForegroundColor Cyan
    Write-Host "- Subscriptions count: $($dashboardScreen._subscriptions.Count)" -ForegroundColor Cyan
    
    # Check store state
    Write-Host "`nChecking store state:" -ForegroundColor Yellow
    $quickActions = & $services.Store.GetState -self $services.Store -path "quickActions"
    Write-Host "- QuickActions: $($quickActions.Count) items" -ForegroundColor $(if($quickActions.Count -gt 0) {"Green"} else {"Red"})
    
    if ($quickActions.Count -gt 0) {
        Write-Host "`nQuick Actions content:" -ForegroundColor Gray
        $quickActions | ForEach-Object { Write-Host "  $($_.Action)" -ForegroundColor Gray }
    }
    
    Write-Host "`nTest completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "`nDashboard initialization failed!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}
