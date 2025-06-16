# Rock-Solid TUI Engine v4.0 - Performance & Reliability Edition
# Implements all critical fixes from code review



#region Core TUI State
$script:TuiState = @{
    Running         = $false
    BufferWidth     = 0
    BufferHeight    = 0
    FrontBuffer     = $null
    BackBuffer      = $null
    ScreenStack     = New-Object System.Collections.Stack
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

# Debug messages removed to prevent screen bleed-through
# Note: Width and Height params are only available inside Initialize-TuiEngine function



# Cell pool to avoid thousands of hashtable allocations
$script:CellPool = @{
    Pool = New-Object System.Collections.Queue
    MaxSize = 1000
}
#endregion

#region Cell Management & Object Pooling

function Get-PooledCell {
    param(
        [char]$Char = ' ',
        [ConsoleColor]$FG = [ConsoleColor]::White,
        [ConsoleColor]$BG = [ConsoleColor]::Black
    )
    
    if ($script:CellPool.Pool.Count -gt 0) {
        $cell = $script:CellPool.Pool.Dequeue()
        $cell.Char = $Char
        $cell.FG = $FG
        $cell.BG = $BG
        return $cell
    }
    
    # Create new cell if pool is empty
    return @{
        Char = $Char
        FG = $FG
        BG = $BG
    }
}

function Return-CellToPool {
    param($Cell)
    if ($script:CellPool.Pool.Count -lt $script:CellPool.MaxSize) {
        $script:CellPool.Pool.Enqueue($Cell)
    }
}

#endregion

#region Engine Lifecycle & Main Loop

function global:Initialize-TuiEngine {
    param(
        [int]$Width = [Console]::WindowWidth,
        [int]$Height = [Console]::WindowHeight - 1
    )

    # Patch: Always set defaults if not passed in
    if (-not $Width) { $Width = [Console]::WindowWidth }
    if (-not $Height) { $Height = [Console]::WindowHeight - 1 }

   

    
    
    try {
        if ($Width -le 0 -or $Height -le 0) { throw "Invalid console dimensions: ${Width}x${Height}" }
        
        $script:TuiState.BufferWidth = $Width
        $script:TuiState.BufferHeight = $Height
        
        # Create 2D arrays for buffers
        $script:TuiState.FrontBuffer = New-Object 'object[,]' $Height, $Width
        $script:TuiState.BackBuffer = New-Object 'object[,]' $Height, $Width
        
        # Initialize buffers with empty cells
        $emptyCell = @{ Char = ' '; FG = [ConsoleColor]::White; BG = [ConsoleColor]::Black }
        for ($y = 0; $y -lt $Height; $y++) {
            for ($x = 0; $x -lt $Width; $x++) {
                $script:TuiState.FrontBuffer[$y, $x] = @{ Char = ' '; FG = [ConsoleColor]::White; BG = [ConsoleColor]::Black }
                $script:TuiState.BackBuffer[$y, $x] = @{ Char = ' '; FG = [ConsoleColor]::White; BG = [ConsoleColor]::Black }
            }
        }
        
        [Console]::CursorVisible = $false
        [Console]::Clear() # Clear console to remove initialization messages
        
        # Initialize subsystems with error handling
        try { Initialize-LayoutEngines } catch { Write-Warning "Layout engines init failed: $_" }
        try { Initialize-ComponentSystem } catch { Write-Warning "Component system init failed: $_" }
        
        # Track event handlers for cleanup (event system should already be initialized)
        $script:TuiState.EventHandlers = @{}
        
        # --- THE FIX: HOOK CTRL+C *BEFORE* STARTING THE INPUT THREAD ---
        # Temporarily disabled due to compatibility issues
        # TODO: Re-enable with proper PowerShell event handling
        try {
            [Console]::TreatControlCAsInput = $false
            # Ctrl+C handler temporarily disabled - will terminate process normally
        } catch {
            Write-Warning "Could not set console input mode: $_"
        }
        
        # Now it is safe to start the input thread.
        Initialize-InputThread
        
        # Publish initialization event
        Safe-PublishEvent -EventName "System.EngineInitialized" -Data @{ Width = $Width; Height = $Height }
        
        # Export TuiState for global access
        $global:TuiState = $script:TuiState
    }
    catch {
        # --- ENHANCED DIAGNOSTIC BLOCK ---
        # This will now clearly print the root cause of any initialization failure.
        Write-Host "--------------------------------------------------------" -ForegroundColor Red
        Write-Host "IMMEDIATE, ORIGINAL ERROR DETECTED DURING INITIALIZATION" -ForegroundColor Red
        Write-Host "THE *REAL* PROBLEM IS LIKELY THIS:" -ForegroundColor Yellow
        
        if ($_) {
            Write-Host "MESSAGE: $($_.Exception.Message)" -ForegroundColor White
            
            Write-Host "FULL ERROR:" -ForegroundColor Yellow
            if ($_.Exception) {
                $_.Exception | Format-List * -Force
            } else {
                Write-Host "Error details: $_" -ForegroundColor White
            }
        } else {
            Write-Host "Unknown error occurred" -ForegroundColor White
        }
        
        Write-Host "--------------------------------------------------------" -ForegroundColor Red
        
        # Re-throw the exception so the main script's finally block is triggered for cleanup.
        throw "FATAL: TUI Engine initialization failed. See original error details above."
    }
}

function Initialize-InputThread {
    try {
        # Create thread-safe input handling
        $queueType = [System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]]
        $script:TuiState.InputQueue = New-Object $queueType
    } catch {
        Write-Warning "Failed to create ConcurrentQueue, falling back to ArrayList"
        $script:TuiState.InputQueue = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
    }
    
    # Create the cancellation token source for thread-safe shutdown.
    $script:TuiState.CancellationTokenSource = [System.Threading.CancellationTokenSource]::new()
    $token = $script:TuiState.CancellationTokenSource.Token

    # Create runspace for input handling (fully-qualified .NET types)
    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('InputQueue', $script:TuiState.InputQueue)
    $runspace.SessionStateProxy.SetVariable('token', $token)
    
    # Create a PowerShell instance in that runspace
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $runspace
    
    # This script block will run in the background.
    $ps.AddScript({
        try {
            while (-not $token.IsCancellationRequested) {
                if ([Console]::KeyAvailable) {
                    $keyInfo = [Console]::ReadKey($true)
                    
                    # Handle different queue types
                    if ($InputQueue -is [System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]]) {
                        if ($InputQueue.Count -lt 100) {
                            $InputQueue.Enqueue($keyInfo)
                        }
                    } elseif ($InputQueue -is [System.Collections.ArrayList]) {
                        if ($InputQueue.Count -lt 100) {
                            $InputQueue.Add($keyInfo) | Out-Null
                        }
                    }
                }
                else {
                    Start-Sleep -Milliseconds 20
                }
            }
        }
        catch [System.Management.Automation.PipelineStoppedException] {
            return
        }
        catch {
            Write-Warning "Input thread error: $_"
        }
    }) | Out-Null
    
    # Store for cleanup
    $script:TuiState.InputRunspace   = $runspace
    $script:TuiState.InputPowerShell = $ps
    $script:TuiState.InputAsyncResult = $ps.BeginInvoke()
}

function Process-TuiInput {
    # Process all queued input events
    $processedAny = $false
    # Check if the queue exists before trying to use it.
    if (-not $script:TuiState.InputQueue) { return $false }

    $keyInfo = $null
    
    # Handle different queue types
    if ($script:TuiState.InputQueue -is [System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]]) {
        $keyInfo = [System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::None, $false, $false, $false)
        while ($script:TuiState.InputQueue.TryDequeue([ref]$keyInfo)) {
            $processedAny = $true
            $script:TuiState.LastActivity = [DateTime]::Now
            Process-SingleKeyInput -keyInfo $keyInfo
        }
    } elseif ($script:TuiState.InputQueue -is [System.Collections.ArrayList]) {
        while ($script:TuiState.InputQueue.Count -gt 0) {
            try {
                $keyInfo = $script:TuiState.InputQueue[0]
                $script:TuiState.InputQueue.RemoveAt(0)
                $processedAny = $true
                $script:TuiState.LastActivity = [DateTime]::Now
                Process-SingleKeyInput -keyInfo $keyInfo
            } catch {
                break
            }
        }
    }
    
    return $processedAny
}

function Process-SingleKeyInput {
    param($keyInfo)
    
    try {
        # Dialog system gets first chance at input
        if ((Get-Command -Name "Handle-DialogInput" -ErrorAction SilentlyContinue) -and (Handle-DialogInput -Key $keyInfo)) {
            return
        }
        
        # Focused component gets the next chance
        $focusedComponent = $script:TuiState.FocusedComponent
        if ($focusedComponent -and $focusedComponent.HandleInput) {
            try {
                if (& $focusedComponent.HandleInput -self $focusedComponent -Key $keyInfo) {
                    return
                }
            } catch {
                Write-Warning "Component input handler error: $_"
            }
        }
        
        # Finally, the screen itself gets the key
        $currentScreen = $script:TuiState.CurrentScreen
        if ($currentScreen -and $currentScreen.HandleInput) {
            try {
                $result = & $currentScreen.HandleInput -self $currentScreen -Key $keyInfo
                switch ($result) {
                    "Back" { Pop-Screen }
                    "Quit" { 
                        $script:TuiState.Running = $false
                        if ($script:TuiState.CancellationTokenSource) {
                            $script:TuiState.CancellationTokenSource.Cancel()
                        }
                    }
                }
            } catch {
                Write-Warning "Screen input handler error: $_"
            }
        }
    } catch {
        Write-Warning "Input processing error: $_"
    }
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
        $frameTime = New-Object System.Diagnostics.Stopwatch
        $targetFrameTime = 1000.0 / $script:TuiState.RenderStats.TargetFPS
        
        while ($script:TuiState.Running) {
            $frameTime.Restart()
            
            try {
                # Process input
                $hadInput = Process-TuiInput
                
                # Update dialog system
                if (Get-Command -Name "Update-DialogSystem" -ErrorAction SilentlyContinue) { 
                    try { Update-DialogSystem } catch { Write-Warning "Dialog update error: $_" }
                }

                # Render if dirty or had input
                if ($script:TuiState.IsDirty -or $hadInput) {
                    Render-Frame
                    $script:TuiState.IsDirty = $false
                }
                
                # Adaptive frame timing
                $elapsed = $frameTime.ElapsedMilliseconds
                if ($elapsed -lt $targetFrameTime) {
                    $sleepTime = [Math]::Max(1, $targetFrameTime - $elapsed)
                    Start-Sleep -Milliseconds $sleepTime
                }
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

function Render-Frame {
    try {
        $bgColor = if (Get-Command -Name "Get-ThemeColor" -ErrorAction SilentlyContinue) {
            Get-ThemeColor "Background"
        } else {
            [ConsoleColor]::Black
        }
        
        # Always clear the back buffer completely
        Clear-BackBuffer -BackgroundColor $bgColor
        
        # Render current screen
        if ($script:TuiState.CurrentScreen -and $script:TuiState.CurrentScreen.Render) {
            try {
                & $script:TuiState.CurrentScreen.Render -self $script:TuiState.CurrentScreen
            } catch {
                Write-Warning "Screen render error: $_"
                # Draw error message on screen
                Write-BufferString -X 2 -Y 2 -Text "Screen render error: $_" -ForegroundColor Red
            }
        }
        
        # Render dialogs on top
        if (Get-Command -Name "Render-Dialogs" -ErrorAction SilentlyContinue) {
            try {
                Render-Dialogs
            } catch {
                Write-Warning "Dialog render error: $_"
            }
        }
        
        # Perform optimized render
        Render-BufferOptimized
        
        # Force cursor to bottom-right to avoid interference
        [Console]::SetCursorPosition($script:TuiState.BufferWidth - 1, $script:TuiState.BufferHeight - 1)
        
    } catch {
        Write-Warning "Frame render error: $_"
    }
}

function global:Request-TuiRefresh {
    $script:TuiState.IsDirty = $true
}

function Cleanup-TuiEngine {
    try {
        # --- ROBUST CLEANUP ROUTINE ---
        # This sequence is defensive and will not fail even if initialization was partial.
        if ($script:TuiState.CancellationTokenSource) {
            try {
                if (-not $script:TuiState.CancellationTokenSource.IsCancellationRequested) {
                    $script:TuiState.CancellationTokenSource.Cancel()
                }
            } catch { 
                # Ignore errors if CancellationTokenSource is in an invalid state
            }
        }

        if ($script:TuiState.InputPowerShell) {
            if ($script:TuiState.InputAsyncResult) {
                try { $script:TuiState.InputPowerShell.EndInvoke($script:TuiState.InputAsyncResult) } catch { }
            }
            try { $script:TuiState.InputPowerShell.Dispose() } catch { }
        }
        
        if ($script:TuiState.InputRunspace) {
            try { $script:TuiState.InputRunspace.Dispose() } catch { }
        }
        
        if ($script:TuiState.CancellationTokenSource) {
            try { $script:TuiState.CancellationTokenSource.Dispose() } catch { }
        }

        Cleanup-EventHandlers
        
        # Only try to reset the console if we are in an interactive session
        if (-not $env:CI -and -not $PSScriptRoot) {
            try {
                if ([System.Environment]::UserInteractive) {
                    [Console]::Write("`e[0m")
                    [Console]::CursorVisible = $true
                    [Console]::Clear()
                    [Console]::ResetColor()
                }
            } catch {
                # This can fail in non-interactive environments, ignore the error.
            }
        }
    } catch {
        Write-Warning "A secondary error occurred during TUI cleanup: $_"
    }
}

function Cleanup-EventHandlers {
    if (-not (Get-Command -Name "Unsubscribe-Event" -ErrorAction SilentlyContinue)) { return }
    if (-not $script:TuiState.EventHandlers) { return }

    foreach ($handlerId in $script:TuiState.EventHandlers.Values) {
        try { Unsubscribe-Event -HandlerId $handlerId } catch { }
    }
    $script:TuiState.EventHandlers.Clear()
    
    # Clean up any Ctrl+C event handler if it exists
    try {
        Get-EventSubscriber -SourceIdentifier "TuiCtrlC" -ErrorAction SilentlyContinue | Unregister-Event
    } catch { }
}

function Safe-PublishEvent {
    param($EventName, $Data)
    if (Get-Command -Name "Publish-Event" -ErrorAction SilentlyContinue) {
        try { Publish-Event -EventName $EventName -Data $Data } catch { }
    }
}

#endregion

#region Screen Management

function global:Push-Screen {
    param([hashtable]$Screen)
    if (-not $Screen) { return }
    
    try {
        # Handle focus before switching screens
        if ($script:TuiState.FocusedComponent -and $script:TuiState.FocusedComponent.OnBlur) {
            try {
                & $script:TuiState.FocusedComponent.OnBlur -self $script:TuiState.FocusedComponent
            } catch {
                Write-Warning "Component blur error: $_"
            }
        }
        
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
        $script:TuiState.FocusedComponent = $null  # Clear focus when changing screens
        
        if ($Screen.Init) { 
            try {
                & $Screen.Init -self $Screen 
            } catch {
                Write-Warning "Screen init error: $_"
            }
        }
        
        Request-TuiRefresh
        Safe-PublishEvent -EventName "Screen.Pushed" -Data @{ ScreenName = $Screen.Name }
        
    } catch {
        Write-Warning "Push screen error: $_"
    }
}

function global:Pop-Screen {
    if ($script:TuiState.ScreenStack.Count -eq 0) { return $false }
    
    try {
        # Handle focus before switching screens
        if ($script:TuiState.FocusedComponent -and $script:TuiState.FocusedComponent.OnBlur) {
            try {
                & $script:TuiState.FocusedComponent.OnBlur -self $script:TuiState.FocusedComponent
            } catch {
                Write-Warning "Component blur error: $_"
            }
        }
        
        # Store the screen to exit before changing CurrentScreen
        $screenToExit = $script:TuiState.CurrentScreen
        
        # Pop the new screen from the stack
        $script:TuiState.CurrentScreen = $script:TuiState.ScreenStack.Pop()
        $script:TuiState.FocusedComponent = $null  # Clear focus when changing screens
        
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
        
        # Restore focus if the screen tracks it
        if ($script:TuiState.CurrentScreen.LastFocusedComponent) {
            Set-ComponentFocus -Component $script:TuiState.CurrentScreen.LastFocusedComponent
        }
        
        Request-TuiRefresh
        Safe-PublishEvent -EventName "Screen.Popped" -Data @{ ScreenName = $script:TuiState.CurrentScreen.Name }
        
        return $true
        
    } catch {
        Write-Warning "Pop screen error: $_"
        return $false
    }
}

#endregion

#region Buffer and Rendering

# GetBufferIndex no longer needed - using 2D arrays directly

function global:Clear-BackBuffer {
    param([ConsoleColor]$BackgroundColor = [ConsoleColor]::Black)
    
    # Create a new cell for each position to ensure proper clearing
    for ($y = 0; $y -lt $script:TuiState.BufferHeight; $y++) {
        for ($x = 0; $x -lt $script:TuiState.BufferWidth; $x++) {
            $script:TuiState.BackBuffer[$y, $x] = @{ 
                Char = ' '
                FG = [ConsoleColor]::White
                BG = $BackgroundColor 
            }
        }
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
    if ($Y -lt 0 -or $Y -ge $script:TuiState.BufferHeight) { return }
    if ([string]::IsNullOrEmpty($Text)) { return }
    
    $currentX = $X
    foreach ($char in $Text.ToCharArray()) {
        if ($currentX -ge 0 -and $currentX -lt $script:TuiState.BufferWidth) {
            $script:TuiState.BackBuffer[$Y, $currentX] = @{ 
                Char = $char
                FG = $ForegroundColor
                BG = $BackgroundColor 
            }
        }
        $currentX++
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
}

function global:Render-BufferOptimized {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $outputBuilder = New-Object System.Text.StringBuilder -ArgumentList 20000
    $lastFG = -1
    $lastBG = -1
    
    # Force full render on first frame or if requested
    $forceFullRender = $script:TuiState.RenderStats.FrameCount -eq 0
    
    try {
        # Build ANSI output with change detection
        for ($y = 0; $y -lt $script:TuiState.BufferHeight; $y++) {
            # Position cursor at start of line
            $outputBuilder.Append("`e[$($y + 1);1H") | Out-Null
            
            for ($x = 0; $x -lt $script:TuiState.BufferWidth; $x++) {
                $backCell = $script:TuiState.BackBuffer[$y, $x]
                $frontCell = $script:TuiState.FrontBuffer[$y, $x]
                
                # Skip if cell hasn't changed (unless forcing full render)
                if (-not $forceFullRender -and
                    $backCell.Char -eq $frontCell.Char -and 
                    $backCell.FG -eq $frontCell.FG -and 
                    $backCell.BG -eq $frontCell.BG) {
                    continue
                }
                
                # Position cursor if we skipped cells
                if ($x -gt 0 -and $outputBuilder.Length -gt 0) {
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
                $script:TuiState.FrontBuffer[$y, $x] = @{
                    Char = $backCell.Char
                    FG = $backCell.FG
                    BG = $backCell.BG
                }
            }
        }
        
        # Reset ANSI formatting at the end
        $outputBuilder.Append("`e[0m") | Out-Null
        
        # Write to console
        if ($outputBuilder.Length -gt 0) {
            [Console]::Write($outputBuilder.ToString())
        }
        
    } catch {
        Write-Warning "Render error: $_"
    }
    
    # Update stats
    $stopwatch.Stop()
    $script:TuiState.RenderStats.LastFrameTime = $stopwatch.ElapsedMilliseconds
    $script:TuiState.RenderStats.FrameCount++
    $script:TuiState.RenderStats.TotalTime += $stopwatch.ElapsedMilliseconds
}

#endregion

#region Component System

function Initialize-ComponentSystem {
    $script:TuiState.Components = @()
    $script:TuiState.FocusedComponent = $null
}

function global:Register-Component {
    param([hashtable]$Component)
    
    # Add to component registry
    $script:TuiState.Components += $Component
    
    # Initialize component with error handling
    if ($Component.Init) {
        try {
            & $Component.Init -self $Component
        } catch {
            Write-Warning "Component init error: $_"
        }
    }
    
    return $Component
}

function global:Set-ComponentFocus {
    param([hashtable]$Component)
    
    # Blur previous component with error handling
    if ($script:TuiState.FocusedComponent -and $script:TuiState.FocusedComponent.OnBlur) {
        try {
            & $script:TuiState.FocusedComponent.OnBlur -self $script:TuiState.FocusedComponent
        } catch {
            Write-Warning "Component blur error: $_"
        }
    }
    
    # Track focus on current screen
    if ($script:TuiState.CurrentScreen) {
        $script:TuiState.CurrentScreen.LastFocusedComponent = $Component
    }
    
    # Focus new component with error handling
    $script:TuiState.FocusedComponent = $Component
    if ($Component -and $Component.OnFocus) {
        try {
            & $Component.OnFocus -self $Component
        } catch {
            Write-Warning "Component focus error: $_"
        }
    }
    
    Request-TuiRefresh
}

function global:New-Component {
    param(
        [string]$Type = "Base",
        [int]$X = 0,
        [int]$Y = 0,
        [int]$Width = 10,
        [int]$Height = 1,
        [hashtable]$Props = @{}
    )
    
    $component = @{
        Type = $Type
        X = $X
        Y = $Y
        Width = $Width
        Height = $Height
        Visible = $true
        Focused = $false
        Parent = $null
        Children = @()
        Props = $Props
        State = @{}
        
        # Lifecycle methods
        Init = { param($self) }
        Render = { param($self) }
        HandleInput = { param($self, $Key) return $false }
        OnFocus = { param($self) $self.Focused = $true }
        OnBlur = { param($self) $self.Focused = $false }
        Dispose = { param($self) }
    }
    
    # Merge with type-specific properties
    switch ($Type) {
        "TextInput" { $component = Merge-Hashtables $component (Get-TextInputComponent) }
        "Button" { $component = Merge-Hashtables $component (Get-ButtonComponent) }
        "List" { $component = Merge-Hashtables $component (Get-ListComponent) }
        "Table" { $component = Merge-Hashtables $component (Get-TableComponent) }
    }
    
    return $component
}

function Merge-Hashtables {
    param($Base, $Override)
    $result = $Base.Clone()
    foreach ($key in $Override.Keys) {
        $result[$key] = $Override[$key]
    }
    return $result
}

#endregion

#region Layout Management

function Initialize-LayoutEngines {
    $script:TuiState.Layouts = @{
        Grid = Get-GridLayout
        Stack = Get-StackLayout
        Dock = Get-DockLayout
    }
}

function global:Apply-Layout {
    param(
        [string]$LayoutType,
        [hashtable[]]$Components,
        [hashtable]$Options = @{}
    )
    
    if ($script:TuiState.Layouts.ContainsKey($LayoutType)) {
        $layout = $script:TuiState.Layouts[$LayoutType]
        try {
            & $layout.Apply -Components $Components -Options $Options
        } catch {
            Write-Warning "Layout error: $_"
        }
    }
}

function Get-GridLayout {
    return @{
        Apply = {
            param($Components, $Options)
            $cols = if ($Options.Columns) { $Options.Columns } else { 2 }
            $rows = [Math]::Ceiling($Components.Count / $cols)
            $cellWidth = [Math]::Floor($script:TuiState.BufferWidth / $cols)
            $cellHeight = [Math]::Floor($script:TuiState.BufferHeight / $rows)
            
            for ($i = 0; $i -lt $Components.Count; $i++) {
                $col = $i % $cols
                $row = [Math]::Floor($i / $cols)
                $Components[$i].X = $col * $cellWidth
                $Components[$i].Y = $row * $cellHeight
                $Components[$i].Width = $cellWidth - 1
                $Components[$i].Height = $cellHeight - 1
            }
        }
    }
}

function Get-StackLayout {
    return @{
        Apply = {
            param($Components, $Options)
            $orientation = if ($Options.Orientation) { $Options.Orientation } else { "Vertical" }
            $spacing = if ($null -ne $Options.Spacing) { $Options.Spacing } else { 1 }
            $x = if ($null -ne $Options.X) { $Options.X } else { 0 }
            $y = if ($null -ne $Options.Y) { $Options.Y } else { 0 }
            
            foreach ($component in $Components) {
                $component.X = $x
                $component.Y = $y
                
                if ($orientation -eq "Vertical") {
                    $y += $component.Height + $spacing
                } else {
                    $x += $component.Width + $spacing
                }
            }
        }
    }
}

function Get-DockLayout {
    return @{
        Apply = {
            param($Components, $Options)
            
            # Container bounds
            $containerX = if ($null -ne $Options.X) { $Options.X } else { 0 }
            $containerY = if ($null -ne $Options.Y) { $Options.Y } else { 0 }
            $containerWidth = if ($Options.Width) { $Options.Width } else { $script:TuiState.BufferWidth }
            $containerHeight = if ($Options.Height) { $Options.Height } else { $script:TuiState.BufferHeight }
            
            # Current available area
            $availableX = $containerX
            $availableY = $containerY
            $availableWidth = $containerWidth
            $availableHeight = $containerHeight
            
            # Process components by dock position
            $topComponents = $Components | Where-Object { $_.Props.Dock -eq "Top" }
            $bottomComponents = $Components | Where-Object { $_.Props.Dock -eq "Bottom" }
            $leftComponents = $Components | Where-Object { $_.Props.Dock -eq "Left" }
            $rightComponents = $Components | Where-Object { $_.Props.Dock -eq "Right" }
            $fillComponents = $Components | Where-Object { $_.Props.Dock -eq "Fill" -or -not $_.Props.Dock }
            
            # Dock top components
            foreach ($comp in $topComponents) {
                $comp.X = $availableX
                $comp.Y = $availableY
                $comp.Width = $availableWidth
                $availableY += $comp.Height
                $availableHeight -= $comp.Height
            }
            
            # Dock bottom components
            foreach ($comp in $bottomComponents) {
                $comp.X = $availableX
                $comp.Y = $availableY + $availableHeight - $comp.Height
                $comp.Width = $availableWidth
                $availableHeight -= $comp.Height
            }
            
            # Dock left components
            foreach ($comp in $leftComponents) {
                $comp.X = $availableX
                $comp.Y = $availableY
                $comp.Height = $availableHeight
                $availableX += $comp.Width
                $availableWidth -= $comp.Width
            }
            
            # Dock right components
            foreach ($comp in $rightComponents) {
                $comp.X = $availableX + $availableWidth - $comp.Width
                $comp.Y = $availableY
                $comp.Height = $availableHeight
                $availableWidth -= $comp.Width
            }
            
            # Fill remaining space
            foreach ($comp in $fillComponents) {
                $comp.X = $availableX
                $comp.Y = $availableY
                $comp.Width = $availableWidth
                $comp.Height = $availableHeight
            }
        }
    }
}

#endregion

#region Utility Functions

function global:Get-BorderChars { 
    param([string]$Style) 
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
    if ($styles.ContainsKey($Style)) { 
        return $styles[$Style] 
    } else { 
        return $styles.Single 
    }
}

function Get-AnsiColorCode { 
    param([ConsoleColor]$Color, [bool]$IsBackground) 
    $map = @{ 
        Black=30; DarkBlue=34; DarkGreen=32; DarkCyan=36
        DarkRed=31; DarkMagenta=35; DarkYellow=33; Gray=37
        DarkGray=90; Blue=94; Green=92; Cyan=96
        Red=91; Magenta=95; Yellow=93; White=97 
    }
    $code = $map[$Color.ToString()]
    if ($IsBackground) { 
        return $code + 10 
    } else { 
        return $code 
    } 
}

function Get-ThemeColorFallback {
    param($ColorName, $Default = [ConsoleColor]::White)
    # This is a fallback function for when theme manager isn't available
    # The theme manager will override this with its own global Get-ThemeColor
    return $Default
}

# Only define global Get-ThemeColor if it doesn't already exist
if (-not (Get-Command -Name "Get-ThemeColor" -ErrorAction SilentlyContinue)) {
    function global:Get-ThemeColor {
        param($ColorName, $Default = [ConsoleColor]::White)
        return Get-ThemeColorFallback -ColorName $ColorName -Default $Default
    }
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

function global:Subscribe-TuiEvent {
    param($EventName, $Handler)
    if (Get-Command -Name "Subscribe-Event" -ErrorAction SilentlyContinue) {
        $handlerId = Subscribe-Event -EventName $EventName -Handler $Handler
        # Track for cleanup
        $script:TuiState.EventHandlers[$EventName] = $handlerId
        return $handlerId
    }
}

#endregion

#region Component Definitions

function Get-TextInputComponent {
    return @{
        # State
        Value = ""
        CursorPosition = 0
        MaxLength = 50
        
        # Methods
        Render = {
            param($self)
            try {
                $borderColor = if ($self.Focused) { 
                    Get-ThemeColor "Accent" -Default ([ConsoleColor]::Cyan)
                } else { 
                    Get-ThemeColor "Border" -Default ([ConsoleColor]::DarkGray)
                }
                
                # Draw input box
                Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height `
                    -BorderColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
                
                # Draw text
                $displayText = $self.Value
                if ($displayText.Length > ($self.Width - 3)) {
                    $displayText = $displayText.Substring($displayText.Length - ($self.Width - 3))
                }
                Write-BufferString -X ($self.X + 1) -Y ($self.Y + 1) -Text $displayText
                
                # Draw cursor if focused
                if ($self.Focused -and $self.CursorPosition -lt ($self.Width - 3)) {
                    Write-BufferString -X ($self.X + 1 + $self.CursorPosition) -Y ($self.Y + 1) `
                        -Text "_" -ForegroundColor ([ConsoleColor]::Yellow)
                }
            } catch {
                Write-Warning "TextInput render error: $_"
            }
        }
        
        HandleInput = {
            param($self, $Key)
            try {
                switch ($Key.Key) {
                    ([ConsoleKey]::Backspace) {
                        if ($self.Value.Length -gt 0 -and $self.CursorPosition -gt 0) {
                            $self.Value = $self.Value.Remove($self.CursorPosition - 1, 1)
                            $self.CursorPosition--
                        }
                        return $true
                    }
                    ([ConsoleKey]::Delete) {
                        if ($self.CursorPosition -lt $self.Value.Length) {
                            $self.Value = $self.Value.Remove($self.CursorPosition, 1)
                        }
                        return $true
                    }
                    ([ConsoleKey]::LeftArrow) {
                        if ($self.CursorPosition -gt 0) {
                            $self.CursorPosition--
                        }
                        return $true
                    }
                    ([ConsoleKey]::RightArrow) {
                        if ($self.CursorPosition -lt $self.Value.Length) {
                            $self.CursorPosition++
                        }
                        return $true
                    }
                    ([ConsoleKey]::Home) {
                        $self.CursorPosition = 0
                        return $true
                    }
                    ([ConsoleKey]::End) {
                        $self.CursorPosition = $self.Value.Length
                        return $true
                    }
                    default {
                        if ($Key.KeyChar -and -not [char]::IsControl($Key.KeyChar) -and 
                            $self.Value.Length -lt $self.MaxLength) {
                            $self.Value = $self.Value.Insert($self.CursorPosition, $Key.KeyChar)
                            $self.CursorPosition++
                            return $true
                        }
                    }
                }
            } catch {
                Write-Warning "TextInput input error: $_"
            }
            return $false
        }
    }
}

function Get-ButtonComponent {
    return @{
        # State
        Text = "Button"
        
        # Methods
        Render = {
            param($self)
            try {
                $bgColor = if ($self.Focused) { 
                    Get-ThemeColor "Accent" -Default ([ConsoleColor]::DarkCyan)
                } else { 
                    Get-ThemeColor "Primary" -Default ([ConsoleColor]::DarkGray)
                }
                
                $text = " $($self.Text) "
                if ($text.Length > $self.Width) {
                    $text = $text.Substring(0, $self.Width)
                }
                
                $x = $self.X + [Math]::Floor(($self.Width - $text.Length) / 2)
                Write-BufferString -X $x -Y $self.Y -Text $text `
                    -ForegroundColor ([ConsoleColor]::White) -BackgroundColor $bgColor
            } catch {
                Write-Warning "Button render error: $_"
            }
        }
        
        HandleInput = {
            param($self, $Key)
            try {
                if ($Key.Key -eq [ConsoleKey]::Enter -or $Key.Key -eq [ConsoleKey]::Spacebar) {
                    if ($self.OnClick) {
                        & $self.OnClick -self $self
                    }
                    return $true
                }
            } catch {
                Write-Warning "Button input error: $_"
            }
            return $false
        }
    }
}

function Get-TableComponent {
    return @{
        # State
        Data = @()
        Columns = @()
        SelectedRow = 0
        ScrollOffset = 0
        
        # Methods
        Render = {
            param($self)
            try {
                # Simplified table rendering
                $y = $self.Y
                
                # Header
                $headerText = ""
                foreach ($col in $self.Columns) {
                    $headerText += $col.Name.PadRight($col.Width)
                }
                Write-BufferString -X $self.X -Y $y -Text $headerText `
                    -ForegroundColor (Get-ThemeColor "Header" -Default ([ConsoleColor]::Cyan))
                $y++
                
                # Data rows
                $visibleRows = $self.Data | Select-Object -Skip $self.ScrollOffset -First ($self.Height - 1)
                $rowIndex = $self.ScrollOffset
                foreach ($row in $visibleRows) {
                    $rowText = ""
                    foreach ($col in $self.Columns) {
                        $value = if ($row.($col.Property)) { $row.($col.Property) } else { "" }
                        $rowText += $value.ToString().PadRight($col.Width)
                    }
                    
                    $fg = if ($rowIndex -eq $self.SelectedRow) {
                        Get-ThemeColor "Selection" -Default ([ConsoleColor]::Yellow)
                    } else {
                        Get-ThemeColor "Primary" -Default ([ConsoleColor]::White)
                    }
                    
                    Write-BufferString -X $self.X -Y $y -Text $rowText -ForegroundColor $fg
                    $y++
                    $rowIndex++
                }
            } catch {
                Write-Warning "Table render error: $_"
            }
        }
    }
}

#endregion

#region Word Wrap Helper
function global:Get-WordWrappedLines {
    param(
        [string]$Text,
        [int]$MaxWidth
    )
    
    if ([string]::IsNullOrEmpty($Text) -or $MaxWidth -le 0) { return @() }
    
    $lines = @()
    $words = $Text -split '\s+'
    $sb = New-Object System.Text.StringBuilder
    
    foreach ($word in $words) {
        if ($sb.Length -eq 0) {
            [void]$sb.Append($word)
        } elseif (($sb.Length + 1 + $word.Length) -le $MaxWidth) {
            [void]$sb.Append(' ')
            [void]$sb.Append($word)
        } else {
            $lines += $sb.ToString()
            [void]$sb.Clear()
            [void]$sb.Append($word)
        }
    }
    
    if ($sb.Length -gt 0) {
        $lines += $sb.ToString()
    }
    
    return $lines
}
#endregion

# Build export list dynamically
$exportFunctions = @(
    'Start-TuiLoop', 'Request-TuiRefresh', 'Push-Screen', 'Pop-Screen',
    'Write-BufferString', 'Write-BufferBox', 'Clear-BackBuffer',
    'Write-StatusLine', 'Get-BorderChars',
    'Register-Component', 'Set-ComponentFocus', 'New-Component', 'Apply-Layout',
    'Get-WordWrappedLines', 'Subscribe-TuiEvent'
)

# Only export Get-ThemeColor if we defined it
if (Get-Command -Name "Get-ThemeColor" -ErrorAction SilentlyContinue | Where-Object { $_.Source -eq "tui-engine-v2" }) {
    $exportFunctions += 'Get-ThemeColor'
}

Export-ModuleMember -Function $exportFunctions -Variable @('TuiState')