# Task Management Application
# Main entry point

# Import required modules
$modulePath = Join-Path $PSScriptRoot "modules"
Import-Module (Join-Path $modulePath "tui-engine-v2.psm1") -Force
Import-Module (Join-Path $modulePath "tui-framework.psm1") -Force
Import-Module (Join-Path $modulePath "tui-components.psm1") -Force
Import-Module (Join-Path $modulePath "advanced-data-components.psm1") -Force
Import-Module (Join-Path $modulePath "event-system.psm1") -Force

# Import task screen
$screenPath = Join-Path $PSScriptRoot "screens"
Import-Module (Join-Path $screenPath "task-screen.psm1") -Force

# Clear screen for clean start
Clear-Host

try {
    # Initialize the TUI engine
    Initialize-TuiEngine
    
    # Create and push the task screen
    $taskScreen = Create-TaskScreen
    Push-TuiScreen -Screen $taskScreen
    
    # Start the main loop
    Start-TuiLoop
}
finally {
    # Cleanup
    Clear-Host
    Write-Host "Task Management closed." -ForegroundColor Green
}
