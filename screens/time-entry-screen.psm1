# Time Entry Form Screen Module - COMPLIANT VERSION
# Using programmatic pattern with component-based architecture

function global:Get-TimeEntryFormScreen {
    param([hashtable]$Services)
    $screen = @{
        Name = "TimeEntryFormScreen"
        
        # 1. State: Central data model for the screen
        State = @{
            ProjectKey = ""
            ProjectName = ""
            Hours = ""
            Description = ""
            Date = (Get-Date).ToString("yyyy-MM-dd")
            ValidationErrors = @{}
        }
        
        # 2. Components: Storage for instantiated component objects
        Components = @{}
        
        # 3. Init: One-time setup
        Init = {
            param($self)
            $self._services = $Services # Store injected services
            
            # Pre-populate with project from context if available
            if ($script:ContextData -and $script:ContextData.ProjectKey) {
                $self.State.ProjectKey = $script:ContextData.ProjectKey
                # Try to get project name
                $storeProjects = $null
                if ($self._services -and $self._services.Store) { # Replaced global:Services
                    $storeProjects = & $self._services.Store.GetState -self $self._services.Store -path 'projects'
                }
                if ($storeProjects -and $storeProjects.ContainsKey($self.State.ProjectKey)) {
                    $self.State.ProjectName = $storeProjects[$self.State.ProjectKey].Name
                }
            }
            
            # Calculate form position
            $formWidth = 60
            $formHeight = 20
            $formX = [Math]::Floor(($global:TuiState.BufferWidth - $formWidth) / 2)
            $formY = [Math]::Floor(($global:TuiState.BufferHeight - $formHeight) / 2)
            
            # Project selection button
            $self.Components.projectButton = New-TuiButton -Props @{
                X = $formX + 21; Y = $formY + 3; Width = 30; Height = 3
                Text = if ($self.State.ProjectName) { $self.State.ProjectName } else { "[ Select Project ]" }
                OnClick = {
                    # Show project selector dialog
                    if (Get-Command Show-ListDialog -ErrorAction SilentlyContinue) {
                        # Get available projects from store
                        $storeProjects = $null
                        if ($self._services -and $self._services.Store) { # Replaced global:Services
                            $storeProjects = & $self._services.Store.GetState -self $self._services.Store -path 'projects'
                        }
                        $projectsForDialog = @()
                        if ($storeProjects) {
                            $projectsForDialog = $storeProjects.GetEnumerator() | ForEach-Object {
                                @{ Display = $_.Value.Name; Value = $_.Key }
                            } | Sort-Object Display
                        }
                        
                        if ($projectsForDialog.Count -gt 0) {
                            Show-ListDialog -Title "Select Project" -Prompt "Choose a project:" -Items $projectsForDialog -OnSelect {
                                param($item)
                                $self.State.ProjectKey = $item.Value
                                $self.State.ProjectName = $item.Display
                                $self.Components.projectButton.Text = $item.Display
                                Request-TuiRefresh
                            }
                        } else {
                            Show-AlertDialog -Title "No Projects" -Message "No projects available. Please create a project first."
                        }
                    }
                }
            }

            # Hours input
                            Show-ListDialog -Title "Select Project" -Prompt "Choose a project:" -Items $projects -OnSelect {
                                param($item)
                                $self.State.ProjectKey = $item.Value
                                $self.State.ProjectName = $item.Display
                                $self.Components.projectButton.Text = $item.Display
                                Request-TuiRefresh
                            }
                        } else {
                            Show-AlertDialog -Title "No Projects" -Message "No projects available. Please create a project first."
                        }
                    }
                }
            }
            
            # Hours input
            $self.Components.hoursTextBox = New-TuiTextBox -Props @{
                X = $formX + 21; Y = $formY + 6; Width = 20; Height = 3
                Placeholder = "0.0"
                Text = $self.State.Hours
                OnChange = {
                    param($NewValue)
                    $self.State.Hours = $NewValue
                    # Clear validation error when user types
                    if ($self.State.ValidationErrors.Hours) {
                        $self.State.ValidationErrors.Remove("Hours")
                    }
                }
            }
            
            # Description input
            $self.Components.descriptionTextArea = New-TuiTextArea -Props @{
                X = $formX + 21; Y = $formY + 9; Width = 35; Height = 4
                Placeholder = "What did you work on?"
                Text = $self.State.Description
                OnChange = {
                    param($NewValue)
                    $self.State.Description = $NewValue
                }
            }
            
            # Date input
            $self.Components.datePicker = New-TuiDatePicker -Props @{
                X = $formX + 21; Y = $formY + 13; Width = 20; Height = 3
                Value = [DateTime]::Parse($self.State.Date)
                Format = "yyyy-MM-dd"
                OnChange = {
                    param($NewValue)
                    $self.State.Date = $NewValue.ToString("yyyy-MM-dd")
                }
            }
            
            # Submit button
            $self.Components.submitButton = New-TuiButton -Props @{
                X = $formX + 15; Y = $formY + 17; Width = 12; Height = 3
                Text = "Submit"
                OnClick = {
                    # Validate form
                    $self.State.ValidationErrors = @{}
                    $isValid = $true
                    
                    # Validate project
                    if ([string]::IsNullOrEmpty($self.State.ProjectKey)) {
                        $self.State.ValidationErrors.Project = "Project is required"
                        $isValid = $false
                    }
                    
                    # Validate hours
                    $hours = 0.0
                    if (-not [double]::TryParse($self.State.Hours, [ref]$hours) -or $hours -le 0) {
                        $self.State.ValidationErrors.Hours = "Valid hours required (e.g., 2.5)"
                        $self.FocusedComponentName = "hoursTextBox"
                        $isValid = $false
                    }
                    
                    if ($isValid) {
                        # Create time entry
                        $timeEntry = @{
                            Id = [Guid]::NewGuid().ToString()
                            ProjectKey = $self.State.ProjectKey
                            Hours = $hours
                            Description = $self.State.Description
                            Date = $self.State.Date
                            Created = Get-Date
                        }
                        
                        # Dispatch action to create time entry
                        if ($self._services -and $self._services.Store) { # Replaced global:Services
                            & $self._services.Store.Dispatch -self $self._services.Store -actionName "CREATE_TIME_ENTRY" -payload $timeEntry
                        } else {
                            Write-Log -Level Error -Message "Store service not available via self._services. Cannot save time entry."
                            Show-AlertDialog -Title "Error" -Message "Failed to save time entry: Store unavailable."
                            # Decide if we should Pop-Screen or allow retry, for now, we continue to pop
                        }
                        
                        # Publish event (This might be redundant if the store action handles events)
                        if (Get-Command Publish-Event -ErrorAction SilentlyContinue) {
                            Publish-Event -EventName "Data.Create.TimeEntry" -Data $timeEntry
                        }
                        
                        # Show success and go back
                        if (Get-Command Show-AlertDialog -ErrorAction SilentlyContinue) {
                            Show-AlertDialog -Title "Success" -Message "Time entry added successfully!"
                        }
                        
                        Pop-Screen
                    } else {
                        Request-TuiRefresh
                    }
                }
            }
            
            # Cancel button
            $self.Components.cancelButton = New-TuiButton -Props @{
                X = $formX + 30; Y = $formY + 17; Width = 12; Height = 3
                Text = "Cancel"
                OnClick = { Pop-Screen }
            }
            
            # Labels
            $self.Components.projectLabel = New-TuiLabel -Props @{
                X = $formX + 3; Y = $formY + 4
                Text = "Project/Template:"
            }
            
            $self.Components.hoursLabel = New-TuiLabel -Props @{
                X = $formX + 3; Y = $formY + 7
                Text = "Hours:"
            }
            
            $self.Components.descriptionLabel = New-TuiLabel -Props @{
                X = $formX + 3; Y = $formY + 10
                Text = "Description:"
            }
            
            $self.Components.dateLabel = New-TuiLabel -Props @{
                X = $formX + 3; Y = $formY + 14
                Text = "Date:"
            }
            
            # Error labels
            $self.Components.projectError = New-TuiLabel -Props @{
                X = $formX + 21; Y = $formY + 5
                Text = ""
                ForegroundColor = [ConsoleColor]::Red
            }
            
            $self.Components.hoursError = New-TuiLabel -Props @{
                X = $formX + 21; Y = $formY + 8
                Text = ""
                ForegroundColor = [ConsoleColor]::Red
            }
            
            # Focus management
            $self.FocusableComponents = @("projectButton", "hoursTextBox", "descriptionTextArea", "datePicker", "submitButton", "cancelButton")
            $self.FocusedComponentName = if ($self.State.ProjectKey) { "hoursTextBox" } else { "projectButton" }
        }
        
        # 4. Render: Draw the screen and its components
        Render = {
            param($self)
            
            # Calculate form position
            $formWidth = 60
            $formHeight = 20
            $formX = [Math]::Floor(($global:TuiState.BufferWidth - $formWidth) / 2)
            $formY = [Math]::Floor(($global:TuiState.BufferHeight - $formHeight) / 2)
            
            # Draw form box
            Write-BufferBox -X $formX -Y $formY -Width $formWidth -Height $formHeight `
                -Title " Add Time Entry " -BorderColor (Get-ThemeColor "Accent")
            
            # Update error visibility
            if ($self.State.ValidationErrors.Project) {
                $self.Components.projectError.Text = $self.State.ValidationErrors.Project
            } else {
                $self.Components.projectError.Text = ""
            }
            
            if ($self.State.ValidationErrors.Hours) {
                $self.Components.hoursError.Text = $self.State.ValidationErrors.Hours
            } else {
                $self.Components.hoursError.Text = ""
            }
            
            # Render all components
            foreach ($kvp in $self.Components.GetEnumerator()) {
                $component = $kvp.Value
                if ($component -and $component.Visible -ne $false) {
                    # Set focus state
                    $component.IsFocused = ($self.FocusedComponentName -eq $kvp.Key)
                    if ($component.Render) {
                        & $component.Render -self $component
                    }
                }
            }
            
            # Instructions
            Write-BufferString -X ($formX + 3) -Y ($formY + $formHeight - 2) `
                -Text "Tab: Next Field • Enter: Submit • Esc: Cancel" `
                -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        # 5. HandleInput: Global input handling for the screen
        HandleInput = {
            param($self, $Key)
            
            # Global navigation
            switch ($Key.Key) {
                ([ConsoleKey]::Escape) { 
                    Pop-Screen
                    return $true 
                }
                ([ConsoleKey]::Tab) {
                    # Cycle through focusable components
                    $currentIndex = [array]::IndexOf($self.FocusableComponents, $self.FocusedComponentName)
                    if ($currentIndex -eq -1) { $currentIndex = 0 }
                    
                    $direction = if ($Key.Modifiers -band [ConsoleModifiers]::Shift) { -1 } else { 1 }
                    $nextIndex = ($currentIndex + $direction + $self.FocusableComponents.Count) % $self.FocusableComponents.Count
                    $self.FocusedComponentName = $self.FocusableComponents[$nextIndex]
                    Request-TuiRefresh
                    return $true
                }
            }
            
            # Delegate to focused component
            $focusedComponent = if ($self.FocusedComponentName) { $self.Components[$self.FocusedComponentName] } else { $null }
            if ($focusedComponent -and $focusedComponent.HandleInput) {
                $result = & $focusedComponent.HandleInput -self $focusedComponent -Key $Key
                if ($result) {
                    Request-TuiRefresh
                    return $true
                }
            }
            
            return $false
        }
    }
    
    return $screen
}

# Export module members
Export-ModuleMember -Function 'Get-TimeEntryFormScreen'