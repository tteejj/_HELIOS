# Quick Test for AppStore Context Fix
# This tests that action handlers receive the correct context with UpdateState method

Write-Host "Testing AppStore Context Fix" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan

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

# Initialize test services
Write-Host "`nInitializing AppStore..." -ForegroundColor Yellow
$store = Initialize-AppStore -InitialData @{
    testValue = "initial"
} -EnableDebugLogging $true

# Register a test action
Write-Host "`nRegistering test action..." -ForegroundColor Yellow
& $store.RegisterAction -self $store -actionName "TEST_ACTION" -scriptBlock {
    param($Context, $Payload)
    
    Write-Host "  Action handler called" -ForegroundColor Magenta
    Write-Host "  Context type: $($Context.GetType().Name)" -ForegroundColor Gray
    Write-Host "  Context has UpdateState: $($Context.UpdateState -ne $null)" -ForegroundColor Gray
    
    if ($Context.UpdateState) {
        Write-Host "  Calling UpdateState..." -ForegroundColor Gray
        & $Context.UpdateState @{ testValue = "updated" }
        Write-Host "  UpdateState completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: UpdateState method not found!" -ForegroundColor Red
    }
}

# Test subscription with correct parameters
Write-Host "`nCreating subscription..." -ForegroundColor Yellow
$subId = & $store.Subscribe -self $store -path "testValue" -handler {
    param($NewValue, $OldValue, $Path)
    Write-Host "  Subscription handler called" -ForegroundColor Magenta
    Write-Host "  Path: $Path" -ForegroundColor Gray
    Write-Host "  OldValue: $OldValue" -ForegroundColor Gray
    Write-Host "  NewValue: $NewValue" -ForegroundColor Gray
}

Write-Host "`nSubscription ID: $subId" -ForegroundColor Cyan

# Dispatch the test action
Write-Host "`nDispatching TEST_ACTION..." -ForegroundColor Yellow
$result = & $store.Dispatch -self $store -actionName "TEST_ACTION"

if ($result.Success) {
    Write-Host "`nAction dispatched successfully!" -ForegroundColor Green
} else {
    Write-Host "`nAction dispatch failed: $($result.Error)" -ForegroundColor Red
}

# Check final state
Write-Host "`nChecking final state..." -ForegroundColor Yellow
$finalValue = & $store.GetState -self $store -path "testValue"
Write-Host "Final value: $finalValue" -ForegroundColor Cyan

if ($finalValue -eq "updated") {
    Write-Host "`nTest PASSED! Context and UpdateState are working correctly." -ForegroundColor Green
} else {
    Write-Host "`nTest FAILED! Value was not updated." -ForegroundColor Red
}
