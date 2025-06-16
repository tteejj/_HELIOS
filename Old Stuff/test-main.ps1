# Test runner for PMC Terminal
# This will help isolate any remaining issues

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    Clear-Host
    Write-Host "Starting PMC Terminal test..." -ForegroundColor Green
    
    # Run the main debug script
    & "$PSScriptRoot\main-debug.ps1"
    
} catch {
    Write-Host "`nTest failed with error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor White
    Write-Host "`nStack trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
