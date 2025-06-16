# Simple TUI Engine Fix Test
Write-Host "Testing TUI Engine after fixes..." -ForegroundColor Cyan

# Import only the required modules
$modules = @(
    ".\modules\event-system.psm1",
    ".\modules\theme-manager.psm1",
    ".\modules\tui-engine-v2.psm1"
)

foreach ($module in $modules) {
    Write-Host "Loading $module..." -ForegroundColor Gray
    Import-Module $module -Force
}

# Initialize basic systems
Initialize-EventSystem
Initialize-ThemeManager

try {
    Write-Host "`nInitializing TUI Engine..." -ForegroundColor Yellow
    Initialize-TuiEngine
    
    Write-Host "`nSUCCESS! TUI Engine initialized without errors!" -ForegroundColor Green
    Write-Host "Buffer dimensions: $($global:TuiState.BufferWidth) x $($global:TuiState.BufferHeight)" -ForegroundColor Green
    
    # Test basic buffer operations
    Write-Host "`nTesting buffer operations..." -ForegroundColor Yellow
    Clear-BackBuffer
    Write-BufferString -X 5 -Y 5 -Text "Hello, TUI!" -ForegroundColor Green
    Write-BufferBox -X 2 -Y 2 -Width 20 -Height 5 -Title " Test " -BorderColor Cyan
    
    Write-Host "Buffer operations successful!" -ForegroundColor Green
    
    # Clean up
    Write-Host "`nCleaning up..." -ForegroundColor Gray
    Cleanup-TuiEngine
    
    Write-Host "`nAll tests passed! ✓" -ForegroundColor Green
    
} catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    
    # Try to clean up even on error
    try { Cleanup-TuiEngine } catch { }
}

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
