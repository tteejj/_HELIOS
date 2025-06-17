# Cleanup-NumberedFiles.ps1
# This script removes numbered files created by incorrect > operator usage

Write-Host "Cleaning up numbered files..." -ForegroundColor Cyan

# Get all files that are just numbers
$numberedFiles = Get-ChildItem -Path . -File | Where-Object { 
    $_.Name -match '^\d+$' -and $_.Extension -eq ''
}

if ($numberedFiles) {
    Write-Host "Found $($numberedFiles.Count) numbered file(s) to delete:" -ForegroundColor Yellow
    
    foreach ($file in $numberedFiles) {
        Write-Host "  Deleting: $($file.Name) (Size: $($file.Length) bytes)" -ForegroundColor Red
        Remove-Item $file.FullName -Force
    }
    
    Write-Host "`nCleanup complete!" -ForegroundColor Green
} else {
    Write-Host "No numbered files found." -ForegroundColor Green
}
