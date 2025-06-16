# Test script to verify TUI engine fix
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    $basePath = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    Write-Host "Testing TUI Engine initialization..." -ForegroundColor Cyan
    
    # Import just the TUI engine module
    $tuiModulePath = Join-Path $basePath "modules\tui-engine-v2.psm1"
    Import-Module $tuiModulePath -Force
    
    Write-Host "Module imported successfully" -ForegroundColor Green
    
    # Test basic initialization
    Initialize-TuiEngine -Width 80 -Height 24
    
    Write-Host "TUI Engine initialized successfully!" -ForegroundColor Green
    Write-Host "The ArrayList creation bug has been fixed." -ForegroundColor Green
    
    # Test creating a simple screen
    $testScreen = @{
        Name = "TestScreen"
        State = @{}
        
        Render = {
            Write-BufferBox -X 10 -Y 5 -Width 50 -Height 10 -Title " Test Screen " -BorderColor "Green"
            Write-BufferString -X 15 -Y 8 -Text "TUI Engine is working!" -ForegroundColor "White"
            Write-BufferString -X 15 -Y 10 -Text "Press Q to quit" -ForegroundColor "Yellow"
        }
        
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -eq [ConsoleKey]::Q) {
                return "Quit"
            }
            return $false
        }
    }
    
    Write-Host "Starting TUI test (press Q to quit)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    
    Start-TuiLoop -InitialScreen $testScreen
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
} finally {
    Write-Host "`nTest completed." -ForegroundColor Cyan
}
