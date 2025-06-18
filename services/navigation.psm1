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
                $self,
                [string]$Path,
                [hashtable]$Params = @{},
                [hashtable]$Services = $null
            )
            
            if ([string]::IsNullOrWhiteSpace($Path)) {
                Write-Log -Level Error -Message "Navigation path cannot be empty"
                return $false
            }
            
            # Normalize path
            if (-not $Path.StartsWith("/")) { $Path = "/$Path" }
            
            # Check if route exists
            if (-not $self._routes.ContainsKey($Path)) {
                $availableRoutes = ($self._routes.Keys | Sort-Object) -join ", "
                $msg = "Route not found: $Path. Available routes: $availableRoutes"
                Write-Log -Level Error -Message $msg
                Show-AlertDialog -Title "Navigation Error" -Message "The screen '$Path' does not exist."
                return $false
            }
            
            $route = $self._routes[$Path]
            
            # Run before navigation guards
            foreach ($guard in $self._beforeNavigate) {
                $canNavigate = & $guard -Path $Path -Route $route -Params $Params
                if (-not $canNavigate) {
                    Write-Log -Level Debug -Message "Navigation to '$Path' cancelled by guard"
                    return $false
                }
            }
            
            # Check authentication if required
            if ($route.RequiresAuth -and -not (& $self._checkAuth -self $self)) {
                Write-Log -Level Warning -Message "Navigation to '$Path' requires authentication"
                Show-AlertDialog -Title "Access Denied" -Message "You must be logged in to access this screen."
                return $false
            }
            
            try {
                # Pass Services to factory if provided
                if ($Services) {
                    $screen = & $route.Factory -Services $Services
                } else {
                    $screen = & $route.Factory
                }
                if (-not $screen) { throw "Screen factory returned null for route '$Path'" }
                
                # CRITICAL: Ensure screen has services stored
                if ($Services -and -not $screen._services) {
                    $screen._services = $Services
                }
                
                if ($screen.SetParams -and $Params.Count -gt 0) { & $screen.SetParams -self $screen -Params $Params }
                
                $self._history += @{ Path = $Path; Timestamp = [DateTime]::UtcNow; Params = $Params }
                if ($EnableBreadcrumbs) { $self._breadcrumbs += @{ Path = $Path; Title = $route.Title ?? $Path } }
                
                Push-Screen -Screen $screen
                
                foreach ($hook in $self._afterNavigate) { & $hook -Path $Path -Screen $screen }
                
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
            param($self, [int]$Steps = 1)
            for ($i = 0; $i -lt $Steps; $i++) {
                if ($global:TuiState.ScreenStack.Count -le 1) {
                    Write-Log -Level Debug -Message "Cannot go back - at root screen"
                    return $false
                }
                Pop-Screen
                if ($EnableBreadcrumbs -and $self._breadcrumbs.Count -gt 0) {
                    $self._breadcrumbs = $self._breadcrumbs[0..($self._breadcrumbs.Count - 2)]
                }
            }
            return $true
        }
        
        GetCurrentPath = {
            param($self)
            if ($self._history.Count -eq 0) { return "/" }
            return $self._history[-1].Path
        }
        
        GetBreadcrumbs = {
            param($self)
            return $self._breadcrumbs
        }
        
        AddRoute = {
            param($self, [string]$Path, [hashtable]$RouteConfig)
            if (-not $RouteConfig.Factory) { throw "Route must have a Factory scriptblock" }
            $self._routes[$Path] = $RouteConfig
            Write-Log -Level Debug -Message "Added route: $Path"
        }
        
        RemoveRoute = {
            param($self, [string]$Path)
            $self._routes.Remove($Path)
            Write-Log -Level Debug -Message "Removed route: $Path"
        }
        
        AddBeforeNavigateGuard = {
            param($self, [scriptblock]$Guard)
            $self._beforeNavigate += $Guard
        }
        
        AddAfterNavigateHook = {
            param($self, [scriptblock]$Hook)
            $self._afterNavigate += $Hook
        }
        
        _checkAuth = {
            param($self)
            # Placeholder for authentication check
            return $true
        }
        
        GetRoutes = {
            param($self)
            return $self._routes.Keys | Sort-Object
        }
        
        IsValidRoute = {
            param($self, [string]$Path)
            return $self._routes.ContainsKey($Path)
        }
    }
    
    return $service
}

Export-ModuleMember -Function "Initialize-NavigationService"