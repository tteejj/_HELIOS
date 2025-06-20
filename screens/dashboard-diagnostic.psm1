# Dashboard Diagnostic Version - Traces Panel Rendering
function Get-DashboardDiagnostic {
    param([hashtable]$Services)

    $screen = @{
        Name = "DashboardDiagnostic"
        Components = @{}
        Children = @()
        _services = $Services
        _subscriptions = @()
        Visible = $true
        ZIndex = 0

        Init = {
            param($self, $services)
            
            Write-Host "[DIAG] Dashboard Init starting..." -ForegroundColor Cyan
            
            # Store services
            if (-not $services) {
                $services = $self._services ?? $global:Services
            }
            $self._services = $services
            
            # Create a simple test panel first
            Write-Host "[DIAG] Creating test panel..." -ForegroundColor Yellow
            $testPanel = New-TuiStackPanel -Props @{
                Name = "testPanel"
                X = 5
                Y = 5
                Width = 50
                Height = 10
                BackgroundColor = [ConsoleColor]::DarkBlue
                BorderStyle = "Single"
                Title = "Test Panel"
                ShowBorder = $true
            }
            
            # Add a simple label
            $label = New-TuiLabel -Props @{
                Text = "This is a test label"
                ForegroundColor = [ConsoleColor]::White
            }
            & $testPanel.AddChild -self $testPanel -Child $label
            
            # Add panel to children
            $self.Children += $testPanel
            
            Write-Host "[DIAG] Test panel created. Children count: $($self.Children.Count)" -ForegroundColor Green
            Write-Host "[DIAG] Panel properties:" -ForegroundColor Cyan
            Write-Host "  X: $($testPanel.X), Y: $($testPanel.Y)" -ForegroundColor Gray
            Write-Host "  Width: $($testPanel.Width), Height: $($testPanel.Height)" -ForegroundColor Gray
            Write-Host "  Visible: $($testPanel.Visible)" -ForegroundColor Gray
            Write-Host "  Children: $($testPanel.Children.Count)" -ForegroundColor Gray
        }
        
        Render = {
            param($self)
            
            # Draw diagnostic info
            Write-BufferString -X 2 -Y 1 -Text "DASHBOARD DIAGNOSTIC MODE" -ForegroundColor Red
            Write-BufferString -X 2 -Y 2 -Text "Children in screen: $($self.Children.Count)" -ForegroundColor Yellow
            
            # Manually check if panel would be visible
            if ($self.Children.Count -gt 0) {
                $panel = $self.Children[0]
                Write-BufferString -X 2 -Y 3 -Text "Panel at X=$($panel.X) Y=$($panel.Y) W=$($panel.Width) H=$($panel.Height)" -ForegroundColor Cyan
                
                # Try manual render of the panel border
                if ($panel.ShowBorder) {
                    Write-BufferString -X 2 -Y 4 -Text "Attempting manual border render..." -ForegroundColor Magenta
                    
                    # Draw a simple box manually
                    $x = $panel.X
                    $y = $panel.Y
                    $w = $panel.Width
                    $h = $panel.Height
                    
                    # Top border
                    Write-BufferString -X $x -Y $y -Text ("┌" + ("─" * ($w - 2)) + "┐") -ForegroundColor White
                    
                    # Title if exists
                    if ($panel.Title) {
                        Write-BufferString -X ($x + 2) -Y $y -Text $panel.Title -ForegroundColor Yellow
                    }
                    
                    # Side borders
                    for ($i = 1; $i -lt $h - 1; $i++) {
                        Write-BufferString -X $x -Y ($y + $i) -Text "│" -ForegroundColor White
                        Write-BufferString -X ($x + $w - 1) -Y ($y + $i) -Text "│" -ForegroundColor White
                    }
                    
                    # Bottom border
                    Write-BufferString -X $x -Y ($y + $h - 1) -Text ("└" + ("─" * ($w - 2)) + "┘") -ForegroundColor White
                    
                    # Content area background
                    if ($panel.BackgroundColor) {
                        for ($row = 1; $row -lt $h - 1; $row++) {
                            $spaces = " " * ($w - 2)
                            Write-BufferString -X ($x + 1) -Y ($y + $row) -Text $spaces -BackgroundColor $panel.BackgroundColor
                        }
                    }
                }
            }
            
            # Status
            Write-BufferString -X 2 -Y ($global:TuiState.BufferHeight - 2) -Text "Press Q to quit | This is diagnostic mode" -ForegroundColor Gray
        }
        
        HandleInput = {
            param($self, $Key)
            
            if ($Key.Key -eq [ConsoleKey]::Q -or $Key.KeyChar -eq 'q') {
                return "Quit"
            }
            
            return $false
        }
        
        OnExit = {
            param($self)
            Write-Host "[DIAG] Dashboard exiting" -ForegroundColor Cyan
        }
    }
    
    $screen._services = $Services
    return $screen
}

# Export the function
Export-ModuleMember -Function Get-DashboardDiagnostic