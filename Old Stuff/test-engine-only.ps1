# Minimal test for TUI Engine v2

# Load the required modules
Import-Module "$PSScriptRoot\modules\event-system.psm1" -Force
Import-Module "$PSScriptRoot\modules\theme-manager.psm1" -Force
Import-Module "$PSScriptRoot\modules\tui-engine-v2.psm1" -Force

# Initialize subsystems
Initialize-EventSystem
Initialize-ThemeManager

# Create a minimal test screen
$testScreen = @{
    Name = "TestScreen"
    State = @{ Counter = 0 }
    
    Init = {
        param($self)
        Write-Host "Test screen initialized"
    }
    
    Render = {
        param($self)
        Write-BufferString -X 2 -Y 2 -Text "TUI Engine Test - Press Q to quit" -ForegroundColor White
        Write-BufferString -X 2 -Y 4 -Text "Counter: $($self.State.Counter)" -ForegroundColor Cyan
        Write-BufferString -X 2 -Y 6 -Text "Press SPACE to increment counter" -ForegroundColor Gray
    }
    
    HandleInput = {
        param($self, $Key)
        switch ($Key.Key) {
            ([ConsoleKey]::Q) { return "Quit" }
            ([ConsoleKey]::Spacebar) { 
                $self.State.Counter++
                Request-TuiRefresh
                return $true 
            }
        }
        return $false
    }
}

try {
    Write-Host "Starting TUI Engine test..." -ForegroundColor Green
    Start-TuiLoop -InitialScreen $testScreen
    Write-Host "TUI Engine test completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "TUI Engine test failed: $_" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
}
