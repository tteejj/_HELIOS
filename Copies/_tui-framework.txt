# TUI Framework Integration Module - COMPLIANT VERSION
# Only contains compliant utility functions - deprecated functions removed

$script:TuiAsyncJobs = @()

function global:Invoke-TuiMethod {
    <#
    .SYNOPSIS
    Safely invokes a method on a TUI component.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Component,

        [Parameter(Mandatory=$true)]
        [string]$MethodName,

        [Parameter()]
        [hashtable]$Arguments = @{}
    )

    if ($null -eq $Component) { return }
    if (-not $Component.ContainsKey($MethodName)) { return }

    $method = $Component[$MethodName]
    if ($null -eq $method -or $method -isnot [scriptblock]) {
        # The method doesn't exist or is not a scriptblock, so we can't call it.
        # This prevents the "term is not recognized" error.
        return
    }

    # Add the component itself as the 'self' parameter for convenience
    $Arguments['self'] = $Component

    try {
        # Use splatting with the @ operator for robust parameter passing
        return & $method @Arguments
    
        } catch {
        $errorMessage = "Error invoking method '$MethodName' on component '$($Component.Type)': $($_.Exception.Message)"
        Write-Log -Level Error -Message $errorMessage -Data $_
        Request-TuiRefresh
    }
}

# Add 'Invoke-TuiMethod' to the Export-ModuleMember list at the end of the file.

function global:Initialize-TuiFramework {
    <#
    .SYNOPSIS
    Initializes the TUI framework
    #>
    
    # Ensure engine is initialized
    if (-not $global:TuiState) {
        throw "TUI Engine must be initialized before framework"
    }
    
    Write-Verbose "TUI Framework initialized"
}

function global:Invoke-TuiAsync {
    <#
    .SYNOPSIS
    Executes a script block asynchronously with proper job management
    
    .PARAMETER ScriptBlock
    The script block to execute asynchronously
    
    .PARAMETER OnComplete
    Handler to call when the job completes successfully
    
    .PARAMETER OnError
    Handler to call if the job encounters an error
    
    .PARAMETER ArgumentList
    Arguments to pass to the script block
    #>
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [scriptblock]$OnComplete = {},
        
        [Parameter()]
        [scriptblock]$OnError = {},
        
        [Parameter()]
        [array]$ArgumentList = @()
    )
    
    try {
        # Start the job
        $job = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
        
        # Track the job for cleanup
        $script:TuiAsyncJobs += $job
        
        # Create a timer to check job status
        $timer = New-Object System.Timers.Timer
        $timer.Interval = 100  # Check every 100ms
        $timer.AutoReset = $true
        
        # Use Register-ObjectEvent to handle the timer tick
        $timerEvent = Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
            $job = $Event.MessageData.Job
            $onComplete = $Event.MessageData.OnComplete
            $onError = $Event.MessageData.OnError
            $timer = $Event.MessageData.Timer
            
            if ($job.State -eq 'Completed') {
                try {
                    $result = Receive-Job -Job $job -ErrorAction Stop
                    Remove-Job -Job $job -Force
                    
                    # Remove from tracking
                    $script:TuiAsyncJobs = @($script:TuiAsyncJobs | Where-Object { $_ -ne $job })
                    
                    # Stop and dispose timer
                    $timer.Stop()
                    $timer.Dispose()
                    Unregister-Event -SourceIdentifier $Event.SourceIdentifier
                    
                    # Call completion handler on UI thread
                    if ($onComplete) {
                        & $onComplete -Data $result
                        Request-TuiRefresh
                    }
                } catch {
                    Write-Warning "Job receive error: $_"
                }
            }
            elseif ($job.State -eq 'Failed') {
                try {
                    $error = $job.ChildJobs[0].JobStateInfo.Reason
                    Remove-Job -Job $job -Force
                    
                    # Remove from tracking
                    $script:TuiAsyncJobs = @($script:TuiAsyncJobs | Where-Object { $_ -ne $job })
                    
                    # Stop and dispose timer
                    $timer.Stop()
                    $timer.Dispose()
                    Unregister-Event -SourceIdentifier $Event.SourceIdentifier
                    
                    # Call error handler
                    if ($onError) {
                        & $onError -Error $error
                        Request-TuiRefresh
                    }
                } catch {
                    Write-Warning "Job error handling failed: $_"
                }
            }
        } -MessageData @{
            Job = $job
            OnComplete = $OnComplete
            OnError = $OnError
            Timer = $timer
        }
        
        # Start the timer
        $timer.Start()
        
        # Return job info
        return @{
            Job = $job
            Timer = $timer
            EventSubscription = $timerEvent
        }
        
    } catch {
        Write-Warning "Failed to start async operation: $_"
        if ($OnError) {
            & $OnError -Error $_
        }
    }
}

function global:Stop-AllTuiAsyncJobs {
    <#
    .SYNOPSIS
    Stops and cleans up all tracked async jobs
    #>
    
    foreach ($job in $script:TuiAsyncJobs) {
        try {
            if ($job.State -eq 'Running') {
                Stop-Job -Job $job -ErrorAction SilentlyContinue
            }
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Failed to stop job: $_"
        }
    }
    
    $script:TuiAsyncJobs = @()
    
    # Clean up any orphaned timer events
    Get-EventSubscriber | Where-Object { $_.SourceObject -is [System.Timers.Timer] } | ForEach-Object {
        try {
            Unregister-Event -SourceIdentifier $_.SourceIdentifier -ErrorAction SilentlyContinue
            if ($_.SourceObject) {
                $_.SourceObject.Stop()
                $_.SourceObject.Dispose()
            }
        } catch { }
    }
}

function global:Create-TuiState {
    <#
    .SYNOPSIS
    Creates a reactive state management system with deep change detection
    
    .PARAMETER InitialState
    The initial state values
    
    .PARAMETER DeepWatch
    Enable deep property change detection (impacts performance)
    #>
    param(
        [Parameter()]
        [hashtable]$InitialState = @{},
        
        [Parameter()]
        [bool]$DeepWatch = $false
    )
    
    $stateManager = @{
        _data = $InitialState.Clone()
        _subscribers = @{}
        _deepWatch = $DeepWatch
        _changeQueue = @()
        _processing = $false
        
        GetValue = {
            param([string]$Path)
            if (-not $Path) { return $this._data }
            
            $parts = $Path -split '\.'
            $current = $this._data
            
            foreach ($part in $parts) {
                if ($null -eq $current) { return $null }
                $current = $current[$part]
            }
            
            return $current
        }
        
        SetValue = {
            param([string]$Path, $Value)
            
            $parts = $Path -split '\.'
            $current = $this._data
            
            # Navigate to parent
            for ($i = 0; $i -lt $parts.Count - 1; $i++) {
                $part = $parts[$i]
                if (-not $current.ContainsKey($part)) {
                    $current[$part] = @{}
                }
                $current = $current[$part]
            }
            
            # Get old value for comparison
            $lastPart = $parts[-1]
            $oldValue = $current[$lastPart]
            
            # Set new value
            $current[$lastPart] = $Value
            
            # Notify if changed
            if (-not (Compare-TuiValue $oldValue $Value)) {
                & $this.NotifySubscribers -Path $Path -OldValue $oldValue -NewValue $Value
                
                # Also notify parent paths
                $parentPath = ""
                for ($i = 0; $i -lt $parts.Count; $i++) {
                    if ($i -gt 0) { $parentPath += "." }
                    $parentPath += $parts[$i]
                    & $this.NotifySubscribers -Path $parentPath -OldValue $null -NewValue (& $this.GetValue $parentPath)
                }
            }
        }
        
        Update = {
            param([hashtable]$Updates)
            
            # Queue changes to batch notifications
            $this._changeQueue = @()
            
            foreach ($key in $Updates.Keys) {
                $oldValue = $this._data[$key]
                $this._data[$key] = $Updates[$key]
                
                if (-not (Compare-TuiValue $oldValue $Updates[$key])) {
                    $this._changeQueue += @{
                        Path = $key
                        OldValue = $oldValue
                        NewValue = $Updates[$key]
                    }
                }
            }
            
            # Process all notifications
            if ($this._changeQueue.Count -gt 0 -and -not $this._processing) {
                $this._processing = $true
                try {
                    foreach ($change in $this._changeQueue) {
                        & $this.NotifySubscribers @change
                    }
                } finally {
                    $this._processing = $false
                    $this._changeQueue = @()
                }
            }
        }
        
        Subscribe = {
            param(
                [string]$Path,
                [scriptblock]$Handler,
                [string]$SubscriptionId = [Guid]::NewGuid().ToString()
            )
            
            if (-not $this._subscribers.ContainsKey($Path)) {
                $this._subscribers[$Path] = @()
            }
            
            $this._subscribers[$Path] += @{
                Id = $SubscriptionId
                Handler = $Handler
            }
            
            # Call handler with current value
            $currentValue = & $this.GetValue $Path
            try {
                & $Handler -NewValue $currentValue -OldValue $null -Path $Path
            } catch {
                Write-Warning "State subscriber error: $_"
            }
            
            return $SubscriptionId
        }
        
        Unsubscribe = {
            param([string]$SubscriptionId)
            
            foreach ($path in @($this._subscribers.Keys)) {
                $this._subscribers[$path] = @($this._subscribers[$path] | Where-Object { $_.Id -ne $SubscriptionId })
                if ($this._subscribers[$path].Count -eq 0) {
                    $this._subscribers.Remove($path)
                }
            }
        }
        
        NotifySubscribers = {
            param([string]$Path, $OldValue, $NewValue)
            
            # Exact path subscribers
            if ($this._subscribers.ContainsKey($Path)) {
                foreach ($sub in $this._subscribers[$Path]) {
                    try {
                        & $sub.Handler -NewValue $NewValue -OldValue $OldValue -Path $Path
                    } catch {
                        Write-Warning "State notification error: $_"
                    }
                }
            }
            
            # Wildcard subscribers (e.g., "user.*")
            foreach ($subPath in $this._subscribers.Keys) {
                if ($subPath.EndsWith('*')) {
                    $basePath = $subPath.TrimEnd('*').TrimEnd('.')
                    if ($Path.StartsWith($basePath)) {
                        foreach ($sub in $this._subscribers[$subPath]) {
                            try {
                                & $sub.Handler -NewValue $NewValue -OldValue $OldValue -Path $Path
                            } catch {
                                Write-Warning "State wildcard notification error: $_"
                            }
                        }
                    }
                }
            }
        }
        
        Reset = {
            param([hashtable]$NewState = @{})
            $oldData = $this._data
            $this._data = $NewState.Clone()
            
            # Notify all subscribers of reset
            foreach ($path in $this._subscribers.Keys) {
                $oldValue = Get-NestedProperty -Object $oldData -Path $path
                $newValue = & $this.GetValue $path
                
                if (-not (Compare-TuiValue $oldValue $newValue)) {
                    & $this.NotifySubscribers -Path $path -OldValue $oldValue -NewValue $newValue
                }
            }
        }
    }
    
    return $stateManager
}

function Compare-TuiValue {
    <#
    .SYNOPSIS
    Compares two values for equality, handling nulls and complex types
    #>
    param($Value1, $Value2)
    
    if ($null -eq $Value1 -and $null -eq $Value2) { return $true }
    if ($null -eq $Value1 -or $null -eq $Value2) { return $false }
    
    if ($Value1 -is [hashtable] -and $Value2 -is [hashtable]) {
        if ($Value1.Count -ne $Value2.Count) { return $false }
        foreach ($key in $Value1.Keys) {
            if (-not $Value2.ContainsKey($key)) { return $false }
            if (-not (Compare-TuiValue $Value1[$key] $Value2[$key])) { return $false }
        }
        return $true
    }
    
    if ($Value1 -is [array] -and $Value2 -is [array]) {
        if ($Value1.Count -ne $Value2.Count) { return $false }
        for ($i = 0; $i -lt $Value1.Count; $i++) {
            if (-not (Compare-TuiValue $Value1[$i] $Value2[$i])) { return $false }
        }
        return $true
    }
    
    return $Value1 -eq $Value2
}

function Get-NestedProperty {
    param($Object, $Path)
    
    $parts = $Path -split '\.'
    $current = $Object
    
    foreach ($part in $parts) {
        if ($null -eq $current) { return $null }
        $current = $current[$part]
    }
    
    return $current
}

function global:Remove-TuiComponent {
    <#
    .SYNOPSIS
    Properly removes a component and cleans up references to prevent memory leaks
    
    .PARAMETER Component
    The component to remove
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Component
    )
    
    try {
        # Remove event handlers if the component has an ID or Name
        $componentId = if ($Component.Id) { $Component.Id } elseif ($Component.Name) { $Component.Name } else { $null }
        
        if ($componentId -and (Get-Command -Name "Remove-ComponentEventHandlers" -ErrorAction SilentlyContinue)) {
            Remove-ComponentEventHandlers -ComponentId $componentId
        }
        
        # Clear focus if this component is focused
        if ($global:TuiState -and $global:TuiState.FocusedComponent -eq $Component) {
            if (Get-Command -Name "Clear-ComponentFocus" -ErrorAction SilentlyContinue) {
                Clear-ComponentFocus
            } else {
                $global:TuiState.FocusedComponent = $null
            }
        }
        
        # Break circular references
        if ($Component.Parent) {
            # Remove from parent's children collection
            if ($Component.Parent._children -and $Component.Name) {
                $Component.Parent._children.Remove($Component.Name)
            }
            if ($Component.Parent.Children) {
                $Component.Parent.Children = @($Component.Parent.Children | Where-Object { $_ -ne $Component })
            }
            $Component.Parent = $null
        }
        
        if ($Component.ParentScreen) {
            # Remove from parent screen's children
            if ($Component.ParentScreen._children -and $Component.Name) {
                $Component.ParentScreen._children.Remove($Component.Name)
            }
            # Remove from focusable names
            if ($Component.ParentScreen._focusableNames) {
                $Component.ParentScreen._focusableNames = @($Component.ParentScreen._focusableNames | Where-Object { $_ -ne $Component.Name })
            }
            $Component.ParentScreen = $null
        }
        
        # Clear children references
        if ($Component.Children) {
            foreach ($child in $Component.Children) {
                if ($child -is [hashtable]) {
                    $child.Parent = $null
                    $child.ParentScreen = $null
                }
            }
            $Component.Children = @()
        }
        
        if ($Component._children) {
            foreach ($childName in @($Component._children.Keys)) {
                $child = $Component._children[$childName]
                if ($child -is [hashtable]) {
                    $child.Parent = $null
                    $child.ParentScreen = $null
                }
            }
            $Component._children.Clear()
        }
        
        # Call component's dispose method if it exists
        if ($Component.Dispose) {
            try {
                & $Component.Dispose -self $Component
            } catch {
                Write-Warning "Component dispose error: $_"
            }
        }
        
        # Clear any async operations or timers
        if ($Component._timers) {
            foreach ($timer in $Component._timers) {
                if ($timer -and $timer.Enabled) {
                    $timer.Stop()
                    $timer.Dispose()
                }
            }
            $Component._timers = @()
        }
        
        # Clear state subscriptions
        if ($Component._stateSubscriptions) {
            foreach ($sub in $Component._stateSubscriptions) {
                if ($sub -and (Get-Command -Name "Unsubscribe-Event" -ErrorAction SilentlyContinue)) {
                    try {
                        Unsubscribe-Event -HandlerId $sub
                    } catch { }
                }
            }
            $Component._stateSubscriptions = @()
        }
        
        # Remove from global component registry if registered
        if ($global:TuiState -and $global:TuiState.Components) {
            $global:TuiState.Components = @($global:TuiState.Components | Where-Object { $_ -ne $Component })
        }
        
        Write-Verbose "Component removed: $componentId"
        
    } catch {
        Write-Warning "Error removing component: $_"
    }
}

# Export all functions
Export-ModuleMember -Function @(
    'Initialize-TuiFramework',
    'Invoke-TuiAsync',
    'Stop-AllTuiAsyncJobs',
    'Create-TuiState',
    'Compare-TuiValue',
    'Remove-TuiComponent',
    'Invoke-TuiMethod'
)