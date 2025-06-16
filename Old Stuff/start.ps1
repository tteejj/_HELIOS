# PMC Terminal v3.0 - Safe Startup Script
# This script checks your environment before starting the application

Write-Host "`nPMC Terminal v3.0 - Startup Check" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

# Function to check console size
function Test-MinimumConsoleSize {
    $width = [Console]::WindowWidth
    $height = [Console]::WindowHeight - 1
    $minWidth = 80
    $minHeight = 24
    
    Write-Host "`nChecking console size..." -ForegroundColor Yellow
    Write-Host "  Current: $width x $height"
    Write-Host "  Required: $minWidth x $minHeight"
    
    if ($width -lt $minWidth -or $height -lt $minHeight) {
        Write-Host "  Status: " -NoNewline
        Write-Host "TOO SMALL" -ForegroundColor Red
        Write-Host "`n  Please resize your console window to at least 80x24" -ForegroundColor Yellow
        Write-Host "  - In Windows Terminal: Drag window edges" -ForegroundColor Gray
        Write-Host "  - In PowerShell: Right-click title > Properties > Layout" -ForegroundColor Gray
        Write-Host "  - In VS Code: Drag terminal panel larger" -ForegroundColor Gray
        return $false
    }
    
    Write-Host "  Status: " -NoNewline
    Write-Host "OK" -ForegroundColor Green
    return $true
}

# Check PowerShell version
Write-Host "`nChecking PowerShell version..." -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
Write-Host "  Version: $psVersion"
if ($psVersion.Major -lt 5) {
    Write-Host "  Status: " -NoNewline
    Write-Host "UNSUPPORTED" -ForegroundColor Red
    Write-Host "  PowerShell 5.0 or higher required" -ForegroundColor Yellow
} else {
    Write-Host "  Status: " -NoNewline
    Write-Host "OK" -ForegroundColor Green
}

# Check if we can handle errors gracefully
$ErrorActionPreference = "Continue"

# Check console size
$sizeOk = Test-MinimumConsoleSize

if (-not $sizeOk) {
    Write-Host "`nCannot start PMC Terminal until console is resized." -ForegroundColor Red
    Write-Host "Please resize your window and run this script again." -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Check for required files
Write-Host "`nChecking required files..." -ForegroundColor Yellow
$requiredFiles = @(
    "main.ps1",
    "event-system.psm1",
    "tui-engine-v2.psm1",
    "tui-components.psm1",
    "data-manager.psm1"
)

$allFilesFound = $true
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file" -ForegroundColor Red
        $allFilesFound = $false
    }
}

if (-not $allFilesFound) {
    Write-Host "`nSome required files are missing!" -ForegroundColor Red
    Write-Host "Please ensure you're running from the correct directory." -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# All checks passed
Write-Host "`nAll checks passed!" -ForegroundColor Green
Write-Host "`nStarting PMC Terminal in 3 seconds..." -ForegroundColor Cyan
Write-Host "(Press Ctrl+C to cancel)" -ForegroundColor Gray

Start-Sleep -Seconds 3

# Clear screen and start
Clear-Host
& .\main.ps1
