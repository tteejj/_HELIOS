# Comprehensive Debug Wrapper for PMC Terminal
# This will wrap EVERY function call to find the exact source of the error

$global:DebugCallStack = @()
$global:DebugOutput = @()
$global:ErrorFound = $false

# Function to wrap other functions with debugging
function Wrap-FunctionWithDebug {
    param(
        [string]$FunctionName,
        [scriptblock]$OriginalFunction
    )
    
    $wrappedFunction = {
        param($self, $Key)
        
        $global:DebugCallStack += $FunctionName
        $callDepth = $global:DebugCallStack.Count
        $indent = "  " * $callDepth
        
        Write-Host "${indent}>>> ENTERING: $FunctionName" -ForegroundColor DarkGray
        
        try {
            # Store parameters for debugging
            $paramInfo = @{
                FunctionName = $FunctionName
                CallDepth = $callDepth
                Timestamp = Get-Date -Format "HH:mm:ss.fff"
            }
            
            if ($self) {
                $paramInfo.SelfType = $self.Type
                $paramInfo.SelfName = $self.Name
            }
            
            if ($Key) {
                $paramInfo.KeyInfo = $Key.Key
            }
            
            # Call the original function
            $result = & $OriginalFunction @PSBoundParameters
            
            Write-Host "${indent}<<< EXITING: $FunctionName (Success)" -ForegroundColor DarkGreen
            
            return $result
        }
        catch {
            $global:ErrorFound = $true
            Write-Host "${indent}!!! ERROR IN: $FunctionName" -ForegroundColor Red -BackgroundColor Black
            Write-Host "${indent}!!! Error: $_" -ForegroundColor Red
            Write-Host "${indent}!!! Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            Write-Host "${indent}!!! Stack at error:" -ForegroundColor Red
            
            # Print the entire call stack at the point of error
            for ($i = 0; $i -lt $global:DebugCallStack.Count; $i++) {
                Write-Host "$("  " * ($i + 1))- $($global:DebugCallStack[$i])" -ForegroundColor Yellow
            }
            
            # Print script stack trace
            Write-Host "${indent}!!! Script Stack Trace:" -ForegroundColor Red
            $_.ScriptStackTrace -split "`n" | ForEach-Object {
                Write-Host "${indent}    $_" -ForegroundColor Red
            }
            
            throw
        }
        finally {
            # Remove from call stack
            if ($global:DebugCallStack.Count -gt 0) {
                $global:DebugCallStack = @($global:DebugCallStack[0..($global:DebugCallStack.Count - 2)])
            }
        }
    }.GetNewClosure()
    
    return $wrappedFunction
}

# Load all modules with extensive debugging
Write-Host "=== STARTING DEBUG WRAPPER ===" -ForegroundColor Cyan

$script:BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Function to safely execute code blocks and catch syntax errors
function Safe-Execute {
    param(
        [string]$Description,
        [scriptblock]$Code
    )
    
    Write-Host "`n### $Description ###" -ForegroundColor Yellow
    try {
        & $Code
        Write-Host "### $Description - SUCCESS ###" -ForegroundColor Green
    }
    catch {
        Write-Host "### $Description - FAILED ###" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        Write-Host "Full Error:" -ForegroundColor Red
        $_ | Format-List * -Force
        
        if ($_.Exception.InnerException) {
            Write-Host "Inner Exception:" -ForegroundColor Red
            $_.Exception.InnerException | Format-List * -Force
        }
        
        throw
    }
}

# Load modules one by one with debugging
Safe-Execute "Loading event-system" {
    Import-Module (Join-Path $script:BasePath "modules\event-system.psm1") -Force -Global
}

Safe-Execute "Loading data-manager" {
    Import-Module (Join-Path $script:BasePath "modules\data-manager.psm1") -Force -Global
}

Safe-Execute "Loading theme-manager" {
    Import-Module (Join-Path $script:BasePath "modules\theme-manager.psm1") -Force -Global
}

Safe-Execute "Loading tui-engine-v2" {
    Import-Module (Join-Path $script:BasePath "modules\tui-engine-v2.psm1") -Force -Global
}

Safe-Execute "Loading dialog-system" {
    Import-Module (Join-Path $script:BasePath "modules\dialog-system.psm1") -Force -Global
}

Safe-Execute "Loading tui-components" {
    Import-Module (Join-Path $script:BasePath "components\tui-components.psm1") -Force -Global
}

Safe-Execute "Loading dashboard-screen" {
    Import-Module (Join-Path $script:BasePath "screens\dashboard-screen.psm1") -Force -Global
}

# Initialize systems
Safe-Execute "Initialize-EventSystem" {
    Initialize-EventSystem
}

Safe-Execute "Initialize-ThemeManager" {
    Initialize-ThemeManager
}

Safe-Execute "Initialize-DataManager" {
    Initialize-DataManager
}

Safe-Execute "Initialize-TuiEngine" {
    Initialize-TuiEngine
}

Safe-Execute "Initialize-DialogSystem" {
    Initialize-DialogSystem
}

# Now let's wrap the dashboard render function to catch the error
Write-Host "`n### Wrapping Dashboard Render Function ###" -ForegroundColor Cyan

$dashboardScreen = Get-DashboardScreen

if ($dashboardScreen.Render) {
    $originalRender = $dashboardScreen.Render
    $dashboardScreen.Render = {
        param($self)
        
        Write-Host "`n=== DASHBOARD RENDER START ===" -ForegroundColor Magenta
        Write-Host "Self Type: $($self.Type)" -ForegroundColor Cyan
        Write-Host "Self Name: $($self.Name)" -ForegroundColor Cyan
        
        try {
            # Let's trace each line of the render
            Write-Host "Step 1: Writing header..." -ForegroundColor Gray
            Write-BufferString -X 2 -Y 1 -Text "PMC Terminal Dashboard - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor "Cyan"
            Write-Host "Step 1: SUCCESS" -ForegroundColor Green
            
            Write-Host "Step 2: Drawing box..." -ForegroundColor Gray
            Write-BufferBox -X 2 -Y 3 -Width 40 -Height 10 -Title " Quick Actions " -BorderColor "Yellow"
            Write-Host "Step 2: SUCCESS" -ForegroundColor Green
            
            Write-Host "Step 3: Creating menu items..." -ForegroundColor Gray
            $actions = @("1. Add Time Entry", "2. Start Timer", "3. Manage Tasks", "4. Manage Projects", "5. View Reports", "6. Settings")
            Write-Host "Actions array created with $($actions.Count) items" -ForegroundColor Gray
            
            $y = 5
            Write-Host "Step 4: Drawing menu items..." -ForegroundColor Gray
            foreach ($i in 0..($actions.Count - 1)) {
                Write-Host "  Drawing item $i at Y=$y" -ForegroundColor DarkGray
                
                $isSelected = $i -eq $self.State.SelectedQuickAction
                Write-Host "  isSelected = $isSelected" -ForegroundColor DarkGray
                
                # Explicitly build the values
                $text = "  " + $actions[$i]
                $color = "White"
                
                if ($isSelected) {
                    Write-Host "  Item is selected, updating format" -ForegroundColor DarkGray
                    $text = "→ " + $actions[$i]
                    $color = "Yellow"
                }
                
                Write-Host "  Final text: '$text', color: $color" -ForegroundColor DarkGray
                
                try {
                    Write-BufferString -X 4 -Y $y -Text $text -ForegroundColor $color
                    Write-Host "  Item $i drawn successfully" -ForegroundColor DarkGreen
                }
                catch {
                    Write-Host "  ERROR drawing item $i: $_" -ForegroundColor Red
                    throw
                }
                
                $y++
            }
            Write-Host "Step 4: SUCCESS" -ForegroundColor Green
            
            Write-Host "Step 5: Writing instructions..." -ForegroundColor Gray
            Write-BufferString -X 2 -Y 20 -Text "↑↓ Navigate • Enter: Select • Q: Quit" -ForegroundColor "Gray"
            Write-Host "Step 5: SUCCESS" -ForegroundColor Green
            
            Write-Host "=== DASHBOARD RENDER END ===" -ForegroundColor Magenta
        }
        catch {
            Write-Host "=== DASHBOARD RENDER ERROR ===" -ForegroundColor Red -BackgroundColor Black
            Write-Host "Error at line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
            Write-Host "Statement: $($_.InvocationInfo.Line)" -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Red
            Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            throw
        }
    }
}

# Push the screen
Write-Host "`n### Pushing Dashboard Screen ###" -ForegroundColor Cyan
try {
    Push-Screen -Screen $dashboardScreen
    Write-Host "Screen pushed successfully" -ForegroundColor Green
}
catch {
    Write-Host "ERROR pushing screen: $_" -ForegroundColor Red
}

# Try to render once manually
Write-Host "`n### Manual Render Test ###" -ForegroundColor Cyan
try {
    & $dashboardScreen.Render -self $dashboardScreen
    Write-Host "Manual render succeeded!" -ForegroundColor Green
}
catch {
    Write-Host "Manual render failed: $_" -ForegroundColor Red
    Write-Host "Full exception:" -ForegroundColor Red
    $_ | Format-List * -Force
}

Write-Host "`n### Starting TUI Loop ###" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to exit if the loop hangs" -ForegroundColor Yellow

try {
    Start-TuiLoop
}
catch {
    Write-Host "`nTUI Loop error: $_" -ForegroundColor Red
}

Write-Host "`n=== DEBUG SESSION COMPLETE ===" -ForegroundColor Cyan
Write-Host "Press any key to exit..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
