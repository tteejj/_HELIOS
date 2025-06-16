# Quick test to verify the dashboard screen fix
# Navigate to the current directory and run this

Set-Location "C:\Users\jhnhe\Documents\GitHub\pmc-terminal\modular\experimental features\new testgtound\fixed\current"

try {
    Write-Host "Testing dashboard screen syntax..." -ForegroundColor Cyan
    
    # Import just the dashboard screen module to test it
    Import-Module ".\screens\dashboard-screen.psm1" -Force
    
    # Try to create the dashboard screen (this should not throw the 'if' error)
    $dashboard = Get-DashboardScreen
    
    if ($dashboard) {
        Write-Host "✓ Dashboard screen loaded successfully!" -ForegroundColor Green
        Write-Host "✓ No 'if' syntax errors detected" -ForegroundColor Green
        
        # Test the render function specifically
        Write-Host "Testing render function..." -ForegroundColor Yellow
        
        # Create minimal TUI state for testing
        $global:TuiState = @{
            BufferWidth = 120
            BufferHeight = 30
            BackBuffer = New-Object 'object[,]' 30, 120
        }
        
        # Initialize buffer
        for ($y = 0; $y -lt 30; $y++) {
            for ($x = 0; $x -lt 120; $x++) {
                $global:TuiState.BackBuffer[$y, $x] = @{ Char = ' '; FG = [ConsoleColor]::White; BG = [ConsoleColor]::Black }
            }
        }
        
        # Mock the TUI functions
        function Write-BufferString { param($X, $Y, $Text, $ForegroundColor, $BackgroundColor) }
        function Write-BufferBox { param($X, $Y, $Width, $Height, $Title, $BorderColor) }
        function Request-TuiRefresh { }
        
        # Test the render function
        try {
            & $dashboard.Render -self $dashboard
            Write-Host "✓ Render function executed without errors!" -ForegroundColor Green
        } catch {
            Write-Host "✗ Render function error: $_" -ForegroundColor Red
        }
        
    } else {
        Write-Host "✗ Failed to create dashboard screen" -ForegroundColor Red
    }
    
} catch {
    Write-Host "✗ Error: $_" -ForegroundColor Red
} finally {
    Write-Host "`nTest complete. You can now run your main application." -ForegroundColor White
}
