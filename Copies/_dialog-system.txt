
# Dialog System Module - FIXED VERSION
# Uses engine's word wrap helper and respects the framework

$script:DialogState = @{
    CurrentDialog = $null
    DialogStack   = [System.Collections.Stack]::new()
}

#region --- Public API & Factory Functions ---

function global:Show-TuiDialog {
    <# .SYNOPSIS Internal function to display a dialog component. #>
    param([hashtable]$DialogComponent)
    
    if ($script:DialogState.CurrentDialog) {
        $script:DialogState.DialogStack.Push($script:DialogState.CurrentDialog)
    }
    $script:DialogState.CurrentDialog = $DialogComponent
    Request-TuiRefresh
}

function global:Close-TuiDialog {
    <# .SYNOPSIS Closes the current dialog and restores the previous one, if any. #>
    if ($script:DialogState.DialogStack.Count -gt 0) {
        $script:DialogState.CurrentDialog = $script:DialogState.DialogStack.Pop()
    } else {
        $script:DialogState.CurrentDialog = $null
    }
    Request-TuiRefresh
}

function global:Show-ConfirmDialog {
    <# .SYNOPSIS Displays a standard Yes/No confirmation dialog. #>
    param(
        [string]$Title = "Confirm",
        [string]$Message,
        [scriptblock]$OnConfirm,
        [scriptblock]$OnCancel = {}
    )
    
    $dialog = New-TuiDialog -Props @{
        Title         = $Title
        Message       = $Message
        Buttons       = @("Yes", "No")
        Width         = [Math]::Min(80, [Math]::Max(50, $Message.Length + 10))
        Height        = 10
        OnButtonClick = {
            param($Button, $Index)
            Close-TuiDialog
            if ($Index -eq 0) { & $OnConfirm } else { & $OnCancel }
        }
        OnCancel      = { Close-TuiDialog; & $OnCancel }
    }
    Show-TuiDialog -DialogComponent $dialog
}

function global:Show-AlertDialog {
    <# .SYNOPSIS Displays a simple alert with an OK button. #>
    param(
        [string]$Title = "Alert",
        [string]$Message
    )
    
    $dialog = New-TuiDialog -Props @{
        Title         = $Title
        Message       = $Message
        Buttons       = @("OK")
        Width         = [Math]::Min(80, [Math]::Max(40, $Message.Length + 10))
        Height        = 10
        OnButtonClick = { Close-TuiDialog }
        OnCancel      = { Close-TuiDialog }
    }
    Show-TuiDialog -DialogComponent $dialog
}

function global:Show-InputDialog {
    <# .SYNOPSIS Displays a dialog to get text input from the user. #>
    param(
        [string]$Title = "Input",
        [string]$Prompt,
        [string]$DefaultValue = "",
        [scriptblock]$OnSubmit,
        [scriptblock]$OnCancel = {}
    )

    # Create a screen that contains the input components
    $inputScreen = @{
        Name = "InputDialog"
        State = @{
            InputValue = $DefaultValue
            FocusedIndex = 0  # Start with textbox focused
        }
        _focusableNames = @("InputTextBox", "OKButton", "CancelButton")
        _focusedIndex = 0
        
        Render = {
            param($self)
            
            # Calculate dialog dimensions
            $dialogWidth = [Math]::Min(70, [Math]::Max(50, $Prompt.Length + 10))
            $dialogHeight = 10
            $dialogX = [Math]::Floor(($global:TuiState.BufferWidth - $dialogWidth) / 2)
            $dialogY = [Math]::Floor(($global:TuiState.BufferHeight - $dialogHeight) / 2)
            
            # Draw dialog box
            Write-BufferBox -X $dialogX -Y $dialogY -Width $dialogWidth -Height $dialogHeight `
                -Title " $Title " -BorderColor (Get-ThemeColor "Accent")
            
            # Draw prompt
            $promptX = $dialogX + 2
            $promptY = $dialogY + 2
            Write-BufferString -X $promptX -Y $promptY -Text $Prompt
            
            # Draw text input
            $inputY = $promptY + 2
            $inputWidth = $dialogWidth - 4
            $isFocused = ($self._focusedIndex -eq 0)
            $borderColor = if ($isFocused) { Get-ThemeColor "Warning" } else { Get-ThemeColor "Primary" }
            
            Write-BufferBox -X $promptX -Y $inputY -Width $inputWidth -Height 3 `
                -BorderColor $borderColor
            
            # Draw input value
            $displayText = $self.State.InputValue
            if ($displayText.Length > ($inputWidth - 3)) {
                $displayText = $displayText.Substring($displayText.Length - ($inputWidth - 3))
            }
            Write-BufferString -X ($promptX + 1) -Y ($inputY + 1) -Text $displayText
            
            # Draw cursor if textbox is focused
            if ($isFocused) {
                $cursorPos = [Math]::Min($self.State.InputValue.Length, $inputWidth - 3)
                Write-BufferString -X ($promptX + 1 + $cursorPos) -Y ($inputY + 1) `
                    -Text "_" -ForegroundColor (Get-ThemeColor "Warning")
            }
            
            # Draw buttons
            $buttonY = $dialogY + $dialogHeight - 2
            $buttonSpacing = 15
            $buttonsWidth = $buttonSpacing * 2
            $buttonX = $dialogX + [Math]::Floor(($dialogWidth - $buttonsWidth) / 2)
            
            # OK button
            $okFocused = ($self._focusedIndex -eq 1)
            $okText = if ($okFocused) { "[ OK ]" } else { "  OK  " }
            $okColor = if ($okFocused) { Get-ThemeColor "Warning" } else { Get-ThemeColor "Primary" }
            Write-BufferString -X $buttonX -Y $buttonY -Text $okText -ForegroundColor $okColor
            
            # Cancel button
            $cancelFocused = ($self._focusedIndex -eq 2)
            $cancelText = if ($cancelFocused) { "[ Cancel ]" } else { "  Cancel  " }
            $cancelColor = if ($cancelFocused) { Get-ThemeColor "Warning" } else { Get-ThemeColor "Primary" }
            Write-BufferString -X ($buttonX + $buttonSpacing) -Y $buttonY -Text $cancelText -ForegroundColor $cancelColor
        }
        
        HandleInput = {
            param($self, $Key)
            
            # Handle Tab navigation
            if ($Key.Key -eq [ConsoleKey]::Tab) {
                $direction = if ($Key.Modifiers -band [ConsoleModifiers]::Shift) { -1 } else { 1 }
                $self._focusedIndex = ($self._focusedIndex + $direction + 3) % 3
                Request-TuiRefresh
                return $true
            }
            
            # Handle Escape
            if ($Key.Key -eq [ConsoleKey]::Escape) {
                Close-TuiDialog
                & $OnCancel
                return $true
            }
            
            # Handle based on focused element
            switch ($self._focusedIndex) {
                0 {  # TextBox
                    switch ($Key.Key) {
                        ([ConsoleKey]::Enter) {
                            Close-TuiDialog
                            & $OnSubmit -Value $self.State.InputValue
                            return $true
                        }
                        ([ConsoleKey]::Backspace) {
                            if ($self.State.InputValue.Length -gt 0) {
                                $self.State.InputValue = $self.State.InputValue.Substring(0, $self.State.InputValue.Length - 1)
                                Request-TuiRefresh
                            }
                            return $true
                        }
                        default {
                            if ($Key.KeyChar -and -not [char]::IsControl($Key.KeyChar)) {
                                $self.State.InputValue += $Key.KeyChar
                                Request-TuiRefresh
                                return $true
                            }
                        }
                    }
                }
                1 {  # OK Button
                    if ($Key.Key -eq [ConsoleKey]::Enter -or $Key.Key -eq [ConsoleKey]::Spacebar) {
                        Close-TuiDialog
                        & $OnSubmit -Value $self.State.InputValue
                        return $true
                    }
                }
                2 {  # Cancel Button
                    if ($Key.Key -eq [ConsoleKey]::Enter -or $Key.Key -eq [ConsoleKey]::Spacebar) {
                        Close-TuiDialog
                        & $OnCancel
                        return $true
                    }
                }
            }
            
            return $false
        }
    }
    
    $script:DialogState.CurrentDialog = $inputScreen
    Request-TuiRefresh
}

#endregion

#region --- Engine Integration & Initialization ---

function global:Initialize-DialogSystem {
    <# .SYNOPSIS Subscribes to high-level application events to show dialogs. #>
    
    Subscribe-Event -EventName "Confirm.Request" -Handler {
        param($EventData)
        $dialogParams = $EventData.Data
        Show-ConfirmDialog @dialogParams
    }
    
    Subscribe-Event -EventName "Alert.Show" -Handler {
        param($EventData)
        $dialogParams = $EventData.Data
        Show-AlertDialog @dialogParams
    }
    
    Subscribe-Event -EventName "Input.Request" -Handler {
        param($EventData)
        $dialogParams = $EventData.Data
        Show-InputDialog @dialogParams
    }
    
    Write-Verbose "Dialog System initialized and event handlers registered."
}

function global:Render-Dialogs {
    <# .SYNOPSIS Engine Hook: Renders the current dialog over the screen. #>
    if ($script:DialogState.CurrentDialog) {
        # If it's a component with its own render method
        if ($script:DialogState.CurrentDialog.Render) {
            & $script:DialogState.CurrentDialog.Render -self $script:DialogState.CurrentDialog
        }
    }
}

function global:Handle-DialogInput {
    <# .SYNOPSIS Engine Hook: Intercepts input if a dialog is active. #>
    param($Key)
    
    if ($script:DialogState.CurrentDialog) {
        if ($script:DialogState.CurrentDialog.HandleInput) {
            return & $script:DialogState.CurrentDialog.HandleInput -self $script:DialogState.CurrentDialog -Key $Key
        }
    }
    return $false
}

function global:Update-DialogSystem {
    <# .SYNOPSIS Engine Hook: Updates dialog system state. #>
    # Placeholder for any periodic updates needed
}

function global:New-TuiDialog {
    <# .SYNOPSIS Creates a simple dialog component. #>
    param([hashtable]$Props = @{})
    
    $dialog = @{
        Type = "Dialog"
        Title = if ($Props.Title) { $Props.Title } else { "Dialog" }
        Message = if ($Props.Message) { $Props.Message } else { "" }
        Buttons = if ($Props.Buttons) { $Props.Buttons } else { @("OK") }
        SelectedButton = 0
        Width = if ($Props.Width) { $Props.Width } else { 50 }
        Height = if ($Props.Height) { $Props.Height } else { 10 }
        X = 0
        Y = 0
        OnButtonClick = if ($Props.OnButtonClick) { $Props.OnButtonClick } else { {} }
        OnCancel = if ($Props.OnCancel) { $Props.OnCancel } else { {} }
        
        Render = {
            param($self)
            
            # Center the dialog
            $self.X = [Math]::Floor(($global:TuiState.BufferWidth - $self.Width) / 2)
            $self.Y = [Math]::Floor(($global:TuiState.BufferHeight - $self.Height) / 2)
            
            # Draw dialog box
            Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height `
                -Title $self.Title -BorderColor (Get-ThemeColor "Accent")
            
            # Use engine's word wrap helper
            $messageY = $self.Y + 2
            $messageX = $self.X + 2
            $maxWidth = $self.Width - 4
            
            $wrappedLines = Get-WordWrappedLines -Text $self.Message -MaxWidth $maxWidth
            
            foreach ($line in $wrappedLines) {
                if ($messageY -ge ($self.Y + $self.Height - 3)) { break }  # Don't overwrite buttons
                Write-BufferString -X $messageX -Y $messageY -Text $line -ForegroundColor (Get-ThemeColor "Primary")
                $messageY++
            }
            
            # Buttons
            $buttonY = $self.Y + $self.Height - 3
            $totalButtonWidth = ($self.Buttons.Count * 12) + (($self.Buttons.Count - 1) * 2)
            $buttonX = $self.X + [Math]::Floor(($self.Width - $totalButtonWidth) / 2)
            
            for ($i = 0; $i -lt $self.Buttons.Count; $i++) {
                $isSelected = ($i -eq $self.SelectedButton)
                $buttonText = if ($isSelected) { "[ $($self.Buttons[$i]) ]" } else { "  $($self.Buttons[$i])  " }
                $color = if ($isSelected) { Get-ThemeColor "Warning" } else { Get-ThemeColor "Primary" }
                
                Write-BufferString -X $buttonX -Y $buttonY -Text $buttonText -ForegroundColor $color
                $buttonX += 14
            }
        }
        
        HandleInput = {
            param($self, $Key)
            
            switch ($Key.Key) {
                ([ConsoleKey]::LeftArrow) {
                    $self.SelectedButton = [Math]::Max(0, $self.SelectedButton - 1)
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::RightArrow) {
                    $self.SelectedButton = [Math]::Min($self.Buttons.Count - 1, $self.SelectedButton + 1)
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::Tab) {
                    $self.SelectedButton = ($self.SelectedButton + 1) % $self.Buttons.Count
                    Request-TuiRefresh
                    return $true
                }
                
                ([ConsoleKey]::Enter) {
                    & $self.OnButtonClick -Button $self.Buttons[$self.SelectedButton] -Index $self.SelectedButton
                    return $true
                }
                ([ConsoleKey]::Spacebar) {
                    & $self.OnButtonClick -Button $self.Buttons[$self.SelectedButton] -Index $self.SelectedButton
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    & $self.OnCancel
                    return $true
                }
            }
            
            return $false
        }
    }
    
    return $dialog
}

function global:Show-ProgressDialog {
    <# .SYNOPSIS Shows a progress dialog with updating percentage. #>
    param(
        [string]$Title = "Progress",
        [string]$Message = "Processing...",
        [int]$PercentComplete = 0,
        [switch]$ShowCancel
    )
    
    $dialog = @{
        Type = "ProgressDialog"
        Title = $Title
        Message = $Message
        PercentComplete = $PercentComplete
        Width = 60
        Height = 8
        ShowCancel = $ShowCancel
        IsCancelled = $false
        
        Render = {
            param($self)
            
            # Center the dialog
            $x = [Math]::Floor(($global:TuiState.BufferWidth - $self.Width) / 2)
            $y = [Math]::Floor(($global:TuiState.BufferHeight - $self.Height) / 2)
            
            # Draw dialog box
            Write-BufferBox -X $x -Y $y -Width $self.Width -Height $self.Height `
                -Title " $($self.Title) " -BorderColor (Get-ThemeColor "Accent")
            
            # Draw message
            Write-BufferString -X ($x + 2) -Y ($y + 2) -Text $self.Message
            
            # Draw progress bar
            $barY = $y + 4
            $barWidth = $self.Width - 4
            $filledWidth = [Math]::Floor($barWidth * ($self.PercentComplete / 100))
            
            # Progress bar background
            Write-BufferString -X ($x + 2) -Y $barY `
                -Text ("─" * $barWidth) -ForegroundColor (Get-ThemeColor "Border")
            
            # Progress bar fill
            if ($filledWidth -gt 0) {
                Write-BufferString -X ($x + 2) -Y $barY `
                    -Text ("█" * $filledWidth) -ForegroundColor (Get-ThemeColor "Success")
            }
            
            # Percentage text
            $percentText = "$($self.PercentComplete)%"
            $percentX = $x + [Math]::Floor(($self.Width - $percentText.Length) / 2)
            Write-BufferString -X $percentX -Y $barY -Text $percentText
            
            # Cancel button if requested
            if ($self.ShowCancel) {
                $buttonY = $y + $self.Height - 2
                $buttonText = if ($self.IsCancelled) { "[ Cancelling... ]" } else { "[ Cancel ]" }
                $buttonX = $x + [Math]::Floor(($self.Width - $buttonText.Length) / 2)
                Write-BufferString -X $buttonX -Y $buttonY -Text $buttonText `
                    -ForegroundColor (Get-ThemeColor "Warning")
            }
        }
        
        HandleInput = {
            param($self, $Key)
            
            if ($self.ShowCancel -and -not $self.IsCancelled) {
                if ($Key.Key -eq [ConsoleKey]::Escape -or 
                    $Key.Key -eq [ConsoleKey]::Enter -or 
                    $Key.Key -eq [ConsoleKey]::Spacebar) {
                    $self.IsCancelled = $true
                    Request-TuiRefresh
                    return $true
                }
            }
            
            return $false
        }
        
        UpdateProgress = {
            param($self, [int]$PercentComplete, [string]$Message = $null)
            $self.PercentComplete = [Math]::Min(100, [Math]::Max(0, $PercentComplete))
            if ($Message) { $self.Message = $Message }
            Request-TuiRefresh
        }
    }
    
    $script:DialogState.CurrentDialog = $dialog
    Request-TuiRefresh
    return $dialog
}

function global:Show-ListDialog {
    <# .SYNOPSIS Shows a dialog with a selectable list of items. #>
    param(
        [string]$Title = "Select Item",
        [string]$Prompt = "Choose an item:",
        [array]$Items,
        [scriptblock]$OnSelect,
        [scriptblock]$OnCancel = {},
        [switch]$AllowMultiple
    )
    
    $dialog = @{
        Type = "ListDialog"
        Title = $Title
        Prompt = $Prompt
        Items = $Items
        SelectedIndex = 0
        SelectedItems = @()
        Width = 60
        Height = [Math]::Min(20, $Items.Count + 8)
        AllowMultiple = $AllowMultiple
        
        Render = {
            param($self)
            
            $x = [Math]::Floor(($global:TuiState.BufferWidth - $self.Width) / 2)
            $y = [Math]::Floor(($global:TuiState.BufferHeight - $self.Height) / 2)
            
            # Draw dialog box
            Write-BufferBox -X $x -Y $y -Width $self.Width -Height $self.Height `
                -Title " $($self.Title) " -BorderColor (Get-ThemeColor "Accent")
            
            # Draw prompt
            Write-BufferString -X ($x + 2) -Y ($y + 2) -Text $self.Prompt
            
            # Calculate list area
            $listY = $y + 4
            $listHeight = $self.Height - 7
            $listWidth = $self.Width - 4
            
            # Draw scrollable list
            $startIndex = [Math]::Max(0, $self.SelectedIndex - [Math]::Floor($listHeight / 2))
            $endIndex = [Math]::Min($self.Items.Count - 1, $startIndex + $listHeight - 1)
            
            for ($i = $startIndex; $i -le $endIndex; $i++) {
                $itemY = $listY + ($i - $startIndex)
                $item = $self.Items[$i]
                $isSelected = ($i -eq $self.SelectedIndex)
                $isChecked = $self.SelectedItems -contains $i
                
                # Selection indicator
                $prefix = ""
                if ($self.AllowMultiple) {
                    $prefix = if ($isChecked) { "[X] " } else { "[ ] " }
                }
                
                $itemText = "$prefix$item"
                if ($itemText.Length -gt $listWidth - 2) {
                    $itemText = $itemText.Substring(0, $listWidth - 5) + "..."
                }
                
                $bgColor = if ($isSelected) { Get-ThemeColor "Selection" } else { $null }
                $fgColor = if ($isSelected) { Get-ThemeColor "Background" } else { Get-ThemeColor "Primary" }
                
                Write-BufferString -X ($x + 2) -Y $itemY -Text $itemText `
                    -ForegroundColor $fgColor -BackgroundColor $bgColor
            }
            
            # Draw scrollbar if needed
            if ($self.Items.Count -gt $listHeight) {
                $scrollbarX = $x + $self.Width - 2
                $scrollbarHeight = $listHeight
                $thumbSize = [Math]::Max(1, [Math]::Floor($scrollbarHeight * $listHeight / $self.Items.Count))
                $thumbPos = [Math]::Floor($scrollbarHeight * $self.SelectedIndex / $self.Items.Count)
                
                for ($i = 0; $i -lt $scrollbarHeight; $i++) {
                    $char = if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) { "█" } else { "│" }
                    Write-BufferString -X $scrollbarX -Y ($listY + $i) -Text $char `
                        -ForegroundColor (Get-ThemeColor "Border")
                }
            }
            
            # Draw buttons
            $buttonY = $y + $self.Height - 2
            if ($self.AllowMultiple) {
                $okText = "[ OK ]"
                $cancelText = "[ Cancel ]"
                $buttonSpacing = 15
                $totalWidth = 30
                $startX = $x + [Math]::Floor(($self.Width - $totalWidth) / 2)
                
                Write-BufferString -X $startX -Y $buttonY -Text $okText `
                    -ForegroundColor (Get-ThemeColor "Success")
                Write-BufferString -X ($startX + $buttonSpacing) -Y $buttonY -Text $cancelText `
                    -ForegroundColor (Get-ThemeColor "Primary")
            }
        }
        
        HandleInput = {
            param($self, $Key)
            
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) {
                    $self.SelectedIndex = [Math]::Max(0, $self.SelectedIndex - 1)
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    $self.SelectedIndex = [Math]::Min($self.Items.Count - 1, $self.SelectedIndex + 1)
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::Spacebar) {
                    if ($self.AllowMultiple) {
                        if ($self.SelectedItems -contains $self.SelectedIndex) {
                            $self.SelectedItems = $self.SelectedItems | Where-Object { $_ -ne $self.SelectedIndex }
                        } else {
                            $self.SelectedItems += $self.SelectedIndex
                        }
                        Request-TuiRefresh
                        return $true
                    }
                }
                ([ConsoleKey]::Enter) {
                    Close-TuiDialog
                    if ($self.AllowMultiple) {
                        $selectedValues = $self.SelectedItems | ForEach-Object { $self.Items[$_] }
                        & $OnSelect -Selected $selectedValues
                    } else {
                        & $OnSelect -Selected $self.Items[$self.SelectedIndex]
                    }
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    Close-TuiDialog
                    & $OnCancel
                    return $true
                }
            }
            
            return $false
        }
    }
    
    $script:DialogState.CurrentDialog = $dialog
    Request-TuiRefresh
}

#endregion

# Export all public functions
Export-ModuleMember -Function @(
    'Initialize-DialogSystem',
    'Show-TuiDialog',
    'Close-TuiDialog',
    'Show-ConfirmDialog',
    'Show-AlertDialog',
    'Show-InputDialog',
    'Show-ProgressDialog',
    'Show-ListDialog',
    'Render-Dialogs',
    'Handle-DialogInput',
    'Update-DialogSystem',
    'New-TuiDialog'
)