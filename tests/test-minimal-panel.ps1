# Minimal Panel Render Test
Write-Host "Minimal Panel Render Test" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

# Load only essential modules
$script:BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path

$essentialModules = @(
    "modules\logger.psm1",
    "modules\event-system.psm1", 
    "modules\theme-manager.psm1",
    "modules\tui-framework.psm1",
    "modules\tui-engine-v2.psm1",
    "layout\panels.psm1",
    "components\tui-components.psm1"
)

Write-Host "`nLoading essential modules..." -ForegroundColor Yellow
foreach ($module in $essentialModules) {
    $path = Join-Path $script:BasePath $module
    if (Test-Path $path) {
        Import-Module $path -Force -Global
        Write-Host "  ✓ $module" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $module NOT FOUND" -ForegroundColor Red
    }
}

# Initialize systems
Write-Host "`nInitializing systems..." -ForegroundColor Yellow
Initialize-Logger
Initialize-EventSystem  
Initialize-ThemeManager
Initialize-TuiFramework
Initialize-TuiEngine
Write-Host "✓ Systems initialized" -ForegroundColor Green

# Create a minimal test screen
Write-Host "`nCreating test screen..." -ForegroundColor Yellow

$testScreen = @{
    Name = "MinimalPanelTest"
    Children = @()
    Visible = $true
    
    Init = {
        param($self)
        Write-Host "[TEST] Init called" -ForegroundColor Cyan
        
        # Test 1: Simple panel with explicit colors
        Write-Host "[TEST] Creating simple blue panel..." -ForegroundColor Yellow
        $panel1 = New-TuiStackPanel -Props @{
            Name = "TestPanel1"
            X = 5
            Y = 3
            Width = 30
            Height = 8
            ShowBorder = $true
            BorderStyle = "Single"
            Title = "Blue Panel"
            BackgroundColor = [ConsoleColor]::DarkBlue
            ForegroundColor = [ConsoleColor]::White
            Padding = 1
        }
        
        # Add a white label
        $label1 = New-TuiLabel -Props @{
            Text = "White text on blue"
            ForegroundColor = [ConsoleColor]::White
        }
        & $panel1.AddChild -self $panel1 -Child $label1
        
        # Test 2: Panel with theme colors
        Write-Host "[TEST] Creating themed panel..." -ForegroundColor Yellow
        $panel2 = New-TuiStackPanel -Props @{
            Name = "TestPanel2"
            X = 40
            Y = 3
            Width = 30
            Height = 8
            ShowBorder = $true
            Title = "Themed Panel"
            Padding = 1
        }
        
        $label2 = New-TuiLabel -Props @{
            Text = "Using theme colors"
        }
        & $panel2.AddChild -self $panel2 -Child $label2
        
        # Test 3: Grid panel
        Write-Host "[TEST] Creating grid panel..." -ForegroundColor Yellow
        $gridPanel = New-TuiGridPanel -Props @{
            Name = "TestGrid"
            X = 5
            Y = 13
            Width = 65
            Height = 10
            ShowBorder = $true
            Title = "Grid Test"
            RowDefinitions = @("1*", "1*")
            ColumnDefinitions = @("1*", "1*")
            ShowGridLines = $true
            BackgroundColor = [ConsoleColor]::DarkGray
        }
        
        # Add cells
        $cell1 = New-TuiLabel -Props @{ Text = "Cell 0,0"; ForegroundColor = [ConsoleColor]::Yellow }
        $cell2 = New-TuiLabel -Props @{ Text = "Cell 0,1"; ForegroundColor = [ConsoleColor]::Cyan }
        $cell3 = New-TuiLabel -Props @{ Text = "Cell 1,0"; ForegroundColor = [ConsoleColor]::Green }
        $cell4 = New-TuiLabel -Props @{ Text = "Cell 1,1"; ForegroundColor = [ConsoleColor]::Magenta }
        
        & $gridPanel.AddChild -self $gridPanel -Child $cell1 -LayoutProps @{ "Grid.Row" = 0; "Grid.Column" = 0 }
        & $gridPanel.AddChild -self $gridPanel -Child $cell2 -LayoutProps @{ "Grid.Row" = 0; "Grid.Column" = 1 }
        & $gridPanel.AddChild -self $gridPanel -Child $cell3 -LayoutProps @{ "Grid.Row" = 1; "Grid.Column" = 0 }
        & $gridPanel.AddChild -self $gridPanel -Child $cell4 -LayoutProps @{ "Grid.Row" = 1; "Grid.Column" = 1 }
        
        # Add all panels to screen
        $self.Children = @($panel1, $panel2, $gridPanel)
        
        Write-Host "[TEST] Screen children: $($self.Children.Count)" -ForegroundColor Green
        
        # Force calculate layouts
        foreach ($panel in $self.Children) {
            if ($panel.CalculateLayout) {
                Write-Host "[TEST] Calculating layout for $($panel.Name)..." -ForegroundColor Gray
                & $panel.CalculateLayout -self $panel
            }
        }
    }
    
    Render = {
        param($self)
        
        # Header
        Write-BufferString -X 2 -Y 1 -Text "MINIMAL PANEL TEST - Colors should be visible" -ForegroundColor Red
        
        # Manual check - draw a test box to verify Write-BufferBox works
        Write-BufferBox -X 75 -Y 3 -Width 20 -Height 5 -BorderColor White -Title "Manual Test"
        Write-BufferString -X 77 -Y 5 -Text "If you see this" -ForegroundColor Yellow
        Write-BufferString -X 77 -Y 6 -Text "rendering works!" -ForegroundColor Green
        
        # Status
        Write-BufferString -X 2 -Y 25 -Text "Press Q to quit | Children: $($self.Children.Count)" -ForegroundColor Gray
    }
    
    HandleInput = {
        param($self, $Key)
        if ($Key.KeyChar -eq 'q' -or $Key.KeyChar -eq 'Q') {
            return "Quit"
        }
        return $false
    }
}

# Initialize screen
Write-Host "`nInitializing screen..." -ForegroundColor Yellow
if ($testScreen.Init) {
    & $testScreen.Init -self $testScreen
}

# Check current theme
Write-Host "`nCurrent theme info:" -ForegroundColor Yellow
$theme = Get-CurrentTheme
if ($theme) {
    Write-Host "  Theme name: $($theme.Name ?? 'Unknown')" -ForegroundColor Gray
    Write-Host "  Primary color: $($theme.Colors.Primary ?? 'Not set')" -ForegroundColor Gray
    Write-Host "  Background: $($theme.Colors.Background ?? 'Not set')" -ForegroundColor Gray
} else {
    Write-Host "  No theme loaded!" -ForegroundColor Red
}

Write-Host "`nPress Enter to start test..." -ForegroundColor Yellow
$null = Read-Host

try {
    Clear-Host
    Push-Screen -Screen $testScreen
    Start-TuiLoop
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
} finally {
    Stop-TuiEngine
    Write-Host "`nTest completed." -ForegroundColor Green
}