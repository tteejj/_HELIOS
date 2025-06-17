# Test script to debug panel creation and rendering
Set-Location "C:\Users\jhnhe\Documents\GitHub\_HELIOS"

# Load required modules
Import-Module ".\layout\panels.psm1" -Force

Write-Host "Testing panel creation..." -ForegroundColor Cyan

# Test 1: Create a GridPanel
Write-Host "`nTest 1: Creating GridPanel" -ForegroundColor Yellow
try {
    $gridPanel = New-TuiGridPanel -Props @{
        X = 10
        Y = 5
        Width = 50
        Height = 20
        ShowBorder = $true
        Title = "Test Grid Panel"
        RowDefinitions = @("10", "1*")
        ColumnDefinitions = @("20", "30")
    }
    
    Write-Host "GridPanel created successfully:" -ForegroundColor Green
    Write-Host "  Type: $($gridPanel.Type)"
    Write-Host "  Position: ($($gridPanel.X), $($gridPanel.Y))"
    Write-Host "  Size: $($gridPanel.Width) x $($gridPanel.Height)"
    Write-Host "  Visible: $($gridPanel.Visible)"
    Write-Host "  Has Render method: $($null -ne $gridPanel.Render)"
    Write-Host "  Has CalculateLayout method: $($null -ne $gridPanel.CalculateLayout)"
} catch {
    Write-Host "Error creating GridPanel: $_" -ForegroundColor Red
}

# Test 2: Create a StackPanel
Write-Host "`nTest 2: Creating StackPanel" -ForegroundColor Yellow
try {
    $stackPanel = New-TuiStackPanel -Props @{
        X = 10
        Y = 5
        Width = 30
        Height = 15
        ShowBorder = $true
        Title = "Test Stack Panel"
        Orientation = "Vertical"
        Spacing = 1
    }
    
    Write-Host "StackPanel created successfully:" -ForegroundColor Green
    Write-Host "  Type: $($stackPanel.Type)"
    Write-Host "  Position: ($($stackPanel.X), $($stackPanel.Y))"
    Write-Host "  Size: $($stackPanel.Width) x $($stackPanel.Height)"
    Write-Host "  Visible: $($stackPanel.Visible)"
    Write-Host "  Orientation: $($stackPanel.Orientation)"
    Write-Host "  Has Render method: $($null -ne $stackPanel.Render)"
    Write-Host "  Has CalculateLayout method: $($null -ne $stackPanel.CalculateLayout)"
} catch {
    Write-Host "Error creating StackPanel: $_" -ForegroundColor Red
}

# Test 3: Check if panel functions are exported
Write-Host "`nTest 3: Checking exported functions" -ForegroundColor Yellow
$exportedFunctions = Get-Command -Module panels
if ($exportedFunctions) {
    Write-Host "Exported functions from panels module:" -ForegroundColor Green
    $exportedFunctions | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "No functions exported from panels module!" -ForegroundColor Red
}

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")