# Test the diagnostic dashboard
Write-Host "Loading diagnostic dashboard..." -ForegroundColor Cyan

# Load modules
. ".\main-helios.ps1"

try {
    # Initialize everything
    $loadedModules = Initialize-PMCModules -Silent:$true
    Initialize-Logger
    Initialize-EventSystem
    Initialize-ThemeManager
    Initialize-DataManager
    Initialize-TuiFramework
    Initialize-TuiEngine
    Initialize-DialogSystem
    Initialize-FocusManager
    
    # Load screens including diagnostic
    Initialize-PMCScreens -Silent:$true
    Import-Module ".\screens\dashboard-diagnostic.psm1" -Force -Global
    
    # Initialize services
    $services = Initialize-PMCServices -Silent:$true
    
    # Get TUI state info
    Write-Host "`nTUI State Info:" -ForegroundColor Yellow
    Write-Host "  Buffer Width: $($global:TuiState.BufferWidth)" -ForegroundColor Gray
    Write-Host "  Buffer Height: $($global:TuiState.BufferHeight)" -ForegroundColor Gray
    Write-Host "  Screen Stack: $($global:TuiState.ScreenStack.Count)" -ForegroundColor Gray
    
    # Create diagnostic dashboard
    Write-Host "`nCreating diagnostic dashboard..." -ForegroundColor Yellow
    $dashboard = Get-DashboardDiagnostic -Services $services
    
    if ($dashboard) {
        Write-Host "Dashboard created successfully" -ForegroundColor Green
        
        # Initialize it
        if ($dashboard.Init) {
            & $dashboard.Init -self $dashboard -services $services
        }
        
        # Check what happened
        Write-Host "`nPost-init state:" -ForegroundColor Yellow
        Write-Host "  Children count: $($dashboard.Children.Count)" -ForegroundColor Gray
        
        if ($dashboard.Children.Count -gt 0) {
            $panel = $dashboard.Children[0]
            Write-Host "  First child type: $($panel.Type ?? 'Unknown')" -ForegroundColor Gray
            Write-Host "  First child name: $($panel.Name ?? 'Unnamed')" -ForegroundColor Gray
            
            # Check if panel has Render method
            if ($panel.Render) {
                Write-Host "  Panel has Render method: Yes" -ForegroundColor Green
            } else {
                Write-Host "  Panel has Render method: No" -ForegroundColor Red
            }
        }
        
        Write-Host "`nPress Enter to start the TUI loop..." -ForegroundColor Yellow
        $null = Read-Host
        
        Clear-Host
        Push-Screen -Screen $dashboard
        Start-TuiLoop
    } else {
        Write-Host "Failed to create dashboard" -ForegroundColor Red
    }
    
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
} finally {
    if (Get-Command -Name "Stop-TuiEngine" -ErrorAction SilentlyContinue) {
        Stop-TuiEngine
    }
}