# Extended TUI Components Library
# Additional components for the TUI framework

#region DateTime Components

function global:New-TuiDatePicker {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "DatePicker"
    $component.IsFocusable = $true
    $component.Height = 3
    $component.Value = $Props.Value ?? (Get-Date)
    $component.Format = $Props.Format ?? "yyyy-MM-dd"
    
    $component.Render = {
        param($self)
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height 3 -BorderColor $borderColor
        
        $dateStr = $self.Value.ToString($self.Format)
        Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text $dateStr
        
        if ($self.IsFocused) {
            Write-BufferString -X ($self.X + $self.Width - 4) -Y ($self.Y + 1) -Text "📅" -ForegroundColor $borderColor
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        $date = $self.Value
        $handled = $true
        
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow) { 
                $date = $date.AddDays(1)
            }
            ([ConsoleKey]::DownArrow) { 
                $date = $date.AddDays(-1)
            }
            ([ConsoleKey]::PageUp) { 
                $date = $date.AddMonths(1)
            }
            ([ConsoleKey]::PageDown) { 
                $date = $date.AddMonths(-1)
            }
            ([ConsoleKey]::Home) { 
                $date = Get-Date
            }
            ([ConsoleKey]::T) {
                if ($Key.Modifiers -band [ConsoleModifiers]::Control) {
                    $date = Get-Date
                } else {
                    $handled = $false
                }
            }
            default { 
                $handled = $false 
            }
        }
        
        if ($handled -and $self.OnChange) {
            & $self.OnChange -NewValue $date
        }
        return $handled
    }
    
    return $component
}

function global:New-TuiTimePicker {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "TimePicker"
    $component.IsFocusable = $true
    $component.Height = 3
    $component.Hour = $Props.Hour ?? 0
    $component.Minute = $Props.Minute ?? 0
    $component.Format24H = $Props.Format24H ?? $true
    
    $component.Render = {
        param($self)
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height 3 -BorderColor $borderColor
        
        if ($self.Format24H) {
            $timeStr = "{0:D2}:{1:D2}" -f $self.Hour, $self.Minute
        } else {
            $displayHour = if ($self.Hour -eq 0) { 12 } elseif ($self.Hour -gt 12) { $self.Hour - 12 } else { $self.Hour }
            $ampm = if ($self.Hour -lt 12) { "AM" } else { "PM" }
            $timeStr = "{0:D2}:{1:D2} {2}" -f $displayHour, $self.Minute, $ampm
        }
        
        Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text $timeStr
        
        if ($self.IsFocused) {
            Write-BufferString -X ($self.X + $self.Width - 4) -Y ($self.Y + 1) -Text "⏰" -ForegroundColor $borderColor
        }
    }
    
    $component.HandleInput = {
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
            ([ConsoleKey]::LeftArrow) { 
                $hour = ($hour - 1 + 24) % 24
            }
            ([ConsoleKey]::RightArrow) { 
                $hour = ($hour + 1) % 24
            }
            default { 
                $handled = $false 
            }
        }
        
        if ($handled -and $self.OnChange) {
            & $self.OnChange -NewHour $hour -NewMinute $minute
        }
        return $handled
    }
    
    return $component
}

#endregion

#region Data Display Components

function global:New-TuiTable {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "Table"
    $component.IsFocusable = $true
    $component.Columns = $Props.Columns ?? @()
    $component.Rows = $Props.Rows ?? @()
    $component.SelectedRow = 0
    $component.ScrollOffset = 0
    $component.SortColumn = $null
    $component.SortAscending = $true
    
    $component.Render = {
        param($self)
        if ($self.Columns.Count -eq 0) { return }
        
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height -BorderColor $borderColor
        
        # Calculate column widths
        $totalWidth = $self.Width - 4
        $colWidth = [Math]::Floor($totalWidth / $self.Columns.Count)
        
        # Header
        $headerY = $self.Y + 1
        $currentX = $self.X + 2
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
        
        # Separator
        Write-BufferString -X ($self.X + 1) -Y ($headerY + 1) -Text ("─" * ($self.Width - 2)) -ForegroundColor $borderColor
        
        # Rows
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
            
            # Clear row background
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
        
        # Scrollbar if needed
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
    
    $component.HandleInput = {
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
                # Column sorting with number keys
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
                        
                        # Sort rows
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
    
    return $component
}

function global:New-TuiChart {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "Chart"
    $component.ChartType = $Props.ChartType ?? "Bar"
    $component.Data = $Props.Data ?? @()
    $component.ShowValues = $Props.ShowValues ?? $true
    $component.ShowLegend = $Props.ShowLegend ?? $false
    
    $component.Render = {
        param($self)
        if ($self.Data.Count -eq 0) { return }
        
        switch ($self.ChartType) {
            "Bar" {
                # Find max value for scaling
                $maxValue = ($self.Data | Measure-Object -Property Value -Maximum).Maximum
                if ($maxValue -eq 0) { $maxValue = 1 }
                
                $chartHeight = $self.Height - 2
                $barWidth = [Math]::Floor(($self.Width - 4) / $self.Data.Count)
                
                # Draw bars
                for ($i = 0; $i -lt $self.Data.Count; $i++) {
                    $item = $self.Data[$i]
                    $barHeight = [Math]::Floor(($item.Value / $maxValue) * $chartHeight)
                    $barX = $self.X + 2 + ($i * $barWidth)
                    
                    # Draw bar
                    for ($y = 0; $y -lt $barHeight; $y++) {
                        $barY = $self.Y + $self.Height - 2 - $y
                        Write-BufferString -X $barX -Y $barY -Text ("█" * ($barWidth - 1)) `
                            -ForegroundColor (Get-ThemeColor "Accent")
                    }
                    
                    # Label
                    if ($item.Label -and $barWidth -gt 3) {
                        $label = $item.Label
                        if ($label.Length -gt $barWidth - 1) {
                            $label = $label.Substring(0, $barWidth - 2)
                        }
                        Write-BufferString -X $barX -Y ($self.Y + $self.Height - 1) -Text $label `
                            -ForegroundColor (Get-ThemeColor "Subtle")
                    }
                    
                    # Value
                    if ($self.ShowValues -and $barHeight -gt 0) {
                        $valueText = $item.Value.ToString()
                        Write-BufferString -X $barX -Y ($self.Y + $self.Height - 3 - $barHeight) `
                            -Text $valueText -ForegroundColor (Get-ThemeColor "Primary")
                    }
                }
            }
            "Sparkline" {
                $width = $self.Width - 2
                $height = $self.Height - 1
                $maxValue = ($self.Data | Measure-Object -Maximum).Maximum
                if ($maxValue -eq 0) { $maxValue = 1 }
                
                $sparkChars = @(" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█")
                $sparkline = ""
                
                foreach ($value in $self.Data) {
                    $normalized = ($value / $maxValue)
                    $charIndex = [Math]::Floor($normalized * ($sparkChars.Count - 1))
                    $sparkline += $sparkChars[$charIndex]
                }
                
                # Trim or pad to fit width
                if ($sparkline.Length -gt $width) {
                    $sparkline = $sparkline.Substring($sparkline.Length - $width)
                } else {
                    $sparkline = $sparkline.PadLeft($width)
                }
                
                Write-BufferString -X ($self.X + 1) -Y ($self.Y + [Math]::Floor($height / 2)) `
                    -Text $sparkline -ForegroundColor (Get-ThemeColor "Accent")
            }
        }
    }
    
    return $component
}

#endregion

#region Notification Components

function global:New-TuiToast {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "Toast"
    $component.Message = $Props.Message ?? ""
    $component.ToastType = $Props.ToastType ?? "Info"
    $component.Duration = $Props.Duration ?? 3000
    $component.Position = $Props.Position ?? "TopRight"
    
    $component.Render = {
        param($self)
        if ([string]::IsNullOrEmpty($self.Message)) { return }
        
        $width = [Math]::Min($self.Message.Length + 6, 50)
        $height = 5
        
        # Calculate position
        switch ($self.Position) {
            "TopLeft" { 
                $x = 2
                $y = 1 
            }
            "TopRight" { 
                $x = $script:TuiState.BufferWidth - $width - 2
                $y = 1 
            }
            "BottomLeft" { 
                $x = 2
                $y = $script:TuiState.BufferHeight - $height - 2
            }
            "BottomRight" { 
                $x = $script:TuiState.BufferWidth - $width - 2
                $y = $script:TuiState.BufferHeight - $height - 2
            }
            "Center" {
                $x = [Math]::Floor(($script:TuiState.BufferWidth - $width) / 2)
                $y = [Math]::Floor(($script:TuiState.BufferHeight - $height) / 2)
            }
        }
        
        # Colors based on type
        $colors = switch ($self.ToastType) {
            "Success" { @{ Border = "Green"; Icon = "✓" } }
            "Error" { @{ Border = "Red"; Icon = "✗" } }
            "Warning" { @{ Border = "Yellow"; Icon = "⚠" } }
            "Info" { @{ Border = "Cyan"; Icon = "ℹ" } }
            default { @{ Border = "White"; Icon = "•" } }
        }
        
        # Draw shadow
        for ($sy = 1; $sy -lt $height; $sy++) {
            for ($sx = 1; $sx -lt $width; $sx++) {
                Write-BufferString -X ($x + $sx + 1) -Y ($y + $sy + 1) -Text " " `
                    -BackgroundColor [ConsoleColor]::Black
            }
        }
        
        # Draw toast
        Write-BufferBox -X $x -Y $y -Width $width -Height $height `
            -BorderStyle "Rounded" -BorderColor (Get-ThemeColor $colors.Border)
        
        # Icon and message
        $messageX = $x + 3
        Write-BufferString -X $messageX -Y ($y + 2) -Text "$($colors.Icon) $($self.Message)" `
            -ForegroundColor (Get-ThemeColor $colors.Border)
    }
    
    return $component
}

function global:New-TuiDialog {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "Dialog"
    $component.Title = $Props.Title ?? "Dialog"
    $component.Message = $Props.Message ?? ""
    $component.Buttons = $Props.Buttons ?? @("OK")
    $component.SelectedButton = 0
    $component.Width = $Props.Width ?? 50
    $component.Height = $Props.Height ?? 10
    
    $component.Render = {
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
        
        # Message
        $messageLines = $self.Message -split "`n"
        $messageY = $y + 2
        foreach ($line in $messageLines) {
            if ($line.Length -gt $self.Width - 4) {
                $line = $line.Substring(0, $self.Width - 7) + "..."
            }
            $messageX = $x + [Math]::Floor(($self.Width - $line.Length) / 2)
            Write-BufferString -X $messageX -Y $messageY -Text $line
            $messageY++
        }
        
        # Buttons
        $buttonY = $y + $self.Height - 3
        $totalButtonWidth = ($self.Buttons | ForEach-Object { $_.Length + 4 }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        $spacing = [Math]::Floor(($self.Width - $totalButtonWidth) / ($self.Buttons.Count + 1))
        $currentX = $x + $spacing
        
        for ($i = 0; $i -lt $self.Buttons.Count; $i++) {
            $button = $self.Buttons[$i]
            $buttonWidth = $button.Length + 4
            
            if ($i -eq $self.SelectedButton) {
                Write-BufferString -X $currentX -Y $buttonY -Text "[ $button ]" `
                    -ForegroundColor (Get-ThemeColor "Background") `
                    -BackgroundColor (Get-ThemeColor "Accent")
            } else {
                Write-BufferString -X $currentX -Y $buttonY -Text "[ $button ]" `
                    -ForegroundColor (Get-ThemeColor "Secondary")
            }
            
            $currentX += $buttonWidth + $spacing
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        switch ($Key.Key) {
            ([ConsoleKey]::LeftArrow) {
                if ($self.SelectedButton -gt 0) {
                    $self.SelectedButton--
                    Request-TuiRefresh
                }
                return $true
            }
            ([ConsoleKey]::RightArrow) {
                if ($self.SelectedButton -lt $self.Buttons.Count - 1) {
                    $self.SelectedButton++
                    Request-TuiRefresh
                }
                return $true
            }
            ([ConsoleKey]::Tab) {
                $self.SelectedButton = ($self.SelectedButton + 1) % $self.Buttons.Count
                Request-TuiRefresh
                return $true
            }
            ([ConsoleKey]::Enter) {
                if ($self.OnButtonClick) {
                    & $self.OnButtonClick -Button $self.Buttons[$self.SelectedButton] -Index $self.SelectedButton
                }
                return $true
            }
            ([ConsoleKey]::Escape) {
                if ($self.OnCancel) {
                    & $self.OnCancel
                }
                return $true
            }
        }
        return $false
    }
    
    return $component
}

#endregion

Export-ModuleMember -Function @(
    'New-TuiDatePicker', 'New-TuiTimePicker',
    'New-TuiTable', 'New-TuiChart',
    'New-TuiToast', 'New-TuiDialog'
)
