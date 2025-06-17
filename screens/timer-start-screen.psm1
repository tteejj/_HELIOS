# Timer Start Screen Module - COMPLIANT VERSION
# Simple screen for starting/stopping timers

function global:Get-TimerStartScreen {
    param([hashtable]$Services)
    $screen = @{
        Name = "TimerStartScreen"
        
        # State
        State = @{
            ProjectKey = ""
            ProjectName = ""
            Description = ""
            ActiveTimer = $null
        }
        
        # Components
        Components = @{}
        FocusedComponentName = "projectButton"
        
        # Init
        Init = {
            param($self)
            $self._services = $Services # Store injected services
            
            # Calculate form position
            $formWidth = 50
            $formHeight = 15
            $formX = [Math]::Floor(($global:TuiState.BufferWidth - $formWidth) / 2)
            $formY = [Math]::Floor(($global:TuiState.BufferHeight - $formHeight) / 2)

            # Access store
            $store = $self._services.Store # Replaced global:Services
            $storeActiveTimers = $null
            $storeProjects = $null
            if ($store) {
                $storeActiveTimers = & $store.GetState -self $store -path 'active_timers'
                $storeProjects = & $store.GetState -self $store -path 'projects'
            }
            
            # Check if there's an active timer from store
            if ($storeActiveTimers -and $storeActiveTimers.Count -gt 0) {
                $activeTimerEntry = $storeActiveTimers.GetEnumerator() | Select-Object -First 1
                if ($activeTimerEntry) {
                    $self.State.ActiveTimer = $activeTimerEntry.Value
                    $self.State.ProjectKey = $activeTimerEntry.Value.ProjectKey
                    if ($storeProjects -and $storeProjects.ContainsKey($self.State.ProjectKey)) {
                        $self.State.ProjectName = $storeProjects[$self.State.ProjectKey].Name
                    }
                    $self.State.Description = $activeTimerEntry.Value.Description
                }
            }
            
            # Project selection button
            $self.Components.projectButton = New-TuiButton -Props @{
                X = $formX + 15; Y = $formY + 3; Width = 30; Height = 3
                Text = if ($self.State.ProjectName) { $self.State.ProjectName } else { "[ Select Project ]" }
                OnClick = {
                    if ($self.State.ActiveTimer) { return } # Can't change project while timer is running
                    
                    if (Get-Command Show-ListDialog -ErrorAction SilentlyContinue) {
                        $projectsForDialog = @()
                        # Re-fetch projects from store in case they changed
                        $currentStoreProjects = $null
                        if ($self._services -and $self._services.Store) { # Replaced global:Services
                            $currentStoreProjects = & $self._services.Store.GetState -self $self._services.Store -path 'projects'
                        }
                        if ($currentStoreProjects) {
                            $projectsForDialog = $currentStoreProjects.GetEnumerator() | ForEach-Object {
                                @{ Display = $_.Value.Name; Value = $_.Key }
                            } | Sort-Object Display
                        }
                        
                        if ($projectsForDialog.Count -gt 0) {
                            Show-ListDialog -Title "Select Project" -Prompt "Choose a project:" -Items $projectsForDialog -OnSelect {
                                param($item)
                                $self.State.ProjectKey = $item.Value
                                $self.State.ProjectName = $item.Display
                                $self.Components.projectButton.Text = $item.Display
                                Request-TuiRefresh
                            }
                        } else {
                            Show-AlertDialog -Title "No Projects" -Message "No projects available. Please create a project first."
                        }
                    }
                }
            }
            
            # Description input
            $self.Components.descriptionTextBox = New-TuiTextBox -Props @{
                X = $formX + 15; Y = $formY + 6; Width = 30; Height = 3
                Placeholder = "Task description..."
                Text = $self.State.Description
                OnChange = {
                    param($NewValue)
                    $self.State.Description = $NewValue
                }
            }
            
            # Timer display
            $self.Components.timerLabel = New-TuiLabel -Props @{
                X = $formX + 15; Y = $formY + 9
                Text = "00:00:00"
                ForegroundColor = if ($self.State.ActiveTimer) { [ConsoleColor]::Green } else { [ConsoleColor]::White }
            }
            
            # Start/Stop button
            $self.Components.actionButton = New-TuiButton -Props @{
                X = $formX + 15; Y = $formY + 11; Width = 20; Height = 3
                Text = if ($self.State.ActiveTimer) { "Stop Timer" } else { "Start Timer" }
                OnClick = {
                    if ($self.State.ActiveTimer) {
                        # Stop timer
                        $elapsed = (Get-Date) - [DateTime]$self.State.ActiveTimer.StartTime
                        $hours = [Math]::Round($elapsed.TotalHours, 2)
                        
                        # Create time entry
                        $timeEntry = @{
                            Id = [Guid]::NewGuid().ToString()
                            ProjectKey = $self.State.ActiveTimer.ProjectKey
                            Hours = $hours
                            Description = $self.State.ActiveTimer.Description
                            Date = (Get-Date).ToString("yyyy-MM-dd")
                            Created = Get-Date
                        }
                        
                        # Dispatch action to stop timer and create time entry
                        if ($self._services -and $self._services.Store) { # Replaced global:Services
                            $payload = @{
                                TimeEntry = $timeEntry
                                TimerIdToRemove = $self.State.ActiveTimer.Id
                            }
                            & $self._services.Store.Dispatch -self $self._services.Store -actionName "STOP_TIMER_AND_CREATE_ENTRY" -payload $payload
                        } else {
                            Write-Log -Level Error -Message "Store service not available via self._services. Cannot stop timer."
                            Show-AlertDialog -Title "Error" -Message "Failed to stop timer: Store unavailable."
                            return # Do not proceed with UI changes if store op failed
                        }
                        
                        # Reset state (assuming action was successful, or optimistic update)
                        $self.State.ActiveTimer = $null
                        $self.Components.actionButton.Text = "Start Timer"
                        $self.Components.timerLabel.ForegroundColor = [ConsoleColor]::White
                        
                        Show-AlertDialog -Title "Timer Stopped" -Message "Time entry created: $hours hours"
                        Request-TuiRefresh
                    } else {
                        # Start timer
                        if ([string]::IsNullOrEmpty($self.State.ProjectKey)) {
                            Show-AlertDialog -Title "Error" -Message "Please select a project first."
                            return
                        }
                        
                        $timer = @{
                            Id = [Guid]::NewGuid().ToString()
                            ProjectKey = $self.State.ProjectKey
                            Description = $self.State.Description
                            StartTime = Get-Date
                        }
                        
                        # Dispatch action to start timer
                        if ($self._services -and $self._services.Store) { # Replaced global:Services
                            & $self._services.Store.Dispatch -self $self._services.Store -actionName "START_TIMER" -payload $timer
                        } else {
                            Write-Log -Level Error -Message "Store service not available via self._services. Cannot start timer."
                            Show-AlertDialog -Title "Error" -Message "Failed to start timer: Store unavailable."
                            return # Do not proceed with UI changes if store op failed
                        }
                        
                        $self.State.ActiveTimer = $timer # Optimistic update, ideally this comes from store subscription
                        $self.Components.actionButton.Text = "Stop Timer"
                        $self.Components.timerLabel.ForegroundColor = [ConsoleColor]::Green
                        
                        Request-TuiRefresh
                    }
                }
            }
            
            # Labels
            $self.Components.projectLabel = New-TuiLabel -Props @{
                X = $formX + 3; Y = $formY + 4
                Text = "Project:"
            }
            
            $self.Components.descriptionLabel = New-TuiLabel -Props @{
                X = $formX + 3; Y = $formY + 7
                Text = "Description:"
            }
            
            # Update timer
            $self.UpdateTimer = {
                param($self)
                if ($self.State.ActiveTimer) {
                    $elapsed = (Get-Date) - [DateTime]$self.State.ActiveTimer.StartTime
                    $self.Components.timerLabel.Text = "{0:00}:{1:00}:{2:00}" -f [Math]::Floor($elapsed.TotalHours), $elapsed.Minutes, $elapsed.Seconds
                }
            }
        }
        
        # Render
        Render = {
            param($self)
            
            # Calculate form position
            $formWidth = 50
            $formHeight = 15
            $formX = [Math]::Floor(($global:TuiState.BufferWidth - $formWidth) / 2)
            $formY = [Math]::Floor(($global:TuiState.BufferHeight - $formHeight) / 2)
            
            # Draw form box
            Write-BufferBox -X $formX -Y $formY -Width $formWidth -Height $formHeight `
                -Title " Timer " -BorderColor (Get-ThemeColor "Accent")
            
            # Update timer display
            & $self.UpdateTimer $self
            
            # Render all components
            foreach ($kvp in $self.Components.GetEnumerator()) {
                $component = $kvp.Value
                if ($component -and $component.Visible -ne $false) {
                    # Set focus state
                    $component.IsFocused = ($self.FocusedComponentName -eq $kvp.Key)
                    if ($component.Render) {
                        & $component.Render -self $component
                    }
                }
            }
            
            # Status
            $statusY = $formY + $formHeight - 2
            if ($self.State.ActiveTimer) {
                Write-BufferString -X ($formX + 3) -Y $statusY -Text "Timer is running..." -ForegroundColor Green
            } else {
                Write-BufferString -X ($formX + 3) -Y $statusY -Text "Tab: Next Field • Enter: Action • Esc: Back" -ForegroundColor (Get-ThemeColor "Subtle")
            }
        }
        
        # HandleInput
        HandleInput = {
            param($self, $Key)
            
            # Global navigation
            switch ($Key.Key) {
                ([ConsoleKey]::Escape) { 
                    Pop-Screen
                    return $true 
                }
                ([ConsoleKey]::Tab) {
                    # Simple focus cycling
                    $focusable = @("projectButton", "descriptionTextBox", "actionButton")
                    $currentIndex = [array]::IndexOf($focusable, $self.FocusedComponentName)
                    if ($currentIndex -eq -1) { $currentIndex = 0 }
                    
                    $nextIndex = ($currentIndex + 1) % $focusable.Count
                    $self.FocusedComponentName = $focusable[$nextIndex]
                    Request-TuiRefresh
                    return $true
                }
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
            
            return $false
        }
    }
    
    return $screen
}

Export-ModuleMember -Function 'Get-TimerStartScreen'
