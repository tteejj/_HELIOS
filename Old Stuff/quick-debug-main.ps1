# Quick Debug Version - Add These Debug Lines to Your main.ps1
# Insert these debug blocks into the Start-PMCTerminal function right after "Initializing subsystems..."

function Start-PMCTerminal {
    try {
        $loadedModules = Initialize-PMCModules
        
        Write-Host "`nInitializing subsystems..." -ForegroundColor Cyan
        
        # Add debug before each initialization step
        Write-Host "DEBUG: About to Initialize-EventSystem" -ForegroundColor Yellow
        try {
            Initialize-EventSystem
            Write-Host "DEBUG: Initialize-EventSystem completed" -ForegroundColor Green
        } catch {
            Write-Host "DEBUG: Initialize-EventSystem FAILED: $_" -ForegroundColor Red
            throw
        }
        
        Write-Host "DEBUG: About to Initialize-ThemeManager" -ForegroundColor Yellow
        try {
            Initialize-ThemeManager
            Write-Host "DEBUG: Initialize-ThemeManager completed" -ForegroundColor Green
        } catch {
            Write-Host "DEBUG: Initialize-ThemeManager FAILED: $_" -ForegroundColor Red
            throw
        }
        
        Write-Host "DEBUG: About to Initialize-DataManager" -ForegroundColor Yellow
        try {
            Initialize-DataManager
            Write-Host "DEBUG: Initialize-DataManager completed" -ForegroundColor Green
        } catch {
            Write-Host "DEBUG: Initialize-DataManager FAILED: $_" -ForegroundColor Red
            throw
        }
        
        Write-Host "DEBUG: About to Initialize-TuiEngine" -ForegroundColor Yellow
        try {
            Initialize-TuiEngine
            Write-Host "DEBUG: Initialize-TuiEngine completed" -ForegroundColor Green
        } catch {
            Write-Host "DEBUG: Initialize-TuiEngine FAILED: $_" -ForegroundColor Red
            Write-Host "DEBUG: THIS IS LIKELY WHERE YOUR NULL METHOD ERROR OCCURS" -ForegroundColor Red
            throw
        }
        
        Write-Host "DEBUG: About to Initialize-DialogSystem" -ForegroundColor Yellow
        try {
            Initialize-DialogSystem
            Write-Host "DEBUG: Initialize-DialogSystem completed" -ForegroundColor Green
        } catch {
            Write-Host "DEBUG: Initialize-DialogSystem FAILED: $_" -ForegroundColor Red
            throw
        }
        
        # Continue with rest of function...
        # Load-UnifiedData, etc.
        
    } catch {
        Write-Error "FATAL: Failed to initialize PMC Terminal: $_"
        throw
    }
}
