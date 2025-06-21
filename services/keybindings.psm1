@{
    # Module manifest for keybindings service
    RootModule = 'keybindings.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'c3d4e5f6-7a8b-9c0d-1e2f-3a4b5c6d7e8f'
    Author = 'PMC Terminal Team'
    CompanyName = 'PMC Terminal'
    Copyright = '(c) 2025 PMC Terminal. All rights reserved.'
    Description = 'Centralized keybinding management service with context support for PMC Terminal'
    
    # Minimum PowerShell version
    PowerShellVersion = '5.1'
    
    # Functions to export
    FunctionsToExport = @('Initialize-KeybindingService')
    
    # Variables to export
    VariablesToExport = @()
    
    # Aliases to export
    AliasesToExport = @()
    
    # Cmdlets to export
    CmdletsToExport = @()
    
    # Required modules
    RequiredModules = @()
    
    # Module dependencies that must be loaded
    NestedModules = @()
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('Keybindings', 'Input', 'TUI', 'PMC')
            ProjectUri = 'https://github.com/pmc-terminal/pmc-terminal'
            ReleaseNotes = 'Initial release of keybinding service with context-aware bindings and chord support'
        }
    }
}
# FILE: services/keybindings.psm1
# PURPOSE: Centralizes keybinding logic to make them configurable and declarative.

function Initialize-KeybindingService {
    param(
        [hashtable]$CustomBindings = @{},
        [bool]$EnableChords = $false  # For future multi-key sequences
    )
    Invoke-WithErrorHandling -Component "KeybindingService.Initialize" -ScriptBlock {
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
                    $self,
                    [string]$ActionName, 
                    [System.ConsoleKeyInfo]$KeyInfo,
                    [string]$Context = $null
                )
                Invoke-WithErrorHandling -Component "KeybindingService.IsAction" -ScriptBlock {
                    if ([string]::IsNullOrWhiteSpace($ActionName)) { return $false }
                    
                    # Check context-specific binding first
                    $contextKey = if ($Context) { "$Context.$ActionName" } else { $null }
                    if ($contextKey -and $self._keyMap.ContainsKey($contextKey)) {
                        return (& $self._matchesBinding -self $self -binding $self._keyMap[$contextKey] -keyInfo $KeyInfo)
                    }
                    
                    # Check global binding
                    if (-not $self._keyMap.ContainsKey($ActionName)) { return $false }
                    
                    return (& $self._matchesBinding -self $self -binding $self._keyMap[$ActionName] -keyInfo $KeyInfo)
                } -Context @{ ActionName = $ActionName; KeyInfo = $KeyInfo; Context = $Context } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "KeybindingService IsAction error: $($Exception.Message)" -Data $Exception.Context
                    return $false
                }
            }
            
            _matchesBinding = {
                param($self, $binding, $keyInfo)
                Invoke-WithErrorHandling -Component "KeybindingService._matchesBinding" -ScriptBlock {
                    # Match key
                    $keyMatches = $false
                    if ($binding.Key -is [System.ConsoleKey]) {
                        $keyMatches = $keyInfo.Key -eq $binding.Key
                    }
                    elseif ($binding.Key -is [string] -and $binding.Key.Length -eq 1) {
                        $keyMatches = $keyInfo.KeyChar.ToString().Equals($binding.Key, [System.StringComparison]::InvariantCultureIgnoreCase)
                    }
                    
                    if (-not $keyMatches) { return $false }
                    
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
                } -Context @{ Binding = $binding; KeyInfo = $KeyInfo } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "KeybindingService _matchesBinding error: $($Exception.Message)" -Data $Exception.Context
                    return $false
                }
            }
            
            GetBinding = {
                param($self, [string]$ActionName)
                Invoke-WithErrorHandling -Component "KeybindingService.GetBinding" -ScriptBlock {
                    return $self._keyMap[$ActionName]
                } -Context @{ ActionName = $ActionName } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "KeybindingService GetBinding error: $($Exception.Message)" -Data $Exception.Context
                    return $null
                }
            }
            
            SetBinding = {
                param($self, [string]$ActionName, $Key, [string[]]$Modifiers = @())
                Invoke-WithErrorHandling -Component "KeybindingService.SetBinding" -ScriptBlock {
                    $self._keyMap[$ActionName] = @{ Key = $Key; Modifiers = $Modifiers }
                    Write-Log -Level Debug -Message "Set keybinding for '$ActionName': $Key + $($Modifiers -join '+')"
                } -Context @{ ActionName = $ActionName; Key = $Key; Modifiers = $Modifiers } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "KeybindingService SetBinding error: $($Exception.Message)" -Data $Exception.Context
                }
            }
            
            RemoveBinding = {
                param($self, [string]$ActionName)
                Invoke-WithErrorHandling -Component "KeybindingService.RemoveBinding" -ScriptBlock {
                    $self._keyMap.Remove($ActionName)
                    Write-Log -Level Debug -Message "Removed keybinding for '$ActionName'"
                } -Context @{ ActionName = $ActionName } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "KeybindingService RemoveBinding error: $($Exception.Message)" -Data $Exception.Context
                }
            }
            
            GetBindingDescription = {
                param($self, [string]$ActionName)
                Invoke-WithErrorHandling -Component "KeybindingService.GetBindingDescription" -ScriptBlock {
                    if (-not $self._keyMap.ContainsKey($ActionName)) { return $null }
                    $binding = $self._keyMap[$ActionName]
                    $keyStr = if ($binding.Key -is [System.ConsoleKey]) { $binding.Key.ToString() } else { $binding.Key.ToString().ToUpper() }
                    if ($binding.Modifiers.Count -gt 0) { return "$($binding.Modifiers -join '+') + $keyStr" }
                    return $keyStr
                } -Context @{ ActionName = $ActionName } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "KeybindingService GetBindingDescription error: $($Exception.Message)" -Data $Exception.Context
                    return $null
                }
            }
            
            RegisterGlobalHandler = {
                param($self, [string]$ActionName, [scriptblock]$Handler)
                Invoke-WithErrorHandling -Component "KeybindingService.RegisterGlobalHandler" -ScriptBlock {
                    $self._globalHandlers[$ActionName] = $Handler
                    Write-Log -Level Debug -Message "Registered global handler for '$ActionName'"
                } -Context @{ ActionName = $ActionName } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "KeybindingService RegisterGlobalHandler error: $($Exception.Message)" -Data $Exception.Context
                }
            }
            
            HandleKey = {
                param($self, [System.ConsoleKeyInfo]$KeyInfo, [string]$Context = $null)
                Invoke-WithErrorHandling -Component "KeybindingService.HandleKey" -ScriptBlock {
                    foreach ($action in $self._keyMap.Keys) {
                        if ((& $self.IsAction -self $self -ActionName $action -KeyInfo $KeyInfo -Context $Context)) {
                            if ($self._globalHandlers.ContainsKey($action)) {
                                Write-Log -Level Debug -Message "Executing global handler for '$action'"
                                return (& $self._globalHandlers[$action] -KeyInfo $KeyInfo -Context $Context)
                            }
                            return $action
                        }
                    }
                    return $null
                } -Context @{ KeyInfo = $KeyInfo; Context = $Context } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "KeybindingService HandleKey error: $($Exception.Message)" -Data $Exception.Context
                    return $null
                }
            }
            
            PushContext = {
                param($self, [string]$Context)
                Invoke-WithErrorHandling -Component "KeybindingService.PushContext" -ScriptBlock {
                    $self._contextStack += $Context
                    Write-Log -Level Debug -Message "Pushed keybinding context: $Context"
                } -Context @{ Context = $Context } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "KeybindingService PushContext error: $($Exception.Message)" -Data $Exception.Context
                }
            }
            
            PopContext = {
                param($self)
                Invoke-WithErrorHandling -Component "KeybindingService.PopContext" -ScriptBlock {
                    if ($self._contextStack.Count -gt 0) {
                        $context = $self._contextStack[-1]
                        $self._contextStack = $self._contextStack[0..($self._contextStack.Count - 2)]
                        Write-Log -Level Debug -Message "Popped keybinding context: $context"
                        return $context
                    }
                    return $null
                } -Context @{} -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "KeybindingService PopContext error: $($Exception.Message)" -Data $Exception.Context
                    return $null
                }
            }
            
            GetCurrentContext = {
                param($self)
                Invoke-WithErrorHandling -Component "KeybindingService.GetCurrentContext" -ScriptBlock {
                    if ($self._contextStack.Count -gt 0) { return $self._contextStack[-1] }
                    return $null
                } -Context @{} -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "KeybindingService GetCurrentContext error: $($Exception.Message)" -Data $Exception.Context
                    return $null
                }
            }
            
            GetAllBindings = {
                param($self, [bool]$GroupByCategory = $false)
                Invoke-WithErrorHandling -Component "KeybindingService.GetAllBindings" -ScriptBlock {
                    if (-not $GroupByCategory) { return $self._keyMap }
                    $grouped = @{}
                    foreach ($action in $self._keyMap.Keys) {
                        $parts = $action.Split('.')
                        $category = if ($parts.Count -gt 1) { $parts[0] } else { "General" }
                        if (-not $grouped.ContainsKey($category)) { $grouped[$category] = @{} }
                        $grouped[$category][$action] = $self._keyMap[$action]
                    }
                    return $grouped
                } -Context @{ GroupByCategory = $GroupByCategory } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "KeybindingService GetAllBindings error: $($Exception.Message)" -Data $Exception.Context
                    return @{}
                }
            }
            
            ExportBindings = {
                param($self, [string]$Path)
                Invoke-WithErrorHandling -Component "KeybindingService.ExportBindings" -ScriptBlock {
                    $self._keyMap | ConvertTo-Json -Depth 3 | Out-File -FilePath $Path
                    Write-Log -Level Info -Message "Exported keybindings to: $Path"
                } -Context @{ FilePath = $Path } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "KeybindingService ExportBindings error: $($Exception.Message)" -Data $Exception.Context
                }
            }
            
            ImportBindings = {
                param($self, [string]$Path)
                Invoke-WithErrorHandling -Component "KeybindingService.ImportBindings" -ScriptBlock {
                    if (Test-Path $Path) {
                        $imported = Get-Content $Path | ConvertFrom-Json
                        foreach ($prop in $imported.PSObject.Properties) {
                            $self._keyMap[$prop.Name] = @{
                                Key = $prop.Value.Key
                                Modifiers = $prop.Value.Modifiers
                            }
                        }
                        Write-Log -Level Info -Message "Imported keybindings from: $Path"
                    }
                } -Context @{ FilePath = $Path } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "KeybindingService ImportBindings error: $($Exception.Message)" -Data $Exception.Context
                }
            }
        }
        
        return $service
    } -Context @{ CustomBindings = $CustomBindings; EnableChords = $EnableChords } -ErrorHandler {
        param($Exception)
        Write-Log -Level Error -Message "Failed to initialize Keybinding Service: $($Exception.Message)" -Data $Exception.Context
        return $null
    }
}

Export-ModuleMember -Function "Initialize-KeybindingService"