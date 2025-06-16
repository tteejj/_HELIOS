# Task Management Screen - COMPLIANT VERSION
# Using programmatic pattern with DataTable component

function global:Get-TaskManagementScreen {
    $screen = @{
        Name = "TaskScreen"
        
        # 1. State: Central data model for the screen
        State = @{
            tasks = @()
            filter = "all"
            sortBy = "priority"
            categories = @("Work", "Personal", "Urgent", "Projects")
            showingForm = $false
            editingTaskId = $null
            showHelp = $false
        }
        
        # 2. Components: Storage for instantiated component objects
        Components = @{}
        
        # Focus management
        FocusedComponentName = 'taskTable'
        
        # Define helper methods directly on the screen
        GetFilteredTasks = {
            param($screen)
            $tasks = $screen.State.tasks
            $filter = $screen.State.filter
            
            # Apply filter
            $filtered = switch ($filter) {
                "active" { $tasks | Where-Object { $_.Status -eq "Active" } }
                "completed" { $tasks | Where-Object { $_.Status -eq "Completed" } }
                default { $tasks }
            }
            
            # Apply sort
            $sorted = switch ($screen.State.sortBy) {
                "priority" { 
                    $filtered | Sort-Object @{
                        Expression = {
                            switch ($_.Priority) {
                                "Critical" { 0 }
                                "High" { 1 }
                                "Medium" { 2 }
                                "Low" { 3 }
                            }
                        }
                    }, Created
                }
                "dueDate" { $filtered | Sort-Object DueDate, Priority }
                "created" { $filtered | Sort-Object Created -Descending }
                default { $filtered }
            }
            
            # Transform for table display
            return @($sorted | ForEach-Object {
                @{
                    Id = $_.Id
                    Status = if ($_.Status -eq "Completed") { "X" } else { " " }
                    Priority = $_.Priority
                    Title = if ($_.Title.Length -gt 30) { $_.Title.Substring(0, 27) + "..." } else { $_.Title }
                    Category = $_.Category
                    DueDate = $_.DueDate
                }
            })
        }
        
        RefreshTaskTable = {
            param($screen)
            $tableData = & $screen.GetFilteredTasks -screen $screen
            $screen.Components.taskTable.Data = $tableData
            # Force process data to refresh the display
            if ($screen.Components.taskTable.ProcessData) {
                & $screen.Components.taskTable.ProcessData -self $screen.Components.taskTable
            }
            Request-TuiRefresh
        }
        
        ShowAddTaskForm = {
            param($screen)
            $screen.State.showingForm = $true
            $screen.State.editingTaskId = $null
            
            # Update form components
            $screen.Components.formTitle.Text = ""
            $screen.Components.formDescription.Text = ""
            $screen.Components.formCategory.Value = "Work"
            $screen.Components.formPriority.Value = "Medium"
            $screen.Components.formDueDate.Value = (Get-Date).AddDays(7)
            
            # Center the form panel
            $formWidth = 60
            $formHeight = 24
            $screen.Components.formPanel.X = [Math]::Floor(($global:TuiState.BufferWidth - $formWidth) / 2)
            $screen.Components.formPanel.Y = 6
            $screen.Components.formPanel.Title = " New Task "
            
            # Show form panel
            $screen.Components.formPanel.Visible = $true
            
            # Enable focus on form components
            $screen.Components.formTitle.IsFocusable = $true
            $screen.Components.formDescription.IsFocusable = $true
            $screen.Components.formCategory.IsFocusable = $true
            $screen.Components.formPriority.IsFocusable = $true
            $screen.Components.formDueDate.IsFocusable = $true
            $screen.Components.formSaveButton.IsFocusable = $true
            $screen.Components.formCancelButton.IsFocusable = $true
            
            # Hide table
            if ($screen.Components.taskTable) {
                $screen.Components.taskTable.Visible = $false
                $screen.Components.taskTable.IsFocusable = $false
                $screen.Components.taskTable.IsFocused = $false
            }
            
            # Focus first field
            $screen.FocusedComponentName = 'formTitle'
            $screen.Components.formTitle.IsFocused = $true
            
            # Update engine focus
            if (Get-Command Set-ComponentFocus -ErrorAction SilentlyContinue) {
                Set-ComponentFocus -Component $screen.Components.formTitle
            }
            
            Request-TuiRefresh
        }
        
        ShowEditTaskForm = {
            param($screen, $taskId)
            $task = $screen.State.tasks | Where-Object { $_.Id -eq $taskId }
            if (-not $task) { return }
            
            $screen.State.showingForm = $true
            $screen.State.editingTaskId = $task.Id
            
            # Update form components
            $screen.Components.formTitle.Text = $task.Title
            $screen.Components.formDescription.Text = $task.Description
            $screen.Components.formCategory.Value = $task.Category
            $screen.Components.formPriority.Value = $task.Priority
            $screen.Components.formDueDate.Value = [DateTime]::Parse($task.DueDate)
            
            # Center the form panel
            $formWidth = 60
            $formHeight = 24
            $screen.Components.formPanel.X = [Math]::Floor(($global:TuiState.BufferWidth - $formWidth) / 2)
            $screen.Components.formPanel.Y = 6
            $screen.Components.formPanel.Title = " Edit Task "
            
            # Show form panel
            $screen.Components.formPanel.Visible = $true
            
            # Enable focus on form components
            $screen.Components.formTitle.IsFocusable = $true
            $screen.Components.formDescription.IsFocusable = $true
            $screen.Components.formCategory.IsFocusable = $true
            $screen.Components.formPriority.IsFocusable = $true
            $screen.Components.formDueDate.IsFocusable = $true
            $screen.Components.formSaveButton.IsFocusable = $true
            $screen.Components.formCancelButton.IsFocusable = $true
            
            # Hide table
            if ($screen.Components.taskTable) {
                $screen.Components.taskTable.Visible = $false
                $screen.Components.taskTable.IsFocusable = $false
                $screen.Components.taskTable.IsFocused = $false
            }
            
            # Focus first field
            $screen.FocusedComponentName = 'formTitle'
            $screen.Components.formTitle.IsFocused = $true
            
            # Update engine focus
            if (Get-Command Set-ComponentFocus -ErrorAction SilentlyContinue) {
                Set-ComponentFocus -Component $screen.Components.formTitle
            }
            
            Request-TuiRefresh
        }
        
        SaveTask = {
            param($screen)
            
            # Get current values from form components
            $title = $screen.Components.formTitle.Text
            $description = $screen.Components.formDescription.Text
            $category = $screen.Components.formCategory.Value
            $priority = $screen.Components.formPriority.Value
            $dueDate = $screen.Components.formDueDate.Value
            
            $editingId = $screen.State.editingTaskId
            
            if ($editingId) {
                # Update existing
                $task = $screen.State.tasks | Where-Object { $_.Id -eq $editingId }
                if ($task) {
                    $task.Title = $title
                    $task.Description = $description
                    $task.Category = $category
                    $task.Priority = $priority
                    $task.DueDate = if ($dueDate -is [DateTime]) { $dueDate.ToString("MM/dd/yy") } else { $dueDate }
                }
            } else {
                # Add new
                $newTask = @{
                    Id = [Guid]::NewGuid().ToString()
                    Title = $title
                    Description = $description
                    Category = $category
                    Priority = $priority
                    Status = "Active"
                    DueDate = if ($dueDate -is [DateTime]) { $dueDate.ToString("MM/dd/yy") } else { $dueDate }
                    Created = Get-Date
                    Completed = $null
                }
                $screen.State.tasks += $newTask
            }
            
            & $screen.HideForm -screen $screen
            & $screen.RefreshTaskTable -screen $screen
        }
        
        HideForm = {
            param($screen)
            $screen.State.showingForm = $false
            
            # Hide form panel
            $screen.Components.formPanel.Visible = $false
            
            # Disable focus on form components
            $screen.Components.formTitle.IsFocusable = $false
            $screen.Components.formTitle.IsFocused = $false
            $screen.Components.formDescription.IsFocusable = $false
            $screen.Components.formDescription.IsFocused = $false
            $screen.Components.formCategory.IsFocusable = $false
            $screen.Components.formCategory.IsFocused = $false
            $screen.Components.formPriority.IsFocusable = $false
            $screen.Components.formPriority.IsFocused = $false
            $screen.Components.formDueDate.IsFocusable = $false
            $screen.Components.formDueDate.IsFocused = $false
            $screen.Components.formSaveButton.IsFocusable = $false
            $screen.Components.formSaveButton.IsFocused = $false
            $screen.Components.formCancelButton.IsFocusable = $false
            $screen.Components.formCancelButton.IsFocused = $false
            
            # Show table
            if ($screen.Components.taskTable) {
                $screen.Components.taskTable.Visible = $true
                $screen.Components.taskTable.IsFocusable = $true
            }
            $screen.FocusedComponentName = 'taskTable'
            Request-TuiRefresh
        }
        
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
                        $task.Status = "Completed"
                        $task.Completed = Get-Date
                    } else {
                        $task.Status = "Active"
                        $task.Completed = $null
                    }
                    & $screen.RefreshTaskTable -screen $screen
                }
            }
        }
        
        # 3. Init: One-time setup
        Init = {
            param($self)
            
            # Try to load from global data first
            if ($global:Data -and $global:Data.Tasks -and $global:Data.Tasks.Count -gt 0) {
                $self.State.tasks = @($global:Data.Tasks | ForEach-Object { $_ })
                Write-Log -Level Debug -Message "Loaded $($self.State.tasks.Count) tasks from global data"
            } else {
                # Initialize sample tasks
            $sampleTasks = @(
                @{
                    Id = [Guid]::NewGuid().ToString()
                    Title = "Review documentation"
                    Description = "Go through TUI framework docs and identify gaps"
                    Category = "Work"
                    Priority = "High"
                    Status = "Active"
                    DueDate = (Get-Date).AddDays(2).ToString("MM/dd/yy")
                    Created = (Get-Date).AddDays(-3)
                    Completed = $null
                }
                @{
                    Id = [Guid]::NewGuid().ToString()
                    Title = "Fix memory leaks"
                    Description = "Address critical memory leak issues in event system"
                    Category = "Urgent"
                    Priority = "Critical"
                    Status = "Active"
                    DueDate = (Get-Date).AddDays(1).ToString("MM/dd/yy")
                    Created = (Get-Date).AddDays(-1)
                    Completed = $null
                }
                @{
                    Id = [Guid]::NewGuid().ToString()
                    Title = "Add clipboard support"
                    Description = "Implement Ctrl+C/V in text components"
                    Category = "Projects"
                    Priority = "Medium"
                    Status = "Completed"
                    DueDate = (Get-Date).AddDays(-1).ToString("MM/dd/yy")
                    Created = (Get-Date).AddDays(-7)
                    Completed = (Get-Date).AddDays(-1)
                }
            )
            
                $self.State.tasks = $sampleTasks
                Write-Log -Level Debug -Message "Using sample tasks data"
            }
            
            # Create main task table
            $tableScreen = $self  # Capture reference for closure
            $self.Components.taskTable = New-TuiDataTable -Props @{
                X = 2; Y = 5; Width = 76; Height = 20
                Columns = @(
                    @{ Name = "Status"; Header = "✓"; Width = 3 }
                    @{ Name = "Priority"; Header = "Priority"; Width = 10 }
                    @{ Name = "Title"; Header = "Title"; Width = 30 }
                    @{ Name = "Category"; Header = "Category"; Width = 11 }
                    @{ Name = "DueDate"; Header = "Due Date"; Width = 10 }
                )
                Data = & $self.GetFilteredTasks -screen $self
                AllowSort = $false  # We handle sorting ourselves
                AllowFilter = $false
                MultiSelect = $false
                Title = "Tasks"
                OnRowSelect = {
                    param($SelectedData, $SelectedIndex)
                    # Toggle task status on Enter
                    $task = $tableScreen.State.tasks | Where-Object { $_.Id -eq $SelectedData.Id }
                    if ($task) {
                        if ($task.Status -eq "Active") {
                            $task.Status = "Completed"
                            $task.Completed = Get-Date
                        } else {
                            $task.Status = "Active"
                            $task.Completed = $null
                        }
                        & $tableScreen.RefreshTaskTable -screen $tableScreen
                    }
                }
            }
            
            # Force process data to ensure display
            if ($self.Components.taskTable.ProcessData) {
                & $self.Components.taskTable.ProcessData -self $self.Components.taskTable
            }
            
            # Form components (hidden by default)
            $formScreen = $self  # Capture reference for closures
            
            # Create form panel that will contain all form elements
            $self.Components.formPanel = New-TuiPanel -Props @{
                X = 0; Y = 0; Width = 60; Height = 24  # Will be positioned when shown
                Layout = 'Stack'
                Orientation = 'Vertical' 
                Spacing = 1
                Padding = 2
                ShowBorder = $true
                Title = " Task Form "
                Visible = $false
            }
            
            # Title label and textbox in a row
            $titleRow = New-TuiPanel -Props @{
                Width = 56; Height = 4
                Layout = 'Stack'
                Orientation = 'Vertical'
                Spacing = 0
                Padding = 0
            }
            $titleLabel = New-TuiLabel -Props @{ Text = "Title:"; Width = 50 }
            $self.Components.formTitle = New-TuiTextBox -Props @{
                Width = 54; Height = 3
                Placeholder = "Enter task title..."
                IsFocusable = $false
            }
            $titleRow.AddChild($titleRow, $titleLabel)
            $titleRow.AddChild($titleRow, $self.Components.formTitle)
            
            # Description label and textarea in a row
            $descRow = New-TuiPanel -Props @{
                Width = 56; Height = 6
                Layout = 'Stack'
                Orientation = 'Vertical'
                Spacing = 0
                Padding = 0
            }
            $descLabel = New-TuiLabel -Props @{ Text = "Description:"; Width = 50 }
            $self.Components.formDescription = New-TuiTextArea -Props @{
                Width = 54; Height = 5
                Placeholder = "Enter task description..."
                IsFocusable = $false
            }
            $descRow.AddChild($descRow, $descLabel)
            $descRow.AddChild($descRow, $self.Components.formDescription)
            
            # Category and Priority in horizontal layout
            $categoryPriorityRow = New-TuiPanel -Props @{
                Width = 56; Height = 4
                Layout = 'Stack'
                Orientation = 'Horizontal'
                Spacing = 5
                Padding = 0
            }
            
            $categoryPanel = New-TuiPanel -Props @{
                Width = 25; Height = 4
                Layout = 'Stack'
                Orientation = 'Vertical'
                Spacing = 0
                Padding = 0
            }
            $categoryLabel = New-TuiLabel -Props @{ Text = "Category:"; Width = 20 }
            $self.Components.formCategory = New-TuiDropdown -Props @{
                Width = 20; Height = 3
                Options = $self.State.categories | ForEach-Object { @{ Display = $_; Value = $_ } }
                IsFocusable = $false
            }
            $categoryPanel.AddChild($categoryPanel, $categoryLabel)
            $categoryPanel.AddChild($categoryPanel, $self.Components.formCategory)
            
            $priorityPanel = New-TuiPanel -Props @{
                Width = 25; Height = 4
                Layout = 'Stack'
                Orientation = 'Vertical'
                Spacing = 0
                Padding = 0
            }
            $priorityLabel = New-TuiLabel -Props @{ Text = "Priority:"; Width = 20 }
            $self.Components.formPriority = New-TuiDropdown -Props @{
                Width = 20; Height = 3
                Options = @(
                    @{ Display = "Critical"; Value = "Critical" }
                    @{ Display = "High"; Value = "High" }
                    @{ Display = "Medium"; Value = "Medium" }
                    @{ Display = "Low"; Value = "Low" }
                )
                IsFocusable = $false
            }
            $priorityPanel.AddChild($priorityPanel, $priorityLabel)
            $priorityPanel.AddChild($priorityPanel, $self.Components.formPriority)
            
            $categoryPriorityRow.AddChild($categoryPriorityRow, $categoryPanel)
            $categoryPriorityRow.AddChild($categoryPriorityRow, $priorityPanel)
            
            # Due Date row
            $dueDateRow = New-TuiPanel -Props @{
                Width = 56; Height = 4
                Layout = 'Stack'
                Orientation = 'Vertical'
                Spacing = 0
                Padding = 0
            }
            $dueDateLabel = New-TuiLabel -Props @{ Text = "Due Date:"; Width = 50 }
            $self.Components.formDueDate = New-TuiDatePicker -Props @{
                Width = 20; Height = 3
                IsFocusable = $false
            }
            $dueDateRow.AddChild($dueDateRow, $dueDateLabel)
            $dueDateRow.AddChild($dueDateRow, $self.Components.formDueDate)
            
            # Button row
            $buttonRow = New-TuiPanel -Props @{
                Width = 56; Height = 3
                Layout = 'Stack'
                Orientation = 'Horizontal'
                Spacing = 5
                Padding = 0
            }
            
            $self.Components.formSaveButton = New-TuiButton -Props @{
                Width = 15; Height = 3
                Text = "Save"
                IsFocusable = $false
                OnClick = { & $formScreen.SaveTask -screen $formScreen }
            }
            
            $self.Components.formCancelButton = New-TuiButton -Props @{
                Width = 15; Height = 3
                Text = "Cancel"
                IsFocusable = $false
                OnClick = { & $formScreen.HideForm -screen $formScreen }
            }
            
            $buttonRow.AddChild($buttonRow, $self.Components.formSaveButton)
            $buttonRow.AddChild($buttonRow, $self.Components.formCancelButton)
            
            # Add all rows to form panel
            $self.Components.formPanel.AddChild($self.Components.formPanel, $titleRow)
            $self.Components.formPanel.AddChild($self.Components.formPanel, $descRow)
            $self.Components.formPanel.AddChild($self.Components.formPanel, $categoryPriorityRow)
            $self.Components.formPanel.AddChild($self.Components.formPanel, $dueDateRow)
            $self.Components.formPanel.AddChild($self.Components.formPanel, $buttonRow)
        }
        
        # 4. Render: Draw the screen and its components
        Render = {
            param($self)
            
            # Header
            $headerColor = Get-ThemeColor "Header" -Default ([ConsoleColor]::Cyan)
            Write-BufferString -X 2 -Y 1 -Text "Task Management" -ForegroundColor $headerColor
            
            # Filter/Sort toolbar
            $toolbarY = 3
            Write-BufferString -X 2 -Y $toolbarY -Text "Filter: " -ForegroundColor ([ConsoleColor]::Gray)
            $filterOptions = @("All", "Active", "Completed")
            $filterX = 10
            foreach ($option in $filterOptions) {
                $isSelected = ($option.ToLower() -eq $self.State.filter)
                $color = if ($isSelected) { [ConsoleColor]::Yellow } else { [ConsoleColor]::White }
                Write-BufferString -X $filterX -Y $toolbarY -Text "[$option]" -ForegroundColor $color
                $filterX += $option.Length + 4
            }
            
            Write-BufferString -X 40 -Y $toolbarY -Text "Sort: " -ForegroundColor ([ConsoleColor]::Gray)
            $sortOptions = @(@{Display="Priority"; Value="priority"}, @{Display="Due Date"; Value="dueDate"}, @{Display="Created"; Value="created"})
            $sortX = 46
            foreach ($option in $sortOptions) {
                $isSelected = ($option.Value -eq $self.State.sortBy)
                $color = if ($isSelected) { [ConsoleColor]::Yellow } else { [ConsoleColor]::White }
                Write-BufferString -X $sortX -Y $toolbarY -Text "[$($option.Display)]" -ForegroundColor $color
                $sortX += $option.Display.Length + 4
            }
            
            # Help panel
            if ($self.State.showHelp) {
                $helpWidth = 40
                $helpHeight = 20
                $helpX = $global:TuiState.BufferWidth - $helpWidth - 2
                $helpY = 5
                
                # Help background
                for ($y = $helpY; $y -lt ($helpY + $helpHeight); $y++) {
                    for ($x = $helpX; $x -lt ($helpX + $helpWidth); $x++) {
                        Write-BufferString -X $x -Y $y -Text " " -BackgroundColor ([ConsoleColor]::DarkBlue)
                    }
                }
                
                Write-BufferBox -X $helpX -Y $helpY -Width $helpWidth -Height $helpHeight -Title " Help " -BorderColor ([ConsoleColor]::Yellow)
                
                $commands = @(
                    @{ Key = "↑/↓"; Description = "Navigate tasks" }
                    @{ Key = "Space"; Description = "Toggle task completion" }
                    @{ Key = "N"; Description = "Add new task" }
                    @{ Key = "E"; Description = "Edit selected task" }
                    @{ Key = "D"; Description = "Delete selected task" }
                    @{ Key = "1-3"; Description = "Change filter" }
                    @{ Key = "P"; Description = "Sort by priority" }
                    @{ Key = "U"; Description = "Sort by due date" }
                    @{ Key = "C"; Description = "Sort by created date" }
                    @{ Key = "H"; Description = "Toggle this help" }
                    @{ Key = "Q/Esc"; Description = "Go back" }
                )
                
                $cmdY = $helpY + 2
                foreach ($cmd in $commands) {
                    Write-BufferString -X ($helpX + 2) -Y $cmdY -Text $cmd.Key -ForegroundColor ([ConsoleColor]::Yellow)
                    Write-BufferString -X ($helpX + 10) -Y $cmdY -Text $cmd.Description -ForegroundColor ([ConsoleColor]::White)
                    $cmdY++
                }
            }
            
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
            
            # Status bar
            $statusY = $global:TuiState.BufferHeight - 2
            $statusText = if ($self.State.showingForm) {
                "Tab: Next Field • Enter: Save • Esc: Cancel"
            } elseif ($self.State.showHelp) {
                "Esc/H: Close Help"
            } else {
                "↑↓: Navigate • Space: Toggle • N: New • E: Edit • D: Delete • H: Help • Q: Back"
            }
            Write-BufferString -X 2 -Y $statusY -Text $statusText -ForegroundColor ([ConsoleColor]::Gray)
        }
        
        # 5. HandleInput: Global input handling for the screen
        HandleInput = {
            param($self, $Key)
            
            if ($self.State.showingForm) {
                # Handle form navigation
                switch ($Key.Key) {
                    ([ConsoleKey]::Escape) {
                        & $self.HideForm -screen $self
                        return $true
                    }
                    ([ConsoleKey]::Tab) {
                        # Cycle through form fields
                        $formFields = @('formTitle', 'formDescription', 'formCategory', 'formPriority', 'formDueDate', 'formSaveButton', 'formCancelButton')
                        $visibleFields = $formFields | Where-Object { $self.Components[$_] -and $self.Components[$_].Visible }
                        
                        if ($visibleFields.Count -gt 0) {
                            $currentIndex = [array]::IndexOf($visibleFields, $self.FocusedComponentName)
                            if ($currentIndex -eq -1) { $currentIndex = 0 }
                            
                            if ($Key.Modifiers -band [ConsoleModifiers]::Shift) {
                                # Shift+Tab - go backwards
                                $nextIndex = ($currentIndex - 1 + $visibleFields.Count) % $visibleFields.Count
                            } else {
                                # Tab - go forwards
                                $nextIndex = ($currentIndex + 1) % $visibleFields.Count
                            }
                            
                            $self.FocusedComponentName = $visibleFields[$nextIndex]
                            
                            # Update component focus states
                            foreach ($field in $formFields) {
                                if ($self.Components[$field]) {
                                    $self.Components[$field].IsFocused = ($field -eq $self.FocusedComponentName)
                                }
                            }
                            
                            # Update engine's focus tracking
                            $focusedComponent = $self.Components[$self.FocusedComponentName]
                            if ($focusedComponent -and (Get-Command Set-ComponentFocus -ErrorAction SilentlyContinue)) {
                                Set-ComponentFocus -Component $focusedComponent
                            }
                        }
                        
                        Request-TuiRefresh
                        return $true
                    }
                }
                
                # Delegate to focused form component
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
            
            # Handle list navigation
            switch ($Key.Key) {
                ([ConsoleKey]::H) {
                    $self.State.showHelp = -not $self.State.showHelp
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::Q) { return "Back" }
                ([ConsoleKey]::Escape) {
                    if ($self.State.showHelp) {
                        $self.State.showHelp = $false
                        Request-TuiRefresh
                        return $true
                    }
                    return "Back"
                }
                ([ConsoleKey]::Spacebar) {
                    & $self.ToggleTaskStatus -screen $self
                    return $true
                }
            }
            
            # Handle key characters
            if ($Key.KeyChar) {
                switch ($Key.KeyChar.ToString().ToUpper()) {
                    'N' {
                        & $self.ShowAddTaskForm -screen $self
                        return $true
                    }
                    'E' {
                        $selectedRow = $self.Components.taskTable.SelectedRow
                        if ($selectedRow -ge 0 -and $selectedRow -lt $self.Components.taskTable.ProcessedData.Count) {
                            $taskData = $self.Components.taskTable.ProcessedData[$selectedRow]
                            & $self.ShowEditTaskForm -screen $self -taskId $taskData.Id
                        }
                        return $true
                    }
                    'D' {
                        & $self.DeleteTask -screen $self
                        return $true
                    }
                    '1' {
                        $self.State.filter = "all"
                        & $self.RefreshTaskTable -screen $self
                        return $true
                    }
                    '2' {
                        $self.State.filter = "active"
                        & $self.RefreshTaskTable -screen $self
                        return $true
                    }
                    '3' {
                        $self.State.filter = "completed"
                        & $self.RefreshTaskTable -screen $self
                        return $true
                    }
                    'P' {
                        $self.State.sortBy = "priority"
                        & $self.RefreshTaskTable -screen $self
                        return $true
                    }
                    'U' {
                        $self.State.sortBy = "dueDate"
                        & $self.RefreshTaskTable -screen $self
                        return $true
                    }
                    'C' {
                        $self.State.sortBy = "created"
                        & $self.RefreshTaskTable -screen $self
                        return $true
                    }
                }
            }
            
            # Delegate to task table
            if ($self.Components.taskTable.Visible -and $self.Components.taskTable.HandleInput) {
                $result = & $self.Components.taskTable.HandleInput -self $self.Components.taskTable -Key $Key
                if ($result) {
                    Request-TuiRefresh
                    return $true
                }
            }
            
            return $false
        }
        
        # 6. Lifecycle Hooks
        OnResume = {
            param($self)
            # Refresh tasks from global data when returning to screen
            if ($global:Data -and $global:Data.Tasks) {
                $self.State.tasks = @($global:Data.Tasks | ForEach-Object { $_ })
                & $self.RefreshTaskTable -screen $self
                Write-Log -Level Debug -Message "Refreshed tasks from global data: $($self.State.tasks.Count) tasks"
            }
            Request-TuiRefresh
        }
    }
    
    return $screen
}

# Alias for compatibility
function global:Get-TaskScreen {
    return Get-TaskManagementScreen
}

Export-ModuleMember -Function Get-TaskManagementScreen, Get-TaskScreen