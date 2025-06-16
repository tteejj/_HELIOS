# Quick Test for Console Size Fix
# Test the console size validation

Clear-Host
Write-Host "Testing Console Size..." -ForegroundColor Cyan

$currentWidth = [Console]::WindowWidth
$currentHeight = [Console]::WindowHeight

Write-Host "Current console size: ${currentWidth}x${currentHeight}" -ForegroundColor White

$minWidth = 80
$minHeight = 24

if ($currentWidth -lt $minWidth -or $currentHeight -lt $minHeight) {
    Write-Host "Console too small - this would trigger the error" -ForegroundColor Red
    Write-Host "Required: ${minWidth}x${minHeight}" -ForegroundColor Yellow
} else {
    Write-Host "Console size OK - should work now" -ForegroundColor Green
}

Write-Host ""
Write-Host "Now testing main.ps1..." -ForegroundColor Cyan
