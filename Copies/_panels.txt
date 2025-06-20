# FILE: layout/panels.psm1
# PURPOSE: Provides a suite of specialized layout panels for declarative UI construction.

function New-BasePanel {
    param([hashtable]$Props)
    
    $panel = @{
        Type = "Panel"
        Name = if ($null -ne $Props.Name) { $Props.Name } else { "Panel_$([Guid]::NewGuid().ToString('N').Substring(0,8))" }
        X = if ($null -ne $Props.X) { $Props.X } else { 0 }
        Y = if ($null -ne $Props.Y) { $Props.Y } else { 0 }
        Width = if ($null -ne $Props.Width) { $Props.Width } else { 40 }
        Height = if ($null -ne $Props.Height) { $Props.Height } else { 20 }
        Visible = if ($null -ne $Props.Visible) { $Props.Visible } else { $true }
        IsFocusable = if ($null -ne $Props.IsFocusable) { $Props.IsFocusable } else { $false }
        ZIndex = if ($null -ne $Props.ZIndex) { $Props.ZIndex } else { 0 }
        Children = @()
        Parent = $null
        LayoutProps = if ($null -ne $Props.LayoutProps) { $Props.LayoutProps } else { @{} }
        ShowBorder = if ($null -ne $Props.ShowBorder) { $Props.ShowBorder } else { $false }
        BorderStyle = if ($null -ne $Props.BorderStyle) { $Props.BorderStyle } else { "Single" }  # Single, Double, Rounded
        Title = $Props.Title
        Padding = if ($null -ne $Props.Padding) { $Props.Padding } else { 0 }
        Margin = if ($null -ne $Props.Margin) { $Props.Margin } else { 0 }
        BackgroundColor = $Props.BackgroundColor
        ForegroundColor = $Props.ForegroundColor
        _isDirty = $true
        _cachedLayout = $null
        
        AddChild = { 
            param($self, $Child, [hashtable]$LayoutProps = @{})
            
            if (-not $Child) {
                throw "Cannot add null child to panel"
            }
            
            $Child.Parent = $self
            $Child.LayoutProps = $LayoutProps
	    [void]($self.Children += $Child) # <<< FIX: Cast to [void] to suppress pipeline output
	    $self._isDirty = $true
            
            # Propagate visibility
            if (-not $self.Visible) {
                $Child.Visible = $false
            }
        }
        
        RemoveChild = {
            param($self, $Child)
            
            $self.Children = $self.Children | Where-Object { $_ -ne $Child }
            if ($Child.Parent -eq $self) {
                $Child.Parent = $null
            }
            $self._isDirty = $true
        }
        
        ClearChildren = {
            param($self)
            
            foreach ($child in $self.Children) {
                $child.Parent = $null
            }
            $self.Children = @()
            $self._isDirty = $true
        }
        
        Show = { 
            param($self)
            
            $self.Visible = $true
            foreach ($child in $self.Children) { 
                if ($child.Show) { 
                    & $child.Show -self $child
                } else { 
                    $child.Visible = $true
                }
            }
            
            # Request refresh if we have access to the function
            if (Get-Command -Name "Request-TuiRefresh" -ErrorAction SilentlyContinue) {
                Request-TuiRefresh
            }
        }
        
        Hide = { 
            param($self)
            
            $self.Visible = $false
            foreach ($child in $self.Children) { 
                if ($child.Hide) { 
                    & $child.Hide -self $child
                } else { 
                    $child.Visible = $false
                }
            }
            
            # Request refresh if we have access to the function
            if (Get-Command -Name "Request-TuiRefresh" -ErrorAction SilentlyContinue) {
                Request-TuiRefresh
            }
        }
        
        HandleInput = { 
            param($self, $Key)
            
            # Panels typically don't handle input directly
            # but can be overridden for special behavior
            return $false
        }
        
        GetContentBounds = {
            param($self)
            
            $borderOffset = if ($self.ShowBorder) { 1 } else { 0 }
            
            return @{
                X = $self.X + $self.Padding + $borderOffset + $self.Margin
                Y = $self.Y + $self.Padding + $borderOffset + $self.Margin
                Width = $self.Width - (2 * ($self.Padding + $borderOffset + $self.Margin))
                Height = $self.Height - (2 * ($self.Padding + $borderOffset + $self.Margin))
            }
        }
        
        InvalidateLayout = {
            param($self)
            
            $self._isDirty = $true
            
            # Propagate to parent
            if ($self.Parent -and $self.Parent.InvalidateLayout) {
                & $self.Parent.InvalidateLayout -self $self.Parent
            }
        }
    }
    
    return $panel
}

function global:New-TuiStackPanel {
    param([hashtable]$Props = @{})
    
    $panel = New-BasePanel -Props $Props
    $panel.Type = "StackPanel"
    $panel.Layout = 'Stack'
    $panel.Orientation = if ($null -ne $Props.Orientation) { $Props.Orientation } else { 'Vertical' }
    $panel.Spacing = if ($null -ne $Props.Spacing) { $Props.Spacing } else { 1 }
    $panel.HorizontalAlignment = if ($null -ne $Props.HorizontalAlignment) { $Props.HorizontalAlignment } else { 'Stretch' }  # Left, Center, Right, Stretch
    $panel.VerticalAlignment = if ($null -ne $Props.VerticalAlignment) { $Props.VerticalAlignment } else { 'Stretch' }      # Top, Middle, Bottom, Stretch
    
    $panel.CalculateLayout = {
        param($self)
        
        $bounds = & $self.GetContentBounds -self $self
        $layout = @{
            Children = @()
        }
        
        $currentX = $bounds.X
        $currentY = $bounds.Y
        $totalChildWidth = 0
        $totalChildHeight = 0
        $visibleChildren = $self.Children | Where-Object { $_.Visible }
        
        # Calculate total size needed
        foreach ($child in $visibleChildren) {
            if ($self.Orientation -eq 'Vertical') {
                $totalChildHeight += $child.Height
                $totalChildWidth = [Math]::Max($totalChildWidth, $child.Width)
            } else {
                $totalChildWidth += $child.Width
                $totalChildHeight = [Math]::Max($totalChildHeight, $child.Height)
            }
        }
        
        # Add spacing
        if ($visibleChildren.Count -gt 1) {
            if ($self.Orientation -eq 'Vertical') {
                $totalChildHeight += ($visibleChildren.Count - 1) * $self.Spacing
            } else {
                $totalChildWidth += ($visibleChildren.Count - 1) * $self.Spacing
            }
        }
        
        # Calculate starting position based on alignment
        if ($self.Orientation -eq 'Vertical') {
            switch ($self.VerticalAlignment) {
                'Top' { $currentY = $bounds.Y }
                'Middle' { $currentY = $bounds.Y + [Math]::Floor(($bounds.Height - $totalChildHeight) / 2) }
                'Bottom' { $currentY = $bounds.Y + $bounds.Height - $totalChildHeight }
                'Stretch' { $currentY = $bounds.Y }
            }
        } else {
            switch ($self.HorizontalAlignment) {
                'Left' { $currentX = $bounds.X }
                'Center' { $currentX = $bounds.X + [Math]::Floor(($bounds.Width - $totalChildWidth) / 2) }
                'Right' { $currentX = $bounds.X + $bounds.Width - $totalChildWidth }
                'Stretch' { $currentX = $bounds.X }
            }
        }
        
        # Layout children
        foreach ($child in $visibleChildren) {
            $childLayout = @{
                Component = $child
                X = $currentX
                Y = $currentY
                Width = $child.Width
                Height = $child.Height
            }
            
            # Apply stretch behavior
            if ($self.Orientation -eq 'Vertical' -and $self.HorizontalAlignment -eq 'Stretch') {
                $childLayout.Width = $bounds.Width
                # Update child's actual width for proper rendering
                if ($child.Width -ne $bounds.Width) {
                    $child.Width = $bounds.Width
                }
            }
            elseif ($self.Orientation -eq 'Horizontal' -and $self.VerticalAlignment -eq 'Stretch') {
                $childLayout.Height = $bounds.Height
                # Update child's actual height for proper rendering
                if ($child.Height -ne $bounds.Height) {
                    $child.Height = $bounds.Height
                }
            }
            
            # Handle horizontal alignment for vertical stacks
            if ($self.Orientation -eq 'Vertical' -and $self.HorizontalAlignment -ne 'Stretch') {
                switch ($self.HorizontalAlignment) {
                    'Center' { $childLayout.X = $bounds.X + [Math]::Floor(($bounds.Width - $child.Width) / 2) }
                    'Right' { $childLayout.X = $bounds.X + $bounds.Width - $child.Width }
                }
            }
            
            # Handle vertical alignment for horizontal stacks
            if ($self.Orientation -eq 'Horizontal' -and $self.VerticalAlignment -ne 'Stretch') {
                switch ($self.VerticalAlignment) {
                    'Middle' { $childLayout.Y = $bounds.Y + [Math]::Floor(($bounds.Height - $child.Height) / 2) }
                    'Bottom' { $childLayout.Y = $bounds.Y + $bounds.Height - $child.Height }
                }
            }
            
            # FIX: CRITICAL - Apply calculated positions and sizes back to the child component
            $child.X = $childLayout.X
            $child.Y = $childLayout.Y
            if ($childLayout.Width -ne $child.Width -and $child.PSObject.Properties['Width'].IsSettable) {
                $child.Width = $childLayout.Width
            }
            if ($childLayout.Height -ne $child.Height -and $child.PSObject.Properties['Height'].IsSettable) {
                $child.Height = $childLayout.Height
            }
            
            $layout.Children += $childLayout
            
            # Move to next position
            if ($self.Orientation -eq 'Vertical') {
                $currentY += $childLayout.Height + $self.Spacing
            } else {
                $currentX += $childLayout.Width + $self.Spacing
            }
        }
        
        $self._cachedLayout = $layout
        $self._isDirty = $false
        return $layout
    }
    
    $panel.Render = {
        param($self)
        if (-not $self.Visible) { return }
        
        # Clear panel area first to prevent bleed-through
        $bgColor = if ($self.BackgroundColor) { $self.BackgroundColor } else { Get-ThemeColor "Background" -Default Black }
        for ($y = $self.Y; $y -lt ($self.Y + $self.Height); $y++) {
            Write-BufferString -X $self.X -Y $y -Text (' ' * $self.Width) -BackgroundColor $bgColor
        }
        
        if ($self.ShowBorder) {
            $borderColor = if ($self.ForegroundColor) { $self.ForegroundColor } else { Get-ThemeColor "Border" -Default Gray }
            Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height -BorderColor $borderColor -Title $self.Title
        }
        # FIX: Ensure layout is calculated before Z-Index renderer processes children.
        & $self.CalculateLayout -self $self
    }
    
    return $panel
}

function global:New-TuiGridPanel {
    param([hashtable]$Props = @{})
    
    $panel = New-BasePanel -Props $Props
    $panel.Type = "GridPanel"
    $panel.Layout = 'Grid'
    $panel.RowDefinitions = if ($null -ne $Props.RowDefinitions) { $Props.RowDefinitions } else { @("1*") }
    $panel.ColumnDefinitions = if ($null -ne $Props.ColumnDefinitions) { $Props.ColumnDefinitions } else { @("1*") }
    $panel.ShowGridLines = if ($null -ne $Props.ShowGridLines) { $Props.ShowGridLines } else { $false }
    $panel.GridLineColor = if ($null -ne $Props.GridLineColor) { $Props.GridLineColor } else { Get-ThemeColor "BorderDim" -Default DarkGray }
    
    $panel._CalculateGridSizes = {
        param($self, $definitions, $totalSize)
        
        $parsedDefs = @()
        $totalFixed = 0
        $totalStars = 0.0
        
        foreach ($def in $definitions) {
            if ($def -match '^(\d+)$') {
                $parsedDefs += @{ Type = 'Fixed'; Value = [int]$Matches[1] }
                $totalFixed += [int]$Matches[1]
            } elseif ($def -match '^(\d*\.?\d*)\*$') {
                $stars = if ($Matches[1]) { [double]$Matches[1] } else { 1.0 }
                $parsedDefs += @{ Type = 'Star'; Value = $stars }
                $totalStars += $stars
            } elseif ($def -eq 'Auto') {
                $parsedDefs += @{ Type = 'Star'; Value = 1.0 }
                $totalStars += 1.0
            } else {
                throw "Invalid grid definition: $def"
            }
        }
        
        $remainingSize = [Math]::Max(0, $totalSize - $totalFixed)
        $sizes = @()
        
        foreach ($def in $parsedDefs) {
            if ($def.Type -eq 'Fixed') {
                $sizes += $def.Value
            } else {
                $size = if ($totalStars -gt 0) { [Math]::Floor($remainingSize * ($def.Value / $totalStars)) } else { 0 }
                $sizes += $size
            }
        }
        
        # FIX: Distribute rounding errors to the last star-sized cell to ensure total size is met.
        $totalAllocated = ($sizes | Measure-Object -Sum).Sum
        if ($totalAllocated -ne $totalSize -and $totalStars -gt 0) {
            $lastStarIndex = -1
            for($i = $parsedDefs.Count - 1; $i -ge 0; $i--) {
                if ($parsedDefs[$i].Type -eq 'Star') {
                    $lastStarIndex = $i; break
                }
            }
            if ($lastStarIndex -ne -1) {
                $sizes[$lastStarIndex] += ($totalSize - $totalAllocated)
            }
        }
        
        return $sizes
    }
    
    $panel.CalculateLayout = {
        param($self)
        
        $bounds = & $self.GetContentBounds -self $self
        
        $rowHeights = & $self._CalculateGridSizes -self $self -definitions $self.RowDefinitions -totalSize $bounds.Height
        $colWidths = & $self._CalculateGridSizes -self $self -definitions $self.ColumnDefinitions -totalSize $bounds.Width
        
        $rowOffsets = @(0); for ($i = 0; $i -lt $rowHeights.Count - 1; $i++) { $rowOffsets += ($rowOffsets[-1] + $rowHeights[$i]) }
        $colOffsets = @(0); for ($i = 0; $i -lt $colWidths.Count - 1; $i++) { $colOffsets += ($colOffsets[-1] + $colWidths[$i]) }
        
        $layout = @{ Children = @(); Rows = $rowHeights; Columns = $colWidths; RowOffsets = $rowOffsets; ColumnOffsets = $colOffsets }
        
        foreach ($child in $self.Children) {
            if (-not $child.Visible) { continue }
            
            $gridRow = if ($null -ne $child.LayoutProps."Grid.Row") { [int]$child.LayoutProps."Grid.Row" } else { 0 }
            $gridCol = if ($null -ne $child.LayoutProps."Grid.Column") { [int]$child.LayoutProps."Grid.Column" } else { 0 }
            $gridRowSpan = if ($null -ne $child.LayoutProps."Grid.RowSpan") { [int]$child.LayoutProps."Grid.RowSpan" } else { 1 }
            $gridColSpan = if ($null -ne $child.LayoutProps."Grid.ColumnSpan") { [int]$child.LayoutProps."Grid.ColumnSpan" } else { 1 }
            
            $row = [Math]::Max(0, [Math]::Min($rowHeights.Count - 1, $gridRow))
            $col = [Math]::Max(0, [Math]::Min($colWidths.Count - 1, $gridCol))
            $rowSpan = [Math]::Max(1, [Math]::Min($rowHeights.Count - $row, $gridRowSpan))
            $colSpan = [Math]::Max(1, [Math]::Min($colWidths.Count - $col, $gridColSpan))
            
            $cellX = $bounds.X + $colOffsets[$col]; $cellY = $bounds.Y + $rowOffsets[$row]
            $cellWidth = 0; for ($i = 0; $i -lt $colSpan; $i++) { if (($col + $i) -lt $colWidths.Count) { $cellWidth += $colWidths[$col + $i] } }
            $cellHeight = 0; for ($i = 0; $i -lt $rowSpan; $i++) { if (($row + $i) -lt $rowHeights.Count) { $cellHeight += $rowHeights[$row + $i] } }
            
            $childX = $cellX; $childY = $cellY
            $childWidth = $child.Width; $childHeight = $child.Height
            
            $hAlign = if ($null -ne $child.LayoutProps."Grid.HorizontalAlignment") { $child.LayoutProps."Grid.HorizontalAlignment" } else { "Stretch" }
            switch ($hAlign) {
                "Center" { $childX = $cellX + [Math]::Floor(($cellWidth - $childWidth) / 2) }
                "Right" { $childX = $cellX + $cellWidth - $childWidth }
                "Stretch" { $childWidth = $cellWidth }
            }
            
            $vAlign = if ($null -ne $child.LayoutProps."Grid.VerticalAlignment") { $child.LayoutProps."Grid.VerticalAlignment" } else { "Stretch" }
            switch ($vAlign) {
                "Middle" { $childY = $cellY + [Math]::Floor(($cellHeight - $childHeight) / 2) }
                "Bottom" { $childY = $cellY + $cellHeight - $childHeight }
                "Stretch" { $childHeight = $cellHeight }
            }
            
            # FIX: CRITICAL - Apply calculated positions and sizes back to the child component
            $child.X = $childX
            $child.Y = $childY
            if ($child.PSObject.Properties['Width'] -and $child.Width -ne $childWidth) { $child.Width = $childWidth }
            if ($child.PSObject.Properties['Height'] -and $child.Height -ne $childHeight) { $child.Height = $childHeight }
            
            $layout.Children += @{ Component = $child; X = $childX; Y = $childY; Width = $childWidth; Height = $childHeight }
        }
        
        $self._cachedLayout = $layout
        $self._isDirty = $false
        return $layout
    }
    
    $panel.Render = {
        param($self)
        if (-not $self.Visible) { return }
        
        # Clear panel area first to prevent bleed-through
        $bgColor = if ($self.BackgroundColor) { $self.BackgroundColor } else { Get-ThemeColor "Background" -Default Black }
        for ($y = $self.Y; $y -lt ($self.Y + $self.Height); $y++) {
            Write-BufferString -X $self.X -Y $y -Text (' ' * $self.Width) -BackgroundColor $bgColor
        }
        
        if ($self.ShowBorder) {
            $borderColor = if ($self.ForegroundColor) { $self.ForegroundColor } else { Get-ThemeColor "Border" -Default Gray }
            Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height -BorderColor $borderColor -Title $self.Title
        }
        
        # FIX: Calculate layout to set child positions. TUI engine will render the children.
        $layout = & $self.CalculateLayout -self $self
        
        if ($self.ShowGridLines) {
            $bounds = & $self.GetContentBounds -self $self
            foreach ($offset in $layout.ColumnOffsets[1..($layout.ColumnOffsets.Count - 1)]) {
                $x = $bounds.X + $offset; for ($y = $bounds.Y; $y -lt ($bounds.Y + $bounds.Height); $y++) { Write-BufferString -X $x -Y $y -Text "│" -ForegroundColor $self.GridLineColor }
            }
            foreach ($offset in $layout.RowOffsets[1..($layout.RowOffsets.Count - 1)]) {
                $y = $bounds.Y + $offset; Write-BufferString -X $bounds.X -Y $y -Text ("─" * $bounds.Width) -ForegroundColor $self.GridLineColor
            }
        }
    }
    
    return $panel
}

function global:New-TuiDockPanel { param([hashtable]$Props = @{}) ; return New-TuiStackPanel -Props ($Props.Clone() | Add-Member -MemberType NoteProperty -Name Orientation -Value 'Vertical' -PassThru) }
function global:New-TuiWrapPanel { param([hashtable]$Props = @{}) ; return New-TuiStackPanel -Props $Props }

Export-ModuleMember -Function "New-BasePanel", "New-TuiStackPanel", "New-TuiGridPanel", "New-TuiDockPanel", "New-TuiWrapPanel"