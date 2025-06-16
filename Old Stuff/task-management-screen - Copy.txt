# Task Management Screen

function Get-TaskManagementScreen {
    $screen = @{
        Name = "TaskManagementScreen"
        State = @{
            Tasks = @()
            FilterStatus = "Active" # Active, Completed, All
            FilterProject = $null
            SelectedIndex = 0
            ShowCompletedDays = 7
        }
        
        Init = {
            param($self)
            & $self.RefreshTasks -self $self
        }
        
        RefreshTasks = {
            param($self)
            $tasks = $script:Data.Tasks
            
            # Filter by status
            switch ($self.State.FilterStatus) {
                "Active" {
                    $tasks = $tasks | Where-Object { -not $_.Completed }
                }
                "Completed" {
                    $cutoffDate = (Get-Date).AddDays(-$self.State.ShowCompletedDays)
                    $tasks = $tasks | Where-Object { 
                        $_.Completed -and 
                        $_.CompletedDate -and 
                        [DateTime]::Parse($_.CompletedDate) -ge $cutoffDate
                    }
                }
                # "All" shows everything
            }
            
            # Filter by project
            if ($self.State.FilterProject) {
                $tasks = $tasks | Where-Object { $_.ProjectKey -eq $self.State.FilterProject }
            }
            
            # Sort tasks
            $self.State.Tasks = $tasks | Sort-Object -Property @(
                @{Expression = {$_.Completed}; Ascending = $true},
                @{Expression = {
                    switch ($_.Priority) {
                        "Critical" { 0 }
                        "High" { 1 }
                        "Medium" { 2 }
                        "Low" { 3 }
                        default { 4 }
                    }
                }},
                @{Expression = {$_.DueDate}}
            )
        }
        
        Render = {
            param($self)
            
            # Header
            Write-BufferString -X 2 -Y 1 -Text "Task Management" -ForegroundColor (Get-ThemeColor "Header")
            
            # Filter info
            $filterText = "Showing: $($self.State.FilterStatus) tasks"
            if ($self.State.FilterProject) {
                $project = Get-ProjectById -ProjectId $self.State.FilterProject
                $filterText += " | Project: $($project.Name)"
            }
            Write-BufferString -X 2 -Y 3 -Text $filterText -ForegroundColor (Get-ThemeColor "Subtle")
            
            # Task counts
            $activeTasks = $self.State.Tasks | Where-Object { -not $_.Completed }
            $overdueTasks = $activeTasks | Where-Object { 
                $_.DueDate -and [DateTime]::Parse($_.DueDate) -lt [DateTime]::Today
            }
            
            $countText = "$($activeTasks.Count) active"
            if ($overdueTasks.Count -gt 0) {
                $countText += " | $($overdueTasks.Count) overdue"
            }
            Write-BufferString -X ($script:TuiState.BufferWidth - $countText.Length - 2) -Y 3 `
                -Text $countText -ForegroundColor (Get-ThemeColor "Warning")
            
            # Task list
            $listY = 5
            $visibleTasks = $script:TuiState.BufferHeight - $listY - 4
            $startIdx = [Math]::Max(0, $self.State.SelectedIndex - [Math]::Floor($visibleTasks / 2))
            $endIdx = [Math]::Min($self.State.Tasks.Count, $startIdx + $visibleTasks)
            
            if ($self.State.Tasks.Count -eq 0) {
                $emptyMsg = "No tasks found"
                $msgX = [Math]::Floor(($script:TuiState.BufferWidth - $emptyMsg.Length) / 2)
                $msgY = [Math]::Floor($script:TuiState.BufferHeight / 2)
                Write-BufferString -X $msgX -Y $msgY -Text $emptyMsg -ForegroundColor (Get-ThemeColor "Subtle")
            } else {
                for ($i = $startIdx; $i -lt $endIdx; $i++) {
                    $task = $self.State.Tasks[$i]
                    $rowY = $listY + ($i - $startIdx)
                    
                    $isSelected = ($i -eq $self.State.SelectedIndex)
                    $bgColor = if ($isSelected) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Background" }
                    $fgColor = if ($isSelected) { Get-ThemeColor "Background" } else { Get-ThemeColor "Primary" }
                    
                    # Clear row if selected
                    if ($isSelected) {
                        Write-BufferString -X 1 -Y $rowY -Text (" " * ($script:TuiState.BufferWidth - 2)) `
                            -BackgroundColor $bgColor
                    }
                    
                    # Priority indicator
                    $priorityInfo = Get-PriorityInfo -Priority $task.Priority
                    Write-BufferString -X 2 -Y $rowY -Text $priorityInfo.Icon `
                        -ForegroundColor $priorityInfo.Color -BackgroundColor $bgColor
                    
                    # Checkbox
                    $checkbox = if ($task.Completed) { "[X]" } else { "[ ]" }
                    Write-BufferString -X 5 -Y $rowY -Text $checkbox `
                        -ForegroundColor $fgColor -BackgroundColor $bgColor
                    
                    # Task description
                    $desc = $task.Description
                    $maxDescLen = $script:TuiState.BufferWidth - 40
                    if ($desc.Length -gt $maxDescLen) {
                        $desc = $desc.Substring(0, $maxDescLen - 3) + "..."
                    }
                    $descColor = if ($task.Completed) { Get-ThemeColor "Subtle" } else { $fgColor }
                    Write-BufferString -X 10 -Y $rowY -Text $desc `
                        -ForegroundColor $descColor -BackgroundColor $bgColor
                    
                    # Due date
                    if ($task.DueDate) {
                        $dueDate = [DateTime]::Parse($task.DueDate)
                        $dueText = $dueDate.ToString("MM/dd")
                        $today = [DateTime]::Today
                        
                        $dueColor = if ($task.Completed) { 
                            Get-ThemeColor "Subtle" 
                        } elseif ($dueDate -lt $today) { 
                            Get-ThemeColor "Error" 
                        } elseif ($dueDate -eq $today) { 
                            Get-ThemeColor "Warning" 
                        } else { 
                            $fgColor 
                        }
                        
                        Write-BufferString -X ($script:TuiState.BufferWidth - 25) -Y $rowY `
                            -Text $dueText -ForegroundColor $dueColor -BackgroundColor $bgColor
                    }
                    
                    # Progress
                    if ($task.Progress -and $task.Progress -gt 0) {
                        $progressText = "$($task.Progress)%"
                        Write-BufferString -X ($script:TuiState.BufferWidth - 15) -Y $rowY `
                            -Text $progressText -ForegroundColor $fgColor -BackgroundColor $bgColor
                    }
                    
                    # Task ID
                    $idText = "[$($task.Id.Substring(0, 6))]"
                    Write-BufferString -X ($script:TuiState.BufferWidth - 10) -Y $rowY `
                        -Text $idText -ForegroundColor (Get-ThemeColor "Subtle") -BackgroundColor $bgColor
                }
            }
            
            # Instructions
            $instructions = "[↑↓] Navigate | [Space] Toggle | [N] New | [E] Edit | [D] Delete | [F] Filter | [Esc] Back"
            Write-BufferString -X ([Math]::Floor(($script:TuiState.BufferWidth - $instructions.Length) / 2)) `
                -Y ($script:TuiState.BufferHeight - 2) -Text $instructions -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        HandleInput = {
            param($self, $Key)
            
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($self.State.SelectedIndex -gt 0) {
                        $self.State.SelectedIndex--
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($self.State.SelectedIndex -lt $self.State.Tasks.Count - 1) {
                        $self.State.SelectedIndex++
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::Spacebar) {
                    if ($self.State.Tasks.Count -gt 0) {
                        $task = $self.State.Tasks[$self.State.SelectedIndex]
                        
                        # Toggle completion
                        $task.Completed = -not $task.Completed
                        if ($task.Completed) {
                            $task.CompletedDate = (Get-Date).ToString("yyyy-MM-dd")
                        } else {
                            $task.CompletedDate = $null
                        }
                        
                        Save-UnifiedData
                        & $self.RefreshTasks -self $self
                        Request-TuiRefresh
                        
                        $msg = if ($task.Completed) { "Task completed" } else { "Task reopened" }
                        Publish-Event -EventName "Notification.Show" -Data @{
                            Text = $msg
                            Type = "Success"
                        }
                    }
                    return $true
                }
                ([ConsoleKey]::N) {
                    Push-Screen -Screen (Get-AddTaskScreen)
                    return $true
                }
                ([ConsoleKey]::E) {
                    if ($self.State.Tasks.Count -gt 0) {
                        $task = $self.State.Tasks[$self.State.SelectedIndex]
                        # TODO: Push edit task screen
                        Publish-Event -EventName "Notification.Show" -Data @{
                            Text = "Edit task not implemented yet"
                            Type = "Info"
                        }
                    }
                    return $true
                }
                ([ConsoleKey]::D) {
                    if ($self.State.Tasks.Count -gt 0) {
                        $task = $self.State.Tasks[$self.State.SelectedIndex]
                        
                        # Confirm deletion
                        Publish-Event -EventName "Confirm.Request" -Data @{
                            Title = "Delete Task"
                            Message = "Delete task: $($task.Description)?"
                            OnConfirm = {
                                $script:Data.Tasks = $script:Data.Tasks | Where-Object { $_.Id -ne $task.Id }
                                Save-UnifiedData
                                
                                & $self.RefreshTasks -self $self
                                if ($self.State.SelectedIndex -ge $self.State.Tasks.Count -and $self.State.SelectedIndex -gt 0) {
                                    $self.State.SelectedIndex--
                                }
                                Request-TuiRefresh
                                
                                Publish-Event -EventName "Notification.Show" -Data @{
                                    Text = "Task deleted"
                                    Type = "Success"
                                }
                            }
                        }
                    }
                    return $true
                }
                ([ConsoleKey]::F) {
                    # Cycle through filters
                    $filters = @("Active", "Completed", "All")
                    $currentIdx = [Array]::IndexOf($filters, $self.State.FilterStatus)
                    $self.State.FilterStatus = $filters[($currentIdx + 1) % $filters.Count]
                    
                    & $self.RefreshTasks -self $self
                    $self.State.SelectedIndex = 0
                    Request-TuiRefresh
                    
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    return "Back"
                }
            }
            
            return $false
        }
        
        OnResume = {
            param($self)
            & $self.RefreshTasks -self $self
            Request-TuiRefresh
        }
    }
    
    return $screen
}

function Get-AddTaskScreen {
    $screen = @{
        Name = "AddTaskScreen"
        State = @{
            Description = ""
            ProjectKey = $null
            Priority = "Medium"
            DueDate = $null
            DescriptionCursor = 0
            FocusedChildName = "description_textbox"
        }
        FormContainer = $null
        
        Init = {
            param($self)
            
            $children = @(
                New-TuiTextBox -Props @{
                    Name = "description_textbox"
                    Y = 1
                    Width = 56
                    Placeholder = "Task description..."
                    TextProp = "Description"
                    CursorProp = "DescriptionCursor"
                    OnChange = { 
                        param($NewText, $NewCursorPosition) 
                        $self.State.Description = $NewText
                        $self.State.DescriptionCursor = $NewCursorPosition
                        Request-TuiRefresh 
                    }
                }
                
                New-TuiDropdown -Props @{
                    Name = "project_dropdown"
                    Y = 5
                    Width = 26
                    Options = @(
                        @{ Value = $null; Display = "No Project" }
                        $script:Data.Projects.GetEnumerator() | ForEach-Object { 
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
                
                New-TuiDropdown -Props @{
                    Name = "priority_dropdown"
                    X = 30
                    Y = 5
                    Width = 26
                    Options = @(
                        @{ Value = "Low"; Display = "Low Priority" }
                        @{ Value = "Medium"; Display = "Medium Priority" }
                        @{ Value = "High"; Display = "High Priority" }
                        @{ Value = "Critical"; Display = "Critical Priority" }
                    )
                    ValueProp = "Priority"
                    OnChange = { 
                        param($NewValue) 
                        $self.State.Priority = $NewValue
                        Request-TuiRefresh 
                    }
                }
                
                New-TuiDatePicker -Props @{
                    Name = "due_date_picker"
                    Y = 9
                    Width = 26
                    ValueProp = "DueDate"
                    OnChange = { 
                        param($NewValue) 
                        $self.State.DueDate = $NewValue
                        Request-TuiRefresh 
                    }
                }
                
                New-TuiButton -Props @{
                    Name = "create_button"
                    Y = 13
                    Width = 12
                    Text = "Create Task"
                    OnClick = {
                        if ([string]::IsNullOrWhiteSpace($self.State.Description)) {
                            Publish-Event -EventName "Notification.Show" -Data @{
                                Text = "Task description is required"
                                Type = "Error"
                            }
                            return
                        }
                        
                        # Create task
                        $dueDateStr = if ($self.State.DueDate) { $self.State.DueDate.ToString("yyyy-MM-dd") } else { $null }
                        Add-Task -Title $self.State.Description -ProjectKey $self.State.ProjectKey `
                            -Priority $self.State.Priority -DueDate $dueDateStr
                        
                        Publish-Event -EventName "Notification.Show" -Data @{
                            Text = "Task created successfully"
                            Type = "Success"
                        }
                        
                        Pop-Screen
                    }
                }
                
                New-TuiButton -Props @{
                    Name = "cancel_button"
                    X = 44
                    Y = 13
                    Width = 12
                    Text = "Cancel"
                    OnClick = { Pop-Screen }
                }
            )
            
            # Set initial priority value
            $self.State.Priority = "Medium"
            
            $self.FormContainer = New-TuiForm -Props @{
                X = [Math]::Floor(($script:TuiState.BufferWidth - 60) / 2)
                Y = [Math]::Floor(($script:TuiState.BufferHeight - 20) / 2)
                Width = 60
                Height = 20
                Title = " Add New Task "
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
    }
    
    return $screen
}

function Get-PriorityInfo {
    param([string]$Priority)
    
    switch ($Priority) {
        "Critical" { return @{ Icon = "🔴"; Color = [ConsoleColor]::Red } }
        "High"     { return @{ Icon = "🟠"; Color = [ConsoleColor]::DarkYellow } }
        "Medium"   { return @{ Icon = "🟡"; Color = [ConsoleColor]::Yellow } }
        "Low"      { return @{ Icon = "🟢"; Color = [ConsoleColor]::Green } }
        default    { return @{ Icon = "⚪"; Color = [ConsoleColor]::Gray } }
    }
}

Export-ModuleMember -Function 'Get-TaskManagementScreen', 'Get-AddTaskScreen', 'Get-PriorityInfo'
