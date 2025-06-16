# Test script for fixed TUI rendering issues
# Run this to verify the fixes work correctly

# Set strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Clear the console first
Clear-Host

Write-Host "Testing Fixed TUI System..." -ForegroundColor Green
Write-Host "This test will:" -ForegroundColor Cyan
Write-Host "1. Test the fixed RenderFormField issue" -ForegroundColor Gray
Write-Host "2. Test screen clearing between renders" -ForegroundColor Gray
Write-Host "3. Navigate through screens to verify stability" -ForegroundColor Gray
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Get the script directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

try {
    # Import the main module
    Import-Module "$scriptPath\main.ps1" -Force
    
    Write-Host "`nModules loaded successfully!" -ForegroundColor Green
    Write-Host "Starting PMC Terminal..." -ForegroundColor Cyan
    
    # Add a small delay to ensure everything is initialized
    Start-Sleep -Milliseconds 500
    
    # Start the application
    & "$scriptPath\main.ps1"
    
} catch {
    Write-Host "`nError occurred during testing:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
