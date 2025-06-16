# Test script to diagnose PMC Terminal issues
Clear-Host

Write-Host "PMC Terminal Diagnostic Test" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Console Size
Write-Host "Test 1: Console Size" -ForegroundColor Yellow
Write-Host "Current Width: $([Console]::WindowWidth)" -ForegroundColor Green
Write-Host "Current Height: $([Console]::WindowHeight)" -ForegroundColor Green
Write-Host ""

# Test 2: Key Input
Write-Host "Test 2: Key Input (Press any key to test)" -ForegroundColor Yellow
try {
    $key = [Console]::ReadKey($true)
    Write-Host "Key pressed successfully: $($key.Key)" -ForegroundColor Green
    Write-Host "KeyChar: $($key.KeyChar)" -ForegroundColor Green
    Write-Host "Modifiers: $($key.Modifiers)" -ForegroundColor Green
} catch {
    Write-Host "Error reading key: $_" -ForegroundColor Red
}
Write-Host ""

# Test 3: Module Loading
Write-Host "Test 3: Module Loading" -ForegroundColor Yellow
$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path
$modules = @(
    "modules\event-system.psm1",
    "modules\data-manager.psm1",
    "modules\theme-manager.psm1",
    "modules\tui-engine-v2.psm1",
    "modules\dialog-system.psm1",
    "components\tui-components.psm1"
)

foreach ($module in $modules) {
    $modulePath = Join-Path $basePath $module
    if (Test-Path $modulePath) {
        Write-Host "  [OK] $module" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $module" -ForegroundColor Red
    }
}
Write-Host ""

# Test 4: Simple Buffer Test
Write-Host "Test 4: Buffer Rendering" -ForegroundColor Yellow
Write-Host "Testing simple console output..." -ForegroundColor Gray
[Console]::ForegroundColor = [ConsoleColor]::Cyan
[Console]::Write("This is a test ")
[Console]::ForegroundColor = [ConsoleColor]::Yellow
[Console]::WriteLine("of color output")
[Console]::ResetColor()
Write-Host ""

Write-Host "Diagnostic complete. Press any key to exit..." -ForegroundColor Gray
$null = [Console]::ReadKey($true)