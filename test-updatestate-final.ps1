# Test script to verify AppStore UpdateState fix
Clear-Host
Write-Host "Testing AppStore UpdateState Fix" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Load required modules
$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path
$modules = @(
    "modules\logger.psm1",
    "modules\exceptions.psm1",
    "modules\event-system.psm1",
    "modules\tui-framework.psm1",
    "services\app-store.psm1"
)

Write-Host "Loading modules..." -ForegroundColor Yellow
foreach ($module in $modules) {
    $modulePath = Join-Path $basePath $module
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -Global
    } else {
        Write-Host "  Module not found: $module" -ForegroundColor Red
        exit 1
    }
}
Write-Host "Modules loaded successfully" -ForegroundColor Green
Write-Host ""

# Initialize systems
Initialize-EventSystem
Initialize-Logger

# Create AppStore
Write-Host "Creating AppStore..." -ForegroundColor Yellow
$store = Initialize-AppStore -InitialData @{
    testValue = "initial"
    quickActions = @()
} -EnableDebugLogging $true

# Test basic subscription
Write-Host "Testing subscription..." -ForegroundColor Yellow
$subId = & $store.Subscribe -self $store -path "testValue" -handler {
    param($data)
    Write-Host "  Subscription fired: testValue = $($data.NewValue)" -ForegroundColor Cyan
}
Write-Host "Subscription created: $subId" -ForegroundColor Green
Write-Host ""

# Register test action
Write-Host "Registering test action..." -ForegroundColor Yellow
& $store.RegisterAction -self $store -actionName "TEST_UPDATE" -scriptBlock {
    param($Context, $Payload)
    Write-Host "  Action executing..." -ForegroundColor Gray
    try {
        Write-Host "  Calling UpdateState..." -ForegroundColor Gray
        & $Context.UpdateState @{ testValue = "updated via action" }
        Write-Host "  UpdateState completed successfully" -ForegroundColor Green
    } catch {
        Write-Host "  UpdateState failed: $_" -ForegroundColor Red
        throw
    }
}
Write-Host "Action registered" -ForegroundColor Green
Write-Host ""

# Dispatch the action
Write-Host "Dispatching TEST_UPDATE action..." -ForegroundColor Yellow
try {
    $result = & $store.Dispatch -self $store -actionName "TEST_UPDATE"
    if ($result.Success) {
        Write-Host "Action dispatched successfully" -ForegroundColor Green
    } else {
        Write-Host "Action dispatch failed: $($result.Error)" -ForegroundColor Red
    }
} catch {
    Write-Host "Exception during dispatch: $_" -ForegroundColor Red
}
Write-Host ""

# Check final state
Write-Host "Checking final state..." -ForegroundColor Yellow
$finalValue = & $store.GetState -self $store -path "testValue"
Write-Host "Final value: $finalValue" -ForegroundColor Cyan
if ($finalValue -eq "updated via action") {
    Write-Host ""
    Write-Host "TEST PASSED! UpdateState is working correctly." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "TEST FAILED! Value was not updated." -ForegroundColor Red
}

# Test quickActions update (like dashboard)
Write-Host ""
Write-Host "Testing quickActions update (dashboard scenario)..." -ForegroundColor Yellow

& $store.RegisterAction -self $store -actionName "LOAD_DASHBOARD_DATA" -scriptBlock {
    param($Context)
    Write-Host "  Loading dashboard data..." -ForegroundColor Gray
    $quickActions = @(
        @{ Action = "[1] New Time Entry" },
        @{ Action = "[2] Start Timer" },
        @{ Action = "[3] View Tasks" }
    )
    & $Context.UpdateState @{ quickActions = $quickActions }
    Write-Host "  quickActions updated with $($quickActions.Count) items" -ForegroundColor Green
}

$qaSubId = & $store.Subscribe -self $store -path "quickActions" -handler {
    param($data)
    $newValue = if ($data.NewValue -ne $null) { $data.NewValue } else { $data }
    Write-Host "  quickActions subscription fired: $($newValue.Count) items" -ForegroundColor Cyan
}

$result = & $store.Dispatch -self $store -actionName "LOAD_DASHBOARD_DATA"
if ($result.Success) {
    Write-Host "Dashboard data loaded successfully" -ForegroundColor Green
} else {
    Write-Host "Dashboard data load failed: $($result.Error)" -ForegroundColor Red
}

# Cleanup
& $store.Unsubscribe -self $store -subId $subId
& $store.Unsubscribe -self $store -subId $qaSubId

Write-Host ""
Write-Host "Test completed." -ForegroundColor Cyan
