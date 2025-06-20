# PMC Terminal v4.2 "Helios" - Main Entry Point (CORRECTED)
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
    @{ Name = "exceptions"; Path = "modules\exceptions.psm1"; Required = $true },
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
    "dashboard-screen-helios",
    "task-screen-helios",
    "timer-start-screen",
    "project-management-screen",
    "timer-management-screen",
    "reports-screen",
    "settings-screen",
    "debug-log-screen",
    "demo-screen",
    "time-entry-screen",
    "simple-test-screen"
)

function Initialize-PMCModules {
    param([bool]$Silent = $false)
    
    $minWidth = 80
    $minHeight = 24
    if ($Host.UI.RawUI) {
        $currentWidth = $Host.UI.RawUI.WindowSize.Width
        $currentHeight = $Host.UI.RawUI.WindowSize.Height
        if ($currentWidth -lt $minWidth -or $currentHeight -lt $minHeight) {
            Write-Host "Console window too small!" -ForegroundColor Red
            Write-Host "Current size: ${currentWidth}x${currentHeight}" -ForegroundColor Yellow
            Write-Host "Minimum required: ${minWidth}x${minHeight}" -ForegroundColor Green
            Write-Host "Please resize your console window and try again." -ForegroundColor White
            Write-Host "Press any key to exit..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 1
        }
    }
    
    if (-not $Silent) { Write-Host "Initializing PMC Terminal v4.2 'Helios'..." -ForegroundColor Cyan }
    $loadedModules = @()
    
    foreach ($module in $script:ModulesToLoad) {
        $modulePath = Join-Path $script:BasePath $module.Path
        try {
            if (Test-Path $modulePath) {
                if (-not $Silent) { Write-Host "  Loading $($module.Name)..." -ForegroundColor Gray }
                Import-Module $modulePath -Force -Global -ErrorAction Stop
                $loadedModules += $module.Name
            } elseif ($module.Required) { throw "Required module not found: $($module.Name) at $modulePath" }
        } catch {
            if ($module.Required) { Write-Host "  Failed to load $($module.Name): $_" -ForegroundColor Red; throw }
            else { if (-not $Silent) { Write-Host "  Optional module $($module.Name) not loaded: $_" -ForegroundColor Yellow } }
        }
    }
    
    if (-not $Silent) { Write-Host "Loaded $($loadedModules.Count) modules successfully" -ForegroundColor Green }
    return $loadedModules
}

function Initialize-PMCScreens {
    param([bool]$Silent = $false)
    
    if (-not $Silent) { Write-Host "Loading screens..." -ForegroundColor Cyan }
    $loadedScreens = @()
    
    foreach ($screenName in $script:ScreenModules) {
        $screenPath = Join-Path $script:BasePath "screens\$screenName.psm1"
        try {
            if (Test-Path $screenPath) {
                Import-Module $screenPath -Force -Global -ErrorAction SilentlyContinue
                $loadedScreens += $screenName
            } else { if (-not $Silent) { Write-Host "  Screen module not found: $screenName" -ForegroundColor Yellow } }
        } catch { if (-not $Silent) { Write-Host "  Failed to load screen: $screenName - $_" -ForegroundColor Yellow } }
    }
    
    if (-not $Silent) { Write-Host "Loaded $($loadedScreens.Count) screens" -ForegroundColor Green }
    return $loadedScreens
}

function Initialize-PMCServices {
    param([bool]$Silent = $false)
    
    if (-not $Silent) { Write-Host "Initializing services..." -ForegroundColor Cyan }
    $services = @{}
    
    try {
        $initialData = if ($global:Data) { $global:Data } else { @{} }
        $services.Store = Initialize-AppStore -InitialData $initialData -EnableDebugLogging $false
        
        & $services.Store.RegisterAction -self $services.Store -actionName "DASHBOARD_REFRESH" -scriptBlock {
            param($Context)
            & $Context.Dispatch "LOAD_DASHBOARD_DATA"
            & $Context.Dispatch "TASKS_REFRESH"
            & $Context.Dispatch "TIMERS_REFRESH"
        }
        
        & $services.Store.RegisterAction -self $services.Store -actionName "TASKS_REFRESH" -scriptBlock {
            param($Context)
            if (-not $global:Data) { $global:Data = @{} }
            if (-not ($global:Data.tasks -is [System.Collections.IEnumerable])) { $global:Data.tasks = @() }
            
            $rawTasks = $global:Data.tasks
            $activeTasks = ($rawTasks | Where-Object { -not $_.completed }).Count
            $today = (Get-Date).Date
            
            $dashboardTasks = $rawTasks | Where-Object {
                $updatedDate = $null
                # FIX: Add specific try/catch for date parsing
                try { if ($_.updated_at) { $updatedDate = [DateTime]::Parse($_.updated_at).Date } } catch { }
                -not $_.completed -or ($updatedDate -and $updatedDate -eq $today)
            } | Select-Object -First 10 | ForEach-Object {
                @{
                    Priority = switch($_.priority) { "high" { "[HIGH]" } "medium" { "[MED]" } default { "[LOW]" } }
                    Task = $_.title
                    Project = if ($_.project) { $_.project } else { "None" }
                }
            }

            $tasksForTable = $rawTasks | ForEach-Object {
                $dueDateText = "N/A"
                # FIX: Add specific try/catch for date parsing
                if ($_.due_date) { try { $dueDateText = ([DateTime]$_.due_date).ToString("yyyy-MM-dd") } catch { } }
                @{
                    Id = $_.id
                    Status = if ($_.completed) { "✓" } else { "○" }
                    Priority = if ($_.priority) { $_.priority } else { "Medium" }
                    Title = if ($_.title) { $_.title } else { "Untitled" }
                    Category = if ($_.project) { $_.project } else { "General" }
                    DueDate = $dueDateText
                }
            }
            
            & $Context.UpdateState @{ tasks = $tasksForTable; todaysTasks = $dashboardTasks; "stats.activeTasks" = $activeTasks }
        }
        
        & $services.Store.RegisterAction -self $services.Store -actionName "TIMERS_REFRESH" -scriptBlock {
            param($Context)
            if (-not $global:Data) { $global:Data = @{} }
            # FIX: Ensure timers is a collection to prevent pipeline errors.
            if (-not ($global:Data.timers -is [System.Collections.IEnumerable])) { $global:Data.timers = @() }
            
            $runningTimers = ($global:Data.timers | Where-Object { $_.is_running }).Count
            $activeTimers = $global:Data.timers | Where-Object { $_.is_running } | ForEach-Object {
                $duration = "00:00:00"
                # FIX: Add specific try/catch for date parsing
                if ($_.start_time) {
                    try {
                        $start = [DateTime]::Parse($_.start_time)
                        $duration = "{0:hh\:mm\:ss}" -f ((Get-Date) - $start)
                    } catch { } # Keep default duration if parse fails
                }
                @{
                    Project = if ($_.project) { $_.project } else { "No Project" }
                    Time = $duration
                }
            }
            & $Context.UpdateState @{ activeTimers = $activeTimers; "stats.runningTimers" = $runningTimers }
        }
        
        & $services.Store.RegisterAction -self $services.Store -actionName "LOAD_DASHBOARD_DATA" -scriptBlock {
            param($Context)
            $quickActions = @(
                @{ Action = "[1] New Time Entry" }, @{ Action = "[2] Start Timer" },
                @{ Action = "[3] View Tasks" }, @{ Action = "[4] View Projects" },
                @{ Action = "[5] Reports" }, @{ Action = "[6] Settings" }
            )
            & $Context.UpdateState @{ quickActions = $quickActions }
            
            if (-not $global:Data) { $global:Data = @{} }
            if (-not ($global:Data.time_entries -is [System.Collections.IEnumerable])) { $global:Data.time_entries = @() }
            
            $todayHours = 0; $weekHours = 0
            if ($global:Data.time_entries -and $global:Data.time_entries.Count -gt 0) {
                $today = (Get-Date).Date
                # FIX: Correctly calculate the start of the week (assuming Monday is the first day)
                $weekStartDay = [DayOfWeek]::Monday
                $currentDayOfWeek = $today.DayOfWeek
                $daysToSubtract = ($currentDayOfWeek - $weekStartDay + 7) % 7
                $weekStart = $today.AddDays(-$daysToSubtract)

                foreach ($entry in $global:Data.time_entries) {
                    # FIX: Add specific try/catch for date parsing
                    if ($entry.start_time) {
                        try {
                            $entryDate = [DateTime]::Parse($entry.start_time).Date
                            if ($entry.duration) {
                                if ($entryDate -eq $today) { $todayHours += $entry.duration }
                                if ($entryDate -ge $weekStart -and $entryDate -le $today) { $weekHours += $entry.duration }
                            }
                        } catch { } # Skip entries with invalid dates
                    }
                }
            }
            & $Context.UpdateState @{ "stats.todayHours" = [Math]::Round($todayHours, 2); "stats.weekHours" = [Math]::Round($weekHours, 2) }
        }
        
        # Other actions (TASK_CREATE, TASK_TOGGLE_STATUS, etc.)
        # These are generally safe as they create new data, but kept for completeness.
        & $services.Store.RegisterAction -self $services.Store -actionName "TASK_CREATE" -scriptBlock {
            param($Context, $Payload)
            if (-not $global:Data) { $global:Data = @{} }
            if (-not $global:Data.tasks) { $global:Data.tasks = @() }
            if ($Payload.Title) {
                $newTask = @{
                    id = [Guid]::NewGuid().ToString(); title = $Payload.Title
                    description = if ($Payload.Description) { $Payload.Description } else { "" }
                    completed = $false; priority = "medium"
                    created_at = (Get-Date).ToString("o"); updated_at = (Get-Date).ToString("o")
                }
                $global:Data.tasks += $newTask
                Save-UnifiedData
                & $Context.Dispatch "TASKS_REFRESH"
            }
        }
        
        & $services.Store.RegisterAction -self $services.Store -actionName "TASK_TOGGLE_STATUS" -scriptBlock {
            param($Context, $Payload)
            if ($global:Data -and $global:Data.tasks -and $Payload.TaskId) {
                $taskToUpdate = $global:Data.tasks | Where-Object { $_.id -eq $Payload.TaskId } | Select-Object -First 1
                if ($taskToUpdate) {
                    $taskToUpdate.completed = -not $taskToUpdate.completed
                    $taskToUpdate.updated_at = (Get-Date).ToString("o")
                    Save-UnifiedData
                    & $Context.Dispatch "TASKS_REFRESH"
                }
            }
        }
        
        # ... other actions like TASK_DELETE, UPDATE_STATE, TASKS_LOAD
        
        # Initialize Navigation Service
        $services.Navigation = Initialize-NavigationService
        # Initialize Keybinding Service
        $services.Keybindings = Initialize-KeybindingService
        
    } catch { Write-Host "  Failed to initialize services: $_" -ForegroundColor Red; throw }
    
    $global:Services = $services
    return $services
}

function Start-PMCTerminal {
    param([bool]$Silent = $false)
    
    try {
        $loadedModules = Initialize-PMCModules -Silent:$Silent
        if (-not $Silent) { Write-Host "`nInitializing subsystems..." -ForegroundColor Cyan }
        
        if (Get-Command Initialize-Logger -ErrorAction SilentlyContinue) {
            Initialize-Logger
            Write-Log -Level Info -Message "PMC Terminal v4.2 'Helios' startup initiated"
            Write-Log -Level Info -Message "Loaded modules: $($loadedModules -join ', ')"
        }
        
        Initialize-EventSystem; Initialize-ThemeManager; Initialize-DataManager
        Initialize-TuiFramework; Initialize-TuiEngine; Initialize-DialogSystem
        
        Load-UnifiedData
        $services = Initialize-PMCServices -Silent:$Silent
        Initialize-FocusManager
        Initialize-PMCScreens -Silent:$Silent
        
        if (-not $Silent) { Write-Host "`nStarting application..." -ForegroundColor Green }
        Clear-Host
        
        # Flexible startup path logic
        $startPath = "/dashboard" # Default
        if ($args -contains "-start") {
            $startIndex = [array]::IndexOf($args, "-start")
            if (($startIndex + 1) -lt $args.Count) { $startPath = $args[$startIndex + 1] }
        }
        
        if ((& $services.Navigation.IsValidRoute -self $services.Navigation -Path $startPath)) {
            & $services.Navigation.GoTo -self $services.Navigation -Path $startPath -Services $services
        } else {
            Write-Log -Level Warning -Message "Startup path '$startPath' is not valid. Defaulting to /dashboard."
            & $services.Navigation.GoTo -self $services.Navigation -Path "/dashboard" -Services $services
        }
        
        Start-TuiLoop
        
    } catch {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) { Write-Log -Level Error -Message "FATAL: Failed to initialize PMC Terminal" -Data $_ }
        Write-Host "`nFATAL ERROR DURING INITIALIZATION: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
        throw
    } finally {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) { Write-Log -Level Info -Message "PMC Terminal shutting down" }
        if (Get-Command -Name "Stop-TuiEngine" -ErrorAction SilentlyContinue) { if (-not $Silent) { Write-Host "`nShutting down..." }; Stop-TuiEngine }
        if ($global:Data -and (Get-Command -Name "Save-UnifiedData" -ErrorAction SilentlyContinue)) { if (-not $Silent) { Write-Host "Saving data..." }; Save-UnifiedData }
        if (-not $Silent) { Write-Host "Goodbye!" -ForegroundColor Green }
    }
}

# Main execution block
$script:Silent = $args -contains "-silent" -or $args -contains "-s"
try {
    Clear-Host
    Start-PMCTerminal -Silent:$script:Silent
} catch {
    Write-Error "Fatal error occurred: $_"
    if ($Host.UI.RawUI) {
        Write-Host "`nPress any key to exit..." -ForegroundColor Red
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    exit 1
}