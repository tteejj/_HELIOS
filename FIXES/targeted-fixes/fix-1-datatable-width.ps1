# Fix 1: DataTable Column Width Calculation
# File: components\advanced-data-components.psm1
# Issue: Quick Actions showing "..." due to incorrect column width calculation

# Find this section around line 114-130:
            # Calculate column widths
            $totalDefinedWidth = ($self.Columns | Where-Object { $_.Width } | Measure-Object -Property Width -Sum).Sum ?? 0
            $flexColumns = @($self.Columns | Where-Object { -not $_.Width })
            $columnSeparators = [Math]::Max(0, $self.Columns.Count - 1)  # Space between columns
            $remainingWidth = $innerWidth - $totalDefinedWidth - ($self.ShowRowNumbers ? 5 : 0) - $columnSeparators
            $flexWidth = if ($flexColumns.Count -gt 0) { [Math]::Floor($remainingWidth / $flexColumns.Count) } else { 0 }

# Replace with:
            # Calculate column widths - FIXED VERSION
            $totalDefinedWidth = ($self.Columns | Where-Object { $_.Width } | Measure-Object -Property Width -Sum).Sum ?? 0
            $flexColumns = @($self.Columns | Where-Object { -not $_.Width })
            $columnSeparators = if ($self.Columns.Count -gt 1) { $self.Columns.Count - 1 } else { 0 }  # Only add separators if multiple columns
            $remainingWidth = $innerWidth - $totalDefinedWidth - ($self.ShowRowNumbers ? 5 : 0) - $columnSeparators
            
            # CRITICAL FIX: Ensure flex columns get adequate width, especially for single-column tables
            if ($flexColumns.Count -eq 1 -and $self.Columns.Count -eq 1) {
                # Single flex column should use full available width
                $flexWidth = $remainingWidth
            } elseif ($flexColumns.Count -gt 0) {
                $flexWidth = [Math]::Floor($remainingWidth / $flexColumns.Count)
            } else {
                $flexWidth = 0
            }

# Additional fix for dashboard-screen-grid.psm1
# The Quick Actions table should specify a column width to prevent auto-calc issues
# Around line 47-53, change:
                        Columns = @(
                            @{ Name = "Action"; Header = "Quick Actions" }  # Let width auto-calculate
                        )

# To:
                        Columns = @(
                            @{ Name = "Action"; Header = "Quick Actions"; Width = 30 }  # Fixed width to prevent truncation
                        )
