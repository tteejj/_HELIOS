# Test script to verify AppStore UpdateState fix
Write-Host "Testing AppStore UpdateState Fix" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Change to script directory
Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Path)

# Load required modules
Write-Host "`nLoading modules..." -ForegroundColor Yellow

# Minimal module loading for test
$modulesToLoad = @(
    @{ Name = "tui-framework"; Path = "modules\tui-framework.psm1" },
    @{ Name = "app-store"; Path = "services\app-store.psm1" }
)

foreach ($module in $modulesToLoad) {
    $modulePath = Join-Path $PWD $module.Path
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -Global
    } else {
        Write-Host "Module not found: $($module.Name)" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Modules loaded successfully" -ForegroundColor Green

# Initialize AppStore
Write-Host "`nInitializing AppStore..." -ForegroundColor Yellow
$store = Initialize-AppStore -InitialData @{ testValue = "initial" }

# Register test action
Write-Host "Registering test action..." -ForegroundColor Yellow
& $store.RegisterAction -self $store -actionName "TEST_UPDATESTATE" -scriptBlock {
    param($Context)
    Write-Host "  Action executing - calling UpdateState..." -ForegroundColor Gray
    try {
        & $Context.UpdateState @{ testValue = "updated successfully!" }
        Write-Host "  UpdateState called successfully" -ForegroundColor Green
    } catch {
        Write-Host "  UpdateState failed: $_" -ForegroundColor Red
        throw
    }
}

# Create subscription to verify update
Write-Host "Creating subscription..." -ForegroundColor Yellow
$subId = & $store.Subscribe -self $store -path "testValue" -handler {
    param($NewValue, $OldValue)
    Write-Host "  Subscription triggered - New value: $NewValue" -ForegroundColor Cyan
}

# Dispatch the action
Write-Host "`nDispatching TEST_UPDATESTATE action..." -ForegroundColor Yellow
$result = & $store.Dispatch -self $store -actionName "TEST_UPDATESTATE"

# Check result
if ($result.Success) {
    Write-Host "Action dispatch succeeded!" -ForegroundColor Green
    
    # Verify final state
    $finalValue = & $store.GetState -self $store -path "testValue"
    Write-Host "`nFinal value: $finalValue" -ForegroundColor Cyan
    
    if ($finalValue -eq "updated successfully!") {
        Write-Host "`nTEST PASSED! UpdateState is working correctly." -ForegroundColor Green
    } else {
        Write-Host "`nTEST FAILED! Value was not updated correctly." -ForegroundColor Red
    }
} else {
    Write-Host "Action dispatch FAILED: $($result.Error)" -ForegroundColor Red
    Write-Host "`nTEST FAILED!" -ForegroundColor Red
}

# Cleanup
& $store.Unsubscribe -self $store -subId $subId
Write-Host "`nTest completed." -ForegroundColor Yellow