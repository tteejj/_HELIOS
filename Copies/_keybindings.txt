@{
    # Module manifest for keybindings service
    RootModule = 'keybindings.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'c3d4e5f6-7a8b-9c0d-1e2f-3a4b5c6d7e8f'
    Author = 'PMC Terminal Team'
    CompanyName = 'PMC Terminal'
    Copyright = '(c) 2025 PMC Terminal. All rights reserved.'
    Description = 'Centralized keybinding management service with context support for PMC Terminal'
    
    # Minimum PowerShell version
    PowerShellVersion = '5.1'
    
    # Functions to export
    FunctionsToExport = @('Initialize-KeybindingService')
    
    # Variables to export
    VariablesToExport = @()
    
    # Aliases to export
    AliasesToExport = @()
    
    # Cmdlets to export
    CmdletsToExport = @()
    
    # Required modules
    RequiredModules = @()
    
    # Module dependencies that must be loaded
    NestedModules = @()
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('Keybindings', 'Input', 'TUI', 'PMC')
            ProjectUri = 'https://github.com/pmc-terminal/pmc-terminal'
            ReleaseNotes = 'Initial release of keybinding service with context-aware bindings and chord support'
        }
    }
}
