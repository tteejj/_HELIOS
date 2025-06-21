# Test Theme Colors
Write-Host "Testing Theme Colors" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan

# Load modules
$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module "$basePath\modules\theme-manager.psm1" -Force
Import-Module "$basePath\modules\tui-engine-v2.psm1" -Force

# Initialize theme
Initialize-ThemeManager
Write-Host "`nTheme Manager initialized" -ForegroundColor Green

# Test Get-ThemeColor
$colors = @("Primary", "Secondary", "Accent", "Border", "Header", "Subtle", "Error", "Warning", "Success")

Write-Host "`nTesting theme colors:" -ForegroundColor Yellow
foreach ($colorName in $colors) {
    $color = Get-ThemeColor $colorName
    Write-Host "  $colorName = " -NoNewline
    Write-Host "████" -ForegroundColor $color -NoNewline
    Write-Host " ($color)"
}

# Test console colors
Write-Host "`nConsole color test:" -ForegroundColor Yellow
[ConsoleColor].GetEnumValues() | ForEach-Object {
    Write-Host "  $_ = " -NoNewline
    Write-Host "████" -ForegroundColor $_ -NoNewline
    Write-Host ""
}

Write-Host "`nTest completed!" -ForegroundColor Green
