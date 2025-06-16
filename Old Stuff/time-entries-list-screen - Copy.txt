# Time Entries List Screen

function Get-TimeEntriesListScreen {
    $screen = @{
        Name = "TimeEntriesListScreen"
        State = @{
            Entries = @()
            FilterProject = $null
            FilterDateStart = (Get-Date).AddDays(-7)
            FilterDateEnd = (Get-Date)
            SelectedIndex = 0
            PageSize = 15
            CurrentPage = 0
        }
        
        Init = {
            param($self)
            # Load initial data
            & $self.RefreshData -self $self
        }
        
        RefreshData = {
            param($self)
            $entries = $script:Data.TimeEntries
            
            # Apply filters
            if ($self.State.FilterProject) {
                $entries = $entries | Where-Object { $_.ProjectKey -eq $self.State.FilterProject }
            }
            
            $startStr = $self.State.FilterDateStart.ToString("yyyy-MM-dd")
            $endStr = $self.State.FilterDateEnd.ToString("yyyy-MM-dd")
            $entries = $entries | Where-Object { 
                $_.Date -ge $startStr -and $_.Date -le $endStr 
            }
            
            # Sort by date descending
            $self.State.Entries = $entries | Sort-Object -Property Date -Descending
            $self.State.CurrentPage = 0
            $self.State.SelectedIndex = 0
        }
        
        Render = {
            param($self)
            
            # Header
            Write-BufferString -X 2 -Y 1 -Text "Time Entries" -ForegroundColor (Get-ThemeColor "Header")
            
            # Filter info
            $filterText = "Showing: "
            if ($self.State.FilterProject) {
                $project = Get-ProjectById -ProjectId $self.State.FilterProject
                $filterText += "$($project.Name) | "
            } else {
                $filterText += "All Projects | "
            }
            $filterText += "$($self.State.FilterDateStart.ToString('MM/dd')) - $($self.State.FilterDateEnd.ToString('MM/dd'))"
            Write-BufferString -X 2 -Y 3 -Text $filterText -ForegroundColor (Get-ThemeColor "Subtle")
            
            # Calculate totals
            $totalHours = ($self.State.Entries | Measure-Object -Property Hours -Sum).Sum
            $totalHours = if ($totalHours) { [Math]::Round($totalHours, 2) } else { 0 }
            Write-BufferString -X ($script:TuiState.BufferWidth - 20) -Y 3 `
                -Text "Total: $totalHours hours" -ForegroundColor (Get-ThemeColor "Success")
            
            # Table headers
            $tableY = 5
            Write-BufferString -X 2 -Y $tableY -Text "Date" -ForegroundColor (Get-ThemeColor "Header")
            Write-BufferString -X 15 -Y $tableY -Text "Project" -ForegroundColor (Get-ThemeColor "Header")
            Write-BufferString -X 40 -Y $tableY -Text "Hours" -ForegroundColor (Get-ThemeColor "Header")
            Write-BufferString -X 50 -Y $tableY -Text "Description" -ForegroundColor (Get-ThemeColor "Header")
            
            # Separator
            Write-BufferString -X 2 -Y ($tableY + 1) `
                -Text ("─" * ($script:TuiState.BufferWidth - 4)) -ForegroundColor (Get-ThemeColor "Secondary")
            
            # Entries
            $startIdx = $self.State.CurrentPage * $self.State.PageSize
            $endIdx = [Math]::Min($startIdx + $self.State.PageSize, $self.State.Entries.Count)
            $displayIdx = 0
            
            for ($i = $startIdx; $i -lt $endIdx; $i++) {
                $entry = $self.State.Entries[$i]
                $rowY = $tableY + 2 + $displayIdx
                
                $isSelected = ($i -eq $self.State.SelectedIndex)
                $bgColor = if ($isSelected) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Background" }
                $fgColor = if ($isSelected) { Get-ThemeColor "Background" } else { Get-ThemeColor "Primary" }
                
                # Clear row if selected
                if ($isSelected) {
                    Write-BufferString -X 1 -Y $rowY -Text (" " * ($script:TuiState.BufferWidth - 2)) `
                        -BackgroundColor $bgColor
                }
                
                # Date
                $date = [DateTime]::Parse($entry.Date)
                Write-BufferString -X 2 -Y $rowY -Text $date.ToString("MM/dd/yyyy") `
                    -ForegroundColor $fgColor -BackgroundColor $bgColor
                
                # Project
                $project = Get-ProjectById -ProjectId $entry.ProjectKey
                $projectName = if ($project) { $project.Name } else { "Unknown" }
                if ($projectName.Length -gt 22) { $projectName = $projectName.Substring(0, 19) + "..." }
                Write-BufferString -X 15 -Y $rowY -Text $projectName `
                    -ForegroundColor $fgColor -BackgroundColor $bgColor
                
                # Hours
                Write-BufferString -X 40 -Y $rowY -Text $entry.Hours.ToString("0.00") `
                    -ForegroundColor $fgColor -BackgroundColor $bgColor
                
                # Description
                $desc = $entry.Description ?? ""
                $maxDescLen = $script:TuiState.BufferWidth - 52
                if ($desc.Length -gt $maxDescLen) { $desc = $desc.Substring(0, $maxDescLen - 3) + "..." }
                Write-BufferString -X 50 -Y $rowY -Text $desc `
                    -ForegroundColor $fgColor -BackgroundColor $bgColor
                
                $displayIdx++
            }
            
            # Page info
            $totalPages = [Math]::Ceiling($self.State.Entries.Count / $self.State.PageSize)
            $pageText = "Page $($self.State.CurrentPage + 1) of $totalPages"
            Write-BufferString -X ([Math]::Floor(($script:TuiState.BufferWidth - $pageText.Length) / 2)) `
                -Y ($script:TuiState.BufferHeight - 4) -Text $pageText -ForegroundColor (Get-ThemeColor "Subtle")
            
            # Instructions
            $instructions = "[↑↓] Navigate | [Enter] Edit | [Del] Delete | [F] Filter | [N] New | [Esc] Back"
            Write-BufferString -X ([Math]::Floor(($script:TuiState.BufferWidth - $instructions.Length) / 2)) `
                -Y ($script:TuiState.BufferHeight - 2) -Text $instructions -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        HandleInput = {
            param($self, $Key)
            
            $pageSize = $self.State.PageSize
            $totalEntries = $self.State.Entries.Count
            
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($self.State.SelectedIndex -gt 0) {
                        $self.State.SelectedIndex--
                        
                        # Update page if needed
                        $newPage = [Math]::Floor($self.State.SelectedIndex / $pageSize)
                        if ($newPage -ne $self.State.CurrentPage) {
                            $self.State.CurrentPage = $newPage
                        }
                        
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($self.State.SelectedIndex -lt $totalEntries - 1) {
                        $self.State.SelectedIndex++
                        
                        # Update page if needed
                        $newPage = [Math]::Floor($self.State.SelectedIndex / $pageSize)
                        if ($newPage -ne $self.State.CurrentPage) {
                            $self.State.CurrentPage = $newPage
                        }
                        
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::PageUp) {
                    if ($self.State.CurrentPage -gt 0) {
                        $self.State.CurrentPage--
                        $self.State.SelectedIndex = $self.State.CurrentPage * $pageSize
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::PageDown) {
                    $totalPages = [Math]::Ceiling($totalEntries / $pageSize)
                    if ($self.State.CurrentPage -lt $totalPages - 1) {
                        $self.State.CurrentPage++
                        $self.State.SelectedIndex = $self.State.CurrentPage * $pageSize
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    if ($totalEntries -gt 0) {
                        $selectedEntry = $self.State.Entries[$self.State.SelectedIndex]
                        # TODO: Push edit screen
                        Publish-Event -EventName "Notification.Show" -Data @{
                            Text = "Edit time entry not implemented yet"
                            Type = "Info"
                        }
                    }
                    return $true
                }
                ([ConsoleKey]::Delete) {
                    if ($totalEntries -gt 0) {
                        $selectedEntry = $self.State.Entries[$self.State.SelectedIndex]
                        
                        # Show confirmation dialog
                        $dialog = New-TuiDialog -Props @{
                            Title = "Delete Time Entry"
                            Message = "Delete entry for $($selectedEntry.Hours) hours?`n`n$($selectedEntry.Description)"
                            Buttons = @("Delete", "Cancel")
                            OnButtonClick = {
                                param($Button)
                                if ($Button -eq "Delete") {
                                    # Remove from data
                                    $script:Data.TimeEntries = $script:Data.TimeEntries | 
                                        Where-Object { $_.Id -ne $selectedEntry.Id }
                                    Save-UnifiedData
                                    
                                    # Refresh display
                                    & $self.RefreshData -self $self
                                    Request-TuiRefresh
                                    
                                    Publish-Event -EventName "Notification.Show" -Data @{
                                        Text = "Time entry deleted"
                                        Type = "Success"
                                    }
                                }
                            }
                        }
                        # TODO: Show dialog
                    }
                    return $true
                }
                ([ConsoleKey]::N) {
                    Push-Screen -Screen (Get-TimeEntryFormScreen)
                    return $true
                }
                ([ConsoleKey]::F) {
                    # TODO: Show filter dialog
                    Publish-Event -EventName "Notification.Show" -Data @{
                        Text = "Filter dialog not implemented yet"
                        Type = "Info"
                    }
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    return "Back"
                }
            }
            
            return $false
        }
        
        OnResume = {
            param($self)
            # Refresh data when returning to this screen
            & $self.RefreshData -self $self
            Request-TuiRefresh
        }
    }
    
    return $screen
}

Export-ModuleMember -Function 'Get-TimeEntriesListScreen'
