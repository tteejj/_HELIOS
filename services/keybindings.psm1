# FILE: services/keybindings.psm1
# PURPOSE: Centralizes keybinding logic to make them configurable and declarative.

function Initialize-KeybindingService {
    param(
        [hashtable]$CustomBindings = @{},
        [bool]$EnableChords = $false  # For future multi-key sequences
    )
    
    # Default keybindings - can be overridden
    $defaultKeyMap = @{
        # Application-level
        "App.Quit" = @{ Key = 'Q'; Modifiers = @() }
        "App.ForceQuit" = @{ Key = 'Q'; Modifiers = @('Ctrl') }
        "App.Back" = @{ Key = [ConsoleKey]::Escape; Modifiers = @() }
        "App.Refresh" = @{ Key = 'R'; Modifiers = @() }
        "App.DebugLog" = @{ Key = [ConsoleKey]::F12; Modifiers = @() }
        "App.Help" = @{ Key = [ConsoleKey]::F1; Modifiers = @() }
        
        # List operations
        "List.New" = @{ Key = 'N'; Modifiers = @() }
        "List.Edit" = @{ Key = 'E'; Modifiers = @() }
        "List.Delete" = @{ Key = 'D'; Modifiers = @() }
        "List.Toggle" = @{ Key = [ConsoleKey]::Spacebar; Modifiers = @() }
        "List.SelectAll" = @{ Key = 'A'; Modifiers = @('Ctrl') }
        
        # Navigation
        "Nav.Up" = @{ Key = [ConsoleKey]::UpArrow; Modifiers = @() }
        "Nav.Down" = @{ Key = [ConsoleKey]::DownArrow; Modifiers = @() }
        "Nav.Left" = @{ Key = [ConsoleKey]::LeftArrow; Modifiers = @() }
        "Nav.Right" = @{ Key = [ConsoleKey]::RightArrow; Modifiers = @() }
        "Nav.PageUp" = @{ Key = [ConsoleKey]::PageUp; Modifiers = @() }
        "Nav.PageDown" = @{ Key = [ConsoleKey]::PageDown; Modifiers = @() }
        "Nav.Home" = @{ Key = [ConsoleKey]::Home; Modifiers = @() }
        "Nav.End" = @{ Key = [ConsoleKey]::End; Modifiers = @() }
        
        # Quick navigation (number keys)
        "QuickNav.1" = @{ Key = '1'; Modifiers = @() }
        "QuickNav.2" = @{ Key = '2'; Modifiers = @() }
        "QuickNav.3" = @{ Key = '3'; Modifiers = @() }
        "QuickNav.4" = @{ Key = '4'; Modifiers = @() }
        "QuickNav.5" = @{ Key = '5'; Modifiers = @() }
        "QuickNav.6" = @{ Key = '6'; Modifiers = @() }
        "QuickNav.7" = @{ Key = '7'; Modifiers = @() }
        "QuickNav.8" = @{ Key = '8'; Modifiers = @() }
        "QuickNav.9" = @{ Key = '9'; Modifiers = @() }
        
        # Form operations
        "Form.Submit" = @{ Key = [ConsoleKey]::Enter; Modifiers = @('Ctrl') }
        "Form.Cancel" = @{ Key = [ConsoleKey]::Escape; Modifiers = @() }
        "Form.Clear" = @{ Key = 'C'; Modifiers = @('Ctrl', 'Shift') }
        
        # Text editing
        "Edit.Cut" = @{ Key = 'X'; Modifiers = @('Ctrl') }
        "Edit.Copy" = @{ Key = 'C'; Modifiers = @('Ctrl') }
        "Edit.Paste" = @{ Key = 'V'; Modifiers = @('Ctrl') }
        "Edit.Undo" = @{ Key = 'Z'; Modifiers = @('Ctrl') }
        "Edit.Redo" = @{ Key = 'Y'; Modifiers = @('Ctrl') }
    }
    
    # Merge custom bindings
    $keyMap = $defaultKeyMap
    foreach ($action in $CustomBindings.Keys) {
        $keyMap[$action] = $CustomBindings[$action]
    }
    
    $service = @{
        _keyMap = $keyMap
        _enableChords = $EnableChords
        _chordBuffer = @()
        _chordTimeout = 1000  # milliseconds
        _lastKeyTime = [DateTime]::MinValue
        _contextStack = @()  # For context-specific bindings
        _globalHandlers = @{}  # Action name -> handler scriptblock
        
        IsAction = {
            param(
                [string]$ActionName, 
                [System.ConsoleKeyInfo]$KeyInfo,
                [string]$Context = $null
            )
            
            if ([string]::IsNullOrWhiteSpace($ActionName)) {
                return $false
            }
            
            # Check context-specific binding first
            $contextKey = if ($Context) { "$Context.$ActionName" } else { $null }
            if ($contextKey -and $service._keyMap.ContainsKey($contextKey)) {
                return $service._matchesBinding($service._keyMap[$contextKey], $KeyInfo)
            }
            
            # Check global binding
            if (-not $service._keyMap.ContainsKey($ActionName)) { 
                return $false 
            }
            
            return $service._matchesBinding($service._keyMap[$ActionName], $KeyInfo)
        }
        
        _matchesBinding = {
            param($binding, $keyInfo)
            
            # Match key
            $keyMatches = $false
            if ($binding.Key -is [System.ConsoleKey]) {
                $keyMatches = $keyInfo.Key -eq $binding.Key
            }
            elseif ($binding.Key -is [string] -and $binding.Key.Length -eq 1) {
                $keyMatches = $keyInfo.KeyChar.ToString().Equals($binding.Key, [System.StringComparison]::InvariantCultureIgnoreCase)
            }
            
            if (-not $keyMatches) {
                return $false
            }
            
            # Match modifiers
            $requiredModifiers = $binding.Modifiers ?? @()
            $hasCtrl = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Control) -ne 0
            $hasAlt = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Alt) -ne 0
            $hasShift = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift) -ne 0
            
            $ctrlRequired = 'Ctrl' -in $requiredModifiers
            $altRequired = 'Alt' -in $requiredModifiers
            $shiftRequired = 'Shift' -in $requiredModifiers
            
            return ($hasCtrl -eq $ctrlRequired) -and 
                   ($hasAlt -eq $altRequired) -and 
                   ($hasShift -eq $shiftRequired)
        }
        
        GetBinding = {
            param([string]$ActionName)
            return $service._keyMap[$ActionName]
        }
        
        SetBinding = {
            param(
                [string]$ActionName,
                $Key,
                [string[]]$Modifiers = @()
            )
            
            $service._keyMap[$ActionName] = @{
                Key = $Key
                Modifiers = $Modifiers
            }
            
            Write-Log -Level Debug -Message "Set keybinding for '$ActionName': $Key + $($Modifiers -join '+')"
        }
        
        RemoveBinding = {
            param([string]$ActionName)
            $service._keyMap.Remove($ActionName)
            Write-Log -Level Debug -Message "Removed keybinding for '$ActionName'"
        }
        
        GetBindingDescription = {
            param([string]$ActionName)
            
            if (-not $service._keyMap.ContainsKey($ActionName)) {
                return $null
            }
            
            $binding = $service._keyMap[$ActionName]
            $keyStr = if ($binding.Key -is [System.ConsoleKey]) {
                $binding.Key.ToString()
            } else {
                $binding.Key.ToString().ToUpper()
            }
            
            if ($binding.Modifiers.Count -gt 0) {
                return "$($binding.Modifiers -join '+') + $keyStr"
            }
            
            return $keyStr
        }
        
        RegisterGlobalHandler = {
            param(
                [string]$ActionName,
                [scriptblock]$Handler
            )
            
            $service._globalHandlers[$ActionName] = $Handler
            Write-Log -Level Debug -Message "Registered global handler for '$ActionName'"
        }
        
        HandleKey = {
            param(
                [System.ConsoleKeyInfo]$KeyInfo,
                [string]$Context = $null
            )
            
            # Check all registered actions
            foreach ($action in $service._keyMap.Keys) {
                if ($service.IsAction($action, $KeyInfo, $Context)) {
                    # Execute global handler if registered
                    if ($service._globalHandlers.ContainsKey($action)) {
                        Write-Log -Level Debug -Message "Executing global handler for '$action'"
                        return & $service._globalHandlers[$action] -KeyInfo $KeyInfo -Context $Context
                    }
                    
                    # Return the action name for the caller to handle
                    return $action
                }
            }
            
            return $null
        }
        
        PushContext = {
            param([string]$Context)
            $service._contextStack += $Context
            Write-Log -Level Debug -Message "Pushed keybinding context: $Context"
        }
        
        PopContext = {
            if ($service._contextStack.Count -gt 0) {
                $context = $service._contextStack[-1]
                $service._contextStack = $service._contextStack[0..($service._contextStack.Count - 2)]
                Write-Log -Level Debug -Message "Popped keybinding context: $context"
                return $context
            }
            return $null
        }
        
        GetCurrentContext = {
            if ($service._contextStack.Count -gt 0) {
                return $service._contextStack[-1]
            }
            return $null
        }
        
        GetAllBindings = {
            param([bool]$GroupByCategory = $false)
            
            if (-not $GroupByCategory) {
                return $service._keyMap
            }
            
            # Group by category (part before the dot)
            $grouped = @{}
            foreach ($action in $service._keyMap.Keys) {
                $parts = $action.Split('.')
                $category = if ($parts.Count -gt 1) { $parts[0] } else { "General" }
                
                if (-not $grouped.ContainsKey($category)) {
                    $grouped[$category] = @{}
                }
                
                $grouped[$category][$action] = $service._keyMap[$action]
            }
            
            return $grouped
        }
        
        ExportBindings = {
            param([string]$Path)
            $service._keyMap | ConvertTo-Json -Depth 3 | Out-File -FilePath $Path
            Write-Log -Level Info -Message "Exported keybindings to: $Path"
        }
        
        ImportBindings = {
            param([string]$Path)
            if (Test-Path $Path) {
                $imported = Get-Content $Path | ConvertFrom-Json
                foreach ($prop in $imported.PSObject.Properties) {
                    $service._keyMap[$prop.Name] = @{
                        Key = $prop.Value.Key
                        Modifiers = $prop.Value.Modifiers
                    }
                }
                Write-Log -Level Info -Message "Imported keybindings from: $Path"
            }
        }
    }
    
    return $service
}

Export-ModuleMember -Function "Initialize-KeybindingService"
