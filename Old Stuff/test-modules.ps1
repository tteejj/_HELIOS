# Test script to debug module loading

Write-Host "Testing module loading..." -ForegroundColor Cyan

$modules = @(
    "event-system.psm1",
    "tui-engine-v2.psm1",
    "tui-components.psm1",
    "data-manager.psm1"
)

foreach ($module in $modules) {
    $modulePath = Join-Path $PSScriptRoot $module
    try {
        Import-Module $modulePath -Force -Global -ErrorAction Stop
        Write-Host "✓ Loaded: $module" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed: $module - $_" -ForegroundColor Red
    }
}

# Test loading screen modules
$screensPath = Join-Path $PSScriptRoot "screens"
Get-ChildItem -Path $screensPath -Filter "*.psm1" | ForEach-Object {
    try {
        Import-Module $_.FullName -Force -Global -ErrorAction Stop
        Write-Host "✓ Loaded screen: $($_.Name)" -ForegroundColor Green
        
        # Test if function exists
        $functionName = $_.BaseName -replace '-screen', '' -replace '-', ''
        $functionName = "Get-" + (Get-Culture).TextInfo.ToTitleCase($functionName) + "Screen"
        
        if (Get-Command $functionName -ErrorAction SilentlyContinue) {
            Write-Host "  ✓ Function exists: $functionName" -ForegroundColor DarkGreen
        } else {
            Write-Host "  ✗ Function missing: $functionName" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "✗ Failed screen: $($_.Name) - $_" -ForegroundColor Red
        Write-Host "  Error details: $($_.Exception.Message)" -ForegroundColor DarkRed
    }
}

# Test specific functions
Write-Host "`nTesting specific functions:" -ForegroundColor Cyan
$testFunctions = @(
    "Get-DashboardScreen",
    "Get-TimeTrackingMenuScreen",
    "Get-TimeEntryFormScreen"
)

foreach ($func in $testFunctions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "✓ $func exists" -ForegroundColor Green
    } else {
        Write-Host "✗ $func missing" -ForegroundColor Red
    }
}
