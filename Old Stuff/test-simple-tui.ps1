# Super Simple TUI Test
# Tests the most basic TUI functionality

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Starting super simple TUI test..." -ForegroundColor Yellow
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = [Console]::ReadKey($true)

try {
    # Import just the TUI engine
    $basePath = Split-Path -Parent $MyInvocation.MyCommand.Path
    Import-Module "$basePath\modules\tui-engine-v2.psm1" -Force
    
    # Create a minimal theme function
    function Get-ThemeColor { param($name) return [ConsoleColor]::White }
    
    # Initialize engine with small size
    Initialize-TuiEngine -Width 60 -Height 20
    
    # Create the simplest possible screen
    $simpleScreen = @{
        Name = "SimpleScreen"
        State = @{ KeyPressed = "None" }
        
        Render = {
            param($self)
            Write-BufferString -X 5 -Y 5 -Text "Super Simple TUI Test"
            Write-BufferString -X 5 -Y 7 -Text "Last key: $($self.State.KeyPressed)"
            Write-BufferString -X 5 -Y 9 -Text "Press Q to quit"
        }
        
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -eq [ConsoleKey]::Q) {
                return "Quit"
            }
            $self.State.KeyPressed = $Key.Key.ToString()
            Request-TuiRefresh
            return $true
        }
    }
    
    # Start the loop
    Push-Screen -Screen ([PSCustomObject]$simpleScreen)
    Start-TuiLoop
    
    Write-Host "`nTest completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
} finally {
    [Console]::CursorVisible = $true
    [Console]::Clear()
    [Console]::ResetColor()
    Write-Host "Test ended. Press any key to exit..." -ForegroundColor Gray
    $null = [Console]::ReadKey($true)
}