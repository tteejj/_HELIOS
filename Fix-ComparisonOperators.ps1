# Fix-ComparisonOperators.ps1
# This script fixes incorrect use of > and < operators in PowerShell files
# Run this from the _HELIOS directory

$ErrorActionPreference = "Stop"

Write-Host "Fixing incorrect comparison operators in PowerShell files..." -ForegroundColor Cyan

# Get all PowerShell files
$files = Get-ChildItem -Path . -Include "*.ps1", "*.psm1" -Recurse | Where-Object { $_.FullName -notmatch "\\(Old Stuff|Not Main Files|Copies|FIXES)\\" }

$totalFixed = 0

foreach ($file in $files) {
    Write-Host "Checking $($file.Name)..." -ForegroundColor Gray
    
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    $fixes = 0
    
    # Fix > comparisons (but not >> or -> or =>)
    $content = $content -replace '(\$[\w\.]+\s*|\)\.Length\s*|\)\.Count\s*|\.Length\s*|\.Count\s*|\$[\w]+\s*)>(\s*[\$\d\(])', '$1-gt$2'
    
    # Fix < comparisons (but not << or <- or <=)  
    $content = $content -replace '(\$[\w\.]+\s*|\)\.Length\s*|\)\.Count\s*|\.Length\s*|\.Count\s*|\$[\w]+\s*)<(\s*[\$\d\(])', '$1-lt$2'
    
    # Fix >= comparisons
    $content = $content -replace '(\$[\w\.]+\s*|\)\.Length\s*|\)\.Count\s*|\.Length\s*|\.Count\s*|\$[\w]+\s*)>=(\s*[\$\d\(])', '$1-ge$2'
    
    # Fix <= comparisons
    $content = $content -replace '(\$[\w\.]+\s*|\)\.Length\s*|\)\.Count\s*|\.Length\s*|\.Count\s*|\$[\w]+\s*)<=(\s*[\$\d\(])', '$1-le$2'
    
    # Count fixes
    if ($content -ne $originalContent) {
        # Count number of replacements by comparing line by line
        $originalLines = $originalContent -split "`n"
        $newLines = $content -split "`n"
        
        for ($i = 0; $i -lt $originalLines.Count; $i++) {
            if ($i -lt $newLines.Count -and $originalLines[$i] -ne $newLines[$i]) {
                $fixes++
            }
        }
        
        # Write back the fixed content
        Set-Content -Path $file.FullName -Value $content -NoNewline
        
        Write-Host "  Fixed $fixes issues in $($file.Name)" -ForegroundColor Green
        $totalFixed += $fixes
    }
}

Write-Host "`nTotal fixes applied: $totalFixed" -ForegroundColor Yellow

# Clean up any numbered files that were created
Write-Host "`nCleaning up numbered files..." -ForegroundColor Cyan

$numberedFiles = Get-ChildItem -Path . -File | Where-Object { $_.Name -match '^\d+$' }
if ($numberedFiles) {
    Write-Host "Found $($numberedFiles.Count) numbered files to delete:" -ForegroundColor Yellow
    $numberedFiles | ForEach-Object {
        Write-Host "  Deleting: $($_.Name)" -ForegroundColor Red
        Remove-Item $_.FullName -Force
    }
} else {
    Write-Host "No numbered files found." -ForegroundColor Green
}

Write-Host "`nDone!" -ForegroundColor Green
