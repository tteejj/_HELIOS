# REAL Fix for Task Screen Form Components
# This fix addresses the root cause: components being stored in multiple places

# File: screens\task-screen.psm1

# STEP 1: Replace the Init method's component creation section
# Find the section starting around line 185 where form components are created
# Replace the ENTIRE form component creation section with this:

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

            # Create the form panel - HIDDEN by default
            $self.Components.formPanel = New-TuiPanel -Props @{
                X = 10; Y = 4; Width = 60; Height = 26
                Layout = 'Stack'; Orientation = 'Vertical'; Spacing = 1; Padding = 2
                ShowBorder = $true
                Visible = $false # Start hidden
                Title = " New Task "
            }
            
            # Create form components and add them ONLY to the panel
            # DO NOT store them in $self.Components
            
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
                Width = 54; Height = 5; IsFocusable = $true; Name = "formDescription"
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
            
            # Add helper method to find form components
            $self.GetFormComponent = {
                param($screen, $name)
                foreach ($child in $screen.Components.formPanel.Children) {
                    if ($child.Name -eq $name) { return $child }
                    if ($child.Children) {
                        foreach ($subchild in $child.Children) {
                            if ($subchild.Name -eq $name) { return $subchild }
                        }
                    }
                }
                return $null
            }
        }

# STEP 2: Update the ShowForm method to use the helper
# Replace the ShowForm method with this:

        ShowForm = {
            param($screen, $taskId)
            
            $isEditing = $null -ne $taskId
            
            # Get form components through helper
            $titleField = & $screen.GetFormComponent -screen $screen -name "formTitle"
            $descField = & $screen.GetFormComponent -screen $screen -name "formDescription"
            $catField = & $screen.GetFormComponent -screen $screen -name "formCategory"
            $priField = & $screen.GetFormComponent -screen $screen -name "formPriority"
            $dueField = & $screen.GetFormComponent -screen $screen -name "formDueDate"
            
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
            $screen.Components.formPanel.Visible = $true
            $screen.Components.taskTable.Visible = $false
            
            # Focus the title field
            Set-ComponentFocus -Component $titleField
        }

# STEP 3: Update the SaveTask method to use the helper
# Replace the SaveTask method with this:

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

# STEP 4: The Render method is already correct in the current file
# It only renders components without a Parent property

# STEP 5: Fix tab navigation in HandleInput
# The current HandleInput is already using Handle-TabNavigation which is correct
