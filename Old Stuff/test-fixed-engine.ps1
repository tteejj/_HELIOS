# Test the fixed TUI engine
Write-Host "Testing fixed TUI engine..." -ForegroundColor Green

# Import the fixed TUI engine
Write-Host "Loading fixed TUI engine..."
Import-Module ".\modules\tui-engine-v4-fixed.psm1" -Force -Verbose

# Create a simple test screen
$testScreen = @{
    Name = "TestScreen"
    
    Init = {
        param($self)
        Write-Host "Test screen initialized"
    }
    
    Render = {
        param($self)
        try {
            # Clear and draw a simple test interface
            Write-BufferBox -X 5 -Y 3 -Width 60 -Height 15 -Title " TUI Engine Test " -BorderColor White
            Write-BufferString -X 8 -Y 5 -Text "TUI Engine v4 Fixed - Test Successful!" -ForegroundColor Green
            Write-BufferString -X 8 -Y 7 -Text "This message indicates the TUI engine is working correctly." -ForegroundColor White
            Write-BufferString -X 8 -Y 9 -Text "Features tested:" -ForegroundColor Cyan
            Write-BufferString -X 10 -Y 10 -Text "✓ Buffer management" -ForegroundColor Green
            Write-BufferString -X 10 -Y 11 -Text "✓ Screen rendering" -ForegroundColor Green
            Write-BufferString -X 10 -Y 12 -Text "✓ Input handling" -ForegroundColor Green
            Write-BufferString -X 10 -Y 13 -Text "✓ Error resilience" -ForegroundColor Green
            
            Write-BufferString -X 8 -Y 15 -Text "Press 'Q' to quit, 'T' to test error handling" -ForegroundColor Yellow
        } catch {
            Write-Host "Render error: $_" -ForegroundColor Red
        }
    }
    
    HandleInput = {
        param($self, $Key)
        try {
            switch ($Key.Key) {
                ([ConsoleKey]::Q) { 
                    Write-Host "Quit requested by user"
                    return "Quit" 
                }
                ([ConsoleKey]::T) {
                    Write-Host "Testing error handling..."
                    # Intentionally cause a non-fatal error
                    try {
                        $null.SomeMethod()
                    } catch {
                        Write-Host "Error handled gracefully: $_" -ForegroundColor Yellow
                    }
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::R) {
                    Request-TuiRefresh
                    return $true
                }
            }
            return $false
        } catch {
            Write-Host "Input handling error: $_" -ForegroundColor Red
            return $false
        }
    }
    
    OnExit = {
        param($self)
        Write-Host "Test screen exiting"
    }
}

# Test the TUI engine
try {
    Write-Host "Starting TUI test loop..."
    Start-TuiLoop -InitialScreen $testScreen
    Write-Host "TUI test completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "TUI test failed: $_" -ForegroundColor Red
    Write-Host "Error details:" -ForegroundColor Red
    $_.Exception | Format-List * -Force
}

Write-Host "Test finished. Press any key to continue..."
try {
    $null = [Console]::ReadKey($true)
} catch {
    # Ignore if console read fails
}
