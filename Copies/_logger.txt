# Enhanced Granular Logger Module for PMC Terminal
# Provides EXTREMELY detailed logging functionality to track down all issues

$script:LogPath = $null
$script:LogLevel = "Debug"  # Set to most verbose by default
$script:LogQueue = @()
$script:MaxLogSize = 5MB  # Increased for detailed logging
$script:LogInitialized = $false
$script:CallDepth = 0
$script:TraceAllCalls = $true

function global:Initialize-Logger {
    param(
        [string]$LogDirectory = (Join-Path $env:TEMP "PMCTerminal"),
        [string]$LogFileName = "pmc_terminal_{0:yyyy-MM-dd}.log" -f (Get-Date),
        [string]$Level = "Debug"
    )
    
    try {
        # Create log directory if it doesn't exist
        if (-not (Test-Path $LogDirectory)) {
            New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
        }
        
        $script:LogPath = Join-Path $LogDirectory $LogFileName
        $script:LogLevel = $Level
        $script:LogInitialized = $true
        
        # Write initialization message with full system context
        Write-Log -Level Info -Message "Logger initialized" -Data @{
            LogPath = $script:LogPath
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            OS = "$($PSVersionTable.OS)"
            ProcessId = $PID
            InitializedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        }
        
    } catch {
        Write-Warning "Failed to initialize logger: $_"
        $script:LogInitialized = $false
    }
}

function global:Write-Log {
    param(
        [ValidateSet("Debug", "Verbose", "Info", "Warning", "Error", "Trace")]
        [string]$Level = "Info",
        [Parameter(Mandatory)]
        [string]$Message,
        [object]$Data = $null,
        [switch]$Force  # Force logging even if level is below threshold
    )
    
    # Skip if logger not initialized, unless this is Force logging
    if (-not $script:LogInitialized -and -not $Force) { return }
    
    $levelPriority = @{
        Debug = 0
        Trace = 0
        Verbose = 1
        Info = 2
        Warning = 3
        Error = 4
    }
    
    if (-not $Force -and $levelPriority[$Level] -lt $levelPriority[$script:LogLevel]) { return }
    
    try {
        # Get call stack information for precise location tracking
        $callStack = Get-PSCallStack
        $caller = if ($callStack.Count -gt 1) { $callStack[1] } else { $callStack[0] }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $threadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        
        # Build comprehensive context
        $logContext = @{
            Timestamp = $timestamp
            Level = $Level
            ThreadId = $threadId
            CallDepth = $script:CallDepth
            Message = $Message
            Caller = @{
                Command = $caller.Command
                Location = $caller.Location
                ScriptName = $caller.ScriptName
                LineNumber = $caller.ScriptLineNumber
                Arguments = $caller.Arguments
            }
            FullCallStack = $callStack | ForEach-Object {
                @{
                    Command = $_.Command
                    Location = $_.Location
                    ScriptName = $_.ScriptName
                    LineNumber = $_.ScriptLineNumber
                }
            }
        }
        
        # Add user data if provided
        if ($Data) {
            $logContext.UserData = if ($Data -is [Exception]) {
                @{
                    Type = "Exception"
                    Message = $Data.Message
                    StackTrace = $Data.StackTrace
                    InnerException = if ($Data.InnerException) { $Data.InnerException.Message } else { $null }
                }
            } else {
                try {
                    # Try to serialize safely
                    $serialized = ConvertTo-SerializableObject -Object $Data
                    $serialized
                } catch {
                    @{
                        Type = "SerializationFailed"
                        StringRepresentation = $Data.ToString()
                        Error = $_.Exception.Message
                    }
                }
            }
        }
        
        # Create formatted log entry
        $indent = "  " * $script:CallDepth
        $callerInfo = if ($caller.ScriptName) {
            "$([System.IO.Path]::GetFileName($caller.ScriptName)):$($caller.ScriptLineNumber)"
        } else {
            $caller.Command
        }
        
        $logEntry = "$timestamp[$Level   ]$indent[$callerInfo] $Message"
        
        if ($Data) {
            $dataStr = if ($Data -is [Exception]) {
                "`n${indent}  Exception: $($Data.Message)`n${indent}  StackTrace: $($Data.StackTrace)"
            } else {
                try {
                    $json = ConvertTo-SerializableObject -Object $Data | ConvertTo-Json -Compress -Depth 3 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                    "`n${indent}  Data: $json"
                } catch {
                    "`n${indent}  Data: $($Data.ToString())"
                }
            }
            $logEntry += $dataStr
        }
        
        # Add to in-memory queue (for debug screen)
        $script:LogQueue += $logContext
        
        # Keep only last 2000 entries in memory for detailed debugging
        if ($script:LogQueue.Count -gt 2000) {
            $script:LogQueue = $script:LogQueue[-2000..-1]
        }
        
        # Write to file with enhanced error handling
        if ($script:LogPath) {
            try {
                # Ensure directory exists
                $logDir = Split-Path $script:LogPath -Parent
                if (-not (Test-Path $logDir)) {
                    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
                }
                
                # Check file size and rotate if needed
                if ((Test-Path $script:LogPath) -and (Get-Item $script:LogPath).Length -gt $script:MaxLogSize) {
                    $archivePath = $script:LogPath -replace '\.log$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
                    Move-Item $script:LogPath $archivePath -Force
                }
                
                # Force flush to ensure content is written
                Add-Content -Path $script:LogPath -Value $logEntry -Encoding UTF8 -Force
                
            } catch {
                # If file writing fails, at least output to console
                Write-Host "LOG WRITE FAILED: $logEntry" -ForegroundColor Yellow
                Write-Host "Error: $_" -ForegroundColor Red
            }
        }
        
        # Also output to console for immediate feedback if Error level
        if ($Level -eq "Error" -or $Level -eq "Warning") {
            $color = if ($Level -eq "Error") { "Red" } else { "Yellow" }
            Write-Host $logEntry -ForegroundColor $color
        }
        
    } catch {
        # Even the logger's error handling should be logged
        try {
            $errorEntry = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff")[LOGGER ERROR] Failed to log message '$Message': $_"
            if ($script:LogPath) {
                Add-Content -Path $script:LogPath -Value $errorEntry -Encoding UTF8
            }
            Write-Host $errorEntry -ForegroundColor Red
        } catch {
            # Ultimate fallback - just write to host
            Write-Host "CRITICAL: Logger completely failed: $_" -ForegroundColor Red
        }
    }
}

function global:Trace-FunctionEntry {
    param(
        [string]$FunctionName,
        [object]$Parameters = $null
    )
    
    $script:CallDepth++
    Write-Log -Level Trace -Message "ENTER: $FunctionName" -Data @{
        Parameters = $Parameters
        CallDepth = $script:CallDepth
        Action = "FunctionEntry"
    }
}

function global:Trace-FunctionExit {
    param(
        [string]$FunctionName,
        [object]$ReturnValue = $null,
        [switch]$WithError
    )
    
    Write-Log -Level Trace -Message "EXIT: $FunctionName" -Data @{
        ReturnValue = $ReturnValue
        CallDepth = $script:CallDepth
        Action = if ($WithError) { "FunctionExitWithError" } else { "FunctionExit" }
        HasError = $WithError.IsPresent
    }
    $script:CallDepth--
    if ($script:CallDepth -lt 0) { $script:CallDepth = 0 }
}

function global:Trace-Step {
    param(
        [string]$StepName,
        [object]$StepData = $null,
        [string]$Module = $null
    )
    
    $caller = (Get-PSCallStack)[1]
    $moduleInfo = if ($Module) { $Module } else { 
        if ($caller.ScriptName) { [System.IO.Path]::GetFileNameWithoutExtension($caller.ScriptName) } else { "Unknown" }
    }
    
    Write-Log -Level Debug -Message "STEP: $StepName" -Data @{
        StepData = $StepData
        Module = $moduleInfo
        Action = "Step"
        Caller = @{
            Command = $caller.Command
            Location = $caller.Location
            LineNumber = $caller.ScriptLineNumber
        }
    }
}

function global:Trace-StateChange {
    param(
        [string]$StateType,
        [object]$OldValue = $null,
        [object]$NewValue = $null,
        [string]$PropertyPath = $null
    )
    
    Write-Log -Level Debug -Message "STATE: $StateType changed" -Data @{
        StateType = $StateType
        PropertyPath = $PropertyPath
        OldValue = ConvertTo-SerializableObject -Object $OldValue
        NewValue = ConvertTo-SerializableObject -Object $NewValue
        Action = "StateChange"
    }
}

function global:Trace-ComponentLifecycle {
    param(
        [string]$ComponentType,
        [string]$ComponentId,
        [string]$Phase,  # Create, Initialize, Render, Update, Destroy
        [object]$ComponentData = $null
    )
    
    Write-Log -Level Debug -Message "COMPONENT: $ComponentType [$ComponentId] $Phase" -Data @{
        ComponentType = $ComponentType
        ComponentId = $ComponentId
        Phase = $Phase
        ComponentData = ConvertTo-SerializableObject -Object $ComponentData
        Action = "ComponentLifecycle"
    }
}

function global:Trace-ServiceCall {
    param(
        [string]$ServiceName,
        [string]$MethodName,
        [object]$Parameters = $null,
        [object]$Result = $null,
        [switch]$IsError
    )
    
    $action = if ($IsError) { "ServiceCallError" } else { "ServiceCall" }
    Write-Log -Level Debug -Message "SERVICE: $ServiceName.$MethodName" -Data @{
        ServiceName = $ServiceName
        MethodName = $MethodName
        Parameters = ConvertTo-SerializableObject -Object $Parameters
        Result = ConvertTo-SerializableObject -Object $Result
        Action = $action
        IsError = $IsError.IsPresent
    }
}

function ConvertTo-SerializableObject {
    param([object]$Object)
    
    if ($null -eq $Object) { return $null }
    
    # Handle different object types safely
    switch ($Object.GetType().Name) {
        "Hashtable" {
            $result = @{}
            foreach ($key in $Object.Keys) {
                try {
                    $result[$key] = ConvertTo-SerializableObject -Object $Object[$key]
                } catch {
                    $result[$key] = "<SerializationError: $($_.Exception.Message)>"
                }
            }
            return $result
        }
        "PSCustomObject" {
            $result = @{}
            foreach ($prop in $Object.PSObject.Properties) {
                try {
                    $result[$prop.Name] = ConvertTo-SerializableObject -Object $prop.Value
                } catch {
                    $result[$prop.Name] = "<SerializationError: $($_.Exception.Message)>"
                }
            }
            return $result
        }
        "Object[]" {
            $result = @()
            for ($i = 0; $i -lt [Math]::Min($Object.Count, 10); $i++) {  # Limit array size for performance
                try {
                    $result += ConvertTo-SerializableObject -Object $Object[$i]
                } catch {
                    $result += "<SerializationError: $($_.Exception.Message)>"
                }
            }
            if ($Object.Count -gt 10) {
                $result += "<... $($Object.Count - 10) more items>"
            }
            return $result
        }
        default {
            try {
                # For simple types, return as-is or convert to string
                if ($Object -is [string] -or $Object -is [int] -or $Object -is [bool] -or $Object -is [double]) {
                    return $Object
                } else {
                    return $Object.ToString()
                }
            } catch {
                return "<ToString failed: $($_.Exception.Message)>"
            }
        }
    }
}

function global:Get-LogEntries {
    param(
        [int]$Count = 100,
        [string]$Level = $null,
        [string]$Module = $null,
        [string]$Action = $null
    )
    
    try {
        $entries = $script:LogQueue
        
        if ($Level) {
            $entries = $entries | Where-Object { $_.Level -eq $Level }
        }
        
        if ($Module) {
            $entries = $entries | Where-Object { 
                $_.Caller.ScriptName -and ([System.IO.Path]::GetFileNameWithoutExtension($_.Caller.ScriptName) -like "*$Module*")
            }
        }
        
        if ($Action) {
            $entries = $entries | Where-Object { $_.UserData.Action -eq $Action }
        }
        
        return $entries | Select-Object -Last $Count
    } catch {
        Write-Warning "Error getting log entries: $_"
        return @()
    }
}

function global:Get-CallTrace {
    param([int]$Depth = 10)
    
    try {
        $callStack = Get-PSCallStack
        $trace = @()
        
        for ($i = 0; $i -lt [Math]::Min($callStack.Count, $Depth); $i++) {
            $call = $callStack[$i]
            $trace += @{
                Level = $i
                Command = $call.Command
                Location = $call.Location
                ScriptName = $call.ScriptName
                LineNumber = $call.ScriptLineNumber
                Arguments = $call.Arguments
            }
        }
        
        return $trace
    } catch {
        Write-Warning "Error getting call trace: $_"
        return @()
    }
}

function global:Clear-LogQueue {
    try {
        $script:LogQueue = @()
        Write-Log -Level Info -Message "Log queue cleared"
    } catch {
        Write-Warning "Error clearing log queue: $_"
    }
}

function global:Set-LogLevel {
    param(
        [ValidateSet("Debug", "Verbose", "Info", "Warning", "Error", "Trace")]
        [string]$Level
    )
    
    try {
        $oldLevel = $script:LogLevel
        $script:LogLevel = $Level
        Write-Log -Level Info -Message "Log level changed from $oldLevel to $Level"
    } catch {
        Write-Warning "Error setting log level to '$Level': $_"
    }
}

function global:Enable-CallTracing {
    $script:TraceAllCalls = $true
    Write-Log -Level Info -Message "Call tracing enabled"
}

function global:Disable-CallTracing {
    $script:TraceAllCalls = $false
    Write-Log -Level Info -Message "Call tracing disabled"
}

function global:Get-LogPath {
    return $script:LogPath
}

function global:Get-LogStatistics {
    try {
        $stats = @{
            TotalEntries = $script:LogQueue.Count
            LogPath = $script:LogPath
            LogLevel = $script:LogLevel
            CallTracingEnabled = $script:TraceAllCalls
            LogFileSize = if ($script:LogPath -and (Test-Path $script:LogPath)) { 
                (Get-Item $script:LogPath).Length 
            } else { 0 }
            EntriesByLevel = @{}
            EntriesByModule = @{}
            EntriesByAction = @{}
        }
        
        # Count entries by level
        foreach ($entry in $script:LogQueue) {
            $level = $entry.Level
            if (-not $stats.EntriesByLevel.ContainsKey($level)) {
                $stats.EntriesByLevel[$level] = 0
            }
            $stats.EntriesByLevel[$level]++
            
            # Count by module
            if ($entry.Caller.ScriptName) {
                $module = [System.IO.Path]::GetFileNameWithoutExtension($entry.Caller.ScriptName)
                if (-not $stats.EntriesByModule.ContainsKey($module)) {
                    $stats.EntriesByModule[$module] = 0
                }
                $stats.EntriesByModule[$module]++
            }
            
            # Count by action
            if ($entry.UserData -and $entry.UserData.Action) {
                $action = $entry.UserData.Action
                if (-not $stats.EntriesByAction.ContainsKey($action)) {
                    $stats.EntriesByAction[$action] = 0
                }
                $stats.EntriesByAction[$action]++
            }
        }
        
        return $stats
    } catch {
        Write-Warning "Error getting log statistics: $_"
        return @{}
    }
}

Export-ModuleMember -Function @(
    'Initialize-Logger',
    'Write-Log',
    'Trace-FunctionEntry',
    'Trace-FunctionExit', 
    'Trace-Step',
    'Trace-StateChange',
    'Trace-ComponentLifecycle',
    'Trace-ServiceCall',
    'Get-LogEntries',
    'Get-CallTrace',
    'Clear-LogQueue',
    'Set-LogLevel',
    'Enable-CallTracing',
    'Disable-CallTracing',
    'Get-LogPath',
    'Get-LogStatistics'
)