# Console Size Validation and Safe Dashboard Layout
# Add minimum size check to main.ps1 and fix dashboard calculations

function Test-ConsoleSize {
    $minWidth = 80
    $minHeight = 24
    $currentWidth = [Console]::WindowWidth
    $currentHeight = [Console]::WindowHeight
    
    if ($currentWidth -lt $minWidth -or $currentHeight -lt $minHeight) {
        Write-Host "Console window too small!" -ForegroundColor Red
        Write-Host "Current size: ${currentWidth}x${currentHeight}" -ForegroundColor Yellow
        Write-Host "Minimum required: ${minWidth}x${minHeight}" -ForegroundColor Green
        Write-Host ""
        Write-Host "Please resize your console window and try again." -ForegroundColor White
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }
    return $true
}

function Initialize-PMCModules {
    Write-Host "Checking console size..." -ForegroundColor Cyan
    if (-not (Test-ConsoleSize)) {
        exit 1
    }
    
    Write-Host "Initializing PMC Terminal v3.0..." -ForegroundColor Cyan
    
    $loadedModules = @()
    
    foreach ($module in $script:ModulesToLoad) {
        $modulePath = Join-Path $script:BasePath $module.Path
        
        try {
            if (Test-Path $modulePath) {
                Write-Host "  Loading $($module.Name)..." -ForegroundColor Gray
                Import-Module $modulePath -Force -Global -ErrorAction Stop
                $loadedModules += $module.Name
            } elseif ($module.Required) {
                throw "Required module not found: $($module.Name) at $modulePath"
            }
        } catch {
            if ($module.Required) {
                throw "Failed to load required module $($module.Name): $_"
            }
        }
    }
    
    Write-Host "Loaded $($loadedModules.Count) modules successfully" -ForegroundColor Green
    return $loadedModules
}