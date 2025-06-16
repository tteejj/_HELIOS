# Simple Panel Component
# Add to components/tui-components.psm1

function global:New-TuiPanel {
    <#
    .SYNOPSIS
    Creates a container component that manages child layout automatically
    
    .PARAMETER Props
    Hashtable of properties including:
    - Layout: 'Stack' (default) or 'Grid'
    - Orientation: 'Vertical' (default) or 'Horizontal' (for Stack layout)
    - Spacing: Space between children (default 1)
    - Padding: Internal padding (default 1)
    - ShowBorder: Whether to draw a border (default false)
    
    .EXAMPLE
    $panel = New-TuiPanel -Props @{
        X = 10; Y = 5; Width = 50; Height = 20
        Layout = 'Stack'
        ShowBorder = $true
        Title = "My Panel"
    }
    $panel.AddChild($panel, $button1)
    $panel.AddChild($panel, $button2)
    #>
    param([hashtable]$Props = @{})
    
    $component = @{
        Type = "Panel"
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 40
        Height = $Props.Height ?? 20
        Visible = $Props.Visible ?? $true
        Children = @()
        
        # Layout properties
        Layout = $Props.Layout ?? 'Stack'
        Orientation = $Props.Orientation ?? 'Vertical'
        Spacing = $Props.Spacing ?? 1
        Padding = $Props.Padding ?? 1
        ShowBorder = $Props.ShowBorder ?? $false
        Title = $Props.Title
        
        # Methods
        AddChild = {
            param($self, $Child)
            $self.Children += $Child
            # Immediately recalculate layout
            & $self._RecalculateLayout -self $self
        }
        
        RemoveChild = {
            param($self, $Child)
            $self.Children = @($self.Children | Where-Object { $_ -ne $Child })
            & $self._RecalculateLayout -self $self
        }
        
        _RecalculateLayout = {
            param($self)
            
            # Calculate content area
            $contentX = $self.X + $self.Padding
            $contentY = $self.Y + $self.Padding
            $contentWidth = $self.Width - ($self.Padding * 2)
            $contentHeight = $self.Height - ($self.Padding * 2)
            
            if ($self.ShowBorder) {
                $contentX++
                $contentY++
                $contentWidth -= 2
                $contentHeight -= 2
            }
            
            # Apply layout
            switch ($self.Layout) {
                'Stack' {
                    $currentX = $contentX
                    $currentY = $contentY
                    
                    foreach ($child in $self.Children) {
                        if (-not $child.Visible) { continue }
                        
                        $child.X = $currentX
                        $child.Y = $currentY
                        
                        # Constrain child size to panel
                        if ($self.Orientation -eq 'Vertical') {
                            $child.Width = [Math]::Min($child.Width, $contentWidth)
                            $currentY += $child.Height + $self.Spacing
                        } else {
                            $child.Height = [Math]::Min($child.Height, $contentHeight)
                            $currentX += $child.Width + $self.Spacing
                        }
                    }
                }
                
                'Grid' {
                    # Simple grid - auto columns based on width
                    if ($self.Children.Count -eq 0) { return }
                    
                    # Estimate columns based on average child width
                    $avgWidth = 20
                    if ($self.Children[0].Width) {
                        $avgWidth = $self.Children[0].Width
                    }
                    
                    $cols = [Math]::Max(1, [Math]::Floor($contentWidth / ($avgWidth + $self.Spacing)))
                    $cellWidth = [Math]::Floor(($contentWidth - ($cols - 1) * $self.Spacing) / $cols)
                    
                    $row = 0
                    $col = 0
                    
                    foreach ($child in $self.Children) {
                        if (-not $child.Visible) { continue }
                        
                        $child.X = $contentX + ($col * ($cellWidth + $self.Spacing))
                        $child.Y = $contentY + ($row * ($child.Height + $self.Spacing))
                        $child.Width = [Math]::Min($child.Width, $cellWidth)
                        
                        $col++
                        if ($col -ge $cols) {
                            $col = 0
                            $row++
                        }
                    }
                }
            }
        }
        
        Render = {
            param($self)
            if (-not $self.Visible) { return }
            
            # Draw border if requested
            if ($self.ShowBorder) {
                $borderColor = if ($self.IsFocused) {
                    Get-ThemeColor "Accent" -Default ([ConsoleColor]::Cyan)
                } else {
                    Get-ThemeColor "Border" -Default ([ConsoleColor]::DarkGray)
                }
                
                Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height `
                    -BorderColor $borderColor -Title $self.Title
            }
            
            # Render children
            foreach ($child in $self.Children) {
                if ($child.Visible -and $child.Render) {
                    & $child.Render -self $child
                }
            }
        }
        
        HandleInput = {
            param($self, $Key)
            # Panels don't handle input directly, but could implement focus management
            return $false
        }
    }
    
    # Initial layout calculation
    & $component._RecalculateLayout -self $component
    
    return $component
}

# Example usage in a screen:
<#
# In screen Init:
$self.Components.buttonPanel = New-TuiPanel -Props @{
    X = 10; Y = 20; Width = 60; Height = 5
    Layout = 'Stack'
    Orientation = 'Horizontal'
    Spacing = 2
}

$saveBtn = New-TuiButton -Props @{ Text = "Save"; Width = 15; Height = 3 }
$cancelBtn = New-TuiButton -Props @{ Text = "Cancel"; Width = 15; Height = 3 }
$helpBtn = New-TuiButton -Props @{ Text = "Help"; Width = 15; Height = 3 }

$self.Components.buttonPanel.AddChild($self.Components.buttonPanel, $saveBtn)
$self.Components.buttonPanel.AddChild($self.Components.buttonPanel, $cancelBtn)
$self.Components.buttonPanel.AddChild($self.Components.buttonPanel, $helpBtn)

# The panel automatically positions the buttons horizontally with spacing
#>
