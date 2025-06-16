# Test script to check logger functionality
# Run this from the project root directory

# Set the base path
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import the logger module directly
Write-Host "Testing Logger Module..." -ForegroundColor Cyan
$loggerPath = Join-Path $scriptPath "modules\logger.psm1"

if (Test-Path $loggerPath) {
    Write-Host "Logger module found at: $loggerPath" -ForegroundColor Green
    Import-Module $loggerPath -Force
    
    # Initialize logger
    Initialize-Logger
    
    # Write some test logs
    Write-Log -Level Info -Message "Test log entry - Info level"
    Write-Log -Level Warning -Message "Test log entry - Warning level"
    Write-Log -Level Error -Message "Test log entry - Error level"
    
    # Try to create an error
    try {
        throw "This is a test error"
    } catch {
        Write-Log -Level Error -Message "Caught test error" -Data $_
    }
    
    # Get log file path and display it
    $logPath = Get-LogFilePath
    Write-Host "`nLog file location: $logPath" -ForegroundColor Yellow
    
    # Check if log file exists
    if (Test-Path $logPath) {
        Write-Host "Log file exists!" -ForegroundColor Green
        Write-Host "`nLast 10 lines of log file:" -ForegroundColor Cyan
        Get-Content $logPath -Tail 10 | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    } else {
        Write-Host "Log file does not exist!" -ForegroundColor Red
    }
    
    # Test retrieving logs
    Write-Host "`nRetrieving last 5 log entries:" -ForegroundColor Cyan
    $logs = Get-Logs -Count 5
    $logs | ForEach-Object {
        Write-Host "[$($_.Timestamp)] [$($_.Level)] $($_.Message)" -ForegroundColor Gray
    }
    
} else {
    Write-Host "Logger module not found!" -ForegroundColor Red
}

Write-Host "`nLogger test complete." -ForegroundColor Green
Write-Host "You can now check the log file at the location shown above." -ForegroundColor Yellow