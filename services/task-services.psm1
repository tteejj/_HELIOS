# Task Service Module
# Manages all state and business logic related to tasks
# Replaces the old app-store pattern for task management

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Initialize-TaskService {
    <#
    .SYNOPSIS
    Initializes the Task Service with PowerShell-First architecture
    
    .DESCRIPTION
    Creates and returns a service object that manages task state and operations.
    Uses PowerShell's native eventing engine for state change notifications.
    
    .OUTPUTS
    [PSCustomObject] The initialized Task Service instance
    #>
    
    Invoke-WithErrorHandling -Component "TaskService.Initialize" -Context @{} -ScriptBlock {
        Write-Log -Level Info -Message "Initializing Task Service"
        
        # Create the service object
        $service = [PSCustomObject]@{
            _tasks = @()  # Private array to hold tasks
            _isInitialized = $false
        }
        
        # Register the service's events with PowerShell's native engine
        Register-EngineEvent -SourceIdentifier "TaskService" -SupportEvent
        Write-Log -Level Debug -Message "Registered TaskService engine event"
        
        # AddTask method
        Add-Member -InputObject $service -MemberType ScriptMethod -Name "AddTask" -Value {
            param(
                [Parameter(Mandatory = $true)]
                [hashtable]$taskData
            )
            
            Invoke-WithErrorHandling -Component "TaskService.AddTask" -Context @{ TaskData = $taskData } -ScriptBlock {
                # Defensive validation
                if (-not $taskData) {
                    Write-Log -Level Warning -Message "AddTask: No task data provided"
                    return
                }
                
                if (-not $taskData.Title -or [string]::IsNullOrWhiteSpace($taskData.Title)) {
                    Write-Log -Level Warning -Message "AddTask: No title provided"
                    return
                }
                
                Write-Log -Level Info -Message "Adding new task: $($taskData.Title)"
                
                # Create new task with all required fields
                $newTask = @{
                    id = [Guid]::NewGuid().ToString()
                    title = $taskData.Title.Trim()
                    description = if ($taskData.Description) { $taskData.Description } else { "" }
                    completed = $false
                    priority = if ($taskData.Priority) { $taskData.Priority } else { "medium" }
                    project = if ($taskData.Category) { $taskData.Category } else { "General" }
                    due_date = if ($taskData.DueDate) { $taskData.DueDate } else { $null }
                    created_at = (Get-Date).ToString("o")
                    updated_at = (Get-Date).ToString("o")
                }
                
                # Add to internal task array
                $this._tasks = @($this._tasks) + $newTask
                
                Write-Log -Level Debug -Message "Task created with ID: $($newTask.id)"
                
                # Persist if data manager available
                if ($global:Data) {
                    if (-not $global:Data.ContainsKey('Tasks')) {
                        $global:Data.Tasks = @()
                    }
                    $global:Data.Tasks = @($global:Data.Tasks) + $newTask
                    
                    if (Get-Command Save-UnifiedData -ErrorAction SilentlyContinue) {
                        Save-UnifiedData
                        Write-Log -Level Debug -Message "Task data persisted"
                    }
                }
                
                # Announce state change using native PowerShell eventing
                New-Event -SourceIdentifier "TaskService" -EventIdentifier "Tasks.Changed" -MessageData @{
                    Action = "TaskAdded"
                    TaskId = $newTask.id
                    Task = $newTask
                }
                
                Write-Log -Level Info -Message "Task added successfully: $($newTask.id)"
                return $newTask
            }
        }
        
        # UpdateTask method
        Add-Member -InputObject $service -MemberType ScriptMethod -Name "UpdateTask" -Value {
            param(
                [Parameter(Mandatory = $true)]
                [string]$taskId,
                
                [Parameter(Mandatory = $true)]
                [hashtable]$updates
            )
            
            Invoke-WithErrorHandling -Component "TaskService.UpdateTask" -Context @{ TaskId = $taskId; Updates = $updates } -ScriptBlock {
                # Defensive validation
                if (-not $taskId) {
                    Write-Log -Level Warning -Message "UpdateTask: No TaskId provided"
                    return
                }
                
                if (-not $updates -or $updates.Count -eq 0) {
                    Write-Log -Level Warning -Message "UpdateTask: No updates provided"
                    return
                }
                
                Write-Log -Level Info -Message "Updating task: $taskId"
                
                # Find task in internal array
                $taskIndex = -1
                for ($i = 0; $i -lt $this._tasks.Count; $i++) {
                    if ($this._tasks[$i].id -eq $taskId) {
                        $taskIndex = $i
                        break
                    }
                }
                
                if ($taskIndex -eq -1) {
                    Write-Log -Level Warning -Message "UpdateTask: Task not found with ID $taskId"
                    return
                }
                
                # Update task fields
                $task = $this._tasks[$taskIndex]
                if ($updates.ContainsKey('Title') -and $updates.Title) { 
                    $task.title = $updates.Title.Trim() 
                }
                if ($updates.ContainsKey('Description')) { 
                    $task.description = $updates.Description 
                }
                if ($updates.ContainsKey('Priority')) { 
                    $task.priority = $updates.Priority 
                }
                if ($updates.ContainsKey('Category')) { 
                    $task.project = $updates.Category 
                }
                if ($updates.ContainsKey('DueDate')) { 
                    $task.due_date = $updates.DueDate 
                }
                if ($updates.ContainsKey('Completed')) { 
                    $task.completed = $updates.Completed 
                }
                
                $task.updated_at = (Get-Date).ToString("o")
                
                Write-Log -Level Debug -Message "Task updated: $taskId"
                
                # Update in global data if available
                if ($global:Data -and $global:Data.Tasks) {
                    $globalIndex = -1
                    for ($i = 0; $i -lt $global:Data.Tasks.Count; $i++) {
                        if ($global:Data.Tasks[$i].id -eq $taskId) {
                            $globalIndex = $i
                            break
                        }
                    }
                    
                    if ($globalIndex -ne -1) {
                        $global:Data.Tasks[$globalIndex] = $task
                        
                        if (Get-Command Save-UnifiedData -ErrorAction SilentlyContinue) {
                            Save-UnifiedData
                            Write-Log -Level Debug -Message "Task data persisted"
                        }
                    }
                }
                
                # Announce state change using native PowerShell eventing
                New-Event -SourceIdentifier "TaskService" -EventIdentifier "Tasks.Changed" -MessageData @{
                    Action = "TaskUpdated"
                    TaskId = $taskId
                    Task = $task
                    Updates = $updates
                }
                
                Write-Log -Level Info -Message "Task updated successfully: $taskId"
                return $task
            }
        }
        
        # DeleteTask method
        Add-Member -InputObject $service -MemberType ScriptMethod -Name "DeleteTask" -Value {
            param(
                [Parameter(Mandatory = $true)]
                [string]$taskId
            )
            
            Invoke-WithErrorHandling -Component "TaskService.DeleteTask" -Context @{ TaskId = $taskId } -ScriptBlock {
                # Defensive validation
                if (-not $taskId) {
                    Write-Log -Level Warning -Message "DeleteTask: No TaskId provided"
                    return $false
                }
                
                Write-Log -Level Info -Message "Deleting task: $taskId"
                
                # Find and remove from internal array
                $originalCount = $this._tasks.Count
                $deletedTask = $null
                
                $newTasks = @()
                foreach ($task in $this._tasks) {
                    if ($task.id -eq $taskId) {
                        $deletedTask = $task
                    } else {
                        $newTasks += $task
                    }
                }
                
                $this._tasks = $newTasks
                
                if (-not $deletedTask) {
                    Write-Log -Level Warning -Message "DeleteTask: Task not found with ID $taskId"
                    return $false
                }
                
                Write-Log -Level Debug -Message "Task removed from internal array: $taskId"
                
                # Remove from global data if available
                if ($global:Data -and $global:Data.Tasks) {
                    $global:Data.Tasks = @($global:Data.Tasks | Where-Object { 
                        $_ -and $_.id -ne $taskId 
                    })
                    
                    if (Get-Command Save-UnifiedData -ErrorAction SilentlyContinue) {
                        Save-UnifiedData
                        Write-Log -Level Debug -Message "Task data persisted"
                    }
                }
                
                # Announce state change using native PowerShell eventing
                New-Event -SourceIdentifier "TaskService" -EventIdentifier "Tasks.Changed" -MessageData @{
                    Action = "TaskDeleted"
                    TaskId = $taskId
                    Task = $deletedTask
                }
                
                Write-Log -Level Info -Message "Task deleted successfully: $taskId"
                return $true
            }
        }
        
        # GetTasks method
        Add-Member -InputObject $service -MemberType ScriptMethod -Name "GetTasks" -Value {
            param(
                [switch]$ActiveOnly
            )
            
            Invoke-WithErrorHandling -Component "TaskService.GetTasks" -Context @{ ActiveOnly = $ActiveOnly } -ScriptBlock {
                Write-Log -Level Debug -Message "Getting tasks (ActiveOnly: $ActiveOnly)"
                
                $tasks = @($this._tasks)
                
                if ($ActiveOnly) {
                    $tasks = @($tasks | Where-Object { 
                        $_ -and $_.ContainsKey('completed') -and (-not $_.completed) 
                    })
                }
                
                Write-Log -Level Debug -Message "Returning $($tasks.Count) tasks"
                return $tasks
            }
        }
        
        # GetTaskById method
        Add-Member -InputObject $service -MemberType ScriptMethod -Name "GetTaskById" -Value {
            param(
                [Parameter(Mandatory = $true)]
                [string]$taskId
            )
            
            Invoke-WithErrorHandling -Component "TaskService.GetTaskById" -Context @{ TaskId = $taskId } -ScriptBlock {
                if (-not $taskId) {
                    Write-Log -Level Warning -Message "GetTaskById: No TaskId provided"
                    return $null
                }
                
                foreach ($task in $this._tasks) {
                    if ($task.id -eq $taskId) {
                        return $task
                    }
                }
                
                Write-Log -Level Debug -Message "GetTaskById: Task not found with ID $taskId"
                return $null
            }
        }
        
        # GetTasksForDisplay method (formatted for UI tables)
        Add-Member -InputObject $service -MemberType ScriptMethod -Name "GetTasksForDisplay" -Value {
            Invoke-WithErrorHandling -Component "TaskService.GetTasksForDisplay" -Context @{} -ScriptBlock {
                Write-Log -Level Debug -Message "Getting tasks for display"
                
                $tasksForTable = @()
                
                foreach ($task in $this._tasks) {
                    if (-not $task) { continue }
                    
                    # Safe property access with defaults
                    $taskItem = @{
                        Id = if ($task.ContainsKey('id')) { $task.id } else { [Guid]::NewGuid().ToString() }
                        Status = if ($task.ContainsKey('completed') -and $task.completed) { "✓" } else { "○" }
                        Priority = if ($task.ContainsKey('priority')) { $task.priority } else { "medium" }
                        Title = if ($task.ContainsKey('title')) { $task.title } else { "Untitled" }
                        Category = if ($task.ContainsKey('project')) { $task.project } else { "General" }
                        DueDate = "N/A"
                    }
                    
                    # Safe date parsing
                    if ($task.ContainsKey('due_date') -and $task.due_date) {
                        try {
                            $taskItem.DueDate = ([DateTime]$task.due_date).ToString("yyyy-MM-dd")
                        } catch {
                            $taskItem.DueDate = "Invalid"
                        }
                    }
                    
                    $tasksForTable += $taskItem
                }
                
                Write-Log -Level Debug -Message "Returning $($tasksForTable.Count) tasks for display"
                return @($tasksForTable)
            }
        }
        
        # GetStatistics method
        Add-Member -InputObject $service -MemberType ScriptMethod -Name "GetStatistics" -Value {
            Invoke-WithErrorHandling -Component "TaskService.GetStatistics" -Context @{} -ScriptBlock {
                Write-Log -Level Debug -Message "Calculating task statistics"
                
                $stats = @{
                    TotalTasks = $this._tasks.Count
                    ActiveTasks = 0
                    CompletedTasks = 0
                    HighPriorityTasks = 0
                    OverdueTasks = 0
                }
                
                $today = Get-Date
                
                foreach ($task in $this._tasks) {
                    if (-not $task) { continue }
                    
                    if ($task.ContainsKey('completed') -and $task.completed) {
                        $stats.CompletedTasks++
                    } else {
                        $stats.ActiveTasks++
                    }
                    
                    if ($task.ContainsKey('priority') -and $task.priority -eq 'high') {
                        $stats.HighPriorityTasks++
                    }
                    
                    if ($task.ContainsKey('due_date') -and $task.due_date -and -not $task.completed) {
                        try {
                            $dueDate = [DateTime]$task.due_date
                            if ($dueDate -lt $today) {
                                $stats.OverdueTasks++
                            }
                        } catch {
                            # Invalid date format
                        }
                    }
                }
                
                Write-Log -Level Debug -Message "Statistics calculated: Total=$($stats.TotalTasks), Active=$($stats.ActiveTasks)"
                return $stats
            }
        }
        
        # Initialize method - loads tasks from global data
        Add-Member -InputObject $service -MemberType ScriptMethod -Name "Initialize" -Value {
            Invoke-WithErrorHandling -Component "TaskService.Initialize" -Context @{} -ScriptBlock {
                if ($this._isInitialized) {
                    Write-Log -Level Debug -Message "TaskService already initialized"
                    return
                }
                
                Write-Log -Level Info -Message "Initializing TaskService data"
                
                # Load tasks from global data if available
                if ($global:Data -and $global:Data.ContainsKey('Tasks')) {
                    $this._tasks = @($global:Data.Tasks)
                    Write-Log -Level Info -Message "Loaded $($this._tasks.Count) tasks from global data"
                } else {
                    $this._tasks = @()
                    Write-Log -Level Info -Message "No existing tasks found, starting with empty list"
                }
                
                $this._isInitialized = $true
                
                # Announce initialization complete
                New-Event -SourceIdentifier "TaskService" -EventIdentifier "Service.Initialized" -MessageData @{
                    TaskCount = $this._tasks.Count
                }
            }
        }
        
        # Initialize the service
        $service.Initialize()
        
        Write-Log -Level Info -Message "Task Service initialized successfully"
        return $service
    }
}

# Export the initialization function
Export-ModuleMember -Function Initialize-TaskService