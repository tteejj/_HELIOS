# Enhanced Exception Module for Helios
# Provides EXTREMELY detailed error tracking and context capture

# Define custom exception types using PowerShell 5-compatible approach
# NOTE: Disabled C# exceptions in favor of PowerShell objects for startup safety
<#
Add-Type -TypeDefinition @"
using System;
using System.Collections;

namespace Helios {
    public class HeliosException : Exception {
        public Hashtable Context { get; set; }
        public string Component { get; set; }
        public object OriginalError { get; set; }
        public DateTime Timestamp { get; set; }
        
        public HeliosException(string message, Hashtable context) : base(message) {
            this.Context = context ?? new Hashtable();
            this.Component = context != null && context.ContainsKey("Component") ? context["Component"].ToString() : "Unknown";
            this.Timestamp = DateTime.Now;
        }
    }
    
    public class NavigationException : HeliosException {
        public NavigationException(string message, Hashtable context) : base(message, context) { }
    }
    
    public class ServiceInitializationException : HeliosException {
        public ServiceInitializationException(string message, Hashtable context) : base(message, context) { }
    }
    
    public class ComponentRenderException : HeliosException {
        public ComponentRenderException(string message, Hashtable context) : base(message, context) { }
    }
    
    public class StateMutationException : HeliosException {
        public StateMutationException(string message, Hashtable context) : base(message, context) { }
    }
    
    public class InputHandlingException : HeliosException {
        public InputHandlingException(string message, Hashtable context) : base(message, context) { }
    }
    
    public class DataLoadException : HeliosException {
        public DataLoadException(string message, Hashtable context) : base(message, context) { }
    }
    
    public class ThemeException : HeliosException {
        public ThemeException(string message, Hashtable context) : base(message, context) { }
    }
}
"@ -ErrorAction SilentlyContinue
#>

# Global error tracking
$script:ErrorHistory = @()
$script:MaxErrorHistory = 500
$script:GlobalErrorHandler = $null

# Enhanced error handler with automatic logging
function global:Set-HeliosErrorHandler {
    param(
        [scriptblock]$CustomHandler = $null
    )
    
    $script:GlobalErrorHandler = $CustomHandler
    
    # Don't set global error action preference as it can break things
    # Instead we'll use try/catch patterns everywhere
    
    # Safely log if available
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        Write-Log -Level Info -Message "Helios error handler configured" -Data @{
            HasCustomHandler = ($null -ne $CustomHandler)
            Timestamp = Get-Date
        }
    }
}

# Get EXTREMELY detailed error information
function global:Get-DetailedError {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [hashtable]$AdditionalContext = @{}
    )
    
    try {
        # Capture full call stack
        $callStack = Get-PSCallStack
        
        $errorInfo = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            Summary = $ErrorRecord.Exception.Message
            Type = $ErrorRecord.Exception.GetType().FullName
            Category = $ErrorRecord.CategoryInfo.Category.ToString()
            CategoryActivity = $ErrorRecord.CategoryInfo.Activity
            CategoryReason = $ErrorRecord.CategoryInfo.Reason
            CategoryTargetName = $ErrorRecord.CategoryInfo.TargetName
            CategoryTargetType = $ErrorRecord.CategoryInfo.TargetType
            TargetObject = $null  # We'll handle this carefully
            ScriptName = $ErrorRecord.InvocationInfo.ScriptName
            LineNumber = $ErrorRecord.InvocationInfo.ScriptLineNumber
            ColumnNumber = $ErrorRecord.InvocationInfo.OffsetInLine
            Line = $ErrorRecord.InvocationInfo.Line
            Command = $ErrorRecord.InvocationInfo.InvocationName
            PositionMessage = $ErrorRecord.InvocationInfo.PositionMessage
            StackTrace = @()
            InnerExceptions = @()
            HeliosContext = @{}
            SystemContext = @{}
            AdditionalContext = $AdditionalContext
        }
        
        # Safely capture target object
        try {
            if ($ErrorRecord.TargetObject) {
                $errorInfo.TargetObject = @{
                    Type = $ErrorRecord.TargetObject.GetType().FullName
                    ToString = $ErrorRecord.TargetObject.ToString()
                    Properties = @{}
                }
                
                # Try to capture key properties safely
                if ($ErrorRecord.TargetObject -is [hashtable]) {
                    $errorInfo.TargetObject.Properties = @{
                        Keys = $ErrorRecord.TargetObject.Keys
                        Count = $ErrorRecord.TargetObject.Count
                    }
                }
            }
        } catch {
            $errorInfo.TargetObject = "Failed to serialize target object: $($_.Exception.Message)"
        }
        
        # Capture complete call stack with maximum detail
        foreach ($frame in $callStack) {
            try {
                $frameInfo = @{
                    Command = $frame.Command
                    Location = $frame.Location
                    ScriptName = $frame.ScriptName
                    ScriptLineNumber = $frame.ScriptLineNumber
                    Arguments = @()
                    Module = if ($frame.ScriptName) { 
                        [System.IO.Path]::GetFileNameWithoutExtension($frame.ScriptName) 
                    } else { "Interactive" }
                }
                
                # Safely capture arguments
                try {
                    if ($frame.Arguments) {
                        $frameInfo.Arguments = $frame.Arguments | ForEach-Object {
                            try {
                                if ($_ -is [string] -or $_ -is [int] -or $_ -is [bool]) {
                                    $_
                                } else {
                                    $_.ToString()
                                }
                            } catch {
                                "<arg-serialization-failed>"
                            }
                        }
                    }
                } catch {
                    $frameInfo.Arguments = @("<arguments-capture-failed>")
                }
                
                $errorInfo.StackTrace += $frameInfo
            } catch {
                $errorInfo.StackTrace += @{
                    Command = "Failed to capture frame"
                    Error = $_.Exception.Message
                }
            }
        }
        
        # Capture all inner exceptions
        $innerEx = $ErrorRecord.Exception.InnerException
        while ($innerEx) {
            try {
                $innerInfo = @{
                    Message = $innerEx.Message
                    Type = $innerEx.GetType().FullName
                    StackTrace = $innerEx.StackTrace
                    Data = @{}
                }
                
                # Safely capture exception data
                try {
                    if ($innerEx.Data -and $innerEx.Data.Count -gt 0) {
                        foreach ($key in $innerEx.Data.Keys) {
                            try {
                                $innerInfo.Data[$key] = $innerEx.Data[$key].ToString()
                            } catch {
                                $innerInfo.Data[$key] = "<data-serialization-failed>"
                            }
                        }
                    }
                } catch {
                    $innerInfo.Data = "<data-capture-failed>"
                }
                
                $errorInfo.InnerExceptions += $innerInfo
                $innerEx = $innerEx.InnerException
            } catch {
                $errorInfo.InnerExceptions += @{
                    Message = "Failed to capture inner exception"
                    Error = $_.Exception.Message
                }
                break
            }
        }
        
        # Extract Helios-specific context if available
        try {
            if ($ErrorRecord.Exception.GetType().Namespace -eq "Helios") {
                $errorInfo.HeliosContext = $ErrorRecord.Exception.Context
                $errorInfo.Component = $ErrorRecord.Exception.Component
            } else {
                # Identify component from call stack
                $errorInfo.Component = Identify-HeliosComponent -ErrorRecord $ErrorRecord
            }
        } catch {
            $errorInfo.Component = "Unknown"
            $errorInfo.HeliosContext = @{ Error = "Failed to extract Helios context" }
        }
        
        # Capture system context
        try {
            $errorInfo.SystemContext = @{
                ProcessId = $PID
                ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                ExecutionPolicy = (Get-ExecutionPolicy).ToString()
                CurrentLocation = (Get-Location).Path
                MemoryUsage = [System.GC]::GetTotalMemory($false)
                LoadedModules = (Get-Module).Name
                GlobalVariables = @()
            }
            
            # Capture relevant global variables safely
            $relevantGlobals = @('Data', 'Services', 'CurrentScreen', 'Store')
            foreach ($varName in $relevantGlobals) {
                try {
                    $var = Get-Variable -Name $varName -Scope Global -ErrorAction SilentlyContinue
                    if ($var) {
                        $errorInfo.SystemContext.GlobalVariables += @{
                            Name = $varName
                            Type = $var.Value.GetType().FullName
                            HasValue = $null -ne $var.Value
                        }
                    }
                } catch {
                    $errorInfo.SystemContext.GlobalVariables += @{
                        Name = $varName
                        Error = "Failed to capture variable"
                    }
                }
            }
        } catch {
            $errorInfo.SystemContext = @{ Error = "Failed to capture system context" }
        }
        
        return $errorInfo
        
    } catch {
        # If error analysis itself fails, return minimal info
        return @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            Summary = "CRITICAL: Error analysis failed"
            OriginalError = $ErrorRecord.Exception.Message
            AnalysisError = $_.Exception.Message
            Type = "ErrorAnalysisFailure"
        }
    }
}

# Identify which Helios component caused the error with enhanced detection
function global:Identify-HeliosComponent {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    try {
        $scriptName = $ErrorRecord.InvocationInfo.ScriptName
        if (-not $scriptName) { 
            # Try to get component from call stack
            $callStack = Get-PSCallStack
            foreach ($frame in $callStack) {
                if ($frame.ScriptName) {
                    $scriptName = $frame.ScriptName
                    break
                }
            }
        }
        
        if (-not $scriptName) { return "Interactive/Unknown" }
        
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($scriptName)
        
        # Enhanced component mapping
        $componentMap = @{
            'app-store' = 'AppStore/State Management'
            'navigation' = 'Navigation Service'
            'tui-engine' = 'TUI Engine/Renderer'
            'tui-framework' = 'TUI Framework'
            'dashboard-screen' = 'Dashboard Screen'
            'task-screen' = 'Task Management Screen'
            'timer' = 'Timer Service'
            'dialog' = 'Dialog System'
            'focus-manager' = 'Focus Manager'
            'layout' = 'Layout System'
            'panel' = 'Panel Components'
            'main-helios' = 'Main Application'
            'data-manager' = 'Data Manager'
            'theme-manager' = 'Theme Manager'
            'keybindings' = 'Keybinding Service'
            'exceptions' = 'Exception Handler'
            'logger' = 'Logging Service'
            'advanced-data-components' = 'Data Components'
            'advanced-input-components' = 'Input Components'
            'tui-components' = 'UI Components'
        }
        
        foreach ($pattern in $componentMap.Keys) {
            if ($fileName -match $pattern) {
                return $componentMap[$pattern]
            }
        }
        
        return "Unknown Component ($fileName)"
        
    } catch {
        return "Component Identification Failed"
    }
}

# Enhanced error handling wrapper with automatic context capture
function global:Invoke-WithErrorHandling {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Component = "Unknown",
        [hashtable]$Context = @{},
        [scriptblock]$ErrorHandler = $null,
        [string]$OperationName = "Unknown Operation"
    )
    
    # Safely trace function entry if available
    if (Get-Command Trace-FunctionEntry -ErrorAction SilentlyContinue) {
        Trace-FunctionEntry -FunctionName "Invoke-WithErrorHandling" -Parameters @{
            Component = $Component
            OperationName = $OperationName
            HasCustomErrorHandler = ($null -ne $ErrorHandler)
        }
    }
    
    try {
        # Safely trace step if available
        if (Get-Command Trace-Step -ErrorAction SilentlyContinue) {
            Trace-Step -StepName "Starting protected operation" -StepData @{
                Component = $Component
                Operation = $OperationName
            }
        }
        
        $result = & $ScriptBlock
        
        # Safely trace completion if available
        if (Get-Command Trace-Step -ErrorAction SilentlyContinue) {
            Trace-Step -StepName "Protected operation completed successfully" -StepData @{
                Component = $Component
                Operation = $OperationName
                ResultType = if ($result) { $result.GetType().Name } else { "null" }
            }
        }
        
        # Safely trace function exit if available
        if (Get-Command Trace-FunctionExit -ErrorAction SilentlyContinue) {
            Trace-FunctionExit -FunctionName "Invoke-WithErrorHandling" -ReturnValue @{
                Success = $true
                Component = $Component
            }
        }
        
        return $result
        
    } catch {
        # Safely clone the context hashtable
        $errorContext = @{}
        if ($Context) {
            foreach ($key in $Context.Keys) {
                $errorContext[$key] = $Context[$key]
            }
        }
        $errorContext.Component = $Component
        $errorContext.OperationName = $OperationName
        $errorContext.Timestamp = Get-Date
        $errorContext.ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        
        # Get detailed error information
        $detailedError = Get-DetailedError -ErrorRecord $_ -AdditionalContext $errorContext
        
        # Safely log the error if available
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Level Error -Message "Error in $Component during $OperationName" -Data $detailedError
        }
        
        # Add to error history
        $script:ErrorHistory += $detailedError
        if ($script:ErrorHistory.Count -gt $script:MaxErrorHistory) {
            $script:ErrorHistory = $script:ErrorHistory[-$script:MaxErrorHistory..-1]
        }
        
        # Create PowerShell-based Helios exception instead of C# classes
        $heliosEx = New-Object PSObject
        $heliosEx | Add-Member -MemberType NoteProperty -Name Message -Value $_.Exception.Message
        $heliosEx | Add-Member -MemberType NoteProperty -Name Component -Value $Component
        $heliosEx | Add-Member -MemberType NoteProperty -Name Context -Value $errorContext
        $heliosEx | Add-Member -MemberType NoteProperty -Name Timestamp -Value (Get-Date)
        $heliosEx | Add-Member -MemberType NoteProperty -Name OriginalError -Value $_
        $heliosEx | Add-Member -MemberType NoteProperty -Name OperationName -Value $OperationName
        
        # Determine exception type based on component
        $exceptionType = switch -Regex ($Component) {
            'Navigation' { 'NavigationException' }
            'Store|State|AppStore' { 'StateMutationException' }
            'Render|TUI|Component' { 'ComponentRenderException' }
            'Input|Focus' { 'InputHandlingException' }
            'Service|Manager' { 'ServiceInitializationException' }
            'Data|Load' { 'DataLoadException' }
            'Theme' { 'ThemeException' }
            default { 'HeliosException' }
        }
        
        $heliosEx | Add-Member -MemberType NoteProperty -Name ExceptionType -Value $exceptionType
        
        # Safely trace function exit if available
        if (Get-Command Trace-FunctionExit -ErrorAction SilentlyContinue) {
            Trace-FunctionExit -FunctionName "Invoke-WithErrorHandling" -ReturnValue @{
                Success = $false
                Component = $Component
                ErrorType = $exceptionType
            } -WithError
        }
        
        if ($ErrorHandler) {
            try {
                & $ErrorHandler -Exception $heliosEx -DetailedError $detailedError
            } catch {
                if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
                    Write-Log -Level Error -Message "Error handler itself failed" -Data @{
                        Component = $Component
                        OriginalError = $heliosEx.Message
                        HandlerError = $_.Exception.Message
                    }
                }
            }
        } else {
            # Call global error handler if available
            if ($script:GlobalErrorHandler) {
                try {
                    & $script:GlobalErrorHandler -Exception $heliosEx -DetailedError $detailedError
                } catch {
                    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
                        Write-Log -Level Error -Message "Global error handler failed" -Data @{
                            Component = $Component
                            OriginalError = $heliosEx.Message
                            HandlerError = $_.Exception.Message
                        }
                    }
                }
            }
            
            # Create a proper exception with our data attached
            $properException = New-Object System.Management.Automation.RuntimeException($heliosEx.Message)
            $properException.Data.Add("HeliosException", $heliosEx)
            $properException.Data.Add("Component", $Component)
            $properException.Data.Add("OperationName", $OperationName)
            $properException.Data.Add("Timestamp", $heliosEx.Timestamp)
            
            # Re-throw the proper exception
            throw $properException
        }
    }
}

# Create a comprehensive diagnostic report
function global:Get-HeliosDiagnosticReport {
    param(
        [switch]$IncludeErrorHistory,
        [switch]$IncludeLogEntries,
        [int]$LogEntryCount = 50
    )
    
    try {
        # Safely trace function entry if available
        if (Get-Command Trace-FunctionEntry -ErrorAction SilentlyContinue) {
            Trace-FunctionEntry -FunctionName "Get-HeliosDiagnosticReport"
        }
        
        $report = @{
            GeneratedAt = Get-Date
            System = @{
                PowerShellVersion = $PSVersionTable
                ProcessId = $PID
                ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                ExecutionPolicy = (Get-ExecutionPolicy).ToString()
                CurrentLocation = (Get-Location).Path
                MemoryUsage = [System.GC]::GetTotalMemory($false)
                AvailableMemory = [System.GC]::GetTotalMemory($true)
            }
            Modules = @{}
            GlobalVariables = @{}
            Services = @{}
            CallStack = Get-CallTrace -Depth 20
            ErrorStatistics = @{
                TotalErrorsTracked = $script:ErrorHistory.Count
                ErrorsByComponent = @{}
                ErrorsByType = @{}
                RecentErrorsCount = ($script:ErrorHistory | Where-Object { 
                    $_.Timestamp -gt (Get-Date).AddMinutes(-5) 
                }).Count
            }
        }
        
        # Capture loaded modules with details
        foreach ($module in Get-Module) {
            $report.Modules[$module.Name] = @{
                Version = $module.Version.ToString()
                Path = $module.Path
                ExportedFunctions = $module.ExportedFunctions.Keys
                ExportedCmdlets = $module.ExportedCmdlets.Keys
                ModuleType = $module.ModuleType.ToString()
            }
        }
        
        # Capture relevant global variables safely
        $relevantGlobals = @('Data', 'Services', 'CurrentScreen', 'Store', 'Theme', 'TuiEngine')
        foreach ($varName in $relevantGlobals) {
            try {
                $var = Get-Variable -Name $varName -Scope Global -ErrorAction SilentlyContinue
                if ($var) {
                    $report.GlobalVariables[$varName] = @{
                        Type = $var.Value.GetType().FullName
                        HasValue = $null -ne $var.Value
                        Properties = @()
                    }
                    
                    # Safely capture properties for hashtables
                    if ($var.Value -is [hashtable]) {
                        $report.GlobalVariables[$varName].Properties = $var.Value.Keys
                        $report.GlobalVariables[$varName].Count = $var.Value.Count
                    }
                }
            } catch {
                $report.GlobalVariables[$varName] = @{
                    Error = "Failed to capture variable: $($_.Exception.Message)"
                }
            }
        }
        
        # Capture service states if available
        try {
            if ($global:Services) {
                foreach ($serviceName in $global:Services.Keys) {
                    try {
                        $service = $global:Services[$serviceName]
                        $report.Services[$serviceName] = @{
                            Type = $service.GetType().FullName
                            HasValue = $null -ne $service
                            Methods = @()
                        }
                        
                        if ($service -is [hashtable]) {
                            $report.Services[$serviceName].Methods = $service.Keys | Where-Object { 
                                $service[$_] -is [scriptblock] 
                            }
                        }
                    } catch {
                        $report.Services[$serviceName] = @{
                            Error = "Failed to analyze service: $($_.Exception.Message)"
                        }
                    }
                }
            }
        } catch {
            $report.Services = @{
                Error = "Failed to capture services: $($_.Exception.Message)"
            }
        }
        
        # Calculate error statistics
        foreach ($error in $script:ErrorHistory) {
            $component = $error.Component
            if (-not $report.ErrorStatistics.ErrorsByComponent.ContainsKey($component)) {
                $report.ErrorStatistics.ErrorsByComponent[$component] = 0
            }
            $report.ErrorStatistics.ErrorsByComponent[$component]++
            
            $type = $error.Type
            if (-not $report.ErrorStatistics.ErrorsByType.ContainsKey($type)) {
                $report.ErrorStatistics.ErrorsByType[$type] = 0
            }
            $report.ErrorStatistics.ErrorsByType[$type]++
        }
        
        # Include error history if requested
        if ($IncludeErrorHistory) {
            $report.ErrorHistory = $script:ErrorHistory
        }
        
        # Include recent log entries if requested
        if ($IncludeLogEntries) {
            try {
                $report.RecentLogEntries = Get-LogEntries -Count $LogEntryCount
            } catch {
                $report.RecentLogEntries = @{
                    Error = "Failed to get log entries: $($_.Exception.Message)"
                }
            }
        }
        
        # Safely trace function exit if available
        if (Get-Command Trace-FunctionExit -ErrorAction SilentlyContinue) {
            Trace-FunctionExit -FunctionName "Get-HeliosDiagnosticReport" -ReturnValue @{
                ReportSize = ($report | ConvertTo-Json -Depth 1).Length
                IncludedSections = @($report.Keys)
            }
        }
        
        return $report
        
    } catch {
        Write-Log -Level Error -Message "Failed to generate diagnostic report" -Data @{
            Error = $_.Exception.Message
            StackTrace = $_.Exception.StackTrace
        }
        
        return @{
            Error = "Failed to generate diagnostic report"
            Exception = $_.Exception.Message
            GeneratedAt = Get-Date
        }
    }
}

function global:Get-ErrorHistory {
    param(
        [int]$Count = 20,
        [string]$Component = $null,
        [datetime]$Since = $null
    )
    
    try {
        $errors = $script:ErrorHistory
        
        if ($Component) {
            $errors = $errors | Where-Object { $_.Component -like "*$Component*" }
        }
        
        if ($Since) {
            $errors = $errors | Where-Object { 
                [datetime]$_.Timestamp -gt $Since 
            }
        }
        
        return $errors | Select-Object -Last $Count
        
    } catch {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Level Error -Message "Failed to get error history" -Data @{
                Error = $_.Exception.Message
            }
        }
        return @()
    }
}

function global:Clear-ErrorHistory {
    try {
        $clearedCount = $script:ErrorHistory.Count
        $script:ErrorHistory = @()
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "Cleared error history" -Data @{
                ClearedCount = $clearedCount
            }
        }
    } catch {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Level Error -Message "Failed to clear error history" -Data @{
                Error = $_.Exception.Message
            }
        }
    }
}

function global:Test-ComponentHealth {
    param(
        [string]$ComponentName = "All"
    )
    
    try {
        # Safely trace function entry if available
        if (Get-Command Trace-FunctionEntry -ErrorAction SilentlyContinue) {
            Trace-FunctionEntry -FunctionName "Test-ComponentHealth" -Parameters @{
                ComponentName = $ComponentName
            }
        }
        
        $healthReport = @{
            TestedAt = Get-Date
            OverallHealth = "Unknown"
            ComponentTests = @{}
            Recommendations = @()
        }
        
        # Test global services
        if ($ComponentName -eq "All" -or $ComponentName -eq "Services") {
            $healthReport.ComponentTests.Services = @{
                Status = "Unknown"
                Details = @{}
            }
            
            try {
                if ($global:Services) {
                    $serviceCount = $global:Services.Keys.Count
                    $healthReport.ComponentTests.Services.Status = "Healthy"
                    $healthReport.ComponentTests.Services.Details.ServiceCount = $serviceCount
                    $healthReport.ComponentTests.Services.Details.Services = $global:Services.Keys
                } else {
                    $healthReport.ComponentTests.Services.Status = "Failed"
                    $healthReport.ComponentTests.Services.Details.Error = "Global Services not found"
                    $healthReport.Recommendations += "Initialize global services"
                }
            } catch {
                $healthReport.ComponentTests.Services.Status = "Error"
                $healthReport.ComponentTests.Services.Details.Error = $_.Exception.Message
            }
        }
        
        # Test data structures
        if ($ComponentName -eq "All" -or $ComponentName -eq "Data") {
            $healthReport.ComponentTests.Data = @{
                Status = "Unknown"
                Details = @{}
            }
            
            try {
                if ($global:Data) {
                    $healthReport.ComponentTests.Data.Status = "Healthy"
                    $healthReport.ComponentTests.Data.Details.HasData = $true
                    $healthReport.ComponentTests.Data.Details.DataKeys = $global:Data.Keys
                } else {
                    $healthReport.ComponentTests.Data.Status = "Warning"
                    $healthReport.ComponentTests.Data.Details.HasData = $false
                    $healthReport.Recommendations += "Initialize global data structures"
                }
            } catch {
                $healthReport.ComponentTests.Data.Status = "Error"
                $healthReport.ComponentTests.Data.Details.Error = $_.Exception.Message
            }
        }
        
        # Test logging system
        if ($ComponentName -eq "All" -or $ComponentName -eq "Logger") {
            $healthReport.ComponentTests.Logger = @{
                Status = "Unknown"
                Details = @{}
            }
            
            try {
                $logPath = Get-LogPath
                if ($logPath) {
                    $healthReport.ComponentTests.Logger.Status = "Healthy"
                    $healthReport.ComponentTests.Logger.Details.LogPath = $logPath
                    $healthReport.ComponentTests.Logger.Details.LogFileExists = Test-Path $logPath
                } else {
                    $healthReport.ComponentTests.Logger.Status = "Warning"
                    $healthReport.ComponentTests.Logger.Details.Error = "Logger not initialized"
                    $healthReport.Recommendations += "Initialize logger system"
                }
            } catch {
                $healthReport.ComponentTests.Logger.Status = "Error"
                $healthReport.ComponentTests.Logger.Details.Error = $_.Exception.Message
            }
        }
        
        # Determine overall health
        $componentStatuses = $healthReport.ComponentTests.Values | ForEach-Object { $_.Status }
        if ($componentStatuses -contains "Error") {
            $healthReport.OverallHealth = "Critical"
        } elseif ($componentStatuses -contains "Failed") {
            $healthReport.OverallHealth = "Failed"
        } elseif ($componentStatuses -contains "Warning") {
            $healthReport.OverallHealth = "Warning"
        } else {
            $healthReport.OverallHealth = "Healthy"
        }
        
        # Safely trace function exit if available
        if (Get-Command Trace-FunctionExit -ErrorAction SilentlyContinue) {
            Trace-FunctionExit -FunctionName "Test-ComponentHealth" -ReturnValue @{
                OverallHealth = $healthReport.OverallHealth
                TestedComponents = $healthReport.ComponentTests.Keys
                RecommendationCount = $healthReport.Recommendations.Count
            }
        }
        
        return $healthReport
        
    } catch {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Level Error -Message "Component health test failed" -Data @{
                ComponentName = $ComponentName
                Error = $_.Exception.Message
            }
        }
        
        return @{
            TestedAt = Get-Date
            OverallHealth = "Critical"
            Error = "Health test failed: $($_.Exception.Message)"
            ComponentName = $ComponentName
        }
    }
}

# Export all functions
Export-ModuleMember -Function @(
    'Set-HeliosErrorHandler',
    'Get-DetailedError',
    'Identify-HeliosComponent',
    'Invoke-WithErrorHandling',
    'Get-HeliosDiagnosticReport',
    'Get-ErrorHistory',
    'Clear-ErrorHistory',
    'Test-ComponentHealth'
)