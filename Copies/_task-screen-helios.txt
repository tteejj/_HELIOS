# Task Screen - Simplified with separate list/form views and defensive programming
# Fixed all scope issues and null reference errors

function Get-TaskManagementScreen {
    param([hashtable]$Services)
    
    $screen = @{
        Name = "TaskManagementScreen"
        Components = @{}
        Children = @()
        _subscriptions = @()
        _services = $null
        _formMode = $null  # null = list view, "create" = new task, "edit" = edit task
        _selectedTask = $null
        _focusIndex = 0
        _focusableComponents = @()
        Visible = $true
        ZIndex = 0
        
        Init = {
            param($self, $services)
            
            # Defensive service validation
            if (-not $services) {
                Write-Log -Level Error -Message "Task Screen Init: No services provided"
                if ($self._services) {
                    $services = $self._services
                } elseif ($global:Services) {
                    $services = $global:Services
                } else {
                    Write-Log -Level Critical -Message "Task Screen Init: No services available"
                    return
                }
            }
            
            $self._services = $services
            Write-Log -Level Info -Message "Task Screen Init: Starting initialization"
            
            # Create root container
            $rootPanel = New-TuiStackPanel -Props @{
                X = 0
                Y = 0
                Width = $global:TuiState.BufferWidth
                Height = $global:TuiState.BufferHeight
                ShowBorder = $false
                Orientation = "Vertical"
            }
            
            if (-not $rootPanel) {
                Write-Log -Level Critical -Message "Task Screen Init: Failed to create root panel"
                return
            }
            
            $self.Components.rootPanel = $rootPanel
            $self.Children = @($rootPanel)
            
            # Create list view panel
            $listPanel = New-TuiStackPanel -Props @{
                Name = "listPanel"
                X = 1
                Y = 1
                Width = ($global:TuiState.BufferWidth - 2)
                Height = ($global:TuiState.BufferHeight - 2)
                ShowBorder = $true
                Title = " Task Management "
                Orientation = "Vertical"
                Spacing = 1
                Padding = 1
                Visible = $true
            }
            
            # Header with instructions
            $headerLabel = New-TuiLabel -Props @{
                Text = "Tasks - [N]ew, [E]dit, [D]elete, [Space] Toggle, [ESC] Back"
                Height = 1
            }
            & $listPanel.AddChild -self $listPanel -Child $headerLabel | Out-Null
            
            # Task table
            $capturedSelf = $self
            $capturedServices = $services
            
            $taskTable = New-TuiDataTable -Props @{
                Name = "taskTable"
                IsFocusable = $true
                ShowBorder = $true
                Height = ($global:TuiState.BufferHeight - 8)
                Columns = @(
                    @{ Name = "Status"; Width = 6; Align = "Center" }
                    @{ Name = "Priority"; Width = 8; Align = "Center" }
                    @{ Name = "Title"; Width = 40; Align = "Left" }
                    @{ Name = "Category"; Width = 15; Align = "Left" }
                    @{ Name = "DueDate"; Width = 10; Align = "Center" }
                )
                Data = @()
                OnRowSelect = {
                    param($SelectedData, $SelectedIndex)
                    # Row selection handled by keyboard shortcuts
                    Write-Log -Level Debug -Message "Task selected: $($SelectedData.Title)"
                }
            }
            
            & $listPanel.AddChild -self $listPanel -Child $taskTable | Out-Null
            & $rootPanel.AddChild -self $rootPanel -Child $listPanel | Out-Null
            
            # Create form view panel (initially hidden)
            $formPanel = New-TuiStackPanel -Props @{
                Name = "formPanel"
                X = 1
                Y = 1
                Width = ($global:TuiState.BufferWidth - 2)
                Height = ($global:TuiState.BufferHeight - 2)
                ShowBorder = $true
                Title = " Task Form "
                Orientation = "Vertical"
                Spacing = 1
                Padding = 2
                Visible = $false
            }
            
            # Form fields
            $titleInput = New-TuiTextBox -Props @{
                Name = "titleInput"
                IsFocusable = $true
                Label = "Title:"
                Width = 60
                Height = 3
                MaxLength = 100
                Text = ""
            }
            
            $descInput = New-TuiTextBox -Props @{
                Name = "descInput"
                IsFocusable = $true
                Label = "Description:"
                Width = 60
                Height = 5
                MaxLength = 500
                Multiline = $true
                Text = ""
            }
            
            $priorityDropdown = New-TuiDropdown -Props @{
                Name = "priorityDropdown"
                IsFocusable = $true
                Label = "Priority:"
                Width = 20
                Options = @(
                    @{ Display = "Low"; Value = "low" }
                    @{ Display = "Medium"; Value = "medium" }
                    @{ Display = "High"; Value = "high" }
                )
                Value = "medium"
            }
            
            $categoryInput = New-TuiTextBox -Props @{
                Name = "categoryInput"
                IsFocusable = $true
                Label = "Category:"
                Width = 30
                Height = 3
                MaxLength = 50
                Text = "General"
            }
            
            $dueDateInput = New-TuiTextBox -Props @{
                Name = "dueDateInput"
                IsFocusable = $true
                Label = "Due Date (YYYY-MM-DD):"
                Width = 20
                Height = 3
                MaxLength = 10
                Text = ""
            }
            
            # Button panel
            $buttonPanel = New-TuiStackPanel -Props @{
                Orientation = "Horizontal"
                Spacing = 2
                Height = 3
            }
            
            $saveButton = New-TuiButton -Props @{
                Text = "[S]ave"
                Width = 10
                IsFocusable = $true
                OnClick = {
                    Write-Log -Level Info -Message "Save button clicked"
                    & $capturedSelf.SaveTask -self $capturedSelf
                }
            }
            
            $cancelButton = New-TuiButton -Props @{
                Text = "[C]ancel"
                Width = 10
                IsFocusable = $true
                OnClick = {
                    Write-Log -Level Info -Message "Cancel button clicked"
                    & $capturedSelf.ShowListView -self $capturedSelf
                }
            }
            
            & $buttonPanel.AddChild -self $buttonPanel -Child $saveButton | Out-Null
            & $buttonPanel.AddChild -self $buttonPanel -Child $cancelButton | Out-Null
            
            # Add all form fields to form panel
            & $formPanel.AddChild -self $formPanel -Child $titleInput | Out-Null
            & $formPanel.AddChild -self $formPanel -Child $descInput | Out-Null
            & $formPanel.AddChild -self $formPanel -Child $priorityDropdown | Out-Null
            & $formPanel.AddChild -self $formPanel -Child $categoryInput | Out-Null
            & $formPanel.AddChild -self $formPanel -Child $dueDateInput | Out-Null
            & $formPanel.AddChild -self $formPanel -Child $buttonPanel | Out-Null
            
            & $rootPanel.AddChild -self $rootPanel -Child $formPanel | Out-Null
            
            # Store component references
            $self.Components.listPanel = $listPanel
            $self.Components.formPanel = $formPanel
            $self.Components.taskTable = $taskTable
            $self.Components.titleInput = $titleInput
            $self.Components.descInput = $descInput
            $self.Components.priorityDropdown = $priorityDropdown
            $self.Components.categoryInput = $categoryInput
            $self.Components.dueDateInput = $dueDateInput
            $self.Components.saveButton = $saveButton
            $self.Components.cancelButton = $cancelButton
            
            # Store focusable components for form
            $self._formFocusableComponents = @(
                $titleInput,
                $descInput,
                $priorityDropdown,
                $categoryInput,
                $dueDateInput,
                $saveButton,
                $cancelButton
            )
            
            # Helper functions
            $self.ShowListView = {
                param($self)
                Write-Log -Level Debug -Message "Showing list view"
                $self._formMode = $null
                $self._selectedTask = $null
                $self._focusIndex = 0
                $self.Components.listPanel.Visible = $true
                $self.Components.formPanel.Visible = $false
                if ($self.Components.taskTable.Focus) {
                    & $self.Components.taskTable.Focus -self $self.Components.taskTable
                }
                Request-TuiRefresh
            }
            
            $self.ShowFormView = {
                param($self, $mode, $task)
                Write-Log -Level Debug -Message "Showing form view: $mode"
                $self._formMode = $mode
                $self._selectedTask = $task
                $self._focusIndex = 0
                
                # Update form title
                $self.Components.formPanel.Title = if ($mode -eq "create") { " New Task " } else { " Edit Task " }
                
                # Clear or populate form fields
                if ($mode -eq "create") {
                    $self.Components.titleInput.Text = ""
                    $self.Components.descInput.Text = ""
                    $self.Components.priorityDropdown.Value = "medium"
                    $self.Components.categoryInput.Text = "General"
                    $self.Components.dueDateInput.Text = ""
                } elseif ($task) {
                    $self.Components.titleInput.Text = if ($task.Title) { $task.Title } else { "" }
                    $self.Components.descInput.Text = if ($task.Description) { $task.Description } else { "" }
                    $self.Components.priorityDropdown.Value = if ($task.Priority) { $task.Priority } else { "medium" }
                    $self.Components.categoryInput.Text = if ($task.Category) { $task.Category } else { "General" }
                    $self.Components.dueDateInput.Text = if ($task.DueDate -and $task.DueDate -ne "N/A") { $task.DueDate } else { "" }
                }
                
                # Show form
                $self.Components.listPanel.Visible = $false
                $self.Components.formPanel.Visible = $true
                
                # Focus first field
                if ($self.Components.titleInput.Focus) {
                    & $self.Components.titleInput.Focus -self $self.Components.titleInput
                }
                
                Request-TuiRefresh
            }
            
            $self.SaveTask = {
                param($self)
                Write-Log -Level Info -Message "SaveTask called"
                
                if (-not $self._services -or -not $self._services.Store) {
                    Write-Log -Level Error -Message "SaveTask: Services not available"
                    return
                }
                
                # Validate input
                $title = $self.Components.titleInput.Text
                if ([string]::IsNullOrWhiteSpace($title)) {
                    Write-Log -Level Warning -Message "SaveTask: Title is required"
                    return
                }
                
                # Build payload
                $payload = @{
                    Title = $title.Trim()
                    Description = $self.Components.descInput.Text
                    Priority = $self.Components.priorityDropdown.Value
                    Category = $self.Components.categoryInput.Text
                    DueDate = $self.Components.dueDateInput.Text
                }
                
                # Dispatch appropriate action
                if ($self._formMode -eq "create") {
                    Write-Log -Level Info -Message "Creating new task: $title"
                    & $self._services.Store.Dispatch -self $self._services.Store -actionName "TASK_CREATE" -payload $payload
                } elseif ($self._formMode -eq "edit" -and $self._selectedTask) {
                    $payload.TaskId = $self._selectedTask.Id
                    Write-Log -Level Info -Message "Updating task: $($self._selectedTask.Id)"
                    & $self._services.Store.Dispatch -self $self._services.Store -actionName "TASK_UPDATE" -payload $payload
                }
                
                # Return to list view
                & $self.ShowListView -self $self
            }
            
            # Subscribe to task updates
            $screen = $self
            $self._subscriptions += & $services.Store.Subscribe -self $services.Store -path "tasks" -handler {
                param($data)
                if ($screen.Components.taskTable) {
                    $newTasks = if ($data.NewValue) { @($data.NewValue) } else { @() }
                    $screen.Components.taskTable.Data = $newTasks
                    if ($screen.Components.taskTable.ProcessData) {
                        & $screen.Components.taskTable.ProcessData -self $screen.Components.taskTable
                    }
                    Request-TuiRefresh
                }
            }
            
            # Initial data load
            & $services.Store.Dispatch -self $services.Store -actionName "TASKS_REFRESH"
            
            # Focus on task table
            if ($taskTable.Focus) {
                & $taskTable.Focus -self $taskTable
            }
            
            Write-Log -Level Info -Message "Task Screen Init: Completed successfully"
        }
        
        HandleInput = {
            param($self, $key)
            
            if (-not $key) { return $false }
            
            # Handle form mode input
            if ($self._formMode) {
                # Form navigation
                if ($key.Key -eq "Tab") {
                    if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
                        # Previous field
                        $self._focusIndex--
                        if ($self._focusIndex -lt 0) {
                            $self._focusIndex = $self._formFocusableComponents.Count - 1
                        }
                    } else {
                        # Next field
                        $self._focusIndex++
                        if ($self._focusIndex -ge $self._formFocusableComponents.Count) {
                            $self._focusIndex = 0
                        }
                    }
                    
                    $focusComponent = $self._formFocusableComponents[$self._focusIndex]
                    if ($focusComponent -and $focusComponent.Focus) {
                        & $focusComponent.Focus -self $focusComponent
                    }
                    return $true
                }
                
                # Form shortcuts
                switch ($key.Character) {
                    's' { & $self.SaveTask -self $self; return $true }
                    'S' { & $self.SaveTask -self $self; return $true }
                    'c' { & $self.ShowListView -self $self; return $true }
                    'C' { & $self.ShowListView -self $self; return $true }
                }
                
                # ESC to cancel
                if ($key.Key -eq "Escape") {
                    & $self.ShowListView -self $self
                    return $true
                }
                
                # Pass to focused component
                $focusComponent = $self._formFocusableComponents[$self._focusIndex]
                if ($focusComponent -and $focusComponent.HandleInput) {
                    return & $focusComponent.HandleInput -self $focusComponent -key $key
                }
            } else {
                # List mode input
                switch ($key.Character) {
                    'n' { & $self.ShowFormView -self $self -mode "create"; return $true }
                    'N' { & $self.ShowFormView -self $self -mode "create"; return $true }
                    'e' {
                        $selected = $self.Components.taskTable.GetSelectedData()
                        if ($selected) {
                            & $self.ShowFormView -self $self -mode "edit" -task $selected
                        }
                        return $true
                    }
                    'E' {
                        $selected = $self.Components.taskTable.GetSelectedData()
                        if ($selected) {
                            & $self.ShowFormView -self $self -mode "edit" -task $selected
                        }
                        return $true
                    }
                    'd' {
                        $selected = $self.Components.taskTable.GetSelectedData()
                        if ($selected -and $self._services -and $self._services.Store) {
                            Write-Log -Level Info -Message "Deleting task: $($selected.Id)"
                            & $self._services.Store.Dispatch -self $self._services.Store -actionName "TASK_DELETE" -payload @{ TaskId = $selected.Id }
                        }
                        return $true
                    }
                    'D' {
                        $selected = $self.Components.taskTable.GetSelectedData()
                        if ($selected -and $self._services -and $self._services.Store) {
                            Write-Log -Level Info -Message "Deleting task: $($selected.Id)"
                            & $self._services.Store.Dispatch -self $self._services.Store -actionName "TASK_DELETE" -payload @{ TaskId = $selected.Id }
                        }
                        return $true
                    }
                    ' ' {
                        # Space to toggle completion
                        $selected = $self.Components.taskTable.GetSelectedData()
                        if ($selected -and $self._services -and $self._services.Store) {
                            $newStatus = $selected.Status -ne "✓"
                            Write-Log -Level Info -Message "Toggling task status: $($selected.Id)"
                            & $self._services.Store.Dispatch -self $self._services.Store -actionName "TASK_UPDATE" -payload @{ 
                                TaskId = $selected.Id
                                Completed = $newStatus
                            }
                        }
                        return $true
                    }
                }
                
                # ESC to go back
                if ($key.Key -eq "Escape" -and $self._services -and $self._services.Navigation) {
                    & $self._services.Navigation.GoTo -self $self._services.Navigation -Path "/dashboard" -Services $self._services
                    return $true
                }
                
                # Pass to task table
                if ($self.Components.taskTable -and $self.Components.taskTable.HandleInput) {
                    return & $self.Components.taskTable.HandleInput -self $self.Components.taskTable -key $key
                }
            }
            
            return $false
        }
        
        OnExit = {
            param($self)
            Write-Log -Level Info -Message "Task Screen OnExit: Cleaning up"
            
            # Unsubscribe from all subscriptions
            if ($self._subscriptions -and @($self._subscriptions).Count -gt 0) {
                foreach ($subId in $self._subscriptions) {
                    if ($subId -and $self._services -and $self._services.Store) {
                        try {
                            & $self._services.Store.Unsubscribe -self $self._services.Store -subId $subId
                        } catch {
                            Write-Log -Level Warning -Message "Failed to unsubscribe: $_"
                        }
                    }
                }
                $self._subscriptions = @()
            }
        }
        
        Render = {
            param($self)
            # Components handle their own rendering
        }
    }
    
    return $screen
}

# Alias for compatibility
function Get-TaskScreen {
    param([hashtable]$Services)
    return Get-TaskManagementScreen -Services $Services
}

Export-ModuleMember -Function @('Get-TaskManagementScreen', 'Get-TaskScreen')