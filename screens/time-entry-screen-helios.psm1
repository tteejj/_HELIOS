# Time Entry Screen - Simple placeholder
# Provides basic time entry functionality

function Get-TimeEntryScreenHelios {
    param([hashtable]$Services)
    
    $screen = @{
        Name = "TimeEntryScreen"
        Components = @{}
        Children = @()
        _subscriptions = @()
        Visible = $true
        ZIndex = 0
        
        Init = {
            param($self, $services)
            Write-Log -Level Info -Message "Time Entry screen Init started"
            
            # Store services
            if (-not $services) {
                if ($self._services) {
                    $services = $self._services
                } elseif ($global:Services) {
                    $services = $global:Services
                    $self._services = $services
                } else {
                    Write-Log -Level Error -Message "Services not available for time entry screen"
                    return
                }
            } else {
                $self._services = $services
            }
            
            # Create root layout
            $rootPanel = New-TuiStackPanel -Props @{
                X = 1; Y = 1
                Width = ($global:TuiState.BufferWidth - 2)
                Height = ($global:TuiState.BufferHeight - 2)
                ShowBorder = $false
                Orientation = "Vertical"
                Spacing = 1
            }
            $self.Components.rootPanel = $rootPanel
            $self.Children += $rootPanel
            
            # Header
            $header = New-TuiLabel -Props @{
                Text = "Time Entry"
                Height = 1
            }
            & $rootPanel.AddChild -self $rootPanel -Child $header | Out-Null
            
            # Content panel
            $contentPanel = New-TuiStackPanel -Props @{
                Title = " New Time Entry "
                ShowBorder = $true
                Padding = 2
                Height = 15
                Orientation = "Vertical"
                Spacing = 1
            }
            
            $infoLabel = New-TuiLabel -Props @{
                Text = "Time entry functionality coming soon..."
                Height = 1
            }
            & $contentPanel.AddChild -self $contentPanel -Child $infoLabel | Out-Null
            
            $backButton = New-TuiButton -Props @{
                Text = "Back to Dashboard"
                Width = 20
                Height = 3
                IsFocusable = $true
                OnClick = {
                    $services = $self._services
                    if ($services -and $services.Navigation) {
                        & $services.Navigation.GoTo -self $services.Navigation -Path "/dashboard" -Services $services
                    }
                }
            }
            
            # Capture services for button handler
            $capturedServices = $services
            $backButton.OnClick = {
                if ($capturedServices -and $capturedServices.Navigation) {
                    & $capturedServices.Navigation.GoTo -self $capturedServices.Navigation -Path "/dashboard" -Services $capturedServices
                }
            }
            
            & $contentPanel.AddChild -self $contentPanel -Child $backButton | Out-Null
            & $rootPanel.AddChild -self $rootPanel -Child $contentPanel | Out-Null
            
            # Set focus
            Request-Focus -Component $backButton
            
            Write-Log -Level Info -Message "Time Entry screen Init completed"
        }
        
        Render = {
            param($self)
            # Status bar
            $statusY = $global:TuiState.BufferHeight - 1
            Write-BufferString -X 2 -Y $statusY -Text "Q: Back to Dashboard" -ForegroundColor (Get-ThemeColor "Subtle" -Default DarkGray)
        }
        
        HandleInput = {
            param($self, $Key)
            
            switch ($Key.KeyChar) {
                'q' { return "Back" }
            }
            
            return $false
        }
        
        OnExit = {
            param($self)
            # Cleanup if needed
        }
    }
    
    $screen._services = $Services
    return $screen
}

Export-ModuleMember -Function Get-TimeEntryScreenHelios