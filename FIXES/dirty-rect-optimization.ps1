# Dirty Rectangle Optimization Patch
# Apply these changes to tui-engine-v2.psm1 for better performance

# Add to the $script:TuiState definition:
# DirtyRects = [System.Collections.Generic.List[hashtable]]::new()

# Enhanced Request-TuiRefresh function:
function global:Request-TuiRefresh {
    <#
    .SYNOPSIS
    Requests a screen refresh, optionally for just a specific component
    
    .PARAMETER Component
    If specified, only the area occupied by this component will be redrawn
    
    .EXAMPLE
    Request-TuiRefresh
    Request-TuiRefresh -Component $button
    #>
    param([hashtable]$Component)
    
    if ($Component) {
        # Component-specific refresh
        $rect = @{
            X = [Math]::Max(0, $Component.X - 1)
            Y = [Math]::Max(0, $Component.Y - 1)
            Width = $Component.Width + 2
            Height = $Component.Height + 2
        }
        
        # Ensure rect stays within screen bounds
        if (($rect.X + $rect.Width) -gt $script:TuiState.BufferWidth) {
            $rect.Width = $script:TuiState.BufferWidth - $rect.X
        }
        if (($rect.Y + $rect.Height) -gt $script:TuiState.BufferHeight) {
            $rect.Height = $script:TuiState.BufferHeight - $rect.Y
        }
        
        # Thread-safe add to dirty rects list
        if (-not $script:TuiState.DirtyRects) {
            $script:TuiState.DirtyRects = [System.Collections.Generic.List[hashtable]]::new()
        }
        
        [System.Threading.Monitor]::Enter($script:TuiState.DirtyRects)
        try {
            # Check if this rect overlaps with existing ones
            $merged = $false
            for ($i = 0; $i -lt $script:TuiState.DirtyRects.Count; $i++) {
                $existing = $script:TuiState.DirtyRects[$i]
                if (Rects-Overlap $rect $existing) {
                    # Merge rectangles
                    $script:TuiState.DirtyRects[$i] = Merge-Rects $rect $existing
                    $merged = $true
                    break
                }
            }
            
            if (-not $merged) {
                $script:TuiState.DirtyRects.Add($rect)
            }
        } finally {
            [System.Threading.Monitor]::Exit($script:TuiState.DirtyRects)
        }
    } else {
        # Full screen refresh
        $script:TuiState.IsDirty = $true
        if ($script:TuiState.DirtyRects) {
            $script:TuiState.DirtyRects.Clear()
        }
    }
}

# Helper functions for rectangle operations
function Rects-Overlap {
    param($rect1, $rect2)
    
    $left1 = $rect1.X
    $right1 = $rect1.X + $rect1.Width
    $top1 = $rect1.Y
    $bottom1 = $rect1.Y + $rect1.Height
    
    $left2 = $rect2.X
    $right2 = $rect2.X + $rect2.Width
    $top2 = $rect2.Y
    $bottom2 = $rect2.Y + $rect2.Height
    
    return -not ($left1 -ge $right2 -or $right1 -le $left2 -or $top1 -ge $bottom2 -or $bottom1 -le $top2)
}

function Merge-Rects {
    param($rect1, $rect2)
    
    $left = [Math]::Min($rect1.X, $rect2.X)
    $top = [Math]::Min($rect1.Y, $rect2.Y)
    $right = [Math]::Max($rect1.X + $rect1.Width, $rect2.X + $rect2.Width)
    $bottom = [Math]::Max($rect1.Y + $rect1.Height, $rect2.Y + $rect2.Height)
    
    return @{
        X = $left
        Y = $top
        Width = $right - $left
        Height = $bottom - $top
    }
}

# Enhanced Render-BufferOptimized function (partial render support):
function Render-DirtyRects {
    if (-not $script:TuiState.DirtyRects -or $script:TuiState.DirtyRects.Count -eq 0) {
        return
    }
    
    $outputBuilder = New-Object System.Text.StringBuilder -ArgumentList 5000
    $lastFG = -1
    $lastBG = -1
    
    [System.Threading.Monitor]::Enter($script:TuiState.DirtyRects)
    try {
        foreach ($rect in $script:TuiState.DirtyRects) {
            $startX = $rect.X
            $startY = $rect.Y
            $endX = [Math]::Min($startX + $rect.Width, $script:TuiState.BufferWidth) - 1
            $endY = [Math]::Min($startY + $rect.Height, $script:TuiState.BufferHeight) - 1
            
            for ($y = $startY; $y -le $endY; $y++) {
                # Position cursor at start of line segment
                $outputBuilder.Append("`e[$($y + 1);$($startX + 1)H") | Out-Null
                
                for ($x = $startX; $x -le $endX; $x++) {
                    $backCell = $script:TuiState.BackBuffer[$y, $x]
                    $frontCell = $script:TuiState.FrontBuffer[$y, $x]
                    
                    # Skip unchanged cells
                    if ($backCell.Char -eq $frontCell.Char -and 
                        $backCell.FG -eq $frontCell.FG -and 
                        $backCell.BG -eq $frontCell.BG) {
                        # Move cursor forward
                        $outputBuilder.Append("`e[C") | Out-Null
                        continue
                    }
                    
                    # Update colors if changed
                    if ($backCell.FG -ne $lastFG -or $backCell.BG -ne $lastBG) {
                        $fgCode = Get-AnsiColorCode $backCell.FG
                        $bgCode = Get-AnsiColorCode $backCell.BG -IsBackground $true
                        $outputBuilder.Append("`e[${fgCode};${bgCode}m") | Out-Null
                        $lastFG = $backCell.FG
                        $lastBG = $backCell.BG
                    }
                    
                    # Append character
                    $outputBuilder.Append($backCell.Char) | Out-Null
                    
                    # Update front buffer
                    $script:TuiState.FrontBuffer[$y, $x] = @{
                        Char = $backCell.Char
                        FG = $backCell.FG
                        BG = $backCell.BG
                    }
                }
            }
        }
        
        # Clear the dirty rects list
        $script:TuiState.DirtyRects.Clear()
        
    } finally {
        [System.Threading.Monitor]::Exit($script:TuiState.DirtyRects)
    }
    
    # Reset formatting and write to console
    $outputBuilder.Append("`e[0m") | Out-Null
    if ($outputBuilder.Length -gt 0) {
        [Console]::Write($outputBuilder.ToString())
    }
}

# Update the main Render-BufferOptimized to check for dirty rects:
# Add this at the beginning of Render-BufferOptimized:
# if ($script:TuiState.DirtyRects -and $script:TuiState.DirtyRects.Count -gt 0 -and -not $script:TuiState.IsDirty) {
#     Render-DirtyRects
#     return
# }
