# PMC Terminal v4.2 "Helios" - Main Entry Point
# This file orchestrates module loading and application startup with the new service architecture

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$script:BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Module loading order is critical - dependencies must load first
$script:ModulesToLoad = @(
    # Core infrastructure (no dependencies)
    @{ Name = "logger"; Path = "modules\logger.psm1"; Required = $true },
    @{ Name = "event-system"; Path = "modules\event-system.psm1"; Required = $true },
    
    # Data and theme (depend on event system)
    @{ Name = "data-manager"; Path = "modules\data-manager.psm1"; Required = $true },
    @{ Name = "theme-manager"; Path = "modules\theme-manager.psm1"; Required = $true },
    
    # Framework (depends on event system)
    @{ Name = "tui-framework"; Path = "modules\tui-framework.psm1"; Required = $true },
    
    # Engine (depends on theme and framework)
    @{ Name = "tui-engine-v2"; Path = "modules\tui-engine-v2.psm1"; Required = $true },
    
    # Dialog system (depends on engine)
    @{ Name = "dialog-system"; Path = "modules\dialog-system.psm1"; Required = $true },
    
    # Services (depend on framework for state management)
    @{ Name = "app-store"; Path = "services\app-store.psm1"; Required = $true },
    @{ Name = "navigation"; Path = "services\navigation.psm1"; Required = $true },
    @{ Name = "keybindings"; Path = "services\keybindings.psm1"; Required = $true },
    
    # Layout system
    @{ Name = "layout-panels"; Path = "layout\panels.psm1"; Required = $true },
    
    # Focus management (depends on event system)
    @{ Name = "focus-manager"; Path = "utilities\focus-manager.psm1"; Required = $true },
    
    # Components (depend on engine and panels)
    @{ Name = "tui-components"; Path = "components\tui-components.psm1"; Required = $true },
    @{ Name = "advanced-input-components"; Path = "components\advanced-input-components.psm1"; Required = $false },
    @{ Name = "advanced-data-components"; Path = "components\advanced-data-components.psm1"; Required = $true }
)

# Screen modules will be loaded dynamically
$script:ScreenModules = @(
    "dashboard-screen-grid",
    "task-screen",
    "timer-start-screen",
    "project-management-screen",
    "timer-management-screen",
    "reports-screen",
    "settings-screen",
    "debug-log-screen",
    "demo-screen",
    "time-entry-screen"
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
        Write-Host "Initializing PMC Terminal v4.2 'Helios'..." -ForegroundColor Cyan
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
                Write-Host "  Failed to load $($module.Name): $_" -ForegroundColor Red
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

function Initialize-PMCServices {
    param([bool]$Silent = $false)
    
    if (-not $Silent) {
        Write-Host "Initializing services..." -ForegroundColor Cyan
    }
    
    # Create the service registry
    $services = @{}
    
    try {
        # Initialize App Store with initial data
        $initialData = if ($global:Data) { $global:Data } else { @{} }
        $services.Store = Initialize-AppStore -InitialData $initialData -EnableDebugLogging $false
        
        # Register store actions
        & $services.Store.RegisterAction -actionName "LOAD_DASHBOARD_DATA" -scriptBlock {
            param($Context)
            
            # Load quick actions
            $quickActions = @(
                @{ Action = "[Enter] Start Timer" },
                @{ Action = "[Space] Quick Timer" },
                @{ Action = "[T] Tasks" },
                @{ Action = "[P] Projects" },
                @{ Action = "[R] Reports" },
                @{ Action = "[S] Settings" }
            )
            $Context.UpdateState(@{ quickActions = $quickActions })
            
            # Calculate today's hours
            $todayHours = 0
            if ($global:Data -and $global:Data.time_entries) {
                $today = (Get-Date).Date
                $todayEntries = $global:Data.time_entries | Where-Object { 
                    [DateTime]::Parse($_.start_time).Date -eq $today 
                }
                foreach ($entry in $todayEntries) {
                    $todayHours += $entry.duration
                }
            }
            $Context.UpdateState(@{ stats = @{ todayHours = [Math]::Round($todayHours, 2) } })
        }
        
        & $services.Store.RegisterAction -actionName "TASKS_LOAD" -scriptBlock {
            param($Context)
            
            $tasks = @()
            if ($global:Data -and $global:Data.tasks) {
                $tasks = $global:Data.tasks | ForEach-Object {
                    @{
                        Status = if ($_.completed) { "✓" } else { "○" }
                        Priority = $_.priority ?? "Medium"
                        Title = $_.title ?? "Untitled"
                    }
                }
            }
            $Context.UpdateState(@{ tasks = $tasks })
        }
        
        if (-not $Silent) {
            Write-Host "  App Store initialized" -ForegroundColor Gray
        }
        
        # Initialize Navigation Service
        $services.Navigation = Initialize-NavigationService -EnableBreadcrumbs $true
        if (-not $Silent) {
            Write-Host "  Navigation Service initialized" -ForegroundColor Gray
        }
        
        # Initialize Keybinding Service
        $services.Keybindings = Initialize-KeybindingService -EnableChords $false
        
        # Register global keybinding handlers
        & $services.Keybindings.RegisterGlobalHandler -ActionName "App.Help" -Handler {
            Show-AlertDialog -Title "Help" -Message "PMC Terminal v4.2`n`nPress F1 for help`nPress Escape to go back`nPress Q to quit"
        }
        
        if (-not $Silent) {
            Write-Host "  Keybinding Service initialized" -ForegroundColor Gray
        }
        
    } catch {
        Write-Host "  Failed to initialize services: $_" -ForegroundColor Red
        throw
    }
    
    # Store services globally for backward compatibility
    $global:Services = $services
    
    return $services
}

function Start-PMCTerminal {
    param([bool]$Silent = $false)
    
    try {
        # Load modules
        $loadedModules = Initialize-PMCModules -Silent:$Silent
        
        if (-not $Silent) {
            Write-Host "`nInitializing subsystems..." -ForegroundColor Cyan
        }
        
        # Initialize logger first
        if (Get-Command Initialize-Logger -ErrorAction SilentlyContinue) {
            Initialize-Logger
            Write-Log -Level Info -Message "PMC Terminal v4.2 'Helios' startup initiated"
            Write-Log -Level Info -Message "Loaded modules: $($loadedModules -join ', ')"
        }
        
        # Initialize core systems in correct order
        Initialize-EventSystem
        Initialize-ThemeManager
        Initialize-DataManager
        Initialize-TuiFramework
        Initialize-TuiEngine
        Initialize-DialogSystem
        
        # Load application data
        Load-UnifiedData
        
        # Initialize services AFTER data is loaded
        $services = Initialize-PMCServices -Silent:$Silent
        
        # Initialize focus manager
        Initialize-FocusManager
        if (-not $Silent) {
            Write-Host "  Focus Manager initialized" -ForegroundColor Gray
        }
        
        # Load screens
        Initialize-PMCScreens -Silent:$Silent
        
        if (-not $Silent) {
            Write-Host "`nStarting application..." -ForegroundColor Green
        }
        
        # Clear the console before starting
        Clear-Host
        
        # Navigate to initial screen
        if ($args -contains "-demo" -and $services.Navigation.IsValidRoute("/demo")) {
            $services.Navigation.GoTo("/demo")
        } else {
            $services.Navigation.GoTo("/dashboard")
        }
        
        # Start the main loop
        Start-TuiLoop
        
    } catch {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Level Error -Message "FATAL: Failed to initialize PMC Terminal" -Data $_
        }
        
        # Enhanced error display
        Write-Host "`n========================================" -ForegroundColor Red
        Write-Host "FATAL ERROR DURING INITIALIZATION" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Stack Trace:" -ForegroundColor Cyan
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        
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
        
        # Save data
        if ($global:Data -and (Get-Command -Name "Save-UnifiedData" -ErrorAction SilentlyContinue)) {
            if (-not $Silent) {
                Write-Host "Saving data..." -ForegroundColor Yellow -NoNewline
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
    Write-Error "Fatal error occurred: $_"
    Write-Host "`nPress any key to exit..." -ForegroundColor Red
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}
