# Syntax checker for PowerShell modules

function Test-ModuleSyntax {
    param([string]$Path)
    
    try {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $Path,
            [ref]$tokens,
            [ref]$errors
        )
        
        if ($errors.Count -gt 0) {
            Write-Host "✗ Syntax errors in: $Path" -ForegroundColor Red
            foreach ($error in $errors) {
                Write-Host "  Line $($error.Extent.StartLineNumber): $($error.Message)" -ForegroundColor Yellow
                Write-Host "  Near: $($error.Extent.Text)" -ForegroundColor DarkYellow
            }
            return $false
        } else {
            Write-Host "✓ Syntax OK: $Path" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "✗ Failed to parse: $Path - $_" -ForegroundColor Red
        return $false
    }
}

# Check all modules
Write-Host "Checking module syntax..." -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

# Core modules
$modules = @(
    "event-system.psm1",
    "tui-engine-v2.psm1",
    "tui-components.psm1",
    "data-manager.psm1"
)

foreach ($module in $modules) {
    $modulePath = Join-Path $PSScriptRoot $module
    if (Test-Path $modulePath) {
        Test-ModuleSyntax -Path $modulePath
    }
}

# Screen modules
Write-Host "`nChecking screen modules..." -ForegroundColor Cyan
$screensPath = Join-Path $PSScriptRoot "screens"
Get-ChildItem -Path $screensPath -Filter "*.psm1" | ForEach-Object {
    Test-ModuleSyntax -Path $_.FullName
}

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
