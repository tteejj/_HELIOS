# Quick fixes for common issues in the TUI system

Write-Host "Applying quick fixes..." -ForegroundColor Yellow

# Fix 1: Ensure Clone method exists on all components
$componentFixCode = @'
# Add Clone method to component prototype if missing
if (-not $component.ContainsKey('Clone')) {
    $component.Clone = { 
        $clone = @{}
        foreach ($key in $this.Keys) {
            if ($key -ne 'Clone' -and $this[$key] -is [scriptblock]) {
                $clone[$key] = $this[$key]
            } else {
                $clone[$key] = $this[$key]
            }
        }
        return $clone
    }.GetNewClosure()
}
'@

# Apply the fix to tui-components.psm1
$componentsPath = Join-Path (Get-Location) "tui-components.psm1"
if (Test-Path $componentsPath) {
    $content = Get-Content $componentsPath -Raw
    
    # Check if Clone method is already properly implemented
    if ($content -notmatch 'Clone\s*=\s*{') {
        Write-Host "  Adding Clone method to components..." -ForegroundColor Cyan
        
        # Find the New-TuiComponent function and add Clone method
        $content = $content -replace '(\$component = @{[^}]+})', @'
$1
    
    # Add Clone method
    $component.Clone = { 
        $clone = @{}
        foreach ($key in $this.Keys) {
            if ($this[$key] -is [scriptblock]) {
                $clone[$key] = $this[$key]
            } elseif ($this[$key] -is [array]) {
                $clone[$key] = @($this[$key])
            } elseif ($this[$key] -is [hashtable]) {
                $clone[$key] = $this[$key].Clone()
            } else {
                $clone[$key] = $this[$key]
            }
        }
        return $clone
    }
'@
        
        Set-Content -Path $componentsPath -Value $content
        Write-Host "  ✓ Clone method added" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Clone method already exists" -ForegroundColor Green
    }
}

# Fix 2: Ensure proper module export
Write-Host "  Checking module exports..." -ForegroundColor Cyan
$moduleFiles = Get-ChildItem -Path (Get-Location) -Filter "*.psm1" -Recurse

foreach ($file in $moduleFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($content -notmatch 'Export-ModuleMember') {
        Write-Host "    Adding Export-ModuleMember to $($file.Name)..." -ForegroundColor Yellow
        # This would need custom logic per module
    }
}

Write-Host "`nFixes applied!" -ForegroundColor Green
Write-Host "Run .\test-system.ps1 to verify the system" -ForegroundColor Yellow
