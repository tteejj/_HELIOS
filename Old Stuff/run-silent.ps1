# Test script for fixed TUI rendering issues - Silent Mode
# This runs the terminal in silent mode to prevent initialization text bleed-through

# Set strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Clear the console first
Clear-Host

# Get the script directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

try {
    # Run main.ps1 with silent flag to suppress initialization messages
    & "$scriptPath\main.ps1" -silent
    
} catch {
    Write-Host "`nError occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
