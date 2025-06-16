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
    
    $stateObject = Create-TuiState -InitialState $InitialData
    
    $store = @{
        _state = $stateObject
        _actions = @{}
        _middleware = @()
        _history = @()  # For time-travel debugging
        _enableDebugLogging = $EnableDebugLogging
        
        GetState = { 
            param([string]$path = $null) 
            if ([string]::IsNullOrEmpty($path)) {
                return $store._state.GetValue()
            }
            return $store._state.GetValue($path) 
        }
        
        Subscribe = { 
            param(
                [string]$path, 
                [scriptblock]$handler
            ) 
            if (-not $handler) {
                throw "Handler scriptblock is required for Subscribe"
            }
            return $store._state.Subscribe($path, $handler) 
        }
        
        Unsubscribe = { 
            param($subId) 
            if ($subId) {
                $store._state.Unsubscribe($subId) 
            }
        }
        
        RegisterAction = { 
            param(
                [string]$actionName, 
                [scriptblock]$scriptBlock
            ) 
            if ([string]::IsNullOrWhiteSpace($actionName)) {
                throw "Action name cannot be empty"
            }
            if (-not $scriptBlock) {
                throw "Script block is required for action '$actionName'"
            }
            $store._actions[$actionName] = $scriptBlock 
            if ($store._enableDebugLogging) {
                Write-Log -Level Debug -Message "Registered action: $actionName"
            }
        }
        
        AddMiddleware = {
            param([scriptblock]$middleware)
            $store._middleware += $middleware
        }
        
        Dispatch = {
            param(
                [string]$actionName, 
                $payload = $null
            )
            
            if ([string]::IsNullOrWhiteSpace($actionName)) {
                return @{ Success = $false; Error = "Action name cannot be empty" }
            }
            
            # Create action object
            $action = @{
                Type = $actionName
                Payload = $payload
                Timestamp = [DateTime]::UtcNow
            }
            
            # Run through middleware
            foreach ($mw in $store._middleware) {
                $action = & $mw -Action $action -Store $store
                if (-not $action) {
                    # Middleware can cancel action by returning null
                    return @{ Success = $false; Error = "Action cancelled by middleware" }
                }
            }
            
            if (-not $store._actions.ContainsKey($actionName)) {
                if ($store._enableDebugLogging) {
                    Write-Log -Level Warning -Message "Action '$actionName' not found."
                }
                return @{ Success = $false; Error = "Action '$actionName' not registered." }
            }
            
            if ($store._enableDebugLogging -and (Get-Command -Name "Write-Log" -ErrorAction SilentlyContinue)) {
                Write-Log -Level Debug -Message "Dispatching action '$actionName'" -Data $payload
            }
            
            try {
                # Store previous state for potential rollback
                $previousState = $store.GetState()
                
                # Execute action with store context
                $actionContext = @{
                    GetState = $store.GetState
                    UpdateState = $store._updateState
                    Dispatch = $store.Dispatch
                }
                
                & $store._actions[$actionName] -Context $actionContext -Payload $payload
                
                # Add to history for debugging
                if ($store._history.Count -gt 100) {
                    $store._history = $store._history[-100..-1]  # Keep last 100 actions
                }
                $store._history += @{
                    Action = $action
                    PreviousState = $previousState
                    NextState = $store.GetState()
                }
                
                return @{ Success = $true }
            } 
            catch {
                if ($store._enableDebugLogging -and (Get-Command -Name "Write-Log" -ErrorAction SilentlyContinue)) {
                    Write-Log -Level Error -Message "Error in action handler '$actionName'" -Data $_
                }
                return @{ Success = $false; Error = $_.ToString() }
            }
        }
        
        _updateState = { 
            param([hashtable]$updates)
            if (-not $updates) {
                return
            }
            $store._state.Update($updates) 
        }
        
        GetHistory = {
            return $store._history
        }
        
        # Development helper: Time-travel to previous state
        RestoreState = {
            param([int]$stepsBack = 1)
            if ($stepsBack -gt $store._history.Count) {
                throw "Cannot go back $stepsBack steps. Only $($store._history.Count) actions in history."
            }
            $targetState = $store._history[-$stepsBack].PreviousState
            $store._updateState($targetState)
        }
    }
    
    # Register built-in actions
    & $store.RegisterAction -actionName "RESET_STATE" -scriptBlock {
        param($Context, $Payload)
        $Context.UpdateState($InitialData)
    }
    
    & $store.RegisterAction -actionName "UPDATE_STATE" -scriptBlock {
        param($Context, $Payload)
        if ($Payload -is [hashtable]) {
            $Context.UpdateState($Payload)
        }
    }
    
    return $store
}

Export-ModuleMember -Function "Initialize-AppStore"
