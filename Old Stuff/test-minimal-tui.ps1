# Minimal TUI Engine with Step-by-Step Debugging
# This version adds explicit null checks and debug output at each critical step

Write-Host "Loading minimal TUI engine with debugging..."

$script:TuiState = @{
    Running         = $false
    BufferWidth     = 0
    BufferHeight    = 0
    FrontBuffer     = $null
    BackBuffer      = $null
    ScreenStack     = $null
    CurrentScreen   = $null
    IsDirty         = $true
    InputQueue      = $null
    InputRunspace   = $null
    InputPowerShell = $null
    CancellationTokenSource = $null
}

function Test-TuiInitialization {
    Write-Host "=== STARTING STEP-BY-STEP TUI INITIALIZATION DEBUG ==="
    
    # Step 1: Parameter validation
    Write-Host "Step 1: Parameter validation"
    $Width = [Console]::WindowWidth
    $Height = [Console]::WindowHeight - 1
    Write-Host "  Width: $Width, Height: $Height"
    
    if ($Width -le 0 -or $Height -le 0) { 
        throw "Invalid console dimensions: ${Width}x${Height}" 
    }
    Write-Host "  ✓ Parameters valid"
    
    # Step 2: Initialize basic state
    Write-Host "Step 2: Initialize basic state"
    $script:TuiState.BufferWidth = $Width
    $script:TuiState.BufferHeight = $Height
    Write-Host "  ✓ Dimensions set"
    
    # Step 3: Create buffers
    Write-Host "Step 3: Create buffers"
    $totalCells = $Height * $Width
    Write-Host "  Creating arrays with $totalCells cells"
    
    try {
        $script:TuiState.FrontBuffer = New-Object 'object[]' $totalCells
        Write-Host "  ✓ FrontBuffer created"
    } catch {
        Write-Host "  ✗ FrontBuffer creation failed: $_" -ForegroundColor Red
        throw
    }
    
    try {
        $script:TuiState.BackBuffer = New-Object 'object[]' $totalCells
        Write-Host "  ✓ BackBuffer created"
    } catch {
        Write-Host "  ✗ BackBuffer creation failed: $_" -ForegroundColor Red
        throw
    }
    
    # Step 4: Initialize buffers
    Write-Host "Step 4: Initialize buffer contents"
    try {
        for ($i = 0; $i -lt $totalCells; $i++) {
            $emptyCell = @{ Char = ' '; FG = [ConsoleColor]::White; BG = [ConsoleColor]::Black }
            $script:TuiState.FrontBuffer[$i] = $emptyCell
            $script:TuiState.BackBuffer[$i] = $emptyCell.Clone()
        }
        Write-Host "  ✓ Buffers initialized"
    } catch {
        Write-Host "  ✗ Buffer initialization failed: $_" -ForegroundColor Red
        Write-Host "  Error details: $($_.Exception)"
        throw
    }
    
    # Step 5: Screen stack
    Write-Host "Step 5: Create screen stack"
    try {
        $script:TuiState.ScreenStack = New-Object System.Collections.Stack
        Write-Host "  ✓ Screen stack created"
    } catch {
        Write-Host "  ✗ Screen stack creation failed: $_" -ForegroundColor Red
        throw
    }
    
    # Step 6: Console setup
    Write-Host "Step 6: Console setup"
    try {
        $originalCursor = [Console]::CursorVisible
        Write-Host "  Original cursor visible: $originalCursor"
        [Console]::CursorVisible = $false
        Write-Host "  ✓ Console cursor set to invisible"
    } catch {
        Write-Host "  ✗ Console setup failed: $_" -ForegroundColor Red
        Write-Host "  Error details: $($_.Exception)"
        # Don't throw here, continue with initialization
    }
    
    # Step 7: Input queue
    Write-Host "Step 7: Create input queue"
    try {
        $queueType = [System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]]
        $script:TuiState.InputQueue = New-Object $queueType
        Write-Host "  ✓ ConcurrentQueue created"
    } catch {
        Write-Host "  ⚠ ConcurrentQueue failed, trying ArrayList fallback: $_" -ForegroundColor Yellow
        try {
            $script:TuiState.InputQueue = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
            Write-Host "  ✓ ArrayList fallback created"
        } catch {
            Write-Host "  ✗ ArrayList fallback also failed: $_" -ForegroundColor Red
            throw
        }
    }
    
    # Step 8: Cancellation token
    Write-Host "Step 8: Create cancellation token"
    try {
        $script:TuiState.CancellationTokenSource = [System.Threading.CancellationTokenSource]::new()
        Write-Host "  ✓ CancellationTokenSource created"
    } catch {
        Write-Host "  ✗ CancellationTokenSource creation failed: $_" -ForegroundColor Red
        throw
    }
    
    # Step 9: Runspace
    Write-Host "Step 9: Create runspace"
    try {
        $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        if ($runspace -eq $null) {
            throw "Runspace is null after creation"
        }
        Write-Host "  ✓ Runspace factory returned runspace"
        
        $runspace.Open()
        Write-Host "  ✓ Runspace opened"
        
        $runspace.SessionStateProxy.SetVariable('InputQueue', $script:TuiState.InputQueue)
        Write-Host "  ✓ InputQueue variable set"
        
        $script:TuiState.InputRunspace = $runspace
        Write-Host "  ✓ Runspace stored"
    } catch {
        Write-Host "  ✗ Runspace creation failed: $_" -ForegroundColor Red
        Write-Host "  Error details: $($_.Exception)"
        throw
    }
    
    # Step 10: PowerShell instance
    Write-Host "Step 10: Create PowerShell instance"
    try {
        $ps = [System.Management.Automation.PowerShell]::Create()
        if ($ps -eq $null) {
            throw "PowerShell instance is null after creation"
        }
        Write-Host "  ✓ PowerShell instance created"
        
        $ps.Runspace = $script:TuiState.InputRunspace
        Write-Host "  ✓ Runspace assigned to PowerShell"
        
        $script:TuiState.InputPowerShell = $ps
        Write-Host "  ✓ PowerShell instance stored"
    } catch {
        Write-Host "  ✗ PowerShell instance creation failed: $_" -ForegroundColor Red
        Write-Host "  Error details: $($_.Exception)"
        throw
    }
    
    Write-Host "=== ALL STEPS COMPLETED SUCCESSFULLY ==="
    Write-Host "TuiState summary:"
    Write-Host "  BufferWidth: $($script:TuiState.BufferWidth)"
    Write-Host "  BufferHeight: $($script:TuiState.BufferHeight)"
    Write-Host "  FrontBuffer: $(if ($script:TuiState.FrontBuffer) { 'OK' } else { 'NULL' })"
    Write-Host "  BackBuffer: $(if ($script:TuiState.BackBuffer) { 'OK' } else { 'NULL' })"
    Write-Host "  ScreenStack: $(if ($script:TuiState.ScreenStack) { 'OK' } else { 'NULL' })"
    Write-Host "  InputQueue: $(if ($script:TuiState.InputQueue) { 'OK' } else { 'NULL' })"
    Write-Host "  CancellationTokenSource: $(if ($script:TuiState.CancellationTokenSource) { 'OK' } else { 'NULL' })"
    Write-Host "  InputRunspace: $(if ($script:TuiState.InputRunspace) { 'OK' } else { 'NULL' })"
    Write-Host "  InputPowerShell: $(if ($script:TuiState.InputPowerShell) { 'OK' } else { 'NULL' })"
}

function Cleanup-TestTui {
    Write-Host "Cleaning up test TUI..."
    try {
        if ($script:TuiState.CancellationTokenSource) {
            $script:TuiState.CancellationTokenSource.Cancel()
            $script:TuiState.CancellationTokenSource.Dispose()
        }
        
        if ($script:TuiState.InputPowerShell) {
            $script:TuiState.InputPowerShell.Dispose()
        }
        
        if ($script:TuiState.InputRunspace) {
            $script:TuiState.InputRunspace.Close()
            $script:TuiState.InputRunspace.Dispose()
        }
        
        [Console]::CursorVisible = $true
        Write-Host "Cleanup completed"
    } catch {
        Write-Host "Cleanup error: $_" -ForegroundColor Yellow
    }
}

# Run the test
try {
    Test-TuiInitialization
    Write-Host "`nTest completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "`nTest failed with error: $_" -ForegroundColor Red
    Write-Host "Error details:" -ForegroundColor Red
    $_.Exception | Format-List * -Force
} finally {
    Cleanup-TestTui
}

Write-Host "`nPress any key to continue..."
$null = [Console]::ReadKey($true)
