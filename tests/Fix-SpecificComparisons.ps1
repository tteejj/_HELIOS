# Fix-SpecificComparisons.ps1
# This script fixes specific known comparison operator issues

$ErrorActionPreference = "Stop"

Write-Host "Fixing specific comparison operator issues..." -ForegroundColor Cyan

# Define specific fixes for known files
$fixes = @(
    @{
        File = "components\tui-components.psm1"
        Fixes = @(
            @{ Find = 'if ($text.Length > $self.Width)'; Replace = 'if ($text.Length -gt $self.Width)' }
            @{ Find = 'if ($x > 0)'; Replace = 'if ($x -gt 0)' }
            @{ Find = 'if (($x + $text.Length) < $script:TuiState.BufferWidth)'; Replace = 'if (($x + $text.Length) -lt $global:TuiState.BufferWidth)' }
            @{ Find = '$text.Length < $self.MaxLength'; Replace = '$text.Length -lt $self.MaxLength' }
        )
    }
    @{
        File = "components\advanced-input-components.psm1"
        Fixes = @(
            @{ Find = '$self.SearchText.Length > 0'; Replace = '$self.SearchText.Length -gt 0' }
            @{ Find = '$matchIndex >= 0'; Replace = '$matchIndex -ge 0' }
            @{ Find = '$afterMatch < $text.Length'; Replace = '$afterMatch -lt $text.Length' }
        )
    }
    @{
        File = "modules\tui-framework.psm1"
        Fixes = @(
            @{ Find = '$self._changeQueue.Count > 0'; Replace = '$self._changeQueue.Count -gt 0' }
        )
    }
)

foreach ($fileInfo in $fixes) {
    $filePath = Join-Path $PSScriptRoot $fileInfo.File
    
    if (Test-Path $filePath) {
        Write-Host "Processing $($fileInfo.File)..." -ForegroundColor Gray
        
        $content = Get-Content $filePath -Raw
        $originalContent = $content
        $fixCount = 0
        
        foreach ($fix in $fileInfo.Fixes) {
            if ($content -match [regex]::Escape($fix.Find)) {
                $content = $content -replace [regex]::Escape($fix.Find), $fix.Replace
                $fixCount++
                Write-Host "  Fixed: $($fix.Find)" -ForegroundColor Yellow
            }
        }
        
        if ($content -ne $originalContent) {
            Set-Content -Path $filePath -Value $content -NoNewline
            Write-Host "  Applied $fixCount fixes" -ForegroundColor Green
        } else {
            Write-Host "  No changes needed" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "File not found: $($fileInfo.File)" -ForegroundColor Red
    }
}

Write-Host "`nDone!" -ForegroundColor Green
