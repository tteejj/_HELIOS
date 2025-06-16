# Theme Manager Module
# Provides theming and color management for the TUI

$script:CurrentTheme = $null
$script:Themes = @{
    Modern = @{
        Name = "Modern"
        Colors = @{
            # Base colors
            Background = [ConsoleColor]::Black
            Foreground = [ConsoleColor]::White
            
            # UI elements
            Primary = [ConsoleColor]::White
            Secondary = [ConsoleColor]::Gray
            Accent = [ConsoleColor]::Cyan
            Success = [ConsoleColor]::Green
            Warning = [ConsoleColor]::Yellow
            Error = [ConsoleColor]::Red
            Info = [ConsoleColor]::Blue
            
            # Special elements
            Header = [ConsoleColor]::Cyan
            Border = [ConsoleColor]::DarkGray
            Selection = [ConsoleColor]::Yellow
            Highlight = [ConsoleColor]::Cyan
            Subtle = [ConsoleColor]::DarkGray
            
            # Syntax highlighting
            Keyword = [ConsoleColor]::Blue
            String = [ConsoleColor]::Green
            Number = [ConsoleColor]::Magenta
            Comment = [ConsoleColor]::DarkGray
        }
    }
    
    Dark = @{
        Name = "Dark"
        Colors = @{
            Background = [ConsoleColor]::Black
            Foreground = [ConsoleColor]::Gray
            Primary = [ConsoleColor]::Gray
            Secondary = [ConsoleColor]::DarkGray
            Accent = [ConsoleColor]::DarkCyan
            Success = [ConsoleColor]::DarkGreen
            Warning = [ConsoleColor]::DarkYellow
            Error = [ConsoleColor]::DarkRed
            Info = [ConsoleColor]::DarkBlue
            Header = [ConsoleColor]::DarkCyan
            Border = [ConsoleColor]::DarkGray
            Selection = [ConsoleColor]::Yellow
            Highlight = [ConsoleColor]::Cyan
            Subtle = [ConsoleColor]::DarkGray
            Keyword = [ConsoleColor]::DarkBlue
            String = [ConsoleColor]::DarkGreen
            Number = [ConsoleColor]::DarkMagenta
            Comment = [ConsoleColor]::DarkGray
        }
    }
    
    Light = @{
        Name = "Light"
        Colors = @{
            Background = [ConsoleColor]::White
            Foreground = [ConsoleColor]::Black
            Primary = [ConsoleColor]::Black
            Secondary = [ConsoleColor]::DarkGray
            Accent = [ConsoleColor]::Blue
            Success = [ConsoleColor]::Green
            Warning = [ConsoleColor]::DarkYellow
            Error = [ConsoleColor]::Red
            Info = [ConsoleColor]::Blue
            Header = [ConsoleColor]::Blue
            Border = [ConsoleColor]::Gray
            Selection = [ConsoleColor]::Cyan
            Highlight = [ConsoleColor]::Yellow
            Subtle = [ConsoleColor]::Gray
            Keyword = [ConsoleColor]::Blue
            String = [ConsoleColor]::Green
            Number = [ConsoleColor]::Magenta
            Comment = [ConsoleColor]::Gray
        }
    }
    
    Retro = @{
        Name = "Retro"
        Colors = @{
            Background = [ConsoleColor]::Black
            Foreground = [ConsoleColor]::Green
            Primary = [ConsoleColor]::Green
            Secondary = [ConsoleColor]::DarkGreen
            Accent = [ConsoleColor]::Yellow
            Success = [ConsoleColor]::Green
            Warning = [ConsoleColor]::Yellow
            Error = [ConsoleColor]::Red
            Info = [ConsoleColor]::Cyan
            Header = [ConsoleColor]::Yellow
            Border = [ConsoleColor]::DarkGreen
            Selection = [ConsoleColor]::Yellow
            Highlight = [ConsoleColor]::White
            Subtle = [ConsoleColor]::DarkGreen
            Keyword = [ConsoleColor]::Yellow
            String = [ConsoleColor]::Cyan
            Number = [ConsoleColor]::White
            Comment = [ConsoleColor]::DarkGreen
        }
    }
}

function global:Initialize-ThemeManager {
    <#
    .SYNOPSIS
    Initializes the theme manager
    #>
    
    # Set default theme
    Set-TuiTheme -ThemeName "Modern"
    
    Write-Verbose "Theme manager initialized"
}

function global:Set-TuiTheme {
    <#
    .SYNOPSIS
    Sets the current theme
    
    .PARAMETER ThemeName
    The name of the theme to set
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Modern", "Dark", "Light", "Retro")]
        [string]$ThemeName
    )
    
    if ($script:Themes.ContainsKey($ThemeName)) {
        $script:CurrentTheme = $script:Themes[$ThemeName]
        
        # --- FIX ---
        # Defensively check if RawUI exists. In some environments (like the VS Code
        # Integrated Console), it can be $null and cause a crash.
        if ($Host.UI.RawUI) {
            # Apply console colors
            $Host.UI.RawUI.BackgroundColor = $script:CurrentTheme.Colors.Background
            $Host.UI.RawUI.ForegroundColor = $script:CurrentTheme.Colors.Foreground
        }
        
        Write-Verbose "Theme set to: $ThemeName"
        
        # Publish theme change event
        # Check if Publish-Event exists before calling it
        if (Get-Command -Name Publish-Event -ErrorAction SilentlyContinue) {
            Publish-Event -EventName "Theme.Changed" -Data @{ 
                ThemeName = $ThemeName
                Theme = $script:CurrentTheme 
            }
        }
    } else {
        Write-Warning "Theme not found: $ThemeName"
    }
}

function global:Get-ThemeColor {
    <#
    .SYNOPSIS
    Gets a color from the current theme
    
    .PARAMETER ColorName
    The name of the color to get
    
    .PARAMETER Default
    Default color if not found
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ColorName,
        
        [Parameter()]
        [ConsoleColor]$Default = [ConsoleColor]::Gray
    )
    
    if ($script:CurrentTheme -and $script:CurrentTheme.Colors.ContainsKey($ColorName)) {
        return $script:CurrentTheme.Colors[$ColorName]
    } else {
        return $Default
    }
}

function global:Get-TuiTheme {
    <#
    .SYNOPSIS
    Gets the current theme
    #>
    
    return $script:CurrentTheme
}

function global:Get-AvailableThemes {
    <#
    .SYNOPSIS
    Gets all available themes
    #>
    
    return $script:Themes.Keys | Sort-Object
}

function global:New-TuiTheme {
    <#
    .SYNOPSIS
    Creates a new theme
    
    .PARAMETER Name
    The name of the new theme
    
    .PARAMETER BaseTheme
    The name of the theme to base this on
    
    .PARAMETER Colors
    Hashtable of color overrides
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter()]
        [string]$BaseTheme = "Modern",
        
        [Parameter()]
        [hashtable]$Colors = @{}
    )
    
    # Clone base theme
    $newTheme = @{
        Name = $Name
        Colors = @{}
    }
    
    if ($script:Themes.ContainsKey($BaseTheme)) {
        foreach ($colorKey in $script:Themes[$BaseTheme].Colors.Keys) {
            $newTheme.Colors[$colorKey] = $script:Themes[$BaseTheme].Colors[$colorKey]
        }
    }
    
    # Apply overrides
    foreach ($colorKey in $Colors.Keys) {
        $newTheme.Colors[$colorKey] = $Colors[$colorKey]
    }
    
    # Save theme
    $script:Themes[$Name] = $newTheme
    
    Write-Verbose "Created new theme: $Name"
    
    return $newTheme
}

function global:Export-TuiTheme {
    <#
    .SYNOPSIS
    Exports a theme to JSON
    
    .PARAMETER ThemeName
    The name of the theme to export
    
    .PARAMETER Path
    The path to save the theme
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ThemeName,
        
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if ($script:Themes.ContainsKey($ThemeName)) {
        $theme = $script:Themes[$ThemeName]
        
        # Convert ConsoleColor enums to strings for JSON
        $exportTheme = @{
            Name = $theme.Name
            Colors = @{}
        }
        
        foreach ($colorKey in $theme.Colors.Keys) {
            $exportTheme.Colors[$colorKey] = $theme.Colors[$colorKey].ToString()
        }
        
        $exportTheme | ConvertTo-Json -Depth 3 | Set-Content -Path $Path
        
        Write-Verbose "Exported theme to: $Path"
    } else {
        Write-Warning "Theme not found: $ThemeName"
    }
}

function global:Import-TuiTheme {
    <#
    .SYNOPSIS
    Imports a theme from JSON
    
    .PARAMETER Path
    The path to the theme file
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if (Test-Path $Path) {
        try {
            $importedTheme = Get-Content $Path -Raw | ConvertFrom-Json
            
            $theme = @{
                Name = $importedTheme.Name
                Colors = @{}
            }
            
            # Convert string color names back to ConsoleColor enums
            foreach ($colorProp in $importedTheme.Colors.PSObject.Properties) {
                $theme.Colors[$colorProp.Name] = [ConsoleColor]$colorProp.Value
            }
            
            $script:Themes[$theme.Name] = $theme
            
            Write-Verbose "Imported theme: $($theme.Name)"
            
            return $theme
        } catch {
            Write-Error "Failed to import theme: $_"
        }
    } else {
        Write-Warning "Theme file not found: $Path"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-ThemeManager',
    'Set-TuiTheme',
    'Get-ThemeColor',
    'Get-TuiTheme',
    'Get-AvailableThemes',
    'New-TuiTheme',
    'Export-TuiTheme',
    'Import-TuiTheme'
)