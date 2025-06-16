# Syntax checker for PowerShell files
param(
    [string]$Path = "."
)

Write-Host "PowerShell Syntax Checker" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host ""

# Get all PowerShell files
$files = Get-ChildItem -Path $Path -Include "*.ps1", "*.psm1" -Recurse -File

$errorCount = 0
$fileCount = 0

foreach ($file in $files) {
    $fileCount++
    Write-Host -NoNewline "Checking: $($file.Name)... "
    
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $file.FullName -Raw), [ref]$null)
        Write-Host "[OK]" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR]" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        $errorCount++
    }
}

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Files checked: $fileCount"
Write-Host "  Errors found: $errorCount" -ForegroundColor $(if ($errorCount -eq 0) { "Green" } else { "Red" })
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")