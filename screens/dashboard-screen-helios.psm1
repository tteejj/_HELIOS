# Dashboard Screen - Simplified Navigation-Only Version
# Fixed all scope issues, null checks, and race conditions

function Get-DashboardScreen {
    param([hashtable]$Services)
    
    $screen = @{
        Name = "DashboardScreen"
        Components = @{}
        Children = @()
        _subscriptions = @()
        _focusIndex = 0
        _services = $null
        Visible = $true
        ZIndex = 0
        
        Init = {
            param($self, $services)
            
            # Extreme defensive service validation
            if (-not $services) {
                Write-Log -Level Error -Message "Dashboard Init: No services provided"
                # Try fallback options
                if ($self._services) {
                    $services = $self._services
                    Write-Log -Level Warning -Message "Dashboard Init: Using stored services"
                } elseif ($global:Services) {
                    $services = $global:Services
                    Write-Log -Level Warning -Message "Dashboard Init: Using global services"
                } else {
                    Write-Log -Level Critical -Message "Dashboard Init: No services available anywhere"
                    return
                }
            }
            
            # Store services on screen instance
            $self._services = $services
            
            # Validate critical services exist
            if (-not $services.Store) {
                Write-Log -Level Critical -Message "Dashboard Init: Store service missing"
                return
            }
            if (-not $services.Navigation) {
                Write-Log -Level Critical -Message "Dashboard Init: Navigation service missing"
                return
            }
            
            Write-Log -Level Info -Message "Dashboard Init: Services validated successfully"
            
            # Create simple root panel
            $rootPanel = New-TuiStackPanel -Props @{
                X = 2
                Y = 2
                Width = [Math]::Max(60, ($global:TuiState.BufferWidth - 4))
                Height = [Math]::Max(20, ($global:TuiState.BufferHeight - 4))
                ShowBorder = $true
                Title = " PMC Terminal v4.2 - Main Menu "
                Orientation = "Vertical"
                Spacing = 1
                Padding = 2
            }
            
            # Ensure panel is properly initialized
            if (-not $rootPanel) {
                Write-Log -Level Critical -Message "Dashboard Init: Failed to create root panel"
                return
            }
            
            # Store reference and add to children
            $self.Components.rootPanel = $rootPanel
            $self.Children = @($rootPanel)  # Ensure it's an array
            
            # Add instruction label
            $instructionLabel = New-TuiLabel -Props @{
                Text = "Use Arrow Keys or Number Keys to Navigate"
                Height = 1
                Width = 40
                X = 2
                Y = 1
            }
            
            if ($instructionLabel) {
                & $rootPanel.AddChild -self $rootPanel -Child $instructionLabel | Out-Null
            }
            
            # Create menu data - simple array of options
            $menuItems = @(
                @{ Index = "1"; Action = "New Time Entry"; Path = "/time-entry" }
                @{ Index = "2"; Action = "Start Timer"; Path = "/timer-start" }
                @{ Index = "3"; Action = "View Tasks"; Path = "/task" }
                @{ Index = "4"; Action = "View Projects"; Path = "/project" }
                @{ Index = "5"; Action = "Reports"; Path = "/reports" }
                @{ Index = "6"; Action = "Settings"; Path = "/settings" }
                @{ Index = "0"; Action = "Exit"; Path = "/exit" }
            )
            
            # Create navigation menu using DataTable (simpler than custom list)
            # Capture services in closure BEFORE creating component
            $capturedServices = $services
            $capturedSelf = $self
            
            $navigationMenu = New-TuiDataTable -Props @{
                Name = "navigationMenu"
                IsFocusable = $true
                ShowBorder = $true
                BorderStyle = "Double"
                Title = " Main Menu "
                Height = [Math]::Min(15, $menuItems.Count + 4)
                Width = 50
                Columns = @(
                    @{ Name = "Index"; Width = 5; Align = "Center" }
                    @{ Name = "Action"; Width = 40; Align = "Left" }
                )
                Data = $menuItems
                OnRowSelect = {
                    param($SelectedData, $SelectedIndex)
                    
                    # Extreme defensive checks
                    if ($null -eq $SelectedData) {
                        Write-Log -Level Warning -Message "Dashboard: OnRowSelect called with null data"
                        return
                    }
                    
                    if ($null -eq $capturedServices) {
                        Write-Log -Level Error -Message "Dashboard: Captured services is null in handler"
                        return
                    }
                    
                    if ($null -eq $capturedServices.Navigation) {
                        Write-Log -Level Error -Message "Dashboard: Navigation service is null in handler"
                        return
                    }
                    
                    # Get the path from selected data
                    $path = $SelectedData.Path
                    if ([string]::IsNullOrWhiteSpace($path)) {
                        Write-Log -Level Warning -Message "Dashboard: No path in selected data"
                        return
                    }
                    
                    Write-Log -Level Info -Message "Dashboard: Navigating to $path"
                    
                    # Handle special cases
                    if ($path -eq "/exit") {
                        Write-Log -Level Info -Message "Dashboard: Exit requested"
                        if (Get-Command Stop-TuiEngine -ErrorAction SilentlyContinue) {
                            Stop-TuiEngine
                        }
                        return
                    }
                    
                    # Navigate using captured services
                    try {
                        & $capturedServices.Navigation.GoTo -self $capturedServices.Navigation -Path $path -Services $capturedServices
                    } catch {
                        Write-Log -Level Error -Message "Dashboard: Navigation failed to $path" -Data @{
                            Error = $_.Exception.Message
                            Path = $path
                        }
                    }
                }
            }
            
            # Validate menu was created
            if (-not $navigationMenu) {
                Write-Log -Level Critical -Message "Dashboard Init: Failed to create navigation menu"
                return
            }
            
            # Process data immediately
            if ($navigationMenu.ProcessData) {
                & $navigationMenu.ProcessData -self $navigationMenu
            }
            
            # Add menu to panel
            & $rootPanel.AddChild -self $rootPanel -Child $navigationMenu | Out-Null
            
            # Store component reference
            $self.Components.navigationMenu = $navigationMenu
            $self._navigationMenu = $navigationMenu
            
            # Add status label at bottom
            $statusLabel = New-TuiLabel -Props @{
                Text = "Press ESC to return to this menu from any screen"
                Height = 1
                Width = 45
                X = 2
                Y = 1
            }
            
            if ($statusLabel) {
                & $rootPanel.AddChild -self $rootPanel -Child $statusLabel | Out-Null
            }
            
            # Set initial focus
            if ($navigationMenu.Focus) {
                & $navigationMenu.Focus -self $navigationMenu
            }
            
            # Request initial refresh
            Request-TuiRefresh
            
            Write-Log -Level Info -Message "Dashboard Init: Completed successfully"
        }
        
        HandleInput = {
            param($self, $key)
            
            # Defensive null checks
            if ($null -eq $key) { return $false }
            if ($null -eq $self._navigationMenu) {
                Write-Log -Level Warning -Message "Dashboard HandleInput: Navigation menu not available"
                return $false
            }
            
            # Handle number key shortcuts
            if ($key.Character -match '[0-6]') {
                $index = [int]$key.Character.ToString()
                
                # Get menu items safely
                $menuData = if ($self._navigationMenu.Data) { @($self._navigationMenu.Data) } else { @() }
                
                if ($index -eq 0) {
                    # Exit
                    Write-Log -Level Info -Message "Dashboard: Exit via hotkey"
                    if (Get-Command Stop-TuiEngine -ErrorAction SilentlyContinue) {
                        Stop-TuiEngine
                    }
                    return $true
                } elseif ($index -gt 0 -and $index -le $menuData.Count) {
                    # Navigate to the selected item
                    $selectedItem = $menuData[$index - 1]
                    if ($selectedItem -and $selectedItem.Path -and $self._services -and $self._services.Navigation) {
                        try {
                            & $self._services.Navigation.GoTo -self $self._services.Navigation -Path $selectedItem.Path -Services $self._services
                        } catch {
                            Write-Log -Level Error -Message "Dashboard: Hotkey navigation failed" -Data @{
                                Key = $index
                                Path = $selectedItem.Path
                                Error = $_.Exception.Message
                            }
                        }
                    }
                    return $true
                }
            }
            
            # Pass other keys to the menu
            if ($self._navigationMenu.HandleInput) {
                return & $self._navigationMenu.HandleInput -self $self._navigationMenu -key $key
            }
            
            return $false
        }
        
        OnEnter = {
            param($self)
            Write-Log -Level Info -Message "Dashboard OnEnter"
            
            # Ensure focus on menu
            if ($self._navigationMenu -and $self._navigationMenu.Focus) {
                & $self._navigationMenu.Focus -self $self._navigationMenu
            }
            
            Request-TuiRefresh
        }
        
        OnExit = {
            param($self)
            Write-Log -Level Info -Message "Dashboard OnExit: Cleaning up"
            
            # Clean up any subscriptions (though we don't have any in this simple version)
            if ($self._subscriptions -and $self._subscriptions.Count -gt 0) {
                foreach ($subId in $self._subscriptions) {
                    if ($subId -and $self._services -and $self._services.Store -and $self._services.Store.Unsubscribe) {
                        try {
                            & $self._services.Store.Unsubscribe -self $self._services.Store -subId $subId
                        } catch {
                            Write-Log -Level Warning -Message "Dashboard OnExit: Failed to unsubscribe" -Data @{
                                SubId = $subId
                                Error = $_.Exception.Message
                            }
                        }
                    }
                }
                $self._subscriptions = @()
            }
        }
        
        Render = {
            param($self)
            # The panel and components handle their own rendering
            # This is only for non-component chrome if needed
        }
    }
    
    return $screen
}

Export-ModuleMember -Function Get-DashboardScreen