# Complete PMC Terminal Test - Verify All Core Modules
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path

function Test-Module {
    param($ModuleName, $ModulePath, $Required = $true)
    
    try {
        Write-Host "  Testing $ModuleName..." -ForegroundColor Gray
        $fullPath = Join-Path $basePath $ModulePath
        
        if (-not (Test-Path $fullPath)) {
            if ($Required) {
                throw "Module file not found: $fullPath"
            } else {
                Write-Host "    Optional module not found: $ModuleName" -ForegroundColor Yellow
                return $false
            }
        }
        
        Import-Module $fullPath -Force -Global
        Write-Host "    ✓ $ModuleName loaded successfully" -ForegroundColor Green
        return $true
    } catch {
        if ($Required) {
            Write-Host "    ✗ FAILED: $ModuleName - $_" -ForegroundColor Red
            throw
        } else {
            Write-Host "    ⚠ Optional module failed: $ModuleName - $_" -ForegroundColor Yellow
            return $false
        }
    }
}

function Test-Function {
    param($FunctionName, $Required = $true)
    
    try {
        $exists = Get-Command -Name $FunctionName -ErrorAction SilentlyContinue
        if ($exists) {
            Write-Host "    ✓ Function $FunctionName is available" -ForegroundColor Green
            return $true
        } else {
            if ($Required) {
                throw "Required function $FunctionName not found"
            } else {
                Write-Host "    ⚠ Optional function $FunctionName not found" -ForegroundColor Yellow
                return $false
            }
        }
    } catch {
        if ($Required) {
            Write-Host "    ✗ FAILED: Function $FunctionName - $_" -ForegroundColor Red
            throw
        } else {
            Write-Host "    ⚠ Optional function failed: $FunctionName - $_" -ForegroundColor Yellow
            return $false
        }
    }
}

try {
    Write-Host "PMC Terminal Module Test Suite" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host ""
    
    # Test core modules in dependency order
    Write-Host "Testing Core Modules:" -ForegroundColor Yellow
    Test-Module "Event System" "modules\event-system.psm1"
    Test-Module "Theme Manager" "modules\theme-manager.psm1" 
    Test-Module "Data Manager" "modules\data-manager.psm1"
    Test-Module "TUI Engine v2" "modules\tui-engine-v2.psm1"
    Test-Module "Dialog System" "modules\dialog-system.psm1"
    
    Write-Host ""
    Write-Host "Testing Component Modules:" -ForegroundColor Yellow
    Test-Module "TUI Components" "components\tui-components.psm1" -Required $false
    Test-Module "TUI Framework" "modules\tui-framework.psm1" -Required $false
    
    Write-Host ""
    Write-Host "Testing Screen Modules:" -ForegroundColor Yellow
    Test-Module "Dashboard Screen" "screens\dashboard-screen.psm1"
    Test-Module "Demo Screen" "screens\demo-screen.psm1" -Required $false
    
    Write-Host ""
    Write-Host "Testing Core Functions:" -ForegroundColor Yellow
    Test-Function "Initialize-EventSystem"
    Test-Function "Initialize-ThemeManager"
    Test-Function "Initialize-DataManager"
    Test-Function "Initialize-TuiEngine"
    Test-Function "Start-TuiLoop"
    Test-Function "Get-DashboardScreen"
    Test-Function "Load-UnifiedData"
    Test-Function "Save-UnifiedData"
    
    Write-Host ""
    Write-Host "Initializing Systems:" -ForegroundColor Yellow
    
    Write-Host "  Initializing Event System..." -ForegroundColor Gray
    Initialize-EventSystem
    Write-Host "    ✓ Event System initialized" -ForegroundColor Green
    
    Write-Host "  Initializing Theme Manager..." -ForegroundColor Gray
    Initialize-ThemeManager
    Write-Host "    ✓ Theme Manager initialized" -ForegroundColor Green
    
    Write-Host "  Initializing Data Manager..." -ForegroundColor Gray
    Initialize-DataManager
    Write-Host "    ✓ Data Manager initialized" -ForegroundColor Green
    
    Write-Host "  Loading Data..." -ForegroundColor Gray
    Load-UnifiedData
    Write-Host "    ✓ Data loaded" -ForegroundColor Green
    
    Write-Host "  Initializing Dialog System..." -ForegroundColor Gray
    if (Get-Command -Name "Initialize-DialogSystem" -ErrorAction SilentlyContinue) {
        Initialize-DialogSystem
        Write-Host "    ✓ Dialog System initialized" -ForegroundColor Green
    } else {
        Write-Host "    ⚠ Dialog System not available" -ForegroundColor Yellow
    }
    
    Write-Host "  Initializing TUI Engine..." -ForegroundColor Gray
    Initialize-TuiEngine -Width 80 -Height 24
    Write-Host "    ✓ TUI Engine initialized" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Creating Test Screen..." -ForegroundColor Yellow
    $testScreen = @{
        Name = "TestScreen"
        State = @{}
        
        Render = {
            Write-BufferBox -X 10 -Y 5 -Width 60 -Height 15 -Title " PMC Terminal Test Success " -BorderColor "Green"
            Write-BufferString -X 15 -Y 8 -Text "All core modules loaded successfully!" -ForegroundColor "White"
            Write-BufferString -X 15 -Y 10 -Text "TUI Engine is working correctly." -ForegroundColor "Green"
            Write-BufferString -X 15 -Y 12 -Text "Data system is operational." -ForegroundColor "Green"
            Write-BufferString -X 15 -Y 14 -Text "Event system is active." -ForegroundColor "Green"
            Write-BufferString -X 15 -Y 16 -Text "Press D for Dashboard, Q to quit" -ForegroundColor "Yellow"
        }
        
        HandleInput = {
            param($self, $Key)
            switch ($Key.Key) {
                ([ConsoleKey]::Q) { return "Quit" }
                ([ConsoleKey]::D) {
                    if (Get-Command -Name "Get-DashboardScreen" -ErrorAction SilentlyContinue) {
                        Push-Screen -Screen (Get-DashboardScreen)
                    }
                    return $true
                }
            }
            return $false
        }
    }
    
    Write-Host ""
    Write-Host "✓ ALL TESTS PASSED!" -ForegroundColor Green
    Write-Host "✓ PMC Terminal is ready to run!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Starting test interface..." -ForegroundColor Cyan
    Write-Host "(Press D for Dashboard or Q to quit)" -ForegroundColor Yellow
    
    Start-Sleep -Seconds 2
    Start-TuiLoop -InitialScreen $testScreen
    
} catch {
    Write-Host ""
    Write-Host "✗ TEST FAILED!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
} finally {
    Write-Host ""
    Write-Host "Test completed." -ForegroundColor Cyan
}
