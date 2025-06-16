# PMC Terminal v3.0 - DEBUG VERSION - Main Entry Point
# This version adds detailed debugging to isolate the null method call error

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$script:BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Module loading order is critical - dependencies must load first
$script:ModulesToLoad = @(
    @{ Name = "event-system"; Path = "modules\event-system.psm1"; Required = $true },
    @{ Name = "data-manager"; Path = "modules\data-manager.psm1"; Required = $true },
    @{ Name = "theme-manager"; Path = "modules\theme-manager.psm1"; Required = $true },
    @{ Name = "tui-engine-v2"; Path = "modules\tui-engine-v2.psm1"; Required = $true },
    @{ Name = "dialog-system"; Path = "modules\dialog-system.psm1"; Required = $true },
    @{ Name = "tui-components"; Path = "components\tui-components.psm1"; Required = $true },
    @{ Name = "advanced-input-components"; Path = "components\advanced-input-components.psm1"; Required = $false },
    @{ Name = "advanced-data-components"; Path = "components\advanced-data-components.psm1"; Required = $false },
    @{ Name = "tui-framework"; Path = "modules\tui-framework.psm1"; Required = $false }
)

function Write-DebugStep {
    param(
        [string]$StepName,
        [ConsoleColor]$Color = "Cyan"
    )
    Write-Host "DEBUG: *** $StepName ***" -ForegroundColor $Color
}

function Test-SafeCall {
    param(
        [string]$Description,
        [scriptblock]$ScriptBlock,
        [bool]$Required = $true
    )
    
    Write-DebugStep "STARTING: $Description" "Yellow"
    try {
        $result = & $ScriptBlock
        Write-DebugStep "SUCCESS: $Description" "Green"
        return $result
    } catch {
        Write-DebugStep "FAILED: $Description" "Red"
        Write-Host "ERROR MESSAGE: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "ERROR TYPE: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        Write-Host "STACK TRACE:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        
        if ($_.Exception.InnerException) {
            Write-Host "INNER EXCEPTION: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }
        
        if ($Required) {
            Write-Host "THIS IS A REQUIRED STEP - STOPPING EXECUTION" -ForegroundColor Red
            throw
        } else {
            Write-Host "THIS IS AN OPTIONAL STEP - CONTINUING" -ForegroundColor Yellow
            return $null
        }
    }
}

function Initialize-PMCModules {
    Write-DebugStep "MODULE LOADING PHASE" "Magenta"
    
    # Console size validation
    Test-SafeCall "Console size validation" {
        $minWidth = 80
        $minHeight = 24
        $currentWidth = [Console]::WindowWidth
        $currentHeight = [Console]::WindowHeight
        
        Write-Host "DEBUG: Console size: ${currentWidth}x${currentHeight}"
        
        if ($currentWidth -lt $minWidth -or $currentHeight -lt $minHeight) {
            Write-Host "Console window too small!" -ForegroundColor Red
            Write-Host "Current size: ${currentWidth}x${currentHeight}" -ForegroundColor Yellow
            Write-Host "Minimum required: ${minWidth}x${minHeight}" -ForegroundColor Green
            Write-Host ""
            Write-Host "Please resize your console window and try again." -ForegroundColor White
            Write-Host "Press any key to exit..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 1
        }
    }
    
    Write-Host "Initializing PMC Terminal v3.0..." -ForegroundColor Cyan
    
    $loadedModules = @()
    
    foreach ($module in $script:ModulesToLoad) {
        $modulePath = Join-Path $script:BasePath $module.Path
        
        Test-SafeCall "Loading module: $($module.Name)" {
            if (Test-Path $modulePath) {
                Write-Host "  Loading $($module.Name) from $modulePath..." -ForegroundColor Gray
                Import-Module $modulePath -Force -Global -ErrorAction Stop
                $loadedModules += $module.Name
                Write-Host "  Module $($module.Name) loaded successfully" -ForegroundColor Green
            } elseif ($module.Required) {
                throw "Required module not found: $($module.Name) at $modulePath"
            }
        } $module.Required
    }
    
    Write-Host "Loaded $($loadedModules.Count) modules successfully" -ForegroundColor Green
    return $loadedModules
}

function Initialize-PMCScreens {
    Write-DebugStep "SCREEN LOADING PHASE" "Magenta"
    
    $script:ScreenModules = @(
        "dashboard-screen",
        "time-entry-screen", 
        "task-management-screen",
        "project-management-screen",
        "timer-management-screen",
        "reports-screen",
        "settings-screen",
        "demo-screen"
    )
    
    $loadedScreens = @()
    
    foreach ($screenName in $script:ScreenModules) {
        $screenPath = Join-Path $script:BasePath "screens\$screenName.psm1"
        
        Test-SafeCall "Loading screen: $screenName" {
            if (Test-Path $screenPath) {
                Import-Module $screenPath -Force -Global -ErrorAction SilentlyContinue
                $loadedScreens += $screenName
            } else {
                Write-Host "  Screen module not found: $screenName" -ForegroundColor Yellow
            }
        } $false
    }
    
    Write-Host "Loaded $($loadedScreens.Count) screens" -ForegroundColor Green
    return $loadedScreens
}

function Start-PMCTerminal {
    try {
        Write-DebugStep "APPLICATION STARTUP PHASE" "Magenta"
        
        $loadedModules = Initialize-PMCModules
        
        Write-Host "`nInitializing subsystems..." -ForegroundColor Cyan
        
        # Initialize core systems in correct order with detailed debugging
        # Event system MUST be first as other systems depend on it
        Test-SafeCall "Initialize-EventSystem" {
            if (Get-Command -Name "Initialize-EventSystem" -ErrorAction SilentlyContinue) {
                Initialize-EventSystem
                Write-Host "DEBUG: Event system state after init: OK" -ForegroundColor Green
            } else {
                throw "Initialize-EventSystem function not found"
            }
        }
        
        # Theme manager and data manager can initialize after events
        Test-SafeCall "Initialize-ThemeManager" {
            if (Get-Command -Name "Initialize-ThemeManager" -ErrorAction SilentlyContinue) {
                Initialize-ThemeManager
                Write-Host "DEBUG: Theme manager state after init: OK" -ForegroundColor Green
            } else {
                throw "Initialize-ThemeManager function not found"
            }
        }
        
        Test-SafeCall "Initialize-DataManager" {
            if (Get-Command -Name "Initialize-DataManager" -ErrorAction SilentlyContinue) {
                Initialize-DataManager
                Write-Host "DEBUG: Data manager state after init: OK" -ForegroundColor Green
            } else {
                throw "Initialize-DataManager function not found"
            }
        }
        
        # TUI Engine MUST be initialized BEFORE dialog system
        # as dialog system uses TUI functions
        Test-SafeCall "Initialize-TuiEngine" {
            if (Get-Command -Name "Initialize-TuiEngine" -ErrorAction SilentlyContinue) {
                Write-Host "DEBUG: About to call Initialize-TuiEngine with no parameters" -ForegroundColor Yellow
                Initialize-TuiEngine
                Write-Host "DEBUG: TUI Engine state after init: OK" -ForegroundColor Green
                
                # Verify TUI state
                if ($global:TuiState) {
                    Write-Host "DEBUG: TuiState exists, BufferWidth: $($global:TuiState.BufferWidth)" -ForegroundColor Green
                } else {
                    Write-Host "DEBUG: WARNING - TuiState is null after initialization" -ForegroundColor Yellow
                }
            } else {
                throw "Initialize-TuiEngine function not found"
            }
        }
        
        # Dialog system depends on TUI engine
        Test-SafeCall "Initialize-DialogSystem" {
            if (Get-Command -Name "Initialize-DialogSystem" -ErrorAction SilentlyContinue) {
                Initialize-DialogSystem
                Write-Host "DEBUG: Dialog system state after init: OK" -ForegroundColor Green
            } else {
                Write-Host "DEBUG: Initialize-DialogSystem function not found, skipping" -ForegroundColor Yellow
            }
        } $false
        
        # Load data after all systems are initialized
        Test-SafeCall "Load-UnifiedData" {
            if (Get-Command -Name "Load-UnifiedData" -ErrorAction SilentlyContinue) {
                Load-UnifiedData
                Write-Host "DEBUG: Data loaded successfully" -ForegroundColor Green
            } else {
                Write-Host "DEBUG: Load-UnifiedData function not found, skipping" -ForegroundColor Yellow
            }
        } $false
        
        # Initialize optional framework
        Test-SafeCall "Initialize-TuiFramework" {
            if (Get-Command -Name "Initialize-TuiFramework" -ErrorAction SilentlyContinue) {
                Initialize-TuiFramework
                Write-Host "  TUI Framework initialized" -ForegroundColor Gray
            } else {
                Write-Host "DEBUG: Initialize-TuiFramework function not found, skipping" -ForegroundColor Yellow
            }
        } $false
        
        # Load screens
        Initialize-PMCScreens
        
        Write-DebugStep "STARTING APPLICATION UI" "Magenta"
        
        # Check if demo mode is requested
        if ($args -contains "-demo") {
            Write-Host "Starting in demo mode..." -ForegroundColor Cyan
            Test-SafeCall "Get-DemoScreen" {
                if (Get-Command -Name "Get-DemoScreen" -ErrorAction SilentlyContinue) {
                    $demoScreen = Get-DemoScreen
                    Push-Screen -Screen $demoScreen
                } else {
                    throw "Demo screen not available"
                }
            } $false
        } else {
            # Normal startup
            Test-SafeCall "Get-DashboardScreen" {
                if (Get-Command -Name "Get-DashboardScreen" -ErrorAction SilentlyContinue) {
                    $dashboardScreen = Get-DashboardScreen
                    Push-Screen -Screen $dashboardScreen
                } else {
                    Write-Host "Dashboard screen not found, using fallback..." -ForegroundColor Yellow
                    $welcomeScreen = @{
                        Name = "WelcomeScreen"
                        State = @{}
                        
                        Render = { 
                            Write-BufferBox -X 10 -Y 5 -Width 60 -Height 15 -Title " PMC Terminal v3.0 " -BorderColor "Cyan"
                            Write-BufferString -X 15 -Y 8 -Text "Welcome to PMC Terminal!" -ForegroundColor "White"
                            Write-BufferString -X 15 -Y 10 -Text "Dashboard screen could not be loaded." -ForegroundColor "Gray"
                            Write-BufferString -X 15 -Y 12 -Text "Press Q to quit or D for demo" -ForegroundColor "Yellow"
                        }
                        
                        HandleInput = { 
                            param($self, $Key)
                            switch ($Key.Key) {
                                ([ConsoleKey]::Q) { return "Quit" }
                                ([ConsoleKey]::D) {
                                    if (Get-Command -Name "Get-DemoScreen" -ErrorAction SilentlyContinue) {
                                        Push-Screen -Screen (Get-DemoScreen)
                                    }
                                    return $true
                                }
                            }
                            return $false
                        }
                    }
                    Push-Screen -Screen $welcomeScreen
                }
            } $false
        }
        
        # Start the main loop
        Test-SafeCall "Start-TuiLoop" {
            Write-Host "DEBUG: About to start TUI main loop" -ForegroundColor Yellow
            Start-TuiLoop
            Write-Host "DEBUG: TUI main loop ended normally" -ForegroundColor Green
        }
        
    } catch {
        Write-DebugStep "FATAL ERROR CAUGHT" "Red"
        Write-Host "EXCEPTION MESSAGE: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "EXCEPTION TYPE: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        Write-Host "SCRIPT STACK TRACE:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        
        if ($_.Exception.InnerException) {
            Write-Host "INNER EXCEPTION: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }
        
        Write-Error "FATAL: Failed to initialize PMC Terminal: $_"
        throw
    } finally {
        Write-DebugStep "CLEANUP PHASE" "Magenta"
        
        # Cleanup
        Test-SafeCall "Stop-TuiEngine" {
            if (Get-Command -Name "Stop-TuiEngine" -ErrorAction SilentlyContinue) {
                Write-Host "`nShutting down..." -ForegroundColor Yellow
                Stop-TuiEngine
            } else {
                Write-Host "DEBUG: Stop-TuiEngine function not found" -ForegroundColor Yellow
            }
        } $false
        
        Test-SafeCall "Save-UnifiedData" {
            if ($Data -and (Get-Command -Name "Save-UnifiedData" -ErrorAction SilentlyContinue)) {
                Write-Host "Saving data..." -ForegroundColor Yellow
                Save-UnifiedData
            } else {
                Write-Host "DEBUG: Save-UnifiedData not available or no data to save" -ForegroundColor Yellow
            }
        } $false
        
        Write-Host "Goodbye!" -ForegroundColor Green
    }
}

# Parse command line arguments
$script:args = $args

try {
    Clear-Host
    Write-DebugStep "PMC TERMINAL DEBUG MODE STARTUP" "White"
    Start-PMCTerminal
} catch {
    Write-DebugStep "TOP-LEVEL ERROR HANDLER" "Red"
    Write-Error "Fatal error: $_"
    Write-Host "`nPress any key to exit..." -ForegroundColor Red
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}
