# TUI Framework Integration Module
# Provides high-level integration between TUI engine, components, and layout systems

$script:ComponentRegistry = @{}
$script:LayoutCache = @{}

function global:Initialize-TuiFramework {
    <#
    .SYNOPSIS
    Initializes the complete TUI framework with all subsystems
    #>
    
    # Ensure engine is initialized
    if (-not $global:TuiState) {
        throw "TUI Engine must be initialized before framework"
    }
    
    # Initialize component registry
    $script:ComponentRegistry = @{
        Base = { New-TuiComponent @args }
        Label = { New-TuiLabel @args }
        Button = { New-TuiButton @args }
        TextBox = { New-TuiTextBox @args }
        TextArea = { New-TuiTextArea @args }
        CheckBox = { New-TuiCheckBox @args }
        Dropdown = { New-TuiDropdown @args }
        SearchableDropdown = { New-TuiSearchableDropdown @args }
        Table = { New-TuiTable @args }
        ProgressBar = { New-TuiProgressBar @args }
        DatePicker = { New-TuiDatePicker @args }
        TimePicker = { New-TuiTimePicker @args }
        CalendarPicker = { New-TuiCalendarPicker @args }
        NumberInput = { New-TuiNumberInput @args }
        Slider = { New-TuiSlider @args }
        MultiSelect = { New-TuiMultiSelect @args }
        Chart = { New-TuiChart @args }
        Toast = { New-TuiToast @args }
        Dialog = { New-TuiDialog @args }
    }
    
    Write-Verbose "TUI Framework initialized with $($script:ComponentRegistry.Count) component types"
}

function global:Create-TuiComponent {
    <#
    .SYNOPSIS
    Factory method for creating TUI components with type safety
    
    .PARAMETER Type
    The type of component to create
    
    .PARAMETER Props
    Properties to pass to the component constructor
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Type,
        
        [Parameter()]
        [hashtable]$Props = @{}
    )
    
    if (-not $script:ComponentRegistry.ContainsKey($Type)) {
        throw "Unknown component type: $Type"
    }
    
    $factory = $script:ComponentRegistry[$Type]
    $component = & $factory -Props $Props
    
    # Auto-register with engine if focusable
    if ($component.IsFocusable) {
        Register-Component -Component $component
    }
    
    return $component
}

function global:Create-TuiScreen {
    <#
    .SYNOPSIS
    Creates a screen with automatic component management
    
    .PARAMETER Definition
    Screen definition hashtable
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Definition
    )

    # --- START OF CORRECTION ---
    # The original implementation was flawed. This is the new, working version.
    $screen = @{
        Name              = $Definition.Name ?? "Screen_$(Get-Random)"
        State             = $Definition.State ?? @{}
        _children         = @{} # Internal storage for instantiated components
        _focusableNames   = @() # Names of focusable children, in order
        _focusedIndex     = -1
        Layout            = $Definition.Layout ?? "Manual" # Preserving layout properties
        LayoutOptions     = $Definition.LayoutOptions ?? @{}

        Init = {
            param($self)
            
            # Instantiate all child components from the definition.
            # The original code did this but didn't link them correctly.
            if ($Definition.Children) {
                foreach ($compDef in $Definition.Children) {
                    $factoryCommand = "New-Tui$($compDef.Type)"
                    $factory = Get-Command $factoryCommand -ErrorAction SilentlyContinue
                    if (-not $factory) {
                        Write-Warning "Component factory not found: $factoryCommand. Skipping component '$($compDef.Name)'."
                        continue
                    }
                    
                    $component = & $factory -Props $compDef.Props
                    $component.Name = $compDef.Name
                    $component.ParentScreen = $self # CRITICAL: Link component back to the screen
                    
                    $self._children[$component.Name] = $component
                    if ($component.IsFocusable) {
                        $self._focusableNames += $component.Name
                    }
                }
            }

            if ($self._focusableNames.Count -gt 0) {
                $self._focusedIndex = 0
            }
            
            # Call user-defined Init
            if ($Definition.Init) {
                & $Definition.Init -self $self
            }
        }
        
        Render = {
            param($self)
            
            # Call user-defined Render first for backgrounds
            if ($Definition.Render) {
                & $Definition.Render -self $self
            }

            # Render each child component
            if ($self._children) {
                foreach ($childName in $self._children.Keys) {
                    $child = $self._children[$childName]
                    if(-not $child.Visible) { continue }
                    
                    $renderableChild = $child.Clone()
                    
                    # Data Binding (State -> Props)
                    if ($child.Props.RowsProp) { $renderableChild.Data = $self.State.($child.Props.RowsProp) }
                    if ($child.Props.SelectedRowProp) { $renderableChild.SelectedRow = $self.State.($child.Props.SelectedRowProp) }
                    # Add more bindings here as needed

                    # Set focus state
                    if ($self._focusedIndex -ne -1 -and $child.Name -eq $self._focusableNames[$self._focusedIndex]) {
                        $renderableChild.IsFocused = $true
                    }
                    
                    & $renderableChild.Render -self $renderableChild
                }
            }
        }

        HandleInput = {
            param($self, $Key)
            
            # Handle Tab for focus cycling
            if ($Key.Key -eq [ConsoleKey]::Tab) {
                if ($self._focusableNames.Count -gt 1) {
                    $direction = if ($Key.Modifiers -band [ConsoleModifiers]::Shift) { -1 } else { 1 }
                    $self._focusedIndex = ($self._focusedIndex + $direction + $self._focusableNames.Count) % $self._focusableNames.Count
                    Request-TuiRefresh
                    return $true
                }
            }
            
            # Delegate input to the focused child
            if ($self._focusedIndex -ne -1) {
                $focusedChildName = $self._focusableNames[$self._focusedIndex]
                $focusedChild = $self._children[$focusedChildName]
                
                if (& $focusedChild.HandleInput -self $focusedChild -Key $Key) {
                    return $true
                }
            }

            # Fallback to screen's global handler
            if ($Definition.HandleInput) {
                return & $Definition.HandleInput -self $self -Key $Key
            }
            
            return $false
        }
        
        OnExit = {
            param($self)
            # This logic was missing but is important for cleanup
            if ($Definition.OnExit) {
                & $Definition.OnExit -self $self
            }
        }
    }
    # --- END OF CORRECTION ---
    
    return $screen
}

function global:Create-TuiForm {
    <#
    .SYNOPSIS
    Creates a form screen with automatic field management
    
    .PARAMETER Title
    Form title
    
    .PARAMETER Fields
    Array of field definitions
    
    .PARAMETER OnSubmit
    Handler for form submission
    #>
    param(
        [string]$Title = "Form",
        [array]$Fields = @(),
        [scriptblock]$OnSubmit = {}
    )
    
    $formState = @{}
    $formComponents = @()
    
    # Create form container
    $formComponents += @{
        Type = "Form"
        Props = @{
            X = 10
            Y = 3
            Width = 60
            Height = 20
            Title = " $Title "
        }
    }
    
    # Create fields
    $currentY = 2
    foreach ($field in $Fields) {
        # Label
        $formComponents += @{
            Type = "Label"
            Props = @{
                X = 2
                Y = $currentY
                Text = "$($field.Label):"
            }
        }
        
        # Field component
        $fieldComponent = @{
            Type = $field.Type ?? "TextBox"
            Props = @{
                X = 20
                Y = $currentY
                Width = 35
                Name = $field.Name
            }
        }
        
        # Add field-specific properties
        foreach ($key in $field.Keys) {
            if ($key -notin @('Label', 'Name', 'Type')) {
                $fieldComponent.Props[$key] = $field[$key]
            }
        }
        
        $formComponents += $fieldComponent
        
        # Initialize state
        $formState[$field.Name] = $field.DefaultValue ?? ""
        
        $currentY += 3
    }
    
    # Submit button
    $formComponents += @{
        Type = "Button"
        Props = @{
            X = 20
            Y = $currentY + 1
            Width = 15
            Text = "Submit"
            OnClick = {
                $formData = @{}
                foreach ($field in $Fields) {
                    $formData[$field.Name] = $formState[$field.Name]
                }
                & $OnSubmit -FormData $formData
            }
        }
    }
    
    # Cancel button
    $formComponents += @{
        Type = "Button"
        Props = @{
            X = 37
            Y = $currentY + 1
            Width = 15
            Text = "Cancel"
            OnClick = {
                Pop-Screen
            }
        }
    }
    
    return Create-TuiScreen -Definition @{
        Name = "$Title`Form"
        State = $formState
        Components = $formComponents
        Layout = "Manual"
    }
}

function global:Show-TuiMessageBox {
    <#
    .SYNOPSIS
    Shows a message box dialog
    
    .PARAMETER Title
    Dialog title
    
    .PARAMETER Message
    Message to display
    
    .PARAMETER Buttons
    Array of button names
    
    .PARAMETER OnButtonClick
    Handler for button clicks
    #>
    param(
        [string]$Title = "Message",
        [string]$Message = "",
        [string[]]$Buttons = @("OK"),
        [scriptblock]$OnButtonClick = {}
    )
    
    $dialog = Create-TuiComponent -Type "Dialog" -Props @{
        Title = $Title
        Message = $Message
        Buttons = $Buttons
        OnButtonClick = $OnButtonClick
    }
    
    # Create a screen wrapper for the dialog
    $dialogScreen = @{
        Name = "DialogScreen"
        State = @{ Dialog = $dialog }
        
        Render = {
            param($self)
            & $self.State.Dialog.Render -self $self.State.Dialog
        }
        
        HandleInput = {
            param($self, $Key)
            return & $self.State.Dialog.HandleInput -self $self.State.Dialog -Key $Key
        }
    }
    
    Push-Screen -Screen $dialogScreen
}

function global:Show-TuiNotification {
    <#
    .SYNOPSIS
    Shows a toast notification
    
    .PARAMETER Message
    Notification message
    
    .PARAMETER Type
    Notification type (Info, Success, Warning, Error)
    
    .PARAMETER Duration
    Display duration in milliseconds
    #>
    param(
        [string]$Message,
        [string]$Type = "Info",
        [int]$Duration = 3000
    )
    
    if (Get-Command -Name "Publish-Event" -ErrorAction SilentlyContinue) {
        Publish-Event -EventName "Notification.Show" -Data @{
            Text = $Message
            Type = $Type
            Duration = $Duration
        }
    } else {
        # Fallback to direct rendering
        $toast = Create-TuiComponent -Type "Toast" -Props @{
            Message = $Message
            ToastType = $Type
            Duration = $Duration
        }
        
        # This would need integration with the dialog system
        # For now, just write to status line
        Write-StatusLine -Text $Message -ForegroundColor (Get-ThemeColor $Type)
    }
}

function global:Create-TuiWizard {
    <#
    .SYNOPSIS
    Creates a multi-step wizard interface
    
    .PARAMETER Title
    Wizard title
    
    .PARAMETER Steps
    Array of step definitions
    
    .PARAMETER OnComplete
    Handler for wizard completion
    #>
    param(
        [string]$Title,
        [array]$Steps,
        [scriptblock]$OnComplete
    )
    
    $wizardState = @{
        CurrentStep = 0
        Data = @{}
    }
    
    $wizard = Create-TuiScreen -Definition @{
        Name = "$Title`Wizard"
        State = $wizardState
        
        Render = {
            param($self)
            
            # Progress indicator
            $progressY = 2
            $progressText = "Step $($self.State.CurrentStep + 1) of $($Steps.Count)"
            Write-BufferString -X 10 -Y $progressY -Text $progressText
            
            # Progress bar
            $progress = ($self.State.CurrentStep + 1) / $Steps.Count
            $progressBar = Create-TuiComponent -Type "ProgressBar" -Props @{
                X = 10
                Y = $progressY + 1
                Width = 60
                Value = $progress * 100
                Max = 100
                ShowPercent = $false
            }
            & $progressBar.Render -self $progressBar
            
            # Current step
            $currentStep = $Steps[$self.State.CurrentStep]
            if ($currentStep.Render) {
                & $currentStep.Render -self $self -StepData $self.State.Data
            }
            
            # Navigation buttons
            $navY = 20
            if ($self.State.CurrentStep -gt 0) {
                Write-BufferString -X 10 -Y $navY -Text "[← Previous]" -ForegroundColor (Get-ThemeColor "Primary")
            }
            
            if ($self.State.CurrentStep -lt ($Steps.Count - 1)) {
                Write-BufferString -X 60 -Y $navY -Text "[Next →]" -ForegroundColor (Get-ThemeColor "Primary")
            } else {
                Write-BufferString -X 60 -Y $navY -Text "[Complete ✓]" -ForegroundColor (Get-ThemeColor "Success")
            }
        }
        
        HandleInput = {
            param($self, $Key)
            
            $currentStep = $Steps[$self.State.CurrentStep]
            
            # Let step handle input first
            if ($currentStep.HandleInput) {
                $result = & $currentStep.HandleInput -self $self -Key $Key -StepData $self.State.Data
                if ($result) { return $result }
            }
            
            # Navigation
            switch ($Key.Key) {
                ([ConsoleKey]::LeftArrow) {
                    if ($self.State.CurrentStep -gt 0) {
                        $self.State.CurrentStep--
                        Request-TuiRefresh
                        return $true
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($self.State.CurrentStep -lt ($Steps.Count - 1)) {
                        # Validate current step
                        if ($currentStep.Validate) {
                            $isValid = & $currentStep.Validate -StepData $self.State.Data
                            if (-not $isValid) {
                                Show-TuiNotification -Message "Please complete all required fields" -Type "Warning"
                                return $true
                            }
                        }
                        
                        $self.State.CurrentStep++
                        Request-TuiRefresh
                        return $true
                    } else {
                        # Complete wizard
                        if ($OnComplete) {
                            & $OnComplete -WizardData $self.State.Data
                        }
                        Pop-Screen
                        return $true
                    }
                }
            }
            
            return $false
        }
    }
    
    return $wizard
}

# Export all functions
Export-ModuleMember -Function @(
    'Initialize-TuiFramework',
    'Create-TuiComponent',
    'Create-TuiScreen',
    'Create-TuiForm',
    'Show-TuiMessageBox',
    'Show-TuiNotification',
    'Create-TuiWizard'
)