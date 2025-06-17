# State Manager Module
# Simple, practical reactive state management for PowerShell TUI

function global:New-TuiState {
    <#
    .SYNOPSIS
    Creates a reactive state object for managing application or screen state
    
    .DESCRIPTION
    This creates a PowerShell object that tracks state changes and notifies
    subscribers when values change. It's designed to be simple and practical.
    
    .PARAMETER InitialState
    Hashtable of initial state values
    
    .PARAMETER Actions
    Hashtable of named actions (methods) that can mutate the state
    
    .EXAMPLE
    $state = New-TuiState -InitialState @{ count = 0; name = "Test" } -Actions @{
        Increment = { $this.count++ }
        SetName = { param($name) $this.name = $name }
    }
    $state.Subscribe('count', { param($new, $old) Write-Host "Count changed from $old to $new" })
    $state.Increment()
    #>
    param(
        [hashtable]$InitialState = @{},
        [hashtable]$Actions = @{}
    )
    
    # Create the state object
    $stateObject = [PSCustomObject]@{
        # Private properties
        _data = $InitialState.Clone()
        _subscribers = @{}
        _suspendNotifications = $false
    }
    
    # Add dynamic properties for each state key
    foreach ($key in $InitialState.Keys) {
        $stateObject | Add-Member -MemberType ScriptProperty -Name $key -Value {
            # Getter
            $this._data[$key]
        }.GetNewClosure() -SecondValue {
            # Setter
            param($value)
            $this.SetValue($key, $value)
        }.GetNewClosure()
    }
    
    # Core methods
    $stateObject | Add-Member -MemberType ScriptMethod -Name 'SetValue' -Value {
        param([string]$key, $value)
        
        $oldValue = $this._data[$key]
        
        # Skip if value hasn't changed
        if ($oldValue -eq $value) { return }
        
        # Update the value
        $this._data[$key] = $value
        
        # Notify subscribers unless suspended
        if (-not $this._suspendNotifications) {
            $this._NotifySubscribers($key, $value, $oldValue)
        }
    }
    
    $stateObject | Add-Member -MemberType ScriptMethod -Name 'GetValue' -Value {
        param([string]$key)
        return $this._data[$key]
    }
    
    $stateObject | Add-Member -MemberType ScriptMethod -Name 'Subscribe' -Value {
        param(
            [string]$key,
            [scriptblock]$handler
        )
        
        if (-not $this._subscribers.ContainsKey($key)) {
            $this._subscribers[$key] = @()
        }
        
        # Generate unique ID for this subscription
        $subscriptionId = [Guid]::NewGuid().ToString()
        
        $this._subscribers[$key] += @{
            Id = $subscriptionId
            Handler = $handler
        }
        
        # Call handler immediately with current value
        try {
            & $handler $this._data[$key] $null
        } catch {
            Write-Warning "State subscription handler error: $_"
        }
        
        # Return subscription ID for unsubscribing
        return $subscriptionId
    }
    
    $stateObject | Add-Member -MemberType ScriptMethod -Name 'Unsubscribe' -Value {
        param([string]$subscriptionId)
        
        foreach ($key in $this._subscribers.Keys) {
            $this._subscribers[$key] = @($this._subscribers[$key] | Where-Object { $_.Id -ne $subscriptionId })
        }
    }
    
    $stateObject | Add-Member -MemberType ScriptMethod -Name 'Update' -Value {
        param([hashtable]$updates)
        
        # Suspend notifications during bulk update
        $this._suspendNotifications = $true
        
        try {
            foreach ($key in $updates.Keys) {
                $this.SetValue($key, $updates[$key])
            }
        } finally {
            $this._suspendNotifications = $false
        }
        
        # Notify all affected keys
        foreach ($key in $updates.Keys) {
            if ($this._data[$key] -ne $this._data[$key]) { # Check if changed
                $this._NotifySubscribers($key, $this._data[$key], $null)
            }
        }
    }
    
    $stateObject | Add-Member -MemberType ScriptMethod -Name 'GetState' -Value {
        # Return a copy of the current state
        return $this._data.Clone()
    }
    
    $stateObject | Add-Member -MemberType ScriptMethod -Name '_NotifySubscribers' -Value {
        param($key, $newValue, $oldValue)
        
        # Notify specific key subscribers
        if ($this._subscribers.ContainsKey($key)) {
            foreach ($subscription in $this._subscribers[$key]) {
                try {
                    & $subscription.Handler $newValue $oldValue
                } catch {
                    Write-Warning "State notification error for key '$key': $_"
                }
            }
        }
        
        # Notify wildcard subscribers
        if ($this._subscribers.ContainsKey('*')) {
            foreach ($subscription in $this._subscribers['*']) {
                try {
                    & $subscription.Handler @{
                        Key = $key
                        NewValue = $newValue
                        OldValue = $oldValue
                    }
                } catch {
                    Write-Warning "Wildcard state notification error: $_"
                }
            }
        }
    }
    
    # Add user-defined actions as methods
    foreach ($actionName in $Actions.Keys) {
        $stateObject | Add-Member -MemberType ScriptMethod -Name $actionName -Value $Actions[$actionName]
    }
    
    return $stateObject
}

function global:New-ComputedState {
    <#
    .SYNOPSIS
    Creates a computed/derived state value that updates automatically
    
    .PARAMETER Source
    The source state object to derive from
    
    .PARAMETER Keys
    Array of state keys to watch for changes
    
    .PARAMETER Compute
    Scriptblock that computes the derived value
    
    .EXAMPLE
    $filtered = New-ComputedState -Source $state -Keys @('tasks', 'filter') -Compute {
        param($state)
        $state.tasks | Where-Object { $_.Status -eq $state.filter }
    }
    #>
    param(
        [PSCustomObject]$Source,
        [string[]]$Keys,
        [scriptblock]$Compute
    )
    
    $computed = [PSCustomObject]@{
        _source = $Source
        _value = $null
        _compute = $Compute
        _subscriptions = @()
    }
    
    # Add Value property
    $computed | Add-Member -MemberType ScriptProperty -Name 'Value' -Value {
        $this._value
    }
    
    # Recompute method
    $computed | Add-Member -MemberType ScriptMethod -Name '_Recompute' -Value {
        try {
            $this._value = & $this._compute $this._source
        } catch {
            Write-Warning "Computed state error: $_"
        }
    }
    
    # Initial computation
    $computed._Recompute()
    
    # Subscribe to changes
    foreach ($key in $Keys) {
        $subId = $Source.Subscribe($key, {
            $computed._Recompute()
        })
        $computed._subscriptions += $subId
    }
    
    # Cleanup method
    $computed | Add-Member -MemberType ScriptMethod -Name 'Dispose' -Value {
        foreach ($subId in $this._subscriptions) {
            $this._source.Unsubscribe($subId)
        }
    }
    
    return $computed
}

# Export functions
Export-ModuleMember -Function @('New-TuiState', 'New-ComputedState')
