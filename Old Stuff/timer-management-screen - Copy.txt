# Timer Management Screen

function Get-TimerManagementScreen {
    $screen = @{
        Name = "TimerManagementScreen"
        State = @{
            ActiveTimers = @()
            SelectedIndex = 0
            LastUpdate = [DateTime]::Now
        }
        UpdateTimer = $null
        
        Init = {
            param($self)
            # Update timer list
            & $self.RefreshTimers -self $self
            
            # Create a timer to update display every second
            $self.UpdateTimer = New-Object System.Timers.Timer
            $self.UpdateTimer.Interval = 1000
            $self.UpdateTimer.AutoReset = $true
            Register-ObjectEvent -InputObject $self.UpdateTimer -EventName Elapsed -Action {
                Request-TuiRefresh
            } | Out-Null
            $self.UpdateTimer.Start()
        }
        
        RefreshTimers = {
            param($self)
            if ($script:Data.ActiveTimers) {
                $self.State.ActiveTimers = @($script:Data.ActiveTimers.GetEnumerator() | 
                    Sort-Object { [DateTime]$_.Value.StartTime })
            } else {
                $self.State.ActiveTimers = @()
            }
        }
        
        Render = {
            param($self)
            # Header
            Write-BufferString -X 2 -Y 1 -Text "Active Timers" -ForegroundColor (Get-ThemeColor "Header")
            
            $timerCount = $self.State.ActiveTimers.Count
            $countText = if ($timerCount -eq 0) { "No active timers" } 
                        elseif ($timerCount -eq 1) { "1 timer running" } 
                        else { "$timerCount timers running" }
            Write-BufferString -X ($script:TuiState.BufferWidth - $countText.Length - 2) -Y 1 `
                -Text $countText -ForegroundColor (Get-ThemeColor "Info")
            
            if ($timerCount -eq 0) {
                # Empty state
                $emptyMsg = "No timers are currently running"
                $msgX = [Math]::Floor(($script:TuiState.BufferWidth - $emptyMsg.Length) / 2)
                $msgY = [Math]::Floor($script:TuiState.BufferHeight / 2)
                Write-BufferString -X $msgX -Y $msgY -Text $emptyMsg -ForegroundColor (Get-ThemeColor "Subtle")
                
                $helpMsg = "Press [N] to start a new timer"
                $helpX = [Math]::Floor(($script:TuiState.BufferWidth - $helpMsg.Length) / 2)
                Write-BufferString -X $helpX -Y ($msgY + 2) -Text $helpMsg -ForegroundColor (Get-ThemeColor "Subtle")
            } else {
                # Timer list
                $listY = 4
                $currentTime = [DateTime]::Now
                
                for ($i = 0; $i -lt $timerCount; $i++) {
                    $timer = $self.State.ActiveTimers[$i]
                    $timerData = $timer.Value
                    $startTime = [DateTime]$timerData.StartTime
                    $elapsed = $currentTime - $startTime
                    
                    $isSelected = ($i -eq $self.State.SelectedIndex)
                    $boxY = $listY + ($i * 6)
                    
                    # Timer box
                    $boxWidth = $script:TuiState.BufferWidth - 4
                    $borderColor = if ($isSelected) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
                    Write-BufferBox -X 2 -Y $boxY -Width $boxWidth -Height 5 -BorderColor $borderColor
                    
                    # Project name
                    $project = Get-ProjectById -ProjectId $timerData.ProjectKey
                    $projectName = if ($project) { $project.Name } else { "Unknown Project" }
                    Write-BufferString -X 4 -Y ($boxY + 1) -Text $projectName -ForegroundColor (Get-ThemeColor "Primary")
                    
                    # Timer key
                    Write-BufferString -X ($boxWidth - 10) -Y ($boxY + 1) -Text "[$($timer.Key)]" `
                        -ForegroundColor (Get-ThemeColor "Subtle")
                    
                    # Elapsed time
                    $hours = [Math]::Floor($elapsed.TotalHours)
                    $minutes = $elapsed.Minutes
                    $seconds = $elapsed.Seconds
                    $timeText = "{0:D2}:{1:D2}:{2:D2}" -f $hours, $minutes, $seconds
                    Write-BufferString -X 4 -Y ($boxY + 2) -Text "⏱ $timeText" -ForegroundColor (Get-ThemeColor "Success")
                    
                    # Description
                    $desc = $timerData.Description ?? "No description"
                    $maxDescLen = $boxWidth - 8
                    if ($desc.Length -gt $maxDescLen) { $desc = $desc.Substring(0, $maxDescLen - 3) + "..." }
                    Write-BufferString -X 4 -Y ($boxY + 3) -Text $desc -ForegroundColor (Get-ThemeColor "Secondary")
                }
            }
            
            # Instructions
            $instructions = "[↑↓] Navigate | [Space] Stop Selected | [S] Stop All | [N] New Timer | [Esc] Back"
            Write-BufferString -X ([Math]::Floor(($script:TuiState.BufferWidth - $instructions.Length) / 2)) `
                -Y ($script:TuiState.BufferHeight - 2) -Text $instructions -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        HandleInput = {
            param($self, $Key)
            $timerCount = $self.State.ActiveTimers.Count
            
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($self.State.SelectedIndex -gt 0) {
                        $self.State.SelectedIndex--
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($self.State.SelectedIndex -lt $timerCount - 1) {
                        $self.State.SelectedIndex++
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::Spacebar) {
                    if ($timerCount -gt 0) {
                        $selectedTimer = $self.State.ActiveTimers[$self.State.SelectedIndex]
                        $timerKey = $selectedTimer.Key
                        
                        # Stop the timer
                        Publish-Event -EventName "Timer.Stop" -Data @{ Key = $timerKey }
                        
                        # Refresh display
                        & $self.RefreshTimers -self $self
                        if ($self.State.SelectedIndex -ge $self.State.ActiveTimers.Count -and $self.State.SelectedIndex -gt 0) {
                            $self.State.SelectedIndex--
                        }
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::S) {
                    if ($timerCount -gt 0) {
                        # Confirm stop all
                        Publish-Event -EventName "Confirm.Request" -Data @{
                            Title = "Stop All Timers"
                            Message = "Stop all $timerCount running timers?"
                            OnConfirm = {
                                # Stop all timers
                                $keys = @($script:Data.ActiveTimers.Keys)
                                foreach ($key in $keys) {
                                    Publish-Event -EventName "Timer.Stop" -Data @{ Key = $key }
                                }
                                
                                # Refresh
                                & $self.RefreshTimers -self $self
                                $self.State.SelectedIndex = 0
                                Request-TuiRefresh
                                
                                Publish-Event -EventName "Notification.Show" -Data @{
                                    Text = "All timers stopped"
                                    Type = "Success"
                                }
                            }
                        }
                    }
                    return $true
                }
                ([ConsoleKey]::N) {
                    Push-Screen -Screen (Get-StartTimerScreen)
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    return "Back"
                }
            }
            
            return $false
        }
        
        OnExit = {
            param($self)
            # Stop the update timer
            if ($self.UpdateTimer) {
                $self.UpdateTimer.Stop()
                $self.UpdateTimer.Dispose()
                $self.UpdateTimer = $null
            }
        }
        
        OnResume = {
            param($self)
            # Refresh and restart timer
            & $self.RefreshTimers -self $self
            if ($self.UpdateTimer) {
                $self.UpdateTimer.Start()
            }
        }
    }
    
    # Subscribe to timer events
    Subscribe-Event -EventName "Timer.Stop" -Handler {
        param($EventData)
        $timerKey = $EventData.Data.Key
        
        if ($script:Data.ActiveTimers.ContainsKey($timerKey)) {
            $timer = $script:Data.ActiveTimers[$timerKey]
            $startTime = [DateTime]$timer.StartTime
            $elapsed = [DateTime]::Now - $startTime
            $hours = [Math]::Round($elapsed.TotalHours, 2)
            
            # Create time entry
            Add-TimeEntry -ProjectKey $timer.ProjectKey -Hours $hours -Description $timer.Description
            
            # Remove timer
            $script:Data.ActiveTimers.Remove($timerKey)
            Save-UnifiedData
            
            Publish-Event -EventName "Notification.Show" -Data @{
                Text = "Timer stopped: $hours hours logged"
                Type = "Success"
            }
        }
    } -SubscriberId "TimerManagementScreen"
    
    return $screen
}

function Get-StartTimerScreen {
    $screen = @{
        Name = "StartTimerScreen"
        State = @{
            ProjectKey = $null
            Description = ""
            DescriptionCursor = 0
            FocusedChildName = "project_dropdown"
        }
        FormContainer = $null
        
        Init = {
            param($self)
            
            # Create form children
            $children = @(
                New-TuiLabel -Props @{
                    Y = 0
                    Text = "Select project and enter description for the timer:"
                }
                
                New-TuiDropdown -Props @{
                    Name = "project_dropdown"
                    Y = 2
                    Width = 56
                    Options = @(
                        $script:Data.Projects.GetEnumerator() | 
                        Where-Object { $_.Value.Status -eq "Active" } |
                        ForEach-Object { 
                            @{ Value = $_.Key; Display = $_.Value.Name } 
                        }
                    )
                    ValueProp = "ProjectKey"
                    OnChange = { 
                        param($NewValue) 
                        $self.State.ProjectKey = $NewValue
                        Request-TuiRefresh 
                    }
                }
                
                New-TuiTextBox -Props @{
                    Name = "description_textbox"
                    Y = 6
                    Width = 56
                    Placeholder = "What are you working on?"
                    TextProp = "Description"
                    CursorProp = "DescriptionCursor"
                    OnChange = { 
                        param($NewText, $NewCursorPosition) 
                        $self.State.Description = $NewText
                        $self.State.DescriptionCursor = $NewCursorPosition
                        Request-TuiRefresh 
                    }
                }
                
                New-TuiButton -Props @{
                    Name = "start_button"
                    Y = 10
                    Width = 12
                    Text = "Start Timer"
                    OnClick = {
                        if (-not $self.State.ProjectKey) {
                            Publish-Event -EventName "Notification.Show" -Data @{
                                Text = "Please select a project"
                                Type = "Error"
                            }
                            return
                        }
                        
                        # Generate timer key
                        $timerKey = "T" + (Get-Random -Minimum 100 -Maximum 999)
                        while ($script:Data.ActiveTimers.ContainsKey($timerKey)) {
                            $timerKey = "T" + (Get-Random -Minimum 100 -Maximum 999)
                        }
                        
                        # Create timer
                        $script:Data.ActiveTimers[$timerKey] = @{
                            ProjectKey = $self.State.ProjectKey
                            Description = $self.State.Description
                            StartTime = [DateTime]::Now.ToString("o")
                        }
                        Save-UnifiedData
                        
                        Publish-Event -EventName "Timer.Started" -Data @{
                            Key = $timerKey
                            ProjectKey = $self.State.ProjectKey
                        }
                        
                        Publish-Event -EventName "Notification.Show" -Data @{
                            Text = "Timer started (Key: $timerKey)"
                            Type = "Success"
                        }
                        
                        Pop-Screen
                    }
                }
                
                New-TuiButton -Props @{
                    Name = "cancel_button"
                    X = 44
                    Y = 10
                    Width = 12
                    Text = "Cancel"
                    OnClick = { Pop-Screen }
                }
            )
            
            # Create form container
            $self.FormContainer = New-TuiForm -Props @{
                X = [Math]::Floor(($script:TuiState.BufferWidth - 60) / 2)
                Y = [Math]::Floor(($script:TuiState.BufferHeight - 16) / 2)
                Width = 60
                Height = 16
                Title = " Start Timer "
                Padding = 2
                Children = $children
                OnFocusChange = { 
                    param($NewFocusedChildName) 
                    $self.State.FocusedChildName = $NewFocusedChildName
                    Request-TuiRefresh 
                }
            }
        }
        
        Render = {
            param($self)
            $self.FormContainer.State = $self.State
            & $self.FormContainer.Render -self $self.FormContainer
        }
        
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -eq [ConsoleKey]::Escape) {
                return "Back"
            }
            
            $self.FormContainer.State = $self.State
            return & $self.FormContainer.HandleInput -self $self.FormContainer -Key $Key
        }
        
        OnExit = {
            param($self)
            # Clear form
            $self.State.ProjectKey = $null
            $self.State.Description = ""
            $self.State.DescriptionCursor = 0
            $self.State.FocusedChildName = "project_dropdown"
        }
    }
    
    return $screen
}

Export-ModuleMember -Function 'Get-TimerManagementScreen', 'Get-StartTimerScreen'
