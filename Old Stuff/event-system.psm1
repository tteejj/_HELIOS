# Event System Implementation for PMC Terminal TUI
# Provides decoupled communication between components

#region Event Bus Core
$script:EventSystem = @{
    Bus = @{ Subscribers = @{} }
    Events = @{
        ScreenPushed = "Screen.Pushed"
        ScreenPopped = "Screen.Popped"
        DataChanged = "Data.Changed"
        DataLoaded = "Data.Loaded"
        DataSaved = "Data.Saved"
        TimerTick = "Timer.Tick"
        TimerStarted = "Timer.Started"
        TimerStopped = "Timer.Stopped"
        TaskCreated = "Task.Created"
        TaskUpdated = "Task.Updated"
        TaskDeleted = "Task.Deleted"
        TimeEntryCreated = "TimeEntry.Created"
        ThemeChanged = "Theme.Changed"
        ComponentFocused = "Component.Focused"
        EngineInitialized = "System.EngineInitialized"
        AppExit = "App.Exit"
        NotificationShow = "Notification.Show"
        ConfirmRequest = "Confirm.Request"
        NavigationPopScreen = "Navigation.PopScreen"
        NavigationPushScreen = "Navigation.PushScreen"
        NavigationGoHome = "Navigation.GoHome"
    }
}
#endregion

#region Event Management Functions
function global:Subscribe-Event {
    param(
        [string]$EventName, 
        [scriptblock]$Handler, 
        [string]$SubscriberId = ([Guid]::NewGuid().ToString()), 
        [int]$Priority = 0
    )
    
    if (-not $script:EventSystem.Bus.Subscribers.ContainsKey($EventName)) {
        $script:EventSystem.Bus.Subscribers[$EventName] = [System.Collections.Generic.List[object]]::new()
    }
    
    $subscription = @{
        Id = $SubscriberId
        Handler = $Handler
        Priority = $Priority
    }
    
    $script:EventSystem.Bus.Subscribers[$EventName].Add($subscription)
    
    # Sort by priority (highest first)
    $sorted = $script:EventSystem.Bus.Subscribers[$EventName] | Sort-Object Priority -Descending
    $script:EventSystem.Bus.Subscribers[$EventName].Clear()
    $sorted | ForEach-Object { $script:EventSystem.Bus.Subscribers[$EventName].Add($_) }
    
    return $SubscriberId
}

function global:Unsubscribe-Event {
    param(
        [string]$EventName, 
        [string]$SubscriberId
    )
    
    if ($script:EventSystem.Bus.Subscribers.ContainsKey($EventName)) {
        $sub = $script:EventSystem.Bus.Subscribers[$EventName] | 
            Where-Object { $_.Id -eq $SubscriberId } | 
            Select-Object -First 1
            
        if ($sub) { 
            $script:EventSystem.Bus.Subscribers[$EventName].Remove($sub) | Out-Null
        }
    }
}

function global:Publish-Event {
    param(
        [string]$EventName, 
        [object]$Data = $null
    )
    
    if (-not $script:EventSystem.Bus.Subscribers.ContainsKey($EventName)) { 
        return 
    }
    
    # Create a copy to prevent modification during iteration
    $subscribers = @($script:EventSystem.Bus.Subscribers[$EventName])
    
    $eventData = @{ 
        Name = $EventName
        Data = $Data
        Timestamp = (Get-Date) 
    }
    
    foreach ($sub in $subscribers) {
        try {
            & $sub.Handler -EventData $eventData
        } 
        catch {
            Write-Warning "Event handler for '$EventName' (ID: $($sub.Id)) failed: $_"
        }
    }
}

function global:Clear-EventSubscriptions {
    param([string]$EventName)
    
    if ($EventName) {
        if ($script:EventSystem.Bus.Subscribers.ContainsKey($EventName)) {
            $script:EventSystem.Bus.Subscribers[$EventName].Clear()
        }
    } else {
        # Clear all subscriptions
        $script:EventSystem.Bus.Subscribers.Clear()
    }
}

function global:Get-EventSubscriptions {
    param([string]$EventName)
    
    if ($EventName) {
        return $script:EventSystem.Bus.Subscribers[$EventName]
    } else {
        return $script:EventSystem.Bus.Subscribers
    }
}

#endregion

Export-ModuleMember -Function @(
    'Subscribe-Event', 
    'Unsubscribe-Event', 
    'Publish-Event',
    'Clear-EventSubscriptions',
    'Get-EventSubscriptions'
)
