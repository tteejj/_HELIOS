# Data Manager Module
# Unified data persistence and CRUD operations with event integration

$script:Data = @{
    Projects = @{}
    Tasks = @()
    TimeEntries = @()
    ActiveTimers = @{}
    TodoTemplates = @{}
    Settings = @{
        DefaultView = "Dashboard"
        Theme = "Modern"
        AutoSave = $true
        BackupCount = 5
    }
}

$script:DataPath = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\pmc-data.json"
$script:BackupPath = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\backups"
$script:LastSaveTime = $null
$script:DataModified = $false

function global:Initialize-DataManager {
    <#
    .SYNOPSIS
    Initializes the data management system
    #>
    
    # Ensure data directory exists
    $dataDir = Split-Path $script:DataPath -Parent
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
    
    # Ensure backup directory exists
    if (-not (Test-Path $script:BackupPath)) {
        New-Item -ItemType Directory -Path $script:BackupPath -Force | Out-Null
    }
    
    # Initialize event handlers
    Initialize-DataEventHandlers
    
    # Make data globally accessible
    $global:Data = $script:Data
    
    Write-Verbose "Data manager initialized"
}

function global:Load-UnifiedData {
    <#
    .SYNOPSIS
    Loads data from the persistent storage
    #>
    
    if (Test-Path $script:DataPath) {
        try {
            $jsonContent = Get-Content $script:DataPath -Raw
            # Use -Depth to ensure deeply nested objects are properly deserialized
            $loadedData = $jsonContent | ConvertFrom-Json -AsHashtable -Depth 20
            
            # Merge with default structure to ensure all keys exist
            foreach ($key in $loadedData.Keys) {
                $script:Data[$key] = $loadedData[$key]
            }
            
            $script:LastSaveTime = (Get-Item $script:DataPath).LastWriteTime
            Write-Verbose "Data loaded from $script:DataPath"
            
            # Publish event
            Publish-Event -EventName "Data.Loaded" -Data @{ 
                Path = $script:DataPath
                ItemCount = @{
                    Projects = $script:Data.Projects.Count
                    Tasks = $script:Data.Tasks.Count
                    TimeEntries = $script:Data.TimeEntries.Count
                    ActiveTimers = $script:Data.ActiveTimers.Count
                }
            }
        } catch {
            Write-Warning "Failed to load data: $_"
            Write-Warning "Using default data structure"
        }
    } else {
        Write-Verbose "No existing data file found at $script:DataPath"
        # Initialize with sample data
        Initialize-SampleData
    }
    
    # Sync global variable
    $global:Data = $script:Data
}

function global:Save-UnifiedData {
    <#
    .SYNOPSIS
    Saves data to persistent storage with backup
    #>
    
    try {
        # Create backup if file exists
        if (Test-Path $script:DataPath) {
            $backupName = "pmc-data_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            $backupFile = Join-Path $script:BackupPath $backupName
            Copy-Item $script:DataPath $backupFile -Force
            
            # Clean old backups
            $backups = Get-ChildItem $script:BackupPath -Filter "pmc-data_*.json" | 
                       Sort-Object LastWriteTime -Descending
            
            if ($backups.Count -gt $script:Data.Settings.BackupCount) {
                $backups | Select-Object -Skip $script:Data.Settings.BackupCount | 
                          Remove-Item -Force
            }
        }
        
        # Save data with increased depth to handle nested objects
        # Use -Compress to reduce file size and -WarningAction to suppress depth warnings
        $jsonContent = $script:Data | ConvertTo-Json -Depth 20 -Compress -WarningAction SilentlyContinue
        Set-Content -Path $script:DataPath -Value $jsonContent -Force
        
        $script:LastSaveTime = Get-Date
        $script:DataModified = $false
        
        Write-Verbose "Data saved to $script:DataPath"
        
        # Publish event
        Publish-Event -EventName "Data.Saved" -Data @{ Path = $script:DataPath }
        
    } catch {
        Write-Error "Failed to save data: $_"
        Publish-Event -EventName "Data.SaveError" -Data @{ Error = $_.ToString() }
    }
}

function global:Initialize-DataEventHandlers {
    <#
    .SYNOPSIS
    Sets up event handlers for data operations
    #>
    
    # Time Entry Creation
    $null = Subscribe-Event -EventName "Data.Create.TimeEntry" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        try {
            # Validate required fields
            if (-not $data.Project) { throw "Project is required" }
            if (-not $data.Hours -or $data.Hours -le 0) { throw "Valid hours required" }
            
            $newEntry = @{
                Id = New-Guid
                ProjectKey = $data.Project
                Hours = [double]$data.Hours
                Description = if ($data.Description) { $data.Description } else { "" }
                Date = if ($data.Date) { $data.Date } else { (Get-Date).ToString("yyyy-MM-dd") }
                EnteredAt = (Get-Date).ToString("o")
                TaskId = $data.TaskId
            }
            
            $script:Data.TimeEntries += $newEntry
            $script:DataModified = $true
            
            if ($script:Data.Settings.AutoSave) {
                Save-UnifiedData
            }
            
            Publish-Event -EventName "Notification.Show" -Data @{ 
                Text = "Time entry saved: $($data.Hours)h for $($data.Project)"
                Type = "Success" 
            }
            
            Publish-Event -EventName "Data.TimeEntry.Created" -Data @{ Entry = $newEntry }
            
        } catch {
            Publish-Event -EventName "Notification.Show" -Data @{ 
                Text = "Failed to create time entry: $_"
                Type = "Error" 
            }
        }
    }
    
    # Project Creation
    $null = Subscribe-Event -EventName "Data.Create.Project" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        try {
            if (-not $data.Key) { throw "Project key is required" }
            if (-not $data.Name) { throw "Project name is required" }
            
            if ($script:Data.Projects.ContainsKey($data.Key)) {
                throw "Project key '$($data.Key)' already exists"
            }
            
            $newProject = @{
                Key = $data.Key
                Name = $data.Name
                Client = if ($data.Client) { $data.Client } else { "" }
                BillingType = if ($data.BillingType) { $data.BillingType } else { "NonBillable" }
                Rate = [double](if ($data.Rate) { $data.Rate } else { 0 })
                Budget = [double](if ($data.Budget) { $data.Budget } else { 0 })
                Id1 = if ($data.Id1) { $data.Id1 } else { "" }
                Id2 = if ($data.Id2) { $data.Id2 } else { "" }
                CreatedAt = (Get-Date).ToString("o")
                Active = $true
            }
            
            $script:Data.Projects[$data.Key] = $newProject
            $script:DataModified = $true
            
            if ($script:Data.Settings.AutoSave) {
                Save-UnifiedData
            }
            
            Publish-Event -EventName "Notification.Show" -Data @{ 
                Text = "Project created: $($data.Name)"
                Type = "Success" 
            }
            
            Publish-Event -EventName "Data.Project.Created" -Data @{ Project = $newProject }
            
        } catch {
            Publish-Event -EventName "Notification.Show" -Data @{ 
                Text = "Failed to create project: $_"
                Type = "Error" 
            }
        }
    }
    
    # Task Creation
    $null = Subscribe-Event -EventName "Data.Create.Task" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        try {
            if (-not $data.Description) { throw "Task description is required" }
            
            $newTask = @{
                Id = New-Guid
                Description = $data.Description
                ProjectKey = $data.ProjectKey
                Priority = if ($data.Priority) { $data.Priority } else { "Medium" }
                DueDate = $data.DueDate
                Tags = @(if ($data.Tags) { $data.Tags } else { @() })
                Completed = $false
                CreatedAt = (Get-Date).ToString("o")
                Progress = 0
            }
            
            $script:Data.Tasks += $newTask
            $script:DataModified = $true
            
            if ($script:Data.Settings.AutoSave) {
                Save-UnifiedData
            }
            
            Publish-Event -EventName "Notification.Show" -Data @{ 
                Text = "Task created: $($data.Description)"
                Type = "Success" 
            }
            
            Publish-Event -EventName "Data.Task.Created" -Data @{ Task = $newTask }
            
        } catch {
            Publish-Event -EventName "Notification.Show" -Data @{ 
                Text = "Failed to create task: $_"
                Type = "Error" 
            }
        }
    }
    
    # Timer Start
    $null = Subscribe-Event -EventName "Data.Timer.Start" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        try {
            if (-not $data.ProjectKey) { throw "Project is required to start timer" }
            
            $timerKey = "$($data.ProjectKey)_$(Get-Date -Format 'yyyyMMddHHmmss')"
            
            $newTimer = @{
                Key = $timerKey
                ProjectKey = $data.ProjectKey
                TaskId = $data.TaskId
                Description = if ($data.Description) { $data.Description } else { "" }
                StartTime = (Get-Date).ToString("o")
            }
            
            $script:Data.ActiveTimers[$timerKey] = $newTimer
            $script:DataModified = $true
            
            if ($script:Data.Settings.AutoSave) {
                Save-UnifiedData
            }
            
            $project = $script:Data.Projects[$data.ProjectKey]
            Publish-Event -EventName "Notification.Show" -Data @{ 
                Text = "Timer started for: $($project.Name)"
                Type = "Success" 
            }
            
            Publish-Event -EventName "Data.Timer.Started" -Data @{ Timer = $newTimer }
            
        } catch {
            Publish-Event -EventName "Notification.Show" -Data @{ 
                Text = "Failed to start timer: $_"
                Type = "Error" 
            }
        }
    }
    
    # Timer Stop
    $null = Subscribe-Event -EventName "Data.Timer.Stop" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        try {
            if (-not $data.TimerKey) { throw "Timer key is required" }
            
            if (-not $script:Data.ActiveTimers.ContainsKey($data.TimerKey)) {
                throw "Timer not found: $($data.TimerKey)"
            }
            
            $timer = $script:Data.ActiveTimers[$data.TimerKey]
            $startTime = [DateTime]$timer.StartTime
            $elapsed = (Get-Date) - $startTime
            
            # Create time entry from timer
            $timeEntry = @{
                Id = New-Guid
                ProjectKey = $timer.ProjectKey
                Hours = [Math]::Round($elapsed.TotalHours, 2)
                Description = $timer.Description
                Date = $startTime.ToString("yyyy-MM-dd")
                EnteredAt = (Get-Date).ToString("o")
                TaskId = $timer.TaskId
                FromTimer = $true
            }
            
            $script:Data.TimeEntries += $timeEntry
            $script:Data.ActiveTimers.Remove($data.TimerKey)
            $script:DataModified = $true
            
            if ($script:Data.Settings.AutoSave) {
                Save-UnifiedData
            }
            
            Publish-Event -EventName "Notification.Show" -Data @{ 
                Text = "Timer stopped: $([Math]::Round($elapsed.TotalHours, 2))h recorded"
                Type = "Success" 
            }
            
            Publish-Event -EventName "Data.Timer.Stopped" -Data @{ 
                Timer = $timer
                TimeEntry = $timeEntry 
            }
            
        } catch {
            Publish-Event -EventName "Notification.Show" -Data @{ 
                Text = "Failed to stop timer: $_"
                Type = "Error" 
            }
        }
    }
    
    # Stop All Timers
    $null = Subscribe-Event -EventName "Data.Timer.StopAll" -Handler {
        param($EventData)
        
        $timerKeys = @($script:Data.ActiveTimers.Keys)
        foreach ($timerKey in $timerKeys) {
            Publish-Event -EventName "Data.Timer.Stop" -Data @{ TimerKey = $timerKey }
        }
    }
}

function global:Get-ProjectOrTemplate {
    <#
    .SYNOPSIS
    Gets a project or template by key
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key
    )
    
    if ($script:Data.Projects.ContainsKey($Key)) {
        return $script:Data.Projects[$Key]
    } elseif ($script:Data.TodoTemplates.ContainsKey($Key)) {
        return $script:Data.TodoTemplates[$Key]
    } else {
        return @{ 
            Key = $Key
            Name = $Key
            Client = ""
            BillingType = "NonBillable"
            Rate = 0
        }
    }
}

function global:New-Guid {
    <#
    .SYNOPSIS
    Generates a new unique identifier
    #>
    return [Guid]::NewGuid().ToString()
}

function Initialize-SampleData {
    <#
    .SYNOPSIS
    Initializes sample data for first-time users
    #>
    
    # Sample projects
    $script:Data.Projects["INTERNAL"] = @{
        Key = "INTERNAL"
        Name = "Internal Work"
        Client = "Company"
        BillingType = "NonBillable"
        Rate = 0
        Budget = 0
        Active = $true
        CreatedAt = (Get-Date).ToString("o")
    }
    
    $script:Data.Projects["SAMPLE"] = @{
        Key = "SAMPLE"
        Name = "Sample Project"
        Client = "Sample Client"
        BillingType = "Billable"
        Rate = 100
        Budget = 10000
        Active = $true
        CreatedAt = (Get-Date).ToString("o")
    }
    
    # Sample todo templates
    $script:Data.TodoTemplates["PERSONAL"] = @{
        Key = "PERSONAL"
        Name = "Personal Tasks"
        Client = ""
        BillingType = "NonBillable"
        Rate = 0
        IsTemplate = $true
    }
    
    Write-Verbose "Sample data initialized"
}

# Helper function to get week dates
function global:Get-WeekDates {
    param([DateTime]$Date)
    
    $monday = $Date.AddDays(1 - [int]$Date.DayOfWeek)
    if ($Date.DayOfWeek -eq [DayOfWeek]::Sunday) {
        $monday = $monday.AddDays(-7)
    }
    
    return @(
        @{ Name = "Monday"; Date = $monday.Date }
        @{ Name = "Tuesday"; Date = $monday.AddDays(1).Date }
        @{ Name = "Wednesday"; Date = $monday.AddDays(2).Date }
        @{ Name = "Thursday"; Date = $monday.AddDays(3).Date }
        @{ Name = "Friday"; Date = $monday.AddDays(4).Date }
    )
}

function global:Get-WeekStart {
    param([DateTime]$Date)
    
    $monday = $Date.AddDays(1 - [int]$Date.DayOfWeek)
    if ($Date.DayOfWeek -eq [DayOfWeek]::Sunday) {
        $monday = $monday.AddDays(-7)
    }
    
    return $monday.Date
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-DataManager',
    'Load-UnifiedData',
    'Save-UnifiedData',
    'Initialize-DataEventHandlers',
    'Get-ProjectOrTemplate',
    'New-Guid',
    'Get-WeekDates',
    'Get-WeekStart'
) -Variable @('Data')