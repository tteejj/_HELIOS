# Dashboard Screen - Helios Service-Based Version
# Uses the new service architecture with app store and navigation

function global:Get-DashboardScreen {
    $screen = @{
        Name = "DashboardScreen"
        Components = @{}
        _subscriptions = @()
        
        Init = {
            param($self)
            
            Write-Log -Level Debug -Message "Dashboard Init started (Helios version)"
            
            try {
                # Access services from global registry
                $services = $global:Services
                if (-not $services) {
                    Write-Log -Level Error -Message "Services not initialized"
                    return
                }
                
                # Create the main grid layout
                $rootPanel = New-TuiGridPanel -Props @{
                    X = 1
                    Y = 2
                    Width = ($global:TuiState.BufferWidth - 2)
                    Height = ($global:TuiState.BufferHeight - 4)
                    ShowBorder = $false
                    RowDefinitions = @("14", "1*")  # Top row fixed, bottom row flexible
                    ColumnDefinitions = @("37", "42", "1*")  # Fixed widths for consistency
                }
                $self.Components.rootPanel = $rootPanel
                
                # Quick Actions Panel
                $quickActionsPanel = New-TuiStackPanel -Props @{
                    Name = "quickActionsPanel"
                    Title = " Quick Actions "
                    ShowBorder = $true
                    BorderStyle = "Single"
                    Padding = 1
                }
                
                $quickActions = New-TuiDataTable -Props @{
                    Name = "quickActions"
                    IsFocusable = $true
                    ShowBorder = $false
                    ShowHeader = $false
                    ShowFooter = $false
                    Columns = @(
                        @{ Name = "Action"; Width = 32 }
                    )
                    OnRowSelect = {
                        param($data, $index)
                        Write-Log -Level Debug -Message "Quick action selected: $index"
                        
                        # Use navigation service for routing
                        $routes = @("/time-entry", "/timer/start", "/tasks", "/projects", "/reports", "/settings")
                        if ($index -ge 0 -and $index -lt $routes.Count) {
                            $services.Navigation.GoTo($routes[$index])
                        }
                    }
                }
                
                & $quickActionsPanel.AddChild -self $quickActionsPanel -Child $quickActions
                & $rootPanel.AddChild -self $rootPanel -Child $quickActionsPanel -LayoutProps @{ 
                    "Grid.Row" = 0
                    "Grid.Column" = 0 
                }
                
                # Active Timers Panel
                $timersPanel = New-TuiStackPanel -Props @{
                    Name = "timersPanel"
                    Title = " Active Timers "
                    ShowBorder = $true
                    BorderStyle = "Single"
                    Padding = 1
                }
                
                $activeTimers = New-TuiDataTable -Props @{
                    Name = "activeTimers"
                    IsFocusable = $true
                    ShowBorder = $false
                    ShowFooter = $false
                    Columns = @(
                        @{ Name = "Project"; Width = 20 }
                        @{ Name = "Time"; Width = 10 }
                    )
                    Data = @()
                }
                
                & $timersPanel.AddChild -self $timersPanel -Child $activeTimers
                & $rootPanel.AddChild -self $rootPanel -Child $timersPanel -LayoutProps @{ 
                    "Grid.Row" = 0
                    "Grid.Column" = 1 
                }
                
                # Stats Panel
                $statsPanel = New-TuiStackPanel -Props @{
                    Name = "statsPanel"
                    Title = " Stats "
                    ShowBorder = $true
                    BorderStyle = "Single"
                    Padding = 1
                    Orientation = "Vertical"
                    Spacing = 1
                }
                
                # Create stat labels
                $todayLabel = New-TuiLabel -Props @{
                    Name = "todayHoursLabel"
                    Text = "Today: 0h"
                    Height = 1
                }
                $weekLabel = New-TuiLabel -Props @{
                    Name = "weekHoursLabel"
                    Text = "Week: 0h"
                    Height = 1
                }
                $tasksLabel = New-TuiLabel -Props @{
                    Name = "activeTasksLabel"
                    Text = "Tasks: 0"
                    Height = 1
                }
                $timersLabel = New-TuiLabel -Props @{
                    Name = "runningTimersLabel"
                    Text = "Timers: 0"
                    Height = 1
                }
                
                & $statsPanel.AddChild -self $statsPanel -Child $todayLabel
                & $statsPanel.AddChild -self $statsPanel -Child $weekLabel
                & $statsPanel.AddChild -self $statsPanel -Child $tasksLabel
                & $statsPanel.AddChild -self $statsPanel -Child $timersLabel
                
                & $rootPanel.AddChild -self $rootPanel -Child $statsPanel -LayoutProps @{ 
                    "Grid.Row" = 0
                    "Grid.Column" = 2 
                }
                
                # Today's Tasks Panel (spans all columns)
                $tasksPanel = New-TuiStackPanel -Props @{
                    Name = "tasksPanel"
                    Title = " Today's Tasks "
                    ShowBorder = $true
                    BorderStyle = "Single"
                    Padding = 1
                }
                
                $todaysTasks = New-TuiDataTable -Props @{
                    Name = "todaysTasks"
                    IsFocusable = $true
                    ShowBorder = $false
                    ShowFooter = $false
                    Columns = @(
                        @{ Name = "Priority"; Width = 8 }
                        @{ Name = "Task"; Width = 45 }
                        @{ Name = "Project"; Width = 15 }
                    )
                    Data = @()
                    AllowSort = $true
                }
                
                & $tasksPanel.AddChild -self $tasksPanel -Child $todaysTasks
                & $rootPanel.AddChild -self $rootPanel -Child $tasksPanel -LayoutProps @{ 
                    "Grid.Row" = 1
                    "Grid.Column" = 0
                    "Grid.ColumnSpan" = 3
                }
                
                # Store references for easy access
                $self._quickActions = $quickActions
                $self._activeTimers = $activeTimers
                $self._todaysTasks = $todaysTasks
                $self._todayLabel = $todayLabel
                $self._weekLabel = $weekLabel
                $self._tasksLabel = $tasksLabel
                $self._timersLabel = $timersLabel
                
                # Subscribe to app store updates
                $self._subscriptions += $services.Store.Subscribe("quickActions", {
                    param($data)
                    if ($self._quickActions) {
                        $self._quickActions.Data = $data.NewValue
                        if ($self._quickActions.ProcessData) {
                            & $self._quickActions.ProcessData -self $self._quickActions
                        }
                    }
                })
                
                $self._subscriptions += $services.Store.Subscribe("activeTimers", {
                    param($data)
                    if ($self._activeTimers) {
                        $self._activeTimers.Data = $data.NewValue
                        if ($self._activeTimers.ProcessData) {
                            & $self._activeTimers.ProcessData -self $self._activeTimers
                        }
                    }
                })
                
                $self._subscriptions += $services.Store.Subscribe("todaysTasks", {
                    param($data)
                    if ($self._todaysTasks) {
                        $self._todaysTasks.Data = $data.NewValue
                        if ($self._todaysTasks.ProcessData) {
                            & $self._todaysTasks.ProcessData -self $self._todaysTasks
                        }
                    }
                })
                
                $self._subscriptions += $services.Store.Subscribe("stats.todayHours", {
                    param($data)
                    if ($self._todayLabel) {
                        $self._todayLabel.Text = "Today: $($data.NewValue)h"
                    }
                })
                
                $self._subscriptions += $services.Store.Subscribe("stats.weekHours", {
                    param($data)
                    if ($self._weekLabel) {
                        $self._weekLabel.Text = "Week: $($data.NewValue)h"
                    }
                })
                
                $self._subscriptions += $services.Store.Subscribe("stats.activeTasks", {
                    param($data)
                    if ($self._tasksLabel) {
                        $self._tasksLabel.Text = "Tasks: $($data.NewValue)"
                    }
                })
                
                $self._subscriptions += $services.Store.Subscribe("stats.runningTimers", {
                    param($data)
                    if ($self._timersLabel) {
                        $self._timersLabel.Text = "Timers: $($data.NewValue)"
                    }
                })
                
                # Register store actions if not already registered
                if (-not $services.Store._actions.ContainsKey("DASHBOARD_REFRESH")) {
                    & $services.Store.RegisterAction -actionName "DASHBOARD_REFRESH" -scriptBlock {
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
                        if ($global:Data -and $global:Data.ActiveTimers) {
                            foreach ($timerEntry in $global:Data.ActiveTimers.GetEnumerator()) {
                                $timer = $timerEntry.Value
                                if ($timer -and $timer.StartTime) {
                                    $elapsed = (Get-Date) - [DateTime]$timer.StartTime
                                    $project = if ($global:Data.Projects -and $timer.ProjectKey) { 
                                        $global:Data.Projects[$timer.ProjectKey].Name 
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
                        if ($global:Data -and $global:Data.Tasks) {
                            $today = (Get-Date).ToString("yyyy-MM-dd")
                            foreach ($task in $global:Data.Tasks) {
                                if ($task -and -not $task.Completed -and ($task.DueDate -eq $today -or [string]::IsNullOrEmpty($task.DueDate))) {
                                    $project = if ($global:Data.Projects -and $task.ProjectKey) { 
                                        $global:Data.Projects[$task.ProjectKey].Name 
                                    } else { 
                                        "None" 
                                    }
                                    
                                    $taskData += @{
                                        Priority = $task.Priority ?? "Medium"
                                        Task = $task.Description
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
                        
                        if ($global:Data) {
                            $today = (Get-Date).ToString("yyyy-MM-dd")
                            
                            if ($global:Data.TimeEntries) {
                                $todayEntries = @($global:Data.TimeEntries | Where-Object { $_ -and $_.Date -eq $today })
                                $stats.todayHours = [Math]::Round(($todayEntries | Measure-Object -Property Hours -Sum).Sum, 2)
                                
                                $weekStart = (Get-Date).AddDays(-[int](Get-Date).DayOfWeek).Date
                                $weekEntries = @($global:Data.TimeEntries | Where-Object { 
                                    $_ -and $_.Date -and ([DateTime]::Parse($_.Date) -ge $weekStart)
                                })
                                $stats.weekHours = [Math]::Round(($weekEntries | Measure-Object -Property Hours -Sum).Sum, 2)
                            }
                            
                            if ($global:Data.Tasks) {
                                $stats.activeTasks = @($global:Data.Tasks | Where-Object { $_ -and -not $_.Completed }).Count
                            }
                            
                            if ($global:Data.ActiveTimers) {
                                $stats.runningTimers = $global:Data.ActiveTimers.Count
                            }
                        }
                        
                        $Context.UpdateState(@{ stats = $stats })
                    }
                }
                
                # Initial data load
                $services.Store.Dispatch("DASHBOARD_REFRESH")
                
                # Set up auto-refresh timer
                $self._refreshTimer = [System.Timers.Timer]::new(5000)  # 5 seconds
                Register-ObjectEvent -InputObject $self._refreshTimer -EventName Elapsed -Action {
                    if ($global:Services -and $global:Services.Store) {
                        $global:Services.Store.Dispatch("DASHBOARD_REFRESH")
                    }
                }
                $self._refreshTimer.Start()
                
                Write-Log -Level Debug -Message "Dashboard Init completed"
                
            } catch {
                Write-Log -Level Error -Message "Dashboard Init error: $_" -Data $_
            }
        }
        
        Render = {
            param($self)
            
            try {
                # Header
                $headerColor = Get-ThemeColor "Header" -Default Cyan
                $currentTime = Get-Date -Format 'dddd, MMMM dd, yyyy HH:mm:ss'
                Write-BufferString -X 2 -Y 1 -Text "PMC Terminal Dashboard - $currentTime" -ForegroundColor $headerColor
                
                # Active timer indicator
                $store = $global:Services.Store
                if ($store) {
                    $timers = $store.GetState("stats.runningTimers")
                    if ($timers -gt 0) {
                        $timerText = "● TIMER ACTIVE"
                        $timerX = $global:TuiState.BufferWidth - $timerText.Length - 2
                        Write-BufferString -X $timerX -Y 1 -Text $timerText -ForegroundColor Red
                    }
                }
                
                # Render the root panel (which renders all children)
                if ($self.Components.rootPanel -and $self.Components.rootPanel.Render) {
                    & $self.Components.rootPanel.Render -self $self.Components.rootPanel
                }
                
                # Status bar
                $subtleColor = Get-ThemeColor "Subtle" -Default DarkGray
                $statusY = $global:TuiState.BufferHeight - 2
                Write-BufferString -X 2 -Y $statusY -Text "Tab: Switch Focus | Enter: Select | R: Refresh | Q: Quit | F12: Debug Log" -ForegroundColor $subtleColor
                
            } catch {
                Write-Log -Level Error -Message "Dashboard Render error: $_" -Data $_
                Write-BufferString -X 2 -Y 2 -Text "Error rendering dashboard: $_" -ForegroundColor Red
            }
        }
        
        HandleInput = {
            param($self, $Key)
            
            try {
                $services = $global:Services
                if (-not $services) {
                    return $false
                }
                
                # Check keybinding service
                $action = $services.Keybindings.HandleKey($Key)
                
                switch ($action) {
                    "App.Refresh" { 
                        $services.Store.Dispatch("DASHBOARD_REFRESH")
                        return $true
                    }
                    "App.DebugLog" {
                        $services.Navigation.GoTo("/log")
                        return $true
                    }
                    "App.Quit" {
                        return "Quit"
                    }
                    "App.Back" {
                        return "Quit"  # Dashboard is root, so back = quit
                    }
                }
                
                # Number keys for quick navigation
                if ($Key.KeyChar -ge '1' -and $Key.KeyChar -le '6') {
                    $index = [int]$Key.KeyChar.ToString() - 1
                    $routes = @("/time-entry", "/timer/start", "/tasks", "/projects", "/reports", "/settings")
                    if ($index -ge 0 -and $index -lt $routes.Count) {
                        $services.Navigation.GoTo($routes[$index])
                        return $true
                    }
                }
                
                return $false
                
            } catch {
                Write-Log -Level Error -Message "HandleInput error: $_" -Data $_
                return $false
            }
        }
        
        OnExit = {
            param($self)
            
            Write-Log -Level Debug -Message "Dashboard screen exiting"
            
            # Stop refresh timer
            if ($self._refreshTimer) {
                $self._refreshTimer.Stop()
                $self._refreshTimer.Dispose()
            }
            
            # Unsubscribe from store updates
            $services = $global:Services
            if ($services -and $services.Store) {
                foreach ($subId in $self._subscriptions) {
                    $services.Store.Unsubscribe($subId)
                }
            }
        }
        
        OnResume = {
            param($self)
            
            Write-Log -Level Debug -Message "Dashboard screen resuming"
            
            # Force complete redraw
            if ($global:TuiState -and $global:TuiState.RenderStats) {
                $global:TuiState.RenderStats.FrameCount = 0
            }
            
            # Refresh data
            $services = $global:Services
            if ($services -and $services.Store) {
                $services.Store.Dispatch("DASHBOARD_REFRESH")
            }
            
            Request-TuiRefresh
        }
    }
    
    return $screen
}

Export-ModuleMember -Function Get-DashboardScreen
