# Text Resources Module
# Simple text management without external dependencies

$script:TextResources = @{
    # Common UI strings
    Common = @{
        OK = "OK"
        Cancel = "Cancel"
        Save = "Save"
        Delete = "Delete"
        Edit = "Edit"
        Add = "Add"
        Remove = "Remove"
        Back = "Back"
        Next = "Next"
        Previous = "Previous"
        Close = "Close"
        Error = "Error"
        Warning = "Warning"
        Info = "Information"
        Success = "Success"
        Loading = "Loading..."
        PleaseWait = "Please wait..."
    }
    
    # Dashboard specific
    Dashboard = @{
        Title = "PMC Terminal Dashboard"
        QuickActions = "Quick Actions"
        ActiveTimers = "Active Timers"
        TodaysTasks = "Today's Tasks"
        Stats = "Statistics"
        NoTimersActive = "No active timers"
        NoTasksToday = "No tasks for today"
    }
    
    # Task screen specific
    Tasks = @{
        Title = "Task Management"
        AddTask = "Add Task"
        EditTask = "Edit Task"
        DeleteConfirm = "Are you sure you want to delete this task?"
        FilterAll = "All"
        FilterActive = "Active"
        FilterCompleted = "Completed"
        SortByPriority = "Priority"
        SortByDueDate = "Due Date"
        SortByCreated = "Created"
    }
    
    # Form labels
    Forms = @{
        Title = "Title"
        Description = "Description"
        Category = "Category"
        Priority = "Priority"
        DueDate = "Due Date"
        Status = "Status"
        Project = "Project"
        Hours = "Hours"
        Date = "Date"
    }
    
    # Validation messages
    Validation = @{
        Required = "{0} is required"
        MinLength = "{0} must be at least {1} characters"
        MaxLength = "{0} cannot exceed {1} characters"
        InvalidDate = "Invalid date format"
        InvalidNumber = "Must be a valid number"
    }
    
    # Status messages
    Status = @{
        Saved = "Changes saved successfully"
        Deleted = "Item deleted successfully"
        Updated = "Item updated successfully"
        Created = "Item created successfully"
        Error = "An error occurred: {0}"
    }
}

function global:Get-Text {
    <#
    .SYNOPSIS
    Retrieves a text resource by key path
    
    .PARAMETER Key
    Dot-separated path to the text resource (e.g., "Common.OK")
    
    .PARAMETER Format
    Optional format arguments for string interpolation
    
    .EXAMPLE
    Get-Text "Common.OK"
    Get-Text "Validation.Required" -Format "Username"
    Get-Text "Status.Error" -Format $_.Exception.Message
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Key,
        
        [Parameter(ValueFromRemainingArguments=$true)]
        [object[]]$Format
    )
    
    # Navigate the nested hashtable
    $parts = $Key -split '\.'
    $current = $script:TextResources
    
    foreach ($part in $parts) {
        if ($current -is [hashtable] -and $current.ContainsKey($part)) {
            $current = $current[$part]
        } else {
            Write-Warning "Text resource not found: '$Key'"
            return $Key  # Return the key as fallback
        }
    }
    
    # Format the string if arguments provided
    if ($Format -and $Format.Count -gt 0) {
        try {
            return $current -f $Format
        } catch {
            Write-Warning "Failed to format text resource '$Key': $_"
            return $current
        }
    }
    
    return $current
}

function global:Set-TextResource {
    <#
    .SYNOPSIS
    Sets or updates a text resource
    
    .PARAMETER Key
    Dot-separated path to the text resource
    
    .PARAMETER Value
    The text value to set
    
    .EXAMPLE
    Set-TextResource "Custom.WelcomeMessage" "Welcome to my app!"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Key,
        
        [Parameter(Mandatory=$true)]
        [string]$Value
    )
    
    $parts = $Key -split '\.'
    $current = $script:TextResources
    
    # Navigate to the parent
    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
        $part = $parts[$i]
        if (-not $current.ContainsKey($part)) {
            $current[$part] = @{}
        }
        $current = $current[$part]
    }
    
    # Set the value
    $current[$parts[-1]] = $Value
}

function global:Get-TextResources {
    <#
    .SYNOPSIS
    Gets all text resources (useful for export/import)
    #>
    return $script:TextResources.Clone()
}

function global:Import-TextResources {
    <#
    .SYNOPSIS
    Imports text resources from a file
    
    .PARAMETER Path
    Path to JSON file containing text resources
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if (Test-Path $Path) {
        try {
            $imported = Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable
            $script:TextResources = $imported
            Write-Host "Text resources imported successfully"
        } catch {
            Write-Error "Failed to import text resources: $_"
        }
    } else {
        Write-Error "File not found: $Path"
    }
}

function global:Export-TextResources {
    <#
    .SYNOPSIS
    Exports text resources to a file
    
    .PARAMETER Path
    Path to save the JSON file
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    try {
        $script:TextResources | ConvertTo-Json -Depth 10 | Set-Content $Path
        Write-Host "Text resources exported successfully"
    } catch {
        Write-Error "Failed to export text resources: $_"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-Text',
    'Set-TextResource',
    'Get-TextResources',
    'Import-TextResources',
    'Export-TextResources'
)
