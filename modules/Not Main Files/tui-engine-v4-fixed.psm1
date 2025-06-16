# Rock-Solid TUI Engine v2 - Framework Edition
# Manages the main loop, rendering pipeline, input queue, and theme system.
# FIXED VERSION - Addresses null reference errors and initialization issues

#region Core TUI State
$script:TuiState = @{
    Running         = $false
    BufferWidth     = 0
    BufferHeight    = 0
    FrontBuffer     = $null
    BackBuffer      = $null
    ScreenStack     = $null
    CurrentScreen   = $null
    IsDirty         = $true
    LastActivity    = [DateTime]::Now
    LastRenderTime  = [DateTime]::MinValue
    RenderStats     = @{ LastFrameTime = 0; FrameCount = 0; TotalTime = 0; TargetFPS = 60 }
    Components      = @()
    Layouts         = @{}
    FocusedComponent = $null
    
    # Thread-safe input queue and runspace management
    InputQueue = $null
    InputRunspace = $null
    InputPowerShell = $null
    InputAsyncResult = $null
    
    # The correct, thread-safe object for signalling shutdown.
    CancellationTokenSource = $null
    
    # Event cleanup tracking
    EventHandlers = @{}
}

# Helper function to create safe cell objects
function New-SafeCell {
    param(
        [char]$Char = ' ',
        [ConsoleColor]$FG = [ConsoleColor]::White,
        [ConsoleColor]$BG = [ConsoleColor]::Black
    )
    
    # Create a new hashtable instead of cloning
    return @{
        Char = $Char
        FG = $FG
        BG = $BG
    }
}
#endregion

#region Engine Lifecycle & Main Loop

function global:Initialize-TuiEngine {
    param(
        [int]$Width = 0,
        [int]$Height = 0
    )

    try {
        # Safe parameter defaults
        if ($Width -le 0) { 
            try {
                $Width = [Console]::WindowWidth
            } catch {
                Write-Warning "Could not get console width, using default: 80"
                $Width = 80
            }
        }
        
        if ($Height -le 0) { 
            try {
                $Height = [Console]::WindowHeight - 1
            } catch {
                Write-Warning "Could not get console height, using default: 24"
                $Height = 24
            }
        }
        
        Write-Verbose "TUI Engine initializing with dimensions: ${Width}x${Height}"
        
        if ($Width -le 0 -or $Height -le 0) { 
            throw "Invalid console dimensions: ${Width}x${Height}" 
        }
        
        # Initialize basic state
        $script:TuiState.BufferWidth = $Width
        $script:TuiState.BufferHeight = $Height
        
        # Create screen stack
        $script:TuiState.ScreenStack = New-Object System.Collections.Stack
        
        # Use regular arrays for buffers with safe initialization
        $totalCells = $Height * $Width
        $script:TuiState.FrontBuffer = New-Object 'object[]' $totalCells
        $script:TuiState.BackBuffer = New-Object 'object[]' $totalCells
        
        # Initialize buffers with safe cell creation (NO CLONING)
        for ($i = 0; $i -lt $totalCells; $i++) {
            $script:TuiState.FrontBuffer[$i] = New-SafeCell
            $script:TuiState.BackBuffer[$i] = New-SafeCell
        }
        
        # Safe console setup
        try {
            [Console]::CursorVisible = $false
        } catch [System.IO.IOException] {
            Write-Warning "Could not hide cursor (restricted console environment)"
        } catch {
            Write-Warning "Console cursor manipulation failed: $_"
        }
        
        # Initialize subsystems with enhanced error handling
        Initialize-SafeInputSystem
        Initialize-SafeLayoutEngines
        Initialize-SafeComponentSystem
        
        # Safe event publishing
        if (Get-Command -Name "Publish-Event" -ErrorAction SilentlyContinue) {
            try {
                Publish-Event -EventName "System.EngineInitialized" -Data @{ Width = $Width; Height = $Height }
            } catch {
                Write-Warning "Could not publish initialization event: $_"
            }
        }
        
        # Export TuiState for global access
        $global:TuiState = $script:TuiState
        
        Write-Verbose "TUI Engine initialized successfully"
    }
    catch {
        Write-Host "--------------------------------------------------------" -ForegroundColor Red
        Write-Host "TUI ENGINE INITIALIZATION FAILED" -ForegroundColor Red
        Write-Host "ERROR MESSAGE: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "ERROR TYPE: $($_.Exception.GetType().Name)" -ForegroundColor Yellow
        
        if ($_.ScriptStackTrace) {
            Write-Host "STACK TRACE:" -ForegroundColor Yellow
            Write-Host $_.ScriptStackTrace -ForegroundColor White
        }
        
        Write-Host "--------------------------------------------------------" -ForegroundColor Red
        
        # Clean up any partial initialization
        try { Cleanup-TuiEngine } catch {}
        
        throw "FATAL: TUI Engine initialization failed. See error details above."
    }
}

function Initialize-SafeInputSystem {
    Write-Verbose "Initializing input system..."
    
    # Try ConcurrentQueue first, fall back to ArrayList
    try {
        $queueType = [System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]]
        $script:TuiState.InputQueue = New-Object $queueType
        Write-Verbose "Using ConcurrentQueue for input"
    } catch {
        Write-Warning "ConcurrentQueue not available, using ArrayList: $_"
        try {
            $script:TuiState.InputQueue = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
            Write-Verbose "Using synchronized ArrayList for input"
        } catch {
            Write-Warning "ArrayList also failed, input will be synchronous: $_"
            $script:TuiState.InputQueue = @()
        }
    }
    
    # Only create background input thread if we have a proper queue
    if ($script:TuiState.InputQueue -and $script:TuiState.InputQueue -isnot [array]) {
        try {
            Initialize-BackgroundInputThread
        } catch {
            Write-Warning "Background input thread failed, using synchronous input: $_"
            $script:TuiState.InputQueue = @()
        }
    }
}

function Initialize-BackgroundInputThread {
    # Create cancellation token source
    $script:TuiState.CancellationTokenSource = [System.Threading.CancellationTokenSource]::new()
    $token = $script:TuiState.CancellationTokenSource.Token

    # Create runspace for input handling
    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('InputQueue', $script:TuiState.InputQueue)
    $runspace.SessionStateProxy.SetVariable('token', $token)
    
    # Create PowerShell instance
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $runspace
    
    # Background input script
    $ps.AddScript({
        try {
            while (-not $token.IsCancellationRequested) {
                if ([Console]::KeyAvailable) {
                    $keyInfo = [Console]::ReadKey($true)
                    
                    # Handle different queue types safely
                    if ($InputQueue -is [System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]]) {
                        if ($InputQueue.Count -lt 100) {
                            $InputQueue.Enqueue($keyInfo)
                        }
                    } elseif ($InputQueue -is [System.Collections.ArrayList]) {
                        if ($InputQueue.Count -lt 100) {
                            $null = $InputQueue.Add($keyInfo)
                        }
                    }
                }
                else {
                    Start-Sleep -Milliseconds 20
                }
            }
        }
        catch [System.Management.Automation.PipelineStoppedException] {
            # Normal shutdown
            return
        }
        catch {
            # Ignore other errors in background thread
        }
    }) | Out-Null
    
    # Store for cleanup
    $script:TuiState.InputRunspace = $runspace
    $script:TuiState.InputPowerShell = $ps
    $script:TuiState.InputAsyncResult = $ps.BeginInvoke()
    
    Write-Verbose "Background input thread started"
}

function Initialize-SafeLayoutEngines {
    try {
        $script:TuiState.Layouts = @{
            Grid = @{ Apply = { param($Components, $Options) } }
            Stack = @{ Apply = { param($Components, $Options) } }
            Dock = @{ Apply = { param($Components, $Options) } }
        }
        Write-Verbose "Layout engines initialized"
    } catch {
        Write-Warning "Layout engine initialization failed: $_"
        $script:TuiState.Layouts = @{}
    }
}

function Initialize-SafeComponentSystem {
    try {
        $script:TuiState.Components = @()
        $script:TuiState.FocusedComponent = $null
        Write-Verbose "Component system initialized"
    } catch {
        Write-Warning "Component system initialization failed: $_"
    }
}

function Process-TuiInput {
    if (-not $script:TuiState.InputQueue) { 
        # Synchronous input handling
        if ([Console]::KeyAvailable) {
            return [Console]::ReadKey($true)
        }
        return $null
    }

    $keyInfo = $null
    
    # Handle different queue types
    if ($script:TuiState.InputQueue -is [System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]]) {
        $keyInfo = [System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::None, $false, $false, $false)
        if ($script:TuiState.InputQueue.TryDequeue([ref]$keyInfo)) {
            return $keyInfo
        }
    } elseif ($script:TuiState.InputQueue -is [System.Collections.ArrayList]) {
        if ($script:TuiState.InputQueue.Count -gt 0) {
            try {
                $keyInfo = $script:TuiState.InputQueue[0]
                $script:TuiState.InputQueue.RemoveAt(0)
                return $keyInfo
            } catch {}
        }
    } elseif ($script:TuiState.InputQueue -is [array]) {
        # Synchronous fallback
        if ([Console]::KeyAvailable) {
            return [Console]::ReadKey($true)
        }
    }
    
    return $null
}

function global:Start-TuiLoop {
    param([hashtable]$InitialScreen = $null)

    try {
        # Only initialize if not already initialized
        if (-not $script:TuiState.BufferWidth -or $script:TuiState.BufferWidth -eq 0) {
            Initialize-TuiEngine
        }
        
        if ($InitialScreen) {
            Push-Screen -Screen $InitialScreen
        }
        
        # If no screen is active and no initial screen provided, we can't start
        if (-not $script:TuiState.CurrentScreen -and $script:TuiState.ScreenStack.Count -eq 0) {
            throw "No screen available to display. Push a screen before calling Start-TuiLoop or provide an InitialScreen parameter."
        }

        $script:TuiState.Running = $true
        
        while ($script:TuiState.Running) {
            try {
                # Process input
                $key = Process-TuiInput
                if ($key) {
                    $script:TuiState.LastActivity = [DateTime]::Now
                    
                    # Handle input with error protection
                    try {
                        if ($script:TuiState.CurrentScreen -and $script:TuiState.CurrentScreen.HandleInput) {
                            $result = & $script:TuiState.CurrentScreen.HandleInput -self $script:TuiState.CurrentScreen -Key $key
                            switch ($result) {
                                "Back" { Pop-Screen }
                                "Quit" { $script:TuiState.Running = $false }
                            }
                        }
                    } catch {
                        Write-Warning "Input handling error: $_"
                    }
                }

                # Render if dirty
                if ($script:TuiState.IsDirty) {
                    try {
                        Render-SafeFrame
                        $script:TuiState.IsDirty = $false
                    } catch {
                        Write-Warning "Render error: $_"
                    }
                }
                
                # Adaptive sleep
                $sleepTime = if (([DateTime]::Now - $script:TuiState.LastActivity).TotalSeconds -lt 2) { 16 } else { 50 }
                Start-Sleep -Milliseconds $sleepTime
            } catch {
                Write-Warning "Main loop error: $_"
                $script:TuiState.IsDirty = $true  # Force redraw on error
            }
        }
    }
    finally {
        Cleanup-TuiEngine
    }
}

function Render-SafeFrame {
    try {
        # Get background color safely
        $bgColor = [ConsoleColor]::Black
        if (Get-Command -Name "Get-ThemeColor" -ErrorAction SilentlyContinue) {
            try {
                $bgColor = Get-ThemeColor "Background"
            } catch {}
        }
        
        Clear-BackBuffer -BackgroundColor $bgColor
        
        # Render current screen with error protection
        if ($script:TuiState.CurrentScreen -and $script:TuiState.CurrentScreen.Render) {
            try {
                & $script:TuiState.CurrentScreen.Render -self $script:TuiState.CurrentScreen
            } catch {
                # Draw error message on screen
                Write-BufferString -X 2 -Y 2 -Text "Screen render error: $_" -ForegroundColor Red
            }
        }
        
        # Perform optimized render
        Render-BufferOptimized
        
    } catch {
        Write-Warning "Frame render error: $_"
    }
}

function global:Request-TuiRefresh {
    $script:TuiState.IsDirty = $true
}

function Cleanup-TuiEngine {
    try {
        Write-Verbose "Cleaning up TUI engine..."
        
        # Signal shutdown
        if ($script:TuiState.CancellationTokenSource) {
            try {
                if (-not $script:TuiState.CancellationTokenSource.IsCancellationRequested) {
                    $script:TuiState.CancellationTokenSource.Cancel()
                }
            } catch {}
        }

        # Clean up PowerShell instance
        if ($script:TuiState.InputPowerShell) {
            try {
                if ($script:TuiState.InputAsyncResult) {
                    $script:TuiState.InputPowerShell.EndInvoke($script:TuiState.InputAsyncResult)
                }
                $script:TuiState.InputPowerShell.Dispose()
            } catch {}
        }
        
        # Clean up runspace
        if ($script:TuiState.InputRunspace) {
            try {
                $script:TuiState.InputRunspace.Close()
                $script:TuiState.InputRunspace.Dispose()
            } catch {}
        }
        
        # Clean up cancellation token source
        if ($script:TuiState.CancellationTokenSource) {
            try {
                $script:TuiState.CancellationTokenSource.Dispose()
            } catch {}
        }

        # Reset console safely
        try {
            [Console]::CursorVisible = $true
            [Console]::ResetColor()
        } catch {}
        
        Write-Verbose "TUI engine cleanup completed"
    } catch {
        Write-Warning "TUI cleanup error: $_"
    }
}

#endregion

#region Screen Management

function global:Push-Screen {
    param([hashtable]$Screen)
    if (-not $Screen) { return }
    
    try {
        if ($script:TuiState.CurrentScreen) {
            if ($script:TuiState.CurrentScreen.OnExit) { 
                try {
                    & $script:TuiState.CurrentScreen.OnExit -self $script:TuiState.CurrentScreen
                } catch {
                    Write-Warning "Screen exit error: $_"
                }
            }
            $script:TuiState.ScreenStack.Push($script:TuiState.CurrentScreen)
        }
        
        $script:TuiState.CurrentScreen = $Screen
        
        if ($Screen.Init) { 
            try {
                & $Screen.Init -self $Screen 
            } catch {
                Write-Warning "Screen init error: $_"
            }
        }
        
        Request-TuiRefresh
        
        # Safe event publishing
        if (Get-Command -Name "Publish-Event" -ErrorAction SilentlyContinue) {
            try {
                Publish-Event -EventName "Screen.Pushed" -Data @{ ScreenName = $Screen.Name }
            } catch {}
        }
        
    } catch {
        Write-Warning "Push screen error: $_"
    }
}

function global:Pop-Screen {
    if ($script:TuiState.ScreenStack.Count -eq 0) { return $false }
    
    try {
        # Store the screen to exit before changing CurrentScreen
        $screenToExit = $script:TuiState.CurrentScreen
        
        # Pop the new screen from the stack
        $script:TuiState.CurrentScreen = $script:TuiState.ScreenStack.Pop()
        
        # Call lifecycle hooks in correct order
        if ($screenToExit -and $screenToExit.OnExit) { 
            try {
                & $screenToExit.OnExit -self $screenToExit
            } catch {
                Write-Warning "Screen exit error: $_"
            }
        }
        if ($script:TuiState.CurrentScreen -and $script:TuiState.CurrentScreen.OnResume) { 
            try {
                & $script:TuiState.CurrentScreen.OnResume -self $script:TuiState.CurrentScreen
            } catch {
                Write-Warning "Screen resume error: $_"
            }
        }
        
        Request-TuiRefresh
        
        # Safe event publishing
        if (Get-Command -Name "Publish-Event" -ErrorAction SilentlyContinue) {
            try {
                Publish-Event -EventName "Screen.Popped" -Data @{ ScreenName = $script:TuiState.CurrentScreen.Name }
            } catch {}
        }
        
        return $true
        
    } catch {
        Write-Warning "Pop screen error: $_"
        return $false
    }
}

#endregion

#region Buffer and Rendering

function GetBufferIndex {
    param([int]$X, [int]$Y)
    return $Y * $script:TuiState.BufferWidth + $X
}

function global:Clear-BackBuffer {
    param([ConsoleColor]$BackgroundColor = [ConsoleColor]::Black)
    
    try {
        $totalCells = $script:TuiState.BufferHeight * $script:TuiState.BufferWidth
        
        for ($i = 0; $i -lt $totalCells; $i++) {
            $script:TuiState.BackBuffer[$i] = New-SafeCell -BG $BackgroundColor
        }
    } catch {
        Write-Warning "Clear buffer error: $_"
    }
}

function global:Write-BufferString {
    param(
        [int]$X, 
        [int]$Y, 
        [string]$Text, 
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White, 
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black
    )
    
    try {
        if ($Y -lt 0 -or $Y -ge $script:TuiState.BufferHeight) { return }
        if ([string]::IsNullOrEmpty($Text)) { return }
        
        $currentX = $X
        foreach ($char in $Text.ToCharArray()) {
            if ($currentX -ge 0 -and $currentX -lt $script:TuiState.BufferWidth) {
                $index = GetBufferIndex -X $currentX -Y $Y
                if ($index -ge 0 -and $index -lt $script:TuiState.BackBuffer.Length) {
                    $script:TuiState.BackBuffer[$index] = New-SafeCell -Char $char -FG $ForegroundColor -BG $BackgroundColor
                }
            }
            $currentX++
        }
    } catch {
        Write-Warning "Write buffer string error: $_"
    }
}

function global:Write-BufferBox {
    param(
        [int]$X, 
        [int]$Y, 
        [int]$Width, 
        [int]$Height, 
        [string]$BorderStyle = "Single", 
        [ConsoleColor]$BorderColor = [ConsoleColor]::White, 
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black, 
        [string]$Title = ""
    )
    
    try {
        $borders = Get-BorderChars -Style $BorderStyle
        
        # Top border
        Write-BufferString -X $X -Y $Y -Text "$($borders.TopLeft)$($borders.Horizontal * ($Width - 2))$($borders.TopRight)" -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
        
        # Title
        if ($Title) {
            $titleText = " $Title "
            if ($titleText.Length > ($Width - 2)) { 
                $titleText = " $($Title.Substring(0, $Width - 5))... " 
            }
            $titleX = $X + [Math]::Floor(($Width - $titleText.Length) / 2)
            Write-BufferString -X $titleX -Y $Y -Text $titleText -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
        }
        
        # Sides and Fill
        for ($i = 1; $i -lt ($Height - 1); $i++) {
            Write-BufferString -X $X -Y ($Y + $i) -Text $borders.Vertical -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
            Write-BufferString -X ($X + 1) -Y ($Y + $i) -Text (' ' * ($Width - 2)) -BackgroundColor $BackgroundColor
            Write-BufferString -X ($X + $Width - 1) -Y ($Y + $i) -Text $borders.Vertical -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
        }
        
        # Bottom border
        Write-BufferString -X $X -Y ($Y + $Height - 1) -Text "$($borders.BottomLeft)$($borders.Horizontal * ($Width - 2))$($borders.BottomRight)" -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    } catch {
        Write-Warning "Write buffer box error: $_"
    }
}

function global:Render-BufferOptimized {
    try {
        $outputBuilder = New-Object System.Text.StringBuilder -ArgumentList 10000
        $lastFG = -1
        $lastBG = -1
        
        # Build ANSI output with change detection
        for ($y = 0; $y -lt $script:TuiState.BufferHeight; $y++) {
            # Position cursor at start of line
            $outputBuilder.Append("`e[$($y + 1);1H") | Out-Null
            
            for ($x = 0; $x -lt $script:TuiState.BufferWidth; $x++) {
                $index = GetBufferIndex -X $x -Y $y
                if ($index -ge $script:TuiState.BackBuffer.Length) { continue }
                
                $backCell = $script:TuiState.BackBuffer[$index]
                $frontCell = $script:TuiState.FrontBuffer[$index]
                
                # Skip if cell hasn't changed
                if ($backCell.Char -eq $frontCell.Char -and 
                    $backCell.FG -eq $frontCell.FG -and 
                    $backCell.BG -eq $frontCell.BG) {
                    continue
                }
                
                # Position cursor if we skipped cells
                if ($x -gt 0) {
                    $outputBuilder.Append("`e[$($y + 1);$($x + 1)H") | Out-Null
                }
                
                # Update colors if changed
                if ($backCell.FG -ne $lastFG -or $backCell.BG -ne $lastBG) {
                    $fgCode = Get-AnsiColorCode $backCell.FG
                    $bgCode = Get-AnsiColorCode $backCell.BG -IsBackground $true
                    $outputBuilder.Append("`e[${fgCode};${bgCode}m") | Out-Null
                    $lastFG = $backCell.FG
                    $lastBG = $backCell.BG
                }
                
                # Append character
                $outputBuilder.Append($backCell.Char) | Out-Null
                
                # Update front buffer
                $script:TuiState.FrontBuffer[$index] = New-SafeCell -Char $backCell.Char -FG $backCell.FG -BG $backCell.BG
            }
        }
        
        # Reset ANSI formatting and write to console
        $outputBuilder.Append("`e[0m") | Out-Null
        
        if ($outputBuilder.Length -gt 0) {
            [Console]::Write($outputBuilder.ToString())
        }
        
    } catch {
        Write-Warning "Render error: $_"
    }
}

#endregion

#region Utility Functions

function global:Get-BorderChars { 
    param([string]$Style = "Single") 
    $styles = @{ 
        Single = @{ 
            TopLeft='┌'; TopRight='┐'; BottomLeft='└'; BottomRight='┘'
            Horizontal='─'; Vertical='│' 
        }
        Double = @{ 
            TopLeft='╔'; TopRight='╗'; BottomLeft='╚'; BottomRight='╝'
            Horizontal='═'; Vertical='║' 
        }
        Rounded = @{ 
            TopLeft='╭'; TopRight='╮'; BottomLeft='╰'; BottomRight='╯'
            Horizontal='─'; Vertical='│' 
        } 
    }
    return if ($styles.ContainsKey($Style)) { $styles[$Style] } else { $styles.Single }
}

function Get-AnsiColorCode { 
    param([ConsoleColor]$Color, [bool]$IsBackground = $false) 
    $map = @{ 
        Black=30; DarkBlue=34; DarkGreen=32; DarkCyan=36
        DarkRed=31; DarkMagenta=35; DarkYellow=33; Gray=37
        DarkGray=90; Blue=94; Green=92; Cyan=96
        Red=91; Magenta=95; Yellow=93; White=97 
    }
    $code = $map[$Color.ToString()]
    if ($null -eq $code) { $code = 37 }  # Default to white
    if ($IsBackground) { $code + 10 } else { $code } 
}

function global:Write-StatusLine { 
    param(
        [string]$Text, 
        [ConsoleColor]$ForegroundColor = 'White', 
        [ConsoleColor]$BackgroundColor = 'DarkBlue'
    ) 
    try { 
        $y = $script:TuiState.BufferHeight
        [Console]::SetCursorPosition(0, $y)
        [Console]::ForegroundColor = $ForegroundColor
        [Console]::BackgroundColor = $BackgroundColor
        [Console]::Write($Text.PadRight([Console]::WindowWidth))
        [Console]::ResetColor() 
    } catch {
        Write-Warning "Status line error: $_"
    } 
}

# Fallback theme function
if (-not (Get-Command -Name "Get-ThemeColor" -ErrorAction SilentlyContinue)) {
    function global:Get-ThemeColor {
        param($ColorName, $Default = [ConsoleColor]::White)
        return $Default
    }
}

#endregion

# Export functions
$exportFunctions = @(
    'Start-TuiLoop', 'Request-TuiRefresh', 'Push-Screen', 'Pop-Screen',
    'Write-BufferString', 'Write-BufferBox', 'Clear-BackBuffer',
    'Write-StatusLine', 'Get-BorderChars', 'Get-ThemeColor'
)

Export-ModuleMember -Function $exportFunctions -Variable @('TuiState')
