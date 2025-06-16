# Data Manager Module - Core data structures and persistence
# Manages all application data and responds to data-related events

#region Data Structures
$script:Data = @{
    Projects = @{
        "PROJ-001" = @{ 
            Name = "Website Redesign"
            Client = "Acme Corp"
            Status = "Active"
            CreatedDate = "2024-01-15"
        }
        "PROJ-002" = @{ 
            Name = "Mobile App Development"
            Client = "TechStart Inc"
            Status = "Active"
            CreatedDate = "2024-02-01"
        }
        "PROJ-003" = @{ 
            Name = "Database Migration"
            Client = "DataCo"
            Status = "Completed"
            CreatedDate = "2024-01-01"
        }
    }
    TimeEntries = @()
    Tasks = @()
    Settings = @{
        DefaultHoursPerDay = 8
        TimeFormat = "24h"
        Theme = "Default"
        AutoSave = $true
    }
}

$script:DataFilePath = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\data.json"

#endregion

#region Data Persistence Functions

function global:Load-UnifiedData {
    try {
        $dataDir = Split-Path $script:DataFilePath -Parent
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        }
        
        if (Test-Path $script:DataFilePath) {
            $jsonData = Get-Content $script:DataFilePath -Raw | ConvertFrom-Json
            
            # Convert PSCustomObject back to hashtables
            $script:Data.Projects = @{}
            if ($jsonData.Projects) {
                $jsonData.Projects.PSObject.Properties | ForEach-Object {
                    $script:Data.Projects[$_.Name] = @{
                        Name = $_.Value.Name
                        Client = $_.Value.Client
                        Status = $_.Value.Status
                        CreatedDate = $_.Value.CreatedDate
                    }
                }
            }
            
            $script:Data.TimeEntries = @()
            if ($jsonData.TimeEntries) {
                $script:Data.TimeEntries = $jsonData.TimeEntries | ForEach-Object {
                    @{
                        Id = $_.Id
                        ProjectKey = $_.ProjectKey
                        Hours = [double]$_.Hours
                        Description = $_.Description
                        Date = $_.Date
                    }
                }
            }
            
            $script:Data.Tasks = @()
            if ($jsonData.Tasks) {
                $script:Data.Tasks = $jsonData.Tasks | ForEach-Object {
                    @{
                        Id = $_.Id
                        Title = $_.Title
                        ProjectKey = $_.ProjectKey
                        Status = $_.Status
                        Priority = $_.Priority
                        DueDate = $_.DueDate
                    }
                }
            }
            
            if ($jsonData.Settings) {
                $script:Data.Settings = @{
                    DefaultHoursPerDay = $jsonData.Settings.DefaultHoursPerDay ?? 8
                    TimeFormat = $jsonData.Settings.TimeFormat ?? "24h"
                    Theme = $jsonData.Settings.Theme ?? "Default"
                    AutoSave = if ($null -ne $jsonData.Settings.AutoSave) { $jsonData.Settings.AutoSave } else { $true }
                }
            }
        }
        
        Publish-Event -EventName "Data.Loaded" -Data @{ 
            ProjectCount = $script:Data.Projects.Count
            TimeEntryCount = $script:Data.TimeEntries.Count
            TaskCount = $script:Data.Tasks.Count
        }
        
        return $true
    }
    catch {
        Write-Warning "Failed to load data: $_"
        Publish-Event -EventName "Data.LoadError" -Data @{ Error = $_.ToString() }
        return $false
    }
}

function global:Save-UnifiedData {
    try {
        $dataDir = Split-Path $script:DataFilePath -Parent
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        }
        
        $jsonData = $script:Data | ConvertTo-Json -Depth 10
        Set-Content -Path $script:DataFilePath -Value $jsonData -Encoding UTF8
        
        Publish-Event -EventName "Data.Saved" -Data @{ 
            FilePath = $script:DataFilePath
            Size = (Get-Item $script:DataFilePath).Length
        }
        
        return $true
    }
    catch {
        Write-Warning "Failed to save data: $_"
        Publish-Event -EventName "Data.SaveError" -Data @{ Error = $_.ToString() }
        return $false
    }
}

#endregion

#region Data Access Functions

function global:Get-ProjectById {
    param([string]$ProjectId)
    return $script:Data.Projects[$ProjectId]
}

function global:Get-AllProjects {
    return $script:Data.Projects
}

function global:Get-ActiveProjects {
    return $script:Data.Projects.GetEnumerator() | 
        Where-Object { $_.Value.Status -eq "Active" } | 
        ForEach-Object { $_.Value + @{ Key = $_.Key } }
}

function global:Get-TimeEntriesByProject {
    param([string]$ProjectId)
    return $script:Data.TimeEntries | Where-Object { $_.ProjectKey -eq $ProjectId }
}

function global:Get-TimeEntriesByDate {
    param([datetime]$StartDate, [datetime]$EndDate)
    $start = $StartDate.ToString("yyyy-MM-dd")
    $end = $EndDate.ToString("yyyy-MM-dd")
    return $script:Data.TimeEntries | Where-Object { 
        $_.Date -ge $start -and $_.Date -le $end 
    }
}

function global:Get-TasksByProject {
    param([string]$ProjectId)
    return $script:Data.Tasks | Where-Object { $_.ProjectKey -eq $ProjectId }
}

function global:Get-PendingTasks {
    return $script:Data.Tasks | Where-Object { $_.Status -ne "Completed" }
}

#endregion

#region Data Modification Functions

function global:Add-Project {
    param(
        [string]$Name,
        [string]$Client,
        [string]$Status = "Active"
    )
    
    $projectId = "PROJ-" + (Get-Random -Minimum 1000 -Maximum 9999)
    while ($script:Data.Projects.ContainsKey($projectId)) {
        $projectId = "PROJ-" + (Get-Random -Minimum 1000 -Maximum 9999)
    }
    
    $script:Data.Projects[$projectId] = @{
        Name = $Name
        Client = $Client
        Status = $Status
        CreatedDate = (Get-Date).ToString("yyyy-MM-dd")
    }
    
    if ($script:Data.Settings.AutoSave) { Save-UnifiedData }
    
    Publish-Event -EventName "Data.Project.Created" -Data @{ 
        ProjectId = $projectId
        Project = $script:Data.Projects[$projectId]
    }
    
    return $projectId
}

function global:Add-TimeEntry {
    param(
        [string]$ProjectKey,
        [double]$Hours,
        [string]$Description,
        [string]$Date = (Get-Date).ToString("yyyy-MM-dd")
    )
    
    $entry = @{
        Id = "TE-" + (Get-Random -Minimum 100000 -Maximum 999999)
        ProjectKey = $ProjectKey
        Hours = $Hours
        Description = $Description
        Date = $Date
    }
    
    $script:Data.TimeEntries += $entry
    
    if ($script:Data.Settings.AutoSave) { Save-UnifiedData }
    
    Publish-Event -EventName "Data.TimeEntry.Created" -Data $entry
    
    return $entry.Id
}

function global:Add-Task {
    param(
        [string]$Title,
        [string]$ProjectKey,
        [string]$Priority = "Medium",
        [string]$DueDate = $null
    )
    
    $task = @{
        Id = "TASK-" + (Get-Random -Minimum 100000 -Maximum 999999)
        Title = $Title
        ProjectKey = $ProjectKey
        Status = "Pending"
        Priority = $Priority
        DueDate = $DueDate
    }
    
    $script:Data.Tasks += $task
    
    if ($script:Data.Settings.AutoSave) { Save-UnifiedData }
    
    Publish-Event -EventName "Data.Task.Created" -Data $task
    
    return $task.Id
}

function global:Update-TaskStatus {
    param(
        [string]$TaskId,
        [string]$NewStatus
    )
    
    $task = $script:Data.Tasks | Where-Object { $_.Id -eq $TaskId } | Select-Object -First 1
    if ($task) {
        $task.Status = $NewStatus
        
        if ($script:Data.Settings.AutoSave) { Save-UnifiedData }
        
        Publish-Event -EventName "Data.Task.Updated" -Data @{
            TaskId = $TaskId
            NewStatus = $NewStatus
        }
        
        return $true
    }
    return $false
}

#endregion

#region Data Event Handlers

function global:Initialize-DataEventHandlers {
    # Handle time entry creation requests
    Subscribe-Event -EventName "Data.Create.TimeEntry" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        # Validation
        if (-not $data.Project -or -not $data.Hours -or ([double]$data.Hours) -le 0) {
            Publish-Event -EventName "Notification.Show" -Data @{ 
                Text = "Project and valid hours are required."
                Type = "Error" 
            }
            return
        }
        
        # Check if project exists
        if (-not $script:Data.Projects.ContainsKey($data.Project)) {
            Publish-Event -EventName "Notification.Show" -Data @{ 
                Text = "Invalid project selected."
                Type = "Error" 
            }
            return
        }
        
        # Create time entry
        $entryId = Add-TimeEntry -ProjectKey $data.Project -Hours ([double]$data.Hours) -Description $data.Description
        
        # Notify success
        Publish-Event -EventName "Notification.Show" -Data @{ 
            Text = "Time entry saved successfully!"
            Type = "Success" 
        }
        
        # Navigate back
        Publish-Event -EventName "Navigation.PopScreen"
    }
    
    # Handle project creation requests
    Subscribe-Event -EventName "Data.Create.Project" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        if (-not $data.Name -or -not $data.Client) {
            Publish-Event -EventName "Notification.Show" -Data @{ 
                Text = "Project name and client are required."
                Type = "Error" 
            }
            return
        }
        
        $projectId = Add-Project -Name $data.Name -Client $data.Client -Status ($data.Status ?? "Active")
        
        Publish-Event -EventName "Notification.Show" -Data @{ 
            Text = "Project created successfully!"
            Type = "Success" 
        }
        
        Publish-Event -EventName "Navigation.PopScreen"
    }
    
    # Handle task creation requests
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
        
        $taskId = Add-Task -Title $data.Title -ProjectKey $data.ProjectKey `
            -Priority ($data.Priority ?? "Medium") -DueDate $data.DueDate
        
        Publish-Event -EventName "Notification.Show" -Data @{ 
            Text = "Task created successfully!"
            Type = "Success" 
        }
        
        Publish-Event -EventName "Navigation.PopScreen"
    }
    
    # Handle settings updates
    Subscribe-Event -EventName "Data.Update.Settings" -Handler {
        param($EventData)
        $updates = $EventData.Data
        
        foreach ($key in $updates.Keys) {
            if ($script:Data.Settings.ContainsKey($key)) {
                $script:Data.Settings[$key] = $updates[$key]
            }
        }
        
        Save-UnifiedData
        
        Publish-Event -EventName "Notification.Show" -Data @{ 
            Text = "Settings updated successfully!"
            Type = "Success" 
        }
    }
    
    # Auto-save on data changes
    Subscribe-Event -EventName "Data.Changed" -Handler {
        if ($script:Data.Settings.AutoSave) {
            Save-UnifiedData
        }
    }
}

#endregion

#region Data Export Functions

function global:Export-TimeReport {
    param(
        [datetime]$StartDate,
        [datetime]$EndDate,
        [string]$OutputPath
    )
    
    $entries = Get-TimeEntriesByDate -StartDate $StartDate -EndDate $EndDate
    
    $report = @{
        GeneratedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Period = @{
            Start = $StartDate.ToString("yyyy-MM-dd")
            End = $EndDate.ToString("yyyy-MM-dd")
        }
        TotalHours = ($entries | Measure-Object -Property Hours -Sum).Sum
        EntriesByProject = @{}
        DetailedEntries = $entries
    }
    
    # Group by project
    $entries | Group-Object ProjectKey | ForEach-Object {
        $project = Get-ProjectById -ProjectId $_.Name
        $report.EntriesByProject[$_.Name] = @{
            ProjectName = $project.Name
            TotalHours = ($_.Group | Measure-Object -Property Hours -Sum).Sum
            EntryCount = $_.Count
        }
    }
    
    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
    
    Publish-Event -EventName "Data.Report.Exported" -Data @{ 
        Path = $OutputPath
        Type = "TimeReport"
    }
    
    return $report
}

#endregion

Export-ModuleMember -Function @(
    'Load-UnifiedData', 'Save-UnifiedData',
    'Get-ProjectById', 'Get-AllProjects', 'Get-ActiveProjects',
    'Get-TimeEntriesByProject', 'Get-TimeEntriesByDate',
    'Get-TasksByProject', 'Get-PendingTasks',
    'Add-Project', 'Add-TimeEntry', 'Add-Task',
    'Update-TaskStatus',
    'Initialize-DataEventHandlers',
    'Export-TimeReport'
)
