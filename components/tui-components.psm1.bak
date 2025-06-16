# TUI Component Library - COMPLIANT VERSION
# Stateful component factories following the canonical architecture

#region Basic Components

function global:New-TuiLabel {
    param([hashtable]$Props = @{})
    
    $component = @{
        # Metadata
        Type = "Label"
        IsFocusable = $false
        
        # Properties (from Props)
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 10
        Height = $Props.Height ?? 1
        Visible = $Props.Visible ?? $true
        Text = $Props.Text ?? ""
        ForegroundColor = $Props.ForegroundColor
        
        # Methods
        Render = {
            param($self)
            if (-not $self.Visible) { return }
            
            $fg = if ($self.ForegroundColor) { $self.ForegroundColor } else { Get-ThemeColor "Primary" }
            Write-BufferString -X $self.X -Y $self.Y -Text $self.Text -ForegroundColor $fg
        }
        
        HandleInput = {
            param($self, $Key)
            return $false
        }
    }
    
    return $component
}

function global:New-TuiButton {
    param([hashtable]$Props = @{})
    
    $component = @{
        # Metadata
        Type = "Button"
        IsFocusable = $true
        
        # Properties (from Props)
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 10
        Height = $Props.Height ?? 3
        Visible = $Props.Visible ?? $true
        Text = $Props.Text ?? "Button"
        
        # Internal State
        IsPressed = $false
        
        # Event Handlers (from Props)
        OnClick = $Props.OnClick
        
        # Methods
        Render = {
            param($self)
            if (-not $self.Visible) { return }
            
            $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
            $bgColor = if ($self.IsPressed) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Background" }
            $fgColor = if ($self.IsPressed) { Get-ThemeColor "Background" } else { $borderColor }
            
            Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height `
                -BorderColor $borderColor -BackgroundColor $bgColor
                
            $textX = $self.X + [Math]::Floor(($self.Width - $self.Text.Length) / 2)
            Write-BufferString -X $textX -Y ($self.Y + 1) -Text $self.Text `
                -ForegroundColor $fgColor -BackgroundColor $bgColor
        }
        
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
                if ($self.OnClick) {
                    & $self.OnClick
                }
                Request-TuiRefresh
                return $true
            }
            return $false
        }
    }
    
    return $component
}

function global:New-TuiTextBox {
    param([hashtable]$Props = @{})
    
    $component = @{
        # Metadata
        Type = "TextBox"
        IsFocusable = $true
        
        # Properties (from Props)
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 20
        Height = $Props.Height ?? 3
        Visible = $Props.Visible ?? $true
        Text = $Props.Text ?? ""
        Placeholder = $Props.Placeholder ?? ""
        MaxLength = $Props.MaxLength ?? 100
        
        # Internal State
        CursorPosition = $Props.CursorPosition ?? 0
        
        # Event Handlers (from Props)
        OnChange = $Props.OnChange
        
        # Methods
        Render = {
            param($self)
            if (-not $self.Visible) { return }
            
            $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
            Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height 3 -BorderColor $borderColor
            
            $displayText = if ($self.Text) { $self.Text } else { "" }
            if ([string]::IsNullOrEmpty($displayText) -and -not $self.IsFocused) { 
                $displayText = if ($self.Placeholder) { $self.Placeholder } else { "" }
            }
            
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
        
        HandleInput = {
            param($self, $Key)
            $text = if ($self.Text) { $self.Text } else { "" }
            $cursorPos = if ($null -ne $self.CursorPosition) { $self.CursorPosition } else { 0 }
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
                ([ConsoleKey]::Home) { $cursorPos = 0 }
                ([ConsoleKey]::End) { $cursorPos = $text.Length }
                ([ConsoleKey]::V) {
                    # Handle Ctrl+V (paste)
                    if ($Key.Modifiers -band [ConsoleModifiers]::Control) {
                        try {
                            # Get clipboard text (Windows only)
                            $clipboardText = if (Get-Command Get-Clipboard -ErrorAction SilentlyContinue) {
                                Get-Clipboard -Format Text -ErrorAction SilentlyContinue
                            } else {
                                $null
                            }
                            
                            if ($clipboardText) {
                                # Remove newlines for single-line textbox
                                $clipboardText = $clipboardText -replace '[\r\n]+', ' '
                                
                                # Insert as much as will fit
                                $remainingSpace = $self.MaxLength - $text.Length
                                if ($remainingSpace -gt 0) {
                                    $toInsert = if ($clipboardText.Length -gt $remainingSpace) {
                                        $clipboardText.Substring(0, $remainingSpace)
                                    } else {
                                        $clipboardText
                                    }
                                    
                                    $text = $text.Insert($cursorPos, $toInsert)
                                    $cursorPos += $toInsert.Length
                                }
                            }
                        } catch {
                            # Silently ignore clipboard errors
                        }
                    } else {
                        # Regular 'V' key
                        if (-not [char]::IsControl($Key.KeyChar) -and $text.Length -lt $self.MaxLength) {
                            $text = $text.Insert($cursorPos, $Key.KeyChar)
                            $cursorPos++
                        } else {
                            return $false
                        }
                    }
                }
                default {
                    if ($Key.KeyChar -and -not [char]::IsControl($Key.KeyChar) -and $text.Length -lt $self.MaxLength) {
                        $text = $text.Insert($cursorPos, $Key.KeyChar)
                        $cursorPos++
                    } else { 
                        return $false 
                    }
                }
            }
            
            if ($text -ne $oldText -or $cursorPos -ne $self.CursorPosition) {
                $self.Text = $text
                $self.CursorPosition = $cursorPos
                
                if ($self.OnChange) { 
                    & $self.OnChange -NewValue $text
                }
                Request-TuiRefresh
            }
            return $true
        }
    }
    
    return $component
}

function global:New-TuiCheckBox {
    param([hashtable]$Props = @{})
    
    $component = @{
        # Metadata
        Type = "CheckBox"
        IsFocusable = $true
        
        # Properties (from Props)
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 20
        Height = $Props.Height ?? 1
        Visible = $Props.Visible ?? $true
        Text = $Props.Text ?? "Checkbox"
        Checked = $Props.Checked ?? $false
        
        # Event Handlers (from Props)
        OnChange = $Props.OnChange
        
        # Methods
        Render = {
            param($self)
            if (-not $self.Visible) { return }
            
            $fg = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
            $checkbox = if ($self.Checked) { "[X]" } else { "[ ]" }
            Write-BufferString -X $self.X -Y $self.Y -Text "$checkbox $($self.Text)" -ForegroundColor $fg
        }
        
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
                $self.Checked = -not $self.Checked
                
                if ($self.OnChange) { 
                    & $self.OnChange -NewValue $self.Checked 
                }
                Request-TuiRefresh
                return $true
            }
            return $false
        }
    }
    
    return $component
}

function global:New-TuiDropdown {
    param([hashtable]$Props = @{})
    
    $component = @{
        # Metadata
        Type = "Dropdown"
        IsFocusable = $true
        
        # Properties (from Props)
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 20
        Height = $Props.Height ?? 3
        Visible = $Props.Visible ?? $true
        Options = $Props.Options ?? @()
        Value = $Props.Value
        Placeholder = $Props.Placeholder ?? "Select..."
        
        # Internal State
        IsOpen = $false
        SelectedIndex = 0
        
        # Event Handlers (from Props)
        OnChange = $Props.OnChange
        
        # Methods
        Render = {
            param($self)
            if (-not $self.Visible) { return }
            
            $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
            Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height 3 -BorderColor $borderColor
            
            $displayText = $self.Placeholder
            if ($self.Value -and $self.Options) {
                $selected = $self.Options | Where-Object { $_.Value -eq $self.Value } | Select-Object -First 1
                if ($selected) { $displayText = $selected.Display }
            }
            
            Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text $displayText
            $indicator = if ($self.IsOpen) { "▲" } else { "▼" }
            Write-BufferString -X ($self.X + $self.Width - 3) -Y ($self.Y + 1) -Text $indicator
            
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
                    Write-BufferString -X ($self.X + 2) -Y $y -Text $text -ForegroundColor $fg -BackgroundColor $bg
                }
            }
        }
        
        HandleInput = {
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
                            $self.Value = $selected.Value
                            
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
    }
    
    return $component
}

function global:New-TuiProgressBar {
    param([hashtable]$Props = @{})
    
    $component = @{
        # Metadata
        Type = "ProgressBar"
        IsFocusable = $false
        
        # Properties (from Props)
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 20
        Height = $Props.Height ?? 1
        Visible = $Props.Visible ?? $true
        Value = $Props.Value ?? 0
        Max = $Props.Max ?? 100
        ShowPercent = $Props.ShowPercent ?? $false
        
        # Methods
        Render = {
            param($self)
            if (-not $self.Visible) { return }
            
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
        
        HandleInput = {
            param($self, $Key)
            return $false
        }
    }
    
    return $component
}

function global:New-TuiTextArea {
    param([hashtable]$Props = @{})
    
    $component = @{
        # Metadata
        Type = "TextArea"
        IsFocusable = $true
        
        # Properties (from Props)
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 40
        Height = $Props.Height ?? 6
        Visible = $Props.Visible ?? $true
        Text = $Props.Text ?? ""
        Placeholder = $Props.Placeholder ?? "Enter text..."
        WrapText = $Props.WrapText ?? $true
        
        # Internal State
        Lines = @($Props.Text -split "`n")
        CursorX = 0
        CursorY = 0
        ScrollOffset = 0
        
        # Event Handlers (from Props)
        OnChange = $Props.OnChange
        
        # Methods
        Render = {
            param($self)
            if (-not $self.Visible) { return }
            
            $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
            Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height -BorderColor $borderColor
            
            $innerWidth = $self.Width - 4
            $innerHeight = $self.Height - 2
            $displayLines = @()
            if ($self.Lines.Count -eq 0) { $self.Lines = @("") }
            
            foreach ($line in $self.Lines) {
                if ($self.WrapText -and $line.Length -gt $innerWidth) {
                    for ($i = 0; $i -lt $line.Length; $i += $innerWidth) {
                        $displayLines += $line.Substring($i, [Math]::Min($innerWidth, $line.Length - $i))
                    }
                } else { 
                    $displayLines += $line 
                }
            }
            
            if ($displayLines.Count -eq 1 -and $displayLines[0] -eq "" -and -not $self.IsFocused) {
                Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text $self.Placeholder
                return
            }
            
            $startLine = $self.ScrollOffset
            $endLine = [Math]::Min($displayLines.Count - 1, $startLine + $innerHeight - 1)
            
            for ($i = $startLine; $i -le $endLine; $i++) {
                $y = $self.Y + 1 + ($i - $startLine)
                $line = $displayLines[$i]
                Write-BufferString -X ($self.X + 2) -Y $y -Text $line
            }
            
            if ($self.IsFocused -and $self.CursorY -ge $startLine -and $self.CursorY -le $endLine) {
                $cursorScreenY = $self.Y + 1 + ($self.CursorY - $startLine)
                $cursorX = [Math]::Min($self.CursorX, $displayLines[$self.CursorY].Length)
                Write-BufferString -X ($self.X + 2 + $cursorX) -Y $cursorScreenY -Text "_" `
                    -BackgroundColor (Get-ThemeColor "Accent")
            }
            
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
        
        HandleInput = {
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
                        if ($cursorY -lt $self.ScrollOffset) { 
                            $self.ScrollOffset = $cursorY 
                        }
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($cursorY -lt $lines.Count - 1) {
                        $cursorY++
                        $cursorX = [Math]::Min($cursorX, $lines[$cursorY].Length)
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
                ([ConsoleKey]::Home) { $cursorX = 0 }
                ([ConsoleKey]::End) { $cursorX = $lines[$cursorY].Length }
                ([ConsoleKey]::Enter) {
                    $currentLine = $lines[$cursorY]
                    $beforeCursor = $currentLine.Substring(0, $cursorX)
                    $afterCursor = $currentLine.Substring($cursorX)
                    $lines[$cursorY] = $beforeCursor
                    $lines = @($lines[0..$cursorY]) + @($afterCursor) + @($lines[($cursorY + 1)..($lines.Count - 1)])
                    $cursorY++
                    $cursorX = 0
                    if ($cursorY -ge $self.ScrollOffset + $innerHeight) { 
                        $self.ScrollOffset = $cursorY - $innerHeight + 1 
                    }
                }
                ([ConsoleKey]::Backspace) {
                    if ($cursorX -gt 0) { 
                        $lines[$cursorY] = $lines[$cursorY].Remove($cursorX - 1, 1)
                        $cursorX-- 
                    } elseif ($cursorY -gt 0) {
                        $prevLineLength = $lines[$cursorY - 1].Length
                        $lines[$cursorY - 1] += $lines[$cursorY]
                        $newLines = @()
                        for ($i = 0; $i -lt $lines.Count; $i++) { 
                            if ($i -ne $cursorY) { $newLines += $lines[$i] } 
                        }
                        $lines = $newLines
                        $cursorY--
                        $cursorX = $prevLineLength
                    }
                }
                ([ConsoleKey]::Delete) {
                    if ($cursorX -lt $lines[$cursorY].Length) { 
                        $lines[$cursorY] = $lines[$cursorY].Remove($cursorX, 1) 
                    } elseif ($cursorY -lt $lines.Count - 1) {
                        $lines[$cursorY] += $lines[$cursorY + 1]
                        $newLines = @()
                        for ($i = 0; $i -lt $lines.Count; $i++) { 
                            if ($i -ne ($cursorY + 1)) { $newLines += $lines[$i] } 
                        }
                        $lines = $newLines
                    }
                }
                ([ConsoleKey]::V) {
                    # Handle Ctrl+V (paste)
                    if ($Key.Modifiers -band [ConsoleModifiers]::Control) {
                        try {
                            # Get clipboard text (Windows only)
                            $clipboardText = if (Get-Command Get-Clipboard -ErrorAction SilentlyContinue) {
                                Get-Clipboard -Format Text -ErrorAction SilentlyContinue
                            } else {
                                $null
                            }
                            
                            if ($clipboardText) {
                                # Split clipboard text into lines
                                $clipboardLines = $clipboardText -split '[\r\n]+'
                                
                                if ($clipboardLines.Count -eq 1) {
                                    # Single line paste - insert at cursor
                                    $lines[$cursorY] = $lines[$cursorY].Insert($cursorX, $clipboardLines[0])
                                    $cursorX += $clipboardLines[0].Length
                                } else {
                                    # Multi-line paste
                                    $currentLine = $lines[$cursorY]
                                    $beforeCursor = $currentLine.Substring(0, $cursorX)
                                    $afterCursor = $currentLine.Substring($cursorX)
                                    
                                    # First line
                                    $lines[$cursorY] = $beforeCursor + $clipboardLines[0]
                                    
                                    # Insert middle lines
                                    $insertLines = @()
                                    for ($i = 1; $i -lt $clipboardLines.Count - 1; $i++) {
                                        $insertLines += $clipboardLines[$i]
                                    }
                                    
                                    # Last line
                                    $lastLine = $clipboardLines[-1] + $afterCursor
                                    $insertLines += $lastLine
                                    
                                    # Insert all new lines
                                    $newLines = @()
                                    for ($i = 0; $i -le $cursorY; $i++) {
                                        $newLines += $lines[$i]
                                    }
                                    $newLines += $insertLines
                                    for ($i = $cursorY + 1; $i -lt $lines.Count; $i++) {
                                        $newLines += $lines[$i]
                                    }
                                    
                                    $lines = $newLines
                                    $cursorY += $clipboardLines.Count - 1
                                    $cursorX = $clipboardLines[-1].Length
                                }
                                
                                # Adjust scroll if needed
                                $innerHeight = $self.Height - 2
                                if ($cursorY -ge $self.ScrollOffset + $innerHeight) { 
                                    $self.ScrollOffset = $cursorY - $innerHeight + 1 
                                }
                            }
                        } catch {
                            # Silently ignore clipboard errors
                        }
                    } else {
                        # Regular 'V' key
                        if (-not [char]::IsControl($Key.KeyChar)) {
                            $lines[$cursorY] = $lines[$cursorY].Insert($cursorX, $Key.KeyChar)
                            $cursorX++
                        } else {
                            return $false
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
            
            $self.Lines = $lines
            $self.CursorX = $cursorX
            $self.CursorY = $cursorY
            $self.Text = $lines -join "`n"
            
            if ($self.OnChange) { 
                & $self.OnChange -NewValue $self.Text 
            }
            Request-TuiRefresh
            return $true
        }
    }
    
    return $component
}

#endregion

#region DateTime Components

function global:New-TuiDatePicker {
    param([hashtable]$Props = @{})
    
    $component = @{
        # Metadata
        Type = "DatePicker"
        IsFocusable = $true
        
        # Properties (from Props)
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 20
        Height = $Props.Height ?? 3
        Visible = $Props.Visible ?? $true
        Value = $Props.Value ?? (Get-Date)
        Format = $Props.Format ?? "yyyy-MM-dd"
        
        # Event Handlers (from Props)
        OnChange = $Props.OnChange
        
        # Methods
        Render = {
            param($self)
            if (-not $self.Visible) { return }
            
            $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
            Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height 3 -BorderColor $borderColor
            $dateStr = $self.Value.ToString($self.Format)
            
            # Truncate date string if too long
            $maxLength = $self.Width - 6
            if ($dateStr.Length -gt $maxLength) {
                $dateStr = $dateStr.Substring(0, $maxLength)
            }
            
            Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text $dateStr
            if ($self.IsFocused -and $self.Width -ge 6) { 
                Write-BufferString -X ($self.X + $self.Width - 4) -Y ($self.Y + 1) -Text "📅" -ForegroundColor $borderColor 
            }
        }
        
        HandleInput = {
            param($self, $Key)
            $date = $self.Value
            $handled = $true
            
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow)   { $date = $date.AddDays(1) }
                ([ConsoleKey]::DownArrow) { $date = $date.AddDays(-1) }
                ([ConsoleKey]::PageUp)    { $date = $date.AddMonths(1) }
                ([ConsoleKey]::PageDown)  { $date = $date.AddMonths(-1) }
                ([ConsoleKey]::Home)      { $date = Get-Date }
                ([ConsoleKey]::T) { 
                    if ($Key.Modifiers -band [ConsoleModifiers]::Control) { 
                        $date = Get-Date 
                    } else { 
                        $handled = $false 
                    } 
                }
                default { $handled = $false }
            }
            
            if ($handled) {
                $self.Value = $date
                if ($self.OnChange) { 
                    & $self.OnChange -NewValue $date 
                }
                Request-TuiRefresh
            }
            return $handled
        }
    }
    
    return $component
}

function global:New-TuiTimePicker {
    param([hashtable]$Props = @{})
    
    $component = @{
        # Metadata
        Type = "TimePicker"
        IsFocusable = $true
        
        # Properties (from Props)
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 15
        Height = $Props.Height ?? 3
        Visible = $Props.Visible ?? $true
        Hour = $Props.Hour ?? 0
        Minute = $Props.Minute ?? 0
        Format24H = $Props.Format24H ?? $true
        
        # Event Handlers (from Props)
        OnChange = $Props.OnChange
        
        # Methods
        Render = {
            param($self)
            if (-not $self.Visible) { return }
            
            $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
            Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height 3 -BorderColor $borderColor
            
            if ($self.Format24H) { 
                $timeStr = "{0:D2}:{1:D2}" -f $self.Hour, $self.Minute 
            } else {
                $displayHour = if ($self.Hour -eq 0) { 12 } elseif ($self.Hour -gt 12) { $self.Hour - 12 } else { $self.Hour }
                $ampm = if ($self.Hour -lt 12) { "AM" } else { "PM" }
                $timeStr = "{0:D2}:{1:D2} {2}" -f $displayHour, $self.Minute, $ampm
            }
            
            # Truncate time string if too long
            $maxLength = $self.Width - 6
            if ($timeStr.Length -gt $maxLength) {
                $timeStr = $timeStr.Substring(0, $maxLength)
            }
            
            Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text $timeStr
            if ($self.IsFocused -and $self.Width -ge 6) { 
                Write-BufferString -X ($self.X + $self.Width - 4) -Y ($self.Y + 1) -Text "⏰" -ForegroundColor $borderColor 
            }
        }
        
        HandleInput = {
            param($self, $Key)
            $handled = $true
            $hour = $self.Hour
            $minute = $self.Minute
            
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) { 
                    $minute = ($minute + 15) % 60
                    if ($minute -eq 0) { $hour = ($hour + 1) % 24 } 
                }
                ([ConsoleKey]::DownArrow) { 
                    $minute = ($minute - 15 + 60) % 60
                    if ($minute -eq 45) { $hour = ($hour - 1 + 24) % 24 } 
                }
                ([ConsoleKey]::LeftArrow)  { $hour = ($hour - 1 + 24) % 24 }
                ([ConsoleKey]::RightArrow) { $hour = ($hour + 1) % 24 }
                default { $handled = $false }
            }
            
            if ($handled) {
                $self.Hour = $hour
                $self.Minute = $minute
                
                if ($self.OnChange) { 
                    & $self.OnChange -NewHour $hour -NewMinute $minute 
                }
                Request-TuiRefresh
            }
            return $handled
        }
    }
    
    return $component
}

#endregion

#region Data Display Components

function global:New-TuiTable {
    param([hashtable]$Props = @{})
    
    $component = @{
        # Metadata
        Type = "Table"
        IsFocusable = $true
        
        # Properties (from Props)
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 60
        Height = $Props.Height ?? 15
        Visible = $Props.Visible ?? $true
        Columns = $Props.Columns ?? @()
        Rows = $Props.Rows ?? @()
        
        # Internal State
        SelectedRow = 0
        ScrollOffset = 0
        SortColumn = $null
        SortAscending = $true
        
        # Event Handlers (from Props)
        OnRowSelect = $Props.OnRowSelect
        
        # Methods
        Render = {
            param($self)
            if (-not $self.Visible -or $self.Columns.Count -eq 0) { return }
            
            $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
            Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height -BorderColor $borderColor
            
            $totalWidth = $self.Width - 4
            $colWidth = [Math]::Floor($totalWidth / $self.Columns.Count)
            $headerY = $self.Y + 1
            $currentX = $self.X + 2
            
            # Draw headers
            foreach ($col in $self.Columns) {
                $header = $col.Header
                if ($col.Name -eq $self.SortColumn) { 
                    $arrow = if ($self.SortAscending) { "▲" } else { "▼" }
                    $header = "$header $arrow" 
                }
                if ($header.Length -gt $colWidth - 1) { 
                    $header = $header.Substring(0, $colWidth - 4) + "..." 
                }
                Write-BufferString -X $currentX -Y $headerY -Text $header -ForegroundColor (Get-ThemeColor "Header")
                $currentX += $colWidth
            }
            
            # Header separator
            Write-BufferString -X ($self.X + 1) -Y ($headerY + 1) -Text ("─" * ($self.Width - 2)) -ForegroundColor $borderColor
            
            # Draw rows
            $visibleRows = $self.Height - 5
            $startIdx = $self.ScrollOffset
            $endIdx = [Math]::Min($self.Rows.Count - 1, $startIdx + $visibleRows - 1)
            
            for ($i = $startIdx; $i -le $endIdx; $i++) {
                $row = $self.Rows[$i]
                $rowY = ($headerY + 2) + ($i - $startIdx)
                $currentX = $self.X + 2
                $isSelected = ($i -eq $self.SelectedRow -and $self.IsFocused)
                $bgColor = if ($isSelected) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Background" }
                $fgColor = if ($isSelected) { Get-ThemeColor "Background" } else { Get-ThemeColor "Primary" }
                
                if ($isSelected) { 
                    Write-BufferString -X ($self.X + 1) -Y $rowY -Text (" " * ($self.Width - 2)) -BackgroundColor $bgColor 
                }
                
                foreach ($col in $self.Columns) {
                    $value = $row.($col.Name)
                    if ($null -eq $value) { $value = "" }
                    $text = $value.ToString()
                    if ($text.Length -gt $colWidth - 1) { 
                        $text = $text.Substring(0, $colWidth - 4) + "..." 
                    }
                    Write-BufferString -X $currentX -Y $rowY -Text $text -ForegroundColor $fgColor -BackgroundColor $bgColor
                    $currentX += $colWidth
                }
            }
            
            # Scrollbar
            if ($self.Rows.Count -gt $visibleRows) {
                $scrollbarHeight = $visibleRows
                $scrollPosition = [Math]::Floor(($self.ScrollOffset / ($self.Rows.Count - $visibleRows)) * ($scrollbarHeight - 1))
                for ($i = 0; $i -lt $scrollbarHeight; $i++) {
                    $char = if ($i -eq $scrollPosition) { "█" } else { "│" }
                    $color = if ($i -eq $scrollPosition) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Subtle" }
                    Write-BufferString -X ($self.X + $self.Width - 2) -Y ($headerY + 2 + $i) -Text $char -ForegroundColor $color
                }
            }
        }
        
        HandleInput = {
            param($self, $Key)
            if ($self.Rows.Count -eq 0) { return $false }
            
            $visibleRows = $self.Height - 5
            $handled = $true
            
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) { 
                    if ($self.SelectedRow -gt 0) { 
                        $self.SelectedRow--
                        if ($self.SelectedRow -lt $self.ScrollOffset) { 
                            $self.ScrollOffset = $self.SelectedRow 
                        }
                        Request-TuiRefresh 
                    } 
                }
                ([ConsoleKey]::DownArrow) { 
                    if ($self.SelectedRow -lt $self.Rows.Count - 1) { 
                        $self.SelectedRow++
                        if ($self.SelectedRow -ge $self.ScrollOffset + $visibleRows) { 
                            $self.ScrollOffset = $self.SelectedRow - $visibleRows + 1 
                        }
                        Request-TuiRefresh 
                    } 
                }
                ([ConsoleKey]::PageUp) { 
                    $self.SelectedRow = [Math]::Max(0, $self.SelectedRow - $visibleRows)
                    $self.ScrollOffset = [Math]::Max(0, $self.ScrollOffset - $visibleRows)
                    Request-TuiRefresh 
                }
                ([ConsoleKey]::PageDown) { 
                    $self.SelectedRow = [Math]::Min($self.Rows.Count - 1, $self.SelectedRow + $visibleRows)
                    $maxScroll = [Math]::Max(0, $self.Rows.Count - $visibleRows)
                    $self.ScrollOffset = [Math]::Min($maxScroll, $self.ScrollOffset + $visibleRows)
                    Request-TuiRefresh 
                }
                ([ConsoleKey]::Home) { 
                    $self.SelectedRow = 0
                    $self.ScrollOffset = 0
                    Request-TuiRefresh 
                }
                ([ConsoleKey]::End) { 
                    $self.SelectedRow = $self.Rows.Count - 1
                    $self.ScrollOffset = [Math]::Max(0, $self.Rows.Count - $visibleRows)
                    Request-TuiRefresh 
                }
                ([ConsoleKey]::Enter) { 
                    if ($self.OnRowSelect) { 
                        & $self.OnRowSelect -Row $self.Rows[$self.SelectedRow] -Index $self.SelectedRow 
                    } 
                }
                default {
                    if ($Key.KeyChar -match '\d') {
                        $colIndex = [int]$Key.KeyChar.ToString() - 1
                        if ($colIndex -ge 0 -and $colIndex -lt $self.Columns.Count) {
                            $colName = $self.Columns[$colIndex].Name
                            if ($self.SortColumn -eq $colName) { 
                                $self.SortAscending = -not $self.SortAscending 
                            } else { 
                                $self.SortColumn = $colName
                                $self.SortAscending = $true 
                            }
                            $self.Rows = $self.Rows | Sort-Object -Property $colName -Descending:(-not $self.SortAscending)
                            Request-TuiRefresh
                        }
                    } else { 
                        $handled = $false 
                    }
                }
            }
            return $handled
        }
    }
    
    return $component
}

function global:New-TuiChart {
    param([hashtable]$Props = @{})
    
    $component = @{
        # Metadata
        Type = "Chart"
        IsFocusable = $false
        
        # Properties (from Props)
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 40
        Height = $Props.Height ?? 10
        Visible = $Props.Visible ?? $true
        ChartType = $Props.ChartType ?? "Bar"
        Data = $Props.Data ?? @()
        ShowValues = $Props.ShowValues ?? $true
        
        # Methods
        Render = {
            param($self)
            if (-not $self.Visible -or $self.Data.Count -eq 0) { return }
            
            switch ($self.ChartType) {
                "Bar" {
                    $maxValue = ($self.Data | Measure-Object -Property Value -Maximum).Maximum
                    if ($maxValue -eq 0) { $maxValue = 1 }
                    $chartHeight = $self.Height - 2
                    $barWidth = [Math]::Floor(($self.Width - 4) / $self.Data.Count)
                    
                    for ($i = 0; $i -lt $self.Data.Count; $i++) {
                        $item = $self.Data[$i]
                        $barHeight = [Math]::Floor(($item.Value / $maxValue) * $chartHeight)
                        $barX = $self.X + 2 + ($i * $barWidth)
                        
                        for ($y = 0; $y -lt $barHeight; $y++) { 
                            $barY = $self.Y + $self.Height - 2 - $y
                            Write-BufferString -X $barX -Y $barY -Text ("█" * ($barWidth - 1)) -ForegroundColor (Get-ThemeColor "Accent") 
                        }
                        
                        if ($item.Label -and $barWidth -gt 3) { 
                            $label = $item.Label
                            if ($label.Length -gt $barWidth - 1) { 
                                $label = $label.Substring(0, $barWidth - 2) 
                            }
                            Write-BufferString -X $barX -Y ($self.Y + $self.Height - 1) -Text $label -ForegroundColor (Get-ThemeColor "Subtle") 
                        }
                        
                        if ($self.ShowValues -and $barHeight -gt 0) { 
                            $valueText = $item.Value.ToString()
                            Write-BufferString -X $barX -Y ($self.Y + $self.Height - 3 - $barHeight) -Text $valueText -ForegroundColor (Get-ThemeColor "Primary") 
                        }
                    }
                }
                "Sparkline" {
                    $width = $self.Width - 2
                    $height = $self.Height - 1
                    $maxValue = ($self.Data | Measure-Object -Maximum).Maximum
                    if ($maxValue -eq 0) { $maxValue = 1 }
                    
                    $sparkChars = @(" ", " ", "▂", "▃", "▄", "▅", "▆", "▇", "█")
                    $sparkline = ""
                    
                    foreach ($value in $self.Data) { 
                        $normalized = ($value / $maxValue)
                        $charIndex = [Math]::Floor($normalized * ($sparkChars.Count - 1))
                        $sparkline += $sparkChars[$charIndex] 
                    }
                    
                    if ($sparkline.Length -gt $width) { 
                        $sparkline = $sparkline.Substring($sparkline.Length - $width) 
                    } else { 
                        $sparkline = $sparkline.PadLeft($width) 
                    }
                    
                    Write-BufferString -X ($self.X + 1) -Y ($self.Y + [Math]::Floor($height / 2)) -Text $sparkline -ForegroundColor (Get-ThemeColor "Accent")
                }
            }
        }
        
        HandleInput = {
            param($self, $Key)
            return $false
        }
    }
    
    return $component
}

#endregion

#region Container Components

function global:New-TuiPanel {
    <#
    .SYNOPSIS
    Creates a container component that manages child layout automatically
    
    .PARAMETER Props
    Hashtable of properties including:
    - Layout: 'Stack' (default) or 'Grid'
    - Orientation: 'Vertical' (default) or 'Horizontal' (for Stack layout)
    - Spacing: Space between children (default 1)
    - Padding: Internal padding (default 1)
    - ShowBorder: Whether to draw a border (default false)
    #>
    param([hashtable]$Props = @{})
    
    $component = @{
        Type = "Panel"
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 40
        Height = $Props.Height ?? 20
        Visible = $Props.Visible ?? $true
        IsFocusable = $Props.IsFocusable ?? $false
        Children = @()
        
        # Layout properties
        Layout = $Props.Layout ?? 'Stack'
        Orientation = $Props.Orientation ?? 'Vertical'
        Spacing = $Props.Spacing ?? 1
        Padding = $Props.Padding ?? 1
        ShowBorder = $Props.ShowBorder ?? $false
        Title = $Props.Title
        
        # Methods
        AddChild = {
            param($self, $Child)
            $self.Children += $Child
            # Immediately recalculate layout
            & $self._RecalculateLayout -self $self
        }
        
        RemoveChild = {
            param($self, $Child)
            $self.Children = @($self.Children | Where-Object { $_ -ne $Child })
            & $self._RecalculateLayout -self $self
        }
        
        _RecalculateLayout = {
            param($self)
            
            # Calculate content area
            $contentX = $self.X + $self.Padding
            $contentY = $self.Y + $self.Padding
            $contentWidth = $self.Width - ($self.Padding * 2)
            $contentHeight = $self.Height - ($self.Padding * 2)
            
            if ($self.ShowBorder) {
                $contentX++
                $contentY++
                $contentWidth -= 2
                $contentHeight -= 2
            }
            
            # Apply layout
            switch ($self.Layout) {
                'Stack' {
                    $currentX = $contentX
                    $currentY = $contentY
                    
                    foreach ($child in $self.Children) {
                        if (-not $child.Visible) { continue }
                        
                        $child.X = $currentX
                        $child.Y = $currentY
                        
                        # Constrain child size to panel
                        if ($self.Orientation -eq 'Vertical') {
                            $child.Width = [Math]::Min($child.Width, $contentWidth)
                            $currentY += $child.Height + $self.Spacing
                        } else {
                            $child.Height = [Math]::Min($child.Height, $contentHeight)
                            $currentX += $child.Width + $self.Spacing
                        }
                    }
                }
                
                'Grid' {
                    # Simple grid - auto columns based on width
                    if ($self.Children.Count -eq 0) { return }
                    
                    # Estimate columns based on average child width
                    $avgWidth = 20
                    if ($self.Children[0].Width) {
                        $avgWidth = $self.Children[0].Width
                    }
                    
                    $cols = [Math]::Max(1, [Math]::Floor($contentWidth / ($avgWidth + $self.Spacing)))
                    $cellWidth = [Math]::Floor(($contentWidth - ($cols - 1) * $self.Spacing) / $cols)
                    
                    $row = 0
                    $col = 0
                    
                    foreach ($child in $self.Children) {
                        if (-not $child.Visible) { continue }
                        
                        $child.X = $contentX + ($col * ($cellWidth + $self.Spacing))
                        $child.Y = $contentY + ($row * ($child.Height + $self.Spacing))
                        $child.Width = [Math]::Min($child.Width, $cellWidth)
                        
                        $col++
                        if ($col -ge $cols) {
                            $col = 0
                            $row++
                        }
                    }
                }
            }
        }
        
        Render = {
            param($self)
            if (-not $self.Visible) { return }
            
            # Draw border if requested
            if ($self.ShowBorder) {
                $borderColor = if ($self.IsFocused) {
                    Get-ThemeColor "Accent" -Default ([ConsoleColor]::Cyan)
                } else {
                    Get-ThemeColor "Border" -Default ([ConsoleColor]::DarkGray)
                }
                
                Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height `
                    -BorderColor $borderColor -Title $self.Title
            }
            
            # Render children
            foreach ($child in $self.Children) {
                if ($child.Visible -and $child.Render) {
                    & $child.Render -self $child
                }
            }
        }
        
        HandleInput = {
            param($self, $Key)
            # Panels don't handle input directly, but could implement focus management
            return $false
        }
    }
    
    # Initial layout calculation
    & $component._RecalculateLayout -self $component
    
    return $component
}

#endregion

Export-ModuleMember -Function @(
    # Basic Components
    'New-TuiLabel',
    'New-TuiButton',
    'New-TuiTextBox',
    'New-TuiCheckBox',
    'New-TuiDropdown',
    'New-TuiProgressBar',
    'New-TuiTextArea',
    # DateTime Components
    'New-TuiDatePicker',
    'New-TuiTimePicker',
    # Data Display Components
    'New-TuiTable',
    'New-TuiChart',
    # Container Components
    'New-TuiPanel'
)