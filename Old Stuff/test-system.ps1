# Test script to verify the new TUI system is working

Write-Host "`nPMC Terminal v3.0 - System Check" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Check PowerShell version
Write-Host "`nPowerShell Version: " -NoNewline
Write-Host "$($PSVersionTable.PSVersion)" -ForegroundColor Green

# Check current directory
Write-Host "Current Directory: " -NoNewline
Write-Host (Get-Location) -ForegroundColor Green

# Check for required modules
Write-Host "`nChecking modules..." -ForegroundColor Yellow
$requiredModules = @(
    "event-system.psm1",
    "tui-engine-v2.psm1",
    "tui-components.psm1",
    "data-manager.psm1"
)

$allModulesFound = $true
foreach ($module in $requiredModules) {
    $modulePath = Join-Path (Get-Location) $module
    if (Test-Path $modulePath) {
        Write-Host "  ✓ $module" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $module" -ForegroundColor Red
        $allModulesFound = $false
    }
}

# Check for screens
Write-Host "`nChecking screens..." -ForegroundColor Yellow
$screensPath = Join-Path (Get-Location) "screens"
if (Test-Path $screensPath) {
    $screens = Get-ChildItem -Path $screensPath -Filter "*.psm1"
    foreach ($screen in $screens) {
        Write-Host "  ✓ $($screen.Name)" -ForegroundColor Green
    }
} else {
    Write-Host "  ✗ screens directory not found" -ForegroundColor Red
}

# Check console capabilities
Write-Host "`nConsole Capabilities:" -ForegroundColor Yellow
Write-Host "  Console Width: $([Console]::WindowWidth)"
Write-Host "  Console Height: $([Console]::WindowHeight)"
Write-Host "  ANSI Support: " -NoNewline

# Test ANSI support
try {
    [Console]::Write("`e[31mSupported`e[0m")
    Write-Host " ✓" -ForegroundColor Green
} catch {
    Write-Host "Not Supported ✗" -ForegroundColor Red
}

Write-Host "`nReady to start? (Y/N): " -NoNewline -ForegroundColor Yellow
$response = Read-Host

if ($response -eq 'Y' -or $response -eq 'y') {
    Write-Host "`nStarting PMC Terminal..." -ForegroundColor Green
    & ".\main.ps1"
} else {
    Write-Host "`nTest completed. Run .\main.ps1 when ready." -ForegroundColor Yellow
}
