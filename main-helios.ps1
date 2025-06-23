# PMC Terminal v4.2 "Helios" - Main Entry Point (FIXED WITH PROPER ERROR HANDLING)
# This file orchestrates module loading and application startup with the new service architecture

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$script:BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Module loading order is critical - dependencies must load first
# FIX: Logger and Exceptions are now pre-loaded in the main execution block to ensure
# tracing and error handling are available immediately.
$script:ModulesToLoad = @(
    # Core infrastructure (no dependencies)
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
"time-entry-screen-helios",
"simple-test-screen"
)

function Initialize-PMCModules {
    param([bool]$Silent = $false)
    
    Trace-FunctionEntry -FunctionName "Initialize-PMCModules" -Parameters @{ Silent = $Silent }
    
    return Invoke-WithErrorHandling -Component "ModuleLoader" -OperationName "Initialize-PMCModules" -ScriptBlock {
        Trace-Step -StepName "Checking console window size"
        $minWidth = 80
        $minHeight = 24
        if ($Host.UI.RawUI) {
            $currentWidth = $Host.UI.RawUI.WindowSize.Width
            $currentHeight = $Host.UI.RawUI.WindowSize.Height
            Trace-Step -StepName "Console size check" -StepData @{
                CurrentWidth = $currentWidth
                CurrentHeight = $currentHeight
                MinWidth = $minWidth
                MinHeight = $minHeight
            }
            
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
        Trace-Step -StepName "Starting module loading sequence" -StepData @{
            TotalModules = $script:ModulesToLoad.Count
            BasePath = $script:BasePath
        }
        
        $loadedModules = @()
        
        foreach ($module in $script:ModulesToLoad) {
            $modulePath = Join-Path $script:BasePath $module.Path
            Trace-Step -StepName "Processing module" -StepData @{
                ModuleName = $module.Name
                ModulePath = $modulePath
                Required = $module.Required
                PathExists = Test-Path $modulePath
            }
            
            try {
                if (Test-Path $modulePath) {
                    if (-not $Silent) { Write-Host "  Loading $($module.Name)..." -ForegroundColor Gray }
                    
                    Trace-Step -StepName "Importing module" -StepData @{
                        ModuleName = $module.Name
                        Action = "Import-Module"
                    }
                    
                    Import-Module $modulePath -Force -Global -ErrorAction Stop
                    $loadedModules += $module.Name
                    
                    Trace-Step -StepName "Module loaded successfully" -StepData @{
                        ModuleName = $module.Name
                        LoadedCount = $loadedModules.Count
                    }
                    
                } elseif ($module.Required) { 
                    $errorMsg = "Required module not found: $($module.Name) at $modulePath"
                    Write-Log -Level Error -Message $errorMsg -Force
                    throw $errorMsg
                }
            } catch {
                $errorMsg = "Failed to load module $($module.Name): $_"
                Write-Log -Level Error -Message $errorMsg -Data @{
                    ModuleName = $module.Name
                    ModulePath = $modulePath
                    Required = $module.Required
                    Exception = $_.Exception.Message
                } -Force
                
                if ($module.Required) { 
                    Write-Host "  $errorMsg" -ForegroundColor Red
                    throw 
                } else { 
                    if (-not $Silent) { Write-Host "  Optional module $($module.Name) not loaded: $_" -ForegroundColor Yellow } 
                }
            }
        }
        
        if (-not $Silent) { Write-Host "Loaded $($loadedModules.Count) modules successfully" -ForegroundColor Green }
        
        Trace-Step -StepName "Module loading completed" -StepData @{
            LoadedModules = $loadedModules
            LoadedCount = $loadedModules.Count
            TotalAttempted = $script:ModulesToLoad.Count
        }
        
        Trace-FunctionExit -FunctionName "Initialize-PMCModules" -ReturnValue @{
            LoadedCount = $loadedModules.Count
            LoadedModules = $loadedModules
        }
        
        return $loadedModules
    }
}

function Initialize-PMCScreens {
    param([bool]$Silent = $false)
    
    Trace-FunctionEntry -FunctionName "Initialize-PMCScreens" -Parameters @{ Silent = $Silent }
    
    return Invoke-WithErrorHandling -Component "ScreenLoader" -OperationName "Initialize-PMCScreens" -ScriptBlock {
        if (-not $Silent) { Write-Host "Loading screens..." -ForegroundColor Cyan }
        
        Trace-Step -StepName "Starting screen loading sequence" -StepData @{
            TotalScreens = $script:ScreenModules.Count
            BasePath = $script:BasePath
            ScreenModules = $script:ScreenModules
        }
        
        $loadedScreens = @()
        
        foreach ($screenName in $script:ScreenModules) {
            $screenPath = Join-Path $script:BasePath "screens\$screenName.psm1"
            
            Trace-Step -StepName "Processing screen module" -StepData @{
                ScreenName = $screenName
                ScreenPath = $screenPath
                PathExists = Test-Path $screenPath
            }
            
            try {
                if (Test-Path $screenPath) {
                    if (-not $Silent) { Write-Host "  Loading $($screenName)..." -ForegroundColor Gray }
                    Trace-Step -StepName "Importing screen module" -StepData @{
                        ScreenName = $screenName
                        Action = "Import-Module"
                    }
                    
                    # FIX: Removed -LiteralPath for broader PowerShell compatibility.
                    # The previous issue was due to string concatenation, not the path itself.
                    Import-Module $screenPath -Force -Global -ErrorAction SilentlyContinue
                    $loadedScreens += $screenName
                    
                    Trace-Step -StepName "Screen module loaded successfully" -StepData @{
                        ScreenName = $screenName
                        LoadedCount = $loadedScreens.Count
                    }
                    
                    # Verify the screen module exported its expected functions
                    $expectedFunctions = @()
                    switch ($screenName) {
                        "dashboard-screen-helios" { $expectedFunctions = @("Get-DashboardScreen") }
                        "task-screen-helios" { $expectedFunctions = @("Get-TaskManagementScreen", "Get-TaskScreen") }
                        "simple-test-screen" { $expectedFunctions = @("Get-SimpleTestScreen") }
                        default { 
                            # For other screens, ensure the function name is correctly formed without spaces.
                            # Fixed: Proper grouping of ForEach-Object pipeline
                            $functionName = "Get-" + ((($screenName -split "-") | ForEach-Object { 
                                $_.Substring(0,1).ToUpper() + $_.Substring(1) 
                            }) -join "")
                            $expectedFunctions = @($functionName)
                        }
                    }
                    
                    foreach ($funcName in $expectedFunctions) {
                        $funcExists = Get-Command $funcName -ErrorAction SilentlyContinue
                        Trace-Step -StepName "Verifying screen function" -StepData @{
                            ScreenName = $screenName
                            FunctionName = $funcName
                            FunctionExists = ($null -ne $funcExists)
                        }
                        
                        if (-not $funcExists) {
                            Write-Log -Level Warning -Message "Expected function '$funcName' not found for screen '$screenName'"
                        }
                    }
                    
                } else { 
                    if (-not $Silent) { 
                        Write-Host "  Screen module not found: $screenName" -ForegroundColor Yellow 
                    }
                    
                    Trace-Step -StepName "Screen module file not found" -StepData @{
                        ScreenName = $screenName
                        ExpectedPath = $screenPath
                    }
                }
            } catch { 
                if (-not $Silent) { 
                    Write-Host "  Failed to load screen: $screenName - $_" -ForegroundColor Yellow 
                }
                
                Write-Log -Level Warning -Message "Failed to load screen module" -Data @{
                    ScreenName = $screenName
                    ScreenPath = $screenPath
                    Exception = $_.Exception.Message
                    StackTrace = $_.Exception.StackTrace
                }
                
                Trace-Step -StepName "Screen module loading failed" -StepData @{
                    ScreenName = $screenName
                    Error = $_.Exception.Message
                }
            }
        }
        
        if (-not $Silent) { Write-Host "Loaded $($loadedScreens.Count) screens" -ForegroundColor Green }
        
        Trace-Step -StepName "Screen loading completed" -StepData @{
            LoadedScreens = $loadedScreens
            LoadedCount = $loadedScreens.Count
            TotalAttempted = $script:ScreenModules.Count
            SuccessRate = if ($script:ScreenModules.Count -gt 0) { 
                [Math]::Round(($loadedScreens.Count / $script:ScreenModules.Count) * 100, 1) 
            } else { 0 }
        }
        
        Trace-FunctionExit -FunctionName "Initialize-PMCScreens" -ReturnValue @{
            LoadedCount = $loadedScreens.Count
            LoadedScreens = $loadedScreens
        }
        
        return $loadedScreens
    }
}

function Initialize-PMCServices {
    param([bool]$Silent = $false)
    
    Trace-FunctionEntry -FunctionName "Initialize-PMCServices" -Parameters @{ Silent = $Silent }
    
    return Invoke-WithErrorHandling -Component "ServiceInitializer" -OperationName "Initialize-PMCServices" -ScriptBlock {
        if (-not $Silent) { Write-Host "Initializing services..." -ForegroundColor Cyan }
        
        Trace-Step -StepName "Starting service initialization" -StepData @{
            GlobalDataExists = ($null -ne $global:Data)
            GlobalDataType = if ($global:Data) { $global:Data.GetType().Name } else { "null" }
        }
        
        $services = @{}
        
        # Initialize AppStore with defensive checks
        $initialData = @{}
        if ($global:Data) { 
            $initialData = $global:Data 
        } else {
            # Initialize with safe empty structures
            $global:Data = @{
                Tasks = @()
                Projects = @{}
                TimeEntries = @()
                ActiveTimers = @{}
                Settings = @{ Theme = "Modern" }
            }
            $initialData = $global:Data
        }
        
        Trace-Step -StepName "Initializing AppStore" -StepData @{
            InitialDataAvailable = ($null -ne $initialData)
        }
        
        $services.Store = Initialize-AppStore -InitialData $initialData -EnableDebugLogging $false
        
        Trace-Step -StepName "AppStore initialized" -StepData @{
            StoreType = $services.Store.GetType().Name
            StoreKeys = if ($services.Store -is [hashtable]) { $services.Store.Keys } else { "N/A" }
        }
        
        # SIMPLIFIED DASHBOARD_REFRESH - Just navigation, no data loading
        Trace-Step -StepName "Registering DASHBOARD_REFRESH action"
        & $services.Store.RegisterAction -self $services.Store -actionName "DASHBOARD_REFRESH" -scriptBlock {
            param($Context)
            Write-Log -Level Info -Message "DASHBOARD_REFRESH: Simplified version (navigation only)"
            # No data loading needed for navigation-only dashboard
        }
        
        # DEFENSIVE TASKS_REFRESH with extreme null checking
        Trace-Step -StepName "Registering TASKS_REFRESH action"
        & $services.Store.RegisterAction -self $services.Store -actionName "TASKS_REFRESH" -scriptBlock {
            param($Context)
            try {
                # Initialize if needed
                if (-not $global:Data) { $global:Data = @{} }
                if (-not $global:Data.ContainsKey('Tasks')) { $global:Data.Tasks = @() }
                
                # Force array type
                $rawTasks = @()
                if ($global:Data.Tasks) {
                    $rawTasks = @($global:Data.Tasks)
                }
                
                # Safe count
                $totalCount = 0
                if ($rawTasks) { $totalCount = @($rawTasks).Count }
                
                Write-Log -Level Debug -Message "TASKS_REFRESH: Processing $totalCount tasks"
                
                # Count active tasks with defensive filtering
                $activeTasks = 0
                if ($totalCount -gt 0) {
                    $filtered = @($rawTasks | Where-Object { 
                        $_ -and $_.ContainsKey('completed') -and (-not $_.completed) 
                    })
                    $activeTasks = $filtered.Count
                }
                
                # Build tasks for table display with extreme defensive checks
                $tasksForTable = @()
                if ($totalCount -gt 0) {
                    foreach ($task in $rawTasks) {
                        if (-not $task) { continue }
                        
                        # Safe property access with defaults
                        $taskItem = @{
                            Id = if ($task.ContainsKey('id')) { $task.id } else { [Guid]::NewGuid().ToString() }
                            Status = if ($task.ContainsKey('completed') -and $task.completed) { "✓" } else { "○" }
                            Priority = if ($task.ContainsKey('priority')) { $task.priority } else { "medium" }
                            Title = if ($task.ContainsKey('title')) { $task.title } else { "Untitled" }
                            Category = if ($task.ContainsKey('project')) { $task.project } else { "General" }
                            DueDate = "N/A"
                        }
                        
                        # Safe date parsing
                        if ($task.ContainsKey('due_date') -and $task.due_date) {
                            try {
                                $taskItem.DueDate = ([DateTime]$task.due_date).ToString("yyyy-MM-dd")
                            } catch {
                                $taskItem.DueDate = "Invalid"
                            }
                        }
                        
                        $tasksForTable += $taskItem
                    }
                }
                
                # Ensure array type for state update
                $tasksForTable = @($tasksForTable)
                
                Write-Log -Level Debug -Message "TASKS_REFRESH: Updating state with $($tasksForTable.Count) tasks"
                
                # Update state with defensive checks
                & $Context.UpdateState @{ 
                    tasks = $tasksForTable
                    "stats.activeTasks" = $activeTasks 
                }
                
            } catch {
                Write-Log -Level Error -Message "TASKS_REFRESH failed: $_" -Data @{
                    Exception = $_.Exception.Message
                    StackTrace = $_.Exception.StackTrace
                }
            }
        }
        
        # TASK_CREATE with defensive validation
        & $services.Store.RegisterAction -self $services.Store -actionName "TASK_CREATE" -scriptBlock {
            param($Context, $Payload)
            try {
                # Validate payload
                if (-not $Payload) {
                    Write-Log -Level Warning -Message "TASK_CREATE: No payload provided"
                    return
                }
                
                if (-not $Payload.Title -or [string]::IsNullOrWhiteSpace($Payload.Title)) {
                    Write-Log -Level Warning -Message "TASK_CREATE: No title provided"
                    return
                }
                
                # Initialize if needed
                if (-not $global:Data) { $global:Data = @{} }
                if (-not $global:Data.ContainsKey('Tasks')) { $global:Data.Tasks = @() }
                
                # Create new task with all required fields
                $newTask = @{
                    id = [Guid]::NewGuid().ToString()
                    title = $Payload.Title.Trim()
                    description = if ($Payload.Description) { $Payload.Description } else { "" }
                    completed = $false
                    priority = if ($Payload.Priority) { $Payload.Priority } else { "medium" }
                    project = if ($Payload.Category) { $Payload.Category } else { "General" }
                    due_date = if ($Payload.DueDate) { $Payload.DueDate } else { $null }
                    created_at = (Get-Date).ToString("o")
                    updated_at = (Get-Date).ToString("o")
                }
                
                # Add to tasks array
                $global:Data.Tasks = @($global:Data.Tasks) + $newTask
                
                Write-Log -Level Info -Message "TASK_CREATE: Created task '$($newTask.title)' with ID $($newTask.id)"
                
                # Save data
                if (Get-Command Save-UnifiedData -ErrorAction SilentlyContinue) {
                    Save-UnifiedData
                }
                
                # Refresh tasks
                & $Context.Dispatch "TASKS_REFRESH"
                
            } catch {
                Write-Log -Level Error -Message "TASK_CREATE failed: $_" -Data @{
                    Exception = $_.Exception.Message
                    Payload = $Payload
                }
            }
        }
        
        # TASK_UPDATE with defensive validation
        & $services.Store.RegisterAction -self $services.Store -actionName "TASK_UPDATE" -scriptBlock {
            param($Context, $Payload)
            try {
                if (-not $Payload -or -not $Payload.TaskId) {
                    Write-Log -Level Warning -Message "TASK_UPDATE: No TaskId provided"
                    return
                }
                
                if (-not $global:Data -or -not $global:Data.Tasks) {
                    Write-Log -Level Warning -Message "TASK_UPDATE: No tasks found"
                    return
                }
                
                # Find task safely
                $taskIndex = -1
                $tasks = @($global:Data.Tasks)
                for ($i = 0; $i -lt $tasks.Count; $i++) {
                    if ($tasks[$i] -and $tasks[$i].id -eq $Payload.TaskId) {
                        $taskIndex = $i
                        break
                    }
                }
                
                if ($taskIndex -eq -1) {
                    Write-Log -Level Warning -Message "TASK_UPDATE: Task not found with ID $($Payload.TaskId)"
                    return
                }
                
                # Update task fields
                $task = $tasks[$taskIndex]
                if ($Payload.ContainsKey('Title') -and $Payload.Title) { $task.title = $Payload.Title.Trim() }
                if ($Payload.ContainsKey('Description')) { $task.description = $Payload.Description }
                if ($Payload.ContainsKey('Priority')) { $task.priority = $Payload.Priority }
                if ($Payload.ContainsKey('Category')) { $task.project = $Payload.Category }
                if ($Payload.ContainsKey('DueDate')) { $task.due_date = $Payload.DueDate }
                if ($Payload.ContainsKey('Completed')) { $task.completed = $Payload.Completed }
                
                $task.updated_at = (Get-Date).ToString("o")
                
                Write-Log -Level Info -Message "TASK_UPDATE: Updated task $($Payload.TaskId)"
                
                # Save data
                if (Get-Command Save-UnifiedData -ErrorAction SilentlyContinue) {
                    Save-UnifiedData
                }
                
                # Refresh tasks
                & $Context.Dispatch "TASKS_REFRESH"
                
            } catch {
                Write-Log -Level Error -Message "TASK_UPDATE failed: $_" -Data @{
                    Exception = $_.Exception.Message
                    Payload = $Payload
                }
            }
        }
        
        # TASK_DELETE with defensive validation
        & $services.Store.RegisterAction -self $services.Store -actionName "TASK_DELETE" -scriptBlock {
            param($Context, $Payload)
            try {
                if (-not $Payload -or -not $Payload.TaskId) {
                    Write-Log -Level Warning -Message "TASK_DELETE: No TaskId provided"
                    return
                }
                
                if (-not $global:Data -or -not $global:Data.Tasks) {
                    Write-Log -Level Warning -Message "TASK_DELETE: No tasks found"
                    return
                }
                
                # Filter out the task safely
                $originalCount = @($global:Data.Tasks).Count
                $global:Data.Tasks = @($global:Data.Tasks | Where-Object { 
                    $_ -and $_.id -ne $Payload.TaskId 
                })
                $newCount = @($global:Data.Tasks).Count
                
                if ($newCount -lt $originalCount) {
                    Write-Log -Level Info -Message "TASK_DELETE: Deleted task $($Payload.TaskId)"
                    
                    # Save data
                    if (Get-Command Save-UnifiedData -ErrorAction SilentlyContinue) {
                        Save-UnifiedData
                    }
                    
                    # Refresh tasks
                    & $Context.Dispatch "TASKS_REFRESH"
                } else {
                    Write-Log -Level Warning -Message "TASK_DELETE: Task not found with ID $($Payload.TaskId)"
                }
                
            } catch {
                Write-Log -Level Error -Message "TASK_DELETE failed: $_" -Data @{
                    Exception = $_.Exception.Message
                    Payload = $Payload
                }
            }
        }
        
        # Initialize Navigation Service
        Trace-Step -StepName "Initializing Navigation Service"
        $services.Navigation = Initialize-NavigationService
        Trace-Step -StepName "Navigation Service initialized" -StepData @{
            NavigationType = $services.Navigation.GetType().Name
            NavigationKeys = if ($services.Navigation -is [hashtable]) { $services.Navigation.Keys } else { "N/A" }
        }
        
        # Register navigation routes
        Trace-Step -StepName "Registering navigation routes"
        
        & $services.Navigation.RegisterRoute -self $services.Navigation -Path "/dashboard" -ScreenFactory {
            param($Services)
            Get-DashboardScreen -Services $Services
        }
        
        & $services.Navigation.RegisterRoute -self $services.Navigation -Path "/task" -ScreenFactory {
            param($Services)
            Get-TaskManagementScreen -Services $Services
        }
        
        & $services.Navigation.RegisterRoute -self $services.Navigation -Path "/time-entry" -ScreenFactory {
            param($Services)
            Get-TimeEntryScreen -Services $Services
        }
        
        & $services.Navigation.RegisterRoute -self $services.Navigation -Path "/timer-start" -ScreenFactory {
            param($Services)
            Get-TimerStartScreen -Services $Services
        }
        
        & $services.Navigation.RegisterRoute -self $services.Navigation -Path "/project" -ScreenFactory {
            param($Services)
            Get-ProjectManagementScreen -Services $Services
        }
        
        & $services.Navigation.RegisterRoute -self $services.Navigation -Path "/reports" -ScreenFactory {
            param($Services)
            Get-ReportsScreen -Services $Services
        }
        
        & $services.Navigation.RegisterRoute -self $services.Navigation -Path "/settings" -ScreenFactory {
            param($Services)
            Get-SettingsScreen -Services $Services
        }
        
        # Initialize Keybinding Service
        Trace-Step -StepName "Initializing Keybinding Service"
        $services.Keybindings = Initialize-KeybindingService
        Trace-Step -StepName "Keybinding Service initialized" -StepData @{
            KeybindingType = $services.Keybindings.GetType().Name
            KeybindingKeys = if ($services.Keybindings -is [hashtable]) { $services.Keybindings.Keys } else { "N/A" }
        }
        
        Trace-Step -StepName "Setting global services" -StepData @{
            ServiceCount = $services.Keys.Count
            ServiceNames = $services.Keys
        }
        
        $global:Services = $services
        
        Trace-StateChange -StateType "GlobalServices" -NewValue @{
            ServiceCount = $services.Keys.Count
            ServiceNames = $services.Keys
        }
        
        Trace-FunctionExit -FunctionName "Initialize-PMCServices" -ReturnValue @{
            ServiceCount = $services.Keys.Count
            ServiceNames = $services.Keys
        }
        
        return $services
    }
}

function Start-PMCTerminal {
    param([bool]$Silent = $false)
    
    Trace-FunctionEntry -FunctionName "Start-PMCTerminal" -Parameters @{ Silent = $Silent }
    
    try {
        Trace-Step -StepName "Starting PMC Terminal initialization sequence"
        
        $loadedModules = Initialize-PMCModules -Silent:$Silent
        # Prepend the manually loaded modules for complete logging
        $loadedModules = @("logger", "exceptions") + $loadedModules
        Trace-Step -StepName "Module initialization completed" -StepData @{
            LoadedModuleCount = if ($loadedModules) { @($loadedModules).Count } else { 0 } # ADDED DEFENSIVE CHECK
            LoadedModules = $loadedModules
        }
        
        if (-not $Silent) { Write-Host "`nInitializing subsystems..." -ForegroundColor Cyan }
        
        # Initialize logger first - CRITICAL FOR DEBUGGING (already loaded)
        Write-Log -Level Info -Message "PMC Terminal v4.2 'Helios' startup initiated"
        Write-Log -Level Info -Message "Loaded modules: $($loadedModules -join ', ')"
        
        Trace-Step -StepName "Logger system initialized successfully" -StepData @{
            LogPath = Get-LogPath
        }
        
        # Initialize Event System
        Trace-Step -StepName "Initializing Event System"
        try {
            if (Get-Command Initialize-EventSystem -ErrorAction SilentlyContinue) {
                Initialize-EventSystem
                Write-Log -Level Debug -Message "Event system initialized"
                Trace-Step -StepName "Event system initialized successfully"
            } else {
                Write-Log -Level Warning -Message "Event system not available"
                Trace-Step -StepName "Event system not available"
            }
        } catch {
            Write-Log -Level Error -Message "Failed to initialize Event System" -Data @{
                Exception = $_.Exception.Message
                StackTrace = $_.Exception.StackTrace
            }
            Trace-Step -StepName "Event system initialization failed" -StepData @{
                Error = $_.Exception.Message
            }
            # Continue anyway as it might not be critical
        }
        
        # Initialize Theme Manager with enhanced error handling
        Trace-Step -StepName "Initializing Theme Manager"
        try {
            if (Get-Command Initialize-ThemeManager -ErrorAction SilentlyContinue) {
                Trace-Step -StepName "Calling Initialize-ThemeManager"
                Initialize-ThemeManager
                
                Trace-Step -StepName "Checking if theme is set after initialization"
                $currentTheme = $null
                if (Get-Command Get-TuiTheme -ErrorAction SilentlyContinue) {
                    try {
                        $currentTheme = Get-TuiTheme
                        Trace-Step -StepName "Theme check result" -StepData @{
                            ThemeExists = ($null -ne $currentTheme)
                            ThemeType = if ($currentTheme) { $currentTheme.GetType().Name } else { "null" }
                            ThemeProperties = if ($currentTheme -is [hashtable]) { $currentTheme.Keys } else { "N/A" }
                        }
                    } catch {
                        Write-Log -Level Error -Message "Failed to get current theme after initialization" -Data @{
                            Exception = $_.Exception.Message
                        }
                        Trace-Step -StepName "Get-TuiTheme failed" -StepData @{
                            Error = $_.Exception.Message
                        }
                    }
                }
                
                # FIX: Ensure theme is actually set
                if (-not $currentTheme) {
                    Write-Log -Level Warning -Message "Theme not set after initialization, setting Modern theme"
                    Trace-Step -StepName "Theme not set, attempting to set Modern theme"
                    
                    if (Get-Command Set-TuiTheme -ErrorAction SilentlyContinue) {
                        try {
                            Set-TuiTheme -ThemeName "Modern"
                            $currentTheme = Get-TuiTheme
                            Trace-Step -StepName "Modern theme set successfully" -StepData @{
                                ThemeSet = ($null -ne $currentTheme)
                                ThemeName = if ($currentTheme -and $currentTheme.Name) { $currentTheme.Name } else { "Unknown" }
                            }
                        } catch {
                            Write-Log -Level Error -Message "Failed to set Modern theme" -Data @{
                                Exception = $_.Exception.Message
                                StackTrace = $_.Exception.StackTrace
                            }
                            Trace-Step -StepName "Set-TuiTheme failed" -StepData @{
                                Error = $_.Exception.Message
                            }
                        }
                    } else {
                        Write-Log -Level Error -Message "Set-TuiTheme command not available"
                        Trace-Step -StepName "Set-TuiTheme command not available"
                    }
                }
                
                $finalTheme = if (Get-Command Get-TuiTheme -ErrorAction SilentlyContinue) { 
                    try { Get-TuiTheme } catch { $null }
                } else { $null }
                
                Write-Log -Level Debug -Message "Theme manager initialized" -Data @{
                    ThemeName = if ($finalTheme -and $finalTheme.Name) { $finalTheme.Name } else { "Unknown/Default" }
                    ThemeInitialized = ($null -ne $finalTheme)
                }
                
                Trace-Step -StepName "Theme manager initialization completed" -StepData @{
                    Success = ($null -ne $finalTheme)
                    ThemeName = if ($finalTheme -and $finalTheme.Name) { $finalTheme.Name } else { "Unknown/Default" }
                }
            } else {
                Write-Log -Level Warning -Message "Theme manager not available"
                Trace-Step -StepName "Theme manager not available"
            }
        } catch {
            Write-Log -Level Error -Message "Failed to initialize Theme Manager" -Data @{
                Exception = $_.Exception.Message
                StackTrace = $_.Exception.StackTrace
            }
            Trace-Step -StepName "Theme manager initialization failed" -StepData @{
                Error = $_.Exception.Message
                StackTrace = $_.Exception.StackTrace
            }
            # Continue with default colors
        }
        
        # Initialize Data Manager with error handling
        Trace-Step -StepName "Initializing Data Manager"
        try {
            if (Get-Command Initialize-DataManager -ErrorAction SilentlyContinue) {
                Initialize-DataManager
                Write-Log -Level Debug -Message "Data manager initialized"
                Trace-Step -StepName "Data manager initialized successfully"
            } else {
                Write-Log -Level Warning -Message "Data manager not available"
                Trace-Step -StepName "Data manager not available"
            }
        } catch {
            Write-Log -Level Error -Message "Failed to initialize Data Manager" -Data @{
                Exception = $_.Exception.Message
                StackTrace = $_.Exception.StackTrace
            }
            Trace-Step -StepName "Data manager initialization failed" -StepData @{
                Error = $_.Exception.Message
            }
            # Continue as data can be loaded manually
        }
        
        # Initialize TUI Framework
        Trace-Step -StepName "Initializing TUI Framework"
        try {
            if (Get-Command Initialize-TuiFramework -ErrorAction SilentlyContinue) {
                Initialize-TuiFramework
                Write-Log -Level Debug -Message "TUI framework initialized"
                Trace-Step -StepName "TUI framework initialized successfully"
            } else {
                $errorMsg = "Initialize-TuiFramework command not available"
                Write-Log -Level Error -Message $errorMsg
                Trace-Step -StepName "TUI framework not available"
                throw $errorMsg
            }
        } catch {
            Write-Log -Level Error -Message "Failed to initialize TUI Framework" -Data @{
                Exception = $_.Exception.Message
                StackTrace = $_.Exception.StackTrace
            }
            Trace-Step -StepName "TUI framework initialization failed" -StepData @{
                Error = $_.Exception.Message
            }
            throw # This is critical
        }
        
        # Initialize TUI Engine
        Trace-Step -StepName "Initializing TUI Engine"
        try {
            if (Get-Command Initialize-TuiEngine -ErrorAction SilentlyContinue) {
                # Get console dimensions for logging
                $consoleWidth = if ($Host.UI.RawUI) { $Host.UI.RawUI.WindowSize.Width } else { 80 }
                $consoleHeight = if ($Host.UI.RawUI) { $Host.UI.RawUI.WindowSize.Height } else { 24 }
                
                Trace-Step -StepName "Calling Initialize-TuiEngine" -StepData @{
                    ConsoleWidth = $consoleWidth
                    ConsoleHeight = $consoleHeight
                }
                
                Initialize-TuiEngine
                Write-Log -Level Info -Message "Initializing TUI Engine: ${consoleWidth}x${consoleHeight}"
                Write-Log -Level Info -Message "TUI Engine initialized successfully"
                
                Trace-Step -StepName "TUI engine initialized successfully" -StepData @{
                    Dimensions = "${consoleWidth}x${consoleHeight}"
                }
            } else {
                $errorMsg = "Initialize-TuiEngine command not available"
                Write-Log -Level Error -Message $errorMsg
                Trace-Step -StepName "TUI engine not available"
                throw $errorMsg
            }
        } catch {
            Write-Log -Level Error -Message "Failed to initialize TUI Engine" -Data @{
                Exception = $_.Exception.Message
                StackTrace = $_.Exception.StackTrace
            }
            Trace-Step -StepName "TUI engine initialization failed" -StepData @{
                Error = $_.Exception.Message
            }
            throw # This is critical
        }
        
        # Initialize Dialog System with error handling
        Trace-Step -StepName "Initializing Dialog System"
        try {
            if (Get-Command Initialize-DialogSystem -ErrorAction SilentlyContinue) {
                Initialize-DialogSystem
                Write-Log -Level Debug -Message "Dialog system initialized"
                Trace-Step -StepName "Dialog system initialized successfully"
            } else {
                Write-Log -Level Warning -Message "Dialog system not available"
                Trace-Step -StepName "Dialog system not available"
            }
        } catch {
            Write-Log -Level Error -Message "Failed to initialize Dialog System" -Data @{
                Exception = $_.Exception.Message
                StackTrace = $_.Exception.StackTrace
            }
            Trace-Step -StepName "Dialog system initialization failed" -StepData @{
                Error = $_.Exception.Message
            }
            # Continue without dialogs
        }
        
        # Load data
        Trace-Step -StepName "Loading unified data"
        try {
            if (Get-Command Load-UnifiedData -ErrorAction SilentlyContinue) {
                Load-UnifiedData
                Write-Log -Level Debug -Message "Data loaded successfully"
                Trace-Step -StepName "Data loaded successfully" -StepData @{
                    GlobalDataExists = ($null -ne $global:Data)
                    DataType = if ($global:Data) { $global:Data.GetType().Name } else { "null" }
                    DataKeys = if ($global:Data -is [hashtable]) { $global:Data.Keys } else { "N/A" }
                }
            } else {
                Write-Log -Level Warning -Message "Load-UnifiedData not available, initializing empty data"
                $global:Data = @{}
                Trace-Step -StepName "Initialized empty global data"
            }
        } catch {
            Write-Log -Level Warning -Message "Failed to load data, using empty data" -Data @{
                Exception = $_.Exception.Message
            }
            $global:Data = @{}
            Trace-Step -StepName "Data loading failed, using empty data" -StepData @{
                Error = $_.Exception.Message
            }
        }
        
        # Initialize services
        Trace-Step -StepName "Starting service initialization"
        $services = Initialize-PMCServices -Silent:$Silent
        Trace-Step -StepName "Services initialized" -StepData @{
            ServiceCount = $services.Keys.Count
            ServiceNames = $services.Keys
        }
        
        # Initialize Focus Manager with error handling
        Trace-Step -StepName "Initializing Focus Manager"
        try {
            if (Get-Command Initialize-FocusManager -ErrorAction SilentlyContinue) {
                Initialize-FocusManager
                Write-Log -Level Debug -Message "Focus manager initialized"
                Trace-Step -StepName "Focus manager initialized successfully"
            } else {
                Write-Log -Level Warning -Message "Focus manager not available"
                Trace-Step -StepName "Focus manager not available"
            }
        } catch {
            Write-Log -Level Error -Message "Failed to initialize Focus Manager" -Data @{
                Exception = $_.Exception.Message
                StackTrace = $_.Exception.StackTrace
            }
            Trace-Step -StepName "Focus manager initialization failed" -StepData @{
                Error = $_.Exception.Message
            }
            # Continue without advanced focus management
        }
        
        # Load screens
        Trace-Step -StepName "Loading screen modules"
        $loadedScreens = Initialize-PMCScreens -Silent:$Silent
        Trace-Step -StepName "Screens loaded" -StepData @{
            LoadedScreenCount = if ($loadedScreens) { @($loadedScreens).Count } else { 0 } # ADDED DEFENSIVE CHECK
            LoadedScreens = $loadedScreens
        }
        
        if (-not $Silent) { Write-Host "`nStarting application..." -ForegroundColor Green }
        
        Trace-Step -StepName "Clearing host and preparing for navigation"
        Clear-Host
        
        # Dispatch initial actions to populate dashboard data
        Trace-Step -StepName "Dispatching initial actions to populate data"
        try {
            # Note: The original log message here was confusingly worded. It's now corrected.
            # Write-Log -Level Info -Message "Dispatching initial 'DASHBOARD_REFRESH' action" # COMMENTED OUT
            # & $services.Store.Dispatch -self $services.Store -actionName "DASHBOARD_REFRESH" # COMMENTED OUT
            # Trace-Step -StepName "Initial DASHBOARD_REFRESH action dispatched successfully" # COMMENTED OUT
            Write-Log -Level Info -Message "Skipping initial DASHBOARD_REFRESH for simplified dashboard." # ADDED THIS LINE
        } catch {
            Write-Log -Level Error -Message "Error dispatching initial 'DASHBOARD_REFRESH' action" -Data @{
                Exception = $_.Exception.Message
                StackTrace = $_.Exception.StackTrace
            }
            Trace-Step -StepName "Initial DASHBOARD_REFRESH action failed" -StepData @{
                Error = $_.Exception.Message
            }
            # Continue anyway - the dashboard can refresh later
        }
        
        # Navigate to start screen
        Trace-Step -StepName "Determining start screen path"
        $startPath = "/dashboard"
        if ($args -contains "-start") {
            $startIndex = [array]::IndexOf($args, "-start")
            if (($startIndex + 1) -lt $args.Count) { 
                $startPath = $args[$startIndex + 1] 
                Trace-Step -StepName "Custom start path specified" -StepData @{
                    CustomPath = $startPath
                }
            }
        }
        
        Trace-Step -StepName "Validating start path" -StepData @{
            StartPath = $startPath
            NavigationService = ($null -ne $services.Navigation)
        }
        
        if ($services.Navigation -and (& $services.Navigation.IsValidRoute -self $services.Navigation -Path $startPath)) {
            Trace-Step -StepName "Navigating to start screen" -StepData @{
                StartPath = $startPath
                NavigationMethod = "GoTo"
            }
            
            Write-Log -Level Info -Message "Navigated to: $startPath"
            & $services.Navigation.GoTo -self $services.Navigation -Path $startPath -Services $services
            
            Trace-Step -StepName "Navigation completed successfully"
        } else {
            Write-Log -Level Warning -Message "Startup path '$startPath' is not valid. Defaulting to /dashboard."
            Trace-Step -StepName "Invalid start path, defaulting to dashboard" -StepData @{
                InvalidPath = $startPath
                DefaultPath = "/dashboard"
            }
            
            & $services.Navigation.GoTo -self $services.Navigation -Path "/dashboard" -Services $services
        }
        
        # Start the main loop
        Trace-Step -StepName "Starting TUI main loop"
        if (Get-Command Start-TuiLoop -ErrorAction SilentlyContinue) {
            Start-TuiLoop
            Trace-Step -StepName "TUI main loop started"
        } else {
            $errorMsg = "Start-TuiLoop command not available"
            Write-Log -Level Error -Message $errorMsg
            Trace-Step -StepName "TUI main loop unavailable"
            throw $errorMsg
        }
        
        Trace-FunctionExit -FunctionName "Start-PMCTerminal" -ReturnValue @{ Success = $true }
        
    } catch {
        Write-Log -Level Error -Message "FATAL: Failed to initialize PMC Terminal" -Data @{
            Exception = $_.Exception.Message
            StackTrace = $_.Exception.StackTrace
            InnerException = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
        } -Force
        
        Trace-Step -StepName "Fatal error occurred during initialization" -StepData @{
            Error = $_.Exception.Message
            StackTrace = $_.Exception.StackTrace
        }
        
        Write-Host "`nFATAL ERROR DURING INITIALIZATION: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
        
        # Try to get diagnostic report
        Trace-Step -StepName "Attempting to generate crash diagnostic report"
        try {
            if (Get-Command Get-HeliosDiagnosticReport -ErrorAction SilentlyContinue) {
                $report = Get-HeliosDiagnosticReport -IncludeErrorHistory -IncludeLogEntries -LogEntryCount 100
                $reportPath = Join-Path $env:TEMP "helios_crash_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                $report | ConvertTo-Json -Depth 10 | Set-Content $reportPath
                Write-Host "`nDiagnostic report saved to: $reportPath" -ForegroundColor Yellow
                Write-Log -Level Info -Message "Crash diagnostic report saved" -Data @{ ReportPath = $reportPath } -Force
                
                Trace-Step -StepName "Crash diagnostic report generated" -StepData @{
                    ReportPath = $reportPath
                    ReportSize = (Get-Item $reportPath).Length
                }
            } else {
                Write-Host "Diagnostic report generation not available" -ForegroundColor Yellow
                Trace-Step -StepName "Diagnostic report generation not available"
            }
        } catch {
            Write-Host "Failed to generate diagnostic report: $_" -ForegroundColor Yellow
            Trace-Step -StepName "Diagnostic report generation failed" -StepData @{
                Error = $_.Exception.Message
            }
        }
        
        Trace-FunctionExit -FunctionName "Start-PMCTerminal" -ReturnValue @{ Success = $false; Error = $_.Exception.Message } -WithError
        
        throw
    } finally {
        Trace-Step -StepName "Starting cleanup sequence"
        
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) { 
            Write-Log -Level Info -Message "PMC Terminal shutting down" 
        }
        
        if (Get-Command -Name "Stop-TuiEngine" -ErrorAction SilentlyContinue) { 
            if (-not $Silent) { Write-Host "`nShutting down..." }
            Trace-Step -StepName "Stopping TUI Engine"
            Stop-TuiEngine 
        }
        
        if ($global:Data -and (Get-Command -Name "Save-UnifiedData" -ErrorAction SilentlyContinue)) { 
            if (-not $Silent) { Write-Host "Saving data..." }
            Trace-Step -StepName "Saving unified data"
            Save-UnifiedData 
        }
        
        if (-not $Silent) { Write-Host "Goodbye!" -ForegroundColor Green }
        Trace-Step -StepName "Cleanup completed"
    }
}

# Main execution block with comprehensive tracing
$script:Silent = $args -contains "-silent" -or $args -contains "-s"

# Set up enhanced error handling from the start
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    # Clear host and start tracing immediately
    Clear-Host

    # FIX: CRITICAL - Pre-load essential modules (logger, exceptions) BEFORE anything else.
    # This resolves the chicken-and-egg dependency issue where tracing and error handling
    # functions were being called before they were loaded.
    $exceptionsModulePath = Join-Path $script:BasePath "modules\exceptions.psm1"
    $loggerModulePath = Join-Path $script:BasePath "modules\logger.psm1"
    
    if (-not (Test-Path $exceptionsModulePath)) {
        throw "CRITICAL FAILURE: The core exception handling module is missing at '$exceptionsModulePath'. Cannot continue."
    }
    if (-not (Test-Path $loggerModulePath)) {
        throw "CRITICAL FAILURE: The core logger module is missing at '$loggerModulePath'. Cannot continue."
    }
    Import-Module $exceptionsModulePath -Force -Global
    Import-Module $loggerModulePath -Force -Global

    # Now that logger is available, initialize it.
    Initialize-Logger
    Write-Log -Level Info -Message "Logger initialized early in main execution block"
    
    # Initialize basic logging even before modules are loaded
    Write-Host "PMC Terminal v4.2 'Helios' - Enhanced Diagnostics Mode" -ForegroundColor Cyan
    Write-Host "Tracing enabled - All execution steps will be logged" -ForegroundColor Yellow
    Write-Host "Log files written to: $env:TEMP\PMCTerminal\" -ForegroundColor Green
    Write-Host "Starting initialization sequence..." -ForegroundColor Green
    Write-Host ""
    
    # Trace the very beginning
    if (-not $script:Silent) {
        Write-Log -Level Trace -Message "Main execution block started" -Data @{
            Arguments = $args
            SilentMode = $script:Silent
            BasePath = $script:BasePath
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            ProcessId = $PID
        }
    }
    
    # Start the terminal with enhanced error context
    Invoke-WithErrorHandling -Component "MainExecution" -OperationName "Start-PMCTerminal" -ScriptBlock {
        Start-PMCTerminal -Silent:$script:Silent
    } -ErrorHandler {
        param($Exception, $DetailedError)
        
        Write-Host "`n=== CRITICAL FAILURE ===" -ForegroundColor Red
        Write-Host "Fatal error occurred during PMC Terminal startup" -ForegroundColor Red
        
        # Check if this is our custom exception with data
        $heliosEx = $null
        if ($Exception -and $Exception.Data -and $Exception.Data.Contains("HeliosException")) {
            $heliosEx = $Exception.Data["HeliosException"]
        }
        
        # Safely access exception properties that might not exist
        $errorMessage = if ($heliosEx -and $heliosEx.Message) { $heliosEx.Message }
                       elseif ($Exception.Message) { $Exception.Message } 
                       elseif ($Exception -is [string]) { $Exception } 
                       else { "Unknown error" }
        Write-Host "Error: $errorMessage" -ForegroundColor Red
        
        $component = if ($heliosEx -and $heliosEx.Component) { $heliosEx.Component }
                    elseif ($Exception.Component) { $Exception.Component }
                    elseif ($Exception.Data -and $Exception.Data.Contains("Component")) { $Exception.Data["Component"] }
                    else { $null }
        
        if ($component) {
            Write-Host "Component: $component" -ForegroundColor Yellow
        }
        
        $timestamp = if ($heliosEx -and $heliosEx.Timestamp) { $heliosEx.Timestamp }
                    elseif ($Exception.Timestamp) { $Exception.Timestamp }
                    elseif ($Exception.Data -and $Exception.Data.Contains("Timestamp")) { $Exception.Data["Timestamp"] }
                    else { Get-Date }
        
        Write-Host "Timestamp: $timestamp" -ForegroundColor Yellow
        
        if ($DetailedError) {
            Write-Host "`nDetailed Error Information:" -ForegroundColor Yellow
            Write-Host "Type: $($DetailedError.Type)" -ForegroundColor Gray
            Write-Host "Category: $($DetailedError.Category)" -ForegroundColor Gray
            Write-Host "Location: $($DetailedError.ScriptName):$($DetailedError.LineNumber)" -ForegroundColor Gray
            
            if ($DetailedError.StackTrace -and $DetailedError.StackTrace.Count -gt 0) {
                Write-Host "`nCall Stack:" -ForegroundColor Yellow
                for ($i = 0; $i -lt [Math]::Min(5, $DetailedError.StackTrace.Count); $i++) {
                    $frame = $DetailedError.StackTrace[$i]
                    Write-Host "  [$i] $($frame.Command) at $($frame.Location)" -ForegroundColor Gray
                }
            }
            
            if ($DetailedError.SystemContext) {
                Write-Host "`nSystem Context:" -ForegroundColor Yellow
                Write-Host "  Process ID: $($DetailedError.SystemContext.ProcessId)" -ForegroundColor Gray
                Write-Host "  PowerShell: $($DetailedError.SystemContext.PowerShellVersion)" -ForegroundColor Gray
                Write-Host "  Memory Usage: $($DetailedError.SystemContext.MemoryUsage) bytes" -ForegroundColor Gray
                
                if ($DetailedError.SystemContext.LoadedModules) {
                    Write-Host "  Loaded Modules: $($DetailedError.SystemContext.LoadedModules.Count)" -ForegroundColor Gray
                }
                
                if ($DetailedError.SystemContext.GlobalVariables) {
                    Write-Host "  Global Variables:" -ForegroundColor Gray
                    foreach ($var in $DetailedError.SystemContext.GlobalVariables) {
                        Write-Host "    $($var.Name): $($var.Type)" -ForegroundColor DarkGray
                    }
                }
            }
        }
        
        # Try to save crash information
        try {
            # Extract Helios exception if available
            $heliosEx = $null
            if ($Exception -and $Exception.Data -and $Exception.Data.Contains("HeliosException")) {
                $heliosEx = $Exception.Data["HeliosException"]
            }
            
            $crashInfo = @{
                Timestamp = Get-Date
                Exception = @{
                    Message = if ($heliosEx -and $heliosEx.Message) { $heliosEx.Message }
                             elseif ($Exception.Message) { $Exception.Message } 
                             else { "Unknown error" }
                    Type = if ($Exception.GetType) { $Exception.GetType().FullName } else { "Unknown" }
                    Component = if ($heliosEx -and $heliosEx.Component) { $heliosEx.Component }
                               elseif ($Exception.Component) { $Exception.Component }
                               elseif ($Exception.Data -and $Exception.Data.Contains("Component")) { $Exception.Data["Component"] }
                               else { "Unknown" }
                }
                DetailedError = $DetailedError
                ProcessId = $PID
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                Arguments = $args
                BasePath = $script:BasePath
            }
            
            $crashPath = Join-Path $env:TEMP "helios_fatal_crash_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            $crashInfo | ConvertTo-Json -Depth 10 | Set-Content $crashPath -Encoding UTF8
            
            Write-Host "`nCrash information saved to: $crashPath" -ForegroundColor Cyan
            Write-Host "Please include this file when reporting the issue." -ForegroundColor Cyan
            
        } catch {
            Write-Host "`nFailed to save crash information: $_" -ForegroundColor Yellow
        }
        
        Write-Host "`n=== END CRITICAL FAILURE ===" -ForegroundColor Red
        
        # Don't re-throw - we want to handle this gracefully
    }
    
} catch {
    # This is the ultimate fallback error handler
    Write-Host "`n!!! ULTIMATE FALLBACK ERROR HANDLER !!!" -ForegroundColor Red
    Write-Host "Even the enhanced error handling failed!" -ForegroundColor Red
    Write-Host "Raw error: $_" -ForegroundColor Red
    Write-Host "Error type: $($_.GetType().FullName)" -ForegroundColor Yellow
    Write-Host "Script stack trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    
    # Try one last diagnostic attempt
    try {
        $ultimateFailureInfo = @{
            Timestamp = Get-Date
            UltimateError = $_.Exception.Message
            ErrorType = $_.GetType().FullName
            ProcessId = $PID
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            WorkingDirectory = Get-Location
            Arguments = $args
        }
        
        $ultimatePath = Join-Path $env:TEMP "helios_ultimate_failure_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $ultimateFailureInfo | ConvertTo-Json -Depth 5 | Set-Content $ultimatePath -Encoding UTF8
        
        Write-Host "`nUltimate failure info saved to: $ultimatePath" -ForegroundColor Magenta
    } catch {
        Write-Host "Even ultimate failure logging failed: $_" -ForegroundColor Red
    }
    
    Write-Error "Fatal error occurred: $_"
    exit 1
    
} finally {
    # Final cleanup and user interaction
    if ($Host.UI.RawUI) {
        Write-Host "`nPress any key to exit..." -ForegroundColor Green
        try {
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } catch {
            # If even reading a key fails, just wait a moment
            Start-Sleep -Seconds 2
        }
    }
    
    Write-Host "Exiting PMC Terminal..." -ForegroundColor Gray
    exit 1
}