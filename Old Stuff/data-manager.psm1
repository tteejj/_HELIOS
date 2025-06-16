# Data Manager Module - Core data structures and persistence
# Handles all data operations and listens for events to perform CRUD operations

#region Data Structures
$script:Data = @{
    Projects = @{}
    Tasks = @()
    TimeEntries = @()
    ActiveTimers = @{}  # Changed to support multiple timers
    Settings = @{}
    LastSaved = $null
    DataPath = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal"
}
#endregion

#region Data Persistence
function global:Load-UnifiedData {
    try {
        $dataFile = Join-Path $script:Data.DataPath "pmc-data.json"
        
        # Create data directory if it doesn't exist
        if (-not (Test-Path $script:Data.DataPath)) {
            New-Item -ItemType Directory -Path $script:Data.DataPath -Force | Out-Null
        }
        
        if (Test-Path $dataFile) {
            $jsonData = Get-Content $dataFile -Raw | ConvertFrom-Json
            
            # Convert projects back to hashtable
            $script:Data.Projects = @{}
            if ($jsonData.Projects) {
                $jsonData.Projects.PSObject.Properties | ForEach-Object {
                    $script:Data.Projects[$_.Name] = $_.Value
                }
            }
            
            # Load arrays
            $script:Data.Tasks = @($jsonData.Tasks)
            $script:Data.TimeEntries = @($jsonData.TimeEntries)
            
            # Load active timers (support both old single timer and new multiple timers)
            if ($jsonData.ActiveTimers) {
                $script:Data.ActiveTimers = @{}
                $jsonData.ActiveTimers.PSObject.Properties | ForEach-Object {
                    $script:Data.ActiveTimers[$_.Name] = $_.Value
                }
            } elseif ($jsonData.ActiveTimer) {
                # Migrate old single timer to new format
                $script:Data.ActiveTimers = @{
                    "T001" = $jsonData.ActiveTimer
                }
            } else {
                $script:Data.ActiveTimers = @{}
            }
            
            # Load settings
            $script:Data.Settings = @{}
            if ($jsonData.Settings) {
                $jsonData.Settings.PSObject.Properties | ForEach-Object {
                    $script:Data.Settings[$_.Name] = $_.Value
                }
            }
        } else {
            # Initialize with default data
            Initialize-DefaultData
        }
        
        Publish-Event -EventName "Data.Loaded" -Data $script:Data
    }
    catch {
        Write-Warning "Failed to load data: $_"
        Initialize-DefaultData
    }
}

function global:Save-UnifiedData {
    try {
        $dataFile = Join-Path $script:Data.DataPath "pmc-data.json"
        
        # Create backup
        if (Test-Path $dataFile) {
            $backupFile = Join-Path $script:Data.DataPath "pmc-data.backup.json"
            Copy-Item $dataFile $backupFile -Force
        }
        
        $script:Data.LastSaved = Get-Date
        $script:Data | ConvertTo-Json -Depth 10 | Set-Content $dataFile
        
        Publish-Event -EventName "Data.Saved" -Data @{ 
            Path = $dataFile
            Timestamp = $script:Data.LastSaved 
        }
    }
    catch {
        Write-Warning "Failed to save data: $_"
        Publish-Event -EventName "Notification.Show" -Data @{
            Text = "Failed to save data: $_"
            Type = "Error"
        }
    }
}

function Initialize-DefaultData {
    $script:Data = @{
        Projects = @{
            "PROJ001" = @{
                Id = "PROJ001"
                Name = "Default Project"
                Description = "Initial project for time tracking"
                Color = "Blue"
                CreatedDate = (Get-Date).ToString("yyyy-MM-dd")
                IsActive = $true
            }
            "PROJ002" = @{
                Id = "PROJ002"
                Name = "Personal Tasks"
                Description = "Personal time and tasks"
                Color = "Green"
                CreatedDate = (Get-Date).ToString("yyyy-MM-dd")
                IsActive = $true
            }
        }
        Tasks = @(
            @{
                Id = "TASK001"
                ProjectKey = "PROJ001"
                Title = "Initial Setup"
                Description = "Set up the PMC Terminal environment"
                Status = "Open"
                Priority = "High"
                CreatedDate = (Get-Date).ToString("yyyy-MM-dd")
            }
        )
        TimeEntries = @()
        ActiveTimers = @{}
        Settings = @{
            Theme = "Default"
            AutoSaveInterval = 300
            TimeFormat = "24h"
            WeekStartsOn = "Monday"
        }
        LastSaved = $null
        DataPath = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal"
    }
}
#endregion

#region Data Access Functions
function global:Get-ProjectOrTemplate {
    param([string]$ProjectKey)
    
    if ($script:Data.Projects.ContainsKey($ProjectKey)) {
        return $script:Data.Projects[$ProjectKey]
    }
    
    # Return template if not found
    return @{
        Id = $ProjectKey
        Name = "Unknown Project"
        Description = ""
        Color = "Gray"
        CreatedDate = (Get-Date).ToString("yyyy-MM-dd")
        IsActive = $true
    }
}

function global:Get-TasksByProject {
    param([string]$ProjectKey)
    return @($script:Data.Tasks | Where-Object { $_.ProjectKey -eq $ProjectKey })
}

function global:Get-TimeEntriesByDateRange {
    param(
        [DateTime]$StartDate,
        [DateTime]$EndDate
    )
    
    return @($script:Data.TimeEntries | Where-Object {
        $entryDate = [DateTime]::Parse($_.Date)
        $entryDate -ge $StartDate -and $entryDate -le $EndDate
    })
}

function global:Get-ActiveProjects {
    return @($script:Data.Projects.GetEnumerator() | 
        Where-Object { $_.Value.IsActive } | 
        ForEach-Object { $_.Value })
}

function global:Get-ProjectById {
    param([string]$ProjectId)
    return $script:Data.Projects[$ProjectId]
}

function global:Add-TimeEntry {
    param(
        [string]$ProjectKey,
        [double]$Hours,
        [string]$Description = ""
    )
    
    $newEntry = @{
        Id = "TE-$(Get-Random -Maximum 999999)"
        ProjectKey = $ProjectKey
        Hours = $Hours
        Description = $Description
        Date = (Get-Date).ToString("yyyy-MM-dd")
        CreatedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $script:Data.TimeEntries += $newEntry
    Save-UnifiedData
    
    return $newEntry
}

function global:Add-Task {
    param(
        [string]$Title,
        [string]$ProjectKey = $null,
        [string]$Priority = "Medium",
        [string]$DueDate = $null
    )
    
    $newTask = @{
        Id = "TASK$(Get-Random -Minimum 1000 -Maximum 9999)"
        ProjectKey = $ProjectKey
        Description = $Title  # Note: using Description field for the task title
        Priority = $Priority
        DueDate = $DueDate
        Progress = 0
        Completed = $false
        CompletedDate = $null
        CreatedDate = (Get-Date).ToString("yyyy-MM-dd")
    }
    
    $script:Data.Tasks += $newTask
    Save-UnifiedData
    
    Publish-Event -EventName "Task.Created" -Data $newTask
    return $newTask
}
#endregion

#region Data Event Handlers
function global:Initialize-DataEventHandlers {
    # Time Entry Creation
    Subscribe-Event -EventName "Data.Create.TimeEntry" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        # Validation
        if (-not $data.Project -or -not $data.Hours) {
            Publish-Event -EventName "Notification.Show" -Data @{
                Text = "Project and hours are required."
                Type = "Error"
            }
            return
        }
        
        try {
            $hours = [double]$data.Hours
            if ($hours -le 0 -or $hours -gt 24) {
                Publish-Event -EventName "Notification.Show" -Data @{
                    Text = "Hours must be between 0 and 24."
                    Type = "Error"
                }
                return
            }
        }
        catch {
            Publish-Event -EventName "Notification.Show" -Data @{
                Text = "Invalid hours format."
                Type = "Error"
            }
            return
        }
        
        # Create entry
        $newEntry = @{
            Id = "TE-$(Get-Random -Maximum 999999)"
            ProjectKey = $data.Project
            Hours = [double]$data.Hours
            Description = $data.Description ?? ""
            Date = $data.Date ?? (Get-Date).ToString("yyyy-MM-dd")
            CreatedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        $script:Data.TimeEntries += $newEntry
        Save-UnifiedData
        
        Publish-Event -EventName "Data.TimeEntry.Created" -Data $newEntry
        Publish-Event -EventName "Notification.Show" -Data @{
            Text = "Time entry saved: $($hours) hours"
            Type = "Success"
        }
        Publish-Event -EventName "Navigation.PopScreen"
    }
    
    # Project Creation
    Subscribe-Event -EventName "Data.Create.Project" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        if (-not $data.Name) {
            Publish-Event -EventName "Notification.Show" -Data @{
                Text = "Project name is required."
                Type = "Error"
            }
            return
        }
        
        $projectId = "PROJ$(Get-Random -Minimum 1000 -Maximum 9999)"
        $newProject = @{
            Id = $projectId
            Name = $data.Name
            Description = $data.Description ?? ""
            Color = $data.Color ?? "Blue"
            CreatedDate = (Get-Date).ToString("yyyy-MM-dd")
            IsActive = $true
        }
        
        $script:Data.Projects[$projectId] = $newProject
        Save-UnifiedData
        
        Publish-Event -EventName "Data.Project.Created" -Data $newProject
        Publish-Event -EventName "Notification.Show" -Data @{
            Text = "Project created: $($data.Name)"
            Type = "Success"
        }
    }
    
    # Task Creation
    Subscribe-Event -EventName "Data.Create.Task" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        if (-not $data.Title -or -not $data.ProjectKey) {
            Publish-Event -EventName "Notification.Show" -Data @{
                Text = "Task title and project are required."
                Type = "Error"
            }
            return
        }
        
        $newTask = @{
            Id = "TASK$(Get-Random -Minimum 1000 -Maximum 9999)"
            ProjectKey = $data.ProjectKey
            Title = $data.Title
            Description = $data.Description ?? ""
            Status = "Open"
            Priority = $data.Priority ?? "Medium"
            CreatedDate = (Get-Date).ToString("yyyy-MM-dd")
        }
        
        $script:Data.Tasks += $newTask
        Save-UnifiedData
        
        Publish-Event -EventName "Data.Task.Created" -Data $newTask
        Publish-Event -EventName "Notification.Show" -Data @{
            Text = "Task created: $($data.Title)"
            Type = "Success"
        }
    }
    
    # Timer Stop Handler - needed for timer management
    Subscribe-Event -EventName "Timer.Stop" -Handler {
        param($EventData)
        $timerKey = $EventData.Data.Key
        
        if ($script:Data.ActiveTimers.ContainsKey($timerKey)) {
            $timer = $script:Data.ActiveTimers[$timerKey]
            $startTime = [DateTime]$timer.StartTime
            $elapsed = [DateTime]::Now - $startTime
            $hours = [Math]::Round($elapsed.TotalHours, 2)
            
            # Create time entry
            $newEntry = @{
                Id = "TE-$(Get-Random -Maximum 999999)"
                ProjectKey = $timer.ProjectKey
                Hours = $hours
                Description = $timer.Description
                Date = (Get-Date).ToString("yyyy-MM-dd")
                CreatedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
            
            $script:Data.TimeEntries += $newEntry
            
            # Remove timer
            $script:Data.ActiveTimers.Remove($timerKey)
            Save-UnifiedData
            
            Publish-Event -EventName "Notification.Show" -Data @{
                Text = "Timer stopped: $hours hours logged"
                Type = "Success"
            }
        }
    }
    
    # Data Update
    Subscribe-Event -EventName "Data.Update" -Handler {
        param($EventData)
        Save-UnifiedData
        Publish-Event -EventName "Data.Changed" -Data $EventData.Data
    }
}
#endregion

Export-ModuleMember -Function @(
    'Load-UnifiedData', 'Save-UnifiedData', 'Initialize-DataEventHandlers',
    'Get-ProjectOrTemplate', 'Get-TasksByProject', 'Get-TimeEntriesByDateRange',
    'Get-ActiveProjects', 'Get-ProjectById', 'Add-TimeEntry', 'Add-Task'
)
