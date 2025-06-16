@{
    # Module manifest for app-store service
    RootModule = 'app-store.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-5e6f-7a8b-9c0d-1e2f3a4b5c6d'
    Author = 'PMC Terminal Team'
    CompanyName = 'PMC Terminal'
    Copyright = '(c) 2025 PMC Terminal. All rights reserved.'
    Description = 'Centralized state management service using Redux-like pattern for PMC Terminal'
    
    # Minimum PowerShell version
    PowerShellVersion = '5.1'
    
    # Functions to export
    FunctionsToExport = @('Initialize-AppStore')
    
    # Variables to export
    VariablesToExport = @()
    
    # Aliases to export
    AliasesToExport = @()
    
    # Cmdlets to export
    CmdletsToExport = @()
    
    # Required modules
    RequiredModules = @(
        @{ ModuleName = 'tui-framework'; ModuleVersion = '1.0.0' }
    )
    
    # Module dependencies that must be loaded
    NestedModules = @()
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('StateManagement', 'Redux', 'TUI', 'PMC')
            ProjectUri = 'https://github.com/pmc-terminal/pmc-terminal'
            ReleaseNotes = 'Initial release of centralized state management service'
        }
    }
}
