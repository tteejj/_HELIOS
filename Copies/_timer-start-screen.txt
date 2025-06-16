# Timer Start Screen Module - COMPLIANT VERSION
# Simple screen for starting/stopping timers

function global:Get-TimerStartScreen {
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
            
            # Calculate form position
            $formWidth = 50
            $formHeight = 15
            $formX = [Math]::Floor(($global:TuiState.BufferWidth - $formWidth) / 2)
            $formY = [Math]::Floor(($global:TuiState.BufferHeight - $formHeight) / 2)
            
            # Check if there's an active timer
            if ($global:Data -and $global:Data.ActiveTimers -and $global:Data.ActiveTimers.Count -gt 0) {
                $activeTimer = $global:Data.ActiveTimers.GetEnumerator() | Select-Object -First 1
                if ($activeTimer) {
                    $self.State.ActiveTimer = $activeTimer.Value
                    $self.State.ProjectKey = $activeTimer.Value.ProjectKey
                    if ($global:Data.Projects -and $global:Data.Projects[$self.State.ProjectKey]) {
                        $self.State.ProjectName = $global:Data.Projects[$self.State.ProjectKey].Name
                    }
                    $self.State.Description = $activeTimer.Value.Description
                }
            }
            
            # Project selection button
            $self.Components.projectButton = New-TuiButton -Props @{
                X = $formX + 15; Y = $formY + 3; Width = 30; Height = 3
                Text = if ($self.State.ProjectName) { $self.State.ProjectName } else { "[ Select Project ]" }
                OnClick = {
                    if ($self.State.ActiveTimer) { return } # Can't change project while timer is running
                    
                    if (Get-Command Show-ListDialog -ErrorAction SilentlyContinue) {
                        $projects = @()
                        if ($global:Data -and $global:Data.Projects) {
                            $projects = $global:Data.Projects.GetEnumerator() | ForEach-Object {
                                @{ Display = $_.Value.Name; Value = $_.Key }
                            } | Sort-Object Display
                        }
                        
                        if ($projects.Count -gt 0) {
                            Show-ListDialog -Title "Select Project" -Prompt "Choose a project:" -Items $projects -OnSelect {
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
                        
                        # Add to data
                        if ($global:Data) {
                            if (-not $global:Data.TimeEntries) {
                                $global:Data.TimeEntries = @()
                            }
                            $global:Data.TimeEntries += $timeEntry
                            
                            # Remove active timer
                            $global:Data.ActiveTimers.Remove($self.State.ActiveTimer.Id)
                            
                            # Save data
                            if (Get-Command Save-UnifiedData -ErrorAction SilentlyContinue) {
                                Save-UnifiedData -Data $global:Data
                            }
                        }
                        
                        # Reset state
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
                        
                        # Add to active timers
                        if ($global:Data) {
                            if (-not $global:Data.ActiveTimers) {
                                $global:Data.ActiveTimers = @{}
                            }
                            $global:Data.ActiveTimers[$timer.Id] = $timer
                            
                            # Save data
                            if (Get-Command Save-UnifiedData -ErrorAction SilentlyContinue) {
                                Save-UnifiedData -Data $global:Data
                            }
                        }
                        
                        $self.State.ActiveTimer = $timer
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
