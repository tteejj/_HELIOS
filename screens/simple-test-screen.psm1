# Simple Test Screen for TUI Engine Verification
function Get-SimpleTestScreen {
    param($Services)
    
    Write-Host "[DEBUG] Creating simple test screen" -ForegroundColor Cyan
    
    $screen = @{
        Name = "SimpleTest"
        Background = [ConsoleColor]::Black
        Children = @()
        _services = $Services
        _subscriptions = @()
        
        Init = {
            param($self, $services)
            Write-Host "[DEBUG] SimpleTest Init called" -ForegroundColor Cyan
            
            # Create a simple centered panel
            $panel = New-TuiStackPanel -Props @{
                X = 10
                Y = 5
                Width = 60
                Height = 20
                BackgroundColor = [ConsoleColor]::DarkBlue
                BorderStyle = "Single"
                Title = "Simple Test Panel"
                Orientation = "Vertical"
                Padding = 2
            }
            
            # Add a label
            $label = New-TuiLabel -Props @{
                Text = "Test Label: Waiting for data..."
                ForegroundColor = [ConsoleColor]::White
            }
            & $panel.AddChild -self $panel -Child $label
            
            # Add a button
            $button = New-TuiButton -Props @{
                Text = "Click to Update"
                OnClick = {
                    Write-Host "[DEBUG] Button clicked!" -ForegroundColor Green
                    & $services.Store.Dispatch -self $services.Store -actionName "TEST_UPDATE" -payload @{
                        message = "Button was clicked at $(Get-Date -Format 'HH:mm:ss')"
                    }
                }
            }
            & $button.ProcessData -self $button
            & $panel.AddChild -self $panel -Child $button
            
            # Store components
            $self._label = $label
            $self._panel = $panel
            
            # Add panel to screen children
            $self.Children += $panel
            
            # Subscribe to test data
            $self._subscriptions += & $services.Store.Subscribe -self $services.Store -path "testMessage" -handler {
                param($data)
                Write-Host "[DEBUG] Subscription handler called with: $($data.NewValue)" -ForegroundColor Magenta
                if ($screen._label) {
                    $screen._label.Text = "Test Label: $($data.NewValue)"
                    Request-TuiRefresh
                }
            }.GetNewClosure()
            
            # Register test action if not already registered
            & $services.Store.RegisterAction -self $services.Store -actionName "TEST_UPDATE" -scriptBlock {
                param($Context, $Payload)
                Write-Host "[DEBUG] TEST_UPDATE action executing" -ForegroundColor Yellow
                & $Context.UpdateState @{ testMessage = $Payload.message }
            }
            
            # Set initial data
            & $services.Store.Dispatch -self $services.Store -actionName "TEST_UPDATE" -payload @{
                message = "Screen initialized successfully!"
            }
            
            # Register for focus
            if (Get-Command -Name "Register-ScreenForFocus" -ErrorAction SilentlyContinue) {
                Register-ScreenForFocus -Screen $self
            }
        }
        
        HandleInput = {
            param($self, $key)
            if ($key -eq 'q' -or $key -eq 'Q') {
                Write-Host "[DEBUG] Quit requested" -ForegroundColor Red
                return $false
            }
            return $true
        }
        
        Render = {
            param($self)
            # Draw a simple status bar
            $y = [Console]::WindowHeight - 2
            [Console]::SetCursorPosition(0, $y)
            Write-Host "Press 'Q' to quit | Simple Test Screen" -ForegroundColor Gray
        }
        
        OnExit = {
            param($self)
            Write-Host "[DEBUG] SimpleTest OnExit called" -ForegroundColor Cyan
            foreach ($subId in $self._subscriptions) {
                & $self._services.Store.Unsubscribe -self $self._services.Store -subId $subId
            }
        }
    }
    
    return $screen
}

Export-ModuleMember -Function "Get-SimpleTestScreen"