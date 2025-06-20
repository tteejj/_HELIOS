# Quick Dashboard Test Script
# This script helps verify the dashboard is working correctly

Write-Host "Testing Dashboard Screen Fix..." -ForegroundColor Cyan

# Navigate directly to dashboard
if ($global:Services -and $global:Services.Navigation) {
    Write-Host "Navigating to dashboard..." -ForegroundColor Yellow
    & $global:Services.Navigation.GoTo -self $global:Services.Navigation -Path "/dashboard" -Services $global:Services
    
    Start-Sleep -Seconds 2
    
    # Check if store has data
    if ($global:Services.Store) {
        Write-Host "`nChecking store state..." -ForegroundColor Yellow
        
        $quickActions = & $global:Services.Store.GetState -self $global:Services.Store -path "quickActions"
        Write-Host "QuickActions count: $($quickActions.Count)" -ForegroundColor $(if($quickActions.Count -gt 0) {"Green"} else {"Red"})
        
        $todayHours = & $global:Services.Store.GetState -self $global:Services.Store -path "stats.todayHours"
        Write-Host "Today hours: $todayHours" -ForegroundColor Cyan
        
        $activeTasks = & $global:Services.Store.GetState -self $global:Services.Store -path "stats.activeTasks"
        Write-Host "Active tasks: $activeTasks" -ForegroundColor Cyan
        
        # Force a refresh
        Write-Host "`nForcing dashboard refresh..." -ForegroundColor Yellow
        & $global:Services.Store.Dispatch -self $global:Services.Store -actionName "DASHBOARD_REFRESH"
    }
} else {
    Write-Host "Services not available!" -ForegroundColor Red
}

Write-Host "`nTest complete. Check the dashboard display and log for errors." -ForegroundColor Green
