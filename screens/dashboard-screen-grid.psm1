# Dashboard Screen - FIXED COMPLIANT VERSION
# Using programmatic pattern with component-based architecture

function global:Get-DashboardScreen {
    $screen = @{
        Name = "DashboardScreen"
        
        # 1. State: Central data model for the screen
        State = @{
            ActiveTimers = @()
            TodaysTasks = @()
            RecentEntries = @()
            QuickStats = @{
                TodayHours = 0
                WeekHours = 0
                ActiveTasks = 0
                RunningTimers = 0
            }
            LastRefresh = [DateTime]::MinValue
            AutoRefreshInterval = 5
        }
        
        # 2. Components: Storage for instantiated component objects
        Components = @{}
        
        # Focus management
        FocusedComponentName = "quickActions"
        
        # Define refresh method directly on the hashtable
        RefreshData = {
            param($screen)
            
            Write-Log -Level Debug -Message "RefreshData called"
            
            try {
                # Refresh Active Timers
                if ($global:Data -and $global:Data.ActiveTimers) {
                    $timerData = @()
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
                    if ($screen.Components.activeTimers) {
                        $screen.Components.activeTimers.Data = $timerData
                        # Force process data to refresh display
                        if ($screen.Components.activeTimers.ProcessData) {
                            & $screen.Components.activeTimers.ProcessData -self $screen.Components.activeTimers
                        }
                    }
                    Write-Log -Level Debug -Message "Active timers updated: $($timerData.Count) timers"
                }
                
                # Refresh Today's Tasks
                if ($global:Data -and $global:Data.Tasks) {
                    $today = (Get-Date).ToString("yyyy-MM-dd")
                    $taskData = @()
                    foreach ($task in $global:Data.Tasks) {
                        if ($task -and -not $task.Completed -and ($task.DueDate -eq $today -or [string]::IsNullOrEmpty($task.DueDate))) {
                            $project = if ($global:Data.Projects -and $task.ProjectKey) { 
                                $global:Data.Projects[$task.ProjectKey].Name 
                            } else { 
                                "None" 
                            }
                            
                            $taskData += @{
                                Priority = $task.Priority ?? "Medium"
                                Description = $task.Description
                                Project = $project
                            }
                        }
                    }
                    if ($screen.Components.todaysTasks) {
                        $screen.Components.todaysTasks.Data = $taskData | Sort-Object Priority, Description
                        # Force process data to refresh display
                        if ($screen.Components.todaysTasks.ProcessData) {
                            & $screen.Components.todaysTasks.ProcessData -self $screen.Components.todaysTasks
                        }
                    }
                    Write-Log -Level Debug -Message "Today's tasks updated: $($taskData.Count) tasks"
                }
                
                # Refresh Stats
                $stats = @{ TodayHours = 0; WeekHours = 0; ActiveTasks = 0; RunningTimers = 0 }
                
                if ($global:Data) {
                    $today = (Get-Date).ToString("yyyy-MM-dd")
                    
                    if ($global:Data.TimeEntries) {
                        $todayEntries = @($global:Data.TimeEntries | Where-Object { $_ -and $_.Date -eq $today })
                        $stats.TodayHours = [Math]::Round(($todayEntries | Measure-Object -Property Hours -Sum).Sum, 2)
                        
                        $weekStart = (Get-Date).AddDays(-[int](Get-Date).DayOfWeek).Date
                        $weekEntries = @($global:Data.TimeEntries | Where-Object { 
                            $_ -and $_.Date -and ([DateTime]::Parse($_.Date) -ge $weekStart)
                        })
                        $stats.WeekHours = [Math]::Round(($weekEntries | Measure-Object -Property Hours -Sum).Sum, 2)
                    }
                    
                    if ($global:Data.Tasks) {
                        $stats.ActiveTasks = @($global:Data.Tasks | Where-Object { $_ -and -not $_.Completed }).Count
                    }
                    
                    if ($global:Data.ActiveTimers) {
                        $stats.RunningTimers = $global:Data.ActiveTimers.Count
                    }
                }
                
                $screen.State.QuickStats = $stats
                $screen.Components.todayHoursLabel.Text = "Today: $($stats.TodayHours)h"
                $screen.Components.weekHoursLabel.Text = "Week: $($stats.WeekHours)h"
                $screen.Components.activeTasksLabel.Text = "Tasks: $($stats.ActiveTasks)"
                $screen.Components.runningTimersLabel.Text = "Timers: $($stats.RunningTimers)"
                
                Write-Log -Level Debug -Message "Stats updated: Today=$($stats.TodayHours)h, Week=$($stats.WeekHours)h, Tasks=$($stats.ActiveTasks), Timers=$($stats.RunningTimers)"
            } catch {
                Write-Log -Level Error -Message "RefreshData error: $_" -Data $_
            }
        }
        
        # 3. Init: One-time setup
        Init = {
            param($self)
            
            Write-Log -Level Debug -Message "Dashboard Init started"
            
            try {
                # Create a reference to the screen for closures
                $screenRef = $self
                
                # Quick Actions - Simple implementation
                if (Get-Command New-TuiDataTable -ErrorAction SilentlyContinue) {
                    $self.Components.quickActions = New-TuiDataTable -Props @{
                        X = 2; Y = 4; Width = 35; Height = 12
                        IsFocusable = $true
                        ShowBorder = $false  # Parent screen draws the border
                        Columns = @(
                            @{ Name = "Action"; Header = "Quick Actions"; Width = 32 }  # Explicit width (35 table - 3 for borders/padding)
                        )
                        Data = @(
                            @{ Action = "1. Add Time Entry" }
                            @{ Action = "2. Start Timer" }
                            @{ Action = "3. Manage Tasks" }
                            @{ Action = "4. Manage Projects" }
                            @{ Action = "5. View Reports" }
                            @{ Action = "6. Settings" }
                        )
                        AllowSort = $false
                        AllowFilter = $false
                        MultiSelect = $false
                        ShowHeader = $false
                        ShowFooter = $false
                        Title = "Quick Actions"
                        OnRowSelect = {
                            param($SelectedData, $SelectedIndex)
                            Write-Log -Level Debug -Message "Quick action selected: $SelectedIndex"
                            switch ($SelectedIndex) {
                                0 { if (Get-Command Get-TimeEntryFormScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TimeEntryFormScreen) } }
                                1 { if (Get-Command Get-TimerStartScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TimerStartScreen) } }
                                2 { if (Get-Command Get-TaskScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TaskScreen) } elseif (Get-Command Get-TaskManagementScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TaskManagementScreen) } }
                                3 { if (Get-Command Get-ProjectManagementScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-ProjectManagementScreen) } }
                                4 { if (Get-Command Get-ReportsScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-ReportsScreen) } }
                                5 { if (Get-Command Get-SettingsScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-SettingsScreen) } }
                            }
                        }
                    }
                    
                    # Debug logging
                    Write-Log -Level Debug -Message "Quick Actions DataTable created with data:"
                    foreach ($item in $self.Components.quickActions.Data) {
                        Write-Log -Level Debug -Message "  Action: '$($item.Action)' (Length: $($item.Action.Length))"
                    }
                    
                    # Force process data to ensure display
                    if ($self.Components.quickActions.ProcessData) {
                        & $self.Components.quickActions.ProcessData -self $self.Components.quickActions
                        Write-Log -Level Debug -Message "ProcessedData count: $($self.Components.quickActions.ProcessedData.Count)"
                        if ($self.Components.quickActions.ProcessedData.Count -gt 0) {
                            Write-Log -Level Debug -Message "First processed item: $($self.Components.quickActions.ProcessedData[0] | ConvertTo-Json -Compress)"
                        }
                    }
                    Write-Log -Level Debug -Message "Quick Actions DataTable ProcessData called"
                } else {
                    Write-Log -Level Warning -Message "DataTable component not available, using basic rendering"
                    # Fallback to simple rendering
                    $self.Components.quickActions = @{
                        Type = "QuickActionsList"
                        X = 2; Y = 4; Width = 35; Height = 12
                        IsFocusable = $true
                        Visible = $true
                        SelectedIndex = 0
                        Items = @(
                            "1. Add Time Entry"
                            "2. Start Timer"
                            "3. Manage Tasks"
                            "4. Manage Projects"
                            "5. View Reports"
                            "6. Settings"
                        )
                        Render = {
                            param($self)
                            $y = $self.Y
                            foreach ($i in 0..($self.Items.Count - 1)) {
                                $item = $self.Items[$i]
                                $fg = if ($self.IsFocused -and $i -eq $self.SelectedIndex) { 
                                    Get-ThemeColor "Accent" -Default ([ConsoleColor]::Cyan)
                                } else { 
                                    Get-ThemeColor "Primary" -Default ([ConsoleColor]::White)
                                }
                                Write-BufferString -X $self.X -Y $y -Text $item -ForegroundColor $fg
                                $y++
                            }
                        }
                        HandleInput = {
                            param($self, $Key)
                            switch ($Key.Key) {
                                ([ConsoleKey]::UpArrow) {
                                    if ($self.SelectedIndex -gt 0) {
                                        $self.SelectedIndex--
                                        Request-TuiRefresh
                                    }
                                    return $true
                                }
                                ([ConsoleKey]::DownArrow) {
                                    if ($self.SelectedIndex -lt $self.Items.Count - 1) {
                                        $self.SelectedIndex++
                                        Request-TuiRefresh
                                    }
                                    return $true
                                }
                                ([ConsoleKey]::Enter) {
                                    switch ($self.SelectedIndex) {
                                        0 { if (Get-Command Get-TimeEntryFormScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TimeEntryFormScreen) } }
                                        1 { if (Get-Command Get-TimerStartScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TimerStartScreen) } }
                                        2 { if (Get-Command Get-TaskScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TaskScreen) } }
                                        3 { if (Get-Command Get-ProjectManagementScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-ProjectManagementScreen) } }
                                        4 { if (Get-Command Get-ReportsScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-ReportsScreen) } }
                                        5 { if (Get-Command Get-SettingsScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-SettingsScreen) } }
                                    }
                                    return $true
                                }
                            }
                            return $false
                        }
                    }
                }
                
                # Active Timers
                if (Get-Command New-TuiDataTable -ErrorAction SilentlyContinue) {
                    $self.Components.activeTimers = New-TuiDataTable -Props @{
                        X = 40; Y = 4; Width = 40; Height = 12
                        IsFocusable = $true
                        ShowBorder = $false  # Parent screen draws the border
                        Columns = @(
                            @{ Name = "Project"; Header = "Project"; Width = 20 }
                            @{ Name = "Time"; Header = "Time"; Width = 10 }
                        )
                        Data = @()
                        AllowSort = $false
                        AllowFilter = $false
                        MultiSelect = $false
                        Title = "Active Timers"
                        ShowFooter = $false
                    }
                    # Force process data to ensure display
                    if ($self.Components.activeTimers.ProcessData) {
                        & $self.Components.activeTimers.ProcessData -self $self.Components.activeTimers
                    }
                    Write-Log -Level Debug -Message "Active Timers DataTable created"
                }
                
                # Today's Tasks
                if (Get-Command New-TuiDataTable -ErrorAction SilentlyContinue) {
                    $self.Components.todaysTasks = New-TuiDataTable -Props @{
                        X = 2; Y = 18; Width = 78; Height = 10
                        IsFocusable = $true
                        ShowBorder = $false  # Parent screen draws the border
                        Columns = @(
                            @{ Name = "Priority"; Header = "Pri"; Width = 8 }
                            @{ Name = "Description"; Header = "Task"; Width = 50 }
                            @{ Name = "Project"; Header = "Project"; Width = 15 }
                        )
                        Data = @()
                        AllowSort = $true
                        AllowFilter = $false
                        MultiSelect = $false
                        Title = "Today's Tasks"
                        ShowFooter = $false
                    }
                    # Force process data to ensure display
                    if ($self.Components.todaysTasks.ProcessData) {
                        & $self.Components.todaysTasks.ProcessData -self $self.Components.todaysTasks
                    }
                    Write-Log -Level Debug -Message "Today's Tasks DataTable created"
                }
                
                # Stats Labels
                $self.Components.statsLabel = New-TuiLabel -Props @{
                    X = 84; Y = 4; Text = "Today's Stats"
                }
                
                $self.Components.todayHoursLabel = New-TuiLabel -Props @{
                    X = 84; Y = 6; Text = "Today: 0h"
                }
                
                $self.Components.weekHoursLabel = New-TuiLabel -Props @{
                    X = 84; Y = 8; Text = "Week: 0h"
                }
                
                $self.Components.activeTasksLabel = New-TuiLabel -Props @{
                    X = 84; Y = 10; Text = "Tasks: 0"
                }
                
                $self.Components.runningTimersLabel = New-TuiLabel -Props @{
                    X = 84; Y = 12; Text = "Timers: 0"
                }
                
                Write-Log -Level Debug -Message "Stats labels created"
                
                # Initial refresh - call with the screen as parameter
                & $self.RefreshData -screen $self
                
            } catch {
                Write-Log -Level Error -Message "Dashboard Init error: $_" -Data $_
            }
        }
        
        # 4. Render: Draw the screen and its components
        Render = {
            param($self)
            
            try {
                # Auto-refresh check
                if (([DateTime]::Now - $self.State.LastRefresh).TotalSeconds -gt $self.State.AutoRefreshInterval) {
                    & $self.RefreshData -screen $self
                    $self.State.LastRefresh = [DateTime]::Now
                }
                
                # Header
                $headerColor = Get-ThemeColor "Header" -Default ([ConsoleColor]::Cyan)
                $currentTime = Get-Date -Format 'dddd, MMMM dd, yyyy HH:mm:ss'
                Write-BufferString -X 2 -Y 1 -Text "PMC Terminal Dashboard - $currentTime" -ForegroundColor $headerColor
                
                # Active timer indicator
                if ($self.State.QuickStats.RunningTimers -gt 0) {
                    $timerText = "● TIMER ACTIVE"
                    $timerX = $global:TuiState.BufferWidth - $timerText.Length - 2
                    Write-BufferString -X $timerX -Y 1 -Text $timerText -ForegroundColor Red
                }
                
                # Draw boxes for organization
                Write-BufferBox -X 1 -Y 3 -Width 37 -Height 14 -Title " Quick Actions " -BorderColor (Get-ThemeColor "Accent" -Default ([ConsoleColor]::Cyan))
                Write-BufferBox -X 39 -Y 3 -Width 42 -Height 14 -Title " Active Timers " -BorderColor (Get-ThemeColor "Info" -Default ([ConsoleColor]::Blue))
                Write-BufferBox -X 83 -Y 3 -Width 20 -Height 14 -Title " Stats " -BorderColor (Get-ThemeColor "Success" -Default ([ConsoleColor]::Green))
                Write-BufferBox -X 1 -Y 17 -Width 80 -Height 12 -Title " Today's Tasks " -BorderColor (Get-ThemeColor "Warning" -Default ([ConsoleColor]::Yellow))
                
                # Render all components (only top-level ones without parents)
                foreach ($kvp in $self.Components.GetEnumerator()) {
                    $component = $kvp.Value
                    if ($component -and $component.Visible -ne $false -and -not $component.Parent) {
                        # Set focus state based on screen's tracking
                        $component.IsFocused = ($self.FocusedComponentName -eq $kvp.Key)
                        if ($component.Render) {
                            & $component.Render -self $component
                        }
                    }
                }
                
                # Status bar
                $subtleColor = Get-ThemeColor "Subtle" -Default ([ConsoleColor]::DarkGray)
                $statusY = $global:TuiState.BufferHeight - 2
                Write-BufferString -X 2 -Y $statusY -Text "Tab: Switch Focus | Enter: Select | R: Refresh | Q: Quit | F12: Debug Log" -ForegroundColor $subtleColor
                
            } catch {
                Write-Log -Level Error -Message "Dashboard Render error: $_" -Data $_
                Write-BufferString -X 2 -Y 2 -Text "Error rendering dashboard: $_" -ForegroundColor Red
            }
        }
        
        # 5. HandleInput: Global input handling for the screen
        HandleInput = {
            param($self, $Key)
            
            try {
                # Debug log access
                if ($Key.Key -eq [ConsoleKey]::F12) {
                    if (Get-Command Get-DebugLogScreen -ErrorAction SilentlyContinue) {
                        Push-Screen -Screen (Get-DebugLogScreen)
                    }
                    return $true
                }
                
                # Debug overlay toggle
                if ($Key.Key -eq [ConsoleKey]::F10) {
                    $global:TuiState.DebugOverlayEnabled = -not $global:TuiState.DebugOverlayEnabled
                    Request-TuiRefresh
                    return $true
                }
                
                # Screen-level shortcuts
                switch ($Key.Key) {
                    ([ConsoleKey]::R) {
                        # Manual refresh
                        Write-Log -Level Debug -Message "Manual refresh requested"
                        & $self.RefreshData -screen $self
                        Request-TuiRefresh
                        return $true
                    }
                    ([ConsoleKey]::Q) { 
                        Write-Log -Level Debug -Message "Quit requested"
                        return "Quit" 
                    }
                    ([ConsoleKey]::Escape) { 
                        Write-Log -Level Debug -Message "Escape pressed - quitting"
                        return "Quit" 
                    }
                    ([ConsoleKey]::Tab) {
                        # Cycle focus between tables
                        $focusableComponents = @("quickActions", "activeTimers", "todaysTasks") | 
                            Where-Object { $self.Components.$_ -and $self.Components.$_.IsFocusable }
                        
                        if ($focusableComponents.Count -gt 0) {
                            $currentIndex = [array]::IndexOf($focusableComponents, $self.FocusedComponentName)
                            if ($Key.Modifiers -band [ConsoleModifiers]::Shift) {
                                # Shift+Tab - go backwards
                                $nextIndex = ($currentIndex - 1 + $focusableComponents.Count) % $focusableComponents.Count
                            } else {
                                # Tab - go forwards
                                $nextIndex = ($currentIndex + 1) % $focusableComponents.Count
                            }
                            $self.FocusedComponentName = $focusableComponents[$nextIndex]
                            
                            # Update engine's focus tracking
                            $focusedComponent = $self.Components[$self.FocusedComponentName]
                            if ($focusedComponent -and (Get-Command Set-ComponentFocus -ErrorAction SilentlyContinue)) {
                                Set-ComponentFocus -Component $focusedComponent
                            }
                            
                            Write-Log -Level Debug -Message "Focus changed to: $($self.FocusedComponentName)"
                            Request-TuiRefresh
                        }
                        return $true
                    }
                }
                
                # Number keys for quick actions
                if ($Key.KeyChar -ge '1' -and $Key.KeyChar -le '6') {
                    $index = [int]$Key.KeyChar.ToString() - 1
                    Write-Log -Level Debug -Message "Number key pressed: $($Key.KeyChar)"
                    switch ($index) {
                        0 { if (Get-Command Get-TimeEntryFormScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TimeEntryFormScreen) } }
                        1 { if (Get-Command Get-TimerStartScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TimerStartScreen) } }
                        2 { if (Get-Command Get-TaskScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TaskScreen) } elseif (Get-Command Get-TaskManagementScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TaskManagementScreen) } }
                        3 { if (Get-Command Get-ProjectManagementScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-ProjectManagementScreen) } }
                        4 { if (Get-Command Get-ReportsScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-ReportsScreen) } }
                        5 { if (Get-Command Get-SettingsScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-SettingsScreen) } }
                    }
                    return $true
                }
                
                # Delegate to focused component
                $focusedComponent = if ($self.FocusedComponentName) { $self.Components[$self.FocusedComponentName] } else { $null }
                if ($focusedComponent -and $focusedComponent.HandleInput) {
                    $result = & $focusedComponent.HandleInput -self $focusedComponent -Key $Key
                    if ($result) {
                        Request-TuiRefresh
                        return $true
                    }
                }
                
            } catch {
                Write-Log -Level Error -Message "HandleInput error: $_" -Data $_
            }
            
            return $false
        }
        
        # 6. Lifecycle Hooks
        OnExit = {
            param($self)
            Write-Log -Level Debug -Message "Dashboard screen exiting"
        }
        
        OnResume = {
            param($self)
            Write-Log -Level Debug -Message "Dashboard screen resuming"
            
            # Force complete buffer redraw to clear any artifacts from previous screen
            if ($global:TuiState -and $global:TuiState.RenderStats) {
                $global:TuiState.RenderStats.FrameCount = 0
            }
            
            # Refresh data when returning to dashboard
            & $self.RefreshData -screen $self
            
            # Restore focus to the first focusable component
            if (-not $self.FocusedComponentName -or -not $self.Components[$self.FocusedComponentName]) {
                $self.FocusedComponentName = "quickActions"
            }
            
            # Ensure the focused component knows it's focused
            foreach ($kvp in $self.Components.GetEnumerator()) {
                $component = $kvp.Value
                if ($component) {
                    $component.IsFocused = ($kvp.Key -eq $self.FocusedComponentName)
                }
            }
            
            # Set engine focus to match screen's focus
            $focusedComponent = $self.Components[$self.FocusedComponentName]
            if ($focusedComponent -and (Get-Command Set-ComponentFocus -ErrorAction SilentlyContinue)) {
                Set-ComponentFocus -Component $focusedComponent
            }
            
            Request-TuiRefresh
        }
    }
    
    return $screen
}

Export-ModuleMember -Function Get-DashboardScreen