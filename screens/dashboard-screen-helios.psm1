# Dashboard Screen - Helios Service-Based Version (FIXED)
# Conforms to Z-Index rendering and proper service injection patterns

function Get-DashboardScreen {
    param([hashtable]$Services)

    $screen = @{
        Name = "DashboardScreen"
        Components = @{}
        Children = @()   # FIX: Added Children array for the Z-Index renderer to discover components.
        _subscriptions = @()
        Visible = $true
        ZIndex = 0

        Init = {
    param($self, $services)
    
    Write-Log -Level Debug -Message "Dashboard Init started (Helios version)"
    
    try {
        # FIX: More robust services handling
        if (-not $services) {
            if ($self._services) {
                $services = $self._services
            }
            elseif ($global:Services) {
                $services = $global:Services
                $self._services = $services
            }
            else {
                Write-Log -Level Error -Message "Services not available for dashboard screen - no fallback found"
                return
            }
        }
        else {
            $self._services = $services
        }
        
        # Create the main grid layout
        $rootPanel = New-TuiGridPanel -Props @{
            X = 1; Y = 2; Width = ($global:TuiState.BufferWidth - 2); Height = ($global:TuiState.BufferHeight - 4)
            ShowBorder = $false; RowDefinitions = @("14", "1*"); ColumnDefinitions = @("37", "42", "1*")
            ShowGridLines = $false  # Set to true to debug layout
        }
        $self.Components.rootPanel = $rootPanel
        $self.Children += $rootPanel
        
        Write-Log -Level Debug -Message "Dashboard: Created rootPanel, Children count=$($self.Children.Count)"

        # --- Quick Actions Panel ---
        $quickActionsPanel = New-TuiStackPanel -Props @{ Name = "quickActionsPanel"; Title = " Quick Actions "; ShowBorder = $true; Padding = 1 }
        
        # Store services on self BEFORE creating components
        $self._navigationServices = $services
        
        # Capture services for use in handler
        $capturedServices = $services
        
        $quickActions = New-TuiDataTable -Props @{
            Name = "quickActions"; IsFocusable = $true; ShowBorder = $false; ShowHeader = $false; ShowFooter = $false
            Columns = @( @{ Name = "Action"; Width = 32 } )
            Data = @(
                @{ Action = "[1] New Time Entry" },
                @{ Action = "[2] Start Timer" },
                @{ Action = "[3] View Tasks" },
                @{ Action = "[4] View Projects" },
                @{ Action = "[5] Reports" },
                @{ Action = "[6] Settings" }
            )
            OnRowSelect = {
                param($SelectedData, $SelectedIndex)
                $routes = @("/time-entry", "/timer/start", "/tasks", "/projects", "/reports", "/settings")
                
                if ($SelectedIndex -ge 0 -and $SelectedIndex -lt $routes.Count) {
                    if ($capturedServices -and $capturedServices.Navigation) {
                        & $capturedServices.Navigation.GoTo -self $capturedServices.Navigation -Path $routes[$SelectedIndex] -Services $capturedServices
                    } else {
                        Write-Log -Level Error -Message "Navigation services not available in OnRowSelect handler"
                    }
                }
            }
        }
        & $quickActions.ProcessData -self $quickActions
        & $quickActionsPanel.AddChild -self $quickActionsPanel -Child $quickActions
        & $rootPanel.AddChild -self $rootPanel -Child $quickActionsPanel -LayoutProps @{ "Grid.Row" = 0; "Grid.Column" = 0 }
        
        # --- Active Timers Panel ---
        $timersPanel = New-TuiStackPanel -Props @{ Name = "timersPanel"; Title = " Active Timers "; ShowBorder = $true; Padding = 1 }
        $activeTimers = New-TuiDataTable -Props @{
            Name = "activeTimers"; IsFocusable = $true; ShowBorder = $false; ShowFooter = $false
            Columns = @( @{ Name = "Project"; Width = 20 }, @{ Name = "Time"; Width = 10 } ); Data = @()
        }
        & $timersPanel.AddChild -self $timersPanel -Child $activeTimers
        & $rootPanel.AddChild -self $rootPanel -Child $timersPanel -LayoutProps @{ "Grid.Row" = 0; "Grid.Column" = 1 }
        
        # --- Stats Panel ---
        $statsPanel = New-TuiStackPanel -Props @{ Name = "statsPanel"; Title = " Stats "; ShowBorder = $true; Padding = 1; Orientation = "Vertical"; Spacing = 1 }
        $todayLabel = New-TuiLabel -Props @{ Name = "todayHoursLabel"; Text = "Today: 0h"; Height = 1 }
        $weekLabel = New-TuiLabel -Props @{ Name = "weekHoursLabel"; Text = "Week: 0h"; Height = 1 }
        $tasksLabel = New-TuiLabel -Props @{ Name = "activeTasksLabel"; Text = "Tasks: 0"; Height = 1 }
        $timersLabel = New-TuiLabel -Props @{ Name = "runningTimersLabel"; Text = "Timers: 0"; Height = 1 }
        & $statsPanel.AddChild -self $statsPanel -Child $todayLabel
        & $statsPanel.AddChild -self $statsPanel -Child $weekLabel
        & $statsPanel.AddChild -self $statsPanel -Child $tasksLabel
        & $statsPanel.AddChild -self $statsPanel -Child $timersLabel
        & $rootPanel.AddChild -self $rootPanel -Child $statsPanel -LayoutProps @{ "Grid.Row" = 0; "Grid.Column" = 2 }
        
        # --- Today's Tasks Panel ---
        $tasksPanel = New-TuiStackPanel -Props @{ Name = "tasksPanel"; Title = " Today's Tasks "; ShowBorder = $true; Padding = 1 }
        $todaysTasks = New-TuiDataTable -Props @{
            Name = "todaysTasks"; IsFocusable = $true; ShowBorder = $false; ShowFooter = $false
            Columns = @( @{ Name = "Priority"; Width = 8 }, @{ Name = "Task"; Width = 45 }, @{ Name = "Project"; Width = 15 } ); Data = @()
        }
        & $tasksPanel.AddChild -self $tasksPanel -Child $todaysTasks
        & $rootPanel.AddChild -self $rootPanel -Child $tasksPanel -LayoutProps @{ "Grid.Row" = 1; "Grid.Column" = 0; "Grid.ColumnSpan" = 3 }
        
        # ---------------------------------------------------------------------------------
        # THIS IS THE CRITICAL FIX: Storing references BEFORE creating subscriptions.
        # ---------------------------------------------------------------------------------
        $self._quickActions = $quickActions  # FIX: Added missing quickActions storage
        $self._activeTimers = $activeTimers
        $self._todaysTasks = $todaysTasks
        $self._todayLabel = $todayLabel
        $self._weekLabel = $weekLabel
        $self._tasksLabel = $tasksLabel
        $self._timersLabel = $timersLabel
        
        # Store components in hashtable for easy access
        $self.Components.quickActions = $quickActions
        $self.Components.activeTimers = $activeTimers
        $self.Components.todaysTasks = $todaysTasks
        $self.Components.todayLabel = $todayLabel
        $self.Components.weekLabel = $weekLabel
        $self.Components.tasksLabel = $tasksLabel
        $self.Components.timersLabel = $timersLabel
        
        # Capture screen reference for use in handlers (CRITICAL FIX)
        $screen = $self
        
        # Subscribe to app store updates with proper error handling
        try {
            # Test if Store.Subscribe exists and is callable
            if (-not $services.Store.Subscribe) {
                Write-Log -Level Error -Message "Store.Subscribe method not found"
                return
            }
            
            Write-Log -Level Debug -Message "Creating quickActions subscription..."
            $subId = & $services.Store.Subscribe -self $services.Store -path "quickActions" -handler { 
                param($NewValue, $OldValue, $Path) 
                try {
                    Write-Log -Level Debug -Message "quickActions handler triggered for path: $Path"
                    if ($screen -and $screen._quickActions) {
                        if ($NewValue -and $NewValue.Count -gt 0) {
                            $screen._quickActions.Data = $NewValue 
                            & $screen._quickActions.ProcessData -self $screen._quickActions
                            Write-Log -Level Debug -Message "quickActions updated with $($NewValue.Count) items"
                        } else {
                            Write-Log -Level Debug -Message "quickActions NewValue is null or empty"
                        }
                    } else {
                        Write-Log -Level Error -Message "quickActions component not accessible"
                    }
                } catch {
                    Write-Log -Level Error -Message "quickActions handler error: $_"
                }
            }
            
            if ($subId) {
                $self._subscriptions += $subId
                Write-Log -Level Debug -Message "quickActions subscription created: $subId"
            } else {
                Write-Log -Level Error -Message "quickActions subscription failed - no ID returned"
            }
            
            $self._subscriptions += & $services.Store.Subscribe -self $services.Store -path "activeTimers" -handler { 
                param($NewValue, $OldValue, $Path) 
                try {
                    if ($screen -and $screen._activeTimers -and $NewValue) {
                        $screen._activeTimers.Data = $NewValue 
                        & $screen._activeTimers.ProcessData -self $screen._activeTimers 
                    }
                } catch {
                    Write-Log -Level Error -Message "activeTimers handler error: $_"
                }
            }
            
            $self._subscriptions += & $services.Store.Subscribe -self $services.Store -path "todaysTasks" -handler { 
                param($NewValue, $OldValue, $Path) 
                try {
                    if ($screen -and $screen._todaysTasks -and $NewValue) {
                        $screen._todaysTasks.Data = $NewValue 
                        & $screen._todaysTasks.ProcessData -self $screen._todaysTasks 
                    }
                } catch {
                    Write-Log -Level Error -Message "todaysTasks handler error: $_"
                }
            }
            
            $self._subscriptions += & $services.Store.Subscribe -self $services.Store -path "stats.todayHours" -handler { 
                param($NewValue, $OldValue, $Path) 
                try {
                    if ($screen -and $screen._todayLabel -and $NewValue -ne $null) {
                        $screen._todayLabel.Text = "Today: ${NewValue}h" 
                        Request-TuiRefresh
                    }
                } catch {
                    Write-Log -Level Error -Message "todayHours handler error: $_"
                }
            }
            
            $self._subscriptions += & $services.Store.Subscribe -self $services.Store -path "stats.weekHours" -handler { 
                param($NewValue, $OldValue, $Path) 
                try {
                    if ($screen -and $screen._weekLabel -and $NewValue -ne $null) {
                        $screen._weekLabel.Text = "Week: ${NewValue}h" 
                        Request-TuiRefresh
                    }
                } catch {
                    Write-Log -Level Error -Message "weekHours handler error: $_"
                }
            }
            
            $self._subscriptions += & $services.Store.Subscribe -self $services.Store -path "stats.activeTasks" -handler { 
                param($NewValue, $OldValue, $Path) 
                try {
                    if ($screen -and $screen._tasksLabel -and $NewValue -ne $null) {
                        $screen._tasksLabel.Text = "Tasks: $NewValue" 
                        Request-TuiRefresh
                    }
                } catch {
                    Write-Log -Level Error -Message "activeTasks handler error: $_"
                }
            }
            
            $self._subscriptions += & $services.Store.Subscribe -self $services.Store -path "stats.runningTimers" -handler { 
                param($NewValue, $OldValue, $Path) 
                try {
                    if ($screen -and $screen._timersLabel -and $NewValue -ne $null) {
                        $screen._timersLabel.Text = "Timers: $NewValue" 
                        Request-TuiRefresh
                    }
                } catch {
                    Write-Log -Level Error -Message "runningTimers handler error: $_"
                }
            }
            
            Write-Log -Level Debug -Message "Dashboard: Created $($self._subscriptions.Count) subscriptions"
            
        } catch {
            Write-Log -Level Error -Message "Failed to create subscriptions: $_"
        }
        
        # Initial data load with error handling
        try {
            # Small delay to ensure components are ready
            Start-Sleep -Milliseconds 50
            
            $result = & $services.Store.Dispatch -self $services.Store -actionName "LOAD_DASHBOARD_DATA"
            if (-not $result.Success) {
                Write-Log -Level Error -Message "Failed to load dashboard data: $($result.Error)"
            }
            
            $result = & $services.Store.Dispatch -self $services.Store -actionName "DASHBOARD_REFRESH"
            if (-not $result.Success) {
                Write-Log -Level Error -Message "Failed to refresh dashboard: $($result.Error)"
            }
        } catch {
            Write-Log -Level Error -Message "Error dispatching initial actions: $_"
        }
        
        if (Get-Command -Name "Register-ScreenForFocus" -ErrorAction SilentlyContinue) {
            Register-ScreenForFocus -Screen $self
        }
        
        # Set initial focus to quickActions
        Request-Focus -Component $quickActions
        $quickActions.IsFocused = $true
        Write-Log -Level Debug -Message "Set initial focus to quickActions"
        
        # Set up refresh timer with proper service capture
        $timerServices = $services
        $self._refreshTimer = [System.Timers.Timer]::new(5000)
        $self._timerSubscription = Register-ObjectEvent -InputObject $self._refreshTimer -EventName Elapsed -MessageData $timerServices -Action {
            $passedServices = $Event.MessageData
            try {
                if ($passedServices -and $passedServices.Store) {
                    & $passedServices.Store.Dispatch -self $passedServices.Store -actionName "DASHBOARD_REFRESH"
                } else {
                    Write-Log -Level Error -Message "Timer event: services not available via MessageData"
                }
            } catch {
                Write-Log -Level Error -Message "Timer DASHBOARD_REFRESH failed: $_"
            }
        }
        $self._refreshTimer.Start()
        
        Write-Log -Level Debug -Message "Dashboard Init completed successfully"
        
    } catch {
        Write-Log -Level Error -Message "Dashboard Init error: $_" -Data $_
        Write-Log -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
    }
}
        
        Render = {
            param($self)
            
            try {
                # This method now ONLY draws screen-level "chrome" (non-component elements).
                # The engine handles rendering the component tree in the Children array.
                
                # Header
                $headerColor = Get-ThemeColor "Header" -Default Cyan
                $currentTime = Get-Date -Format 'dddd, MMMM dd, yyyy HH:mm:ss'
                Write-BufferString -X 2 -Y 1 -Text "PMC Terminal Dashboard - $currentTime" -ForegroundColor $headerColor
                
                # Active timer indicator
                $store = $self._services.Store
                if ($store) {
                    $timers = & $store.GetState -self $store -path "stats.runningTimers"
                    if ($timers -gt 0) {
                        $timerText = "● TIMER ACTIVE"
                        $timerX = $global:TuiState.BufferWidth - $timerText.Length - 2
                        Write-BufferString -X $timerX -Y 1 -Text $timerText -ForegroundColor Red
                    }
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
                $services = $self._services
                if (-not $services) { return $false }
                
                # First, let focused component handle input
                $focusedComponent = Get-FocusedComponent
                if ($focusedComponent -and $focusedComponent.HandleInput) {
                    $handled = & $focusedComponent.HandleInput -self $focusedComponent -Key $Key
                    if ($handled) {
                        Write-Log -Level Debug -Message "Input handled by focused component: $($focusedComponent.Name)"
                        return $true
                    }
                }
                
                $action = & $services.Keybindings.HandleKey -self $services.Keybindings -KeyInfo $Key
                
                switch ($action) {
                    "App.Refresh" { & $services.Store.Dispatch -self $services.Store -actionName "DASHBOARD_REFRESH"; return $true }
                    "App.DebugLog" { & $services.Navigation.GoTo -self $services.Navigation -Path "/log" -Services $services; return $true }
                    "App.Quit" { return "Quit" }
                    "App.Back" { return "Quit" }
                }
                
                # Tab navigation
                if ($Key.Key -eq [ConsoleKey]::Tab) {
                    $reverse = ($Key.Modifiers -band [ConsoleModifiers]::Shift) -ne 0
                    Move-Focus -Reverse:$reverse
                    return $true
                }
                
                if ($Key.KeyChar -ge '1' -and $Key.KeyChar -le '6') {
                    $index = [int]$Key.KeyChar.ToString() - 1
                    $routes = @("/time-entry", "/timer/start", "/tasks", "/projects", "/reports", "/settings")
                    & $services.Navigation.GoTo -self $services.Navigation -Path $routes[$index] -Services $services
                    return $true
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
            
            if ($self._refreshTimer) {
                $self._refreshTimer.Stop()
                $self._refreshTimer.Dispose()
            }
            if ($self._timerSubscription) {
                Unregister-Event -SubscriptionId $self._timerSubscription.Id -ErrorAction SilentlyContinue
                $self._timerSubscription = $null
            }
            
            $services = $self._services
            if ($services -and $services.Store) {
                foreach ($subId in $self._subscriptions) {
                    & $services.Store.Unsubscribe -self $services.Store -subId $subId
                }
            }
        }
        
        OnResume = {
            param($self)
            
            Write-Log -Level Debug -Message "Dashboard screen resuming"
            $global:TuiState.RenderStats.FrameCount = 0
            
            $services = $self._services
            if ($services -and $services.Store) {
                & $services.Store.Dispatch -self $services.Store -actionName "DASHBOARD_REFRESH"
            }
            Request-TuiRefresh
        }
    }
    
    $screen._services = $Services
    return $screen
}

Export-ModuleMember -Function Get-DashboardScreen
