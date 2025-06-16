# Task Management Screen - FINAL STABILIZED VERSION
# This version uses the corrected Panel and centralized Focus System.
# It is simplified, robust, and free of manual workarounds.

function global:Get-TaskManagementScreen {
    $screen = @{
        Name = "TaskScreen"
        
        # 1. STATE: Central data model for the screen
        State = @{
            tasks = @()
            filter = "all"
            sortBy = "priority"
            categories = @("Work", "Personal", "Urgent", "Projects")
            showingForm = $false
            editingTaskId = $null
        }
        
        # 2. COMPONENTS: Storage for instantiated component objects
        Components = @{}
        
        # =================================================================
        # HELPER METHODS
        # These methods encapsulate screen-specific logic.
        # =================================================================

        GetFilteredTasks = {
            param($screen)
            $tasks = $screen.State.tasks
            
            # Apply filter
            $filtered = switch ($screen.State.filter) {
                "active"    { $tasks | Where-Object { $_.Status -eq "Active" } }
                "completed" { $tasks | Where-Object { $_.Status -eq "Completed" } }
                default     { $tasks }
            }
            
            # Apply sort
            $sorted = switch ($screen.State.sortBy) {
                "priority" { 
                    $filtered | Sort-Object @{
                        Expression = {
                            switch ($_.Priority) {
                                "Critical" { 0 }; "High" { 1 }; "Medium" { 2 }; default { 3 }
                            }
                        }
                    }, Created
                }
                "dueDate" { $filtered | Sort-Object DueDate, Priority }
                "created" { $filtered | Sort-Object Created -Descending }
                default   { $filtered }
            }
            
            # Transform for table display
            return @($sorted | ForEach-Object {
                @{
                    Id       = $_.Id
                    Status   = if ($_.Status -eq "Completed") { "✓" } else { " " }
                    Priority = $_.Priority
                    Title    = $_.Title
                    Category = $_.Category
                    DueDate  = $_.DueDate
                }
            })
        }
        
        RefreshTaskTable = {
            param($screen)
            $tableData = & $screen.GetFilteredTasks -screen $screen
            $screen.Components.taskTable.Data = $tableData
            # The DataTable component is responsible for its own internal state refresh.
            if ($screen.Components.taskTable.ProcessData) {
                & $screen.Components.taskTable.ProcessData -self $screen.Components.taskTable
            }
        }
        
        # --- Form Management: Simplified and Declarative ---
        
        ShowForm = {
            param($screen, $taskId)
            
            $isEditing = $null -ne $taskId
            
            # Debug log
            Write-Log -Level Debug -Message "ShowForm called, isEditing: $isEditing"
            
            # Get form components through helper
            $titleField = & $screen.GetFormComponent -screen $screen -name "formTitle"
            $descField = & $screen.GetFormComponent -screen $screen -name "formDescription"
            $catField = & $screen.GetFormComponent -screen $screen -name "formCategory"
            $priField = & $screen.GetFormComponent -screen $screen -name "formPriority"
            $dueField = & $screen.GetFormComponent -screen $screen -name "formDueDate"
            
            # Debug: Check if components were found
            Write-Log -Level Debug -Message "Form components found: Title=$($null -ne $titleField), Desc=$($null -ne $descField), Cat=$($null -ne $catField), Pri=$($null -ne $priField), Due=$($null -ne $dueField)"
            
            # Check if all components were found
            if (-not $titleField -or -not $descField -or -not $catField -or -not $priField -or -not $dueField) {
                Write-Log -Level Error -Message "Failed to find form components - aborting ShowForm"
                return
            }
            
            if ($isEditing) {
                $task = $screen.State.tasks | Where-Object { $_.Id -eq $taskId }
                if (-not $task) {
                    Write-Log -Level Error -Message "Task not found for editing: $taskId"
                    return
                }
                $screen.State.editingTaskId = $task.Id
                $screen.Components.formPanel.Title = " Edit Task "
                # Populate form fields
                $titleField.Text = $task.Title
                $descField.Text = $task.Description
                $catField.Value = $task.Category
                $priField.Value = $task.Priority
                $dueField.Value = try { [DateTime]::Parse($task.DueDate) } catch { Get-Date }
            } else {
                $screen.State.editingTaskId = $null
                $screen.Components.formPanel.Title = " New Task "
                # Clear form fields
                $titleField.Text = ""
                $descField.Text = ""
                $catField.Value = "Work"
                $priField.Value = "Medium"
                $dueField.Value = (Get-Date).AddDays(7)
            }

            $screen.State.showingForm = $true
            
            # Use the Panel's Show method to properly show it and all children
            & $screen.Components.formPanel.Show -self $screen.Components.formPanel
            $screen.Components.taskTable.Visible = $false
            
            # Focus the title field - must happen AFTER showing the panel
            Request-TuiRefresh
            Set-ComponentFocus -Component $titleField
            
            Write-Log -Level Debug -Message "Form shown, focus set to title field"
        }

        # In _task-screen.txt
HideForm = {
    param($screen)
    $screen.State.showingForm = $false
    
    # Use the Panel's Hide method to properly hide it and all children
    & $screen.Components.formPanel.Hide -self $screen.Components.formPanel
    $screen.Components.taskTable.Visible = $true
    
    # Restore focus to the main table
    Set-ComponentFocus -Component $screen.Components.taskTable

    # --- THE CRITICAL FIX ---
    # By resetting the frame count, we are telling the TUI engine's optimized renderer
    # that the next frame is a "first frame" and it MUST redraw every single cell.
    # This erases any "ghost" artifacts left over from the form overlay.
    $global:TuiState.RenderStats.FrameCount = 0
}
        
        SaveTask = {
            param($screen)
            
            # Get form components through helper
            $titleField = & $screen.GetFormComponent -screen $screen -name "formTitle"
            $descField = & $screen.GetFormComponent -screen $screen -name "formDescription"
            $catField = & $screen.GetFormComponent -screen $screen -name "formCategory"
            $priField = & $screen.GetFormComponent -screen $screen -name "formPriority"
            $dueField = & $screen.GetFormComponent -screen $screen -name "formDueDate"
            
            $formData = @{
                Title       = $titleField.Text
                Description = $descField.Text
                Category    = $catField.Value
                Priority    = $priField.Value
                DueDate     = $dueField.Value
            }
            
            $editingId = $screen.State.editingTaskId
            
            if ($editingId) {
                # Update existing task
                $task = $screen.State.tasks | Where-Object { $_.Id -eq $editingId }
                if ($task) {
                    $task.Title = $formData.Title
                    $task.Description = $formData.Description
                    $task.Category = $formData.Category
                    $task.Priority = $formData.Priority
                    $task.DueDate = if ($formData.DueDate -is [DateTime]) { $formData.DueDate.ToString("yyyy-MM-dd") } else { $formData.DueDate }
                }
            } else {
                # Add new task
                $newTask = @{
                    Id          = [Guid]::NewGuid().ToString()
                    Title       = $formData.Title
                    Description = $formData.Description
                    Category    = $formData.Category
                    Priority    = $formData.Priority
                    Status      = "Active"
                    DueDate     = if ($formData.DueDate -is [DateTime]) { $formData.DueDate.ToString("yyyy-MM-dd") } else { $formData.DueDate }
                    Created     = Get-Date
                    Completed   = $null
                }
                $screen.State.tasks += $newTask
            }
            
            & $screen.HideForm -screen $screen
            & $screen.RefreshTaskTable -screen $screen
        }
        
        # --- Task List Actions ---
        
        DeleteTask = {
            param($screen)
            $selectedRow = $screen.Components.taskTable.SelectedRow
            if ($selectedRow -ge 0 -and $selectedRow -lt $screen.Components.taskTable.ProcessedData.Count) {
                $taskData = $screen.Components.taskTable.ProcessedData[$selectedRow]
                $screen.State.tasks = @($screen.State.tasks | Where-Object { $_.Id -ne $taskData.Id })
                & $screen.RefreshTaskTable -screen $screen
            }
        }
        
        ToggleTaskStatus = {
            param($screen)
            $selectedRow = $screen.Components.taskTable.SelectedRow
            if ($selectedRow -ge 0 -and $selectedRow -lt $screen.Components.taskTable.ProcessedData.Count) {
                $taskData = $screen.Components.taskTable.ProcessedData[$selectedRow]
                $task = $screen.State.tasks | Where-Object { $_.Id -eq $taskData.Id }
                if ($task) {
                    if ($task.Status -eq "Active") {
                        $task.Status = "Completed"; $task.Completed = Get-Date
                    } else {
                        $task.Status = "Active"; $task.Completed = $null
                    }
                    & $screen.RefreshTaskTable -screen $screen
                }
            }
        }
        
        # =================================================================
        # LIFECYCLE HOOKS
        # =================================================================

        # 3. INIT: One-time setup
        Init = {
            param($self)
            
            # --- Data Loading ---
            if ($global:Data -and $global:Data.Tasks -and $global:Data.Tasks.Count -gt 0) {
                $self.State.tasks = @($global:Data.Tasks)
            } else {
                # Initialize with sample data if global data is empty
                $self.State.tasks = @(
                    @{ Id=[Guid]::NewGuid().ToString(); Title="Review TUI framework docs"; Description="Identify gaps"; Category="Work"; Priority="High"; Status="Active"; DueDate=(Get-Date).AddDays(2).ToString("yyyy-MM-dd"); Created=(Get-Date).AddDays(-3); Completed=$null },
                    @{ Id=[Guid]::NewGuid().ToString(); Title="Fix critical framework bugs"; Description="Address panel and focus issues"; Category="Urgent"; Priority="Critical"; Status="Active"; DueDate=(Get-Date).AddDays(1).ToString("yyyy-MM-dd"); Created=(Get-Date).AddDays(-1); Completed=$null },
                    @{ Id=[Guid]::NewGuid().ToString(); Title="Implement state management"; Description="Add a reactive state manager"; Category="Projects"; Priority="Medium"; Status="Completed"; DueDate=(Get-Date).AddDays(-1).ToString("yyyy-MM-dd"); Created=(Get-Date).AddDays(-7); Completed=(Get-Date).AddDays(-1) }
                )
            }
            
            # --- Component Creation ---

            # Create main task table
            $self.Components.taskTable = New-TuiDataTable -Props @{
                X = 2; Y = 5; Width = 76; Height = 20
                Columns = @(
                    @{ Name = "Status"; Header = "✓"; Width = 3 }; @{ Name = "Priority"; Header = "Priority"; Width = 10 };
                    @{ Name = "Title"; Header = "Title"; Width = 30 }; @{ Name = "Category"; Header = "Category"; Width = 11 };
                    @{ Name = "DueDate"; Header = "Due Date"; Width = 10 }
                )
                ShowBorder = $true
                Title = " Tasks "
                OnRowSelect = { & $self.ToggleTaskStatus -screen $self }
            }
            & $self.RefreshTaskTable -screen $self # Initial data load

            # Create the form panel. It starts hidden and will contain all form elements.
            $self.Components.formPanel = New-TuiPanel -Props @{
                X = 10; Y = 4; Width = 60; Height = 22
                Layout = 'Stack'; Orientation = 'Vertical'; Spacing = 0; Padding = 1
                ShowBorder = $true
                Visible = $false # The panel and all its children start hidden.
            }
            
            # Add helper method to find form components
            $self.GetFormComponent = {
                param($screen, $name)
                Write-Log -Level Debug -Message "GetFormComponent looking for: $name"
                Write-Log -Level Debug -Message "Panel has $($screen.Components.formPanel.Children.Count) children"
                foreach ($child in $screen.Components.formPanel.Children) {
                    Write-Log -Level Debug -Message "  Checking child: Name='$($child.Name)', Type='$($child.Type)'"
                    if ($child.Name -eq $name) { 
                        Write-Log -Level Debug -Message "  Found component: $name"
                        return $child 
                    }
                    if ($child.Children) {
                        foreach ($subchild in $child.Children) {
                            Write-Log -Level Debug -Message "    Checking subchild: Name='$($subchild.Name)', Type='$($subchild.Type)'"
                            if ($subchild.Name -eq $name) { 
                                Write-Log -Level Debug -Message "    Found component in subchild: $name"
                                return $subchild 
                            }
                        }
                    }
                }
                Write-Log -Level Warning -Message "GetFormComponent failed to find: $name"
                return $null
            }
            
            # Create and add form components ONLY to the panel
            # Title field
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiLabel -Props @{ 
                Text = "Title:"; Height = 1; Name = "titleLabel"
            })
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiTextBox -Props @{
                Width = 54; Height = 3; IsFocusable = $true; Name = "formTitle"
            })
            
            # Description field
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiLabel -Props @{ 
                Text = "Description:"; Height = 1; Name = "descLabel"
            })
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiTextArea -Props @{
                Width = 54; Height = 4; IsFocusable = $true; Name = "formDescription"
            })
            
            # Category dropdown
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiLabel -Props @{ 
                Text = "Category:"; Height = 1; Name = "catLabel"
            })
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiDropdown -Props @{
                Width = 25; Height = 3; IsFocusable = $true; Name = "formCategory"
                Options = $self.State.categories | ForEach-Object { @{ Display = $_; Value = $_ } }
                Value = "Work"
            })
            
            # Priority dropdown
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiLabel -Props @{ 
                Text = "Priority:"; Height = 1; Name = "priLabel"
            })
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiDropdown -Props @{
                Width = 25; Height = 3; IsFocusable = $true; Name = "formPriority"
                Options = @("Critical", "High", "Medium", "Low") | ForEach-Object { @{ Display = $_; Value = $_ } }
                Value = "Medium"
            })
            
            # Due date picker
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiLabel -Props @{ 
                Text = "Due Date:"; Height = 1; Name = "dueLabel"
            })
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiDatePicker -Props @{
                Width = 25; Height = 3; IsFocusable = $true; Name = "formDueDate"
                Value = (Get-Date).AddDays(7)
            })
            
            # Button panel
            $buttonPanel = New-TuiPanel -Props @{ 
                Layout = 'Stack'; Orientation = 'Horizontal'; Spacing = 2; Height = 3
                ShowBorder = $false; Name = "buttonPanel"
            }
            & $buttonPanel.AddChild -self $buttonPanel -Child (New-TuiButton -Props @{
                Width = 15; Height = 3; Text = "Save"; IsFocusable = $true; Name = "formSaveButton"
                OnClick = { & $self.SaveTask -screen $self }
            })
            & $buttonPanel.AddChild -self $buttonPanel -Child (New-TuiButton -Props @{
                Width = 15; Height = 3; Text = "Cancel"; IsFocusable = $true; Name = "formCancelButton"
                OnClick = { & $self.HideForm -screen $self }
            })
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child $buttonPanel
            
            # CRITICAL: Ensure panel and all children are hidden at startup
            & $self.Components.formPanel.Hide -self $self.Components.formPanel
        }
        
        # 4. RENDER: Draw the screen and its components
        Render = {
            param($self)
            
            # Header
            Write-BufferString -X 2 -Y 1 -Text "Task Management" -ForegroundColor (Get-ThemeColor "Header")
            
            # Toolbar (only shown when not in form mode)
            if (-not $self.State.showingForm) {
                $toolbarY = 3
                Write-BufferString -X 2 -Y $toolbarY -Text "Filter: [1]All [2]Active [3]Completed | Sort: [P]riority [U]pcoming [C]reated"
            }
            
            # CRITICAL Z-ORDER FIX: Render components in specific order
            # 1. First render the task table (background layer)
            if ($self.Components.taskTable -and $self.Components.taskTable.Render) {
                & $self.Components.taskTable.Render -self $self.Components.taskTable
            }
            
            # 2. If form is showing, clear the area where it will render
            if ($self.State.showingForm -and $self.Components.formPanel) {
                $panel = $self.Components.formPanel
                # Clear the entire area where the form will render
                for ($y = $panel.Y; $y -lt ($panel.Y + $panel.Height); $y++) {
                    Write-BufferString -X $panel.X -Y $y -Text (" " * $panel.Width) `
                        -BackgroundColor (Get-ThemeColor "Background")
                }
            }
            
            # 3. Then render the form panel (foreground layer) - it will render its children
            if ($self.Components.formPanel -and $self.Components.formPanel.Render) {
                & $self.Components.formPanel.Render -self $self.Components.formPanel
            }
            
            # 4. Render any other components that don't have parents and aren't already rendered
            foreach ($kvp in $self.Components.GetEnumerator()) {
                $component = $kvp.Value
                # Skip already rendered components and children with parents
                if ($kvp.Key -eq "taskTable" -or $kvp.Key -eq "formPanel") { continue }
                if ($component -and $component.Render -and -not $component.Parent) {
                    & $component.Render -self $component
                }
            }
            
            # Status bar
            $statusY = $global:TuiState.BufferHeight - 2
            $statusText = if ($self.State.showingForm) {
                "Tab: Next Field | Esc: Cancel"
            } else {
                "N: New | E: Edit | D: Delete | Space: Toggle | Q: Back"
            }
            Write-BufferString -X 2 -Y $statusY -Text $statusText -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        # 5. HANDLEINPUT: Global input handling for the screen
        HandleInput = {
            param($self, $Key)
            
            # If the form is showing, all input is handled by it or the engine.
            if ($self.State.showingForm) {
                switch ($Key.Key) {
                    ([ConsoleKey]::Escape) { & $self.HideForm -screen $self; return $true }
                    ([ConsoleKey]::Tab) {
                        # Delegate to the robust engine function.
                        Handle-TabNavigation -Reverse ($Key.Modifiers -band [ConsoleModifiers]::Shift)
                        return $true
                    }
                }
            } else { # Form is not showing, handle list commands.
                switch -Wildcard ($Key.KeyChar.ToString().ToUpper()) {
                    'N' { & $self.ShowForm -screen $self; return $true }
                    'E' {
                        $selected = $self.Components.taskTable.SelectedRow
                        if ($selected -ge 0) {
                            $taskId = $self.Components.taskTable.ProcessedData[$selected].Id
                            & $self.ShowForm -screen $self -taskId $taskId
                        }
                        return $true
                    }
                    'D' { & $self.DeleteTask -screen $self; return $true }
                    'Q' { return "Back" }
                    '1' { $self.State.filter = "all"; & $self.RefreshTaskTable -screen $self; return $true }
                    '2' { $self.State.filter = "active"; & $self.RefreshTaskTable -screen $self; return $true }
                    '3' { $self.State.filter = "completed"; & $self.RefreshTaskTable -screen $self; return $true }
                    'P' { $self.State.sortBy = "priority"; & $self.RefreshTaskTable -screen $self; return $true }
                    'U' { $self.State.sortBy = "dueDate"; & $self.RefreshTaskTable -screen $self; return $true }
                    'C' { $self.State.sortBy = "created"; & $self.RefreshTaskTable -screen $self; return $true }
                }
                if ($Key.Key -eq [ConsoleKey]::Escape) { return "Back" }
            }
            
            # For any other key, delegate to the currently focused component.
            # This handles typing in textboxes, table navigation, etc.
            $focusedComponent = $script:TuiState.FocusedComponent
            if ($focusedComponent -and $focusedComponent.HandleInput) {
                if (& $focusedComponent.HandleInput -self $focusedComponent -Key $Key) {
                    return $true
                }
            }
            
            return $false
        }
        
        # 6. ONRESUME: Hook for when the screen becomes active again.
        OnResume = {
            param($self)
            # Refresh data from global store in case it changed.
            if ($global:Data -and $global:Data.Tasks) {
                $self.State.tasks = @($global:Data.Tasks)
                & $self.RefreshTaskTable -screen $self
            }
        }
    }
    
    return $screen
}

# Alias for backward compatibility if other parts of the app call Get-TaskScreen
function global:Get-TaskScreen {
    return Get-TaskManagementScreen
}

Export-ModuleMember -Function Get-TaskManagementScreen, Get-TaskScreen