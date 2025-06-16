# Example State-Based Screen
# Demonstrates the new reactive state management pattern

function global:Get-StateExampleScreen {
    $screen = @{
        Name = "StateExampleScreen"
        
        # State will be initialized in Init
        State = $null
        Components = @{}
        
        Init = {
            param($self)
            
            # Create reactive state with initial values and actions
            $self.State = New-TuiState -InitialState @{
                counter = 0
                message = "Welcome to reactive state!"
                items = @("Item 1", "Item 2", "Item 3")
                selectedIndex = 0
            } -Actions @{
                Increment = { 
                    $this.counter++
                    $this.message = "Counter is now $($this.counter)"
                }
                Decrement = { 
                    if ($this.counter -gt 0) {
                        $this.counter--
                        $this.message = "Counter is now $($this.counter)"
                    }
                }
                Reset = {
                    $this.counter = 0
                    $this.message = "Counter reset!"
                }
                AddItem = {
                    param($item)
                    $this.items = @($this.items) + $item
                }
            }
            
            # Create UI components
            $self.Components.counterLabel = New-TuiLabel -Props @{
                X = 10; Y = 5; Text = "Counter: 0"
            }
            
            $self.Components.messageLabel = New-TuiLabel -Props @{
                X = 10; Y = 7; Text = $self.State.message
            }
            
            $self.Components.incrementButton = New-TuiButton -Props @{
                X = 10; Y = 10; Width = 15; Text = "Increment"
                OnClick = { $self.State.Increment() }
            }
            
            $self.Components.decrementButton = New-TuiButton -Props @{
                X = 30; Y = 10; Width = 15; Text = "Decrement"
                OnClick = { $self.State.Decrement() }
            }
            
            $self.Components.resetButton = New-TuiButton -Props @{
                X = 50; Y = 10; Width = 15; Text = "Reset"
                OnClick = { $self.State.Reset() }
            }
            
            # Set up reactive bindings - components update automatically when state changes
            $self.State.Subscribe('counter', {
                param($newValue)
                $self.Components.counterLabel.Text = "Counter: $newValue"
                Request-TuiRefresh
            })
            
            $self.State.Subscribe('message', {
                param($newValue)
                $self.Components.messageLabel.Text = $newValue
                Request-TuiRefresh
            })
            
            # Example of wildcard subscription - monitors all state changes
            $self.State.Subscribe('*', {
                param($change)
                Write-Log -Level Debug -Message "State changed: $($change.Key) = $($change.NewValue)"
            })
        }
        
        Render = {
            param($self)
            
            # Header
            Write-BufferString -X 2 -Y 1 -Text "Reactive State Management Example" -ForegroundColor (Get-ThemeColor "Header")
            
            # Instructions
            Write-BufferString -X 2 -Y 3 -Text "This screen demonstrates automatic UI updates when state changes" -ForegroundColor (Get-ThemeColor "Subtle")
            
            # Draw a box around the counter area
            Write-BufferBox -X 8 -Y 4 -Width 60 -Height 10 -Title " Counter Demo " -BorderColor (Get-ThemeColor "Accent")
            
            # Render all components
            foreach ($component in $self.Components.Values) {
                if ($component.Render) {
                    & $component.Render -self $component
                }
            }
            
            # Status bar
            Write-BufferString -X 2 -Y ($global:TuiState.BufferHeight - 2) `
                -Text "Tab: Switch buttons • Enter: Activate • Q: Back" `
                -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        HandleInput = {
            param($self, $Key)
            
            switch ($Key.Key) {
                ([ConsoleKey]::Q) { return "Back" }
                ([ConsoleKey]::Escape) { return "Back" }
                ([ConsoleKey]::Tab) {
                    # Simple focus rotation between buttons
                    $buttons = @('incrementButton', 'decrementButton', 'resetButton')
                    $current = $buttons | Where-Object { $self.Components.$_.IsFocused } | Select-Object -First 1
                    
                    # Clear all focus
                    foreach ($btn in $buttons) {
                        $self.Components.$btn.IsFocused = $false
                    }
                    
                    # Set next focus
                    if ($current) {
                        $idx = [array]::IndexOf($buttons, $current)
                        $nextIdx = ($idx + 1) % $buttons.Count
                        $self.Components[$buttons[$nextIdx]].IsFocused = $true
                    } else {
                        $self.Components.incrementButton.IsFocused = $true
                    }
                    
                    Request-TuiRefresh
                    return $true
                }
            }
            
            # Delegate to focused component
            foreach ($component in $self.Components.Values) {
                if ($component.IsFocused -and $component.HandleInput) {
                    if (& $component.HandleInput -self $component -Key $Key) {
                        return $true
                    }
                }
            }
            
            return $false
        }
        
        OnExit = {
            param($self)
            # No cleanup needed - subscriptions are screen-local
        }
    }
    
    return $screen
}

Export-ModuleMember -Function Get-StateExampleScreen
