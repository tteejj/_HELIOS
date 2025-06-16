# PMC Terminal v3.0 - Minimal Test Version
# This is a simplified version to test basic functionality

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$script:BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Test minimal startup
Clear-Host
Write-Host "PMC Terminal v3.0 - Test Mode" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

try {
    # Load only essential modules
    Write-Host "Loading core modules..." -ForegroundColor Yellow
    
    # Event System
    $eventPath = Join-Path $script:BasePath "modules\event-system.psm1"
    if (Test-Path $eventPath) {
        Import-Module $eventPath -Force -Global
        Initialize-EventSystem
        Write-Host "  [OK] Event System" -ForegroundColor Green
    } else {
        throw "Event system module not found"
    }
    
    # Theme Manager
    $themePath = Join-Path $script:BasePath "modules\theme-manager.psm1"
    if (Test-Path $themePath) {
        Import-Module $themePath -Force -Global
        Initialize-ThemeManager
        Write-Host "  [OK] Theme Manager" -ForegroundColor Green
    } else {
        throw "Theme manager module not found"
    }
    
    # Data Manager
    $dataPath = Join-Path $script:BasePath "modules\data-manager.psm1"
    if (Test-Path $dataPath) {
        Import-Module $dataPath -Force -Global
        Initialize-DataManager
        Load-UnifiedData
        Write-Host "  [OK] Data Manager" -ForegroundColor Green
    } else {
        throw "Data manager module not found"
    }
    
    # TUI Engine
    $tuiPath = Join-Path $script:BasePath "modules\tui-engine-v2.psm1"
    if (Test-Path $tuiPath) {
        Import-Module $tuiPath -Force -Global
        Write-Host "  [OK] TUI Engine" -ForegroundColor Green
    } else {
        throw "TUI engine module not found"
    }
    
    Write-Host ""
    Write-Host "Creating test screen..." -ForegroundColor Yellow
    
    # Create a minimal test screen
    $testScreen = @{
        Name = "TestScreen"
        State = @{ Counter = 0 }
        
        Render = {
            param($self)
            Write-BufferString -X 2 -Y 2 -Text "PMC Terminal Test Screen" -ForegroundColor "Cyan"
            Write-BufferString -X 2 -Y 4 -Text "Press Q to quit, Arrow keys to test" -ForegroundColor "White"
            Write-BufferString -X 2 -Y 6 -Text "Counter: $($self.State.Counter)" -ForegroundColor "Yellow"
            
            # Simple box test
            Write-BufferBox -X 2 -Y 8 -Width 40 -Height 6 -Title " Test Box " -BorderColor "Green"
            Write-BufferString -X 4 -Y 10 -Text "If you can read this," -ForegroundColor "White"
            Write-BufferString -X 4 -Y 11 -Text "the engine is working!" -ForegroundColor "White"
        }
        
        HandleInput = {
            param($self, $Key)
            switch ($Key.Key) {
                ([ConsoleKey]::Q) { return "Quit" }
                ([ConsoleKey]::UpArrow) { 
                    $self.State.Counter++
                    Request-TuiRefresh
                    return $true 
                }
                ([ConsoleKey]::DownArrow) { 
                    $self.State.Counter--
                    Request-TuiRefresh
                    return $true 
                }
            }
            return $false
        }
    }
    
    Write-Host "Initializing TUI Engine..." -ForegroundColor Yellow
    Initialize-TuiEngine
    
    Write-Host "Starting test loop..." -ForegroundColor Yellow
    Start-Sleep -Milliseconds 500
    
    Push-Screen -Screen ([PSCustomObject]$testScreen)
    Start-TuiLoop
    
} catch {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = [Console]::ReadKey($true)
} finally {
    [Console]::CursorVisible = $true
    [Console]::Clear()
    [Console]::ResetColor()
}