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
    "dashboard-screen-helios",
    "task-screen-helios",
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
        
        # Register store actions using the v3.0 call pattern
        & $services.Store.RegisterAction -self $services.Store -actionName "LOAD_DASHBOARD_DATA" -scriptBlock {
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
        
        & $services.Store.RegisterAction -self $services.Store -actionName "TASKS_LOAD" -scriptBlock {
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
        
        # Register TASKS_REFRESH action
        & $services.Store.RegisterAction -self $services.Store -actionName "TASKS_REFRESH" -scriptBlock {
            param($Context)

            $filter = & $Context.GetState -path "taskFilter" ?? "all"
            $sort = & $Context.GetState -path "taskSort" ?? "priority"

            $tasks = @()
            if ($global:Data -and $global:Data.tasks) {
                $tasks = $global:Data.tasks
            }

            $filtered = switch ($filter) {
                "active"    { $tasks | Where-Object { -not $_.completed } }
                "completed" { $tasks | Where-Object { $_.completed } }
                default     { $tasks }
            }

            $sorted = switch ($sort) {
                "priority" {
                    $filtered | Sort-Object @{
                        Expression = {
                            switch ($_.priority) {
                                "Critical" { 0 }; "High" { 1 }; "Medium" { 2 }; "Low" { 3 }; default { 4 }
                            }
                        }
                    }, created
                }
                "dueDate" { $filtered | Sort-Object dueDate, priority }
                "created" { $filtered | Sort-Object created -Descending }
                default   { $filtered }
            }

            $displayTasks = @($sorted | ForEach-Object {
                @{
                    Id       = $_.id ?? [Guid]::NewGuid().ToString()
                    Status   = if ($_.completed) { "✓" } else { " " }
                    Priority = $_.priority ?? "Medium"
                    Title    = $_.title ?? "Untitled"
                    Category = $_.category ?? "General"
                    DueDate  = if ($_.dueDate) {
                                    try { [DateTime]::Parse($_.dueDate).ToString("yyyy-MM-dd") }
                                    catch { $_.dueDate }
                                } else { "" }
                }
            })
            $Context.UpdateState(@{ tasks = $displayTasks })
        }

        # Register TASK_TOGGLE_STATUS action
        & $services.Store.RegisterAction -self $services.Store -actionName "TASK_TOGGLE_STATUS" -scriptBlock {
            param($Context, $Payload)

            if ($global:Data -and $global:Data.tasks -and $Payload.TaskId) {
                $task = $global:Data.tasks | Where-Object { $_.id -eq $Payload.TaskId }
                if ($task) {
                    $task.completed = -not $task.completed
                    $task.completedDate = if ($task.completed) { (Get-Date).ToString("o") } else { $null }
                    Save-UnifiedData
                    & $Context.Dispatch -actionName "TASKS_REFRESH"
                }
            }
        }

        # Register TASK_CREATE action
        & $services.Store.RegisterAction -self $services.Store -actionName "TASK_CREATE" -scriptBlock {
            param($Context, $Payload)

            if (-not $global:Data) { $global:Data = @{} }
            if (-not $global:Data.tasks) { $global:Data.tasks = @() }

            $newTask = @{
                id          = [Guid]::NewGuid().ToString()
                title       = $Payload.Title
                description = $Payload.Description
                category    = $Payload.Category
                priority    = $Payload.Priority
                dueDate     = $Payload.DueDate
                created     = (Get-Date).ToString("o")
                completed   = $false
                completedDate = $null
            }
            $global:Data.tasks += $newTask
            Save-UnifiedData
            & $Context.Dispatch -actionName "TASKS_REFRESH"
        }

        # Register TASK_UPDATE action
        & $services.Store.RegisterAction -self $services.Store -actionName "TASK_UPDATE" -scriptBlock {
            param($Context, $Payload)

            if ($global:Data -and $global:Data.tasks -and $Payload.TaskId) {
                $task = $global:Data.tasks | Where-Object { $_.id -eq $Payload.TaskId }
                if ($task) {
                    $task.title       = $Payload.Title
                    $task.description = $Payload.Description
                    $task.category    = $Payload.Category
                    $task.priority    = $Payload.Priority
                    $task.dueDate     = $Payload.DueDate
                    Save-UnifiedData
                    & $Context.Dispatch -actionName "TASKS_REFRESH"
                }
            }
        }

        # Register TASK_DELETE action
        & $services.Store.RegisterAction -self $services.Store -actionName "TASK_DELETE" -scriptBlock {
            param($Context, $Payload)

            if ($global:Data -and $global:Data.tasks -and $Payload.TaskId) {
                $global:Data.tasks = @($global:Data.tasks | Where-Object { $_.id -ne $Payload.TaskId })
                Save-UnifiedData
                & $Context.Dispatch -actionName "TASKS_REFRESH"
            }
        }

        # Register DASHBOARD_REFRESH action
        & $services.Store.RegisterAction -self $services.Store -actionName "DASHBOARD_REFRESH" -scriptBlock {
            param($Context)

            # Quick Actions
            $quickActions = @(
                @{ Action = "1. Add Time Entry" },
                @{ Action = "2. Start Timer" },
                @{ Action = "3. Manage Tasks" },
                @{ Action = "4. Manage Projects" },
                @{ Action = "5. View Reports" },
                @{ Action = "6. Settings" }
            )
            $Context.UpdateState(@{ quickActions = $quickActions })

            # Active Timers
            $timerData = @()
            $storeActiveTimers = $Context.GetState('active_timers')
            $storeProjects = $Context.GetState('projects')
            if ($storeActiveTimers) {
                foreach ($timerEntry in $storeActiveTimers.GetEnumerator()) {
                    $timer = $timerEntry.Value
                    if ($timer -and $timer.start_time) {
                        $elapsed = (Get-Date) - [DateTime]$timer.start_time
                        $project = if ($storeProjects -and $timer.project_key -and $storeProjects.ContainsKey($timer.project_key)) {
                            $storeProjects[$timer.project_key].name
                        } else {
                            "Unknown"
                        }

                        $timerData += @{
                            Project = $project
                            Time = "{0:00}:{1:00}:{2:00}" -f [Math]::Floor($elapsed.TotalHours), $elapsed.Minutes, $elapsed.Seconds
                        }
                    }
                }
            }
            $Context.UpdateState(@{ activeTimers = $timerData })

            # Today's Tasks
            $taskData = @()
            $storeTasks = $Context.GetState('tasks')
            if ($storeTasks) {
                $today = (Get-Date).ToString("yyyy-MM-dd")
                foreach ($task in $storeTasks) {
                    if ($task -and -not $task.completed -and ($task.due_date -eq $today -or [string]::IsNullOrEmpty($task.due_date))) {
                        $project = if ($storeProjects -and $task.project_key -and $storeProjects.ContainsKey($task.project_key)) {
                            $storeProjects[$task.project_key].name
                        } else {
                            "None"
                        }

                        $taskData += @{
                            Priority = $task.priority ?? "Medium"
                            Task = $task.description ?? $task.title ?? "Untitled"
                            Project = $project
                        }
                    }
                }
            }
            $Context.UpdateState(@{ todaysTasks = $taskData })

            # Calculate Stats
            $stats = @{
                todayHours = 0
                weekHours = 0
                activeTasks = 0
                runningTimers = 0
            }

            $storeTimeEntries = $Context.GetState('time_entries')
            if ($storeTimeEntries) {
                $today = (Get-Date).ToString("yyyy-MM-dd")

                $todayEntries = @($storeTimeEntries | Where-Object { $_ -and $_.date -eq $today })
                $stats.todayHours = [Math]::Round(($todayEntries | Measure-Object -Property hours -Sum).Sum, 2)

                $weekStart = (Get-Date).AddDays(-[int](Get-Date).DayOfWeek).Date
                $weekEntries = @($storeTimeEntries | Where-Object {
                    $_ -and $_.date -and ([DateTime]::Parse($_.date) -ge $weekStart)
                })
                $stats.weekHours = [Math]::Round(($weekEntries | Measure-Object -Property hours -Sum).Sum, 2)
            }

            if ($storeTasks) {
                $stats.activeTasks = @($storeTasks | Where-Object { $_ -and -not $_.completed }).Count
            }

            if ($storeActiveTimers) {
                $stats.runningTimers = $storeActiveTimers.Count
            }

            $Context.UpdateState(@{ stats = $stats })
        }

        & $services.Store.RegisterAction -self $services.Store -actionName "CREATE_TIME_ENTRY" -scriptBlock {
            param($Context, $Payload) # Payload is $timeEntry
            if (-not $global:Data) { $global:Data = @{} }
            if (-not $global:Data.TimeEntries) { $global:Data.TimeEntries = @() }
            $global:Data.TimeEntries += $Payload
            Save-UnifiedData
            # Optionally, dispatch a refresh action if needed, e.g., for a list of time entries
            # & $Context.Dispatch -actionName "TIME_ENTRIES_REFRESH"
        }

        & $services.Store.RegisterAction -self $services.Store -actionName "START_TIMER" -scriptBlock {
            param($Context, $Payload) # Payload is $timer
            if (-not $global:Data) { $global:Data = @{} }
            if (-not $global:Data.ActiveTimers) { $global:Data.ActiveTimers = @{} }
            $global:Data.ActiveTimers[$Payload.Id] = $Payload
            Save-UnifiedData
            # Optionally, dispatch actions to update UI, e.g., active timer display
            # & $Context.Dispatch -actionName "ACTIVE_TIMERS_UPDATED"
        }

        & $services.Store.RegisterAction -self $services.Store -actionName "STOP_TIMER_AND_CREATE_ENTRY" -scriptBlock {
            param($Context, $Payload) # Payload is { TimeEntry = $timeEntry, TimerIdToRemove = $timerId }
            if (-not $global:Data) { $global:Data = @{} }
            if (-not $global:Data.TimeEntries) { $global:Data.TimeEntries = @() }
            if (-not $global:Data.ActiveTimers) { $global:Data.ActiveTimers = @{} }

            $global:Data.TimeEntries += $Payload.TimeEntry
            $global:Data.ActiveTimers.Remove($Payload.TimerIdToRemove) | Out-Null
            Save-UnifiedData
            # Optionally, dispatch actions to update UI
            # & $Context.Dispatch -actionName "TIME_ENTRIES_REFRESH"
            # & $Context.Dispatch -actionName "ACTIVE_TIMERS_UPDATED"
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
        
        # Register global keybinding handlers using the v3.0 call pattern
        & $services.Keybindings.RegisterGlobalHandler -self $services.Keybindings -ActionName "App.Help" -Handler {
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
    # $global:Services = $services # This line is now removed
    
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
        if ($args -contains "-demo" -and (& $services.Navigation.IsValidRoute -self $services.Navigation -Path "/demo")) {
            & $services.Navigation.GoTo -self $services.Navigation -Path "/demo" -Services $services
        } else {
            & $services.Navigation.GoTo -self $services.Navigation -Path "/dashboard" -Services $services
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