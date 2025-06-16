# Isolated TUI Engine Test - Find the exact failure point

Write-Host "Starting isolated TUI test..."

# Test 1: Basic console operations
Write-Host "Test 1: Basic console operations"
try {
    Write-Host "Console Width: $([Console]::WindowWidth)"
    Write-Host "Console Height: $([Console]::WindowHeight)"
    Write-Host "✓ Console dimension access works"
} catch {
    Write-Host "✗ Console access failed: $_" -ForegroundColor Red
    exit 1
}

# Test 2: Array creation
Write-Host "Test 2: Array creation"
try {
    $width = 120
    $height = 29
    $totalCells = $height * $width
    $testBuffer = New-Object 'object[]' $totalCells
    Write-Host "✓ Array creation works (size: $totalCells)"
} catch {
    Write-Host "✗ Array creation failed: $_" -ForegroundColor Red
    exit 1
}

# Test 3: ConcurrentQueue creation
Write-Host "Test 3: ConcurrentQueue creation"
try {
    $queueType = [System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]]
    $testQueue = New-Object $queueType
    Write-Host "✓ ConcurrentQueue creation works"
} catch {
    Write-Host "✗ ConcurrentQueue creation failed: $_" -ForegroundColor Red
    Write-Host "Trying fallback ArrayList..."
    try {
        $testList = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
        Write-Host "✓ ArrayList fallback works"
    } catch {
        Write-Host "✗ ArrayList fallback also failed: $_" -ForegroundColor Red
        exit 1
    }
}

# Test 4: Runspace creation
Write-Host "Test 4: Runspace creation"
try {
    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $runspace.Open()
    Write-Host "✓ Runspace creation works"
    $runspace.Close()
    $runspace.Dispose()
} catch {
    Write-Host "✗ Runspace creation failed: $_" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception)"
}

# Test 5: Console manipulation
Write-Host "Test 5: Console manipulation"
try {
    $originalCursor = [Console]::CursorVisible
    [Console]::CursorVisible = $false
    [Console]::CursorVisible = $originalCursor
    Write-Host "✓ Console cursor manipulation works"
} catch {
    Write-Host "✗ Console manipulation failed: $_" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception)"
}

# Test 6: CancellationTokenSource
Write-Host "Test 6: CancellationTokenSource"
try {
    $cts = [System.Threading.CancellationTokenSource]::new()
    $token = $cts.Token
    $cts.Dispose()
    Write-Host "✓ CancellationTokenSource works"
} catch {
    Write-Host "✗ CancellationTokenSource failed: $_" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception)"
}

# Test 7: Stack creation
Write-Host "Test 7: Stack creation"
try {
    $stack = New-Object System.Collections.Stack
    $stack.Push("test")
    $item = $stack.Pop()
    Write-Host "✓ Stack creation works"
} catch {
    Write-Host "✗ Stack creation failed: $_" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception)"
}

Write-Host "All tests completed. If all passed, the issue is in the integration."
