# PMC Terminal v3.0 - Main Entry Point
# This file orchestrates module loading and application startup

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$script:BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Module loading order is critical - dependencies must load first
$script:ModulesToLoad = @(
    @{ Name = "logger"; Path = "modules\logger.psm1"; Required = $true },
    @{ Name = "event-system"; Path = "modules\event-system.psm1"; Required = $true },
    @{ Name = "data-manager"; Path = "modules\data-manager.psm1"; Required = $true },
    @{ Name = "theme-manager"; Path = "modules\theme-manager.psm1"; Required = $true },
    @{ Name = "tui-engine-v2"; Path = "modules\tui-engine-v2.psm1"; Required = $true },
    @{ Name = "dialog-system"; Path = "modules\dialog-system.psm1"; Required = $true },
    @{ Name = "tui-components"; Path = "components\tui-components.psm1"; Required = $true },
    @{ Name = "advanced-input-components"; Path = "components\advanced-input-components.psm1"; Required = $false },
    @{ Name = "advanced-data-components"; Path = "components\advanced-data-components.psm1"; Required = $true },
    @{ Name = "layout-manager"; Path = "utilities\layout-manager.psm1"; Required = $false },
    @{ Name = "positioning-helper"; Path = "utilities\positioning-helper.psm1"; Required = $false },
    @{ Name = "focus-manager"; Path = "utilities\focus-manager.psm1"; Required = $false },
    @{ Name = "tui-framework"; Path = "modules\tui-framework.psm1"; Required = $false }
)

# Screen modules will be loaded dynamically
$script:ScreenModules = @(
    "dashboard-screen-grid",
    "time-entry-screen",
    "timer-start-screen",
    "task-screen",
    "project-management-screen",
    "timer-management-screen",
    "reports-screen",
    "settings-screen",
    "debug-log-screen",
    "demo-screen"
)

function Initialize-PMCModules {
    param([bool]$Silent = $false)
    
    # Console size validation
    $minWidth = 80
    $minHeight = 24
    $currentWidth = [Console]::WindowWidth
    $currentHeight = [Console]::WindowHeight
    
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
    
    if (-not $Silent) {
        Write-Host "Initializing PMC Terminal v3.0..." -ForegroundColor Cyan
    }
    
    $loadedModules = @()
    
    foreach ($module in $script:ModulesToLoad) {
        $modulePath = Join-Path $script:BasePath $module.Path
        
        try {
            if (Test-Path $modulePath) {
                if (-not $Silent) {
                    Write-Host "  Loading $($module.Name)..." -ForegroundColor Gray
                }
                Import-Module $modulePath -Force -Global -ErrorAction Stop
                $loadedModules += $module.Name
            } elseif ($module.Required) {
                throw "Required module not found: $($module.Name) at $modulePath"
            }
        } catch {
            if ($module.Required) {
                throw "Failed to load required module $($module.Name): $_"
            } else {
                if (-not $Silent) {
                    Write-Host "  Optional module $($module.Name) not loaded: $_" -ForegroundColor Yellow
                }
            }
        }
    }
    
    if (-not $Silent) {
        Write-Host "Loaded $($loadedModules.Count) modules successfully" -ForegroundColor Green
    }
    return $loadedModules
}

function Initialize-PMCScreens {
    param([bool]$Silent = $false)
    
    if (-not $Silent) {
        Write-Host "Loading screens..." -ForegroundColor Cyan
    }
    
    $loadedScreens = @()
    
    foreach ($screenName in $script:ScreenModules) {
        $screenPath = Join-Path $script:BasePath "screens\$screenName.psm1"
        
        try {
            if (Test-Path $screenPath) {
                Import-Module $screenPath -Force -Global -ErrorAction SilentlyContinue
                $loadedScreens += $screenName
            } else {
                if (-not $Silent) {
                    Write-Host "  Screen module not found: $screenName" -ForegroundColor Yellow
                }
            }
        } catch {
            if (-not $Silent) {
                Write-Host "  Failed to load screen: $screenName - $_" -ForegroundColor Yellow
            }
        }
    }
    
    if (-not $Silent) {
        Write-Host "Loaded $($loadedScreens.Count) screens" -ForegroundColor Green
    }
    return $loadedScreens
}

function Start-PMCTerminal {
    param([bool]$Silent = $false)
    
    try {
        $loadedModules = Initialize-PMCModules -Silent:$Silent
        
        if (-not $Silent) {
            Write-Host "`nInitializing subsystems..." -ForegroundColor Cyan
        }
        
        # Initialize logger first to capture all subsequent events
        if (Get-Command Initialize-Logger -ErrorAction SilentlyContinue) {
            Initialize-Logger
            Write-Log -Level Info -Message "PMC Terminal startup initiated"
            Write-Log -Level Info -Message "Loaded modules: $($loadedModules -join ', ')"
        }
        
        # Initialize core systems in correct order
        # Event system MUST be first as other systems depend on it
        Initialize-EventSystem
        
        # Theme manager and data manager can initialize after events
        Initialize-ThemeManager
        Initialize-DataManager
        
        # TUI Engine MUST be initialized BEFORE dialog system
        # as dialog system uses TUI functions
        Initialize-TuiEngine
        
        # Dialog system depends on TUI engine
        Initialize-DialogSystem
        
        # Load data after all systems are initialized
        Load-UnifiedData
        
        # Initialize optional framework
        if (Get-Command -Name "Initialize-TuiFramework" -ErrorAction SilentlyContinue) {
            Initialize-TuiFramework
            if (-not $Silent) {
                Write-Host "  TUI Framework initialized" -ForegroundColor Gray
            }
        }
        
        # Initialize focus manager
        if (Get-Command -Name "Initialize-FocusManager" -ErrorAction SilentlyContinue) {
            Initialize-FocusManager
            if (-not $Silent) {
                Write-Host "  Focus Manager initialized" -ForegroundColor Gray
            }
        }
        
        # Load screens
        Initialize-PMCScreens -Silent:$Silent
        
        if (-not $Silent) {
            Write-Host "`nStarting application..." -ForegroundColor Green
        }
        
        # Clear the console completely before starting TUI
        Clear-Host
        
        # Check if demo mode is requested
        if ($args -contains "-demo") {
            if (Get-Command -Name "Get-DemoScreen" -ErrorAction SilentlyContinue) {
                $demoScreen = Get-DemoScreen
                Push-Screen -Screen $demoScreen
            }
        } else {
            # Normal startup
            if (Get-Command -Name "Get-DashboardScreen" -ErrorAction SilentlyContinue) {
                $dashboardScreen = Get-DashboardScreen
                Push-Screen -Screen $dashboardScreen
            } else {
                # Fallback welcome screen
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
        }
        
        # Start the main loop
        Start-TuiLoop
        
    } catch {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Level Error -Message "FATAL: Failed to initialize PMC Terminal" -Data $_
        }
        Write-Error "FATAL: Failed to initialize PMC Terminal: $_"
        throw
    } finally {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "PMC Terminal shutting down"
        }
        # Cleanup
        if (Get-Command -Name "Stop-TuiEngine" -ErrorAction SilentlyContinue) {
            if (-not $Silent) {
                Write-Host "`nShutting down..." -ForegroundColor Yellow
            }
            Stop-TuiEngine
        }
        
        if ($Data -and (Get-Command -Name "Save-UnifiedData" -ErrorAction SilentlyContinue)) {
            if (-not $Silent) {
                Write-Host "`nSaving data..." -ForegroundColor Yellow -NoNewline
            }
            Save-UnifiedData
            if (-not $Silent) {
                Write-Host " Done!" -ForegroundColor Green
            }
        }
        
        if (-not $Silent) {
            Write-Host "Goodbye!" -ForegroundColor Green
        }
        
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "PMC Terminal shutdown complete"
        }
    }
}

# Parse command line arguments
$script:args = $args
$script:Silent = $args -contains "-silent" -or $args -contains "-s"

try {
    Clear-Host
    Start-PMCTerminal -Silent:$script:Silent
} catch {
    Write-Error "Fatal error: $_"
    Write-Host "`nPress any key to exit..." -ForegroundColor Red
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}
