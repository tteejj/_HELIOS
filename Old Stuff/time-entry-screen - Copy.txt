# Time Entry Form Screen - Built with the v3.0 Framework
# FIXED: Form container is created once and reused

function Get-TimeEntryFormScreen {
    $formScreen = @{
        Name = "TimeEntryFormScreen"
        State = @{
            Project = $null
            Hours = ""
            Description = ""
            HoursCursor = 0
            DescriptionCursor = 0
            FocusedChildName = "project_dropdown"
        }
        FormContainer = $null  # Will be set in Init
        
        Init = {
            param($self)
            
            # Create children once
            $children = @(
                New-TuiDropdown -Props @{
                    Name = "project_dropdown"
                    Y = 2
                    Width = 56
                    Options = @( 
                        $script:Data.Projects.GetEnumerator() | ForEach-Object { 
                            @{ Value = $_.Key; Display = $_.Value.Name } 
                        } 
                    )
                    ValueProp = "Project"
                    OnChange = { 
                        param($NewValue) 
                        $self.State.Project = $NewValue
                        Request-TuiRefresh 
                    }
                }
                
                New-TuiTextBox -Props @{
                    Name = "hours_textbox"
                    Y = 6
                    Width = 56
                    Placeholder = "e.g., 2.5"
                    TextProp = "Hours"
                    CursorProp = "HoursCursor"
                    OnChange = { 
                        param($NewText, $NewCursorPosition) 
                        $self.State.Hours = $NewText
                        $self.State.HoursCursor = $NewCursorPosition
                        Request-TuiRefresh 
                    }
                }
                
                New-TuiTextBox -Props @{
                    Name = "description_textbox"
                    Y = 10
                    Width = 56
                    Placeholder = "Work details..."
                    TextProp = "Description"
                    CursorProp = "DescriptionCursor"
                    OnChange = { 
                        param($NewText, $NewCursorPosition) 
                        $self.State.Description = $NewText
                        $self.State.DescriptionCursor = $NewCursorPosition
                        Request-TuiRefresh 
                    }
                }
                
                New-TuiButton -Props @{
                    Name = "submit_button"
                    Y = 14
                    Width = 12
                    Text = "Submit"
                    OnClick = {
                        Publish-Event -EventName "Data.Create.TimeEntry" -Data @{
                            Project = $self.State.Project
                            Hours = $self.State.Hours
                            Description = $self.State.Description
                        }
                    }
                }
                
                New-TuiButton -Props @{
                    Name = "cancel_button"
                    X = 44
                    Y = 14
                    Width = 12
                    Text = "Cancel"
                    OnClick = {
                        Pop-Screen
                    }
                }
            )
            
            # Create the persistent form container
            $self.FormContainer = New-TuiForm -Props @{
                X = [Math]::Floor(($script:TuiState.BufferWidth - 60) / 2)
                Y = 4
                Width = 60
                Height = 20
                Title = " Add Time Entry "
                Padding = 2
                Children = $children
                OnFocusChange = { 
                    param($NewFocusedChildName) 
                    $self.State.FocusedChildName = $NewFocusedChildName
                    Request-TuiRefresh 
                }
            }
        }
        
        Render = {
            param($self)
            # Simply pass current state to the persistent container and render
            $self.FormContainer.State = $self.State
            & $self.FormContainer.Render -self $self.FormContainer
        }
        
        HandleInput = {
            param($self, $Key)
            
            # ESC to go back
            if ($Key.Key -eq [ConsoleKey]::Escape) {
                return "Back"
            }
            
            # Pass state and key to the persistent container
            $self.FormContainer.State = $self.State
            return & $self.FormContainer.HandleInput -self $self.FormContainer -Key $Key
        }
        
        OnExit = {
            param($self)
            # Clear form data
            $self.State.Project = $null
            $self.State.Hours = ""
            $self.State.Description = ""
            $self.State.HoursCursor = 0
            $self.State.DescriptionCursor = 0
            $self.State.FocusedChildName = "project_dropdown"
        }
    }
    
    return $formScreen
}

Export-ModuleMember -Function 'Get-TimeEntryFormScreen'
