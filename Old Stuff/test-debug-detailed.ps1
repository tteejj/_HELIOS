# Detailed Debug Script - Pinpoint the Null Method Call Error
# This will identify EXACTLY which line in Initialize-TuiEngine causes the error

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$script:BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path

function Test-NullSafeCall {
    param(
        [string]$Description,
        [scriptblock]$ScriptBlock
    )
    
    Write-Host "DEBUG: About to execute: $Description" -ForegroundColor Cyan
    try {
        $result = & $ScriptBlock
        Write-Host "DEBUG: SUCCESS: $Description" -ForegroundColor Green
        return $result
    } catch {
        Write-Host "DEBUG: FAILED: $Description" -ForegroundColor Red
        Write-Host "DEBUG: Error: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "DEBUG: Error Type: $($_.Exception.GetType().FullName)" -ForegroundColor Yellow
        if ($_.Exception.InnerException) {
            Write-Host "DEBUG: Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Yellow
        }
        throw
    }
}

function Load-RequiredModules {
    Write-Host "Loading required modules for testing..." -ForegroundColor Cyan
    
    $modules = @(
        "modules\event-system.psm1",
        "modules\data-manager.psm1",
        "modules\theme-manager.psm1"
    )
    
    foreach ($modulePath in $modules) {
        $fullPath = Join-Path $script:BasePath $modulePath
        Test-NullSafeCall "Loading module: $modulePath" {
            Import-Module $fullPath -Force -Global
        }
    }
    
    # Initialize required systems
    Test-NullSafeCall "Initialize-EventSystem" { Initialize-EventSystem }
    Test-NullSafeCall "Initialize-ThemeManager" { Initialize-ThemeManager }
    Test-NullSafeCall "Initialize-DataManager" { Initialize-DataManager }
}

function Test-TuiEngineInitialization {
    Write-Host "`n=== Testing TUI Engine Initialization Step by Step ===" -ForegroundColor Yellow
    
    # Load TUI Engine module
    $tuiEnginePath = Join-Path $script:BasePath "modules\tui-engine-v2.psm1"
    Test-NullSafeCall "Loading TUI Engine module" {
        Import-Module $tuiEnginePath -Force -Global
    }
    
    # Test console dimensions
    Test-NullSafeCall "Getting console dimensions" {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        Write-Host "DEBUG: Console dimensions: ${width}x${height}"
        if ($width -le 0 -or $height -le 0) {
            throw "Invalid console dimensions: ${width}x${height}"
        }
        return @{ Width = $width; Height = $height }
    }
    
    # Test buffer creation
    Test-NullSafeCall "Creating front buffer" {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight - 1
        $totalCells = $height * $width
        Write-Host "DEBUG: Creating buffer with $totalCells cells (${width}x${height})"
        $frontBuffer = New-Object 'object[]' $totalCells
        if ($null -eq $frontBuffer) {
            throw "Failed to create front buffer"
        }
        Write-Host "DEBUG: Front buffer created successfully, length: $($frontBuffer.Length)"
        return $frontBuffer
    }
    
    Test-NullSafeCall "Creating back buffer" {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight - 1
        $totalCells = $height * $width
        $backBuffer = New-Object 'object[]' $totalCells
        if ($null -eq $backBuffer) {
            throw "Failed to create back buffer"
        }
        Write-Host "DEBUG: Back buffer created successfully, length: $($backBuffer.Length)"
        return $backBuffer
    }
    
    # Test console settings
    Test-NullSafeCall "Setting console cursor visibility" {
        [Console]::CursorVisible = $false
        Write-Host "DEBUG: Console cursor visibility set to false"
    }
    
    # Test layout engines initialization
    Test-NullSafeCall "Initialize-LayoutEngines call" {
        if (Get-Command -Name "Initialize-LayoutEngines" -ErrorAction SilentlyContinue) {
            Initialize-LayoutEngines
        } else {
            Write-Host "DEBUG: Initialize-LayoutEngines function not found, skipping"
        }
    }
    
    # Test component system initialization  
    Test-NullSafeCall "Initialize-ComponentSystem call" {
        if (Get-Command -Name "Initialize-ComponentSystem" -ErrorAction SilentlyContinue) {
            Initialize-ComponentSystem
        } else {
            Write-Host "DEBUG: Initialize-ComponentSystem function not found, skipping"
        }
    }
    
    # Test Ctrl+C handler setup
    Test-NullSafeCall "Setting up Ctrl+C handler" {
        [Console]::TreatControlCAsInput = $false
        Write-Host "DEBUG: TreatControlCAsInput set to false"
        # Don't actually add the handler in test mode
        Write-Host "DEBUG: Ctrl+C handler setup completed (test mode)"
    }
    
    # Test input thread components step by step
    Test-NullSafeCall "Creating ConcurrentQueue" {
        $queueType = [System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]]
        Write-Host "DEBUG: Queue type: $($queueType.FullName)"
        $queue = New-Object $queueType
        if ($null -eq $queue) {
            throw "Failed to create ConcurrentQueue"
        }
        Write-Host "DEBUG: ConcurrentQueue created successfully: $($queue.GetType().FullName)"
        return $queue
    }
    
    Test-NullSafeCall "Creating CancellationTokenSource" {
        $cancellationTokenSource = [System.Threading.CancellationTokenSource]::new()
        if ($null -eq $cancellationTokenSource) {
            throw "Failed to create CancellationTokenSource"
        }
        Write-Host "DEBUG: CancellationTokenSource created successfully"
        $token = $cancellationTokenSource.Token
        if ($null -eq $token) {
            throw "Failed to get cancellation token"
        }
        Write-Host "DEBUG: Cancellation token obtained successfully"
        return @{ Source = $cancellationTokenSource; Token = $token }
    }
    
    Test-NullSafeCall "Creating Runspace" {
        $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        if ($null -eq $runspace) {
            throw "RunspaceFactory.CreateRunspace() returned null"
        }
        Write-Host "DEBUG: Runspace created successfully: $($runspace.GetType().FullName)"
        return $runspace
    }
    
    Test-NullSafeCall "Opening Runspace" {
        $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $runspace.Open()
        Write-Host "DEBUG: Runspace opened successfully, state: $($runspace.RunspaceStateInfo.State)"
        return $runspace
    }
    
    Test-NullSafeCall "Testing SessionStateProxy" {
        $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $runspace.Open()
        $sessionStateProxy = $runspace.SessionStateProxy
        if ($null -eq $sessionStateProxy) {
            throw "SessionStateProxy is null"
        }
        Write-Host "DEBUG: SessionStateProxy obtained successfully: $($sessionStateProxy.GetType().FullName)"
        return $sessionStateProxy
    }
    
    Test-NullSafeCall "Testing SetVariable on SessionStateProxy" {
        $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $runspace.Open()
        $queueType = [System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]]
        $queue = New-Object $queueType
        $runspace.SessionStateProxy.SetVariable('InputQueue', $queue)
        Write-Host "DEBUG: SetVariable on SessionStateProxy successful"
        $runspace.Close()
        $runspace.Dispose()
    }
    
    Test-NullSafeCall "Creating PowerShell instance" {
        $ps = [System.Management.Automation.PowerShell]::Create()
        if ($null -eq $ps) {
            throw "PowerShell.Create() returned null"
        }
        Write-Host "DEBUG: PowerShell instance created successfully: $($ps.GetType().FullName)"
        $ps.Dispose()
        return $true
    }
    
    Test-NullSafeCall "Full PowerShell setup" {
        $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $runspace.Open()
        
        $ps = [System.Management.Automation.PowerShell]::Create()
        $ps.Runspace = $runspace
        
        if ($null -eq $ps.Runspace) {
            throw "PowerShell.Runspace assignment failed"
        }
        
        Write-Host "DEBUG: PowerShell runspace assignment successful"
        
        # Test AddScript
        $scriptResult = $ps.AddScript({ Write-Host "Test script" })
        if ($null -eq $scriptResult) {
            throw "AddScript returned null"
        }
        
        Write-Host "DEBUG: AddScript successful"
        
        $ps.Dispose()
        $runspace.Close()
        $runspace.Dispose()
        return $true
    }
    
    Write-Host "`n=== All Individual Tests Completed Successfully ===" -ForegroundColor Green
}

# Main execution
try {
    Clear-Host
    Write-Host "=== PMC Terminal TUI Engine Debug Test ===" -ForegroundColor Yellow
    Write-Host "This will test each step of TUI Engine initialization individually`n" -ForegroundColor Gray
    
    Load-RequiredModules
    Test-TuiEngineInitialization
    
    Write-Host "`n=== SUCCESS: All tests passed! ===" -ForegroundColor Green
    Write-Host "The error is likely elsewhere in the initialization chain." -ForegroundColor Yellow
    Write-Host "Try running the actual application with more targeted debugging." -ForegroundColor Gray
    
} catch {
    Write-Host "`n=== FAILURE: Found the problematic step! ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "This is likely the source of your null method call error." -ForegroundColor Red
    
    Write-Host "`nFull Exception Details:" -ForegroundColor Yellow
    $_.Exception | Format-List * -Force
    
} finally {
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
