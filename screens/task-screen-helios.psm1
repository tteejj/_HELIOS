# Task Management Screen - Helios Service-Based Version
# Uses the new service architecture with app store, navigation, and layout panels

function global:Get-TaskManagementScreen {
    param([hashtable]$Services)
    $screen = @{
        Name = "TaskScreen"
        Components = @{}
        _subscriptions = @()
        _formVisible = $false
        _editingTaskId = $null
        
        Init = {
            param($self)
            $self._services = $Services # Store injected services
            
            Write-Log -Level Debug -Message "Task screen Init started (Helios version)"
            
            try {
                # Access services
                $services = $self._services
                if (-not $services) {
                    Write-Log -Level Error -Message "Services not available via self._services in Init. Cannot proceed with TaskScreenHelios Init."
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
                        param($SelectedData, $SelectedIndex)
                        if ($SelectedData -and $SelectedData.Id) {
                            # Use services stored in $self
                            $self._services.Store.Dispatch("TASK_TOGGLE_STATUS", @{ TaskId = $SelectedData.Id })
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
                $self._subscriptions += & $services.Store.Subscribe -self $services.Store -path "tasks" -handler {
                    param($data)
                    if ($self._taskTable) {
                        $self._taskTable.Data = $data.NewValue
                        if ($self._taskTable.ProcessData) {
                            & $self._taskTable.ProcessData -self $self._taskTable
                        }
                    }
                }
                
                $self._subscriptions += & $services.Store.Subscribe -self $services.Store -path "taskFilter" -handler {
                    param($data)
                    & $services.Store.Dispatch -self $services.Store -actionName "TASKS_REFRESH"
                }
                
                $self._subscriptions += & $services.Store.Subscribe -self $services.Store -path "taskSort" -handler {
                    param($data)
                    & $services.Store.Dispatch -self $services.Store -actionName "TASKS_REFRESH"
                }
                
                # Initialize filter and sort state
                & $services.Store.Dispatch -self $services.Store -actionName "UPDATE_STATE" -payload @{
                    taskFilter = "all"
                    taskSort = "priority"
                }
                
                # Load initial data
                & $services.Store.Dispatch -self $services.Store -actionName "TASKS_REFRESH"
                
                Write-Log -Level Debug -Message "Task screen Init completed"
                
            } catch {
                Write-Log -Level Error -Message "Task screen Init error: $_" -Data $_
            }
        }
        
        _CreateFormPanel = {
            # Calculate centered position
            $formWidth = 60
            $formHeight = 20
            $formX = [Math]::Floor(($global:TuiState.BufferWidth - $formWidth) / 2)
            $formY = [Math]::Floor(($global:TuiState.BufferHeight - $formHeight) / 2)
            
            $formPanel = New-TuiGridPanel -Props @{
                X = $formX
                Y = $formY
                Width = $formWidth
                Height = $formHeight
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
            $allTasks = $null
            if ($self._services -and $self._services.Store) {
                $allTasks = & $self._services.Store.GetState -self $self._services.Store -path 'tasks'
            }

            if ($taskId -and $allTasks) {
                $task = $allTasks | Where-Object { $_.Id -eq $taskId } # Assuming Id is the correct property name from store
                if ($task) {
                    $self._formFields.Title.Text = $task.Title ?? ""
                    $self._formFields.Description.Text = $task.Description ?? "" # Assuming Description if available
                    $self._formFields.Category.Value = $task.Category ?? "Work"
                    $self._formFields.Priority.Value = $task.Priority ?? "Medium"
                    if ($task.DueDate) {
                        try {
                            $self._formFields.DueDate.Value = [DateTime]::Parse($task.DueDate)
                        } catch {
                            $self._formFields.DueDate.Value = (Get-Date).AddDays(7)
                        }
                    }
                } else {
                    Write-Log -Level Warning -Message "Task with ID '$taskId' not found in store for editing."
                    # Optionally clear form or show error
                    $self._formFields.Title.Text = ""
                    $self._formFields.Description.Text = ""
                    $self._formFields.Category.Value = "Work"
                    $self._formFields.Priority.Value = "Medium"
                    $self._formFields.DueDate.Value = (Get-Date).AddDays(7)
                }
            } else {
                # Clear form for new task or if tasks are not available from store
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
                    $self._formFields.DueDate.Value.ToString("yyyy-MM-dd") # Ensure date is stringified
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
            $services = $self._services # Ensure services are available
            if (-not $services -or -not $services.Store) {
                Write-Log -Level Error -Message "Store service not available in _SaveTask via self._services"
                Show-AlertDialog -Title "Error" -Message "Cannot save task: Store service unavailable."
                return
            }

            if ($self._editingTaskId) {
                $formData.TaskId = $self._editingTaskId
                & $services.Store.Dispatch -self $services.Store -actionName "TASK_UPDATE" -payload $formData
            } else {
                & $services.Store.Dispatch -self $services.Store -actionName "TASK_CREATE" -payload $formData
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
                $services = $self._services
                if (-not $services) {
                    Write-Log -Level Warning -Message "self._services not found in HandleInput for TaskScreenHelios"
                    return $false
                }
                
                # Form mode input handling
                if ($self._formVisible) {
                    if ((& $services.Keybindings.IsAction -self $services.Keybindings -ActionName "Form.Cancel" -KeyInfo $Key) -or $Key.Key -eq [ConsoleKey]::Escape) {
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
                                & $services.Store.Dispatch -self $services.Store -actionName "TASK_DELETE" -payload @{ TaskId = $taskId }
                            }
                        }
                        return $true
                    }
                    'q' { return "Back" }
                    
                    # Filter keys
                    '1' { & $services.Store.Dispatch -self $services.Store -actionName "UPDATE_STATE" -payload @{ taskFilter = "all" }; return $true }
                    '2' { & $services.Store.Dispatch -self $services.Store -actionName "UPDATE_STATE" -payload @{ taskFilter = "active" }; return $true }
                    '3' { & $services.Store.Dispatch -self $services.Store -actionName "UPDATE_STATE" -payload @{ taskFilter = "completed" }; return $true }
                    
                    # Sort keys
                    'p' { & $services.Store.Dispatch -self $services.Store -actionName "UPDATE_STATE" -payload @{ taskSort = "priority" }; return $true }
                    'd' { & $services.Store.Dispatch -self $services.Store -actionName "UPDATE_STATE" -payload @{ taskSort = "dueDate" }; return $true }
                    'c' { & $services.Store.Dispatch -self $services.Store -actionName "UPDATE_STATE" -payload @{ taskSort = "created" }; return $true }
                }
                
                # Check global keybindings
                $action = & $services.Keybindings.HandleKey -self $services.Keybindings -KeyInfo $Key
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
            if ($self._services -and $self._services.Store) {
                foreach ($subId in $self._subscriptions) {
                    & $self._services.Store.Unsubscribe -self $self._services.Store -subId $subId
                }
            }
        }
        
        OnResume = {
            param($self)
            
            Write-Log -Level Debug -Message "Task screen resuming"
            
            # Force complete redraw
            if ($global:TuiState -and $global:TuiState.RenderStats) { # $global:TuiState is fine
                $global:TuiState.RenderStats.FrameCount = 0
            }
            
            # Refresh data
            if ($self._services -and $self._services.Store) {
                & $self._services.Store.Dispatch -self $self._services.Store -actionName "TASKS_REFRESH"
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