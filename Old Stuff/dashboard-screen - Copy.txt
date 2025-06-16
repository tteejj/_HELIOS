# Enhanced Dashboard Screen v4.0 - Using New TUI Engine Features
# Implements proper event handling, error management, and theme support

function global:Get-DashboardScreen {
    
    $dashboardScreen = @{
        Name = "DashboardScreen"
        State = @{
            ActiveTimers = @()
            TodaysTasks = @()
            RecentEntries = @()
            QuickStats = @{}
            SelectedQuickAction = 0
            EventHandlers = @()  # Track subscriptions for cleanup
            LastRefresh = [DateTime]::MinValue
            AutoRefreshInterval = 5  # seconds
        }
        
        Init = {
            param($self)
            try {
                # Initial data refresh
                $self.RefreshAllData.Invoke($self)
                
                # Subscribe to data change events if event system is available
                if (Get-Command -Name "Subscribe-TuiEvent" -ErrorAction SilentlyContinue) {
                    # Timer events
                    $handlerId = Subscribe-TuiEvent -EventName "Data.Timer.Started" -Handler {
                        $self.RefreshActiveTimers.Invoke($self)
                        Request-TuiRefresh
                    }
                    $self.State.EventHandlers += $handlerId
                    
                    $handlerId = Subscribe-TuiEvent -EventName "Data.Timer.Stopped" -Handler {
                        $self.RefreshActiveTimers.Invoke($self)
                        $self.RefreshQuickStats.Invoke($self)
                        Request-TuiRefresh
                    }
                    $self.State.EventHandlers += $handlerId
                    
                    # Time entry events
                    $handlerId = Subscribe-TuiEvent -EventName "Data.TimeEntry.Created" -Handler {
                        $self.RefreshRecentEntries.Invoke($self)
                        $self.RefreshQuickStats.Invoke($self)
                        Request-TuiRefresh
                    }
                    $self.State.EventHandlers += $handlerId
                    
                    # Task events
                    $handlerId = Subscribe-TuiEvent -EventName "Data.Task.Created" -Handler {
                        $self.RefreshTodaysTasks.Invoke($self)
                        $self.RefreshQuickStats.Invoke($self)
                        Request-TuiRefresh
                    }
                    $self.State.EventHandlers += $handlerId
                    
                    $handlerId = Subscribe-TuiEvent -EventName "Data.Task.Updated" -Handler {
                        $self.RefreshTodaysTasks.Invoke($self)
                        $self.RefreshQuickStats.Invoke($self)
                        Request-TuiRefresh
                    }
                    $self.State.EventHandlers += $handlerId
                }
            } catch {
                Write-Warning "Dashboard init error: $_"
            }
        }
        
        OnExit = {
            param($self)
            # Cleanup event subscriptions
            if (Get-Command -Name "Unsubscribe-Event" -ErrorAction SilentlyContinue) {
                foreach ($handlerId in $self.State.EventHandlers) {
                    try {
                        Unsubscribe-Event -HandlerId $handlerId
                    } catch {
                        Write-Warning "Failed to unsubscribe event: $_"
                    }
                }
            }
        }
        
        OnResume = {
            param($self)
            # Refresh data when returning to dashboard
            $self.RefreshAllData.Invoke($self)
        }
        
        Render = {
            param($self)
            try {
                # Auto-refresh check
                if (([DateTime]::Now - $self.State.LastRefresh).TotalSeconds -gt $self.State.AutoRefreshInterval) {
                    $self.RefreshActiveTimers.Invoke($self)  # Only refresh time-sensitive data
                    $self.State.LastRefresh = [DateTime]::Now
                }
                
                # Header with current time
                $headerColor = Get-ThemeColor "Header" -Default "Cyan"
                $currentTime = Get-Date -Format 'dddd, MMMM dd, yyyy HH:mm:ss'
                Write-BufferString -X 2 -Y 1 -Text "PMC Terminal Dashboard - $currentTime" -ForegroundColor $headerColor
                
                # Active timer indicator
                if ($self.State.ActiveTimers.Count -gt 0) {
                    $timerText = "● TIMER ACTIVE"
                    $timerX = $global:TuiState.BufferWidth - $timerText.Length - 2
                    Write-BufferString -X $timerX -Y 1 -Text $timerText -ForegroundColor "Red"
                }
                
                # Layout calculation for responsive design
                $totalWidth = $global:TuiState.BufferWidth - 4
                $columnWidth = [Math]::Floor($totalWidth / 3)
                $leftCol = 2
                $centerCol = $leftCol + $columnWidth + 1
                $rightCol = $centerCol + $columnWidth + 1
                
                # Quick Actions (Left Column)
                $accentColor = Get-ThemeColor "Accent" -Default "Yellow"
                Write-BufferBox -X $leftCol -Y 3 -Width $columnWidth -Height 12 -Title " Quick Actions " -BorderColor $accentColor
                $self.RenderQuickActions.Invoke($self, ($leftCol + 2), 5)
                
                # Quick Stats (Center Column)
                $successColor = Get-ThemeColor "Success" -Default "Green"
                Write-BufferBox -X $centerCol -Y 3 -Width $columnWidth -Height 12 -Title " Today's Stats " -BorderColor $successColor
                $self.RenderQuickStats.Invoke($self, ($centerCol + 2), 5)
                
                # Active Timers (Right Column)
                $infoColor = Get-ThemeColor "Info" -Default "Cyan"
                Write-BufferBox -X $rightCol -Y 3 -Width $columnWidth -Height 12 -Title " Active Timers " -BorderColor $infoColor
                $self.RenderActiveTimers.Invoke($self, ($rightCol + 2), 5)
                
                # Recent Entries (Bottom Left)
                $primaryColor = Get-ThemeColor "Primary" -Default "Blue"
                $bottomWidth = [Math]::Floor(($totalWidth - 2) / 2)
                Write-BufferBox -X $leftCol -Y 16 -Width $bottomWidth -Height 8 -Title " Recent Time Entries " -BorderColor $primaryColor
                $self.RenderRecentEntries.Invoke($self, ($leftCol + 2), 18)
                
                # Today's Tasks (Bottom Right)
                $warningColor = Get-ThemeColor "Warning" -Default "Magenta"
                $rightBottomX = $leftCol + $bottomWidth + 2
                Write-BufferBox -X $rightBottomX -Y 16 -Width $bottomWidth -Height 8 -Title " Today's Tasks " -BorderColor $warningColor
                $self.RenderTodaysTasks.Invoke($self, ($rightBottomX + 2), 18)
                
                # Status bar
                $subtleColor = Get-ThemeColor "Subtle" -Default "Gray"
                $statusY = $global:TuiState.BufferHeight - 2
                Write-BufferString -X 2 -Y $statusY -Text "↑↓ Navigate • Enter: Select • R: Refresh • P: Command Palette • Q: Quit" -ForegroundColor $subtleColor
            } catch {
                Write-Warning "Dashboard render error: $_"
                Write-BufferString -X 2 -Y 2 -Text "Error rendering dashboard: $_" -ForegroundColor "Red"
            }
        }
        
        HandleInput = {
            param($self, $Key)
            try {
                switch ($Key.Key) {
                    ([ConsoleKey]::UpArrow) { 
                        $self.State.SelectedQuickAction = [Math]::Max(0, $self.State.SelectedQuickAction - 1)
                        Request-TuiRefresh
                        return $true 
                    }
                    ([ConsoleKey]::DownArrow) { 
                        $maxActions = $self.GetQuickActions.Invoke($self).Count - 1
                        $self.State.SelectedQuickAction = [Math]::Min($maxActions, $self.State.SelectedQuickAction + 1)
                        Request-TuiRefresh
                        return $true 
                    }
                    ([ConsoleKey]::Enter) { 
                        $selectedAction = $self.GetQuickActions.Invoke($self)[$self.State.SelectedQuickAction]
                        if ($selectedAction -and $selectedAction.Action) {
                            try {
                                & $selectedAction.Action
                            } catch {
                                Write-Warning "Action execution error: $_"
                            }
                        }
                        return $true 
                    }
                    ([ConsoleKey]::R) {
                        # Manual refresh
                        $self.RefreshAllData.Invoke($self)
                        Request-TuiRefresh
                        return $true
                    }
                    ([ConsoleKey]::P) {
                        # Command palette
                        if (Get-Command Get-CommandPaletteScreen -ErrorAction SilentlyContinue) {
                            Push-Screen -Screen (Get-CommandPaletteScreen)
                        }
                        return $true
                    }
                    ([ConsoleKey]::Q) { return "Quit" }
                    ([ConsoleKey]::Escape) { return "Quit" }
                }
                
                # Number keys for quick action selection
                if ($Key.KeyChar -ge '1' -and $Key.KeyChar -le '9') {
                    $index = [int]$Key.KeyChar.ToString() - 1
                    $actions = $self.GetQuickActions.Invoke($self)
                    if ($index -lt $actions.Count) {
                        $self.State.SelectedQuickAction = $index
                        if ($actions[$index].Action) {
                            & $actions[$index].Action
                        }
                    }
                    return $true
                }
            } catch {
                Write-Warning "Dashboard input error: $_"
            }
            return $false
        }
        
        RefreshAllData = { 
            param($self)
            try {
                $self.RefreshActiveTimers.Invoke($self)
                $self.RefreshTodaysTasks.Invoke($self)
                $self.RefreshRecentEntries.Invoke($self)
                $self.RefreshQuickStats.Invoke($self)
            } catch {
                Write-Warning "Data refresh error: $_"
            }
        }
        
        RefreshActiveTimers = { 
            param($self)
            try {
                if ($global:Data -and $global:Data.ActiveTimers) {
                    $self.State.ActiveTimers = @($global:Data.ActiveTimers.GetEnumerator() | ForEach-Object {
                        $timer = $_.Value
                        if ($timer -and $timer.StartTime) {
                            $elapsed = (Get-Date) - [DateTime]$timer.StartTime
                            @{
                                Key = $_.Key
                                ProjectKey = $timer.ProjectKey
                                TaskId = $timer.TaskId
                                Description = $timer.Description
                                StartTime = $timer.StartTime
                                Elapsed = $elapsed
                                ElapsedDisplay = "{0:00}:{1:00}:{2:00}" -f [Math]::Floor($elapsed.TotalHours), $elapsed.Minutes, $elapsed.Seconds
                            }
                        }
                    } | Where-Object { $_ } | Select-Object -First 5)
                } else {
                    $self.State.ActiveTimers = @()
                }
            } catch {
                Write-Warning "Timer refresh error: $_"
                $self.State.ActiveTimers = @()
            }
        }
        
        RefreshTodaysTasks = { 
            param($self)
            try {
                if ($global:Data -and $global:Data.Tasks) {
                    $today = (Get-Date).ToString("yyyy-MM-dd")
                    $self.State.TodaysTasks = @($global:Data.Tasks | Where-Object { 
                        $_ -and (-not $_.Completed) -and 
                        ($_.DueDate -eq $today -or [string]::IsNullOrEmpty($_.DueDate))
                    } | Sort-Object Priority, DueDate | Select-Object -First 5)
                } else {
                    $self.State.TodaysTasks = @()
                }
            } catch {
                Write-Warning "Tasks refresh error: $_"
                $self.State.TodaysTasks = @()
            }
        }
        
        RefreshRecentEntries = { 
            param($self)
            try {
                if ($global:Data -and $global:Data.TimeEntries) {
                    $self.State.RecentEntries = @($global:Data.TimeEntries | 
                        Where-Object { $_ } |
                        Sort-Object Date -Descending | 
                        Select-Object -First 5)
                } else {
                    $self.State.RecentEntries = @()
                }
            } catch {
                Write-Warning "Entries refresh error: $_"
                $self.State.RecentEntries = @()
            }
        }
        
        RefreshQuickStats = { 
            param($self)
            try {
                $today = (Get-Date).ToString("yyyy-MM-dd")
                $stats = @{ TodayHours = 0; ActiveTasks = 0; RunningTimers = 0; WeekHours = 0 }
                
                if ($global:Data) {
                    # Today's hours
                    if ($global:Data.TimeEntries) {
                        $todayEntries = @($global:Data.TimeEntries | Where-Object { $_ -and $_.Date -eq $today })
                        $stats.TodayHours = [Math]::Round(($todayEntries | Measure-Object -Property Hours -Sum).Sum, 2)
                        
                        # Week hours
                        $weekStart = (Get-Date).AddDays(-[int](Get-Date).DayOfWeek).Date
                        $weekEntries = @($global:Data.TimeEntries | Where-Object { 
                            $_ -and $_.Date -and ([DateTime]::Parse($_.Date) -ge $weekStart)
                        })
                        $stats.WeekHours = [Math]::Round(($weekEntries | Measure-Object -Property Hours -Sum).Sum, 2)
                    }
                    
                    # Active tasks
                    if ($global:Data.Tasks) {
                        $stats.ActiveTasks = @($global:Data.Tasks | Where-Object { $_ -and -not $_.Completed }).Count
                    }
                    
                    # Running timers
                    if ($global:Data.ActiveTimers) {
                        $stats.RunningTimers = $global:Data.ActiveTimers.Count
                    }
                }
                
                $self.State.QuickStats = $stats
            } catch {
                Write-Warning "Stats refresh error: $_"
                $self.State.QuickStats = @{ TodayHours = 0; ActiveTasks = 0; RunningTimers = 0; WeekHours = 0 }
            }
        }
        
        GetQuickActions = { 
            param($self)
            return @( 
                @{ 
                    Name = "1. Add Time Entry"
                    Icon = "⏰"
                    Action = { 
                        if (Get-Command Get-TimeEntryScreen -ErrorAction SilentlyContinue) { 
                            Push-Screen -Screen (Get-TimeEntryScreen) 
                        } 
                    } 
                },
                @{ 
                    Name = "2. Start Timer"
                    Icon = "▶️"
                    Action = { 
                        if (Get-Command Get-TimerStartScreen -ErrorAction SilentlyContinue) { 
                            Push-Screen -Screen (Get-TimerStartScreen) 
                        } 
                    } 
                },
                @{ 
                    Name = "3. Manage Tasks"
                    Icon = "📋"
                    Action = { 
                        if (Get-Command Get-TaskManagementScreen -ErrorAction SilentlyContinue) { 
                            Push-Screen -Screen (Get-TaskManagementScreen) 
                        } 
                    } 
                },
                @{ 
                    Name = "4. Manage Projects"
                    Icon = "📁"
                    Action = { 
                        if (Get-Command Get-ProjectManagementScreen -ErrorAction SilentlyContinue) { 
                            Push-Screen -Screen (Get-ProjectManagementScreen) 
                        } 
                    } 
                },
                @{ 
                    Name = "5. View Reports"
                    Icon = "📊"
                    Action = { 
                        if (Get-Command Get-ReportsScreen -ErrorAction SilentlyContinue) { 
                            Push-Screen -Screen (Get-ReportsScreen) 
                        } 
                    } 
                },
                @{ 
                    Name = "6. Settings"
                    Icon = "⚙️"
                    Action = { 
                        if (Get-Command Get-SettingsScreen -ErrorAction SilentlyContinue) { 
                            Push-Screen -Screen (Get-SettingsScreen) 
                        } 
                    } 
                }
            )
        }
        
        RenderQuickActions = { 
            param($self, $x, $y)
            try {
                $actions = $self.GetQuickActions.Invoke($self)
                $maxWidth = $global:TuiState.BufferWidth / 3 - 4
                
                for ($i = 0; $i -lt $actions.Count; $i++) { 
                    $isSelected = ($i -eq $self.State.SelectedQuickAction)
                    $prefix = if ($isSelected) { "→ " } else { "  " }
                    $color = if ($isSelected) { 
                        Get-ThemeColor "Warning" -Default "Yellow"
                    } else { 
                        Get-ThemeColor "Primary" -Default "White"
                    }
                    
                    $text = "$prefix$($actions[$i].Icon) $($actions[$i].Name)"
                    if ($text.Length -gt $maxWidth) {
                        $text = $text.Substring(0, $maxWidth - 3) + "..."
                    }
                    
                    Write-BufferString -X $x -Y ($y + $i) -Text $text -ForegroundColor $color
                }
            } catch {
                Write-Warning "Quick actions render error: $_"
            }
        }
        
        RenderActiveTimers = { 
            param($self, $x, $y)
            try {
                $maxWidth = $global:TuiState.BufferWidth / 3 - 4
                
                if ($self.State.ActiveTimers.Count -eq 0) { 
                    $subtleColor = Get-ThemeColor "Subtle" -Default "Gray"
                    Write-BufferString -X $x -Y $y -Text "No active timers" -ForegroundColor $subtleColor
                } else { 
                    $currentY = $y
                    foreach ($timer in $self.State.ActiveTimers) { 
                        if ($timer) {
                            # Project/Task info
                            $project = if ($global:Data.Projects -and $timer.ProjectKey) {
                                $global:Data.Projects[$timer.ProjectKey]
                            } else { $null }
                            
                            $projectName = if ($project) { $project.Name } else { "Unknown" }
                            if ($projectName.Length -gt ($maxWidth - 10)) {
                                $projectName = $projectName.Substring(0, $maxWidth - 13) + "..."
                            }
                            
                            $infoColor = Get-ThemeColor "Info" -Default "Cyan"
                            Write-BufferString -X $x -Y $currentY -Text $projectName -ForegroundColor $infoColor
                            
                            # Time display
                            $accentColor = Get-ThemeColor "Accent" -Default "Yellow"
                            Write-BufferString -X ($x + 2) -Y ($currentY + 1) -Text $timer.ElapsedDisplay -ForegroundColor $accentColor
                            
                            $currentY += 2
                            if ($currentY -gt ($y + 8)) { break }  # Prevent overflow
                        }
                    } 
                }
            } catch {
                Write-Warning "Timers render error: $_"
                Write-BufferString -X $x -Y $y -Text "Error displaying timers" -ForegroundColor "Red"
            }
        }
        
        RenderTodaysTasks = { 
            param($self, $x, $y)
            try {
                $maxWidth = $global:TuiState.BufferWidth / 2 - 6
                
                if ($self.State.TodaysTasks.Count -eq 0) { 
                    $subtleColor = Get-ThemeColor "Subtle" -Default "Gray"
                    Write-BufferString -X $x -Y $y -Text "No tasks for today" -ForegroundColor $subtleColor
                } else { 
                    $currentY = $y
                    foreach ($task in $self.State.TodaysTasks) { 
                        if ($task -and $task.Description) {
                            # Priority indicator
                            $priorityIcon = switch ($task.Priority) {
                                "Critical" { "🔴" }
                                "High" { "🟡" }
                                "Medium" { "🟢" }
                                default { "⚪" }
                            }
                            
                            $taskText = "$priorityIcon $($task.Description)"
                            if ($taskText.Length -gt $maxWidth) { 
                                $taskText = $taskText.Substring(0, $maxWidth - 3) + "..." 
                            }
                            
                            $primaryColor = Get-ThemeColor "Primary" -Default "White"
                            Write-BufferString -X $x -Y $currentY -Text $taskText -ForegroundColor $primaryColor
                            $currentY++
                            
                            if ($currentY -gt ($y + 5)) { break }  # Prevent overflow
                        }
                    } 
                }
            } catch {
                Write-Warning "Tasks render error: $_"
                Write-BufferString -X $x -Y $y -Text "Error displaying tasks" -ForegroundColor "Red"
            }
        }
        
        RenderRecentEntries = { 
            param($self, $x, $y)
            try {
                $maxWidth = $global:TuiState.BufferWidth / 2 - 6
                
                if ($self.State.RecentEntries.Count -eq 0) { 
                    $subtleColor = Get-ThemeColor "Subtle" -Default "Gray"
                    Write-BufferString -X $x -Y $y -Text "No recent entries" -ForegroundColor $subtleColor
                } else { 
                    $currentY = $y
                    foreach ($entry in $self.State.RecentEntries) {
                        if ($entry -and $entry.Hours -and $entry.Date) {
                            # Format: Date - Hours - Project
                            $project = if ($global:Data.Projects -and $entry.ProjectKey) {
                                $global:Data.Projects[$entry.ProjectKey]
                            } else { $null }
                            
                            $projectName = if ($project) { $project.Name } else { "Unknown" }
                            $entryText = "$($entry.Date): $($entry.Hours)h - $projectName"
                            
                            if ($entryText.Length -gt $maxWidth) { 
                                $entryText = $entryText.Substring(0, $maxWidth - 3) + "..." 
                            }
                            
                            $primaryColor = Get-ThemeColor "Primary" -Default "White"
                            Write-BufferString -X $x -Y $currentY -Text $entryText -ForegroundColor $primaryColor
                            $currentY++
                            
                            if ($currentY -gt ($y + 5)) { break }  # Prevent overflow
                        }
                    } 
                }
            } catch {
                Write-Warning "Entries render error: $_"
                Write-BufferString -X $x -Y $y -Text "Error displaying entries" -ForegroundColor "Red"
            }
        }
        
        RenderQuickStats = { 
            param($self, $x, $y)
            try {
                if ($self.State.QuickStats) {
                    $stats = $self.State.QuickStats
                    $labelColor = Get-ThemeColor "Subtle" -Default "Gray"
                    $valueColor = Get-ThemeColor "Success" -Default "Green"
                    
                    # Today's hours
                    Write-BufferString -X $x -Y $y -Text "Today:" -ForegroundColor $labelColor
                    Write-BufferString -X ($x + 8) -Y $y -Text "$($stats.TodayHours)h" -ForegroundColor $valueColor
                    
                    # Week hours
                    Write-BufferString -X $x -Y ($y + 2) -Text "Week:" -ForegroundColor $labelColor
                    Write-BufferString -X ($x + 8) -Y ($y + 2) -Text "$($stats.WeekHours)h" -ForegroundColor $valueColor
                    
                    # Active tasks
                    $warningColor = Get-ThemeColor "Warning" -Default "Yellow"
                    Write-BufferString -X $x -Y ($y + 4) -Text "Tasks:" -ForegroundColor $labelColor
                    Write-BufferString -X ($x + 8) -Y ($y + 4) -Text "$($stats.ActiveTasks)" -ForegroundColor $warningColor
                    
                    # Running timers
                    $infoColor = Get-ThemeColor "Info" -Default "Cyan"
                    Write-BufferString -X $x -Y ($y + 6) -Text "Timers:" -ForegroundColor $labelColor
                    Write-BufferString -X ($x + 8) -Y ($y + 6) -Text "$($stats.RunningTimers)" -ForegroundColor $infoColor
                }
            } catch {
                Write-Warning "Stats render error: $_"
                Write-BufferString -X $x -Y $y -Text "Error displaying stats" -ForegroundColor "Red"
            }
        }
    }
    
    return $dashboardScreen
}

Export-ModuleMember -Function Get-DashboardScreen