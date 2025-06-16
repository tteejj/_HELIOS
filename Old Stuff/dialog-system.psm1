# Dialog System for TUI
# Handles confirmations, inputs, and alerts

#region Dialog Management

$script:DialogState = @{
    CurrentDialog = $null
    DialogStack = [System.Collections.Stack]::new()
}

function global:Show-TuiDialog {
    param([hashtable]$Dialog)
    
    # Save current dialog if any
    if ($script:DialogState.CurrentDialog) {
        $script:DialogState.DialogStack.Push($script:DialogState.CurrentDialog)
    }
    
    $script:DialogState.CurrentDialog = $Dialog
    Request-TuiRefresh
}

function global:Close-TuiDialog {
    $script:DialogState.CurrentDialog = $null
    
    # Restore previous dialog if any
    if ($script:DialogState.DialogStack.Count -gt 0) {
        $script:DialogState.CurrentDialog = $script:DialogState.DialogStack.Pop()
    }
    
    Request-TuiRefresh
}

#endregion

#region Dialog Factory Functions

function global:Show-ConfirmDialog {
    param(
        [string]$Title = "Confirm",
        [string]$Message,
        [string]$ConfirmText = "Yes",
        [string]$CancelText = "No",
        [scriptblock]$OnConfirm,
        [scriptblock]$OnCancel
    )
    
    $dialog = New-TuiDialog -Props @{
        Title = $Title
        Message = $Message
        Buttons = @($ConfirmText, $CancelText)
        Width = [Math]::Max(50, $Message.Length + 10)
        Height = 10
        OnButtonClick = {
            param($Button, $Index)
            if ($Index -eq 0 -and $OnConfirm) {
                & $OnConfirm
            } elseif ($Index -eq 1 -and $OnCancel) {
                & $OnCancel
            }
            Close-TuiDialog
        }
        OnCancel = {
            if ($OnCancel) { & $OnCancel }
            Close-TuiDialog
        }
    }
    
    Show-TuiDialog -Dialog $dialog
}

function global:Show-AlertDialog {
    param(
        [string]$Title = "Alert",
        [string]$Message,
        [string]$ButtonText = "OK"
    )
    
    $dialog = New-TuiDialog -Props @{
        Title = $Title
        Message = $Message
        Buttons = @($ButtonText)
        Width = [Math]::Max(40, $Message.Length + 10)
        Height = 10
        OnButtonClick = {
            Close-TuiDialog
        }
        OnCancel = {
            Close-TuiDialog
        }
    }
    
    Show-TuiDialog -Dialog $dialog
}

function global:Show-InputDialog {
    param(
        [string]$Title = "Input",
        [string]$Prompt,
        [string]$DefaultValue = "",
        [scriptblock]$OnSubmit,
        [scriptblock]$OnCancel
    )
    
    # Create a custom input dialog
    $dialogState = @{
        Value = $DefaultValue
        CursorPosition = $DefaultValue.Length
    }
    
    $dialog = @{
        Type = "InputDialog"
        Title = $Title
        Prompt = $Prompt
        State = $dialogState
        Width = [Math]::Max(50, $Prompt.Length + 10)
        Height = 12
        
        Render = {
            param($self)
            
            # Center the dialog
            $x = [Math]::Floor(($script:TuiState.BufferWidth - $self.Width) / 2)
            $y = [Math]::Floor(($script:TuiState.BufferHeight - $self.Height) / 2)
            
            # Draw shadow
            for ($sy = 1; $sy -lt $self.Height; $sy++) {
                for ($sx = 1; $sx -lt $self.Width; $sx++) {
                    Write-BufferString -X ($x + $sx + 1) -Y ($y + $sy + 1) -Text " " `
                        -BackgroundColor [ConsoleColor]::Black
                }
            }
            
            # Draw dialog box
            Write-BufferBox -X $x -Y $y -Width $self.Width -Height $self.Height `
                -BorderStyle "Double" -BorderColor (Get-ThemeColor "Accent") `
                -Title " $($self.Title) "
            
            # Prompt
            Write-BufferString -X ($x + 2) -Y ($y + 2) -Text $self.Prompt
            
            # Input box
            $inputY = $y + 4
            Write-BufferBox -X ($x + 2) -Y $inputY -Width ($self.Width - 4) -Height 3 `
                -BorderColor (Get-ThemeColor "Accent")
            
            # Input text
            $text = $self.State.Value
            $displayText = if ($text.Length -gt $self.Width - 8) {
                $text.Substring($text.Length - ($self.Width - 8))
            } else { $text }
            
            Write-BufferString -X ($x + 4) -Y ($inputY + 1) -Text $displayText
            
            # Cursor
            $cursorX = $x + 4 + [Math]::Min($self.State.CursorPosition, $self.Width - 8)
            Write-BufferString -X $cursorX -Y ($inputY + 1) -Text "_" `
                -BackgroundColor (Get-ThemeColor "Accent")
            
            # Buttons
            $buttonY = $y + $self.Height - 3
            $okX = $x + [Math]::Floor(($self.Width - 20) / 3)
            $cancelX = $x + [Math]::Floor(($self.Width - 20) * 2 / 3) + 10
            
            Write-BufferString -X $okX -Y $buttonY -Text "[ OK ]" `
                -ForegroundColor (Get-ThemeColor "Success")
            Write-BufferString -X $cancelX -Y $buttonY -Text "[ Cancel ]" `
                -ForegroundColor (Get-ThemeColor "Secondary")
        }
        
        HandleInput = {
            param($self, $Key)
            
            switch ($Key.Key) {
                ([ConsoleKey]::Backspace) {
                    if ($self.State.CursorPosition -gt 0) {
                        $self.State.Value = $self.State.Value.Remove($self.State.CursorPosition - 1, 1)
                        $self.State.CursorPosition--
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::Delete) {
                    if ($self.State.CursorPosition -lt $self.State.Value.Length) {
                        $self.State.Value = $self.State.Value.Remove($self.State.CursorPosition, 1)
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($self.State.CursorPosition -gt 0) {
                        $self.State.CursorPosition--
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::RightArrow) {
                    if ($self.State.CursorPosition -lt $self.State.Value.Length) {
                        $self.State.CursorPosition++
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::Home) {
                    $self.State.CursorPosition = 0
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::End) {
                    $self.State.CursorPosition = $self.State.Value.Length
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    if ($OnSubmit) {
                        & $OnSubmit -Value $self.State.Value
                    }
                    Close-TuiDialog
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    if ($OnCancel) {
                        & $OnCancel
                    }
                    Close-TuiDialog
                    return $true
                }
                default {
                    if ($Key.KeyChar -and -not [char]::IsControl($Key.KeyChar)) {
                        $self.State.Value = $self.State.Value.Insert($self.State.CursorPosition, $Key.KeyChar)
                        $self.State.CursorPosition++
                        Request-TuiRefresh
                        return $true
                    }
                }
            }
            
            return $false
        }
    }
    
    Show-TuiDialog -Dialog $dialog
}

#endregion

#region Dialog Integration

function global:Initialize-DialogSystem {
    # Subscribe to dialog-related events
    Subscribe-Event -EventName "Confirm.Request" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        Show-ConfirmDialog -Title ($data.Title ?? "Confirm") `
            -Message $data.Message `
            -ConfirmText ($data.ConfirmText ?? "Yes") `
            -CancelText ($data.CancelText ?? "No") `
            -OnConfirm $data.OnConfirm `
            -OnCancel $data.OnCancel
    }
    
    Subscribe-Event -EventName "Alert.Show" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        Show-AlertDialog -Title ($data.Title ?? "Alert") `
            -Message $data.Message `
            -ButtonText ($data.ButtonText ?? "OK")
    }
    
    Subscribe-Event -EventName "Input.Request" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        Show-InputDialog -Title ($data.Title ?? "Input") `
            -Prompt $data.Prompt `
            -DefaultValue ($data.DefaultValue ?? "") `
            -OnSubmit $data.OnSubmit `
            -OnCancel $data.OnCancel
    }
    
    # Hook into screen rendering to overlay dialogs
    Subscribe-Event -EventName "Screen.Pushed" -Handler {
        $originalRender = $script:TuiState.CurrentScreen.Render
        $originalHandleInput = $script:TuiState.CurrentScreen.HandleInput
        
        # Wrap render to include dialog
        $script:TuiState.CurrentScreen.Render = {
            param($self)
            
            # Render the screen first
            & $originalRender -self $self
            
            # Overlay dialog if present
            if ($script:DialogState.CurrentDialog) {
                $dialog = $script:DialogState.CurrentDialog
                & $dialog.Render -self $dialog
            }
        }.GetNewClosure()
        
        # Wrap input handling to prioritize dialog
        $script:TuiState.CurrentScreen.HandleInput = {
            param($self, $Key)
            
            # Dialog handles input first
            if ($script:DialogState.CurrentDialog) {
                $dialog = $script:DialogState.CurrentDialog
                return & $dialog.HandleInput -self $dialog -Key $Key
            }
            
            # Otherwise, screen handles it
            return & $originalHandleInput -self $self -Key $Key
        }.GetNewClosure()
    } -SubscriberId "DialogSystem"
}

#endregion

Export-ModuleMember -Function @(
    'Show-TuiDialog', 'Close-TuiDialog',
    'Show-ConfirmDialog', 'Show-AlertDialog', 'Show-InputDialog',
    'Initialize-DialogSystem'
)
