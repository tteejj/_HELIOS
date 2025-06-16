# Enhanced Debug Version - Pinpoint the render error

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$script:BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Module loading order is critical - dependencies must load first
$script:ModulesToLoad = @(
    @{ Name = "event-system"; Path = "modules\event-system.psm1"; Required = $true },
    @{ Name = "data-manager"; Path = "modules\data-manager.psm1"; Required = $true },
    @{ Name = "theme-manager"; Path = "modules\theme-manager.psm1"; Required = $true },
    @{ Name = "tui-engine-v2"; Path = "modules\tui-engine-v2.psm1"; Required = $true },
    @{ Name = "dialog-system"; Path = "modules\dialog-system.psm1"; Required = $true },
    @{ Name = "tui-components"; Path = "components\tui-components.psm1"; Required = $true },
    @{ Name = "advanced-input-components"; Path = "components\advanced-input-components.psm1"; Required = $false },
    @{ Name = "advanced-data-components"; Path = "components\advanced-data-components.psm1"; Required = $false },
    @{ Name = "tui-framework"; Path = "modules\tui-framework.psm1"; Required = $false }
)

Write-Host "Loading modules..." -ForegroundColor Cyan
foreach ($module in $script:ModulesToLoad) {
    $modulePath = Join-Path $script:BasePath $module.Path
    try {
        if (Test-Path $modulePath) {
            Write-Host "  Loading $($module.Name)..." -ForegroundColor Gray
            Import-Module $modulePath -Force -Global -ErrorAction Stop
        }
    } catch {
        Write-Host "  ERROR loading $($module.Name): $_" -ForegroundColor Red
    }
}

Write-Host "`nInitializing subsystems..." -ForegroundColor Cyan

# Initialize in order
Initialize-EventSystem
Initialize-ThemeManager  
Initialize-DataManager
Initialize-TuiEngine
Initialize-DialogSystem
Load-UnifiedData

if (Get-Command -Name "Initialize-TuiFramework" -ErrorAction SilentlyContinue) {
    Initialize-TuiFramework
}

# Load dashboard screen
Write-Host "`nLoading dashboard screen..." -ForegroundColor Yellow
$screenPath = Join-Path $script:BasePath "screens\dashboard-screen.psm1"
Import-Module $screenPath -Force -Global

# Create test dashboard with extensive debugging
Write-Host "`nCreating debug dashboard..." -ForegroundColor Yellow

$debugDashboard = @{
    Name = "DebugDashboard"
    State = @{
        SelectedQuickAction = 0
    }
    
    Render = {
        param($self)
        
        Write-Host "`nDEBUG: Starting dashboard render" -ForegroundColor Magenta
        
        try {
            # Test 1: Simple header
            Write-Host "DEBUG: Writing header string" -ForegroundColor Cyan
            Write-BufferString -X 2 -Y 1 -Text "PMC Terminal Dashboard - Debug Mode" -ForegroundColor "Cyan"
            Write-Host "DEBUG: Header written successfully" -ForegroundColor Green
            
            # Test 2: Simple box
            Write-Host "DEBUG: Drawing box" -ForegroundColor Cyan
            Write-BufferBox -X 2 -Y 3 -Width 40 -Height 10 -Title " Quick Actions " -BorderColor "Yellow"
            Write-Host "DEBUG: Box drawn successfully" -ForegroundColor Green
            
            # Test 3: Menu items with explicit conditional
            Write-Host "DEBUG: Drawing menu items" -ForegroundColor Cyan
            $actions = @("1. Add Time Entry", "2. Start Timer", "3. Manage Tasks")
            
            $y = 5
            foreach ($i in 0..($actions.Count - 1)) {
                Write-Host "DEBUG: Processing menu item $i" -ForegroundColor Gray
                
                # Explicit conditional test
                $isSelected = $i -eq $self.State.SelectedQuickAction
                Write-Host "DEBUG: isSelected = $isSelected" -ForegroundColor Gray
                
                # Build text and color separately
                $text = "  " + $actions[$i]
                $color = "White"
                
                if ($isSelected) {
                    Write-Host "DEBUG: Item is selected, changing format" -ForegroundColor Gray
                    $text = "→ " + $actions[$i]
                    $color = "Yellow"
                }
                
                Write-Host "DEBUG: Writing menu item: $text with color $color" -ForegroundColor Gray
                Write-BufferString -X 4 -Y $y -Text $text -ForegroundColor $color
                $y++
            }
            
            Write-Host "DEBUG: All menu items written" -ForegroundColor Green
            
            # Instructions
            Write-Host "DEBUG: Writing instructions" -ForegroundColor Cyan
            Write-BufferString -X 2 -Y 20 -Text "↑↓ Navigate • Enter: Select • Q: Quit" -ForegroundColor "Gray"
            Write-Host "DEBUG: Instructions written" -ForegroundColor Green
            
            Write-Host "DEBUG: Render completed successfully!" -ForegroundColor Green
            
        } catch {
            Write-Host "DEBUG: RENDER ERROR CAUGHT: $_" -ForegroundColor Red
            Write-Host "DEBUG: Error Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            Write-Host "DEBUG: Stack Trace:" -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor Red
            throw
        }
    }
    
    HandleInput = {
        param($self, $Key)
        
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow) { 
                $self.State.SelectedQuickAction = [Math]::Max(0, $self.State.SelectedQuickAction - 1)
                Request-TuiRefresh
                return $true 
            }
            ([ConsoleKey]::DownArrow) { 
                $self.State.SelectedQuickAction = [Math]::Min(2, $self.State.SelectedQuickAction + 1)
                Request-TuiRefresh
                return $true 
            }
            ([ConsoleKey]::Q) { return "Quit" }
            ([ConsoleKey]::Escape) { return "Quit" }
        }
        
        return $false
    }
}

Write-Host "`nPushing debug dashboard screen..." -ForegroundColor Yellow
Push-Screen -Screen $debugDashboard

Write-Host "`nStarting TUI loop..." -ForegroundColor Yellow
try {
    Start-TuiLoop
} catch {
    Write-Host "`nFATAL ERROR in TUI loop:" -ForegroundColor Red
    Write-Host $_ -ForegroundColor Red
    Write-Host "`nStack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
