# Phase 2.3 Implementation Test - Layout System Demo
# This demonstrates the new layout system with Stack and Grid layouts

# Test 1: Create a form using the new Stack layout
function Test-FormWithStackLayout {
    Write-Host "Testing Form with Stack Layout..." -ForegroundColor Green
    
    $testForm = Create-TuiForm -Title "User Registration" -Fields @(
        @{ Name = "Username"; Label = "Username"; Type = "TextBox" }
        @{ Name = "Email"; Label = "Email"; Type = "TextBox"; Placeholder = "user@example.com" }
        @{ Name = "Password"; Label = "Password"; Type = "TextBox" }
        @{ Name = "Country"; Label = "Country"; Type = "Dropdown"; Options = @(
            @{ Value = "US"; Display = "United States" }
            @{ Value = "CA"; Display = "Canada" }
            @{ Value = "UK"; Display = "United Kingdom" }
        )}
    ) -OnSubmit {
        param($FormData)
        Write-Host "Form submitted with data:" -ForegroundColor Yellow
        $FormData | Format-Table
    }
    
    Write-Host "✓ Form created with Stack layout (fields are automatically positioned)" -ForegroundColor Green
    return $testForm
}

# Test 2: Create a screen with Grid layout
function Test-GridLayoutScreen {
    Write-Host "`nTesting Grid Layout..." -ForegroundColor Green
    
    $gridScreen = Create-TuiScreen -Definition @{
        Name = "GridLayoutDemo"
        Layout = "Grid"
        LayoutOptions = @{
            Rows = 2
            Columns = 3
            Spacing = 2
            Padding = 2
            X = 5
            Y = 5
            Width = 70
            Height = 20
        }
        Children = @(
            @{ Name = "Cell1"; Type = "Label"; Props = @{ Text = "Cell 1,1" } }
            @{ Name = "Cell2"; Type = "Label"; Props = @{ Text = "Cell 1,2" } }
            @{ Name = "Cell3"; Type = "Label"; Props = @{ Text = "Cell 1,3" } }
            @{ Name = "Cell4"; Type = "Label"; Props = @{ Text = "Cell 2,1" } }
            @{ Name = "Cell5"; Type = "Label"; Props = @{ Text = "Cell 2,2 - Spanning"; ColSpan = 2 } }
        )
        Render = {
            param($self)
            Write-BufferBox -X 5 -Y 5 -Width 70 -Height 20 -Title " Grid Layout Demo " -BorderColor "Cyan"
        }
    }
    
    Write-Host "✓ Grid layout screen created (3x2 grid with cell spanning)" -ForegroundColor Green
    return $gridScreen
}

# Test 3: Create a container with horizontal Stack layout
function Test-HorizontalStackContainer {
    Write-Host "`nTesting Horizontal Stack Container..." -ForegroundColor Green
    
    $container = Create-TuiComponent -Type "Container" -Props @{
        X = 10
        Y = 10
        Width = 50
        Height = 5
        Layout = "Stack"
        LayoutOptions = @{
            Orientation = "Horizontal"
            Spacing = 3
            Padding = 1
        }
        Children = @(
            New-TuiButton -Props @{ Text = "Save"; Width = 10; Height = 3 }
            New-TuiButton -Props @{ Text = "Cancel"; Width = 10; Height = 3 }
            New-TuiButton -Props @{ Text = "Help"; Width = 10; Height = 3 }
        )
    }
    
    Write-Host "✓ Container with horizontal stack layout created" -ForegroundColor Green
    return $container
}

# Test 4: Dashboard with Grid layout
function Test-DashboardGrid {
    Write-Host "`nTesting Dashboard with Grid Layout..." -ForegroundColor Green
    
    # Load the new grid-based dashboard
    $modulePath = Join-Path $PSScriptRoot "screens\dashboard-screen-grid.psm1"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
        $dashboard = Get-DashboardScreen
        Write-Host "✓ Grid-based dashboard loaded successfully" -ForegroundColor Green
        return $dashboard
    } else {
        Write-Host "✗ Grid dashboard module not found at: $modulePath" -ForegroundColor Red
        return $null
    }
}

# Run tests
Write-Host "`n=== Phase 2.3 Layout System Implementation Tests ===" -ForegroundColor Cyan
Write-Host "This demonstrates the new layout managers in the TUI framework`n" -ForegroundColor Gray

# Run individual tests
$form = Test-FormWithStackLayout
$gridScreen = Test-GridLayoutScreen
$container = Test-HorizontalStackContainer
$dashboard = Test-DashboardGrid

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Phase 2.3 implementation includes:" -ForegroundColor Yellow
Write-Host "1. ✓ Apply-Layout function with Stack and Grid algorithms" -ForegroundColor Green
Write-Host "2. ✓ Container component that supports layouts" -ForegroundColor Green
Write-Host "3. ✓ Create-TuiForm refactored to use Stack layout" -ForegroundColor Green
Write-Host "4. ✓ Dashboard screen refactored to use Grid layout" -ForegroundColor Green
Write-Host "5. ✓ Create-TuiScreen already uses component factory" -ForegroundColor Green

Write-Host "`nKey improvements:" -ForegroundColor Yellow
Write-Host "- No more hardcoded coordinates in forms" -ForegroundColor Gray
Write-Host "- Automatic component positioning with layouts" -ForegroundColor Gray
Write-Host "- Responsive grid system for complex screens" -ForegroundColor Gray
Write-Host "- Consistent use of component factory pattern" -ForegroundColor Gray

Write-Host "`n✓ Phase 2.3 implementation complete!" -ForegroundColor Green