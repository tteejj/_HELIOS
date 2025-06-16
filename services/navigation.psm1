# FILE: services/navigation.psm1
# PURPOSE: Decouples screens by managing all navigation through a centralized route map.

function Initialize-NavigationService {
    param(
        [hashtable]$CustomRoutes = @{},
        [bool]$EnableBreadcrumbs = $true
    )
    
    # Default routes - can be overridden by CustomRoutes
    $defaultRoutes = @{
        "/dashboard" = @{ 
            Factory = { Get-DashboardScreen }
            Title = "Dashboard"
            RequiresAuth = $false
        }
        "/tasks" = @{ 
            Factory = { Get-TaskManagementScreen }
            Title = "Task Management"
            RequiresAuth = $false
        }
        "/timer/start" = @{ 
            Factory = { Get-TimerStartScreen }
            Title = "Timer"
            RequiresAuth = $false
        }
        "/timer/manage" = @{
            Factory = { Get-TimerManagementScreen }
            Title = "Timer Management"
            RequiresAuth = $false
        }
        "/reports" = @{ 
            Factory = { Get-ReportsScreen }
            Title = "Reports"
            RequiresAuth = $false
        }
        "/settings" = @{ 
            Factory = { Get-SettingsScreen }
            Title = "Settings"
            RequiresAuth = $false
        }
        "/projects" = @{ 
            Factory = { Get-ProjectManagementScreen }
            Title = "Projects"
            RequiresAuth = $false
        }
        "/log" = @{ 
            Factory = { Get-DebugLogScreen }
            Title = "Debug Log"
            RequiresAuth = $false
        }
    }
    
    # Merge custom routes
    $routes = $defaultRoutes
    foreach ($key in $CustomRoutes.Keys) {
        $routes[$key] = $CustomRoutes[$key]
    }
    
    $service = @{
        _routes = $routes
        _history = @()  # Navigation history for back button
        _breadcrumbs = @()  # For UI breadcrumb display
        _beforeNavigate = @()  # Navigation guards
        _afterNavigate = @()  # Navigation hooks
        
        GoTo = {
            param(
                [string]$Path,
                [hashtable]$Params = @{}
            )
            
            if ([string]::IsNullOrWhiteSpace($Path)) {
                Write-Log -Level Error -Message "Navigation path cannot be empty"
                return $false
            }
            
            # Normalize path
            if (-not $Path.StartsWith("/")) {
                $Path = "/$Path"
            }
            
            # Check if route exists
            if (-not $service._routes.ContainsKey($Path)) {
                $availableRoutes = ($service._routes.Keys | Sort-Object) -join ", "
                $msg = "Route not found: $Path. Available routes: $availableRoutes"
                Write-Log -Level Error -Message $msg
                Show-AlertDialog -Title "Navigation Error" -Message "The screen '$Path' does not exist."
                return $false
            }
            
            $route = $service._routes[$Path]
            
            # Run before navigation guards
            foreach ($guard in $service._beforeNavigate) {
                $canNavigate = & $guard -Path $Path -Route $route -Params $Params
                if (-not $canNavigate) {
                    Write-Log -Level Debug -Message "Navigation to '$Path' cancelled by guard"
                    return $false
                }
            }
            
            # Check authentication if required
            if ($route.RequiresAuth -and -not $service._checkAuth()) {
                Write-Log -Level Warning -Message "Navigation to '$Path' requires authentication"
                Show-AlertDialog -Title "Access Denied" -Message "You must be logged in to access this screen."
                return $false
            }
            
            try {
                # Create screen instance
                $screen = & $route.Factory
                
                if (-not $screen) {
                    throw "Screen factory returned null for route '$Path'"
                }
                
                # Pass parameters to screen if it supports them
                if ($screen.SetParams -and $Params.Count -gt 0) {
                    & $screen.SetParams -self $screen -Params $Params
                }
                
                # Update navigation state
                $service._history += @{
                    Path = $Path
                    Timestamp = [DateTime]::UtcNow
                    Params = $Params
                }
                
                if ($EnableBreadcrumbs) {
                    $service._breadcrumbs += @{
                        Path = $Path
                        Title = $route.Title ?? $Path
                    }
                }
                
                # Push screen
                Push-Screen -Screen $screen
                
                # Run after navigation hooks
                foreach ($hook in $service._afterNavigate) {
                    & $hook -Path $Path -Screen $screen
                }
                
                Write-Log -Level Info -Message "Navigated to: $Path"
                return $true
            }
            catch {
                Write-Log -Level Error -Message "Failed to navigate to '$Path': $_"
                Show-AlertDialog -Title "Navigation Error" -Message "Failed to load screen: $_"
                return $false
            }
        }
        
        Back = { 
            param([int]$Steps = 1)
            
            for ($i = 0; $i -lt $Steps; $i++) {
                if ($global:TuiState.ScreenStack.Count -le 1) {
                    Write-Log -Level Debug -Message "Cannot go back - at root screen"
                    return $false
                }
                
                Pop-Screen
                
                # Update breadcrumbs
                if ($EnableBreadcrumbs -and $service._breadcrumbs.Count -gt 0) {
                    $service._breadcrumbs = $service._breadcrumbs[0..($service._breadcrumbs.Count - 2)]
                }
            }
            
            return $true
        }
        
        GetCurrentPath = {
            if ($service._history.Count -eq 0) {
                return "/"
            }
            return $service._history[-1].Path
        }
        
        GetBreadcrumbs = {
            return $service._breadcrumbs
        }
        
        AddRoute = {
            param(
                [string]$Path,
                [hashtable]$RouteConfig
            )
            
            if (-not $RouteConfig.Factory) {
                throw "Route must have a Factory scriptblock"
            }
            
            $service._routes[$Path] = $RouteConfig
            Write-Log -Level Debug -Message "Added route: $Path"
        }
        
        RemoveRoute = {
            param([string]$Path)
            $service._routes.Remove($Path)
            Write-Log -Level Debug -Message "Removed route: $Path"
        }
        
        AddBeforeNavigateGuard = {
            param([scriptblock]$Guard)
            $service._beforeNavigate += $Guard
        }
        
        AddAfterNavigateHook = {
            param([scriptblock]$Hook)
            $service._afterNavigate += $Hook
        }
        
        _checkAuth = {
            # Placeholder for authentication check
            # In real implementation, would check against auth service
            return $true
        }
        
        GetRoutes = {
            return $service._routes.Keys | Sort-Object
        }
        
        IsValidRoute = {
            param([string]$Path)
            return $service._routes.ContainsKey($Path)
        }
    }
    
    return $service
}

Export-ModuleMember -Function "Initialize-NavigationService"
