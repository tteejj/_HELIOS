# Task Management Screen - Helios Service-Based Version (CORRECTED)
# Conforms to Z-Index rendering and proper service injection patterns

function Get-TaskManagementScreen {
    param([hashtable]$Services)

    $screen = @{
        Name = "TaskScreen"
        Components = @{}
        Children = @()     # FIX: Added Children array for the Z-Index renderer.
        _subscriptions = @()
        _formVisible = $false
        _editingTaskId = $null
        Visible = $true
        ZIndex = 0

        Init = {
            param($self, $services)
            Invoke-WithErrorHandling -Component "$($self.Name).Init" -ScriptBlock {
                Write-Log -Level Debug -Message "Task screen Init started (Helios version)"
                
                # FIX: More robust services handling
                if (-not $services) {
                    # Try to get from self
                    if ($self._services) {
                        $services = $self._services
                    }
                    # Try to get from global as fallback
                    elseif ($global:Services) {
                        $services = $global:Services
                        $self._services = $services
                    }
                    else {
                        Write-Log -Level Error -Message "Services not available for task screen - no fallback found"
                        return
                    }
                }
                else {
                    # Store the passed services
                    $self._services = $services
                }
                
                # Create root layout
                $rootPanel = New-TuiStackPanel -Props @{
                    X = 1; Y = 1
                    Width = ($global:TuiState.BufferWidth - 2)
                    Height = ($global:TuiState.BufferHeight - 2)
                    ShowBorder = $false; Orientation = "Vertical"; Spacing = 1
                }
                $self.Components.rootPanel = $rootPanel
                [void]($self.Children += $rootPanel) # FIX: Suppress pipeline output
                
                # Header & Toolbar
                [void](& $rootPanel.AddChild -self $rootPanel -Child (New-TuiLabel -Props @{ Text = "Task Management"; Height = 1 }))
                [void](& $rootPanel.AddChild -self $rootPanel -Child (New-TuiLabel -Props @{ Text = "Filter: [1]All [2]Active [3]Completed | Sort: [P]riority [D]ue Date [C]reated"; Height = 1 }))
                
                # Task table panel
                $tablePanel = New-TuiStackPanel -Props @{
                    Title = " Tasks "; ShowBorder = $true; Padding = 1
                    Height = ($global:TuiState.BufferHeight - 10)
                }
                
                # Capture store service for component handlers
                $storeService = $services.Store
                
                $taskTable = New-TuiDataTable -Props @{
                    Name = "taskTable"; IsFocusable = $true; ShowBorder = $false
                    Columns = @(
                        @{ Name = "Status"; Width = 3 }, @{ Name = "Priority"; Width = 10 },
                        @{ Name = "Title"; Width = 35 }, @{ Name = "Category"; Width = 12 },
                        @{ Name = "DueDate"; Width = 10 }
                    )
                    Data = @()
                    OnRowSelect = {
                        param($SelectedData, $SelectedIndex)
                        Invoke-WithErrorHandling -Component "taskTable.OnRowSelect" -ScriptBlock {
                            if ($SelectedData -and $SelectedData.Id) {
                                if ($storeService) {
                                    & $storeService.Dispatch -self $storeService -actionName "TASK_TOGGLE_STATUS" -payload @{ TaskId = $SelectedData.Id }
                                } else {
                                    throw "Store service not available in OnRowSelect handler."
                                }
                            }
                        } -Context @{ SelectedData = $SelectedData; SelectedIndex = $SelectedIndex } -ErrorHandler {
                            param($Exception)
                            Write-Log -Level Error -Message "TaskTable OnRowSelect error: $($Exception.Message)" -Data $Exception.Context
                        }
                    }
                }
                
                [void](& $tablePanel.AddChild -self $tablePanel -Child $taskTable)
                [void](& $rootPanel.AddChild -self $rootPanel -Child $tablePanel)
                
                $self._taskTable = $taskTable
                
                # Create form panel (initially hidden)
                & $self._CreateFormPanel -self $self
                if ($self.Components.formPanel) {
                    [void]($self.Children += $self.Components.formPanel) # FIX: Add formPanel to Children array.
                }
                
                # Capture references for use in handlers
                $screen = $self
                $taskTable = $self._taskTable
                $storeRef = $services.Store
                
                # Subscribe to store updates
                $self._subscriptions += & $services.Store.Subscribe -self $services.Store -path "tasks" -handler { 
                    param($data) 
                    Invoke-WithErrorHandling -Component "TaskScreen.tasksSubscription" -ScriptBlock {
                        # Handle both parameter styles
                        $newValue = if ($data.NewValue -ne $null) { $data.NewValue } else { $data }
                        if ($taskTable -and $newValue) {
                            $taskTable.Data = $newValue 
                            & $taskTable.ProcessData -self $taskTable
                            Write-Log -Level Debug -Message "Tasks table updated with $($newValue.Count) items"
                        }
                    } -Context @{ Data = $data } -ErrorHandler {
                        param($Exception)
                        Write-Log -Level Error -Message "TaskScreen tasks subscription error: $($Exception.Message)" -Data $Exception.Context
                    }
                }
                $self._subscriptions += & $services.Store.Subscribe -self $services.Store -path "taskFilter" -handler { 
                    param($data) 
                    Invoke-WithErrorHandling -Component "TaskScreen.taskFilterSubscription" -ScriptBlock {
                        if ($storeRef) {
                            & $storeRef.Dispatch -self $storeRef -actionName "TASKS_REFRESH" 
                        }
                    } -Context @{ Data = $data } -ErrorHandler {
                        param($Exception)
                        Write-Log -Level Error -Message "TaskScreen taskFilter subscription error: $($Exception.Message)" -Data $Exception.Context
                    }
                }
                $self._subscriptions += & $services.Store.Subscribe -self $services.Store -path "taskSort" -handler { 
                    param($data) 
                    Invoke-WithErrorHandling -Component "TaskScreen.taskSortSubscription" -ScriptBlock {
                        if ($storeRef) {
                            & $storeRef.Dispatch -self $storeRef -actionName "TASKS_REFRESH" 
                        }
                    } -Context @{ Data = $data } -ErrorHandler {
                        param($Exception)
                        Write-Log -Level Error -Message "TaskScreen taskSort subscription error: $($Exception.Message)" -Data $Exception.Context
                    }
                }
                
                # Load initial data
                [void](& $services.Store.Dispatch -self $services.Store -actionName "TASKS_REFRESH")
                
                # Register screen with focus manager after all components are created
                if (Get-Command -Name "Register-ScreenForFocus" -ErrorAction SilentlyContinue) {
                    Register-ScreenForFocus -Screen $self
                }
                
                # Set initial focus
                Request-Focus -Component $taskTable
                
                Write-Log -Level Debug -Message "Task screen Init completed"
                
            } -Context @{ ScreenName = $self.Name } -ErrorHandler {
                param($Exception)
                Write-Log -Level Error -Message "Task screen Init error: $($Exception.Message)" -Data $Exception.Context
            }
        }
        
        _CreateFormPanel = {
            param($self)
            Invoke-WithErrorHandling -Component "$($self.Name)._CreateFormPanel" -ScriptBlock {
                $formWidth = 60; $formHeight = 20
                $formX = [Math]::Floor(($global:TuiState.BufferWidth - $formWidth) / 2)
                $formY = [Math]::Floor(($global:TuiState.BufferHeight - $formHeight) / 2)
                
                $formPanel = New-TuiGridPanel -Props @{
                    X = $formX; Y = $formY; Width = $formWidth; Height = $formHeight
                    ShowBorder = $true; Title = " New Task "; Visible = $false
                    ZIndex = 1000 # Ensure form is rendered on top
                    BackgroundColor = (Get-ThemeColor "Background" -Default Black)
                    RowDefinitions = @("3", "3", "3", "3", "3", "1*")
                    ColumnDefinitions = @("15", "1*")
                }
                
                # Fields
                $titleLabel = New-TuiLabel -Props @{ Text = "Title:"; Height = 1 }
                $titleInput = New-TuiTextBox -Props @{ Name = "formTitle"; IsFocusable = $true; Height = 3; Placeholder = "Enter task title..." }
                [void](& $formPanel.AddChild -self $formPanel -Child $titleLabel -LayoutProps @{ "Grid.Row" = 0; "Grid.Column" = 0 })
                [void](& $formPanel.AddChild -self $formPanel -Child $titleInput -LayoutProps @{ "Grid.Row" = 0; "Grid.Column" = 1 })
                
                $descLabel = New-TuiLabel -Props @{ Text = "Description:"; Height = 1 }
                $descInput = New-TuiTextBox -Props @{ Name = "formDescription"; IsFocusable = $true; Height = 3; Placeholder = "Enter description..." }
                [void](& $formPanel.AddChild -self $formPanel -Child $descLabel -LayoutProps @{ "Grid.Row" = 1; "Grid.Column" = 0 })
                [void](& $formPanel.AddChild -self $formPanel -Child $descInput -LayoutProps @{ "Grid.Row" = 1; "Grid.Column" = 1 })
                
                # Capture screen reference for button handlers
                $screen = $self
                
                # Buttons
                $buttonPanel = New-TuiStackPanel -Props @{ Orientation = "Horizontal"; HorizontalAlignment = "Center"; Spacing = 2; Height = 3 }
                $saveButton = New-TuiButton -Props @{ Text = "Save"; Width = 12; Height = 3; IsFocusable = $true; OnClick = { Invoke-WithErrorHandling -Component "TaskForm.SaveButton.OnClick" -ScriptBlock { & $screen._SaveTask -self $screen } -Context @{ FormFields = $screen._formFields } -ErrorHandler { param($Exception) { Show-AlertDialog -Title "Save Error" -Message "Failed to save task: $($Exception.Message)" } } } }
                $cancelButton = New-TuiButton -Props @{ Text = "Cancel"; Width = 12; Height = 3; IsFocusable = $true; OnClick = { Invoke-WithErrorHandling -Component "TaskForm.CancelButton.OnClick" -ScriptBlock { & $screen._HideForm -self $screen } -Context @{} -ErrorHandler { param($Exception) { Show-AlertDialog -Title "Cancel Error" -Message "Failed to cancel form: $($Exception.Message)" } } } }
                [void](& $buttonPanel.AddChild -self $buttonPanel -Child $saveButton)
                [void](& $buttonPanel.AddChild -self $buttonPanel -Child $cancelButton)
                [void](& $formPanel.AddChild -self $formPanel -Child $buttonPanel -LayoutProps @{ "Grid.Row" = 5; "Grid.Column" = 0; "Grid.ColumnSpan" = 2 })
                
                $self.Components.formPanel = $formPanel
                $self._formFields = @{ Title = $titleInput; Description = $descInput }
            } -Context @{ ScreenName = $self.Name } -ErrorHandler {
                param($Exception)
                Write-Log -Level Error -Message "Task screen _CreateFormPanel error: $($Exception.Message)" -Data $Exception.Context
            }
        }
        
        _ShowForm = {
            param($self, $taskId = $null)
            Invoke-WithErrorHandling -Component "$($self.Name)._ShowForm" -ScriptBlock {
                $self._formVisible = $true
                $self._editingTaskId = $taskId
                $self.Components.formPanel.Title = if ($taskId) { " Edit Task " } else { " New Task " }
                
                # Populate or clear form fields
                # (Logic for populating form from $taskId would go here)
                
                $self.Components.formPanel.Visible = $true
                Request-Focus -Component $self._formFields.Title
                Request-TuiRefresh
            } -Context @{ ScreenName = $self.Name; TaskId = $taskId } -ErrorHandler {
                param($Exception)
                Write-Log -Level Error -Message "Task screen _ShowForm error: $($Exception.Message)" -Data $Exception.Context
            }
        }
        
        _HideForm = {
            param($self)
            Invoke-WithErrorHandling -Component "$($self.Name)._HideForm" -ScriptBlock {
                $self._formVisible = $false
                $self._editingTaskId = $null
                $self.Components.formPanel.Visible = $false
                Request-Focus -Component $self._taskTable
                Request-TuiRefresh
            } -Context @{ ScreenName = $self.Name } -ErrorHandler {
                param($Exception)
                Write-Log -Level Error -Message "Task screen _HideForm error: $($Exception.Message)" -Data $Exception.Context
            }
        }
        
        _SaveTask = {
            param($self)
            Invoke-WithErrorHandling -Component "$($self.Name)._SaveTask" -ScriptBlock {
                $formData = @{ Title = $self._formFields.Title.Text; Description = $self._formFields.Description.Text }
                if ([string]::IsNullOrWhiteSpace($formData.Title)) { Show-AlertDialog -Title "Validation Error" -Message "Task title is required"; return }
                
                $action = if ($self._editingTaskId) { "TASK_UPDATE" } else { "TASK_CREATE" }
                if ($self._editingTaskId) { $formData.TaskId = $self._editingTaskId }
                
                [void](& $self._services.Store.Dispatch -self $self._services.Store -actionName $action -payload $formData)
                & $self._HideForm -self $self
            } -Context @{ ScreenName = $self.Name; EditingTaskId = $self._editingTaskId; FormData = $self._formFields.Title.Text } -ErrorHandler {
                param($Exception)
                Write-Log -Level Error -Message "Task screen _SaveTask error: $($Exception.Message)" -Data $Exception.Context
                Show-AlertDialog -Title "Save Error" -Message "Failed to save task: $($Exception.Message)"
            }
        }
        
        Render = {
            param($self)
            Invoke-WithErrorHandling -Component "$($self.Name).Render" -ScriptBlock {
                # This method now ONLY draws screen-level "chrome" (non-component elements).
                # The engine handles rendering the component tree in the Children array.
                
                # Status bar
                $statusY = $global:TuiState.BufferHeight - 1
                $statusText = if ($self._formVisible) {
                    "Tab: Next Field | Esc: Cancel"
                } else {
                    "N: New | E: Edit | D: Delete | Space: Toggle | Q: Back"
                }
                Write-BufferString -X 2 -Y $statusY -Text $statusText -ForegroundColor (Get-ThemeColor "Subtle" -Default DarkGray)
                
            } -Context @{ ScreenName = $self.Name; FormVisible = $self._formVisible } -ErrorHandler {
                param($Exception)
                Write-Log -Level Error -Message "Task screen Render error: $($Exception.Message)" -Data $Exception.Context
                Write-BufferString -X 2 -Y 2 -Text "Error rendering task screen: $($Exception.Message)" -ForegroundColor Red
            }
        }
        
        HandleInput = {
            param($self, $Key)
            Invoke-WithErrorHandling -Component "$($self.Name).HandleInput" -ScriptBlock {
                $services = $self._services
                if ($self._formVisible) {
                    if ($Key.Key -eq [ConsoleKey]::Escape) { & $self._HideForm -self $self; return $true }
                    return $false
                }
                
                switch ($Key.KeyChar) {
                    'n' { & $self._ShowForm -self $self; return $true }
                    'e' { $selected = $self._taskTable.ProcessedData[$self._taskTable.SelectedRow]; if ($selected) { & $self._ShowForm -self $self -taskId $selected.Id }; return $true }
                    'd' {
                        $selected = $self._taskTable.ProcessedData[$self._taskTable.SelectedRow]
                        if ($selected) {
                            Show-ConfirmDialog -Title "Delete Task" -Message "Are you sure?" -OnConfirm {
                                Invoke-WithErrorHandling -Component "TaskScreen.DeleteConfirm.OnConfirm" -ScriptBlock {
                                    & $services.Store.Dispatch -self $services.Store -actionName "TASK_DELETE" -payload @{ TaskId = $selected.Id }
                                } -Context @{ TaskId = $selected.Id } -ErrorHandler {
                                    param($Exception)
                                    Show-AlertDialog -Title "Delete Error" -Message "Failed to delete task: $($Exception.Message)"
                                }
                            }
                        }
                        return $true
                    }
                    'q' { return "Back" }
                    '1' { [void](& $services.Store.Dispatch -self $services.Store -actionName "UPDATE_STATE" -payload @{ taskFilter = "all" }); return $true }
                    '2' { [void](& $services.Store.Dispatch -self $services.Store -actionName "UPDATE_STATE" -payload @{ taskFilter = "active" }); return $true }
                    '3' { [void](& $services.Store.Dispatch -self $services.Store -actionName "UPDATE_STATE" -payload @{ taskFilter = "completed" }); return $true }
                    'p' { [void](& $services.Store.Dispatch -self $services.Store -actionName "UPDATE_STATE" -payload @{ taskSort = "priority" }); return $true }
                    'd' { [void](& $services.Store.Dispatch -self $services.Store -actionName "UPDATE_STATE" -payload @{ taskSort = "dueDate" }); return $true }
                    'c' { [void](& $services.Store.Dispatch -self $services.Store -actionName "UPDATE_STATE" -payload @{ taskSort = "created" }); return $true }
                }
                
                return $false
            } -Context @{ ScreenName = $self.Name; Key = $Key; FormVisible = $self._formVisible } -ErrorHandler {
                param($Exception)
                Write-Log -Level Error -Message "Task screen HandleInput error: $($Exception.Message)" -Data $Exception.Context
                return $false
            }
        }
        
        OnExit = {
            param($self)
            Invoke-WithErrorHandling -Component "$($self.Name).OnExit" -ScriptBlock {
                $services = $self._services
                if ($services -and $services.Store) {
                    foreach ($subId in $self._subscriptions) {
                        & $services.Store.Unsubscribe -self $services.Store -subId $subId
                    }
                }
            } -Context @{ ScreenName = $self.Name } -ErrorHandler {
                param($Exception)
                Write-Log -Level Error -Message "Task screen OnExit error: $($Exception.Message)" -Data $Exception.Context
            }
        }
        
        OnResume = {
            param($self)
            Invoke-WithErrorHandling -Component "$($self.Name).OnResume" -ScriptBlock {
                $global:TuiState.RenderStats.FrameCount = 0
                [void](& $self._services.Store.Dispatch -self $self._services.Store -actionName "TASKS_REFRESH")
                Request-TuiRefresh
            } -Context @{ ScreenName = $self.Name } -ErrorHandler {
                param($Exception)
                Write-Log -Level Error -Message "Task screen OnResume error: $($Exception.Message)" -Data $Exception.Context
            }
        }
    }
    
    $screen._services = $Services
    return $screen
}

function Get-TaskScreen {
    param([hashtable]$Services)
    return Get-TaskManagementScreen -Services $Services
}

Export-ModuleMember -Function Get-TaskManagementScreen, Get-TaskScreen