# Quick test to verify TUI engine fix
Write-Host "Testing TUI Engine Fix..." -ForegroundColor Green

# Load required modules
Import-Module ".\modules\event-system.psm1" -Force
Import-Module ".\modules\data-manager.psm1" -Force
Import-Module ".\modules\theme-manager.psm1" -Force

# Initialize subsystems
Initialize-EventSystem
Initialize-ThemeManager
Initialize-DataManager

# Load TUI engine
Import-Module ".\modules\tui-engine-v2.psm1" -Force

try {
    # Create a simple test screen
    $testScreen = @{
        Name = "TestScreen"
        Render = {
            param($self)
            Write-BufferString -X 10 -Y 5 -Text "TUI Engine is working!" -ForegroundColor Green
            Write-BufferString -X 10 -Y 7 -Text "Press 'Q' to quit" -ForegroundColor Yellow
            Write-BufferBox -X 5 -Y 3 -Width 40 -Height 10 -Title " Test Screen " -BorderColor Cyan
        }
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -eq [ConsoleKey]::Q) {
                return "Quit"
            }
            return $false
        }
    }
    
    # Start the TUI loop
    Start-TuiLoop -InitialScreen $testScreen
    
    Write-Host "`nTUI Engine test completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "`nTUI Engine test failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}
