# Dialog System Module (Fixed Input Handling)
# Provides a high-level API for modal dialogs using a robust, component-based architecture.

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

    # This dialog is a TuiForm containing a Label, TextBox, and Buttons.
    $form = New-TuiForm -Props @{
        Name    = "InputDialogForm"
        Title   = " $Title "
        Width   = [Math]::Min(80, [Math]::Max(50, $Prompt.Length + 6))
        Height  = 12
        Padding = 2
        State   = @{
            InputValue       = $DefaultValue
            InputCursor      = $DefaultValue.Length
            FocusedChildName = "InputTextBox" # Start focus on the textbox
        }
        Children = @(
            New-TuiLabel -Props @{
                Name = "PromptLabel"
                X = 0; Y = 0
                Text = $Prompt
            }
            New-TuiTextBox -Props @{
                Name           = "InputTextBox"
                X = 0; Y = 2
                Width          = [Math]::Min(76, [Math]::Max(46, $Prompt.Length + 2))
                TextProp       = "InputValue"
                CursorProp     = "InputCursor"
                OnChange       = { $this.State.InputValue = $args[0].NewText; $this.State.InputCursor = $args[0].NewCursorPosition }
            }
            New-TuiButton -Props @{
                Name    = "SubmitButton"
                X = 0; Y = 6
                Width   = 12
                Text    = "OK"
                OnClick = { 
                    Close-TuiDialog
                    & $OnSubmit -Value $this.State.InputValue
                }
            }
            New-TuiButton -Props @{
                Name    = "CancelButton"
                X = 14; Y = 6
                Width   = 12
                Text    = "Cancel"
                OnClick = { 
                    Close-TuiDialog
                    & $OnCancel
                }
            }
        )
        # Override the form's input handler to also catch Enter/Escape globally
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -eq [ConsoleKey]::Escape) {
                Close-TuiDialog
                & $OnCancel
                return $true
            }
            
            # Let the default TuiForm handler manage Tab and child input (Enter on buttons, etc.)
            $formPrototype = New-TuiForm
            $handledByChild = & $formPrototype.HandleInput -self $self -Key $Key

            # If not handled by a child (e.g. Enter in TextBox), treat as submit
            if (-not $handledByChild -and $Key.Key -eq [ConsoleKey]::Enter) {
                Close-TuiDialog
                & $OnSubmit -Value $self.State.InputValue
                return $true
            }

            return $handledByChild
        }.GetNewClosure()
    }
    Show-TuiDialog -DialogComponent $form
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
        # Center the dialog component before rendering
        $dialog = $script:DialogState.CurrentDialog
        $dialog.X = [Math]::Floor(($script:TuiState.BufferWidth - $dialog.Width) / 2)
        $dialog.Y = [Math]::Floor(($script:TuiState.BufferHeight - $dialog.Height) / 2)
        
        & $dialog.Render -self $dialog
    }
}

function global:Handle-DialogInput {
    <# .SYNOPSIS Engine Hook: Intercepts input if a dialog is active. #>
    param($Key)  # Removed type constraint to match fixed input handling
    
    if ($script:DialogState.CurrentDialog) {
        return & $script:DialogState.CurrentDialog.HandleInput -self $script:DialogState.CurrentDialog -Key $Key
    }
    return $false # No active dialog, input was not handled.
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
        Title = $Props.Title ?? "Dialog"
        Message = $Props.Message ?? ""
        Buttons = $Props.Buttons ?? @("OK")
        SelectedButton = 0
        Width = $Props.Width ?? 50
        Height = $Props.Height ?? 10
        X = 0
        Y = 0
        OnButtonClick = $Props.OnButtonClick ?? {}
        OnCancel = $Props.OnCancel ?? {}
        
        Render = {
            param($self)
            
            # Draw dialog box
            Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height -Title $self.Title -BorderColor (Get-ThemeColor "Accent")
            
            # Message
            $messageY = $self.Y + 2
            $messageX = $self.X + 2
            $maxWidth = $self.Width - 4
            
            # Word wrap message if needed
            if ($self.Message.Length -le $maxWidth) {
                Write-BufferString -X $messageX -Y $messageY -Text $self.Message -ForegroundColor (Get-ThemeColor "Primary")
            } else {
                # Simple word wrapping
                $words = $self.Message -split ' '
                $line = ""
                $currentY = $messageY
                
                foreach ($word in $words) {
                    if (($line + " " + $word).Length -gt $maxWidth) {
                        Write-BufferString -X $messageX -Y $currentY -Text $line.Trim() -ForegroundColor (Get-ThemeColor "Primary")
                        $currentY++
                        $line = $word
                    } else {
                        $line = if ($line) { "$line $word" } else { $word }
                    }
                }
                if ($line) {
                    Write-BufferString -X $messageX -Y $currentY -Text $line.Trim() -ForegroundColor (Get-ThemeColor "Primary")
                }
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
                ([ConsoleKey]::Escape) {
                    & $self.OnCancel
                    return $true
                }
            }
            
            # Check for button hotkeys (first letter)
            if ($Key.KeyChar) {
                $char = [char]::ToUpper($Key.KeyChar)
                for ($i = 0; $i -lt $self.Buttons.Count; $i++) {
                    if ($self.Buttons[$i].Length -gt 0 -and [char]::ToUpper($self.Buttons[$i][0]) -eq $char) {
                        & $self.OnButtonClick -Button $self.Buttons[$i] -Index $i
                        return $true
                    }
                }
            }
            
            return $false
        }
    }
    
    return $dialog
}

#endregion

Export-ModuleMember -Function @(
    'Initialize-DialogSystem',
    'Show-ConfirmDialog',
    'Show-AlertDialog',
    'Show-InputDialog',
    'Close-TuiDialog',
    'Render-Dialogs',
    'Handle-DialogInput',
    'Update-DialogSystem',
    'New-TuiDialog'
)