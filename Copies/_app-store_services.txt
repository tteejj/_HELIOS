# FILE: services/app-store.psm1
# PURPOSE: Provides a single, reactive source of truth for all shared application state using a Redux-like pattern.

function Initialize-AppStore {
    param(
        [hashtable]$InitialData = @{},
        [bool]$EnableDebugLogging = $false
    )
    
    # Ensure Create-TuiState exists
    if (-not (Get-Command -Name "Create-TuiState" -ErrorAction SilentlyContinue)) {
        throw "Create-TuiState not found. Ensure tui-framework.psm1 is loaded first."
    }
    
    $store = @{
        _state = (Create-TuiState -InitialState $InitialData)
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
            param($self, [string]$path, [scriptblock]$handler) 
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
            
            # Call handler with current value
            $currentValue = & $self.GetState -self $self -path $path
            try {
                & $handler @{ NewValue = $currentValue; OldValue = $null; Path = $path }
            } catch {
                Write-Warning "State subscriber error: $_"
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
                        if (-not $updates -or $updates.Count -eq 0) { return }
                        
                        Write-Host "[DEBUG] UpdateState called with $($updates.Count) updates" -ForegroundColor Yellow
                        
                        # Direct state update without using internal methods
                        $state = $store._state
                        if (-not $state._data) { $state._data = @{} }
                        
                        foreach ($key in $updates.Keys) {
                            $oldValue = $state._data[$key]
                            $newValue = $updates[$key]
                            $state._data[$key] = $newValue
                            
                            Write-Host "[DEBUG] Updated '$key': $oldValue -> $newValue" -ForegroundColor Yellow
                            
                            # Notify subscribers
                            if ($state._subscribers -and $state._subscribers.ContainsKey($key)) {
                                foreach ($sub in $state._subscribers[$key]) {
                                    try {
                                        Write-Host "[DEBUG] Notifying subscriber for '$key'" -ForegroundColor Yellow
                                        & $sub.Handler @{ NewValue = $newValue; OldValue = $oldValue; Path = $key }
                                    } catch {
                                        Write-Warning "Subscriber notification error for '$key': $_"
                                    }
                                }
                            }
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
                if ($self._enableDebugLogging) { Write-Log -Level Error -Message "Error in action handler '$actionName'" -Data $_ }
                Write-Host "[DEBUG] Action dispatch error: $_" -ForegroundColor Red
                return @{ Success = $false; Error = $_.ToString() }
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