# FILE: services/app-store.psm1
# PURPOSE: Provides a single, reactive source of truth for all shared application state using a Redux-like pattern.

function Initialize-AppStore {
    param(
        [hashtable]$InitialData = @{},
        [bool]$EnableDebugLogging = $false
    )
    
    # Initialize state structure properly
    $stateData = if ($InitialData) { $InitialData.Clone() } else { @{} }
    
    $store = @{
        _state = @{
            _data = $stateData
            _subscribers = @{}
            _changeQueue = @()
        }
        _actions = @{}
        _middleware = @()
        _history = @()  # For time-travel debugging
        _enableDebugLogging = $EnableDebugLogging
        
        GetState = { 
            param($self, [string]$path = $null) 
            if ([string]::IsNullOrEmpty($path)) {
                # Directly access state data
                return $self._state._data
            }
            # Navigate path manually
            $parts = $path -split '\.'
            $current = $self._state._data
            foreach ($part in $parts) {
                if ($null -eq $current) { return $null }
                $current = $current[$part]
            }
            return $current
        }
        
        Subscribe = { 
            param($self, [string]$path, [scriptblock]$handler, [bool]$DeferInitialCall = $false) 
            if (-not $handler) { throw "Handler scriptblock is required for Subscribe" }
            
            # Manually implement subscribe to avoid $this issues
            $state = $self._state
            $subId = [Guid]::NewGuid().ToString()
            
            if (-not $state._subscribers) { $state._subscribers = @{} }
            if (-not $state._subscribers.ContainsKey($path)) {
                $state._subscribers[$path] = @()
            }
            
            $state._subscribers[$path] += @{
                Id = $subId
                Handler = $handler
            }
            
            # Call handler with current value unless deferred
            if (-not $DeferInitialCall) {
                $currentValue = & $self.GetState -self $self -path $path
                try {
                    & $handler @{ NewValue = $currentValue; OldValue = $null; Path = $path }
                } catch {
                    Write-Warning "State subscriber error: $_"
                }
            }
            
            return $subId
        }
        
        Unsubscribe = { 
            param($self, $subId) 
            if ($subId -and $self._state._subscribers) {
                # Manually remove subscription
                foreach ($path in @($self._state._subscribers.Keys)) {
                    $self._state._subscribers[$path] = @($self._state._subscribers[$path] | Where-Object { $_.Id -ne $subId })
                    if ($self._state._subscribers[$path].Count -eq 0) {
                        $self._state._subscribers.Remove($path)
                    }
                }
            }
        }
        
        RegisterAction = { 
            param($self, [string]$actionName, [scriptblock]$scriptBlock) 
            if ([string]::IsNullOrWhiteSpace($actionName)) { throw "Action name cannot be empty" }
            if (-not $scriptBlock) { throw "Script block is required for action '$actionName'" }
            $self._actions[$actionName] = $scriptBlock 
            if ($self._enableDebugLogging) { Write-Log -Level Debug -Message "Registered action: $actionName" }
        }
        
        AddMiddleware = {
            param($self, [scriptblock]$middleware)
            $self._middleware += $middleware
        }
        
        Dispatch = {
            param($self, [string]$actionName, $payload = $null)
            
            if ([string]::IsNullOrWhiteSpace($actionName)) { return @{ Success = $false; Error = "Action name cannot be empty" } }
            
            $action = @{ Type = $actionName; Payload = $payload; Timestamp = [DateTime]::UtcNow }
            
            foreach ($mw in $self._middleware) {
                if ($null -ne $mw) {
                    $action = & $mw -Action $action -Store $self
                    if (-not $action) { return @{ Success = $false; Error = "Action cancelled by middleware" } }
                }
            }
            
            if (-not $self._actions.ContainsKey($actionName)) {
                if ($self._enableDebugLogging) { Write-Log -Level Warning -Message "Action '$actionName' not found." }
                return @{ Success = $false; Error = "Action '$actionName' not registered." }
            }
            
            if ($self._enableDebugLogging) { Write-Log -Level Debug -Message "Dispatching action '$actionName'" -Data $payload }
            
            try {
                $previousState = & $self.GetState -self $self
                
                # Create action context with fixed UpdateState
                $storeInstance = $self
                $actionContext = @{
                    GetState = { 
                        param($path = $null) 
                        $store = $storeInstance
                        if ($path) {
                            return & $store.GetState -self $store -path $path
                        } else {
                            return & $store.GetState -self $store
                        }
                    }.GetNewClosure()
                    
                    UpdateState = { 
                        param($updates) 
                        $store = $storeInstance
                        if (-not $updates -or $updates.Count -eq 0) { 
                            Write-Log -Level Debug -Message "UpdateState called with empty updates"
                            return 
                        }
                        
                        Write-Log -Level Debug -Message "UpdateState called with keys: $($updates.Keys -join ', ')"
                        
                        # Use direct update method that handles all the complexity
                        try {
                            & $store._directUpdateState -self $store -updates $updates
                            Write-Log -Level Debug -Message "UpdateState: Successfully updated state"
                        } catch {
                            Write-Log -Level Error -Message "UpdateState failed: $_"
                            throw
                        }
                    }.GetNewClosure()
                    
                    Dispatch = { 
                        param($name, $p = $null) 
                        $store = $storeInstance
                        return & $store.Dispatch -self $store -actionName $name -payload $p
                    }.GetNewClosure()
                }
                
                # Execute the action
                & $self._actions[$actionName] -Context $actionContext -Payload $payload
                
                # Update history
                if ($self._history.Count -gt 100) { $self._history = $self._history[-100..-1] }
                $self._history += @{ Action = $action; PreviousState = $previousState; NextState = (& $self.GetState -self $self) }
                
                return @{ Success = $true }
            } 
            catch {
                throw [StateMutationException]::new(
                    "Error executing action '$actionName'",
                    @{
                        ActionName = $actionName
                        Payload = $payload
                        OriginalException = $_
                    }
                )
            }
        }
        
        _updateState = { 
            param($self, [hashtable]$updates)
            if ($updates -and $self._state) {
                # Direct update implementation
                $state = $self._state
                foreach ($key in $updates.Keys) {
                    $oldValue = $state._data[$key]
                    $state._data[$key] = $updates[$key]
                    
                    if ($oldValue -ne $updates[$key] -and $state._subscribers -and $state._subscribers.ContainsKey($key)) {
                        foreach ($sub in $state._subscribers[$key]) {
                            try {
                                & $sub.Handler @{ NewValue = $updates[$key]; OldValue = $oldValue; Path = $key }
                            } catch {
                                Write-Warning "State notification error: $_"
                            }
                        }
                    }
                }
            }
        }
        
        _directUpdateState = {
            param($self, [hashtable]$updates)
            if (-not $updates -or $updates.Count -eq 0) { return }
            
            Write-Log -Level Debug -Message "_directUpdateState called with $($updates.Count) updates"
            
            # Ensure state structure exists
            $state = $self._state
            if (-not $state._data) { $state._data = @{} }
            
            # Helper function to set nested paths
            $setNestedValue = {
                param($obj, $path, $value)
                $parts = $path -split '\.'
                $current = $obj
                for ($i = 0; $i -lt $parts.Count - 1; $i++) {
                    if (-not $current.ContainsKey($parts[$i])) {
                        $current[$parts[$i]] = @{}
                    }
                    $current = $current[$parts[$i]]
                }
                $current[$parts[-1]] = $value
            }
            
            # Process updates
            foreach ($key in $updates.Keys) {
                $newValue = $updates[$key]
                
                if ($key.Contains('.')) {
                    # Handle nested paths like "stats.todayHours"
                    $oldValue = & $self.GetState -self $self -path $key
                    & $setNestedValue -obj $state._data -path $key -value $newValue
                } else {
                    # Handle simple keys
                    $oldValue = $state._data[$key]
                    $state._data[$key] = $newValue
                }
                
                # Notify subscribers for exact path
                if ($state._subscribers -and $state._subscribers.ContainsKey($key)) {
                    foreach ($sub in $state._subscribers[$key]) {
                        try {
                            & $sub.Handler @{ NewValue = $newValue; OldValue = $oldValue; Path = $key }
                        } catch {
                            Write-Warning "Subscriber notification error for '$key': $_"
                        }
                    }
                }
                
                # Also notify parent path subscribers for nested updates
                if ($key.Contains('.')) {
                    $parts = $key -split '\.'
                    $parentPath = $parts[0]
                    if ($state._subscribers -and $state._subscribers.ContainsKey($parentPath)) {
                        $parentValue = $state._data[$parentPath]
                        foreach ($sub in $state._subscribers[$parentPath]) {
                            try {
                                & $sub.Handler @{ NewValue = $parentValue; OldValue = $parentValue; Path = $parentPath }
                            } catch {
                                Write-Warning "Parent subscriber notification error for '$parentPath': $_"
                            }
                        }
                    }
                }
            }
        }
        
        GetHistory = { param($self) ; return $self._history }
        
        RestoreState = {
            param($self, [int]$stepsBack = 1)
            if ($stepsBack -gt $self._history.Count) { throw "Cannot go back $stepsBack steps. Only $($self._history.Count) actions in history." }
            $targetState = $self._history[-$stepsBack].PreviousState
            & $self._updateState -self $self -updates $targetState
        }
    }
    
    # Register built-in actions
    & $store.RegisterAction -self $store -actionName "RESET_STATE" -scriptBlock {
        param($Context, $Payload)
        & $Context.UpdateState $InitialData
    }
    
    & $store.RegisterAction -self $store -actionName "UPDATE_STATE" -scriptBlock {
        param($Context, $Payload)
        if ($Payload -is [hashtable]) {
            & $Context.UpdateState $Payload
        }
    }
    
    return $store
}

Export-ModuleMember -Function "Initialize-AppStore"