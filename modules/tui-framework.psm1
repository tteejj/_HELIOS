# TUI Framework Integration Module - COMPLIANT VERSION
# Only contains compliant utility functions - deprecated functions removed

$script:TuiAsyncJobs = @()

function global:Invoke-TuiMethod {
    <#
    .SYNOPSIS
    Safely invokes a method on a TUI component.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Component,

        [Parameter(Mandatory=$true)]
        [string]$MethodName,

        [Parameter()]
        [hashtable]$Arguments = @{}
    )

    if ($null -eq $Component) { return }
    if (-not $Component.ContainsKey($MethodName)) { return }

    $method = $Component[$MethodName]
    if ($null -eq $method -or $method -isnot [scriptblock]) {
        # The method doesn't exist or is not a scriptblock, so we can't call it.
        # This prevents the "term is not recognized" error.
        return
    }

    # Add the component itself as the 'self' parameter for convenience
    $Arguments['self'] = $Component

    try {
        # Use splatting with the @ operator for robust parameter passing
        return & $method @Arguments
    
        } catch {
        $errorMessage = "Error invoking method '$MethodName' on component '$($Component.Type)': $($_.Exception.Message)"
        Write-Log -Level Error -Message $errorMessage -Data $_
        Request-TuiRefresh
    }
}

# Add 'Invoke-TuiMethod' to the Export-ModuleMember list at the end of the file.

function global:Initialize-TuiFramework {
    <#
    .SYNOPSIS
    Initializes the TUI framework
    #>
    
    # Ensure engine is initialized
    if (-not $global:TuiState) {
        throw "TUI Engine must be initialized before framework"
    }
    
    Write-Verbose "TUI Framework initialized"
}

function global:Invoke-TuiAsync {
    <#
    .SYNOPSIS
    Executes a script block asynchronously with proper job management
    
    .PARAMETER ScriptBlock
    The script block to execute asynchronously
    
    .PARAMETER OnComplete
    Handler to call when the job completes successfully
    
    .PARAMETER OnError
    Handler to call if the job encounters an error
    
    .PARAMETER ArgumentList
    Arguments to pass to the script block
    #>
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [scriptblock]$OnComplete = {},
        
        [Parameter()]
        [scriptblock]$OnError = {},
        
        [Parameter()]
        [array]$ArgumentList = @()
    )
    
    try {
        # Start the job
        $job = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
        
        # Track the job for cleanup
        $script:TuiAsyncJobs += $job
        
        # Create a timer to check job status
        $timer = New-Object System.Timers.Timer
        $timer.Interval = 100  # Check every 100ms
        $timer.AutoReset = $true
        
        # Use Register-ObjectEvent to handle the timer tick
        $timerEvent = Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
            try { # Internal try/catch for async operation
                $job = $Event.MessageData.Job
                $onComplete = $Event.MessageData.OnComplete
                $onError = $Event.MessageData.OnError
                $timer = $Event.MessageData.Timer
                
                if ($job.State -eq 'Completed') {
                    try {
                        $result = Receive-Job -Job $job -ErrorAction Stop
                        Remove-Job -Job $job -Force
                        
                        # Remove from tracking
                        $script:TuiAsyncJobs = @($script:TuiAsyncJobs | Where-Object { $_ -ne $job })
                        
                        # Stop and dispose timer
                        $timer.Stop()
                        $timer.Dispose()
                        Unregister-Event -SourceIdentifier $Event.SourceIdentifier
                        
                        # Call completion handler on UI thread
                        if ($onComplete) {
                            Invoke-WithErrorHandling -Component "TuiAsync.OnComplete" -ScriptBlock {
                                & $onComplete -Data $result
                                Request-TuiRefresh
                            } -Context @{ JobId = $job.Id; Result = $result } -ErrorHandler {
                                param($Exception)
                                Write-Log -Level Error -Message "TuiAsync OnComplete handler error: $($Exception.Message)" -Data $Exception.Context
                            }
                        }
                    } catch {
                        Write-Log -Level Error -Message "Job receive error in TuiAsync: $_" -Data @{ JobId = $job.Id; Exception = $_ }
                    }
                }
                elseif ($job.State -eq 'Failed') {
                    try {
                        $error = $job.ChildJobs[0].JobStateInfo.Reason
                        Remove-Job -Job $job -Force
                        
                        # Remove from tracking
                        $script:TuiAsyncJobs = @($script:TuiAsyncJobs | Where-Object { $_ -ne $job })
                        
                        # Stop and dispose timer
                        $timer.Stop()
                        $timer.Dispose()
                        Unregister-Event -SourceIdentifier $Event.SourceIdentifier
                        
                        # Call error handler
                        if ($onError) {
                            Invoke-WithErrorHandling -Component "TuiAsync.OnError" -ScriptBlock {
                                & $onError -Error $error
                                Request-TuiRefresh
                            } -Context @{ JobId = $job.Id; Error = $error } -ErrorHandler {
                                param($Exception)
                                Write-Log -Level Error -Message "TuiAsync OnError handler error: $($Exception.Message)" -Data $Exception.Context
                            }
                        }
                    } catch {
                        Write-Log -Level Error -Message "Job error handling failed in TuiAsync: $_" -Data @{ JobId = $job.Id; Exception = $_ }
                    }
                }
            } catch { # Catch for the Register-ObjectEvent Action block itself
                Write-Log -Level Error -Message "Unhandled error in TuiAsync timer event: $_" -Data @{ JobId = $job.Id; Exception = $_ }
            }
        } -MessageData @{
            Job = $job
            OnComplete = $OnComplete
            OnError = $OnError
            Timer = $timer
        }
        
        # Start the timer
        $timer.Start()
        
        # Return job info
        return @{
            Job = $job
            Timer = $timer
            EventSubscription = $timerEvent
        }
        
    } catch {
        Write-Log -Level Error -Message "Failed to start async operation: $_" -Data @{ ScriptBlock = $ScriptBlock; ArgumentList = $ArgumentList; Exception = $_ }
        if ($OnError) {
            & $OnError -Error $_
        }
    }
}

function global:Stop-AllTuiAsyncJobs {
    <#
    .SYNOPSIS
    Stops and cleans up all tracked async jobs
    #>
    
    foreach ($job in $script:TuiAsyncJobs) {
        try {
            if ($job.State -eq 'Running') {
                Stop-Job -Job $job -ErrorAction SilentlyContinue
            }
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Failed to stop job: $_"
        }
    }
    
    $script:TuiAsyncJobs = @()
    
    # Clean up any orphaned timer events
    Get-EventSubscriber | Where-Object { $_.SourceObject -is [System.Timers.Timer] } | ForEach-Object {
        try {
            Unregister-Event -SourceIdentifier $_.SourceIdentifier -ErrorAction SilentlyContinue
            if ($_.SourceObject) {
                $_.SourceObject.Stop()
                $_.SourceObject.Dispose()
            }
        } catch { }
    }
}

function global:Create-TuiState {
    <#
    .SYNOPSIS
    Creates a reactive state management system with deep change detection
    
    .PARAMETER InitialState
    The initial state values
    
    .PARAMETER DeepWatch
    Enable deep property change detection (```powershell
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
    Invoke-WithErrorHandling -Component "ThemeManager.Initialize" -ScriptBlock {
        # Set default theme
        Set-TuiTheme -ThemeName "Modern"
        
        Write-Verbose "Theme manager initialized"
    } -Context @{} -ErrorHandler {
        param($Exception)
        Write-Log -Level Error -Message "Failed to initialize Theme Manager: $($Exception.Message)" -Data $Exception.Context
    }
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
    Invoke-WithErrorHandling -Component "ThemeManager.SetTheme" -ScriptBlock {
        # Initialize themes if null
        if ($null -eq $script:Themes) {
            $script:Themes = @{
                Modern = @{
                    Name = "Modern"
                    Colors = @{
                        Background = [ConsoleColor]::Black
                        Foreground = [ConsoleColor]::White
                        Primary = [ConsoleColor]::White
                        Secondary = [ConsoleColor]::Gray
                        Accent = [ConsoleColor]::Cyan
                        Success = [ConsoleColor]::Green
                        Warning = [ConsoleColor]::Yellow
                        Error = [ConsoleColor]::Red
                        Info = [ConsoleColor]::Blue
                        Header = [ConsoleColor]::Cyan
                        Border = [ConsoleColor]::DarkGray
                        Selection = [ConsoleColor]::Yellow
                        Highlight = [ConsoleColor]::Cyan
                        Subtle = [ConsoleColor]::DarkGray
                    }
                }
            }
        }
        
        if ($script:Themes -and $script:Themes.ContainsKey($ThemeName)) {
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
    } -Context @{ ThemeName = $ThemeName } -ErrorHandler {
        param($Exception)
        Write-Log -Level Error -Message "Failed to set TUI Theme to '$($Exception.Context.ThemeName)': $($Exception.Message)" -Data $Exception.Context
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
    Invoke-WithErrorHandling -Component "ThemeManager.GetColor" -ScriptBlock {
        if ($script:CurrentTheme -and $script:CurrentTheme.Colors.ContainsKey($ColorName)) {
            return $script:CurrentTheme.Colors[$ColorName]
        } else {
            return $Default
        }
    } -Context @{ ColorName = $ColorName; DefaultColor = $Default } -ErrorHandler {
        param($Exception)
        Write-Log -Level Error -Message "Failed to get theme color '$($Exception.Context.ColorName)': $($Exception.Message)" -Data $Exception.Context
        return $Default # Return default on error
    }
}

function global:Get-TuiTheme {
    <#
    .SYNOPSIS
    Gets the current theme
    #>
    Invoke-WithErrorHandling -Component "ThemeManager.GetTheme" -ScriptBlock {
        return $script:CurrentTheme
    } -Context @{} -ErrorHandler {
        param($Exception)
        Write-Log -Level Error -Message "Failed to get current TUI Theme: $($Exception.Message)" -Data $Exception.Context
        return $null # Return null on error
    }
}

function global:Get-AvailableThemes {
    <#
    .SYNOPSIS
    Gets all available themes
    #>
    Invoke-WithErrorHandling -Component "ThemeManager.GetAvailableThemes" -ScriptBlock {
        return $script:Themes.Keys | Sort-Object
    } -Context @{} -ErrorHandler {
        param($Exception)
        Write-Log -Level Error -Message "Failed to get available themes: $($Exception.Message)" -Data $Exception.Context
        return @() # Return empty array on error
    }
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
    Invoke-WithErrorHandling -Component "ThemeManager.NewTheme" -ScriptBlock {
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
    } -Context @{ ThemeName = $Name; BaseTheme = $BaseTheme; CustomColors = $Colors } -ErrorHandler {
        param($Exception)
        Write-Log -Level Error -Message "Failed to create new TUI Theme '$($Exception.Context.ThemeName)': $($Exception.Message)" -Data $Exception.Context
        return $null # Return null on error
    }
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
    Invoke-WithErrorHandling -Component "ThemeManager.ExportTheme" -ScriptBlock {
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
    } -Context @{ ThemeName = $ThemeName; FilePath = $Path } -ErrorHandler {
        param($Exception)
        Write-Log -Level Error -Message "Failed to export TUI Theme '$($Exception.Context.ThemeName)' to '$($Exception.Context.FilePath)': $($Exception.Message)" -Data $Exception.Context
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
    Invoke-WithErrorHandling -Component "ThemeManager.ImportTheme" -ScriptBlock {
        if (Test-Path $Path) {
            try {
                $importedTheme = Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable
                
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
                Write-Log -Level Error -Message "Failed to import theme from '$Path': $_" -Data @{ FilePath = $Path; Exception = $_ }
            }
        } else {
            Write-Warning "Theme file not found: $Path"
        }
    } -Context @{ FilePath = $Path } -ErrorHandler {
        param($Exception)
        Write-Log -Level Error -Message "Failed to import TUI Theme from '$($Exception.Context.FilePath)': $($Exception.Message)" -Data $Exception.Context
        return $null # Return null on error
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