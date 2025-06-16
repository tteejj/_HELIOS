# PMC Terminal - PTUI Port
# Keyboard-centric Project Management Console using PTUI Framework

using namespace PoshCode.Pansies
using namespace PoshCode.TerminalUI

# Import PTUI
Import-Module PTUI -ErrorAction Stop

#region Data Model Initialization

# Initialize the unified data model
function global:Get-DefaultSettings {
    return @{
        # Time Tracker Settings
        DefaultRate = 100.0
        Currency = "USD"
        HoursPerDay = 8.0
        DaysPerWeek = 5
        TimeTrackerTemplates = @{
            "ADMIN" = @{ Name = "Administrative Tasks"; Id1 = "100"; Id2 = "ADM"; Client = "Internal"; Department = "Operations"; BillingType = "Non-Billable"; Status = "Active"; Budget = 0.0; Rate = 0.0; Notes = "General administrative tasks" }
            "MEETING" = @{ Name = "Meetings & Calls"; Id1 = "101"; Id2 = "MTG"; Client = "Internal"; Department = "Various"; BillingType = "Non-Billable"; Status = "Active"; Budget = 0.0; Rate = 0.0; Notes = "Team meetings and calls" }
            "TRAINING" = @{ Name = "Training & Learning"; Id1 = "102"; Id2 = "TRN"; Client = "Internal"; Department = "HR"; BillingType = "Non-Billable"; Status = "Active"; Budget = 0.0; Rate = 0.0; Notes = "Professional development" }
            "BREAK" = @{ Name = "Breaks & Personal"; Id1 = "103"; Id2 = "BRK"; Client = "Internal"; Department = "Personal"; BillingType = "Non-Billable"; Status = "Active"; Budget = 0.0; Rate = 0.0; Notes = "Breaks and personal time" }
        }
        DefaultPriority = "Medium"
        DefaultCategory = "General"
        ShowCompletedDays = 7
        EnableTimeTracking = $true
        AutoArchiveDays = 30
        CommandSnippets = @{
            EnableHotkeys = $true
            AutoCopyToClipboard = $true
            ShowInTaskList = $false
            DefaultCategory = "Commands"
            RecentLimit = 10
        }
        Theme = @{
            Header = "Cyan"
            Success = "Green"
            Warning = "Yellow"
            Error = "Red"
            Info = "Blue"
            Accent = "Magenta"
            Subtle = "DarkGray"
        }
    }
}

# Define the $script:Data structure with defaults
$script:Data = @{
    Projects = @{}     
    Tasks = @()        
    TimeEntries = @()  
    ActiveTimers = @{} 
    ArchivedTasks = @()
    CurrentWeek = Get-Date -UFormat %V
    Settings = Get-DefaultSettings
}

#endregion

#region PTUI Helper Functions

function Show-PTUIMessage {
    param(
        [string]$Message,
        [string]$Title = "Information",
        [ConsoleColor]$Color = 'White'
    )
    
    $dialog = [Dialog]::new($Title)
    $text = [TextBlock]::new($Message)
    $text.ForegroundColor = $Color
    $dialog.Add($text)
    
    $ok = [Button]::new("OK")
    $ok.IsDefault = $true
    $dialog.Add($ok)
    
    $null = Show-UI $dialog
}

function Show-PTUIMenu {
    param(
        [string]$Title,
        [array]$MenuItems,
        [scriptblock]$ItemFormatter = { $_ }
    )
    
    $selection = [Selection]::new($MenuItems, $ItemFormatter)
    $selection.Title = $Title
    $selection.MultiSelect = $false
    
    $result = Show-UI $selection
    return $result
}

function Show-PTUIConfirm {
    param(
        [string]$Message,
        [string]$Title = "Confirm"
    )
    
    $dialog = [Dialog]::new($Title)
    $text = [TextBlock]::new($Message)
    $dialog.Add($text)
    
    $yes = [Button]::new("Yes")
    $yes.IsDefault = $true
    $no = [Button]::new("No")
    $no.IsCancel = $true
    
    $dialog.Add($yes)
    $dialog.Add($no)
    
    $result = Show-UI $dialog
    return $result -eq 0  # Yes was selected
}

#endregion

#region Main Menu System

function Show-MainMenu {
    while ($true) {
        Clear-Host
        
        $menuOptions = @(
            [PSCustomObject]@{ Key = "P"; Text = "Project Management"; Action = { Show-ProjectMenu } }
            [PSCustomObject]@{ Key = "T"; Text = "Task Management"; Action = { Show-TaskMenu } }
            [PSCustomObject]@{ Key = "C"; Text = "Command Snippets"; Action = { Show-CommandMenu } }
            [PSCustomObject]@{ Key = "S"; Text = "Settings"; Action = { Show-SettingsMenu } }
            [PSCustomObject]@{ Key = "Q"; Text = "Quit"; Action = { return $false } }
        )
        
        $selected = Show-PTUIMenu -Title "PMC Terminal - Main Menu" -MenuItems $menuOptions -ItemFormatter { "$($_.Key) - $($_.Text)" }
        
        if ($null -eq $selected) { continue }
        
        $result = & $selected.Action
        if ($result -eq $false) { break }
    }
}

function Show-ProjectMenu {
    while ($true) {
        $menuOptions = @(
            [PSCustomObject]@{ Key = "L"; Text = "List Projects"; Action = { Show-ProjectsList } }
            [PSCustomObject]@{ Key = "A"; Text = "Add Project"; Action = { Add-ProjectPTUI } }
            [PSCustomObject]@{ Key = "E"; Text = "Edit Project"; Action = { Edit-ProjectPTUI } }
            [PSCustomObject]@{ Key = "D"; Text = "Delete Project"; Action = { Remove-ProjectPTUI } }
            [PSCustomObject]@{ Key = "S"; Text = "Project Summary"; Action = { Show-ProjectSummaryPTUI } }
            [PSCustomObject]@{ Key = "B"; Text = "Back to Main Menu"; Action = { return $false } }
        )
        
        $selected = Show-PTUIMenu -Title "Project Management" -MenuItems $menuOptions -ItemFormatter { "$($_.Key) - $($_.Text)" }
        
        if ($null -eq $selected) { continue }
        
        $result = & $selected.Action
        if ($result -eq $false) { break }
    }
    return $true
}

function Show-TaskMenu {
    while ($true) {
        $menuOptions = @(
            [PSCustomObject]@{ Key = "L"; Text = "List Tasks"; Action = { Show-TasksList } }
            [PSCustomObject]@{ Key = "A"; Text = "Add Task"; Action = { Add-TaskPTUI } }
            [PSCustomObject]@{ Key = "Q"; Text = "Quick Add Task"; Action = { Quick-AddTaskPTUI } }
            [PSCustomObject]@{ Key = "C"; Text = "Complete Task"; Action = { Complete-TaskPTUI } }
            [PSCustomObject]@{ Key = "E"; Text = "Edit Task"; Action = { Edit-TaskPTUI } }
            [PSCustomObject]@{ Key = "D"; Text = "Delete Task"; Action = { Remove-TaskPTUI } }
            [PSCustomObject]@{ Key = "V"; Text = "View Archive"; Action = { View-TaskArchivePTUI } }
            [PSCustomObject]@{ Key = "B"; Text = "Back to Main Menu"; Action = { return $false } }
        )
        
        $selected = Show-PTUIMenu -Title "Task Management" -MenuItems $menuOptions -ItemFormatter { "$($_.Key) - $($_.Text)" }
        
        if ($null -eq $selected) { continue }
        
        $result = & $selected.Action
        if ($result -eq $false) { break }
    }
    return $true
}

function Show-CommandMenu {
    while ($true) {
        $menuOptions = @(
            [PSCustomObject]@{ Key = "L"; Text = "List Command Snippets"; Action = { Show-CommandsList } }
            [PSCustomObject]@{ Key = "A"; Text = "Add Command Snippet"; Action = { Add-CommandPTUI } }
            [PSCustomObject]@{ Key = "E"; Text = "Execute Command"; Action = { Execute-CommandPTUI } }
            [PSCustomObject]@{ Key = "D"; Text = "Delete Command"; Action = { Remove-CommandPTUI } }
            [PSCustomObject]@{ Key = "B"; Text = "Back to Main Menu"; Action = { return $false } }
        )
        
        $selected = Show-PTUIMenu -Title "Command Snippets" -MenuItems $menuOptions -ItemFormatter { "$($_.Key) - $($_.Text)" }
        
        if ($null -eq $selected) { continue }
        
        $result = & $selected.Action
        if ($result -eq $false) { break }
    }
    return $true
}

#endregion

#region Project Management Functions

function Show-ProjectsList {
    if ($script:Data.Projects.Count -eq 0) {
        Show-PTUIMessage -Message "No projects found." -Title "Projects" -Color Yellow
        return $true
    }
    
    $projectList = $script:Data.Projects.GetEnumerator() | ForEach-Object {
        [PSCustomObject]@{
            Key = $_.Key
            Name = $_.Value.Name
            Client = $_.Value.Client
            Status = $_.Value.Status
            Budget = $_.Value.Budget
        }
    } | Sort-Object Name
    
    $selected = Show-PTUIMenu -Title "Projects List" -MenuItems $projectList -ItemFormatter { 
        "[$($_.Key)] $($_.Name) - Client: $($_.Client) - Status: $($_.Status)"
    }
    
    if ($selected) {
        Show-ProjectDetailsPTUI -ProjectKey $selected.Key
    }
    
    return $true
}

function Show-ProjectDetailsPTUI {
    param([string]$ProjectKey)
    
    $project = $script:Data.Projects[$ProjectKey]
    if (-not $project) { return }
    
    $details = @"
Project: $($project.Name)
Key: $ProjectKey
Client: $($project.Client)
Department: $($project.Department)
Status: $($project.Status)
Billing Type: $($project.BillingType)
Rate: `$$($project.Rate)/hr
Budget: $($project.Budget) hours
Start Date: $($project.StartDate)
Notes: $($project.Notes)
"@
    
    Show-PTUIMessage -Message $details -Title "Project Details" -Color Cyan
}

function Add-ProjectPTUI {
    $dialog = [Dialog]::new("Add New Project")
    
    # Project Key
    $keyLabel = [TextBlock]::new("Project Key (short identifier):")
    $keyInput = [TextBox]::new()
    $dialog.Add($keyLabel)
    $dialog.Add($keyInput)
    
    # Project Name
    $nameLabel = [TextBlock]::new("Project Name:")
    $nameInput = [TextBox]::new()
    $dialog.Add($nameLabel)
    $dialog.Add($nameInput)
    
    # Client
    $clientLabel = [TextBlock]::new("Client Name:")
    $clientInput = [TextBox]::new()
    $dialog.Add($clientLabel)
    $dialog.Add($clientInput)
    
    # Department
    $deptLabel = [TextBlock]::new("Department:")
    $deptInput = [TextBox]::new()
    $dialog.Add($deptLabel)
    $dialog.Add($deptInput)
    
    # Billing Type
    $billingLabel = [TextBlock]::new("Billing Type:")
    $billingOptions = @("Billable", "Non-Billable", "Fixed Price")
    $billingSelect = [Selection]::new($billingOptions)
    $billingSelect.MultiSelect = $false
    $dialog.Add($billingLabel)
    $dialog.Add($billingSelect)
    
    # Rate
    $rateLabel = [TextBlock]::new("Hourly Rate (0 for non-billable):")
    $rateInput = [TextBox]::new()
    $rateInput.Text = "0"
    $dialog.Add($rateLabel)
    $dialog.Add($rateInput)
    
    # Budget
    $budgetLabel = [TextBlock]::new("Budget Hours (0 for unlimited):")
    $budgetInput = [TextBox]::new()
    $budgetInput.Text = "0"
    $dialog.Add($budgetLabel)
    $dialog.Add($budgetInput)
    
    # Notes
    $notesLabel = [TextBlock]::new("Notes:")
    $notesInput = [TextBox]::new()
    $dialog.Add($notesLabel)
    $dialog.Add($notesInput)
    
    # Buttons
    $ok = [Button]::new("OK")
    $ok.IsDefault = $true
    $cancel = [Button]::new("Cancel")
    $cancel.IsCancel = $true
    $dialog.Add($ok)
    $dialog.Add($cancel)
    
    $result = Show-UI $dialog
    
    if ($result -eq 0) {  # OK was pressed
        $projectKey = $keyInput.Text
        
        if ([string]::IsNullOrWhiteSpace($projectKey)) {
            Show-PTUIMessage -Message "Project key cannot be empty!" -Title "Error" -Color Red
            return $true
        }
        
        if ($script:Data.Projects.ContainsKey($projectKey)) {
            Show-PTUIMessage -Message "Project key already exists!" -Title "Error" -Color Red
            return $true
        }
        
        $billingType = if ($billingSelect.SelectedItems) { $billingSelect.SelectedItems[0] } else { "Non-Billable" }
        
        $script:Data.Projects[$projectKey] = @{
            Name = $nameInput.Text
            Client = $clientInput.Text
            Department = $deptInput.Text
            BillingType = $billingType
            Rate = [double]($rateInput.Text -replace '[^\d.]', '')
            Budget = [double]($budgetInput.Text -replace '[^\d.]', '')
            Status = "Active"
            Notes = $notesInput.Text
            StartDate = (Get-Date).ToString("yyyy-MM-dd")
            TotalHours = 0.0
            TotalBilled = 0.0
            CompletedTasks = 0
            ActiveTasks = 0
            CreatedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        Save-Data
        Show-PTUIMessage -Message "Project added successfully!" -Title "Success" -Color Green
    }
    
    return $true
}

function Edit-ProjectPTUI {
    if ($script:Data.Projects.Count -eq 0) {
        Show-PTUIMessage -Message "No projects to edit." -Title "Edit Project" -Color Yellow
        return $true
    }
    
    $projectList = $script:Data.Projects.GetEnumerator() | ForEach-Object {
        [PSCustomObject]@{
            Key = $_.Key
            Name = $_.Value.Name
        }
    } | Sort-Object Name
    
    $selected = Show-PTUIMenu -Title "Select Project to Edit" -MenuItems $projectList -ItemFormatter { 
        "[$($_.Key)] $($_.Name)"
    }
    
    if (-not $selected) { return $true }
    
    $project = $script:Data.Projects[$selected.Key]
    
    $dialog = [Dialog]::new("Edit Project: $($selected.Key)")
    
    # Similar structure to Add-ProjectPTUI but with existing values
    $nameLabel = [TextBlock]::new("Project Name:")
    $nameInput = [TextBox]::new()
    $nameInput.Text = $project.Name
    $dialog.Add($nameLabel)
    $dialog.Add($nameInput)
    
    # ... (similar fields as Add-ProjectPTUI with existing values)
    
    $ok = [Button]::new("Save")
    $ok.IsDefault = $true
    $cancel = [Button]::new("Cancel")
    $cancel.IsCancel = $true
    $dialog.Add($ok)
    $dialog.Add($cancel)
    
    $result = Show-UI $dialog
    
    if ($result -eq 0) {  # Save was pressed
        # Update project properties
        $project.Name = $nameInput.Text
        # ... update other properties
        
        Save-Data
        Show-PTUIMessage -Message "Project updated successfully!" -Title "Success" -Color Green
    }
    
    return $true
}

function Remove-ProjectPTUI {
    if ($script:Data.Projects.Count -eq 0) {
        Show-PTUIMessage -Message "No projects to delete." -Title "Delete Project" -Color Yellow
        return $true
    }
    
    $projectList = $script:Data.Projects.GetEnumerator() | ForEach-Object {
        [PSCustomObject]@{
            Key = $_.Key
            Name = $_.Value.Name
        }
    } | Sort-Object Name
    
    $selected = Show-PTUIMenu -Title "Select Project to Delete" -MenuItems $projectList -ItemFormatter { 
        "[$($_.Key)] $($_.Name)"
    }
    
    if (-not $selected) { return $true }
    
    $confirmed = Show-PTUIConfirm -Message "Are you sure you want to delete project '$($selected.Name)'?" -Title "Confirm Delete"
    
    if ($confirmed) {
        $script:Data.Projects.Remove($selected.Key)
        Save-Data
        Show-PTUIMessage -Message "Project deleted successfully!" -Title "Success" -Color Green
    }
    
    return $true
}

function Show-ProjectSummaryPTUI {
    if ($script:Data.Projects.Count -eq 0) {
        Show-PTUIMessage -Message "No projects available." -Title "Project Summary" -Color Yellow
        return $true
    }
    
    $summary = "PROJECT SUMMARY`n" + "=" * 50 + "`n`n"
    
    foreach ($proj in $script:Data.Projects.GetEnumerator() | Sort-Object {$_.Value.Name}) {
        $p = $proj.Value
        $summary += "[$($proj.Key)] $($p.Name)`n"
        $summary += "  Client: $($p.Client)`n"
        $summary += "  Status: $($p.Status)`n"
        $summary += "  Budget: $($p.Budget) hours`n"
        $summary += "  Used: $($p.TotalHours) hours`n"
        if ($p.Budget -gt 0) {
            $percentUsed = [Math]::Round(($p.TotalHours / $p.Budget) * 100, 1)
            $summary += "  Progress: $percentUsed%`n"
        }
        $summary += "`n"
    }
    
    Show-PTUIMessage -Message $summary -Title "Project Summary" -Color Cyan
    return $true
}

#endregion

#region Task Management Functions

function Show-TasksList {
    $activeTasks = $script:Data.Tasks | Where-Object { -not $_.Completed -and $_.IsCommand -ne $true }
    
    if ($activeTasks.Count -eq 0) {
        Show-PTUIMessage -Message "No active tasks found." -Title "Tasks" -Color Yellow
        return $true
    }
    
    $taskList = $activeTasks | ForEach-Object {
        [PSCustomObject]@{
            Id = $_.Id
            Description = $_.Description
            Priority = $_.Priority
            DueDate = $_.DueDate
            Progress = $_.Progress
        }
    } | Sort-Object Priority, DueDate
    
    $selected = Show-PTUIMenu -Title "Active Tasks" -MenuItems $taskList -ItemFormatter { 
        "[$($_.Id.Substring(0,6))] $($_.Description) - Priority: $($_.Priority) - Progress: $($_.Progress)%"
    }
    
    if ($selected) {
        Show-TaskDetailsPTUI -TaskId $selected.Id
    }
    
    return $true
}

function Show-TaskDetailsPTUI {
    param([string]$TaskId)
    
    $task = $script:Data.Tasks | Where-Object { $_.Id -eq $TaskId } | Select-Object -First 1
    if (-not $task) { return }
    
    $details = @"
Task: $($task.Description)
ID: $($task.Id)
Priority: $($task.Priority)
Category: $($task.Category)
Progress: $($task.Progress)%
Created: $($task.CreatedDate)
Due Date: $(if ($task.DueDate) { $task.DueDate } else { "Not set" })
Estimated Time: $($task.EstimatedTime) hours
Time Spent: $($task.TimeSpent) hours
Tags: $($task.Tags -join ', ')
Notes: $($task.Notes)
"@
    
    Show-PTUIMessage -Message $details -Title "Task Details" -Color Cyan
}

function Add-TaskPTUI {
    $dialog = [Dialog]::new("Add New Task")
    
    # Task Description
    $descLabel = [TextBlock]::new("Task Description:")
    $descInput = [TextBox]::new()
    $dialog.Add($descLabel)
    $dialog.Add($descInput)
    
    # Priority
    $priorityLabel = [TextBlock]::new("Priority:")
    $priorityOptions = @("Critical", "High", "Medium", "Low")
    $prioritySelect = [Selection]::new($priorityOptions)
    $prioritySelect.MultiSelect = $false
    $dialog.Add($priorityLabel)
    $dialog.Add($prioritySelect)
    
    # Category
    $categoryLabel = [TextBlock]::new("Category:")
    $categoryInput = [TextBox]::new()
    $categoryInput.Text = $script:Data.Settings.DefaultCategory
    $dialog.Add($categoryLabel)
    $dialog.Add($categoryInput)
    
    # Due Date
    $dueDateLabel = [TextBlock]::new("Due Date (YYYY-MM-DD or +days):")
    $dueDateInput = [TextBox]::new()
    $dialog.Add($dueDateLabel)
    $dialog.Add($dueDateInput)
    
    # Project
    if ($script:Data.Projects.Count -gt 0) {
        $projectLabel = [TextBlock]::new("Project (optional):")
        $projectOptions = @("None") + ($script:Data.Projects.GetEnumerator() | ForEach-Object { "$($_.Key) - $($_.Value.Name)" })
        $projectSelect = [Selection]::new($projectOptions)
        $projectSelect.MultiSelect = $false
        $dialog.Add($projectLabel)
        $dialog.Add($projectSelect)
    }
    
    # Tags
    $tagsLabel = [TextBlock]::new("Tags (comma-separated):")
    $tagsInput = [TextBox]::new()
    $dialog.Add($tagsLabel)
    $dialog.Add($tagsInput)
    
    # Estimated Time
    $estTimeLabel = [TextBlock]::new("Estimated Hours:")
    $estTimeInput = [TextBox]::new()
    $estTimeInput.Text = "0"
    $dialog.Add($estTimeLabel)
    $dialog.Add($estTimeInput)
    
    # Notes
    $notesLabel = [TextBlock]::new("Notes:")
    $notesInput = [TextBox]::new()
    $dialog.Add($notesLabel)
    $dialog.Add($notesInput)
    
    # Buttons
    $ok = [Button]::new("OK")
    $ok.IsDefault = $true
    $cancel = [Button]::new("Cancel")
    $cancel.IsCancel = $true
    $dialog.Add($ok)
    $dialog.Add($cancel)
    
    $result = Show-UI $dialog
    
    if ($result -eq 0) {  # OK was pressed
        if ([string]::IsNullOrWhiteSpace($descInput.Text)) {
            Show-PTUIMessage -Message "Task description cannot be empty!" -Title "Error" -Color Red
            return $true
        }
        
        $priority = if ($prioritySelect.SelectedItems) { $prioritySelect.SelectedItems[0] } else { "Medium" }
        $projectKey = $null
        
        if ($projectSelect -and $projectSelect.SelectedItems -and $projectSelect.SelectedItems[0] -ne "None") {
            $projectKey = ($projectSelect.SelectedItems[0] -split ' - ')[0]
        }
        
        $dueDate = $null
        if (-not [string]::IsNullOrWhiteSpace($dueDateInput.Text)) {
            if ($dueDateInput.Text -match '^\+(\d+)$') {
                $dueDate = (Get-Date).AddDays([int]$Matches[1]).ToString("yyyy-MM-dd")
            } else {
                try {
                    $dueDate = [datetime]::Parse($dueDateInput.Text).ToString("yyyy-MM-dd")
                } catch {
                    # Invalid date format, ignore
                }
            }
        }
        
        $tags = @()
        if (-not [string]::IsNullOrWhiteSpace($tagsInput.Text)) {
            $tags = $tagsInput.Text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        }
        
        $newTask = @{
            Id = [Guid]::NewGuid().ToString()
            Description = $descInput.Text
            Priority = $priority
            Category = $categoryInput.Text
            ProjectKey = $projectKey
            StartDate = $null
            DueDate = $dueDate
            Tags = $tags
            Progress = 0
            Completed = $false
            CreatedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            CompletedDate = $null
            EstimatedTime = [double]($estTimeInput.Text -replace '[^\d.]', '')
            TimeSpent = 0.0
            Subtasks = @()
            Notes = $notesInput.Text
            LastModified = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            IsCommand = $false
        }
        
        $script:Data.Tasks += $newTask
        Save-Data
        
        Show-PTUIMessage -Message "Task added successfully!`nID: $($newTask.Id.Substring(0,6))" -Title "Success" -Color Green
    }
    
    return $true
}

function Quick-AddTaskPTUI {
    $dialog = [Dialog]::new("Quick Add Task")
    
    $instructionText = [TextBlock]::new(@"
Enter task with shortcuts:
#category @tag !priority due:tomorrow project:KEY est:2.5
"@)
    $instructionText.ForegroundColor = 'DarkGray'
    $dialog.Add($instructionText)
    
    $input = [TextBox]::new()
    $dialog.Add($input)
    
    $ok = [Button]::new("Add")
    $ok.IsDefault = $true
    $cancel = [Button]::new("Cancel")
    $cancel.IsCancel = $true
    $dialog.Add($ok)
    $dialog.Add($cancel)
    
    $result = Show-UI $dialog
    
    if ($result -eq 0 -and -not [string]::IsNullOrWhiteSpace($input.Text)) {
        # Parse the quick add syntax
        $description = $input.Text
        $category = $script:Data.Settings.DefaultCategory
        $tags = @()
        $priority = $script:Data.Settings.DefaultPriority
        $dueDate = $null
        $projectKey = $null
        $estimatedTime = 0.0
        
        # Extract category
        if ($description -match '#(\S+)') {
            $category = $Matches[1]
            $description = $description -replace ('#' + [regex]::Escape($Matches[1])), ''
        }
        
        # Extract tags
        $tagMatches = [regex]::Matches($description, '@(\S+)')
        foreach ($match in $tagMatches) {
            $tags += $match.Groups[1].Value
            $description = $description -replace ('@' + [regex]::Escape($match.Groups[1].Value)), ''
        }
        
        # Extract priority
        if ($description -match '!(critical|high|medium|low|c|h|m|l)\b') {
            $priority = switch ($Matches[1].ToLower()) {
                "c" { "Critical" } "critical" { "Critical" }
                "h" { "High" } "high" { "High" }
                "l" { "Low" } "low" { "Low" }
                default { "Medium" }
            }
            $description = $description -replace ('!' + [regex]::Escape($Matches[1])), ''
        }
        
        # Extract project
        if ($description -match 'project:(\S+)') {
            $extractedProjectKey = $Matches[1]
            if ($script:Data.Projects.ContainsKey($extractedProjectKey)) {
                $projectKey = $extractedProjectKey
            }
            $description = $description -replace ('project:' + [regex]::Escape($Matches[1])), ''
        }
        
        # Extract estimated time
        if ($description -match 'est:(\d+\.?\d*)') {
            try { $estimatedTime = [double]$Matches[1] } catch { $estimatedTime = 0.0 }
            $description = $description -replace ('est:' + [regex]::Escape($Matches[1])), ''
        }
        
        # Extract due date
        if ($description -match 'due:(\S+)') {
            $dueDateStr = $Matches[1]
            try {
                $parsedDueDate = switch -Regex ($dueDateStr.ToLower()) {
                    '^today$' { [datetime]::Today }
                    '^tomorrow$' { [datetime]::Today.AddDays(1) }
                    '^\+(\d+)$' { [datetime]::Today.AddDays([int]$Matches[1]) }
                    default { [datetime]::Parse($dueDateStr) }
                }
                $dueDate = $parsedDueDate.ToString("yyyy-MM-dd")
            } catch {
                # Invalid date format
            }
            $description = $description -replace ('due:' + [regex]::Escape($Matches[1])), ''
        }
        
        $description = $description.Trim() -replace '\s+', ' '
        
        if ([string]::IsNullOrEmpty($description)) {
            Show-PTUIMessage -Message "Task description cannot be empty after parsing!" -Title "Error" -Color Red
            return $true
        }
        
        $newTask = @{
            Id = [Guid]::NewGuid().ToString()
            Description = $description
            Priority = $priority
            Category = $category
            ProjectKey = $projectKey
            StartDate = $null
            DueDate = $dueDate
            Tags = $tags
            Progress = 0
            Completed = $false
            CreatedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            CompletedDate = $null
            EstimatedTime = $estimatedTime
            TimeSpent = 0.0
            Subtasks = @()
            Notes = ""
            LastModified = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            IsCommand = $false
        }
        
        $script:Data.Tasks += $newTask
        Save-Data
        
        $successMsg = "Quick added: '$description'"
        if ($priority -ne $script:Data.Settings.DefaultPriority) { $successMsg += "`nPriority: $priority" }
        if ($dueDate) { $successMsg += "`nDue: $dueDate" }
        if ($projectKey) { $successMsg += "`nProject: $($script:Data.Projects[$projectKey].Name)" }
        if ($tags.Count -gt 0) { $successMsg += "`nTags: $($tags -join ', ')" }
        if ($estimatedTime -gt 0) { $successMsg += "`nEst. Time: ${estimatedTime}h" }
        
        Show-PTUIMessage -Message $successMsg -Title "Success" -Color Green
    }
    
    return $true
}

function Complete-TaskPTUI {
    $activeTasks = $script:Data.Tasks | Where-Object { -not $_.Completed -and $_.IsCommand -ne $true }
    
    if ($activeTasks.Count -eq 0) {
        Show-PTUIMessage -Message "No active tasks to complete." -Title "Complete Task" -Color Yellow
        return $true
    }
    
    $taskList = $activeTasks | ForEach-Object {
        [PSCustomObject]@{
            Id = $_.Id
            Description = $_.Description
            Priority = $_.Priority
        }
    } | Sort-Object Priority, Description
    
    $selected = Show-PTUIMenu -Title "Select Task to Complete" -MenuItems $taskList -ItemFormatter { 
        "[$($_.Id.Substring(0,6))] $($_.Description) - $($_.Priority)"
    }
    
    if ($selected) {
        $task = $script:Data.Tasks | Where-Object { $_.Id -eq $selected.Id } | Select-Object -First 1
        
        if ($task.Subtasks -and ($task.Subtasks | Where-Object { -not $_.Completed }).Count -gt 0) {
            $uncompletedCount = ($task.Subtasks | Where-Object { -not $_.Completed }).Count
            $confirmed = Show-PTUIConfirm -Message "Task has $uncompletedCount uncompleted subtask(s). Complete anyway?" -Title "Confirm Complete"
            if (-not $confirmed) { return $true }
        }
        
        $task.Completed = $true
        $task.Progress = 100
        $task.CompletedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $task.LastModified = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        
        Save-Data
        
        $msg = "Completed: $($task.Description)"
        if ($task.TimeSpent -gt 0) {
            $msg += "`nTime spent: $($task.TimeSpent) hours"
            if ($task.EstimatedTime -gt 0) {
                $efficiency = [Math]::Round(($task.EstimatedTime / $task.TimeSpent) * 100, 0)
                $msg += "`nEfficiency: $efficiency% of estimate"
            }
        }
        
        Show-PTUIMessage -Message $msg -Title "Task Completed" -Color Green
    }
    
    return $true
}

function Edit-TaskPTUI {
    $tasks = $script:Data.Tasks | Where-Object { $_.IsCommand -ne $true }
    
    if ($tasks.Count -eq 0) {
        Show-PTUIMessage -Message "No tasks to edit." -Title "Edit Task" -Color Yellow
        return $true
    }
    
    $taskList = $tasks | ForEach-Object {
        [PSCustomObject]@{
            Id = $_.Id
            Description = $_.Description
            Completed = $_.Completed
        }
    } | Sort-Object Completed, Description
    
    $selected = Show-PTUIMenu -Title "Select Task to Edit" -MenuItems $taskList -ItemFormatter { 
        $status = if ($_.Completed) { "[✓]" } else { "[ ]" }
        "$status [$($_.Id.Substring(0,6))] $($_.Description)"
    }
    
    if (-not $selected) { return $true }
    
    $task = $script:Data.Tasks | Where-Object { $_.Id -eq $selected.Id } | Select-Object -First 1
    
    # Create edit dialog similar to Add-TaskPTUI but with existing values
    # ... (implementation similar to Add-TaskPTUI with pre-filled values)
    
    Show-PTUIMessage -Message "Edit task functionality to be implemented with full dialog." -Title "Edit Task" -Color Yellow
    return $true
}

function Remove-TaskPTUI {
    $tasks = $script:Data.Tasks | Where-Object { $_.IsCommand -ne $true }
    
    if ($tasks.Count -eq 0) {
        Show-PTUIMessage -Message "No tasks to delete." -Title "Delete Task" -Color Yellow
        return $true
    }
    
    $taskList = $tasks | ForEach-Object {
        [PSCustomObject]@{
            Id = $_.Id
            Description = $_.Description
            Completed = $_.Completed
        }
    } | Sort-Object Completed, Description
    
    $selected = Show-PTUIMenu -Title "Select Task to Delete" -MenuItems $taskList -ItemFormatter { 
        $status = if ($_.Completed) { "[✓]" } else { "[ ]" }
        "$status [$($_.Id.Substring(0,6))] $($_.Description)"
    }
    
    if (-not $selected) { return $true }
    
    $task = $script:Data.Tasks | Where-Object { $_.Id -eq $selected.Id } | Select-Object -First 1
    
    $warningMsg = "Permanently delete task: '$($task.Description)'?"
    if ($task.TimeSpent -gt 0) {
        $warningMsg += "`n`nThis task has $($task.TimeSpent) hours logged!"
    }
    if ($task.Subtasks -and $task.Subtasks.Count -gt 0) {
        $warningMsg += "`n`nThis task has $($task.Subtasks.Count) subtask(s) which will also be deleted."
    }
    
    $confirmed = Show-PTUIConfirm -Message $warningMsg -Title "Confirm Delete"
    
    if ($confirmed) {
        $script:Data.Tasks = $script:Data.Tasks | Where-Object { $_.Id -ne $task.Id }
        Save-Data
        Show-PTUIMessage -Message "Task deleted successfully!" -Title "Success" -Color Green
    }
    
    return $true
}

function View-TaskArchivePTUI {
    if (-not $script:Data.ArchivedTasks -or $script:Data.ArchivedTasks.Count -eq 0) {
        Show-PTUIMessage -Message "No archived tasks." -Title "Task Archive" -Color Yellow
        return $true
    }
    
    $archiveList = $script:Data.ArchivedTasks | ForEach-Object {
        [PSCustomObject]@{
            Id = $_.Id
            Description = $_.Description
            CompletedDate = $_.CompletedDate
            TimeSpent = $_.TimeSpent
        }
    } | Sort-Object CompletedDate -Descending
    
    $selected = Show-PTUIMenu -Title "Archived Tasks" -MenuItems $archiveList -ItemFormatter { 
        $date = if ($_.CompletedDate) { [datetime]::Parse($_.CompletedDate).ToString('yyyy-MM-dd') } else { 'Unknown' }
        "[$date] $($_.Description) - Time: $($_.TimeSpent)h"
    }
    
    if ($selected) {
        Show-TaskDetailsPTUI -TaskId $selected.Id
    }
    
    return $true
}

#endregion

#region Command Snippets Functions

function Show-CommandsList {
    $commands = $script:Data.Tasks | Where-Object { $_.IsCommand -eq $true }
    
    if ($commands.Count -eq 0) {
        Show-PTUIMessage -Message "No command snippets found." -Title "Commands" -Color Yellow
        return $true
    }
    
    $commandList = $commands | ForEach-Object {
        [PSCustomObject]@{
            Id = $_.Id
            Description = $_.Description
            Category = $_.Category
            UseCount = $_.UseCount
        }
    } | Sort-Object UseCount -Descending, Description
    
    $selected = Show-PTUIMenu -Title "Command Snippets" -MenuItems $commandList -ItemFormatter { 
        "[$($_.Id.Substring(0,6))] $($_.Description) - Category: $($_.Category) - Used: $($_.UseCount)"
    }
    
    if ($selected) {
        $command = $script:Data.Tasks | Where-Object { $_.Id -eq $selected.Id } | Select-Object -First 1
        
        $details = @"
Command: $($command.Description)
Category: $($command.Category)
Tags: $($command.Tags -join ', ')
Used: $($command.UseCount) times
Last Used: $(if ($command.LastUsed) { $command.LastUsed } else { "Never" })

Command Content:
$($command.Notes)
"@
        
        Show-PTUIMessage -Message $details -Title "Command Details" -Color Cyan
    }
    
    return $true
}

function Add-CommandPTUI {
    $dialog = [Dialog]::new("Add Command Snippet")
    
    # Command Name
    $nameLabel = [TextBlock]::new("Command Name/Description:")
    $nameInput = [TextBox]::new()
    $dialog.Add($nameLabel)
    $dialog.Add($nameInput)
    
    # Command Content
    $contentLabel = [TextBlock]::new("Command Content (PowerShell code):")
    $contentInput = [TextBox]::new()
    $contentInput.AcceptsReturn = $true
    $contentInput.Height = 10
    $dialog.Add($contentLabel)
    $dialog.Add($contentInput)
    
    # Category
    $categoryLabel = [TextBlock]::new("Category:")
    $categoryInput = [TextBox]::new()
    $categoryInput.Text = $script:Data.Settings.CommandSnippets.DefaultCategory
    $dialog.Add($categoryLabel)
    $dialog.Add($categoryInput)
    
    # Tags
    $tagsLabel = [TextBlock]::new("Tags (comma-separated):")
    $tagsInput = [TextBox]::new()
    $dialog.Add($tagsLabel)
    $dialog.Add($tagsInput)
    
    # Hotkey
    $hotkeyLabel = [TextBlock]::new("Hotkey (optional, e.g., ctrl+1):")
    $hotkeyInput = [TextBox]::new()
    $dialog.Add($hotkeyLabel)
    $dialog.Add($hotkeyInput)
    
    # Buttons
    $ok = [Button]::new("OK")
    $ok.IsDefault = $true
    $cancel = [Button]::new("Cancel")
    $cancel.IsCancel = $true
    $dialog.Add($ok)
    $dialog.Add($cancel)
    
    $result = Show-UI $dialog
    
    if ($result -eq 0) {  # OK was pressed
        if ([string]::IsNullOrWhiteSpace($nameInput.Text)) {
            Show-PTUIMessage -Message "Command name cannot be empty!" -Title "Error" -Color Red
            return $true
        }
        
        if ([string]::IsNullOrWhiteSpace($contentInput.Text)) {
            Show-PTUIMessage -Message "Command content cannot be empty!" -Title "Error" -Color Red
            return $true
        }
        
        $tags = @()
        if (-not [string]::IsNullOrWhiteSpace($tagsInput.Text)) {
            $tags = $tagsInput.Text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        }
        
        $snippet = @{
            Id = [Guid]::NewGuid().ToString()
            Description = $nameInput.Text
            Priority = "Low"
            Category = $categoryInput.Text
            ProjectKey = $null
            StartDate = $null
            DueDate = $null
            Tags = $tags
            Progress = 0
            Completed = $false
            CreatedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            CompletedDate = $null
            EstimatedTime = 0
            TimeSpent = 0
            Subtasks = @()
            Notes = $contentInput.Text
            LastModified = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            IsCommand = $true
            Hotkey = $hotkeyInput.Text
            LastUsed = $null
            UseCount = 0
        }
        
        $script:Data.Tasks += $snippet
        Save-Data
        
        $msg = "Command snippet added: $($snippet.Description)"
        if ($script:Data.Settings.CommandSnippets.AutoCopyToClipboard) {
            Set-Clipboard -Value $contentInput.Text
            $msg += "`n`nCommand copied to clipboard!"
        }
        
        Show-PTUIMessage -Message $msg -Title "Success" -Color Green
    }
    
    return $true
}

function Execute-CommandPTUI {
    $commands = $script:Data.Tasks | Where-Object { $_.IsCommand -eq $true }
    
    if ($commands.Count -eq 0) {
        Show-PTUIMessage -Message "No command snippets found." -Title "Execute Command" -Color Yellow
        return $true
    }
    
    $commandList = $commands | ForEach-Object {
        [PSCustomObject]@{
            Id = $_.Id
            Description = $_.Description
            Category = $_.Category
        }
    } | Sort-Object Category, Description
    
    $selected = Show-PTUIMenu -Title "Select Command to Execute" -MenuItems $commandList -ItemFormatter { 
        "[$($_.Category)] $($_.Description)"
    }
    
    if (-not $selected) { return $true }
    
    $command = $script:Data.Tasks | Where-Object { $_.Id -eq $selected.Id } | Select-Object -First 1
    
    $actionOptions = @(
        [PSCustomObject]@{ Key = "C"; Text = "Copy to clipboard"; Action = "Copy" }
        [PSCustomObject]@{ Key = "E"; Text = "Execute in PowerShell"; Action = "Execute" }
        [PSCustomObject]@{ Key = "B"; Text = "Both (Copy and Execute)"; Action = "Both" }
        [PSCustomObject]@{ Key = "V"; Text = "View command"; Action = "View" }
    )
    
    $action = Show-PTUIMenu -Title "Command: $($command.Description)" -MenuItems $actionOptions -ItemFormatter { "$($_.Key) - $($_.Text)" }
    
    if ($action) {
        switch ($action.Action) {
            "Copy" {
                Set-Clipboard -Value $command.Notes
                Show-PTUIMessage -Message "Command copied to clipboard!" -Title "Success" -Color Green
            }
            "Execute" {
                $confirmed = Show-PTUIConfirm -Message "Execute this command in the current PowerShell session?" -Title "Confirm Execute"
                if ($confirmed) {
                    try {
                        Invoke-Expression $command.Notes
                        Show-PTUIMessage -Message "Command executed successfully!" -Title "Success" -Color Green
                    } catch {
                        Show-PTUIMessage -Message "Execution failed: $_" -Title "Error" -Color Red
                    }
                }
            }
            "Both" {
                Set-Clipboard -Value $command.Notes
                $confirmed = Show-PTUIConfirm -Message "Command copied. Execute in the current PowerShell session?" -Title "Confirm Execute"
                if ($confirmed) {
                    try {
                        Invoke-Expression $command.Notes
                        Show-PTUIMessage -Message "Command copied and executed successfully!" -Title "Success" -Color Green
                    } catch {
                        Show-PTUIMessage -Message "Copy succeeded but execution failed: $_" -Title "Error" -Color Red
                    }
                }
            }
            "View" {
                Show-PTUIMessage -Message $command.Notes -Title "Command Content" -Color White
            }
        }
        
        # Update usage stats
        $command.LastUsed = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $command.UseCount = [int]$command.UseCount + 1
        Save-Data
    }
    
    return $true
}

function Remove-CommandPTUI {
    $commands = $script:Data.Tasks | Where-Object { $_.IsCommand -eq $true }
    
    if ($commands.Count -eq 0) {
        Show-PTUIMessage -Message "No command snippets to delete." -Title "Delete Command" -Color Yellow
        return $true
    }
    
    $commandList = $commands | ForEach-Object {
        [PSCustomObject]@{
            Id = $_.Id
            Description = $_.Description
            Category = $_.Category
        }
    } | Sort-Object Category, Description
    
    $selected = Show-PTUIMenu -Title "Select Command to Delete" -MenuItems $commandList -ItemFormatter { 
        "[$($_.Category)] $($_.Description)"
    }
    
    if (-not $selected) { return $true }
    
    $confirmed = Show-PTUIConfirm -Message "Delete command snippet: '$($selected.Description)'?" -Title "Confirm Delete"
    
    if ($confirmed) {
        $script:Data.Tasks = $script:Data.Tasks | Where-Object { $_.Id -ne $selected.Id }
        Save-Data
        Show-PTUIMessage -Message "Command snippet deleted!" -Title "Success" -Color Green
    }
    
    return $true
}

#endregion

#region Settings Menu

function Show-SettingsMenu {
    while ($true) {
        $menuOptions = @(
            [PSCustomObject]@{ Key = "T"; Text = "Task Settings"; Action = { Edit-TaskSettingsPTUI } }
            [PSCustomObject]@{ Key = "C"; Text = "Command Snippet Settings"; Action = { Edit-CommandSettingsPTUI } }
            [PSCustomObject]@{ Key = "E"; Text = "Export Data"; Action = { Export-DataPTUI } }
            [PSCustomObject]@{ Key = "I"; Text = "Import Data"; Action = { Import-DataPTUI } }
            [PSCustomObject]@{ Key = "B"; Text = "Back to Main Menu"; Action = { return $false } }
        )
        
        $selected = Show-PTUIMenu -Title "Settings" -MenuItems $menuOptions -ItemFormatter { "$($_.Key) - $($_.Text)" }
        
        if ($null -eq $selected) { continue }
        
        $result = & $selected.Action
        if ($result -eq $false) { break }
    }
    return $true
}

function Edit-TaskSettingsPTUI {
    $dialog = [Dialog]::new("Task Settings")
    
    $settings = $script:Data.Settings
    
    # Default Priority
    $priorityLabel = [TextBlock]::new("Default Priority:")
    $priorityOptions = @("Critical", "High", "Medium", "Low")
    $prioritySelect = [Selection]::new($priorityOptions)
    $prioritySelect.MultiSelect = $false
    # Set current selection
    for ($i = 0; $i -lt $priorityOptions.Count; $i++) {
        if ($priorityOptions[$i] -eq $settings.DefaultPriority) {
            $prioritySelect.SelectedIndices = @($i)
            break
        }
    }
    $dialog.Add($priorityLabel)
    $dialog.Add($prioritySelect)
    
    # Default Category
    $categoryLabel = [TextBlock]::new("Default Category:")
    $categoryInput = [TextBox]::new()
    $categoryInput.Text = $settings.DefaultCategory
    $dialog.Add($categoryLabel)
    $dialog.Add($categoryInput)
    
    # Show Completed Days
    $showDaysLabel = [TextBlock]::new("Days to show completed tasks:")
    $showDaysInput = [TextBox]::new()
    $showDaysInput.Text = $settings.ShowCompletedDays.ToString()
    $dialog.Add($showDaysLabel)
    $dialog.Add($showDaysInput)
    
    # Auto Archive Days
    $archiveDaysLabel = [TextBlock]::new("Days until auto-archive:")
    $archiveDaysInput = [TextBox]::new()
    $archiveDaysInput.Text = $settings.AutoArchiveDays.ToString()
    $dialog.Add($archiveDaysLabel)
    $dialog.Add($archiveDaysInput)
    
    # Buttons
    $ok = [Button]::new("Save")
    $ok.IsDefault = $true
    $cancel = [Button]::new("Cancel")
    $cancel.IsCancel = $true
    $dialog.Add($ok)
    $dialog.Add($cancel)
    
    $result = Show-UI $dialog
    
    if ($result -eq 0) {  # Save was pressed
        if ($prioritySelect.SelectedItems) {
            $settings.DefaultPriority = $prioritySelect.SelectedItems[0]
        }
        $settings.DefaultCategory = $categoryInput.Text
        
        try {
            $settings.ShowCompletedDays = [int]$showDaysInput.Text
            $settings.AutoArchiveDays = [int]$archiveDaysInput.Text
        } catch {
            # Keep existing values if conversion fails
        }
        
        Save-Data
        Show-PTUIMessage -Message "Task settings updated!" -Title "Success" -Color Green
    }
    
    return $true
}

function Edit-CommandSettingsPTUI {
    $dialog = [Dialog]::new("Command Snippet Settings")
    
    $settings = $script:Data.Settings.CommandSnippets
    
    # Auto Copy to Clipboard
    $autoCopyLabel = [TextBlock]::new("Auto-copy to clipboard when adding:")
    $autoCopyCheck = [Selection]::new(@("Yes", "No"))
    $autoCopyCheck.MultiSelect = $false
    $autoCopyCheck.SelectedIndices = if ($settings.AutoCopyToClipboard) { @(0) } else { @(1) }
    $dialog.Add($autoCopyLabel)
    $dialog.Add($autoCopyCheck)
    
    # Default Category
    $categoryLabel = [TextBlock]::new("Default Category:")
    $categoryInput = [TextBox]::new()
    $categoryInput.Text = $settings.DefaultCategory
    $dialog.Add($categoryLabel)
    $dialog.Add($categoryInput)
    
    # Recent Limit
    $recentLabel = [TextBlock]::new("Number of recent snippets to show:")
    $recentInput = [TextBox]::new()
    $recentInput.Text = $settings.RecentLimit.ToString()
    $dialog.Add($recentLabel)
    $dialog.Add($recentInput)
    
    # Buttons
    $ok = [Button]::new("Save")
    $ok.IsDefault = $true
    $cancel = [Button]::new("Cancel")
    $cancel.IsCancel = $true
    $dialog.Add($ok)
    $dialog.Add($cancel)
    
    $result = Show-UI $dialog
    
    if ($result -eq 0) {  # Save was pressed
        $settings.AutoCopyToClipboard = ($autoCopyCheck.SelectedItems -and $autoCopyCheck.SelectedItems[0] -eq "Yes")
        $settings.DefaultCategory = $categoryInput.Text
        
        try {
            $settings.RecentLimit = [int]$recentInput.Text
        } catch {
            # Keep existing value if conversion fails
        }
        
        Save-Data
        Show-PTUIMessage -Message "Command snippet settings updated!" -Title "Success" -Color Green
    }
    
    return $true
}

function Export-DataPTUI {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $exportPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "PMC_Export_$timestamp.json"
    
    try {
        $script:Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $exportPath -Encoding UTF8
        Show-PTUIMessage -Message "Data exported to:`n$exportPath" -Title "Export Successful" -Color Green
    } catch {
        Show-PTUIMessage -Message "Export failed: $_" -Title "Export Error" -Color Red
    }
    
    return $true
}

function Import-DataPTUI {
    $dialog = [Dialog]::new("Import Data")
    
    $warningText = [TextBlock]::new("WARNING: This will overwrite all current data!")
    $warningText.ForegroundColor = 'Yellow'
    $dialog.Add($warningText)
    
    $pathLabel = [TextBlock]::new("Import file path:")
    $pathInput = [TextBox]::new()
    $dialog.Add($pathLabel)
    $dialog.Add($pathInput)
    
    $ok = [Button]::new("Import")
    $ok.IsDefault = $true
    $cancel = [Button]::new("Cancel")
    $cancel.IsCancel = $true
    $dialog.Add($ok)
    $dialog.Add($cancel)
    
    $result = Show-UI $dialog
    
    if ($result -eq 0 -and -not [string]::IsNullOrWhiteSpace($pathInput.Text)) {
        if (Test-Path $pathInput.Text) {
            $confirmed = Show-PTUIConfirm -Message "Are you sure you want to import? This will overwrite all current data!" -Title "Confirm Import"
            
            if ($confirmed) {
                try {
                    $importedData = Get-Content -Path $pathInput.Text -Raw | ConvertFrom-Json
                    $script:Data = $importedData
                    Save-Data
                    Show-PTUIMessage -Message "Data imported successfully!" -Title "Import Successful" -Color Green
                } catch {
                    Show-PTUIMessage -Message "Import failed: $_" -Title "Import Error" -Color Red
                }
            }
        } else {
            Show-PTUIMessage -Message "File not found: $($pathInput.Text)" -Title "Import Error" -Color Red
        }
    }
    
    return $true
}

#endregion

#region Data Persistence

function Save-Data {
    $dataPath = Join-Path $env:APPDATA "PMC-PTUI"
    if (-not (Test-Path $dataPath)) {
        New-Item -ItemType Directory -Path $dataPath -Force | Out-Null
    }
    
    $dataFile = Join-Path $dataPath "data.json"
    
    try {
        $script:Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $dataFile -Encoding UTF8
    } catch {
        Write-Warning "Failed to save data: $_"
    }
}

function Load-Data {
    $dataPath = Join-Path $env:APPDATA "PMC-PTUI"
    $dataFile = Join-Path $dataPath "data.json"
    
    if (Test-Path $dataFile) {
        try {
            $loadedData = Get-Content -Path $dataFile -Raw | ConvertFrom-Json
            $script:Data = $loadedData
        } catch {
            Write-Warning "Failed to load data: $_"
        }
    }
}

#endregion

#region Main Entry Point

# Load existing data
Load-Data

# Start the main menu
Show-MainMenu

# Save data on exit
Save-Data

Write-Host "`nThank you for using PMC Terminal (PTUI Edition)!" -ForegroundColor Cyan
