# Minimal test - just dashboard screen

# Define minimal stubs for required functions
function Write-BufferBox { param($X, $Y, $Width, $Height, $Title, $BorderColor) }
function Write-BufferString { param($X, $Y, $Text, $ForegroundColor, $BackgroundColor) }
function Get-ThemeColor { param($ColorName); return "White" }
function Write-StatusLine { param($Text) }
function Subscribe-Event { param($EventName, $Handler) }
function Request-TuiRefresh { }
function Push-Screen { param($Screen) }
function Get-TimeTrackingMenuScreen { return @{} }
function Get-ProjectManagementScreen { return @{} }
function Get-TaskManagementScreen { return @{} }
function Get-ReportsMenuScreen { return @{} }
function Get-SettingsScreen { return @{} }

# Define minimal state
$script:TuiState = @{
    BufferWidth = 80
    BufferHeight = 24
}

$script:Data = @{
    ActiveTimer = $null
    Projects = @{
        "PROJ001" = @{ Name = "Test Project" }
    }
    Tasks = @()
    TimeEntries = @()
}

# Now try to load the dashboard screen
Write-Host "Loading dashboard screen module..." -ForegroundColor Cyan

try {
    # Read and execute the dashboard screen code directly
    $dashboardCode = Get-Content ".\screens\dashboard-screen.psm1" -Raw
    
    # Check for obvious syntax issues
    Write-Host "Checking for common issues..." -ForegroundColor Yellow
    
    # Look for duplicate closing braces or other issues
    $braceCount = ($dashboardCode.ToCharArray() | Where-Object { $_ -eq '{' }).Count
    $closeBraceCount = ($dashboardCode.ToCharArray() | Where-Object { $_ -eq '}' }).Count
    
    Write-Host "Opening braces: $braceCount" -ForegroundColor Gray
    Write-Host "Closing braces: $closeBraceCount" -ForegroundColor Gray
    
    if ($braceCount -ne $closeBraceCount) {
        Write-Host "✗ Brace mismatch detected!" -ForegroundColor Red
    }
    
    # Try to execute
    Invoke-Expression $dashboardCode
    
    if (Get-Command Get-DashboardScreen -ErrorAction SilentlyContinue) {
        Write-Host "✓ Get-DashboardScreen loaded successfully" -ForegroundColor Green
        
        $screen = Get-DashboardScreen
        Write-Host "✓ Screen created successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Get-DashboardScreen not found after loading" -ForegroundColor Red
    }
    
} catch {
    Write-Host "✗ Error: $_" -ForegroundColor Red
    Write-Host "At line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
}

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
