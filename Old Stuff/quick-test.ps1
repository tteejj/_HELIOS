# Quick test to verify TUI engine loads without errors
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    Write-Host "Testing TUI Engine module import..." -ForegroundColor Yellow
    Import-Module ".\modules\tui-engine-v2.psm1" -Force
    Write-Host "✓ TUI Engine imported successfully!" -ForegroundColor Green
    
    Write-Host "Testing engine initialization..." -ForegroundColor Yellow
    Initialize-TuiEngine -Width 80 -Height 24
    Write-Host "✓ TUI Engine initialized successfully!" -ForegroundColor Green
    
    Write-Host "All tests passed! The generic type instantiation issue is fixed." -ForegroundColor Green
    
} catch {
    Write-Host "✗ Test failed: $_" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
    exit 1
} finally {
    # Cleanup
    if (Get-Module "tui-engine-v2") {
        Remove-Module "tui-engine-v2"
    }
}
