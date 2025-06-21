@{
    # Module manifest for navigation service
    RootModule = 'navigation.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'b2c3d4e5-6f7a-8b9c-0d1e-2f3a4b5c6d7e'
    Author = 'PMC Terminal Team'
    CompanyName = 'PMC Terminal'
    Copyright = '(c) 2025 PMC Terminal. All rights reserved.'
    Description = 'Centralized navigation service with routing and breadcrumbs for PMC Terminal'
    
    # Minimum PowerShell version
    PowerShellVersion = '5.1'
    
    # Functions to export
    FunctionsToExport = @('Initialize-NavigationService')
    
    # Variables to export
    VariablesToExport = @()
    
    # Aliases to export
    AliasesToExport = @()
    
    # Cmdlets to export
    CmdletsToExport = @()
    
    # Required modules
    RequiredModules = @(
        @{ ModuleName = 'tui-engine-v2'; ModuleVersion = '1.0.0' },
        @{ ModuleName = 'dialog-system'; ModuleVersion = '1.0.0' }
    )
    
    # Module dependencies that must be loaded
    NestedModules = @()
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('Navigation', 'Routing', 'TUI', 'PMC')
            ProjectUri = 'https://github.com/pmc-terminal/pmc-terminal'
            ReleaseNotes = 'Initial release of navigation service with route guards and breadcrumbs'
        }
    }
}
# FILE: services/navigation.psm1
# PURPOSE: Decouples screens by managing all navigation through a centralized route map.

function Initialize-NavigationService {
    param(
        [hashtable]$CustomRoutes = @{},
        [bool]$EnableBreadcrumbs = $true
    )
    Invoke-WithErrorHandling -Component "NavigationService.Initialize" -ScriptBlock {
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
                Invoke-WithErrorHandling -Component "NavigationService.GoTo" -ScriptBlock {
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
                        try {
                            $canNavigate = & $guard -Path $Path -Route $route -Params $Params
                            if (-not $canNavigate) {
                                Write-Log -Level Debug -Message "Navigation to '$Path' cancelled by guard"
                                return $false
                            }
                        } catch {
                            Write-Log -Level Error -Message "Navigation guard failed for path '$Path': $_" -Data @{ Path = $Path; Guard = $guard; Exception = $_ }
                            Show-AlertDialog -Title "Navigation Error" -Message "A navigation check failed. Cannot proceed."
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
                        
                        if ($screen.SetParams -and $Params.Count -gt 0) { 
                            try {
                                & $screen.SetParams -self $screen -Params $Params 
                            } catch {
                                Write-Log -Level Error -Message "Screen SetParams failed for '$Path': $_" -Data @{ Path = $Path; Params = $Params; Exception = $_ }
                            }
                        }
                        
                        $self._history += @{ Path = $Path; Timestamp = [DateTime]::UtcNow; Params = $Params }
                        if ($EnableBreadcrumbs) { $self._breadcrumbs += @{ Path = $Path; Title = $route.Title ?? $Path } }
                        
                        Push-Screen -Screen $screen
                        
                        foreach ($hook in $self._afterNavigate) { 
                            try {
                                & $hook -Path $Path -Screen $screen 
                            } catch {
                                Write-Log -Level Error -Message "After navigation hook failed for path '$Path': $_" -Data @{ Path = $Path; Hook = $hook; Exception = $_ }
                            }
                        }
                        
                        Write-Log -Level Info -Message "Navigated to: $Path"
                        return $true
                    }
                    catch {
                        throw [NavigationException]::new(
                            "Failed to create or navigate to screen for route '$Path'",
                            @{
                                Route = $Path
                                RouteConfig = $route
                                OriginalException = $_
                            }
                        )
                    }
                } -Context @{ Path = $Path; Params = $Params } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "NavigationService GoTo error for path '$($Exception.Context.Path)': $($Exception.Message)" -Data $Exception.Context
                    Show-AlertDialog -Title "Navigation Error" -Message "Failed to navigate to '$($Exception.Context.Path)': $($Exception.Message)"
                    return $false
                }
            }
            
            Back = { 
                param($self, [int]$Steps = 1)
                Invoke-WithErrorHandling -Component "NavigationService.Back" -ScriptBlock {
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
                } -Context @{ Steps = $Steps } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "NavigationService Back error: $($Exception.Message)" -Data $Exception.Context
                    return $false
                }
            }
            
            GetCurrentPath = {
                param($self)
                Invoke-WithErrorHandling -Component "NavigationService.GetCurrentPath" -ScriptBlock {
                    if ($self._history.Count -eq 0) { return "/" }
                    return $self._history[-1].Path
                } -Context @{} -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "NavigationService GetCurrentPath error: $($Exception.Message)" -Data $Exception.Context
                    return "/"
                }
            }
            
            GetBreadcrumbs = {
                param($self)
                Invoke-WithErrorHandling -Component "NavigationService.GetBreadcrumbs" -ScriptBlock {
                    return $self._breadcrumbs
                } -Context @{} -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "NavigationService GetBreadcrumbs error: $($Exception.Message)" -Data $Exception.Context
                    return @()
                }
            }
            
            AddRoute = {
                param($self, [string]$Path, [hashtable]$RouteConfig)
                Invoke-WithErrorHandling -Component "NavigationService.AddRoute" -ScriptBlock {
                    if (-not $RouteConfig.Factory) { throw "Route must have a Factory scriptblock" }
                    $self._routes[$Path] = $RouteConfig
                    Write-Log -Level Debug -Message "Added route: $Path"
                } -Context @{ Path = $Path; RouteConfig = $RouteConfig } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "NavigationService AddRoute error for path '$($Exception.Context.Path)': $($Exception.Message)" -Data $Exception.Context
                }
            }
            
            RemoveRoute = {
                param($self, [string]$Path)
                Invoke-WithErrorHandling -Component "NavigationService.RemoveRoute" -ScriptBlock {
                    $self._routes.Remove($Path)
                    Write-Log -Level Debug -Message "Removed route: $Path"
                } -Context @{ Path = $Path } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "NavigationService RemoveRoute error for path '$($Exception.Context.Path)': $($Exception.Message)" -Data $Exception.Context
                }
            }
            
            AddBeforeNavigateGuard = {
                param($self, [scriptblock]$Guard)
                Invoke-WithErrorHandling -Component "NavigationService.AddBeforeNavigateGuard" -ScriptBlock {
                    $self._beforeNavigate += $Guard
                } -Context @{} -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "NavigationService AddBeforeNavigateGuard error: $($Exception.Message)" -Data $Exception.Context
                }
            }
            
            AddAfterNavigateHook = {
                param($self, [scriptblock]$Hook)
                Invoke-WithErrorHandling -Component "NavigationService.AddAfterNavigateHook" -ScriptBlock {
                    $self._afterNavigate += $Hook
                } -Context @{} -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "NavigationService AddAfterNavigateHook error: $($Exception.Message)" -Data $Exception.Context
                }
            }
            
            _checkAuth = {
                param($self)
                Invoke-WithErrorHandling -Component "NavigationService._checkAuth" -ScriptBlock {
                    # Placeholder for authentication check
                    return $true
                } -Context @{} -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "NavigationService _checkAuth error: $($Exception.Message)" -Data $Exception.Context
                    return $false
                }
            }
            
            GetRoutes = {
                param($self)
                Invoke-WithErrorHandling -Component "NavigationService.GetRoutes" -ScriptBlock {
                    return $self._routes.Keys | Sort-Object
                } -Context @{} -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "NavigationService GetRoutes error: $($Exception.Message)" -Data $Exception.Context
                    return @()
                }
            }
            
            IsValidRoute = {
                param($self, [string]$Path)
                Invoke-WithErrorHandling -Component "NavigationService.IsValidRoute" -ScriptBlock {
                    return $self._routes.ContainsKey($Path)
                } -Context @{ Path = $Path } -ErrorHandler {
                    param($Exception)
                    Write-Log -Level Error -Message "NavigationService IsValidRoute error for path '$($Exception.Context.Path)': $($Exception.Message)" -Data $Exception.Context
                    return $false
                }
            }
        }
        
        return $service
    } -Context @{ CustomRoutes = $CustomRoutes; EnableBreadcrumbs = $EnableBreadcrumbs } -ErrorHandler {
        param($Exception)
        Write-Log -Level Error -Message "Failed to initialize Navigation Service: $($Exception.Message)" -Data $Exception.Context
        return $null
    }
}

Export-ModuleMember -Function "Initialize-NavigationService"