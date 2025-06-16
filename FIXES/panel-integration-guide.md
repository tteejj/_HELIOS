# Integration Instructions for Panel Component

## How to Add Panel to tui-components.psm1

### Step 1: Open `components/tui-components.psm1`

### Step 2: Add the New-TuiPanel function
Add this function to the file (anywhere after the other component functions):

```powershell
function global:New-TuiPanel {
    param([hashtable]$Props = @{})
    
    $component = @{
        Type = "Panel"
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 40
        Height = $Props.Height ?? 20
        Visible = $Props.Visible ?? $true
        IsFocusable = $Props.IsFocusable ?? $false
        Children = @()
        
        # Layout properties
        Layout = $Props.Layout ?? 'Stack'
        Orientation = $Props.Orientation ?? 'Vertical'
        Spacing = $Props.Spacing ?? 1
        Padding = $Props.Padding ?? 1
        ShowBorder = $Props.ShowBorder ?? $false
        Title = $Props.Title
        
        # ... rest of the implementation from simple-panel-component.ps1
    }
    
    return $component
}
```

### Step 3: Update Export-ModuleMember
At the bottom of the file, add 'New-TuiPanel' to the export list:

```powershell
Export-ModuleMember -Function @(
    'New-TuiLabel',
    'New-TuiButton',
    # ... other components ...
    'New-TuiPanel'  # <-- ADD THIS
)
```

## Example Usage in a Screen

### Before (with magic numbers):
```powershell
$self.Components.saveButton = New-TuiButton -Props @{
    X = 10; Y = 20; Width = 15; Height = 3; Text = "Save"
}
$self.Components.cancelButton = New-TuiButton -Props @{
    X = 30; Y = 20; Width = 15; Height = 3; Text = "Cancel"  # Manual X calculation
}
$self.Components.helpButton = New-TuiButton -Props @{
    X = 50; Y = 20; Width = 15; Height = 3; Text = "Help"    # More manual calculation
}
```

### After (with panel):
```powershell
# Create panel
$self.Components.buttonPanel = New-TuiPanel -Props @{
    X = 10; Y = 20; Width = 60; Height = 5
    Layout = 'Stack'
    Orientation = 'Horizontal'
    Spacing = 2
}

# Create buttons (no X/Y needed!)
$saveBtn = New-TuiButton -Props @{ Text = "Save"; Width = 15; Height = 3 }
$cancelBtn = New-TuiButton -Props @{ Text = "Cancel"; Width = 15; Height = 3 }
$helpBtn = New-TuiButton -Props @{ Text = "Help"; Width = 15; Height = 3 }

# Add to panel - it handles positioning
$panel = $self.Components.buttonPanel
$panel.AddChild($panel, $saveBtn)
$panel.AddChild($panel, $cancelBtn)
$panel.AddChild($panel, $helpBtn)
```

## Benefits
1. No manual X coordinate calculations
2. Easy to add/remove/reorder buttons
3. Automatic spacing between elements
4. Change orientation with one property
5. Responsive to panel size changes
