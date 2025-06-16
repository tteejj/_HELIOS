# Focus Manager Module
# Centralized focus management for TUI components

$script:FocusState = @{
    CurrentScreen = $null
    FocusedComponent = $null
    FocusHistory = @()
    TabOrder = @()
}

function global:Initialize-FocusManager {
    <#
    .SYNOPSIS
    Initializes the focus management system
    #>
    
    $script:FocusState = @{
        CurrentScreen = $null
        FocusedComponent = $null
        FocusHistory = @()
        TabOrder = @()
    }
    
    # Subscribe to screen change events
    if (Get-Command Subscribe-Event -ErrorAction SilentlyContinue) {
        Subscribe-Event -EventName "Screen.Pushed" -Handler {
            param($EventData)
            Set-ScreenFocus -Screen $EventData.Data.Screen
        }
        
        Subscribe-Event -EventName "Screen.Popped" -Handler {
            param($EventData)
            Set-ScreenFocus -Screen $EventData.Data.Screen
        }
    }
}

function global:Set-ScreenFocus {
    <#
    .SYNOPSIS
    Sets focus context for a screen
    #>
    param([hashtable]$Screen)
    
    $script:FocusState.CurrentScreen = $Screen
    
    # Build tab order for the screen
    $script:FocusState.TabOrder = @()
    
    if ($Screen.Components) {
        # Collect all focusable components
        $focusableComponents = @()
        
        if ($Screen.Components -is [hashtable]) {
            foreach ($kvp in $Screen.Components.GetEnumerator()) {
                $component = $kvp.Value
                if ($component -and $component.IsFocusable -ne $false -and $component.Visible -ne $false) {
                    $focusableComponents += @{
                        Name = $kvp.Key
                        Component = $component
                        TabIndex = $component.TabIndex ?? 999
                        Position = @{ X = $component.X; Y = $component.Y }
                    }
                }
            }
        } elseif ($Screen.Components -is [array]) {
            for ($i = 0; $i -lt $Screen.Components.Count; $i++) {
                $component = $Screen.Components[$i]
                if ($component -and $component.IsFocusable -ne $false -and $component.Visible -ne $false) {
                    $focusableComponents += @{
                        Name = "Component$i"
                        Component = $component
                        TabIndex = $component.TabIndex ?? 999
                        Position = @{ X = $component.X; Y = $component.Y }
                    }
                }
            }
        }
        
        # Sort by TabIndex, then by position (top to bottom, left to right)
        $script:FocusState.TabOrder = $focusableComponents | Sort-Object {
            $_.TabIndex
        }, {
            $_.Position.Y
        }, {
            $_.Position.X
        }
        
        # Set initial focus
        if ($script:FocusState.TabOrder.Count -gt 0) {
            $firstComponent = $script:FocusState.TabOrder[0]
            Set-ManagedComponentFocus -Component $firstComponent.Component -ComponentName $firstComponent.Name
        }
    }
}

function global:Set-ManagedComponentFocus {
    <#
    .SYNOPSIS
    Sets focus to a specific component with proper state management
    #>
    param(
        [hashtable]$Component,
        [string]$ComponentName
    )
    
    if (-not $Component) { return }
    
    # Blur previous component
    if ($script:FocusState.FocusedComponent -and $script:FocusState.FocusedComponent -ne $Component) {
        $script:FocusState.FocusedComponent.IsFocused = $false
        if ($script:FocusState.FocusedComponent.OnBlur) {
            & $script:FocusState.FocusedComponent.OnBlur -self $script:FocusState.FocusedComponent
        }
    }
    
    # Update focus state
    $script:FocusState.FocusedComponent = $Component
    $Component.IsFocused = $true
    
    # Track in history
    $script:FocusState.FocusHistory += @{
        Component = $Component
        Name = $ComponentName
        Time = Get-Date
    }
    
    # Keep history size manageable
    if ($script:FocusState.FocusHistory.Count -gt 50) {
        $script:FocusState.FocusHistory = $script:FocusState.FocusHistory[-50..-1]
    }
    
    # Call component's focus handler
    if ($Component.OnFocus) {
        & $Component.OnFocus -self $Component
    }
    
    # Update screen's tracking if it exists
    if ($script:FocusState.CurrentScreen -and $ComponentName) {
        if ($script:FocusState.CurrentScreen.FocusedComponentName) {
            $script:FocusState.CurrentScreen.FocusedComponentName = $ComponentName
        }
    }
    
    # Update engine's focus tracking
    if (Get-Command Set-ComponentFocus -ErrorAction SilentlyContinue) {
        Set-ComponentFocus -Component $Component
    }
    
    Request-TuiRefresh
}

function global:Move-FocusNext {
    <#
    .SYNOPSIS
    Moves focus to the next component in tab order
    #>
    param([bool]$Reverse = $false)
    
    if ($script:FocusState.TabOrder.Count -eq 0) { return }
    
    # Find current component in tab order
    $currentIndex = -1
    for ($i = 0; $i -lt $script:FocusState.TabOrder.Count; $i++) {
        if ($script:FocusState.TabOrder[$i].Component -eq $script:FocusState.FocusedComponent) {
            $currentIndex = $i
            break
        }
    }
    
    # Calculate next index
    if ($currentIndex -eq -1) {
        $nextIndex = 0
    } else {
        if ($Reverse) {
            $nextIndex = ($currentIndex - 1 + $script:FocusState.TabOrder.Count) % $script:FocusState.TabOrder.Count
        } else {
            $nextIndex = ($currentIndex + 1) % $script:FocusState.TabOrder.Count
        }
    }
    
    # Set focus to next component
    $nextItem = $script:FocusState.TabOrder[$nextIndex]
    Set-ManagedComponentFocus -Component $nextItem.Component -ComponentName $nextItem.Name
}

function global:Get-FocusedComponent {
    <#
    .SYNOPSIS
    Gets the currently focused component
    #>
    return $script:FocusState.FocusedComponent
}

function global:Get-FocusableComponents {
    <#
    .SYNOPSIS
    Gets all focusable components in the current screen
    #>
    return $script:FocusState.TabOrder | ForEach-Object { $_.Component }
}

function global:Clear-FocusHistory {
    <#
    .SYNOPSIS
    Clears the focus history
    #>
    $script:FocusState.FocusHistory = @()
}

function global:Set-ComponentTabIndex {
    <#
    .SYNOPSIS
    Sets the tab index for a component
    #>
    param(
        [hashtable]$Component,
        [int]$TabIndex
    )
    
    $Component.TabIndex = $TabIndex
    
    # Rebuild tab order if this is the current screen
    if ($script:FocusState.CurrentScreen) {
        Set-ScreenFocus -Screen $script:FocusState.CurrentScreen
    }
}

function global:Focus-ComponentByName {
    <#
    .SYNOPSIS
    Focuses a component by its name in the current screen
    #>
    param([string]$ComponentName)
    
    if (-not $script:FocusState.CurrentScreen) { return }
    
    $component = $null
    
    if ($script:FocusState.CurrentScreen.Components -is [hashtable]) {
        $component = $script:FocusState.CurrentScreen.Components[$ComponentName]
    }
    
    if ($component) {
        Set-ManagedComponentFocus -Component $component -ComponentName $ComponentName
    }
}

function global:Get-FocusDebugInfo {
    <#
    .SYNOPSIS
    Gets debug information about the current focus state
    #>
    
    return @{
        CurrentScreen = if ($script:FocusState.CurrentScreen) { $script:FocusState.CurrentScreen.Name } else { "None" }
        FocusedComponent = if ($script:FocusState.FocusedComponent) { 
            @{
                Type = $script:FocusState.FocusedComponent.Type
                Position = @{ X = $script:FocusState.FocusedComponent.X; Y = $script:FocusState.FocusedComponent.Y }
                IsFocused = $script:FocusState.FocusedComponent.IsFocused
            }
        } else { "None" }
        TabOrderCount = $script:FocusState.TabOrder.Count
        FocusHistoryCount = $script:FocusState.FocusHistory.Count
        LastFocusChange = if ($script:FocusState.FocusHistory.Count -gt 0) {
            $script:FocusState.FocusHistory[-1].Time
        } else { "Never" }
    }
}

Export-ModuleMember -Function @(
    'Initialize-FocusManager',
    'Set-ScreenFocus',
    'Set-ManagedComponentFocus',
    'Move-FocusNext',
    'Get-FocusedComponent',
    'Get-FocusableComponents',
    'Clear-FocusHistory',
    'Set-ComponentTabIndex',
    'Focus-ComponentByName',
    'Get-FocusDebugInfo'
)