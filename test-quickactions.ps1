# Dashboard Quick Actions Fix Test
# Tests that quick actions are properly loaded and displayed

Write-Host "Dashboard Quick Actions Test" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan

# Load required modules
$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "`nLoading modules..." -ForegroundColor Yellow
try {
    Import-Module "$basePath\modules\logger.psm1" -Force
    Import-Module "$basePath\modules\event-system.psm1" -Force  
    Import-Module "$basePath\modules\tui-framework.psm1" -Force
    Import-Module "$basePath\services\app-store.psm1" -Force
    Write-Host "Modules loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "Failed to load modules: $_" -ForegroundColor Red
    exit 1
}

# Initialize logger
Initialize-Logger

# Create store with initial empty state
Write-Host "`nInitializing AppStore..." -ForegroundColor Yellow
$store = Initialize-AppStore -InitialData @{
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

# Register the LOAD_DASHBOARD_DATA action
Write-Host "`nRegistering LOAD_DASHBOARD_DATA action..." -ForegroundColor Yellow
& $store.RegisterAction -self $store -actionName "LOAD_DASHBOARD_DATA" -scriptBlock {
    param($Context, $Payload)
    
    Write-Host "  LOAD_DASHBOARD_DATA action executing..." -ForegroundColor Magenta
    
    # Create quick actions data
    $quickActions = @(
        @{ Action = "[1] New Time Entry" },
        @{ Action = "[2] Start Timer" },
        @{ Action = "[3] View Tasks" },
        @{ Action = "[4] View Projects" },
        @{ Action = "[5] Reports" },
        @{ Action = "[6] Settings" }
    )
    
    Write-Host "  Updating quickActions with $($quickActions.Count) items" -ForegroundColor Gray
    
    # Update the state
    & $Context.UpdateState @{ quickActions = $quickActions }
    
    Write-Host "  State updated successfully" -ForegroundColor Green
}

# Subscribe to quickActions changes
Write-Host "`nSubscribing to quickActions..." -ForegroundColor Yellow
$subId = & $store.Subscribe -self $store -path "quickActions" -handler {
    param($NewValue, $OldValue, $Path)
    Write-Host "  quickActions subscription triggered" -ForegroundColor Magenta
    Write-Host "  Path: $Path" -ForegroundColor Gray
    Write-Host "  NewValue type: $($NewValue.GetType().Name)" -ForegroundColor Gray
    Write-Host "  NewValue count: $($NewValue.Count)" -ForegroundColor Gray
    if ($NewValue.Count -gt 0) {
        Write-Host "  First item: $($NewValue[0].Action)" -ForegroundColor Gray
    }
}

# Dispatch the action
Write-Host "`nDispatching LOAD_DASHBOARD_DATA..." -ForegroundColor Yellow
$result = & $store.Dispatch -self $store -actionName "LOAD_DASHBOARD_DATA"

if ($result.Success) {
    Write-Host "`nAction dispatched successfully!" -ForegroundColor Green
} else {
    Write-Host "`nAction dispatch failed: $($result.Error)" -ForegroundColor Red
}

# Check final state
Write-Host "`nChecking final state..." -ForegroundColor Yellow
$quickActions = & $store.GetState -self $store -path "quickActions"
Write-Host "QuickActions count: $($quickActions.Count)" -ForegroundColor Cyan

if ($quickActions.Count -eq 6) {
    Write-Host "`nTest PASSED! Quick actions loaded correctly." -ForegroundColor Green
    Write-Host "`nQuick Actions:" -ForegroundColor Yellow
    $quickActions | ForEach-Object { Write-Host "  $($_.Action)" -ForegroundColor Gray }
} else {
    Write-Host "`nTest FAILED! Expected 6 quick actions, got $($quickActions.Count)" -ForegroundColor Red
}
