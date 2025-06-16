# Quick Implementation Script
# Run this to apply all fixes at once

$baseDir = "C:\Users\jhnhe\Documents\GitHub\pmc-terminal\modular\experimental features\new testgtound\fixed\current"

Write-Host "Applying TUI Framework Fixes..." -ForegroundColor Green

# Fix 1: DataTable Column Width
Write-Host "`nFix 1: Updating DataTable column width calculation..." -ForegroundColor Yellow

$dataTablePath = Join-Path $baseDir "components\advanced-data-components.psm1"
$dataTableContent = Get-Content $dataTablePath -Raw

# Find and replace the column width calculation
$oldCalc = @'
            $flexWidth = if ($flexColumns.Count -gt 0) { [Math]::Floor($remainingWidth / $flexColumns.Count) } else { 0 }
'@

$newCalc = @'
            # CRITICAL FIX: Ensure flex columns get adequate width, especially for single-column tables
            if ($flexColumns.Count -eq 1 -and $self.Columns.Count -eq 1) {
                # Single flex column should use full available width
                $flexWidth = $remainingWidth
            } elseif ($flexColumns.Count -gt 0) {
                $flexWidth = [Math]::Floor($remainingWidth / $flexColumns.Count)
            } else {
                $flexWidth = 0
            }
'@

if ($dataTableContent -match [regex]::Escape($oldCalc)) {
    $dataTableContent = $dataTableContent -replace [regex]::Escape($oldCalc), $newCalc
    Set-Content -Path $dataTablePath -Value $dataTableContent
    Write-Host "  ✓ DataTable column width calculation updated" -ForegroundColor Green
} else {
    Write-Host "  ! Could not find column width calculation to update" -ForegroundColor Red
}

# Fix 2: Task Screen Rendering Hierarchy
Write-Host "`nFix 2: Updating task screen rendering hierarchy..." -ForegroundColor Yellow

$taskScreenPath = Join-Path $baseDir "screens\task-screen.psm1"
$taskScreenContent = Get-Content $taskScreenPath -Raw

# Find and replace the render loop
$oldRender = @'
            foreach ($component in $self.Components.Values) {
                if ($component.Render) {
                    & $component.Render -self $component
                }
            }
'@

$newRender = @'
            foreach ($kvp in $self.Components.GetEnumerator()) {
                $component = $kvp.Value
                # CRITICAL FIX: Only render components that don't have a parent
                # This prevents child components from being rendered outside their parent's control
                if ($component -and $component.Render -and -not $component.Parent) {
                    & $component.Render -self $component
                }
            }
'@

if ($taskScreenContent -match [regex]::Escape($oldRender)) {
    $taskScreenContent = $taskScreenContent -replace [regex]::Escape($oldRender), $newRender
    Set-Content -Path $taskScreenPath -Value $taskScreenContent
    Write-Host "  ✓ Task screen render loop updated" -ForegroundColor Green
} else {
    Write-Host "  ! Could not find task screen render loop to update" -ForegroundColor Red
}

# Fix 3: Dashboard Screen Updates
Write-Host "`nFix 3: Updating dashboard screen..." -ForegroundColor Yellow

$dashboardPath = Join-Path $baseDir "screens\dashboard-screen-grid.psm1"
$dashboardContent = Get-Content $dashboardPath -Raw

# Update Quick Actions column definition
$oldColumn = '@{ Name = "Action"; Header = "Quick Actions" }'
$newColumn = '@{ Name = "Action"; Header = "Quick Actions"; Width = 32 }'

if ($dashboardContent -match [regex]::Escape($oldColumn)) {
    $dashboardContent = $dashboardContent -replace [regex]::Escape($oldColumn), $newColumn
    Write-Host "  ✓ Quick Actions column width set" -ForegroundColor Green
} else {
    Write-Host "  ! Could not find Quick Actions column definition" -ForegroundColor Red
}

# Update dashboard render loop
$oldDashRender = @'
                foreach ($kvp in $self.Components.GetEnumerator()) {
                    $component = $kvp.Value
                    if ($component -and $component.Visible -ne $false) {
                        # Set focus state based on screen's tracking
                        $component.IsFocused = ($self.FocusedComponentName -eq $kvp.Key)
                        if ($component.Render) {
                            & $component.Render -self $component
                        }
                    }
                }
'@

$newDashRender = @'
                foreach ($kvp in $self.Components.GetEnumerator()) {
                    $component = $kvp.Value
                    if ($component -and $component.Visible -ne $false -and -not $component.Parent) {
                        # Set focus state based on screen's tracking
                        $component.IsFocused = ($self.FocusedComponentName -eq $kvp.Key)
                        if ($component.Render) {
                            & $component.Render -self $component
                        }
                    }
                }
'@

if ($dashboardContent -match [regex]::Escape($oldDashRender)) {
    $dashboardContent = $dashboardContent -replace [regex]::Escape($oldDashRender), $newDashRender
    Set-Content -Path $dashboardPath -Value $dashboardContent
    Write-Host "  ✓ Dashboard render loop updated" -ForegroundColor Green
} else {
    Write-Host "  ! Could not find dashboard render loop to update" -ForegroundColor Red
}

Write-Host "`nAll fixes applied!" -ForegroundColor Green
Write-Host "Please restart your TUI application to see the changes." -ForegroundColor Cyan
