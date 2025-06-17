# Simple Logger Module for PMC Terminal
# Provides basic logging functionality

$script:LogPath = $null
$script:LogLevel = "Info"
$script:LogQueue = @()
$script:MaxLogSize = 1MB
$script:LogInitialized = $false

function global:Initialize-Logger {
    param(
        [string]$LogDirectory = (Join-Path $env:TEMP "PMCTerminal"),
        [string]$LogFileName = "pmc_terminal_{0:yyyy-MM-dd}.log" -f (Get-Date),
        [string]$Level = "Info"
    )
    
    try {
        # Create log directory if it doesn't exist
        if (-not (Test-Path $LogDirectory)) {
            New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
        }
        
        $script:LogPath = Join-Path $LogDirectory $LogFileName
        $script:LogLevel = $Level
        $script:LogInitialized = $true
        
        # Write initialization message
        Write-Log -Level Info -Message "Logger initialized at $($script:LogPath)"
        
    } catch {
        Write-Warning "Failed to initialize logger: $_"
        $script:LogInitialized = $false
    }
}

function global:Write-Log {
    param(
        [ValidateSet("Debug", "Verbose", "Info", "Warning", "Error")]
        [string]$Level = "Info",
        [Parameter(Mandatory)]
        [string]$Message,
        [object]$Data = $null
    )
    
    # Skip if logger not initialized or if level is below threshold
    if (-not $script:LogInitialized) { return }
    
    $levelPriority = @{
        Debug = 0
        Verbose = 1
        Info = 2
        Warning = 3
        Error = 4
    }
    
    if ($levelPriority[$Level] -lt $levelPriority[$script:LogLevel]) { return }
    
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $logEntry = "$timestamp [$Level] $Message"
        
        if ($Data) {
            $dataStr = if ($Data -is [Exception]) {
                "`n  Exception: $($Data.Message)`n  StackTrace: $($Data.StackTrace)"
            } else {
                "`n  Data: $($Data | ConvertTo-Json -Compress -Depth 2)"
            }
            $logEntry += $dataStr
        }
        
        # Add to in-memory queue (for debug screen)
        $script:LogQueue += @{
            Timestamp = $timestamp
            Level = $Level
            Message = $Message
            Data = $Data
        }
        
        # Keep only last 1000 entries in memory
        if ($script:LogQueue.Count -gt 1000) {
            $script:LogQueue = $script:LogQueue[-1000..-1]
        }
        
        # Write to file
        if ($script:LogPath) {
            # Check file size and rotate if needed
            if ((Test-Path $script:LogPath) -and (Get-Item $script:LogPath).Length -gt $script:MaxLogSize) {
                $archivePath = $script:LogPath -replace '\.log$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
                Move-Item $script:LogPath $archivePath -Force
            }
            
            Add-Content -Path $script:LogPath -Value $logEntry -Encoding UTF8
        }
        
    } catch {
        # Silently fail - we don't want logging errors to break the application
    }
}

function global:Get-LogEntries {
    param(
        [int]$Count = 100,
        [string]$Level = $null
    )
    
    $entries = $script:LogQueue
    
    if ($Level) {
        $entries = $entries | Where-Object { $_.Level -eq $Level }
    }
    
    return $entries | Select-Object -Last $Count
}

function global:Clear-LogQueue {
    $script:LogQueue = @()
}

function global:Set-LogLevel {
    param(
        [ValidateSet("Debug", "Verbose", "Info", "Warning", "Error")]
        [string]$Level
    )
    
    $script:LogLevel = $Level
    Write-Log -Level Info -Message "Log level changed to $Level"
}

function global:Get-LogPath {
    return $script:LogPath
}

Export-ModuleMember -Function @(
    'Initialize-Logger',
    'Write-Log',
    'Get-LogEntries',
    'Clear-LogQueue',
    'Set-LogLevel',
    'Get-LogPath'
)