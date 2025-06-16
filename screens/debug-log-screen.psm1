# Debug Log Screen
# Shows application log entries for debugging

function global:Get-DebugLogScreen {
    $screen = @{
        Name = "DebugLogScreen"
        
        State = @{
            logEntries = @()
            scrollOffset = 0
            selectedLine = 0
            filterLevel = "All"
            autoScroll = $true
            lastLogCount = 0
        }
        
        Components = @{}
        
        Init = {
            param($self)
            
            # Get initial log entries
            if (Get-Command Get-LogEntries -ErrorAction SilentlyContinue) {
                $self.State.logEntries = @(Get-LogEntries -Count 500)
                $self.State.lastLogCount = $self.State.logEntries.Count
            }
            
            # Auto-scroll to bottom
            if ($self.State.autoScroll -and $self.State.logEntries.Count -gt 0) {
                $visibleLines = $global:TuiState.BufferHeight - 8
                $self.State.scrollOffset = [Math]::Max(0, $self.State.logEntries.Count - $visibleLines)
                $self.State.selectedLine = $self.State.logEntries.Count - 1
            }
        }
        
        Render = {
            param($self)
            
            # Update log entries if new ones available
            if (Get-Command Get-LogEntries -ErrorAction SilentlyContinue) {
                $currentEntries = @(Get-LogEntries -Count 500)
                if ($currentEntries.Count -ne $self.State.lastLogCount) {
                    $self.State.logEntries = $currentEntries
                    $self.State.lastLogCount = $currentEntries.Count
                    
                    # Auto-scroll to bottom for new entries
                    if ($self.State.autoScroll) {
                        $visibleLines = $global:TuiState.BufferHeight - 8
                        $self.State.scrollOffset = [Math]::Max(0, $self.State.logEntries.Count - $visibleLines)
                        $self.State.selectedLine = $self.State.logEntries.Count - 1
                    }
                }
            }
            
            # Header
            $headerColor = Get-ThemeColor "Header"
            Write-BufferString -X 2 -Y 1 -Text "Debug Log Viewer" -ForegroundColor $headerColor
            Write-BufferString -X 30 -Y 1 -Text "Filter: $($self.State.filterLevel)" -ForegroundColor (Get-ThemeColor "Info")
            Write-BufferString -X 50 -Y 1 -Text "Auto-scroll: $($self.State.autoScroll)" -ForegroundColor (Get-ThemeColor "Success")
            
            # Main log area
            $logY = 3
            $logHeight = $global:TuiState.BufferHeight - 6
            Write-BufferBox -X 1 -Y 2 -Width ($global:TuiState.BufferWidth - 2) -Height ($logHeight + 2) `
                -Title " Log Entries ($($self.State.logEntries.Count)) " -BorderColor (Get-ThemeColor "Border")
            
            # Filter entries
            $filteredEntries = if ($self.State.filterLevel -eq "All") {
                $self.State.logEntries
            } else {
                $self.State.logEntries | Where-Object { $_.Level -eq $self.State.filterLevel }
            }
            
            # Display log entries
            $visibleStart = $self.State.scrollOffset
            $visibleEnd = [Math]::Min($filteredEntries.Count - 1, $visibleStart + $logHeight - 1)
            
            for ($i = $visibleStart; $i -le $visibleEnd; $i++) {
                $entry = $filteredEntries[$i]
                if (-not $entry) { continue }
                
                $y = $logY + ($i - $visibleStart)
                $isSelected = ($i -eq $self.State.selectedLine)
                
                # Level colors
                $levelColor = switch ($entry.Level) {
                    "Debug" { Get-ThemeColor "Subtle" }
                    "Verbose" { Get-ThemeColor "Secondary" }
                    "Info" { Get-ThemeColor "Primary" }
                    "Warning" { Get-ThemeColor "Warning" }
                    "Error" { Get-ThemeColor "Danger" }
                    default { Get-ThemeColor "Primary" }
                }
                
                # Background for selected line
                if ($isSelected) {
                    $bg = Get-ThemeColor "Accent"
                    Write-BufferString -X 2 -Y $y -Text (" " * ($global:TuiState.BufferWidth - 4)) -BackgroundColor $bg
                } else {
                    $bg = Get-ThemeColor "Background"
                }
                
                # Format log line
                $timestamp = if ($entry.Timestamp) { $entry.Timestamp } else { "" }
                $level = if ($entry.Level) { "[$($entry.Level.PadRight(7))]" } else { "[Unknown]" }
                $message = if ($entry.Message) { $entry.Message } else { "" }
                
                # Truncate message if too long
                $maxMessageLength = $global:TuiState.BufferWidth - 30
                if ($message.Length -gt $maxMessageLength) {
                    $message = $message.Substring(0, $maxMessageLength - 3) + "..."
                }
                
                # Write log entry
                Write-BufferString -X 2 -Y $y -Text $timestamp -ForegroundColor (Get-ThemeColor "Subtle") -BackgroundColor $bg
                Write-BufferString -X 25 -Y $y -Text $level -ForegroundColor $levelColor -BackgroundColor $bg
                Write-BufferString -X 35 -Y $y -Text $message -ForegroundColor (Get-ThemeColor "Primary") -BackgroundColor $bg
            }
            
            # Scrollbar
            if ($filteredEntries.Count -gt $logHeight) {
                $scrollbarHeight = $logHeight
                $scrollPos = if ($filteredEntries.Count -gt 1) {
                    [Math]::Floor(($self.State.scrollOffset / ($filteredEntries.Count - $logHeight)) * ($scrollbarHeight - 1))
                } else { 0 }
                
                for ($i = 0; $i -lt $scrollbarHeight; $i++) {
                    $char = if ($i -eq $scrollPos) { "█" } else { "│" }
                    $color = if ($i -eq $scrollPos) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Subtle" }
                    Write-BufferString -X ($global:TuiState.BufferWidth - 2) -Y ($logY + $i) -Text $char -ForegroundColor $color
                }
            }
            
            # Status bar
            $statusY = $global:TuiState.BufferHeight - 2
            Write-BufferString -X 2 -Y $statusY -Text "↑↓: Navigate • F: Filter • A: Auto-scroll • C: Clear • Esc: Back" `
                -ForegroundColor (Get-ThemeColor "Subtle")
            
            # Display selected entry details if available
            if ($isSelected -and $entry.Data) {
                $detailText = "Data: $($entry.Data | ConvertTo-Json -Compress)"
                if ($detailText.Length -gt ($global:TuiState.BufferWidth - 4)) {
                    $detailText = $detailText.Substring(0, $global:TuiState.BufferWidth - 7) + "..."
                }
                Write-BufferString -X 2 -Y ($statusY - 1) -Text $detailText -ForegroundColor (Get-ThemeColor "Info")
            }
        }
        
        HandleInput = {
            param($self, $Key)
            
            $filteredEntries = if ($self.State.filterLevel -eq "All") {
                $self.State.logEntries
            } else {
                $self.State.logEntries | Where-Object { $_.Level -eq $self.State.filterLevel }
            }
            
            $logHeight = $global:TuiState.BufferHeight - 8
            
            switch ($Key.Key) {
                ([ConsoleKey]::Escape) { return "Back" }
                ([ConsoleKey]::UpArrow) {
                    if ($self.State.selectedLine -gt 0) {
                        $self.State.selectedLine--
                        $self.State.autoScroll = $false
                        
                        # Adjust scroll if needed
                        if ($self.State.selectedLine -lt $self.State.scrollOffset) {
                            $self.State.scrollOffset = $self.State.selectedLine
                        }
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($self.State.selectedLine -lt ($filteredEntries.Count - 1)) {
                        $self.State.selectedLine++
                        
                        # Re-enable auto-scroll if at bottom
                        if ($self.State.selectedLine -eq ($filteredEntries.Count - 1)) {
                            $self.State.autoScroll = $true
                        }
                        
                        # Adjust scroll if needed
                        if ($self.State.selectedLine -ge ($self.State.scrollOffset + $logHeight)) {
                            $self.State.scrollOffset = $self.State.selectedLine - $logHeight + 1
                        }
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::PageUp) {
                    $self.State.selectedLine = [Math]::Max(0, $self.State.selectedLine - $logHeight)
                    $self.State.scrollOffset = [Math]::Max(0, $self.State.scrollOffset - $logHeight)
                    $self.State.autoScroll = $false
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::PageDown) {
                    $maxLine = $filteredEntries.Count - 1
                    $self.State.selectedLine = [Math]::Min($maxLine, $self.State.selectedLine + $logHeight)
                    $self.State.scrollOffset = [Math]::Min([Math]::Max(0, $maxLine - $logHeight + 1), $self.State.scrollOffset + $logHeight)
                    
                    # Re-enable auto-scroll if at bottom
                    if ($self.State.selectedLine -eq $maxLine) {
                        $self.State.autoScroll = $true
                    }
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::Home) {
                    $self.State.selectedLine = 0
                    $self.State.scrollOffset = 0
                    $self.State.autoScroll = $false
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::End) {
                    $self.State.selectedLine = $filteredEntries.Count - 1
                    $self.State.scrollOffset = [Math]::Max(0, $filteredEntries.Count - $logHeight)
                    $self.State.autoScroll = $true
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::F) {
                    # Cycle through filter levels
                    $levels = @("All", "Debug", "Verbose", "Info", "Warning", "Error")
                    $currentIndex = [array]::IndexOf($levels, $self.State.filterLevel)
                    $self.State.filterLevel = $levels[($currentIndex + 1) % $levels.Count]
                    
                    # Reset selection
                    $self.State.selectedLine = 0
                    $self.State.scrollOffset = 0
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::A) {
                    # Toggle auto-scroll
                    $self.State.autoScroll = -not $self.State.autoScroll
                    if ($self.State.autoScroll) {
                        # Jump to bottom
                        $self.State.selectedLine = $filteredEntries.Count - 1
                        $self.State.scrollOffset = [Math]::Max(0, $filteredEntries.Count - $logHeight)
                    }
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::C) {
                    # Clear log
                    if (Get-Command Clear-LogQueue -ErrorAction SilentlyContinue) {
                        Clear-LogQueue
                        $self.State.logEntries = @()
                        $self.State.scrollOffset = 0
                        $self.State.selectedLine = 0
                        $self.State.lastLogCount = 0
                        Request-TuiRefresh
                    }
                    return $true
                }
            }
            
            return $false
        }
    }
    
    return $screen
}

Export-ModuleMember -Function Get-DebugLogScreen