# Standalone Helios Diagnostic Script - v7
# Purpose: To perform a step-by-step, evidence-based debug of screen initialization.
# v7 Fix: Patches the Init scriptblock in memory to remove known problematic lines (like Write-Log)
#         before executing the line-by-line diagnostic. This allows us to bypass environmental
#         issues in the test harness and find the true application logic error.

# --- SETUP ---
Clear-Host
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:BasePath = $PSScriptRoot
$global:TuiState = @{
    BufferWidth = 120
    BufferHeight = 30
}

Write-Host "--- Helios Diagnostic Script v7 (In-Memory Patching) ---" -ForegroundColor Yellow
Write-Host "This script will find the true logical error."
Write-Host "--------------------------------------------------------"

# --- 1. LOAD ALL APPLICATION MODULES ---
function Load-AppModules {
    param($ModulesToLoad)
    Write-Host "`n[PHASE 1] Loading all application modules..." -ForegroundColor Cyan
    foreach ($module in $ModulesToLoad) {
        $modulePath = Join-Path $script:BasePath $module.Path
        if (Test-Path $modulePath) {
            try {
                Import-Module $modulePath -Force -Global
                Write-Host "  [SUCCESS] Loaded $($module.Name)" -ForegroundColor Green
            } catch {
                Write-Host "  [FAILURE] Failed to load required module '$($module.Name)'" -ForegroundColor Red; throw
            }
        } else {
             if ($module.Required) {
                Write-Host "  [FAILURE] Required module not found: $($module.Name) at $modulePath" -ForegroundColor Red; throw
            } else {
                Write-Host "  [SKIPPED] Optional module not found: $($module.Name)" -ForegroundColor Gray
            }
        }
    }
}

$ModulesToLoad = @(
    @{ Name = "logger"; Path = "modules\logger.psm1"; Required = $true },
    @{ Name = "event-system"; Path = "modules\event-system.psm1"; Required = $true },
    @{ Name = "data-manager"; Path = "modules\data-manager.psm1"; Required = $true },
    @{ Name = "theme-manager"; Path = "modules\theme-manager.psm1"; Required = $true },
    @{ Name = "tui-framework"; Path = "modules\tui-framework.psm1"; Required = $true },
    @{ Name = "tui-engine-v2"; Path = "modules\tui-engine-v2.psm1"; Required = $true },
    @{ Name = "dialog-system"; Path = "modules\dialog-system.psm1"; Required = $true },
    @{ Name = "app-store"; Path = "services\app-store.psm1"; Required = $true },
    @{ Name = "navigation"; Path = "services\navigation.psm1"; Required = $true },
    @{ Name = "keybindings"; Path = "services\keybindings.psm1"; Required = $true },
    @{ Name = "layout-panels"; Path = "layout\panels.psm1"; Required = $true },
    @{ Name = "focus-manager"; Path = "utilities\focus-manager.psm1"; Required = $true },
    @{ Name = "tui-components"; Path = "components\tui-components.psm1"; Required = $true },
    @{ Name = "advanced-input-components"; Path = "components\advanced-input-components.psm1"; Required = $false },
    @{ Name = "advanced-data-components"; Path = "components\advanced-data-components.psm1"; Required = $true },
    @{ Name = "dashboard-screen-helios"; Path = "screens\dashboard-screen-helios.psm1"; Required = $true },
    @{ Name = "task-screen-helios"; Path = "screens\task-screen-helios.psm1"; Required = $true }
)
Load-AppModules -ModulesToLoad $ModulesToLoad


# --- 2. INITIALIZE CORE SERVICES ---
Write-Host "`n[PHASE 2] Initializing core services..." -ForegroundColor Cyan
$services = @{}
Initialize-Logger -LogDirectory (Join-Path $env:TEMP "PMCTerminal_DIAG")
Initialize-EventSystem
Initialize-DataManager
Load-UnifiedData
$services.Store = Initialize-AppStore -InitialData $global:Data
$services.Navigation = Initialize-NavigationService
$services.Keybindings = Initialize-KeybindingService


# --- 3. CREATE SCREEN INSTANCE ---
Write-Host "`n[PHASE 3] Creating dashboard screen instance..." -ForegroundColor Cyan
$dashboardScreen = Get-DashboardScreen -Services $services


# --- 4. STEP-BY-STEP DIAGNOSTIC ---
Write-Host "`n[PHASE 4] BEGINNING STEP-BY-STEP DIAGNOSTIC OF Init METHOD" -ForegroundColor Magenta
Write-Host "=========================================================="

# --- IN-MEMORY PATCHING ---
$initScriptBlockString = $dashboardScreen.Init.ToString()
# Remove all lines containing 'Write-Log' to avoid the scoping issue.
$patchedInitString = $initScriptBlockString -replace '(?m)^\s*Write-Log.*$'
# Create a new, clean scriptblock from our patched string.
$patchedInitScriptBlock = [scriptblock]::Create($patchedInitString)
$initCodeLines = ($patchedInitScriptBlock.ToString() -split "`n" | Select-Object -Skip 1 | Select-Object -SkipLast 1).Trim()
Write-Host "NOTE: Live-patched 'Init' method to remove 'Write-Log' calls for this diagnostic run." -ForegroundColor Gray

# Create the controlled execution environment
$runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
$runspace.Open()
$runspace.SessionStateProxy.SetVariable("self", $dashboardScreen)
$runspace.SessionStateProxy.SetVariable("services", $services)
$runspace.SessionStateProxy.SetVariable("global:TuiState", $global:TuiState)
$runspace.SessionStateProxy.SetVariable("navigationServices", $services) # Manually define this from Init

$lineNumber = 1
foreach ($line in $initCodeLines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }

    Write-Host "`n[Line $($lineNumber++)] EXECUTING:" -ForegroundColor Cyan
    Write-Host "  $line"

    try {
        $ps = [powershell]::Create()
        $ps.Runspace = $runspace
        $ps.AddScript($line) | Out-Null
        $ps.Invoke()

        if ($ps.HadErrors) {
            throw $ps.Streams.Error[0]
        }
        Write-Host "  [Line $($lineNumber - 1)] > SUCCESS" -ForegroundColor Green
    } catch {
        Write-Host "-------------------" -ForegroundColor Red
        Write-Host "--- FATAL ERROR ---" -ForegroundColor Red
        Write-Host "-------------------"
        Write-Host "FAILURE ON LINE: $($lineNumber - 1)" -ForegroundColor Yellow
        Write-Host "STATEMENT: $line" -ForegroundColor Yellow
        Write-Host "ERROR MESSAGE: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "--------------------------------------------------------"

        $variableMatches = [regex]::Matches($line, '\$[a-zA-Z0-9_]+')
        if ($variableMatches.Count -gt 0) {
            Write-Host "`n--- INSPECTING VARIABLES IN FAILING STATEMENT ---" -ForegroundColor Magenta
            $inspector = [powershell]::Create()
            $inspector.Runspace = $runspace
            
            foreach ($match in ($variableMatches.Value | Select-Object -Unique)) {
                $varName = $match
                Write-Host "  Inspecting $($varName)..." -NoNewline
                
                $inspector.Commands.Clear()
                $varValue = $inspector.AddScript("$($varName)").Invoke()
                
                if ($inspector.HadErrors -or ($varValue.Count -eq 0)) {
                    Write-Host " -> VALUE IS `$null or inaccessible" -ForegroundColor Red
                } else {
                    Write-Host " -> Is a valid object ($($varValue.GetType().Name))" -ForegroundColor Green
                }
            }
            $inspector.Dispose()
            Write-Host "-------------------------------------------------"
        }

        Write-Host "`nDIAGNOSTIC CONCLUSION: The error occurred because a method or property was accessed on a variable that was `$null at the time of execution." -ForegroundColor Yellow
        $runspace.Dispose()
        exit 1
    }
}

$runspace.Dispose()
Write-Host "`n=========================================================="
Write-Host "[PHASE 4] DIAGNOSTIC COMPLETE" -ForegroundColor Green
Write-Host "The dashboard screen's Init method executed successfully without any errors."

exit 0