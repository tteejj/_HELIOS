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
