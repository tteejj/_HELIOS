# Test AppStore context
Write-Host "Testing AppStore Context..."
$testStore = Initialize-AppStore -InitialData @{ test = "initial" }
& $testStore.RegisterAction -self $testStore -actionName "TEST" -scriptBlock {
    param($Context)
    & $Context.UpdateState @{ test = "updated" }
}
$result = & $testStore.Dispatch -self $testStore -actionName "TEST"
$finalValue = & $testStore.GetState -self $testStore -path "test"
if ($finalValue -eq "updated") {
    Write-Host "✓ AppStore context works" -ForegroundColor Green
} else {
    Write-Host "✗ AppStore context failed" -ForegroundColor Red
}

# Test each screen loads without errors
@("dashboard", "task", "timer-start", "settings") | ForEach-Object {
    Write-Host "Testing $_ screen..."
    try {
        & $services.Navigation.GoTo -self $services.Navigation -Path "/$_" -Services $services
        Write-Host "✓ $_ screen loads" -ForegroundColor Green
    } catch {
        Write-Host "✗ $_ screen failed: $_" -ForegroundColor Red
    }
}