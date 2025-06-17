# Test script to debug dashboard panel rendering
Set-Location "C:\Users\jhnhe\Documents\GitHub\_HELIOS"

Write-Host "Loading modules..." -ForegroundColor Cyan

# Load modules in the correct order
$modules = @(
    ".\modules\logger.psm1",
    ".\modules\event-system.psm1",
    ".\modules\theme-manager.psm1",
    ".\modules\tui-engine-v2.psm1",
    ".\layout\panels.psm1",
    ".\components\tui-components.psm1",
    ".\components\advanced-data-components.psm1"
)

foreach ($module in $modules) {
    try {
        Import-Module $module -Force -Global
        Write-Host "  Loaded: $module" -ForegroundColor Green
    } catch {
        Write-Host "  Failed to load $module : $_" -ForegroundColor Red
    }
}

# Initialize logger
Initialize-Logger

Write-Host "`nTesting dashboard component creation..." -ForegroundColor Cyan

# Test creating components like dashboard does
try {
    # Create the main grid layout
    $rootPanel = New-TuiGridPanel -Props @{
        X = 1
        Y = 2
        Width = 80
        Height = 40
        ShowBorder = $false
        RowDefinitions = @("14", "1*")
        ColumnDefinitions = @("37", "42", "1*")
    }
    Write-Host "Root GridPanel created: Visible=$($rootPanel.Visible)" -ForegroundColor Green
    
    # Quick Actions Panel
    $quickActionsPanel = New-TuiStackPanel -Props @{
        Name = "quickActionsPanel"
        Title = " Quick Actions "
        ShowBorder = $true
        BorderStyle = "Single"
        Padding = 1
    }
    Write-Host "Quick Actions StackPanel created: Visible=$($quickActionsPanel.Visible)" -ForegroundColor Green
    
    # Quick Actions DataTable
    $quickActions = New-TuiDataTable -Props @{
        Name = "quickActions"
        IsFocusable = $true
        ShowBorder = $false
        ShowHeader = $false
        ShowFooter = $false
        Columns = @(
            @{ Name = "Action"; Width = 32 }
        )
        Data = @(
            @{ Action = "1. Add Time Entry" },
            @{ Action = "2. Start Timer" },
            @{ Action = "3. Manage Tasks" }
        )
    }
    Write-Host "Quick Actions DataTable created: Visible=$($quickActions.Visible), Data Count=$($quickActions.Data.Count)" -ForegroundColor Green
    
    # Add DataTable to Panel
    & $quickActionsPanel.AddChild -self $quickActionsPanel -Child $quickActions
    Write-Host "Added DataTable to Panel: Panel children=$($quickActionsPanel.Children.Count)" -ForegroundColor Green
    
    # Add Panel to Root
    & $rootPanel.AddChild -self $rootPanel -Child $quickActionsPanel -LayoutProps @{ 
        "Grid.Row" = 0
        "Grid.Column" = 0 
    }
    Write-Host "Added Panel to Root: Root children=$($rootPanel.Children.Count)" -ForegroundColor Green
    
    # Check render methods
    Write-Host "`nChecking render methods:" -ForegroundColor Yellow
    Write-Host "  RootPanel.Render exists: $($null -ne $rootPanel.Render)"
    Write-Host "  QuickActionsPanel.Render exists: $($null -ne $quickActionsPanel.Render)"
    Write-Host "  QuickActions.Render exists: $($null -ne $quickActions.Render)"
    
    # Test ProcessData on DataTable
    if ($quickActions.ProcessData) {
        Write-Host "`nCalling ProcessData on DataTable..." -ForegroundColor Yellow
        & $quickActions.ProcessData -self $quickActions
        Write-Host "  ProcessedData count: $($quickActions.ProcessedData.Count)" -ForegroundColor Green
    }
    
    # Initialize TUI Engine to test rendering
    Write-Host "`nInitializing TUI Engine..." -ForegroundColor Yellow
    Initialize-TuiEngine -Width 100 -Height 40
    
    # Try rendering the root panel
    Write-Host "`nTrying to render root panel..." -ForegroundColor Yellow
    if ($rootPanel.Render) {
        & $rootPanel.Render -self $rootPanel
        Write-Host "  Render completed without error" -ForegroundColor Green
    }
    
} catch {
    Write-Host "Error during test: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
}

Write-Host "`nCheck the log file for detailed debug output" -ForegroundColor Cyan
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")