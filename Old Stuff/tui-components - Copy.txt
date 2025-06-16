# TUI Component Library v3.0
# A library of stateless, declarative components for building robust TUIs.

#region Base Component & Container
function global:New-TuiComponent {
    param([hashtable]$Props = @{})

    $component = @{
        Name        = $Props.Name ?? "comp_$(Get-Random)"
        Type        = "Component"
        IsFocusable = $false
        Children    = @()
        Visible     = if ($Props.ContainsKey('Visible')) { $Props.Visible } else { $true }
        X           = $Props.X ?? 0
        Y           = $Props.Y ?? 0
        Width       = $Props.Width ?? 10
        Height      = $Props.Height ?? 1
        
        # Default Methods
        Render      = { param($self) }
        HandleInput = { param($self, $Key) return $false }
        Clone       = { 
            $clone = @{}
            foreach ($key in $this.Keys) {
                if ($this[$key] -is [scriptblock]) {
                    $clone[$key] = $this[$key]
                } elseif ($this[$key] -is [array]) {
                    $clone[$key] = @($this[$key])
                } elseif ($this[$key] -is [hashtable]) {
                    $clone[$key] = $this[$key].Clone()
                } else {
                    $clone[$key] = $this[$key]
                }
            }
            return $clone
        }
    }
    
    foreach ($key in $Props.Keys) { 
        if ($key -notin @('X', 'Y', 'Width', 'Height', 'Name', 'Type', 'IsFocusable', 'Visible')) {
            $component[$key] = $Props[$key] 
        }
    }
    return $component
}

function global:New-TuiForm {
    param([hashtable]$Props = @{})
    $form = New-TuiComponent -Props $Props
    $form.Type = "Form"
    
    $form.Render = {
        param($self)
        if (-not $self.Visible) { return }
        
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height `
            -Title $self.Title -BorderColor (Get-ThemeColor "Accent")
        
        foreach ($child in $self.Children) {
            if ($child.Visible) {
                $childToRender = $child.Clone()
                $childToRender.X += $self.X + ($self.Padding ?? 1)
                $childToRender.Y += $self.Y + ($self.Padding ?? 1)
                
                $childToRender.IsFocused = ($self.State.FocusedChildName -eq $child.Name)
                if ($child.TextProp) { $childToRender.Text = $self.State.($child.TextProp) }
                if ($child.CursorProp) { $childToRender.CursorPosition = $self.State.($child.CursorProp) }
                if ($child.ValueProp) { $childToRender.Value = $self.State.($child.ValueProp) }

                & $childToRender.Render -self $childToRender
            }
        }
    }

    $form.HandleInput = {
        param($self, $Key)
        $state = $self.State
        
        $focusableChildren = @($self.Children | Where-Object { $_.IsFocusable -and $_.Visible })
        if ($focusableChildren.Count -eq 0) { return $false }

        if ($Key.Key -eq [ConsoleKey]::Tab) {
            $currentIndex = [array]::IndexOf($focusableChildren.Name, $state.FocusedChildName)
            if ($currentIndex -eq -1) { $currentIndex = 0 }
            
            $direction = if ($Key.Modifiers -band [ConsoleModifiers]::Shift) { -1 } else { 1 }
            $nextIndex = ($currentIndex + $direction + $focusableChildren.Count) % $focusableChildren.Count
            
            if ($self.OnFocusChange) { 
                & $self.OnFocusChange -NewFocusedChildName $focusableChildren[$nextIndex].Name 
            }
            return $true
        }
        
        $focusedChild = $focusableChildren | Where-Object { $_.Name -eq $state.FocusedChildName } | Select-Object -First 1
        if ($focusedChild) {
            $childClone = $focusedChild.Clone()
            if ($focusedChild.TextProp) { $childClone.Text = $state.($focusedChild.TextProp) }
            if ($focusedChild.CursorProp) { $childClone.CursorPosition = $state.($focusedChild.CursorProp) }
            if ($focusedChild.ValueProp) { $childClone.Value = $state.($focusedChild.ValueProp) }

            return & $childClone.HandleInput -self $childClone -Key $Key
        }
        return $false
    }
    return $form
}
#endregion

#region --- All Concrete Components ---

function global:New-TuiLabel {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "Label"
    $component.Render = { 
        param($self) 
        Write-BufferString -X $self.X -Y $self.Y -Text $self.Text `
            -ForegroundColor ($self.ForegroundColor ?? (Get-ThemeColor "Primary"))
    }
    return $component
}

function global:New-TuiButton {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "Button"
    $component.IsFocusable = $true
    $component.Height = 3
    
    $component.Render = {
        param($self)
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
        $bgColor = if ($self.IsPressed) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Background" }
        $fgColor = if ($self.IsPressed) { Get-ThemeColor "Background" } else { $borderColor }
        
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height `
            -BorderColor $borderColor -BackgroundColor $bgColor
            
        $textX = $self.X + [Math]::Floor(($self.Width - $self.Text.Length) / 2)
        Write-BufferString -X $textX -Y ($self.Y + 1) -Text $self.Text `
            -ForegroundColor $fgColor -BackgroundColor $bgColor
    }
    
    $component.HandleInput = {
        param($self, $Key)
        if ($Key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            if ($self.OnClick) { & $self.OnClick }
            return $true
        }
        return $false
    }
    return $component
}

function global:New-TuiTextBox {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "TextBox"
    $component.IsFocusable = $true
    $component.Height = 3
    $component.Text = $Props.Text ?? ""
    $component.CursorPosition = $Props.CursorPosition ?? 0

    $component.Render = {
        param($self)
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height 3 -BorderColor $borderColor
        
        $displayText = $self.Text ?? ""
        if ([string]::IsNullOrEmpty($displayText) -and -not $self.IsFocused) { 
            $displayText = $self.Placeholder ?? "" 
        }
        
        # Simple text truncation for now
        $maxDisplayLength = $self.Width - 4
        if ($displayText.Length -gt $maxDisplayLength) {
            $displayText = $displayText.Substring(0, $maxDisplayLength)
        }
        
        Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text $displayText
        
        if ($self.IsFocused -and $self.CursorPosition -le $displayText.Length) {
            $cursorX = $self.X + 2 + $self.CursorPosition
            Write-BufferString -X $cursorX -Y ($self.Y + 1) -Text "_" `
                -BackgroundColor (Get-ThemeColor "Accent")
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        $text = $self.Text ?? ""
        $cursorPos = $self.CursorPosition ?? 0
        $oldText = $text

        switch ($Key.Key) {
            ([ConsoleKey]::Backspace) { 
                if ($cursorPos -gt 0) { 
                    $text = $text.Remove($cursorPos - 1, 1)
                    $cursorPos-- 
                } 
            }
            ([ConsoleKey]::Delete) { 
                if ($cursorPos -lt $text.Length) { 
                    $text = $text.Remove($cursorPos, 1) 
                } 
            }
            ([ConsoleKey]::LeftArrow) { 
                if ($cursorPos -gt 0) { $cursorPos-- } 
            }
            ([ConsoleKey]::RightArrow) { 
                if ($cursorPos -lt $text.Length) { $cursorPos++ } 
            }
            ([ConsoleKey]::Home) { 
                $cursorPos = 0 
            }
            ([ConsoleKey]::End) { 
                $cursorPos = $text.Length 
            }
            default {
                if ($Key.KeyChar -and -not [char]::IsControl($Key.KeyChar)) {
                    $text = $text.Insert($cursorPos, $Key.KeyChar)
                    $cursorPos++
                } else { 
                    return $false 
                }
            }
        }
        
        if ($text -ne $oldText -or $cursorPos -ne $self.CursorPosition) {
            if ($self.OnChange) {
                & $self.OnChange -NewText $text -NewCursorPosition $cursorPos
            }
        }
        return $true
    }
    return $component
}

function global:New-TuiDropdown {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "Dropdown"
    $component.IsFocusable = $true
    $component.Height = 3
    $component.IsOpen = $false
    $component.SelectedIndex = 0
    $component.Options = $Props.Options ?? @()
    $component.ValueProp = "Project"  # Default value property name
    
    $component.Render = {
        param($self)
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
        
        # Draw the dropdown box
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height 3 -BorderColor $borderColor
        
        # Display selected value or placeholder
        $displayText = "Select..."
        if ($self.Value -and $self.Options) {
            $selected = $self.Options | Where-Object { $_.Value -eq $self.Value } | Select-Object -First 1
            if ($selected) {
                $displayText = $selected.Display
            }
        }
        
        Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text $displayText
        
        # Draw dropdown indicator
        $indicator = if ($self.IsOpen) { "▲" } else { "▼" }
        Write-BufferString -X ($self.X + $self.Width - 3) -Y ($self.Y + 1) -Text $indicator
        
        # Draw dropdown list if open
        if ($self.IsOpen -and $self.Options.Count -gt 0) {
            $listHeight = [Math]::Min($self.Options.Count + 2, 8)
            Write-BufferBox -X $self.X -Y ($self.Y + 3) -Width $self.Width -Height $listHeight `
                -BorderColor $borderColor -BackgroundColor (Get-ThemeColor "Background")
            
            $displayCount = [Math]::Min($self.Options.Count, 6)
            for ($i = 0; $i -lt $displayCount; $i++) {
                $option = $self.Options[$i]
                $y = $self.Y + 4 + $i
                $fg = if ($i -eq $self.SelectedIndex) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
                $bg = if ($i -eq $self.SelectedIndex) { Get-ThemeColor "Secondary" } else { Get-ThemeColor "Background" }
                
                $text = $option.Display
                if ($text.Length -gt ($self.Width - 4)) {
                    $text = $text.Substring(0, $self.Width - 7) + "..."
                }
                
                Write-BufferString -X ($self.X + 2) -Y $y -Text $text `
                    -ForegroundColor $fg -BackgroundColor $bg
            }
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        if (-not $self.IsOpen) {
            if ($Key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar, [ConsoleKey]::DownArrow)) {
                $self.IsOpen = $true
                Request-TuiRefresh
                return $true
            }
        } else {
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($self.SelectedIndex -gt 0) {
                        $self.SelectedIndex--
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($self.SelectedIndex -lt ($self.Options.Count - 1)) {
                        $self.SelectedIndex++
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    if ($self.Options.Count -gt 0) {
                        $selected = $self.Options[$self.SelectedIndex]
                        if ($self.OnChange) {
                            & $self.OnChange -NewValue $selected.Value
                        }
                    }
                    $self.IsOpen = $false
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    $self.IsOpen = $false
                    Request-TuiRefresh
                    return $true
                }
            }
        }
        return $false
    }
    
    return $component
}

function global:New-TuiCheckBox {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "CheckBox"
    $component.IsFocusable = $true
    $component.Checked = $Props.Checked ?? $false
    
    $component.Render = {
        param($self)
        $fg = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
        $checkbox = if ($self.Checked) { "[X]" } else { "[ ]" }
        Write-BufferString -X $self.X -Y $self.Y -Text "$checkbox $($self.Text)" -ForegroundColor $fg
    }
    
    $component.HandleInput = {
        param($self, $Key)
        if ($Key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            $self.Checked = -not $self.Checked
            if ($self.OnChange) { & $self.OnChange -Checked $self.Checked }
            Request-TuiRefresh
            return $true
        }
        return $false
    }
    
    return $component
}

function global:New-TuiProgressBar {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "ProgressBar"
    $component.Value = $Props.Value ?? 0
    $component.Max = $Props.Max ?? 100
    
    $component.Render = {
        param($self)
        $percent = [Math]::Min(100, [Math]::Max(0, ($self.Value / $self.Max) * 100))
        $filled = [Math]::Floor(($self.Width - 2) * ($percent / 100))
        $empty = ($self.Width - 2) - $filled
        
        $bar = "█" * $filled + "░" * $empty
        Write-BufferString -X $self.X -Y $self.Y -Text "[$bar]" -ForegroundColor (Get-ThemeColor "Accent")
        
        if ($self.ShowPercent) {
            $percentText = "$([Math]::Round($percent))%"
            $textX = $self.X + [Math]::Floor(($self.Width - $percentText.Length) / 2)
            Write-BufferString -X $textX -Y $self.Y -Text $percentText -ForegroundColor (Get-ThemeColor "Primary")
        }
    }
    
    return $component
}

function global:New-TuiTextArea {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "TextArea"
    $component.IsFocusable = $true
    $component.Height = $Props.Height ?? 6
    $component.Text = $Props.Text ?? ""
    $component.Lines = @($component.Text -split "`n")
    $component.CursorX = 0
    $component.CursorY = 0
    $component.ScrollOffset = 0
    $component.WrapText = $Props.WrapText ?? $true
    
    $component.Render = {
        param($self)
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height -BorderColor $borderColor
        
        # Calculate visible area
        $innerWidth = $self.Width - 4
        $innerHeight = $self.Height - 2
        
        # Prepare lines for display
        $displayLines = @()
        if ($self.Lines.Count -eq 0) {
            $self.Lines = @("")
        }
        
        foreach ($line in $self.Lines) {
            if ($self.WrapText -and $line.Length -gt $innerWidth) {
                # Word wrap
                $wrapped = @()
                $currentLine = ""
                foreach ($word in $line -split ' ') {
                    if (($currentLine + " " + $word).Trim().Length -le $innerWidth) {
                        $currentLine = ($currentLine + " " + $word).Trim()
                    } else {
                        if ($currentLine) { $wrapped += $currentLine }
                        $currentLine = $word
                    }
                }
                if ($currentLine) { $wrapped += $currentLine }
                $displayLines += $wrapped
            } else {
                $displayLines += $line
            }
        }
        
        # Show placeholder if empty and not focused
        if ($displayLines.Count -eq 1 -and $displayLines[0] -eq "" -and -not $self.IsFocused) {
            Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text ($self.Placeholder ?? "Enter text...")
            return
        }
        
        # Display lines with scrolling
        $startLine = $self.ScrollOffset
        $endLine = [Math]::Min($displayLines.Count - 1, $startLine + $innerHeight - 1)
        
        for ($i = $startLine; $i -le $endLine; $i++) {
            $y = $self.Y + 1 + ($i - $startLine)
            $line = $displayLines[$i]
            if ($line.Length -gt $innerWidth) {
                $line = $line.Substring(0, $innerWidth - 3) + "..."
            }
            Write-BufferString -X ($self.X + 2) -Y $y -Text $line
        }
        
        # Draw cursor if focused
        if ($self.IsFocused -and $self.CursorY -ge $startLine -and $self.CursorY -le $endLine) {
            $cursorScreenY = $self.Y + 1 + ($self.CursorY - $startLine)
            $cursorX = [Math]::Min($self.CursorX, $displayLines[$self.CursorY].Length)
            Write-BufferString -X ($self.X + 2 + $cursorX) -Y $cursorScreenY -Text "_" `
                -BackgroundColor (Get-ThemeColor "Accent")
        }
        
        # Scrollbar if needed
        if ($displayLines.Count -gt $innerHeight) {
            $scrollbarHeight = $innerHeight
            $scrollPosition = [Math]::Floor(($self.ScrollOffset / ($displayLines.Count - $innerHeight)) * ($scrollbarHeight - 1))
            
            for ($i = 0; $i -lt $scrollbarHeight; $i++) {
                $char = if ($i -eq $scrollPosition) { "█" } else { "│" }
                $color = if ($i -eq $scrollPosition) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Subtle" }
                Write-BufferString -X ($self.X + $self.Width - 2) -Y ($self.Y + 1 + $i) -Text $char -ForegroundColor $color
            }
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        $lines = $self.Lines
        $cursorY = $self.CursorY
        $cursorX = $self.CursorX
        $innerHeight = $self.Height - 2
        
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($cursorY -gt 0) {
                    $cursorY--
                    $cursorX = [Math]::Min($cursorX, $lines[$cursorY].Length)
                    
                    # Adjust scroll if needed
                    if ($cursorY -lt $self.ScrollOffset) {
                        $self.ScrollOffset = $cursorY
                    }
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($cursorY -lt $lines.Count - 1) {
                    $cursorY++
                    $cursorX = [Math]::Min($cursorX, $lines[$cursorY].Length)
                    
                    # Adjust scroll if needed
                    if ($cursorY -ge $self.ScrollOffset + $innerHeight) {
                        $self.ScrollOffset = $cursorY - $innerHeight + 1
                    }
                }
            }
            ([ConsoleKey]::LeftArrow) {
                if ($cursorX -gt 0) {
                    $cursorX--
                } elseif ($cursorY -gt 0) {
                    $cursorY--
                    $cursorX = $lines[$cursorY].Length
                }
            }
            ([ConsoleKey]::RightArrow) {
                if ($cursorX -lt $lines[$cursorY].Length) {
                    $cursorX++
                } elseif ($cursorY -lt $lines.Count - 1) {
                    $cursorY++
                    $cursorX = 0
                }
            }
            ([ConsoleKey]::Home) {
                $cursorX = 0
            }
            ([ConsoleKey]::End) {
                $cursorX = $lines[$cursorY].Length
            }
            ([ConsoleKey]::Enter) {
                # Split the current line
                $currentLine = $lines[$cursorY]
                $beforeCursor = $currentLine.Substring(0, $cursorX)
                $afterCursor = $currentLine.Substring($cursorX)
                
                # Update lines
                $lines[$cursorY] = $beforeCursor
                $lines = @($lines[0..$cursorY]) + @($afterCursor) + @($lines[($cursorY + 1)..($lines.Count - 1)])
                
                # Move cursor to start of new line
                $cursorY++
                $cursorX = 0
                
                # Adjust scroll if needed
                if ($cursorY -ge $self.ScrollOffset + $innerHeight) {
                    $self.ScrollOffset = $cursorY - $innerHeight + 1
                }
            }
            ([ConsoleKey]::Backspace) {
                if ($cursorX -gt 0) {
                    $lines[$cursorY] = $lines[$cursorY].Remove($cursorX - 1, 1)
                    $cursorX--
                } elseif ($cursorY -gt 0) {
                    # Join with previous line
                    $prevLineLength = $lines[$cursorY - 1].Length
                    $lines[$cursorY - 1] += $lines[$cursorY]
                    
                    # Remove current line
                    if ($lines.Count -gt 1) {
                        $newLines = @()
                        for ($i = 0; $i -lt $lines.Count; $i++) {
                            if ($i -ne $cursorY) { $newLines += $lines[$i] }
                        }
                        $lines = $newLines
                    }
                    
                    $cursorY--
                    $cursorX = $prevLineLength
                }
            }
            ([ConsoleKey]::Delete) {
                if ($cursorX -lt $lines[$cursorY].Length) {
                    $lines[$cursorY] = $lines[$cursorY].Remove($cursorX, 1)
                } elseif ($cursorY -lt $lines.Count - 1) {
                    # Join with next line
                    $lines[$cursorY] += $lines[$cursorY + 1]
                    
                    # Remove next line
                    if ($lines.Count -gt 1) {
                        $newLines = @()
                        for ($i = 0; $i -lt $lines.Count; $i++) {
                            if ($i -ne ($cursorY + 1)) { $newLines += $lines[$i] }
                        }
                        $lines = $newLines
                    }
                }
            }
            default {
                if ($Key.KeyChar -and -not [char]::IsControl($Key.KeyChar)) {
                    $lines[$cursorY] = $lines[$cursorY].Insert($cursorX, $Key.KeyChar)
                    $cursorX++
                } else {
                    return $false
                }
            }
        }
        
        # Update component state
        $self.Lines = $lines
        $self.CursorX = $cursorX
        $self.CursorY = $cursorY
        $self.Text = $lines -join "`n"
        
        if ($self.OnChange) {
            & $self.OnChange -NewText $self.Text -Lines $self.Lines -CursorX $cursorX -CursorY $cursorY
        }
        
        Request-TuiRefresh
        return $true
    }
    
    return $component
}

#endregion

Export-ModuleMember -Function @(
    'New-TuiComponent', 'New-TuiForm', 'New-TuiLabel', 'New-TuiButton', 
    'New-TuiTextBox', 'New-TuiDropdown', 'New-TuiCheckBox', 'New-TuiProgressBar',
    'New-TuiTextArea'
)
