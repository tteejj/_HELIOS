

#Requires -Modules @{ ModuleName = "PTUI"; ModuleVersion = "1.0" }
using module ptui

# Unified Productivity Suite v5.0 - PTUI Edition
# Ported to use the PowerShell Terminal User Interface (ptui) module.
#
# HOW TO RUN:
# 1. Install the ptui module: Install-Module -Name ptui -Scope CurrentUser
# 2. Save this code as a single file (e.g., pmc.ps1).
# 3. Run the file from your PowerShell terminal: ./pmc.ps1

#region #################### CORE LOGIC MODULE ####################
# This section contains the original application's business logic.
# All user interaction functions (Read-Host, Write-Host) have been
# removed or replaced by parameterized functions that the UI can call.
# All functions are defined with `global:` scope to be accessible by the UI layer.

#region Data Model Initialization

# Initialize the unified data model. This $script:Data structure is the source of truth.
function global:Get-DefaultSettings {
    return @{
        # Time Tracker Settings
        DefaultRate = 100.0; Currency = "USD"; HoursPerDay = 8.0; DaysPerWeek = 5
        TimeTrackerTemplates = @{
            "ADMIN" = @{ Name = "Administrative Tasks"; Id1 = "100"; Id2 = "ADM"; Client = "Internal"; Department = "Operations"; BillingType = "Non-Billable"; Status = "Active"; Budget = 0.0; Rate = 0.0; Notes = "General administrative tasks" }
            "MEETING" = @{ Name = "Meetings & Calls"; Id1 = "101"; Id2 = "MTG"; Client = "Internal"; Department = "Various"; BillingType = "Non-Billable"; Status = "Active"; Budget = 0.0; Rate = 0.0; Notes = "Team meetings and calls" }
            "TRAINING" = @{ Name = "Training & Learning"; Id1 = "102"; Id2 = "TRN"; Client = "Internal"; Department = "HR"; BillingType = "Non-Billable"; Status = "Active"; Budget = 0.0; Rate = 0.0; Notes = "Professional development" }
            "BREAK" = @{ Name = "Breaks & Personal"; Id1 = "103"; Id2 = "BRK"; Client = "Internal"; Department = "Personal"; BillingType = "Non-Billable"; Status = "Active"; Budget = 0.0; Rate = 0.0; Notes = "Breaks and personal time" }
        }
        # Todo Tracker Settings
        DefaultPriority = "Medium"; DefaultCategory = "General"; ShowCompletedDays = 7; EnableTimeTracking = $true; AutoArchiveDays = 30
        # Command Snippets Settings
        CommandSnippets = @{ EnableHotkeys = $true; AutoCopyToClipboard = $true; ShowInTaskList = $false; DefaultCategory = "Commands"; RecentLimit = 10 }
        # Excel Integration Settings
        ExcelFormConfig = @{ WorksheetName = "Project Info"; StandardFields = @{ "Id1" = @{ LabelCell = "A5"; ValueCell = "B5"; Label = "Project ID"; Field = "Id1" }; "Id2" = @{ LabelCell = "A6"; ValueCell = "B6"; Label = "Task Code"; Field = "Id2" }; "Name" = @{ LabelCell = "A7"; ValueCell = "B7"; Label = "Project Name"; Field = "Name" }; "FullName" = @{ LabelCell = "A8"; ValueCell = "B8"; Label = "Full Description"; Field = "FullName" }; "AssignedDate" = @{ LabelCell = "A9"; ValueCell = "B9"; Label = "Start Date"; Field = "AssignedDate" }; "DueDate" = @{ LabelCell = "A10"; ValueCell = "B10"; Label = "End Date"; Field = "DueDate" }; "Manager" = @{ LabelCell = "A11"; ValueCell = "B11"; Label = "Project Manager"; Field = "Manager" }; "Budget" = @{ LabelCell = "A12"; ValueCell = "B12"; Label = "Budget"; Field = "Budget" }; "Status" = @{ LabelCell = "A13"; ValueCell = "B13"; Label = "Status"; Field = "Status" }; "Priority" = @{ LabelCell = "A14"; ValueCell = "B14"; Label = "Priority"; Field = "Priority" }; "Department" = @{ LabelCell = "A15"; ValueCell = "B15"; Label = "Department"; Field = "Department" }; "Client" = @{ LabelCell = "A16"; ValueCell = "B16"; Label = "Client"; Field = "Client" }; "BillingType" = @{ LabelCell = "A17"; ValueCell = "B17"; Label = "Billing Type"; Field = "BillingType" }; "Rate" = @{ LabelCell = "A18"; ValueCell = "B18"; Label = "Hourly Rate"; Field = "Rate" } } }
        # UI Theme (Legacy - Not used by PTUI, kept for data integrity)
        Theme = @{ Header = "Cyan"; Success = "Green"; Warning = "Yellow"; Error = "Red"; Info = "Blue"; Accent = "Magenta"; Subtle = "DarkGray" }
        QuickActionTipShown = $false
    }
}
#region Helper and Utility Logic
$script:DataPath = Join-Path $env:USERPROFILE ".ProductivitySuite"
$script:UnifiedDataFile = Join-Path $script:DataPath "unified_data.json"
$script:BackupPath = Join-Path $script:DataPath "backups"
@($script:DataPath, $script:BackupPath) | ForEach-Object { if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }}

function global:ConvertFrom-JsonToHashtable {
    param([string]$JsonString)
    function Convert-PSObjectToHashtable {
        param($InputObject)
        if ($null -eq $InputObject) { return $null }
        if ($InputObject -is [PSCustomObject]) {
            $hashtable = @{}; $InputObject.PSObject.Properties | ForEach-Object { $hashtable[$_.Name] = Convert-PSObjectToHashtable $_.Value }; return $hashtable
        } elseif ($InputObject -is [array]) { return @($InputObject | ForEach-Object { Convert-PSObjectToHashtable $_ }) }
        else { return $InputObject }
    }
    return Convert-PSObjectToHashtable ($JsonString | ConvertFrom-Json)
}

function global:Load-UnifiedData {
    try {
        if (Test-Path $script:UnifiedDataFile) {
            $jsonContent = Get-Content $script:UnifiedDataFile -Raw
            $loadedData = ConvertFrom-JsonToHashtable $jsonContent
            if (-not $script:Data) { $script:Data = @{ Settings = (Get-DefaultSettings) } }
            $defaultSettings = Get-DefaultSettings
            # Deep merge logic to ensure data structure is always valid
            foreach ($topLevelKey in $loadedData.Keys) {
                if ($topLevelKey -eq "Settings") {
                    if ($loadedData.Settings -is [hashtable]) {
                        foreach ($settingKey in $defaultSettings.Keys) {
                            if ($loadedData.Settings.ContainsKey($settingKey)) {
                                if ($defaultSettings[$settingKey] -is [hashtable] -and $loadedData.Settings[$settingKey] -is [hashtable]) {
                                    # Merge nested settings hashtables
                                    foreach($subKey in $defaultSettings[$settingKey].Keys) {
                                        if($loadedData.Settings[$settingKey].ContainsKey($subKey)){
                                            $script:Data.Settings[$settingKey][$subKey] = $loadedData.Settings[$settingKey][$subKey]
                                        }
                                    }
                                } else {
                                    $script:Data.Settings[$settingKey] = $loadedData.Settings[$settingKey]
                                }
                            }
                        }
                    }
                } elseif ($script:Data.ContainsKey($topLevelKey)) {
                    $script:Data[$topLevelKey] = $loadedData[$topLevelKey]
                }
            }
            if ($script:Data.CurrentWeek -is [string]) { $script:Data.CurrentWeek = [DateTime]::Parse($script:Data.CurrentWeek) }
             elseif ($null -eq $script:Data.CurrentWeek) { $script:Data.CurrentWeek = Get-WeekStart (Get-Date) }
        }
    } catch {
        # On error, we just proceed with the default $script:Data
        Write-Warning "Could not load data file. Starting with default data. Error: $_"
    }
}

function global:Save-UnifiedData {
    try {
        if ((Get-Random -Maximum 10) -eq 0 -or -not (Test-Path $script:UnifiedDataFile)) { Backup-Data -Silent }
        $script:Data | ConvertTo-Json -Depth 10 | Set-Content $script:UnifiedDataFile -Encoding UTF8
    } catch { Write-Error "FATAL: Could not save data to $script:UnifiedDataFile. Error: $_" }
}

function global:Backup-Data { param([switch]$Silent)
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"; $backupFile = Join-Path $script:BackupPath "backup_$timestamp.json"
    try {
        $script:Data | ConvertTo-Json -Depth 10 | Set-Content $backupFile -Encoding UTF8
        if (-not $Silent) { $script:App.ShowMessageBox("Backup", "Backup created: $backupFile") }
        Get-ChildItem $script:BackupPath -Filter "backup_*.json" | Sort-Object CreationTime -Descending | Select-Object -Skip 30 | Remove-Item -Force
    } catch { if (-not $Silent) { $script:App.ShowMessageBox("Backup Failed", "Error: $_") } }
}

function global:New-TodoId { return [System.Guid]::NewGuid().ToString().Substring(0, 8) }
function global:Format-Id2 { param([string]$Id2) $id2 = if([string]::IsNullOrEmpty($Id2)){""}else{$Id2}; if ($id2.Length -gt 9) { $id2 = $id2.Substring(0, 9) }; return "V$('0' * [Math]::Max(0, 7 - $id2.Length))$id2" + "S" }
function global:Get-WeekStart { param([DateTime]$Date = (Get-Date)); $d = [int]$Date.DayOfWeek; if ($d -eq 0) { $d = 7 }; return Get-Date $Date.AddDays(1 - $d) -Hour 0 -Minute 0 -Second 0 }
function global:Get-WeekDates { param([DateTime]$WeekStartDate); return @(0..4 | ForEach-Object { $WeekStartDate.AddDays($_) }) }
function global:Format-TodoDate { param($DateString); if ([string]::IsNullOrEmpty($DateString)) {return ""}; try{$d=[datetime]::Parse($DateString);$t=[datetime]::Today;$diff=($d.Date-$t).Days;$ds=$d.ToString("MMM dd");if($diff -eq 0){return "Today"}elseif($diff -eq 1){return "Tomorrow"}elseif($diff -eq -1){return "Yesterday"}else{return $ds}}catch{return $DateString}}
function global:Get-TaskStatus { param($Task); if($Task.Completed){return "Completed"};if($Task.Progress -ge 100){return "Done"};if($Task.Progress -gt 0){return "In Progress"};if(-not [string]::IsNullOrEmpty($Task.DueDate)){try{$dd=[datetime]::Parse($Task.DueDate).Date;$td=[datetime]::Today.Date;$du=($dd-$td).Days;if($du -lt 0){return "Overdue"}if($du -eq 0){return "Due Today"}if($du -gt 0 -and $du -le 3){return "Due Soon"}}catch{}};if(-not[string]::IsNullOrEmpty($Task.StartDate)){try{$sd=[datetime]::Parse($Task.StartDate).Date;$td=[datetime]::Today.Date;if($sd -gt $td){return "Scheduled"}}catch{}};return "Pending"}
function global:Get-PriorityColor { param($Priority); switch ($Priority) {"Critical" {"Red"}; "High" {"DarkRed"}; "Medium" {"Yellow"}; "Low" {"Green"}; default {"Gray"}} }
#endregion

#endregion
# Define the $script:Data structure with defaults.
$script:Data = @{
    Projects = @{}; Tasks = @(); TimeEntries = @(); ActiveTimers = @{}; ArchivedTasks = @()
    ExcelCopyJobs = @{}; CurrentWeek = (Get-WeekStart (Get-Date)); Settings = (Get-DefaultSettings)
}
#endregion





#region Project Management Logic
function global:Get-ProjectOrTemplate {
    param([string]$Key)
    if ([string]::IsNullOrEmpty($Key)) { return $null }
    if ($script:Data.Projects.ContainsKey($Key)) { return $script:Data.Projects[$Key] }
    elseif ($script:Data.Settings.TimeTrackerTemplates.ContainsKey($Key.ToUpper())) { return $script:Data.Settings.TimeTrackerTemplates[$Key.ToUpper()] }
    return $null
}

function global:Get-AllProjectsAndTemplates {
    $list = @()
    $list += $script:Data.Projects.GetEnumerator() | Sort-Object { $_.Value.Name } | ForEach-Object {
        [pscustomobject]@{ Key = $_.Key; Name = $_.Value.Name; Type = 'Project'; Client = $_.Value.Client; Status = $_.Value.Status }
    }
    $list += $script:Data.Settings.TimeTrackerTemplates.GetEnumerator() | Sort-Object { $_.Value.Name } | ForEach-Object {
        [pscustomobject]@{ Key = $_.Key; Name = $_.Value.Name; Type = 'Template'; Client = $_.Value.Client; Status = 'N/A' }
    }
    return $list
}

function global:New-Project {
    param($ProjectData) # Expects a hashtable with all required fields
    if ($script:Data.Projects.ContainsKey($ProjectData.Key) -or $script:Data.Settings.TimeTrackerTemplates.ContainsKey($ProjectData.Key.ToUpper())) {
        throw "Project key '$($ProjectData.Key)' already exists as a project or template."
    }
    
    $newProject = @{
        Name = $ProjectData.Name; Id1 = $ProjectData.Id1; Id2 = $ProjectData.Id2; Client = $ProjectData.Client
        Department = $ProjectData.Department; BillingType = $ProjectData.BillingType; Rate = $ProjectData.Rate
        Budget = $ProjectData.Budget; Status = $ProjectData.Status; Notes = $ProjectData.Notes
        StartDate = (Get-Date).ToString("yyyy-MM-dd"); TotalHours = 0.0; TotalBilled = 0.0
        CompletedTasks = 0; ActiveTasks = 0; Manager = ""; Priority = "Medium"; DueDate = $null
        CreatedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    $script:Data.Projects[$ProjectData.Key] = $newProject
    Save-UnifiedData
}

function global:Update-Project {
    param([string]$Key, [hashtable]$ProjectData)
    if (-not $script:Data.Projects.ContainsKey($Key)) { throw "Project '$Key' not found." }
    
    foreach ($prop in $ProjectData.Keys) {
        $script:Data.Projects[$Key][$prop] = $ProjectData[$prop]
    }
    Save-UnifiedData
}

function global:Update-ProjectStatistics {
    param([string]$ProjectKey)
    if (-not $script:Data.Projects.ContainsKey($ProjectKey)) { return }
    $project = $script:Data.Projects[$ProjectKey]
    $projectEntries = $script:Data.TimeEntries | Where-Object { $_.ProjectKey -eq $ProjectKey }
    $project.TotalHours = [Math]::Round(($projectEntries | Measure-Object -Property Hours -Sum).Sum, 2)
    $projectTasks = $script:Data.Tasks | Where-Object { $_.ProjectKey -eq $ProjectKey -and ($_.IsCommand -ne $true) }
    $project.CompletedTasks = ($projectTasks | Where-Object { $_.Completed }).Count
    $project.ActiveTasks = ($projectTasks | Where-Object { -not $_.Completed }).Count
}

function global:Get-ProjectSummaryReportData {
    $projectSummaryData = @()
    foreach ($key in ($script:Data.Projects.Keys | Sort-Object)) {
        Update-ProjectStatistics -ProjectKey $key
        $p = $script:Data.Projects[$key]
        $projectSummaryData += [PSCustomObject]@{
            Key = $key; Name = $p.Name; Client = $p.Client; Status = $p.Status; Budget = $p.Budget
            TotalHours = $p.TotalHours
            RemainingHours = if ($p.Budget -gt 0) { [Math]::Round($p.Budget - $p.TotalHours, 2) } else { "N/A" }
            Progress = if ($p.Budget -gt 0 -and $p.TotalHours -ge 0) {
                           if ($p.TotalHours -eq 0 -and $p.Budget -gt 0) { "0%" }
                           elseif ($p.TotalHours -gt 0) { "$([Math]::Round(($p.TotalHours / $p.Budget) * 100, 1))%" }
                           else { "N/A" }
                       } else { "N/A" }
            ActiveTasks = $p.ActiveTasks
        }
    }
    return $projectSummaryData
}
#endregion

#region Task Management Logic
function global:New-TodoTask {
    param([hashtable]$TaskData)
    $newTask = @{
        Id = New-TodoId; Description = $TaskData.Description; Priority = $TaskData.Priority; Category = $TaskData.Category
        ProjectKey = $TaskData.ProjectKey; StartDate = $TaskData.StartDate; DueDate = $TaskData.DueDate; Tags = $TaskData.Tags
        Progress = 0; Completed = $false; CreatedDate = [datetime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
        CompletedDate = $null; EstimatedTime = $TaskData.EstimatedTime; TimeSpent = 0.0; Subtasks = $TaskData.Subtasks
        Notes = ""; LastModified = [datetime]::Now.ToString("yyyy-MM-dd HH:mm:ss"); IsCommand = $false
    }
    $script:Data.Tasks += $newTask
    if ($TaskData.ProjectKey) { Update-ProjectStatistics -ProjectKey $TaskData.ProjectKey }
    Save-UnifiedData
    return $newTask
}

function global:Update-Task {
    param([string]$TaskId, [hashtable]$TaskData)
    $task = $script:Data.Tasks | Where-Object { $_.Id -eq $TaskId } | Select-Object -First 1
    if (-not $task) { throw "Task with ID '$TaskId' not found!" }

    $originalProjectKey = $task.ProjectKey
    foreach($prop in $TaskData.Keys) {
        $task[$prop] = $TaskData[$prop]
    }
    $task.LastModified = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    if ($originalProjectKey -and $originalProjectKey -ne $task.ProjectKey) { Update-ProjectStatistics -ProjectKey $originalProjectKey }
    if ($task.ProjectKey) { Update-ProjectStatistics -ProjectKey $task.ProjectKey }
    Save-UnifiedData
}

function global:Complete-TodoTask {
    param([string]$TaskId)
    $task = $script:Data.Tasks | Where-Object { $_.Id -eq $TaskId } | Select-Object -First 1
    if (-not $task) { throw "Task with ID '$TaskId' not found!" }
    if ($task.Completed) { return $false } # No change
    
    $task.Completed = $true
    $task.Progress = 100
    $task.CompletedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $task.LastModified = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    if ($task.ProjectKey) { Update-ProjectStatistics -ProjectKey $task.ProjectKey }
    Save-UnifiedData
    return $true # Change was made
}

function global:Remove-TodoTask {
    param([string]$TaskId)
    $task = $script:Data.Tasks | Where-Object { $_.Id -eq $TaskId } | Select-Object -First 1
    if (-not $task) { throw "Task with ID '$TaskId' not found!" }
    $originalProjectKey = $task.ProjectKey
    $script:Data.Tasks = $script:Data.Tasks | Where-Object { $_.Id -ne $task.Id }
    if ($originalProjectKey) { Update-ProjectStatistics -ProjectKey $originalProjectKey }
    Save-UnifiedData
}

function global:Archive-CompletedTasksLogic {
    $cutoffDate = [datetime]::Today.AddDays(-$script:Data.Settings.AutoArchiveDays)
    $tasksToArchive = $script:Data.Tasks | Where-Object { 
        $_.Completed -and ($_.IsCommand -ne $true) -and 
        (-not [string]::IsNullOrEmpty($_.CompletedDate)) -and 
        ([datetime]::Parse($_.CompletedDate).Date -lt $cutoffDate.Date)
    }
    if ($tasksToArchive.Count -eq 0) { return 0 }
    if ($null -eq $script:Data.ArchivedTasks) { $script:Data.ArchivedTasks = @() }
    $script:Data.ArchivedTasks += $tasksToArchive
    $idsToArchive = $tasksToArchive | ForEach-Object {$_.Id}
    $script:Data.Tasks = $script:Data.Tasks | Where-Object { $_.Id -notin $idsToArchive }
    $affectedProjects = $tasksToArchive | Where-Object { -not [string]::IsNullOrEmpty($_.ProjectKey) } | Select-Object -ExpandProperty ProjectKey -Unique
    foreach ($projectKey in $affectedProjects) { Update-ProjectStatistics -ProjectKey $projectKey }
    Save-UnifiedData
    return $tasksToArchive.Count
}

function global:Get-FilteredAndSortedTasks {
    param([string]$Filter, [string]$SortBy, [switch]$ShowCompleted, [string]$View)
    $tasksToDisplay = $script:Data.Tasks | Where-Object { $_.IsCommand -ne $true }
    if ($Filter) {
        $tasksToDisplay = $tasksToDisplay | Where-Object {
            $_.Description -like "*$Filter*" -or $_.Category -like "*$Filter*" -or ($_.Tags -and ($_.Tags -join ' ') -like "*$Filter*") -or
            ($_.ProjectKey -and (Get-ProjectOrTemplate $_.ProjectKey) -and (Get-ProjectOrTemplate $_.ProjectKey).Name -like "*$Filter*") -or
            $_.Id -like "*$Filter*"
        }
    }
    if (-not $ShowCompleted) {
        $cutoffDate = [datetime]::Today.AddDays(-$script:Data.Settings.ShowCompletedDays)
        $tasksToDisplay = $tasksToDisplay | Where-Object { (-not $_.Completed) -or ((-not [string]::IsNullOrEmpty($_.CompletedDate)) -and ([datetime]::Parse($_.CompletedDate).Date -ge $cutoffDate.Date)) }
    }
    switch ($SortBy.ToLower()) {
        "smart" { $tasksToDisplay | Sort-Object @{E={@{"Overdue"=1;"Due Today"=2;"Due Soon"=3;"In Progress"=4;"Done (Pending Confirmation)"=4;"Pending"=5;"Scheduled"=6;"Completed"=7}[(Get-TaskStatus $_)]}},@{E={@{"Critical"=1;"High"=2;"Medium"=3;"Low"=4}[$_.Priority]}},@{E={if([string]::IsNullOrEmpty($_.DueDate)){[DateTime]::MaxValue}else{[DateTime]::Parse($_.DueDate)}}},@{E={if([string]::IsNullOrEmpty($_.CreatedDate)){[DateTime]::MinValue}else{[DateTime]::Parse($_.CreatedDate)}}} }
        "priority" { $tasksToDisplay | Sort-Object @{E={@{"Critical"=1;"High"=2;"Medium"=3;"Low"=4}[$_.Priority]}},@{E={if([string]::IsNullOrEmpty($_.DueDate)){[DateTime]::MaxValue}else{[DateTime]::Parse($_.DueDate)}}} }
        "duedate" { $tasksToDisplay | Sort-Object @{E={if([string]::IsNullOrEmpty($_.DueDate)){[DateTime]::MaxValue}else{[DateTime]::Parse($_.DueDate)}}},@{E={@{"Critical"=1;"High"=2;"Medium"=3;"Low"=4}[$_.Priority]}} }
        "created" { $tasksToDisplay | Sort-Object @{E={if([string]::IsNullOrEmpty($_.CreatedDate)){[DateTime]::MinValue}else{[DateTime]::Parse($_.CreatedDate)}}; Descending = $true} }
        "category" { $tasksToDisplay | Sort-Object @{E={if([string]::IsNullOrEmpty($_.Category)){"zzz"}else{$_.Category}}},@{E={@{"Critical"=1;"High"=2;"Medium"=3;"Low"=4}[$_.Priority]}} }
        "project" { $tasksToDisplay | Sort-Object @{E={if([string]::IsNullOrEmpty($_.ProjectKey)){"zzz"}else{$_.ProjectKey}}},@{E={@{"Critical"=1;"High"=2;"Medium"=3;"Low"=4}[$_.Priority]}} }
        default { $tasksToDisplay }
    }
}
#endregion

#region Command Snippet Logic
function global:New-CommandSnippet {
    param([hashtable]$SnippetData)
    $snippet = @{
        Id = New-TodoId; Description = $SnippetData.Name; Priority = "Low"; Category = $SnippetData.Category
        ProjectKey = $null; StartDate = $null; DueDate = $null; Tags = $SnippetData.Tags; Progress = 0
        Completed = $false; CreatedDate = [datetime]::Now.ToString("yyyy-MM-dd HH:mm:ss"); CompletedDate = $null
        EstimatedTime = 0; TimeSpent = 0; Subtasks = @(); Notes = $SnippetData.CommandText
        LastModified = [datetime]::Now.ToString("yyyy-MM-dd HH:mm:ss"); IsCommand = $true; Hotkey = $SnippetData.Hotkey
        LastUsed = $null; UseCount = 0
    }
    $script:Data.Tasks += $snippet
    Save-UnifiedData
    if ($script:Data.Settings.CommandSnippets.AutoCopyToClipboard) { Set-Clipboard $SnippetData.CommandText }
}

function global:Get-CommandSnippets {
    param([string]$SearchTerm)
    $snippets = $script:Data.Tasks | Where-Object { $_.IsCommand -eq $true }
    if ($SearchTerm) {
        $snippets = $snippets | Where-Object {
            $_.Description -like "*$SearchTerm*" -or $_.Notes -like "*$SearchTerm*" -or ($_.Tags -and ($_.Tags -join " ") -like "*$SearchTerm*")
        }
    }
    # First, sort by Description (ascending) as a secondary key.
    # Then, sort by UseCount (descending) as the primary key.
    # This is a "stable sort" approach.
    return $snippets | Sort-Object -Property Description | Sort-Object -Property UseCount -Descending
}

function global:Update-CommandSnippetUsage {
    param([string]$Id)
    $snippet = $script:Data.Tasks | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
    if($snippet) {
        $snippet.LastUsed = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $snippet.UseCount = [int]$snippet.UseCount + 1
        Save-UnifiedData
    }
}

function global:Remove-CommandSnippet {
    param([string]$Id)
    $script:Data.Tasks = $script:Data.Tasks | Where-Object { $_.Id -ne $Id }
    Save-UnifiedData
}
#endregion

#region Time Management Logic
function global:New-ManualTimeEntry {
    param([hashtable]$EntryData) # ProjectKey, Date, Hours, Description, TaskId
    $entry = @{
        Id = New-TodoId; ProjectKey = $EntryData.ProjectKey; TaskId = $EntryData.TaskId; Date = $EntryData.Date
        Hours = [Math]::Round($EntryData.Hours, 2); Description = $EntryData.Description; StartTime = ""; EndTime = "";
        EnteredAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    if ($null -eq $script:Data.TimeEntries) { $script:Data.TimeEntries = @() }
    $script:Data.TimeEntries += $entry
    
    if($EntryData.TaskId){
        $task = $script:Data.Tasks | Where-Object { $_.Id -eq $EntryData.TaskId }
        if ($task) { $task.TimeSpent = [Math]::Round($task.TimeSpent + $EntryData.Hours, 2) }
    }

    if ($script:Data.Projects.ContainsKey($EntryData.ProjectKey)) { Update-ProjectStatistics -ProjectKey $EntryData.ProjectKey }
    Save-UnifiedData
}

function global:Start-TimerLogic {
    param([string]$ProjectKey, [string]$TaskId, [string]$Description)
    $timerMapKey = if ($TaskId) { $TaskId } else { $ProjectKey }
    if ($script:Data.ActiveTimers.ContainsKey($timerMapKey)) { throw "Timer already running for this item!" }
    $timer = @{ StartTime = Get-Date; ProjectKey = $ProjectKey; TaskId = $TaskId; Description = $Description }
    $script:Data.ActiveTimers[$timerMapKey] = $timer
    Save-UnifiedData
}

function global:Stop-TimerLogic {
    param([string]$Key)
    $timer = $script:Data.ActiveTimers[$Key]
    if (-not $timer) { throw "Timer with key '$Key' not found." }

    $endTime = Get-Date
    $durationHours = ($endTime - [DateTime]$timer.StartTime).TotalHours
    if ($durationHours -lt (1/60)) { throw "Timer duration is less than 1 minute. Not logged." }

    $entry = @{
        Id = New-TodoId; ProjectKey = $timer.ProjectKey; TaskId = $timer.TaskId;
        Date = $endTime.Date.ToString("yyyy-MM-dd"); Hours = [Math]::Round($durationHours, 2);
        StartTime = ([DateTime]$timer.StartTime).ToString("HH:mm"); EndTime = $endTime.ToString("HH:mm");
        Description = $timer.Description; EnteredAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    if ($null -eq $script:Data.TimeEntries) { $script:Data.TimeEntries = @() }
    $script:Data.TimeEntries += $entry

    if ($timer.TaskId) {
        $task = $script:Data.Tasks | Where-Object { $_.Id -eq $timer.TaskId }
        if ($task) { $task.TimeSpent = [Math]::Round($task.TimeSpent + $durationHours, 2) }
    }
    if ($script:Data.Projects.ContainsKey($timer.ProjectKey)) { Update-ProjectStatistics -ProjectKey $timer.ProjectKey }
    $script:Data.ActiveTimers.Remove($Key)
    Save-UnifiedData
    return $entry
}

function global:Get-WeekReportData {
    param([DateTime]$WeekStartDate)
    $weekDates = Get-WeekDates $WeekStartDate
    $weekEntries = $script:Data.TimeEntries | Where-Object {
        try {
            $entryDate = [DateTime]::Parse($_.Date).Date
            $entryDate -ge $weekDates[0].Date -and $entryDate -le $weekDates[4].Date
        } catch { $false }
    }
    if ($weekEntries.Count -eq 0) { return @() }
    $projectHours = @{}
    $dayNames = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
    $dayDateMap = @{}; for($i=0; $i -lt $dayNames.Length; $i++){ $dayDateMap[$dayNames[$i]] = $weekDates[$i].Date }
    foreach ($entry in $weekEntries) {
        $entryDate = [DateTime]::Parse($entry.Date).Date
        $dayNameForEntry = $dayNames | Where-Object { $dayDateMap[$_] -eq $entryDate } | Select-Object -First 1
        if(-not $dayNameForEntry) { continue }
        if (-not $projectHours.ContainsKey($entry.ProjectKey)) {
            $projectHours[$entry.ProjectKey] = @{ Monday = 0.0; Tuesday = 0.0; Wednesday = 0.0; Thursday = 0.0; Friday = 0.0 }
        }
        $projectHours[$entry.ProjectKey][$dayNameForEntry] += $entry.Hours
    }
    $reportData = @()
    foreach ($projEnum in ($projectHours.GetEnumerator() | Sort-Object { (Get-ProjectOrTemplate $_.Key).Name })) {
        $project = Get-ProjectOrTemplate $projEnum.Key
        if (-not $project) { continue }
        $projectTotalHours = 0.0; foreach ($day in $dayNames) { $projectTotalHours += $projEnum.Value[$day] }
        $reportData += [PSCustomObject]@{
            Name = $project.Name; Id1 = $project.Id1; Id2 = Format-Id2 $project.Id2; Client = $project.Client
            Mon = [Math]::Round($projEnum.Value.Monday, 2); Tue = [Math]::Round($projEnum.Value.Tuesday, 2)
            Wed = [Math]::Round($projEnum.Value.Wednesday, 2); Thu = [Math]::Round($projEnum.Value.Thursday, 2)
            Fri = [Math]::Round($projEnum.Value.Friday, 2); Total = [Math]::Round($projectTotalHours, 2)
        }
    }
    return $reportData
}
#endregion



#region #################### PTUI APPLICATION MODULE ####################
# This section defines the entire PTUI interface. It uses the logic
# functions from the CORE LOGIC MODULE to manage data.



function Start-ProductivitySuiteTUI {
    # Load data before building UI
    Load-UnifiedData

    # --- UI STATE ---
    # This holds transient state for the UI, like filters and current selections
    $script:UIState = [pscustomobject]@{
        CurrentView = 'Dashboard'
        TaskFilterText = ''
        TaskSortBy = 'Smart'
        TaskShowCompleted = $false
        SelectedTask = $null
        SelectedProjectKey = $null
        SelectedSnippet = $null
        ReportWeek = $script:Data.CurrentWeek
        StatusMessage = "Welcome to the Unified Productivity Suite! | F1 for Help"
    }

    # --- DIALOGS (Forms for Add/Edit operations) ---
    function Show-TaskDialog {
        param([hashtable]$Task = $null)
        $isEdit = $null -ne $Task
        $dialogTitle = if ($isEdit) { "Edit Task" } else { "Add New Task" }

        $allCategories = $script:Data.Tasks | Where-Object { -not $_.IsCommand -and -not [string]::IsNullOrEmpty($_.Category) } | Select-Object -ExpandProperty Category -Unique
        $allProjects = Get-AllProjectsAndTemplates

        $dialog = Dialog -Title $dialogTitle -Width 80 -Height 22 {
            # Row 1: Description
            Label -Content "Description:" -Y 0
            $descField = TextField -Text ($Task.Description) -X 14 -Y 0 -Width 62
            
            # Row 2: Priority & Category
            Label -Content "Priority:" -Y 2
            $prioCombo = ComboBox -Items "Low", "Medium", "High", "Critical" -SelectedItem ($Task.Priority -or $script:Data.Settings.DefaultPriority) -X 14 -Y 2 -Width 20
            Label -Content "Category:" -X 38 -Y 2
            $catCombo = ComboBox -Items $allCategories -SelectedItem ($Task.Category -or $script:Data.Settings.DefaultCategory) -X 49 -Y 2 -Width 27 -AllowNewItems
            
            # Row 3: Project
            Label -Content "Project:" -Y 4
            $projCombo = ComboBox -Items ($allProjects.Name) -SelectedItem ((Get-ProjectOrTemplate $Task.ProjectKey).Name) -X 14 -Y 4 -Width 62
            
            # Row 4: Dates
            Label -Content "Start Date:" -Y 6
            $startDatePicker = DatePicker -Date ($Task.StartDate) -X 14 -Y 6
            Label -Content "Due Date:" -X 38 -Y 6
            $dueDatePicker = DatePicker -Date ($Task.DueDate) -X 49 -Y 6

            # Row 5: Time & Tags
            Label -Content "Est. Hours:" -Y 8
            $estTimeField = TextField -Text ($Task.EstimatedTime) -X 14 -Y 8 -Width 10
            Label -Content "Tags (csv):" -X 38 -Y 8
            $tagsField = TextField -Text ($Task.Tags -join ',') -X 49 -Y 8 -Width 27

            # Row 7+: Notes/Subtasks could go here if needed for more complexity
            
            # Buttons
            Button -Content "OK" -Y 18 -IsDefault -OnClick {
                try {
                    $newProjectKey = if ($projCombo.SelectedIndex -ge 0) { $allProjects[$projCombo.SelectedIndex].Key } else { $null }
                    $taskData = @{
                        Description = $descField.Text
                        Priority = $prioCombo.SelectedItem
                        Category = $catCombo.Text
                        ProjectKey = $newProjectKey
                        StartDate = if($startDatePicker.Date) { $startDatePicker.Date.Value.ToString("yyyy-MM-dd") } else { $null }
                        DueDate = if($dueDatePicker.Date) { $dueDatePicker.Date.Value.ToString("yyyy-MM-dd") } else { $null }
                        EstimatedTime = if($estTimeField.Text){[double]$estTimeField.Text}else{0.0}
                        Tags = $tagsField.Text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                        Subtasks = if($isEdit){$Task.Subtasks}else{@()}
                    }
                    if ($isEdit) {
                        Update-Task -TaskId $Task.Id -TaskData $taskData
                        $script:UIState.StatusMessage = "Task updated: $($taskData.Description)"
                    } else {
                        New-TodoTask -TaskData $taskData
                        $script:UIState.StatusMessage = "Task added: $($taskData.Description)"
                    }
                    $_.Parent.Close()
                    # After closing, the main loop will refresh the view
                } catch {
                    $script:App.ShowMessageBox("Error", "Could not save task. Please check your input.`n$($_.Exception.Message)")
                }
            }
            Button -Content "Cancel" -Y 18 -X 5 -OnClick { $_.Parent.Close() }
        }
        $dialog.Show()
    }
    
    function Show-ProjectDialog {
        param([hashtable]$Project = $null)
        $isEdit = $null -ne $Project
        $dialogTitle = if ($isEdit) { "Edit Project" } else { "Add New Project" }

        $dialog = Dialog -Title $dialogTitle -Width 70 -Height 20 {
            Label -Content "Key:" -Y 0; $keyField = TextField -Text ($Project.Key) -X 14 -Y 0 -Width 15 -ReadOnly:$isEdit
            Label -Content "Name:" -Y 2; $nameField = TextField -Text ($Project.Name) -X 14 -Y 2 -Width 52
            Label -Content "Client:" -Y 4; $clientField = TextField -Text ($Project.Client) -X 14 -Y 4 -Width 25
            Label -Content "Department:" -Y 6; $deptField = TextField -Text ($Project.Department) -X 14 -Y 6 -Width 25
            
            Label -Content "Status:" -Y 8; $statusCombo = ComboBox -Items "Active", "On Hold", "Completed" -SelectedItem ($Project.Status -or "Active") -X 14 -Y 8
            Label -Content "Billing:" -Y 10; $billingCombo = ComboBox -Items "Non-Billable", "Billable", "Fixed Price" -SelectedItem ($Project.BillingType -or "Non-Billable") -X 14 -Y 10
            
            Label -Content "Rate:" -Y 12; $rateField = TextField -Text ($Project.Rate) -X 14 -Y 12 -Width 10
            Label -Content "Budget (h):" -Y 14; $budgetField = TextField -Text ($Project.Budget) -X 14 -Y 14 -Width 10
            
            Button -Content "OK" -Y 16 -IsDefault -OnClick {
                try {
                    $projectData = @{
                        Key = $keyField.Text; Name = $nameField.Text; Client = $clientField.Text; Department = $deptField.Text
                        Status = $statusCombo.SelectedItem; BillingType = $billingCombo.SelectedItem
                        Rate = if($rateField.Text){[double]$rateField.Text}else{0.0}
                        Budget = if($budgetField.Text){[double]$budgetField.Text}else{0.0}
                        Id1 = if($isEdit){$Project.Id1}else{""}; Id2 = if($isEdit){$Project.Id2}else{""}
                        Notes = if($isEdit){$Project.Notes}else{""}
                    }
                    if ($isEdit) {
                        Update-Project -Key $Project.Key -ProjectData $projectData
                        $script:UIState.StatusMessage = "Project updated: $($projectData.Name)"
                    } else {
                        New-Project -ProjectData $projectData
                        $script:UIState.StatusMessage = "Project added: $($projectData.Name)"
                    }
                    $_.Parent.Close()
                } catch { $script:App.ShowMessageBox("Error", "Could not save project.`n$($_.Exception.Message)")}
            }
            Button -Content "Cancel" -Y 16 -X 5 -OnClick { $_.Parent.Close() }
        }
        $dialog.Show()
    }

    # --- MAIN UI VIEWS ---
    function Get-DashboardView {
        $activeTimers = if ($script:Data.ActiveTimers) { $script:Data.ActiveTimers.Count } else { 0 }
        $activeTasks = ($script:Data.Tasks | Where-Object { (-not $_.Completed) -and ($_.IsCommand -ne $true) }).Count
        $todayHours = [Math]::Round(($script:Data.TimeEntries | Where-Object { $_.Date -eq (Get-Date).ToString("yyyy-MM-dd") } | Measure-Object -Property Hours -Sum).Sum, 2)
        $targetWeeklyHours = $script:Data.Settings.HoursPerDay * $script:Data.Settings.DaysPerWeek
        $weekStart = Get-WeekStart
        $weekHours = [Math]::Round(($script:Data.TimeEntries | Where-Object { (-not [string]::IsNullOrEmpty($_.Date)) -and ([DateTime]::Parse($_.Date).Date -ge $weekStart.Date) -and ([DateTime]::Parse($_.Date).Date -lt $weekStart.AddDays(7).Date) } | Measure-Object -Property Hours -Sum).Sum, 2)
        $weekProgress = if ($targetWeeklyHours -gt 0) { [Math]::Min(100, [Math]::Round(($weekHours / $targetWeeklyHours) * 100, 0)) } else { 0 }
        
        return Frame -Title "Dashboard" {
            # Current Status
            Frame -Title "Current Status" -Width 45 -Height 12 {
                Label -Content "Today's Hours:" -Y 0; Text -Text "$todayHours" -X 16 -Y 0 -ColorScheme 'Success'
                Label -Content "Active Timers:" -Y 2; Text -Text "$activeTimers" -X 16 -Y 2 -ColorScheme 'Error'
                Label -Content "Active Tasks:" -Y 4; Text -Text "$activeTasks" -X 16 -Y 4 -ColorScheme 'Warning'
            }
            # Week Summary
            Frame -Title "Week Summary (starting $($weekStart.ToString('MMM dd')))" -X 47 -Width 45 -Height 12 {
                Label -Content "Total Hours:" -Y 0; Text -Text "$weekHours / $targetWeeklyHours target" -X 14 -Y 0
                Label -Content "Progress:" -Y 2
                ProgressBar -Fraction ($weekProgress/100) -X 14 -Y 2 -Width 28
            }
            # Today's Tasks
            Frame -Title "Due Today & Overdue" -Y 13 -Height 10 {
                $dueTasks = Get-FilteredAndSortedTasks -SortBy "Smart" | Where-Object { $_.Status -in "Due Today", "Overdue" } | Select-Object -First 5
                ListView -Items $dueTasks -OnRender { param($task) "[$($task.Id.Substring(0,4))] $($task.Description)" } -ColorScheme 'Warning'
            }
        }
    }

    function Get-TaskView {
    return Frame -Title "Task Management" {
        # Top action bar
        Horizontal -Y 0 {
            Label -Content "Filter:"; $filterField = TextField -Width 30 -Bind ($script:UIState) -MemberName 'TaskFilterText'
            Label -Content " Sort:" -X 38
            $sortCombo = ComboBox -Items "Smart", "Priority", "DueDate", "Created", "Category", "Project" -SelectedItem $script:UIState.TaskSortBy -X 45 -Width 12 -OnSelectedItemChanged {
                $script:UIState.TaskSortBy = $_.SelectedItem
            }
            $completedCheck = CheckBox -Text "Show All Completed" -X 60 -Checked $script:UIState.TaskShowCompleted -OnCheckChanged {
                $script:UIState.TaskShowCompleted = $_.Checked
            }
        }
        # Main task list
        $taskListView = ListView -Y 2 -Height (Fill 5) -OnRender { 
            param($task)
            $prioColor = Get-PriorityColor $task.Priority
            $status = Get-TaskStatus $task
            $statusPart = if($status -ne "Pending"){" ($status)"}else{""}
            $projectPart = if($task.ProjectKey){ " [$( (Get-ProjectOrTemplate $task.ProjectKey).Name )]"} else {""}
            $datePart = if($task.DueDate){" | Due: $(Format-TodoDate $task.DueDate)"}else{""}
            $text = "[fg=$prioColor]●[/] $($task.Description)$statusPart$projectPart$datePart"
            if($task.Completed){ $text = "[fg=Gray,strikethrough]$($task.Description)[/]" }
            return $text
        } -OnSelectedItemChanged { $script:UIState.SelectedTask = $_.SelectedItem }
        
        # Bottom info/action panel
        $taskDetailView = Frame -Title "Task Details" -Y (PosOf $taskListView bottom) -Height 5 {
            Label -Text "Select a task to see details."
        }
        
        # Button bar
        Horizontal -Y (PosOf $taskDetailView bottom) {
            Button -Content "Add (a)" -OnClick { Show-TaskDialog }
            Button -Content "Edit (e)" -OnClick { if($script:UIState.SelectedTask){ Show-TaskDialog -Task $script:UIState.SelectedTask } } -X (PosOf previous left 5)
            Button -Content "Complete (c)" -OnClick {
                if($script:UIState.SelectedTask){
                    if(Complete-TodoTask -TaskId $script:UIState.SelectedTask.Id){ $script:UIState.StatusMessage = "Task completed." }
                    else { $script:UIState.StatusMessage = "Task already completed." }
                }
            }
            Button -Content "Delete (del)" -OnClick { 
                if($script:UIState.SelectedTask){ 
                    $script:App.ShowMessageBox("Confirm Delete", "Delete task '$($script:UIState.SelectedTask.Description)'?", "Yes", "No") | Out-Null
                    if ($script:App.MessageBoxResult -eq 0) {
                        Remove-TodoTask -TaskId $script:UIState.SelectedTask.Id
                        $script:UIState.SelectedTask = $null
                        $script:UIState.StatusMessage = "Task deleted."
                    }
                }
            }
        }
        
        # --- Update Logic for Task View ---
        $taskViewUpdateAction = {
            $taskListView.Items = Get-FilteredAndSortedTasks -Filter $script:UIState.TaskFilterText -SortBy $script:UIState.TaskSortBy -ShowCompleted:$script:UIState.TaskShowCompleted
            if ($script:UIState.SelectedTask) {
                $taskDetailView.Children.Clear()
                # FIX IS HERE: Wrapped the TextBlock command in parentheses
                $taskDetailView.Add(
                    (TextBlock -Text "ID: $($script:UIState.SelectedTask.Id) | Prio: $($script:UIState.SelectedTask.Priority) | Spent: $($script:UIState.SelectedTask.TimeSpent)h / Est: $($script:UIState.SelectedTask.EstimatedTime)h`n$($script:UIState.SelectedTask.Notes)")
                )
            } else {
                $taskDetailView.Children.Clear()
                $taskDetailView.Add((Label -Text "Select a task to see details."))
            }
        }
        # Attach the update logic to run when any filter/sort control changes
        $filterField.OnTextChanged.Add($taskViewUpdateAction)
        $sortCombo.OnSelectedItemChanged.Add($taskViewUpdateAction)
        $completedCheck.OnCheckChanged.Add($taskViewUpdateAction)
        $taskListView.OnSelectedItemChanged.Add($taskViewUpdateAction)
        
        # Set initial state
        Invoke-Command $taskViewUpdateAction
    }
}
    
    function Get-ProjectView {
        return Frame -Title "Projects & Templates" {
            $projListView = ListView -Width 40 -Height (Fill 1) -OnRender {
                param($item)
                if($item.Type -eq 'Project'){ "[fg=Cyan]P[/] $($item.Name) ($($item.Client))" }
                else { "[fg=Magenta]T[/] $($item.Name)" }
            } -OnSelectedItemChanged {
                $script:UIState.SelectedProjectKey = $_.SelectedItem.Key
            }
            
            $projDetailView = Frame -Title "Details" -X (PosOf $projListView right) -Width (Fill) -Height (Fill 1) {
                Label "Select a project or template to see details."
            }

            Horizontal -Y (PosOf $projListView bottom) {
                Button -Content "Add" -OnClick { Show-ProjectDialog }
                Button -Content "Edit" -OnClick {
                    if ($script:UIState.SelectedProjectKey) {
                        $proj = Get-ProjectOrTemplate $script:UIState.SelectedProjectKey
                        if ($proj.PSObject.Properties.Name -contains 'CreatedDate') { # Simple check if it's a project not template
                            Show-ProjectDialog -Project $proj
                        } else { $script:App.ShowMessageBox("Info", "Cannot edit templates from here.") }
                    }
                }
            }

            # --- Update Logic for Project View ---
            $projViewUpdateAction = {
                $projListView.Items = Get-AllProjectsAndTemplates
                $projDetailView.Children.Clear()
                if ($script:UIState.SelectedProjectKey) {
                    $item = Get-ProjectOrTemplate $script:UIState.SelectedProjectKey
                    Update-ProjectStatistics -ProjectKey $script:UIState.SelectedProjectKey # Refresh stats on select
                    $item = Get-ProjectOrTemplate $script:UIState.SelectedProjectKey # Re-get
                    $text = foreach($prop in $item.PSObject.Properties){ if($prop.Name -notmatch "^(PS|Item)"){"$($prop.Name): $($prop.Value)"} }
                    $projDetailView.Add((TextBlock -Text ($text -join "`n")))
                } else {
                    $projDetailView.Add((Label "Select a project or template to see details."))
                }
            }
            $projListView.OnSelectedItemChanged.Add($projViewUpdateAction)
            Invoke-Command $projViewUpdateAction
        }
    }

    function Get-TimeView {
        return Frame -Title "Time Management" {
            # Active Timers
            Frame -Title "Active Timers" -Height 10 {
                $timerListView = ListView -OnRender { 
                    param($timer)
                    $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
                    $projName = (Get-ProjectOrTemplate $timer.Value.ProjectKey).Name
                    "$projName - $($timer.Value.Description) - $([Math]::Floor($elapsed.TotalHours)):$($elapsed.ToString('mm\:ss'))"
                }
            }
            # Recent Entries
            Frame -Title "Recent Time Entries (Last 10)" -Y 10 -Height (Fill 1) {
                $recentEntries = $script:Data.TimeEntries | Sort-Object @{E={[datetime]$_.Date};Desc=$true},@{E={[datetime]$_.EnteredAt};Desc=$true} | Select-Object -First 10
                ListView -Items $recentEntries -OnRender {
                    param($entry)
                    $projName = (Get-ProjectOrTemplate $entry.ProjectKey).Name
                    "$($entry.Date): $($entry.Hours)h - $projName - $($entry.Description)"
                }
            }
            # --- Update Logic for Time View ---
            Invoke-Command {
                $timerListView.Items = $script:Data.ActiveTimers.GetEnumerator()
            }
        }
    }

    function Get-ReportView {
    return Frame -Title "Reports" {
        $reportTypeCombo = ComboBox -Items "Week Report", "Project Summary" -Width 20 -OnSelectedItemChanged {
             $script:UIState.CurrentView = "Reports." + ($_.SelectedItem -replace ' ')
        }
        $reportPanel = Panel -Y 2 -Height (Fill)
        
        # --- Update logic ---
        $reportUpdateAction = {
            $reportPanel.Children.Clear()
            switch ($script:UIState.CurrentView) {
                "Reports.WeekReport" {
                    $reportData = Get-WeekReportData -WeekStartDate $script:UIState.ReportWeek
                    # FIX IS HERE: Wrapped the Frame command in parentheses
                    $reportPanel.Add(
                        (Frame -Title "Week Starting $($script:UIState.ReportWeek.ToString('yyyy-MM-dd'))" {
                            Horizontal {
                                Button -Content "< Prev" -OnClick { $script:UIState.ReportWeek = $script:UIState.ReportWeek.AddDays(-7) }
                                Button -Content "Today" -OnClick { $script:UIState.ReportWeek = (Get-WeekStart (Get-Date)) }
                                Button -Content "Next >" -OnClick { $script:UIState.ReportWeek = $script:UIState.ReportWeek.AddDays(7) }
                            }
                            TableView -Y 2 -Items $reportData
                        })
                    )
                }
                "Reports.ProjectSummary" {
                     # FIX IS HERE: Wrapped the Frame command in parentheses
                     $reportPanel.Add(
                        (Frame -Title "Project Summary" {
                            TableView -Items (Get-ProjectSummaryReportData)
                        })
                     )
                }
            }
        }
        $reportTypeCombo.OnSelectedItemChanged.Add($reportUpdateAction)
        # Add a listener for when the week changes
        $script:UIState.add_PropertyChanged({ if($_.PropertyName -eq 'ReportWeek'){ Invoke-Command $reportUpdateAction }})

        $reportTypeCombo.SelectedIndex = 0 # Trigger initial load
    }
}

    # --- MAIN WINDOW DEFINITION ---
    $script:App = Window -Title "Unified Productivity Suite v5.0" {
        # Menu Bar at the top
        MenuBar {
            MenuItem -Title "_File" {
                MenuItem -Title "_Save" -ShortCut F2 -OnClick { Save-UnifiedData; $script:UIState.StatusMessage = "Data saved." }
                MenuItem -Title "E_xit" -ShortCut F10 -OnClick { $script:App.RequestStop() }
            }
            MenuItem -Title "_Views" {
                MenuItem -Title "_Dashboard" -ShortCut Ctrl+D -OnClick { $script:UIState.CurrentView = 'Dashboard' }
                MenuItem -Title "_Tasks" -ShortCut Ctrl+T -OnClick { $script:UIState.CurrentView = 'Tasks' }
                MenuItem -Title "_Projects" -ShortCut Ctrl+P -OnClick { $script:UIState.CurrentView = 'Projects' }
                MenuItem -Title "T_ime" -ShortCut Ctrl+I -OnClick { $script:UIState.CurrentView = 'Time' }
                MenuItem -Title "_Reports" -ShortCut Ctrl+R -OnClick { $script:UIState.CurrentView = 'Reports.WeekReport' }
            }
            MenuItem -Title "_Actions" {
                MenuItem -Title "Add _Task..." -OnClick { Show-TaskDialog }
                MenuItem -Title "Add _Project..." -OnClick { Show-ProjectDialog }
                MenuItem -Title "Start _Timer..."
                MenuItem -Title "Stop T_imer..." 
            }
            MenuItem -Title "_Help" {
                MenuItem -Title "About" -ShortCut F1 -OnClick { $script:App.ShowMessageBox("About", "Unified Productivity Suite v5.0`nPTUI Edition`n(c) 2024") }
            }
        }

        # Main content panel that will host the different views
        $mainPanel = Panel -Id 'mainPanel'

        # Status bar at the bottom
        StatusBar {
            StatusItem -Text "F10 to Exit" -Alignment Right
            StatusItem -Text " | " -Alignment Right
            $statusMessageItem = StatusItem -Bind $script:UIState -MemberName "StatusMessage" -Alignment Left
        }

        # --- VIEW SWITCHING LOGIC ---
        $script:UIState.add_PropertyChanged({
            param($evt)
            if ($evt.PropertyName -eq 'CurrentView') {
                $mainPanel.Children.Clear()
                $view = $null
                switch -Wildcard ($script:UIState.CurrentView) {
                    'Dashboard'  { $view = Get-DashboardView }
                    'Tasks'      { $view = Get-TaskView }
                    'Projects'   { $view = Get-ProjectView }
                    'Time'       { $view = Get-TimeView }
                    'Reports.*'  { $view = Get-ReportView }
                }
                if ($view) { $mainPanel.Add($view) }
                $script:App.SetFocus($mainPanel) # Focus the new view
            }
        })
    }

    # Set initial view and start the application
    $script:UIState.CurrentView = 'Dashboard'
    Start-Tui -Window $script:App -OnEnd {
        # Ensure data is saved on exit
        if ($script:Data.ActiveTimers.Count -gt 0) {
            # In a real app, you'd confirm with the user before stopping timers.
            # For simplicity, we'll just save the running timers.
        }
        Save-UnifiedData
        Write-Host "Productivity Suite closed. Data saved."
    }
}

# --- SCRIPT ENTRY POINT ---
Start-ProductivitySuiteTUI

#endregion