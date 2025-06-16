# TUI Engine Test Script
# Run this to test the restored TUI engine with new components

# Set the base path
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

Write-Host "TUI Engine Test Script" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Module Loading
Write-Host "Test 1: Loading Modules..." -ForegroundColor Yellow
$modules = @(
    "modules\event-system.psm1",
    "modules\theme-manager.psm1", 
    "modules\tui-engine-v2.psm1",
    "components\tui-components.psm1",
    "components\advanced-input-components.psm1",
    "components\advanced-data-components.psm1"
)

$loadedCount = 0
foreach ($module in $modules) {
    try {
        Import-Module ".\$module" -Force -Global
        Write-Host "  ✓ Loaded: $module" -ForegroundColor Green
        $loadedCount++
    } catch {
        Write-Host "  ✗ Failed: $module - $_" -ForegroundColor Red
    }
}

Write-Host "Loaded $loadedCount of $($modules.Count) modules" -ForegroundColor $(if ($loadedCount -eq $modules.Count) { "Green" } else { "Yellow" })
Write-Host ""

# Test 2: TUI Engine Initialization
Write-Host "Test 2: TUI Engine Initialization..." -ForegroundColor Yellow
try {
    Initialize-EventSystem
    Initialize-ThemeManager
    Initialize-TuiEngine
    Write-Host "  ✓ TUI Engine initialized successfully" -ForegroundColor Green
    Write-Host "  Buffer size: $($global:TuiState.BufferWidth)x$($global:TuiState.BufferHeight)" -ForegroundColor Gray
} catch {
    Write-Host "  ✗ Failed to initialize TUI Engine: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 3: Component Creation
Write-Host "Test 3: Testing Component Creation..." -ForegroundColor Yellow
$componentTests = @(
    @{ Name = "TextBox"; Create = { New-TuiTextBox -Props @{X=0;Y=0;Width=20} } }
    @{ Name = "Button"; Create = { New-TuiButton -Props @{X=0;Y=0;Text="Test"} } }
    @{ Name = "Table"; Create = { New-TuiTable -Props @{X=0;Y=0;Columns=@()} } }
    @{ Name = "CalendarPicker"; Create = { New-TuiCalendarPicker -Props @{X=0;Y=0} } }
    @{ Name = "DataTable"; Create = { New-TuiDataTable -Props @{X=0;Y=0} } }
)

$componentCount = 0
foreach ($test in $componentTests) {
    try {
        $component = & $test.Create
        if ($component) {
            Write-Host "  ✓ Created: $($test.Name)" -ForegroundColor Green
            $componentCount++
        }
    } catch {
        Write-Host "  ✗ Failed: $($test.Name) - $_" -ForegroundColor Red
    }
}

Write-Host "Created $componentCount of $($componentTests.Count) components" -ForegroundColor $(if ($componentCount -eq $componentTests.Count) { "Green" } else { "Yellow" })
Write-Host ""

# Test 4: Screen Creation
Write-Host "Test 4: Creating Test Screen..." -ForegroundColor Yellow
$testScreen = @{
    Name = "TestScreen"
    State = @{
        Counter = 0
        TestData = @(
            [PSCustomObject]@{ Name = "Test 1"; Value = 100 }
            [PSCustomObject]@{ Name = "Test 2"; Value = 200 }
        )
    }
    
    Render = {
        param($self)
        
        # Test rendering functions
        Write-BufferBox -X 5 -Y 2 -Width 70 -Height 20 -Title " TUI Engine Test " -BorderColor (Get-ThemeColor "Accent")
        
        Write-BufferString -X 10 -Y 4 -Text "TUI Engine v3.0 - Restored with Enhancements" -ForegroundColor (Get-ThemeColor "Header")
        
        Write-BufferString -X 10 -Y 6 -Text "Features:" -ForegroundColor (Get-ThemeColor "Primary")
        Write-BufferString -X 12 -Y 7 -Text "✓ ANSI Rendering with StringBuilder" -ForegroundColor (Get-ThemeColor "Success")
        Write-BufferString -X 12 -Y 8 -Text "✓ Double Buffer Optimization" -ForegroundColor (Get-ThemeColor "Success")
        Write-BufferString -X 12 -Y 9 -Text "✓ Async Input Handling" -ForegroundColor (Get-ThemeColor "Success")
        Write-BufferString -X 12 -Y 10 -Text "✓ Component System" -ForegroundColor (Get-ThemeColor "Success")
        Write-BufferString -X 12 -Y 11 -Text "✓ Layout Management" -ForegroundColor (Get-ThemeColor "Success")
        Write-BufferString -X 12 -Y 12 -Text "✓ Advanced Components" -ForegroundColor (Get-ThemeColor "Success")
        
        Write-BufferString -X 10 -Y 14 -Text "Counter: $($self.State.Counter)" -ForegroundColor (Get-ThemeColor "Info")
        
        # Test table rendering
        $table = New-TuiTable -Props @{
            X = 10
            Y = 16
            Width = 60
            Height = 4
            Columns = @(
                @{ Name = "Name"; Header = "Item" }
                @{ Name = "Value"; Header = "Value" }
            )
            Rows = $self.State.TestData
        }
        & $table.Render -self $table
        
        Write-BufferString -X 10 -Y 21 -Text "Press SPACE to increment, R to refresh, Q to quit" -ForegroundColor (Get-ThemeColor "Subtle")
    }
    
    HandleInput = {
        param($self, $Key)
        switch ($Key.Key) {
            ([ConsoleKey]::Q) { return "Quit" }
            ([ConsoleKey]::Spacebar) {
                $self.State.Counter++
                Request-TuiRefresh
                return $true
            }
            ([ConsoleKey]::R) {
                Request-TuiRefresh
                return $true
            }
        }
        return $false
    }
}

try {
    Push-Screen -Screen $testScreen
    Write-Host "  ✓ Test screen created successfully" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to create test screen: $_" -ForegroundColor Red
}
Write-Host ""

# Run the test
Write-Host "Starting TUI Loop Test..." -ForegroundColor Yellow
Write-Host "This will render a test screen. Press Q to exit." -ForegroundColor Gray
Write-Host ""
Write-Host "Press any key to start the test..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

try {
    Start-TuiLoop
    Write-Host "`n✓ TUI Loop completed successfully" -ForegroundColor Green
} catch {
    Write-Host "`n✗ TUI Loop failed: $_" -ForegroundColor Red
} finally {
    # Cleanup
    if (Get-Command -Name "Stop-TuiEngine" -ErrorAction SilentlyContinue) {
        Stop-TuiEngine
    }
}

Write-Host "`nTest complete!" -ForegroundColor Cyan
