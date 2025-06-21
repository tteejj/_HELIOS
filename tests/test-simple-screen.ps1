# Test the simple test screen
param(
    [switch]$Direct = $false
)

# Get the directory where this script is located
$script:BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($Direct) {
    # Direct test - load only necessary modules and test the screen
    Write-Host "Direct Test Mode - Loading minimal modules..." -ForegroundColor Cyan
    
    # Load required modules
    $modules = @(
        "modules\logger.psm1",
        "modules\event-system.psm1",
        "modules\data-manager.psm1",
        "modules\theme-manager.psm1",
        "modules\tui-framework.psm1",
        "modules\tui-engine-v2.psm1",
        "modules\dialog-system.psm1",
        "services\app-store.psm1",
        "services\navigation.psm1",
        "services\keybindings.psm1",
        "layout\panels.psm1",
        "utilities\focus-manager.psm1",
        "components\tui-components.psm1",
        "components\advanced-data-components.psm1",
        "screens\simple-test-screen.psm1"
    )
    
    foreach ($module in $modules) {
        $path = Join-Path $script:BasePath $module
        if (Test-Path $path) {
            Import-Module $path -Force -Global
        } else {
            Write-Host "Module not found: $module" -ForegroundColor Red
        }
    }
    
    # Initialize systems
    Initialize-Logger
    Initialize-EventSystem
    Initialize-ThemeManager
    Initialize-DataManager
    Initialize-TuiFramework
    Initialize-TuiEngine
    Initialize-DialogSystem
    Initialize-FocusManager
    
    # Create minimal services
    $services = @{
        Store = Initialize-AppStore -InitialData @{} -EnableDebugLogging $true
        Navigation = Initialize-NavigationService
        Keybindings = Initialize-KeybindingService
    }
    
    Write-Host "Creating test screen..." -ForegroundColor Yellow
    $screen = Get-SimpleTestScreen -Services $services
    
    if ($screen) {
        Write-Host "Screen created successfully" -ForegroundColor Green
        
        # Initialize the screen
        if ($screen.Init) {
            & $screen.Init -self $screen -services $services
        }
        
        # Push to screen stack
        Push-Screen -Screen $screen
        
        # Start the TUI loop
        Write-Host "Starting TUI loop..." -ForegroundColor Yellow
        Start-TuiLoop
    } else {
        Write-Host "Failed to create screen" -ForegroundColor Red
    }
} else {
    # Full application test - modify main-helios.ps1 to start with test screen
    Write-Host "Full Application Test Mode" -ForegroundColor Cyan
    Write-Host "Starting PMC Terminal and navigating to /test..." -ForegroundColor Yellow
    
    # Create a temporary script that modifies the startup behavior
    $tempScript = @'
# Load main-helios.ps1 functions
. ".\main-helios.ps1"

# Override Start-PMCTerminal to navigate to /test
$originalStart = Get-Command Start-PMCTerminal
$originalDef = $originalStart.Definition

# Create new function that navigates to /test
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
            Write-Log -Level Info -Message "PMC Terminal v4.2 'Helios' TEST MODE"
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
            Write-Host "`nStarting application in TEST MODE..." -ForegroundColor Magenta
        }
        
        # Clear the console before starting
        Clear-Host
        
        # Navigate to TEST screen instead of dashboard
        Write-Host "Navigating to /test..." -ForegroundColor Yellow
        & $services.Navigation.GoTo -self $services.Navigation -Path "/test" -Services $services
        
        # Start the main loop
        Start-TuiLoop
        
    } catch {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Level Error -Message "FATAL: Failed to initialize PMC Terminal" -Data $_
        }
        
        Write-Host "`nERROR: $_" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
        
        throw
    } finally {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "PMC Terminal TEST MODE shutting down"
        }
        
        # Cleanup
        if (Get-Command -Name "Stop-TuiEngine" -ErrorAction SilentlyContinue) {
            if (-not $Silent) {
                Write-Host "`nShutting down..." -ForegroundColor Yellow
            }
            Stop-TuiEngine
        }
    }
}

# Start the application
Clear-Host
Start-PMCTerminal
'@
    
    # Execute the modified startup
    Invoke-Expression $tempScript
}

Write-Host "`nTest completed." -ForegroundColor Green