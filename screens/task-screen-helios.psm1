# Task Management Screen - Helios Service-Based Version
# Uses the new service architecture with app store, navigation, and layout panels

function global:Get-TaskManagementScreen {
    $screen = @{
        Name = "TaskScreen"
        Components = @{}
        _subscriptions = @()
        _formVisible = $false
        _editingTaskId = $null
        
        Init = {
            param($self)
            
            Write-Log -Level Debug -Message "Task screen Init started (Helios version)"
            
            try {
                # Access services
                $services = $global:Services
                if (-not $services) {
                    Write-Log -Level Error -Message "Services not initialized"
                    return
                }
                
                # Create root layout
                $rootPanel = New-TuiStackPanel -Props @{
                    X = 1
                    Y = 1
                    Width = ($global:TuiState.BufferWidth - 2)
                    Height = ($global:TuiState.BufferHeight - 2)
                    ShowBorder = $false
                    Orientation = "Vertical"
                    Spacing = 1
                }
                $self.Components.rootPanel = $rootPanel
                
                # Header
                $headerLabel = New-TuiLabel -Props @{
                    Text = "Task Management"
                    Height = 1
                }
                & $rootPanel.AddChild -self $rootPanel -Child $headerLabel
                
                # Toolbar
                $toolbarLabel = New-TuiLabel -Props @{
                    Text = "Filter: [1]All [2]Active [3]Completed | Sort: [P]riority [D]ue Date [C]reated"
                    Height = 1
                }
                & $rootPanel.AddChild -self $rootPanel -Child $toolbarLabel
                
                # Task table panel
                $tablePanel = New-TuiStackPanel -Props @{
                    Title = " Tasks "
                    ShowBorder = $true
                    Padding = 1
                    Height = ($global:TuiState.BufferHeight - 10)  # Leave room for status bar
                }
                
                $taskTable = New-TuiDataTable -Props @{
                    Name = "taskTable"
                    IsFocusable = $true
                    ShowBorder = $false
                    Columns = @(
                        @{ Name = "Status"; Width = 3 }
                        @{ Name = "Priority"; Width = 10 }
                        @{ Name = "Title"; Width = 35 }
                        @{ Name = "Category"; Width = 12 }
                        @{ Name = "DueDate"; Width = 10 }
                    )
                    Data = @()
                    AllowSort = $false  # We handle sorting through the store
                    OnRowSelect = {
                        param($data, $index)
                        if ($data -and $data.Id) {
                            $services.Store.Dispatch("TASK_TOGGLE_STATUS", @{ TaskId = $data.Id })
                        }
                    }
                }
                
                & $tablePanel.AddChild -self $tablePanel -Child $taskTable
                & $rootPanel.AddChild -self $rootPanel -Child $tablePanel
                
                # Store references
                $self._taskTable = $taskTable
                $self._rootPanel = $rootPanel
                
                # Create form panel (initially hidden)
                $self._CreateFormPanel()
                
                # Subscribe to store updates
                $self._subscriptions += $services.Store.Subscribe("tasks", {
                    param($data)
                    if ($self._taskTable) {
                        $self._taskTable.Data = $data.NewValue
                        if ($self._taskTable.ProcessData) {
                            & $self._taskTable.ProcessData -self $self._taskTable
                        }
                    }
                })
                
                $self._subscriptions += $services.Store.Subscribe("taskFilter", {
                    param($data)
                    $services.Store.Dispatch("TASKS_REFRESH")
                })
                
                $self._subscriptions += $services.Store.Subscribe("taskSort", {
                    param($data)
                    $services.Store.Dispatch("TASKS_REFRESH")
                })
                
                # Register store actions
                if (-not $services.Store._actions.ContainsKey("TASKS_REFRESH")) {
                    & $services.Store.RegisterAction -actionName "TASKS_REFRESH" -scriptBlock {
                        param($Context)
                        
                        $filter = $Context.GetState("taskFilter") ?? "all"
                        $sort = $Context.GetState("taskSort") ?? "priority"
                        
                        # Get raw tasks
                        $tasks = @()
                        if ($global:Data -and $global:Data.tasks) {
                            $tasks = $global:Data.tasks
                        }
                        
                        # Apply filter
                        $filtered = switch ($filter) {
                            "active" { $tasks | Where-Object { -not $_.completed } }
                            "completed" { $tasks | Where-Object { $_.completed } }
                            default { $tasks }
                        }
                        
                        # Apply sort
                        $sorted = switch ($sort) {
                            "priority" {
                                $filtered | Sort-Object @{
                                    Expression = {
                                        switch ($_.priority) {
                                            "Critical" { 0 }
                                            "High" { 1 }
                                            "Medium" { 2 }
                                            "Low" { 3 }
                                            default { 4 }
                                        }
                                    }
                                }, created
                            }
                            "dueDate" { $filtered | Sort-Object dueDate, priority }
                            "created" { $filtered | Sort-Object created -Descending }
                            default { $filtered }
                        }
                        
                        # Transform for display
                        $displayTasks = @($sorted | ForEach-Object {
                            @{
                                Id = $_.id ?? [Guid]::NewGuid().ToString()
                                Status = if ($_.completed) { "✓" } else { " " }
                                Priority = $_.priority ?? "Medium"
                                Title = $_.title ?? "Untitled"
                                Category = $_.category ?? "General"
                                DueDate = if ($_.dueDate) { 
                                    try { [DateTime]::Parse($_.dueDate).ToString("yyyy-MM-dd") } 
                                    catch { $_.dueDate }
                                } else { "" }
                            }
                        })
                        
                        $Context.UpdateState(@{ tasks = $displayTasks })
                    }
                    
                    & $services.Store.RegisterAction -actionName "TASK_TOGGLE_STATUS" -scriptBlock {
                        param($Context, $Payload)
                        
                        if ($global:Data -and $global:Data.tasks -and $Payload.TaskId) {
                            $task = $global:Data.tasks | Where-Object { $_.id -eq $Payload.TaskId }
                            if ($task) {
                                $task.completed = -not $task.completed
                                $task.completedDate = if ($task.completed) { Get-Date } else { $null }
                                
                                # Save data
                                if (Get-Command Save-UnifiedData -ErrorAction SilentlyContinue) {
                                    Save-UnifiedData
                                }
                                
                                # Refresh display
                                $Context.Dispatch("TASKS_REFRESH")
                            }
                        }
                    }
                    
                    & $services.Store.RegisterAction -actionName "TASK_CREATE" -scriptBlock {
                        param($Context, $Payload)
                        
                        if (-not $global:Data) { $global:Data = @{} }
                        if (-not $global:Data.tasks) { $global:Data.tasks = @() }
                        
                        $newTask = @{
                            id = [Guid]::NewGuid().ToString()
                            title = $Payload.Title
                            description = $Payload.Description
                            category = $Payload.Category
                            priority = $Payload.Priority
                            dueDate = $Payload.DueDate
                            created = Get-Date
                            completed = $false
                        }
                        
                        $global:Data.tasks += $newTask
                        
                        # Save data
                        if (Get-Command Save-UnifiedData -ErrorAction SilentlyContinue) {
                            Save-UnifiedData
                        }
                        
                        # Refresh display
                        $Context.Dispatch("TASKS_REFRESH")
                    }
                    
                    & $services.Store.RegisterAction -actionName "TASK_UPDATE" -scriptBlock {
                        param($Context, $Payload)
                        
                        if ($global:Data -and $global:Data.tasks -and $Payload.TaskId) {
                            $task = $global:Data.tasks | Where-Object { $_.id -eq $Payload.TaskId }
                            if ($task) {
                                $task.title = $Payload.Title
                                $task.description = $Payload.Description
                                $task.category = $Payload.Category
                                $task.priority = $Payload.Priority
                                $task.dueDate = $Payload.DueDate
                                
                                # Save data
                                if (Get-Command Save-UnifiedData -ErrorAction SilentlyContinue) {
                                    Save-UnifiedData
                                }
                                
                                # Refresh display
                                $Context.Dispatch("TASKS_REFRESH")
                            }
                        }
                    }
                    
                    & $services.Store.RegisterAction -actionName "TASK_DELETE" -scriptBlock {
                        param($Context, $Payload)
                        
                        if ($global:Data -and $global:Data.tasks -and $Payload.TaskId) {
                            $global:Data.tasks = @($global:Data.tasks | Where-Object { $_.id -ne $Payload.TaskId })
                            
                            # Save data
                            if (Get-Command Save-UnifiedData -ErrorAction SilentlyContinue) {
                                Save-UnifiedData
                            }
                            
                            # Refresh display
                            $Context.Dispatch("TASKS_REFRESH")
                        }
                    }
                }
                
                # Initialize filter and sort state
                $services.Store.Dispatch("UPDATE_STATE", @{
                    taskFilter = "all"
                    taskSort = "priority"
                })
                
                # Load initial data
                $services.Store.Dispatch("TASKS_REFRESH")
                
                Write-Log -Level Debug -Message "Task screen Init completed"
                
            } catch {
                Write-Log -Level Error -Message "Task screen Init error: $_" -Data $_
            }
        }
        
        _CreateFormPanel = {
            $formPanel = New-TuiGridPanel -Props @{
                X = 10
                Y = 4
                Width = 60
                Height = 20
                ShowBorder = $true
                Title = " New Task "
                Visible = $false
                BackgroundColor = (Get-ThemeColor "Background" -Default Black)
                RowDefinitions = @("3", "3", "3", "3", "3", "3", "1*")  # Fixed rows + flexible bottom
                ColumnDefinitions = @("15", "1*")  # Label column + input column
            }
            
            # Title field
            $titleLabel = New-TuiLabel -Props @{ Text = "Title:"; Height = 1 }
            $titleInput = New-TuiTextBox -Props @{
                Name = "formTitle"
                IsFocusable = $true
                Height = 3
                Placeholder = "Enter task title..."
            }
            & $formPanel.AddChild -self $formPanel -Child $titleLabel -LayoutProps @{ "Grid.Row" = 0; "Grid.Column" = 0 }
            & $formPanel.AddChild -self $formPanel -Child $titleInput -LayoutProps @{ "Grid.Row" = 0; "Grid.Column" = 1 }
            
            # Description field
            $descLabel = New-TuiLabel -Props @{ Text = "Description:"; Height = 1 }
            $descInput = New-TuiTextBox -Props @{
                Name = "formDescription"
                IsFocusable = $true
                Height = 3
                Placeholder = "Enter description..."
            }
            & $formPanel.AddChild -self $formPanel -Child $descLabel -LayoutProps @{ "Grid.Row" = 1; "Grid.Column" = 0 }
            & $formPanel.AddChild -self $formPanel -Child $descInput -LayoutProps @{ "Grid.Row" = 1; "Grid.Column" = 1 }
            
            # Category dropdown
            $catLabel = New-TuiLabel -Props @{ Text = "Category:"; Height = 1 }
            $catDropdown = New-TuiDropdown -Props @{
                Name = "formCategory"
                IsFocusable = $true
                Height = 3
                Options = @("Work", "Personal", "Urgent", "Projects") | ForEach-Object { @{ Display = $_; Value = $_ } }
                Value = "Work"
            }
            & $formPanel.AddChild -self $formPanel -Child $catLabel -LayoutProps @{ "Grid.Row" = 2; "Grid.Column" = 0 }
            & $formPanel.AddChild -self $formPanel -Child $catDropdown -LayoutProps @{ "Grid.Row" = 2; "Grid.Column" = 1 }
            
            # Priority dropdown
            $priLabel = New-TuiLabel -Props @{ Text = "Priority:"; Height = 1 }
            $priDropdown = New-TuiDropdown -Props @{
                Name = "formPriority"
                IsFocusable = $true
                Height = 3
                Options = @("Critical", "High", "Medium", "Low") | ForEach-Object { @{ Display = $_; Value = $_ } }
                Value = "Medium"
            }
            & $formPanel.AddChild -self $formPanel -Child $priLabel -LayoutProps @{ "Grid.Row" = 3; "Grid.Column" = 0 }
            & $formPanel.AddChild -self $formPanel -Child $priDropdown -LayoutProps @{ "Grid.Row" = 3; "Grid.Column" = 1 }
            
            # Due date picker
            $dueLabel = New-TuiLabel -Props @{ Text = "Due Date:"; Height = 1 }
            $duePicker = New-TuiDatePicker -Props @{
                Name = "formDueDate"
                IsFocusable = $true
                Height = 3
                Value = (Get-Date).AddDays(7)
            }
            & $formPanel.AddChild -self $formPanel -Child $dueLabel -LayoutProps @{ "Grid.Row" = 4; "Grid.Column" = 0 }
            & $formPanel.AddChild -self $formPanel -Child $duePicker -LayoutProps @{ "Grid.Row" = 4; "Grid.Column" = 1 }
            
            # Buttons
            $buttonPanel = New-TuiStackPanel -Props @{
                Orientation = "Horizontal"
                HorizontalAlignment = "Center"
                Spacing = 2
                Height = 3
            }
            
            $saveButton = New-TuiButton -Props @{
                Text = "Save"
                Width = 12
                Height = 3
                IsFocusable = $true
                OnClick = { & $self._SaveTask }
            }
            
            $cancelButton = New-TuiButton -Props @{
                Text = "Cancel"
                Width = 12
                Height = 3
                IsFocusable = $true
                OnClick = { & $self._HideForm }
            }
            
            & $buttonPanel.AddChild -self $buttonPanel -Child $saveButton
            & $buttonPanel.AddChild -self $buttonPanel -Child $cancelButton
            & $formPanel.AddChild -self $formPanel -Child $buttonPanel -LayoutProps @{ 
                "Grid.Row" = 6
                "Grid.Column" = 0
                "Grid.ColumnSpan" = 2
            }
            
            # Store form panel and references
            $self.Components.formPanel = $formPanel
            $self._formFields = @{
                Title = $titleInput
                Description = $descInput
                Category = $catDropdown
                Priority = $priDropdown
                DueDate = $duePicker
            }
        }
        
        _ShowForm = {
            param($taskId = $null)
            
            Write-Log -Level Debug -Message "Showing task form, taskId: $taskId"
            
            $self._formVisible = $true
            $self._editingTaskId = $taskId
            
            # Update form title
            $self.Components.formPanel.Title = if ($taskId) { " Edit Task " } else { " New Task " }
            
            # Populate form if editing
            if ($taskId -and $global:Data -and $global:Data.tasks) {
                $task = $global:Data.tasks | Where-Object { $_.id -eq $taskId }
                if ($task) {
                    $self._formFields.Title.Text = $task.title ?? ""
                    $self._formFields.Description.Text = $task.description ?? ""
                    $self._formFields.Category.Value = $task.category ?? "Work"
                    $self._formFields.Priority.Value = $task.priority ?? "Medium"
                    if ($task.dueDate) {
                        try {
                            $self._formFields.DueDate.Value = [DateTime]::Parse($task.dueDate)
                        } catch {
                            $self._formFields.DueDate.Value = (Get-Date).AddDays(7)
                        }
                    }
                }
            } else {
                # Clear form for new task
                $self._formFields.Title.Text = ""
                $self._formFields.Description.Text = ""
                $self._formFields.Category.Value = "Work"
                $self._formFields.Priority.Value = "Medium"
                $self._formFields.DueDate.Value = (Get-Date).AddDays(7)
            }
            
            # Show form
            & $self.Components.formPanel.Show -self $self.Components.formPanel
            
            # Focus first field
            if (Get-Command Request-Focus -ErrorAction SilentlyContinue) {
                Request-Focus -Component $self._formFields.Title
            }
            
            Request-TuiRefresh
        }
        
        _HideForm = {
            Write-Log -Level Debug -Message "Hiding task form"
            
            $self._formVisible = $false
            $self._editingTaskId = $null
            
            # Hide form
            & $self.Components.formPanel.Hide -self $self.Components.formPanel
            
            # Return focus to table
            if (Get-Command Request-Focus -ErrorAction SilentlyContinue) {
                Request-Focus -Component $self._taskTable
            }
            
            # Force full redraw to clear artifacts
            $global:TuiState.RenderStats.FrameCount = 0
            Request-TuiRefresh
        }
        
        _SaveTask = {
            Write-Log -Level Debug -Message "Saving task"
            
            $formData = @{
                Title = $self._formFields.Title.Text
                Description = $self._formFields.Description.Text
                Category = $self._formFields.Category.Value
                Priority = $self._formFields.Priority.Value
                DueDate = if ($self._formFields.DueDate.Value -is [DateTime]) {
                    $self._formFields.DueDate.Value.ToString("yyyy-MM-dd")
                } else {
                    $self._formFields.DueDate.Value
                }
            }
            
            # Validate
            if ([string]::IsNullOrWhiteSpace($formData.Title)) {
                Show-AlertDialog -Title "Validation Error" -Message "Task title is required"
                return
            }
            
            # Dispatch appropriate action
            $services = $global:Services
            if ($self._editingTaskId) {
                $formData.TaskId = $self._editingTaskId
                $services.Store.Dispatch("TASK_UPDATE", $formData)
            } else {
                $services.Store.Dispatch("TASK_CREATE", $formData)
            }
            
            & $self._HideForm
        }
        
        Render = {
            param($self)
            
            try {
                # Render main layout
                if ($self.Components.rootPanel -and $self.Components.rootPanel.Render) {
                    & $self.Components.rootPanel.Render -self $self.Components.rootPanel
                }
                
                # Render form on top if visible
                if ($self._formVisible -and $self.Components.formPanel -and $self.Components.formPanel.Render) {
                    # Clear area behind form
                    $panel = $self.Components.formPanel
                    for ($y = $panel.Y; $y -lt ($panel.Y + $panel.Height); $y++) {
                        Write-BufferString -X $panel.X -Y $y -Text (" " * $panel.Width) -BackgroundColor Black
                    }
                    
                    # Render form
                    & $self.Components.formPanel.Render -self $self.Components.formPanel
                }
                
                # Status bar
                $statusY = $global:TuiState.BufferHeight - 1
                $statusText = if ($self._formVisible) {
                    "Tab: Next Field | Esc: Cancel"
                } else {
                    "N: New | E: Edit | D: Delete | Space: Toggle | Q: Back"
                }
                Write-BufferString -X 2 -Y $statusY -Text $statusText -ForegroundColor (Get-ThemeColor "Subtle" -Default DarkGray)
                
            } catch {
                Write-Log -Level Error -Message "Task screen Render error: $_" -Data $_
                Write-BufferString -X 2 -Y 2 -Text "Error rendering task screen: $_" -ForegroundColor Red
            }
        }
        
        HandleInput = {
            param($self, $Key)
            
            try {
                $services = $global:Services
                if (-not $services) {
                    return $false
                }
                
                # Form mode input handling
                if ($self._formVisible) {
                    if ($services.Keybindings.IsAction("Form.Cancel", $Key) -or $Key.Key -eq [ConsoleKey]::Escape) {
                        & $self._HideForm
                        return $true
                    }
                    return $false  # Let focus manager handle tab navigation
                }
                
                # List mode input handling
                switch ($Key.KeyChar) {
                    'n' { & $self._ShowForm; return $true }
                    'e' {
                        $selected = $self._taskTable.SelectedRow
                        if ($selected -ge 0 -and $selected -lt $self._taskTable.ProcessedData.Count) {
                            $taskId = $self._taskTable.ProcessedData[$selected].Id
                            & $self._ShowForm -taskId $taskId
                        }
                        return $true
                    }
                    'd' {
                        $selected = $self._taskTable.SelectedRow
                        if ($selected -ge 0 -and $selected -lt $self._taskTable.ProcessedData.Count) {
                            $taskId = $self._taskTable.ProcessedData[$selected].Id
                            Show-ConfirmDialog -Title "Delete Task" -Message "Are you sure you want to delete this task?" -OnConfirm {
                                $services.Store.Dispatch("TASK_DELETE", @{ TaskId = $taskId })
                            }
                        }
                        return $true
                    }
                    'q' { return "Back" }
                    
                    # Filter keys
                    '1' { $services.Store.Dispatch("UPDATE_STATE", @{ taskFilter = "all" }); return $true }
                    '2' { $services.Store.Dispatch("UPDATE_STATE", @{ taskFilter = "active" }); return $true }
                    '3' { $services.Store.Dispatch("UPDATE_STATE", @{ taskFilter = "completed" }); return $true }
                    
                    # Sort keys
                    'p' { $services.Store.Dispatch("UPDATE_STATE", @{ taskSort = "priority" }); return $true }
                    'd' { $services.Store.Dispatch("UPDATE_STATE", @{ taskSort = "dueDate" }); return $true }
                    'c' { $services.Store.Dispatch("UPDATE_STATE", @{ taskSort = "created" }); return $true }
                }
                
                # Check global keybindings
                $action = $services.Keybindings.HandleKey($Key)
                if ($action -eq "App.Back") {
                    return "Back"
                }
                
                return $false
                
            } catch {
                Write-Log -Level Error -Message "Task screen HandleInput error: $_" -Data $_
                return $false
            }
        }
        
        OnExit = {
            param($self)
            
            Write-Log -Level Debug -Message "Task screen exiting"
            
            # Unsubscribe from store
            $services = $global:Services
            if ($services -and $services.Store) {
                foreach ($subId in $self._subscriptions) {
                    $services.Store.Unsubscribe($subId)
                }
            }
        }
        
        OnResume = {
            param($self)
            
            Write-Log -Level Debug -Message "Task screen resuming"
            
            # Force complete redraw
            if ($global:TuiState -and $global:TuiState.RenderStats) {
                $global:TuiState.RenderStats.FrameCount = 0
            }
            
            # Refresh data
            $services = $global:Services
            if ($services -and $services.Store) {
                $services.Store.Dispatch("TASKS_REFRESH")
            }
            
            Request-TuiRefresh
        }
    }
    
    return $screen
}

# Alias for backward compatibility
function global:Get-TaskScreen {
    return Get-TaskManagementScreen
}

Export-ModuleMember -Function Get-TaskManagementScreen, Get-TaskScreen
