# Test script to verify fixes
Write-Host "Testing TUI Framework Fixes..." -ForegroundColor Cyan

# Test 1: Dashboard RefreshData method
Write-Host "`nTest 1: Testing dashboard RefreshData method" -ForegroundColor Yellow
$dashboard = Get-DashboardScreen
if ($dashboard.RefreshData) {
    Write-Host "  ✓ RefreshData method exists" -ForegroundColor Green
    try {
        & $dashboard.RefreshData -screen $dashboard
        Write-Host "  ✓ RefreshData executes without error" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ RefreshData error: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  ✗ RefreshData method not found" -ForegroundColor Red
}

# Test 2: Task screen methods
Write-Host "`nTest 2: Testing task screen methods" -ForegroundColor Yellow
$taskScreen = Get-TaskManagementScreen
$methods = @('GetFilteredTasks', 'RefreshTaskTable', 'ShowAddTaskForm', 'SaveTask', 'HideForm')
foreach ($method in $methods) {
    if ($taskScreen.$method) {
        Write-Host "  ✓ $method method exists" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $method method not found" -ForegroundColor Red
    }
}

# Test 3: JSON serialization depth
Write-Host "`nTest 3: Testing JSON serialization depth" -ForegroundColor Yellow
$testData = @{
    Level1 = @{
        Level2 = @{
            Level3 = @{
                Level4 = @{
                    Level5 = @{
                        Value = "Deep nested value"
                    }
                }
            }
        }
    }
}

try {
    $json = $testData | ConvertTo-Json -Depth 20 -WarningAction SilentlyContinue
    $parsed = $json | ConvertFrom-Json -AsHashtable -Depth 20
    
    if ($parsed.Level1.Level2.Level3.Level4.Level5.Value -eq "Deep nested value") {
        Write-Host "  ✓ Deep JSON serialization works correctly" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Deep JSON serialization failed" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ JSON test error: $_" -ForegroundColor Red
}

Write-Host "`nAll tests completed!" -ForegroundColor Cyan