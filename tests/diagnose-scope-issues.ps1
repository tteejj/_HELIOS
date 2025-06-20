# Comprehensive Helios Scope Issue Diagnostic Tool
# This tool will identify all potential scope issues in the application

param(
    [string]$Path = ".",
    [switch]$Verbose
)

# Initialize diagnostic results
$issues = @{
    LocalVariableInHandler = @()
    MissingServiceCheck = @()
    DirectGlobalAccess = @()
    UnstorredComponents = @()
    IncorrectSelfReference = @()
}

function Write-DiagnosticLog {
    param($Message, $Type = "Info")
    $color = switch($Type) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Success" { "Green" }
        default { "White" }
    }
    Write-Host "[$Type] $Message" -ForegroundColor $color
}

function Test-FileForScopeIssues {
    param($FilePath)
    
    try {
        $content = Get-Content -Path $FilePath -Raw
        $fileName = Split-Path $FilePath -Leaf
        
        # Pattern 1: Check for local variables used in handlers/subscriptions
        $handlerPattern = '(?ms)(Subscribe|OnClick|OnRowSelect|OnChange|Register-ObjectEvent)[^{]*\{[^}]*\$(?!self|data|Event|_|global:|using:|script:)(\w+)[^}]*\}'
        $matches = [regex]::Matches($content, $handlerPattern)
        foreach ($match in $matches) {
            $varName = $match.Groups[2].Value
            # Check if this variable was stored on $self before the handler
            if ($content -notmatch "\`$self\._?$varName\s*=") {
                $issues.LocalVariableInHandler += @{
                    File = $fileName
                    Line = ($content.Substring(0, $match.Index) -split "`n").Count
                    Variable = $varName
                    Context = $match.Groups[1].Value
                    Code = $match.Value.Substring(0, [Math]::Min($match.Value.Length, 100)) + "..."
                }
            }
        }
        
        # Pattern 2: Check for missing service null checks
        $serviceUsagePattern = '\$(?:self\._)?services\.(\w+)(?!.*if.*\$.*services)'
        $matches = [regex]::Matches($content, $serviceUsagePattern)
        foreach ($match in $matches) {
            # Look for a null check within 5 lines before this usage
            $lineStart = $content.LastIndexOf("`n", $match.Index, 200)
            if ($lineStart -lt 0) { $lineStart = 0 }
            $precedingCode = $content.Substring($lineStart, $match.Index - $lineStart)
            if ($precedingCode -notmatch 'if.*\$.*services') {
                $issues.MissingServiceCheck += @{
                    File = $fileName
                    Line = ($content.Substring(0, $match.Index) -split "`n").Count
                    Service = $match.Groups[1].Value
                    Code = $match.Value
                }
            }
        }
        
        # Pattern 3: Check for direct $global: access (should use services)
        $globalPattern = '\$global:(?!TuiState|Data)(\w+)'
        $matches = [regex]::Matches($content, $globalPattern)
        foreach ($match in $matches) {
            $issues.DirectGlobalAccess += @{
                File = $fileName
                Line = ($content.Substring(0, $match.Index) -split "`n").Count
                Global = $match.Groups[1].Value
                Code = $match.Value
            }
        }
        
        # Pattern 4: Check for components created but not stored on $self
        $componentPattern = '\$(\w+)\s*=\s*New-Tui(?:Label|Button|DataTable|TextBox|DropDown|GridPanel|StackPanel)'
        $matches = [regex]::Matches($content, $componentPattern)
        foreach ($match in $matches) {
            $varName = $match.Groups[1].Value
            # Check if this is used in a handler
            $handlerCheck = "(?ms)(Subscribe|OnClick|OnRowSelect|OnChange)[^{]*{[^}]*\$$varName"
            if ($content -match $handlerCheck -and $content -notmatch "\`$self\._?$varName\s*=") {
                $issues.UnstorredComponents += @{
                    File = $fileName
                    Line = ($content.Substring(0, $match.Index) -split "`n").Count
                    Component = $varName
                    Type = $match.Value
                }
            }
        }
        
        # Pattern 5: Check for incorrect $self references in component handlers
        $componentHandlerPattern = '(?ms)(OnClick|OnRowSelect|OnChange|OnInput)\s*=\s*{[^}]*\$self\.(?!_services)'
        $matches = [regex]::Matches($content, $componentHandlerPattern)
        foreach ($match in $matches) {
            if ($match.Value -match '\$self\.[^_]') {
                $issues.IncorrectSelfReference += @{
                    File = $fileName
                    Line = ($content.Substring(0, $match.Index) -split "`n").Count
                    Handler = $match.Groups[1].Value
                    Code = $match.Value.Substring(0, [Math]::Min($match.Value.Length, 100)) + "..."
                }
            }
        }
        
    } catch {
        Write-DiagnosticLog "Error analyzing $FilePath : $_" -Type Error
    }
}

# Main diagnostic routine
Write-DiagnosticLog "Starting Helios Scope Issue Diagnostic..."
Write-DiagnosticLog "Scanning directory: $Path"

# Find all PowerShell files
$files = Get-ChildItem -Path $Path -Include "*.ps1", "*.psm1" -Recurse -File | Where-Object { $_.FullName -notmatch "test|diagnostic|fixes" }

Write-DiagnosticLog "Found $($files.Count) files to analyze"

# Analyze each file
foreach ($file in $files) {
    if ($Verbose) {
        Write-DiagnosticLog "Analyzing: $($file.Name)"
    }
    Test-FileForScopeIssues -FilePath $file.FullName
}

# Generate report
Write-Host "`n`n========== DIAGNOSTIC REPORT ==========" -ForegroundColor Cyan

# Report local variable issues
if ($issues.LocalVariableInHandler.Count -gt 0) {
    Write-Host "`n[CRITICAL] Local Variables in Handlers/Subscriptions:" -ForegroundColor Red
    Write-Host "These variables may not be accessible when the handler executes:" -ForegroundColor Yellow
    foreach ($issue in $issues.LocalVariableInHandler) {
        Write-Host "`n  File: $($issue.File), Line: $($issue.Line)"
        Write-Host "  Variable: `$$($issue.Variable) used in $($issue.Context) handler"
        Write-Host "  Code: $($issue.Code)" -ForegroundColor DarkGray
        Write-Host "  FIX: Store as `$self._$($issue.Variable) before creating the handler" -ForegroundColor Green
    }
}

# Report unstored components
if ($issues.UnstorredComponents.Count -gt 0) {
    Write-Host "`n[CRITICAL] Components Not Stored on Self:" -ForegroundColor Red
    Write-Host "These components are used in handlers but not stored as screen properties:" -ForegroundColor Yellow
    foreach ($issue in $issues.UnstorredComponents) {
        Write-Host "`n  File: $($issue.File), Line: $($issue.Line)"
        Write-Host "  Component: `$$($issue.Component)"
        Write-Host "  Type: $($issue.Type)"
        Write-Host "  FIX: Add `$self._$($issue.Component) = `$$($issue.Component) after creation" -ForegroundColor Green
    }
}

# Report missing service checks
if ($issues.MissingServiceCheck.Count -gt 0) {
    Write-Host "`n[WARNING] Missing Service Null Checks:" -ForegroundColor Yellow
    Write-Host "These service usages don't have null checks:" -ForegroundColor Yellow
    foreach ($issue in $issues.MissingServiceCheck | Select-Object -First 5) {
        Write-Host "  File: $($issue.File), Line: $($issue.Line) - $($issue.Code)"
    }
    if ($issues.MissingServiceCheck.Count -gt 5) {
        Write-Host "  ... and $($issues.MissingServiceCheck.Count - 5) more"
    }
}

# Report direct global access
if ($issues.DirectGlobalAccess.Count -gt 0) {
    Write-Host "`n[WARNING] Direct Global Access:" -ForegroundColor Yellow
    Write-Host "These should use service injection instead:" -ForegroundColor Yellow
    foreach ($issue in $issues.DirectGlobalAccess | Select-Object -Unique -Property Global) {
        Write-Host "  `$global:$($issue.Global) - should be accessed via services"
    }
}

# Report incorrect self references
if ($issues.IncorrectSelfReference.Count -gt 0) {
    Write-Host "`n[ERROR] Incorrect Self References in Component Handlers:" -ForegroundColor Red
    Write-Host "In component handlers, `$self refers to the component, not the screen:" -ForegroundColor Yellow
    foreach ($issue in $issues.IncorrectSelfReference) {
        Write-Host "`n  File: $($issue.File), Line: $($issue.Line)"
        Write-Host "  Handler: $($issue.Handler)"
        Write-Host "  Code: $($issue.Code)" -ForegroundColor DarkGray
    }
}

# Summary
$totalIssues = $issues.Values | ForEach-Object { $_.Count } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
Write-Host "`n========== SUMMARY ==========" -ForegroundColor Cyan
Write-Host "Total Issues Found: $totalIssues" -ForegroundColor $(if ($totalIssues -gt 0) { "Red" } else { "Green" })

if ($totalIssues -gt 0) {
    Write-Host "`n[RECOMMENDATION] The primary fix is to ensure all components and data" -ForegroundColor Yellow
    Write-Host "needed by handlers are stored as properties on `$self before creating" -ForegroundColor Yellow
    Write-Host "the handlers. This ensures they remain accessible when handlers execute." -ForegroundColor Yellow
}

# Check current dashboard for specific issue
Write-Host "`n========== DASHBOARD SPECIFIC CHECK ==========" -ForegroundColor Cyan
$dashboardFile = Join-Path $Path "screens\dashboard-screen-helios.psm1"
if (Test-Path $dashboardFile) {
    $dashContent = Get-Content $dashboardFile -Raw
    
    # Check if quickActions is stored on $self
    if ($dashContent -match '\$quickActions\s*=\s*New-TuiDataTable' -and $dashContent -notmatch '\$self\._?quickActions\s*=') {
        Write-Host "[CRITICAL] quickActions DataTable is not stored on `$self!" -ForegroundColor Red
        Write-Host "This is causing the scope error. Add:" -ForegroundColor Yellow
        Write-Host '  $self._quickActions = $quickActions' -ForegroundColor Green
        Write-Host "After creating the component and before the subscription." -ForegroundColor Yellow
    } else {
        Write-Host "[OK] quickActions appears to be properly stored" -ForegroundColor Green
    }
}

Write-Host "`n========== END OF DIAGNOSTIC ==========" -ForegroundColor Cyan
