# TUI Framework Quick Reference

## Essential Functions

### Engine Control
```powershell
Initialize-TuiEngine              # Start the engine
Start-TuiLoop                    # Begin main loop
Stop-TuiLoop                     # Exit application
Request-TuiRefresh               # Force redraw
Request-TuiRefresh -Throttled    # Throttled redraw
```

### Screen Management
```powershell
Push-TuiScreen -Screen $screen   # Show new screen
Pop-TuiScreen                    # Go back
Show-TuiDialog -Dialog $dialog   # Show modal
Hide-TuiDialog                   # Close modal
Get-TuiScreen                    # Get current screen
```

### Component Creation
```powershell
Create-TuiScreen -Definition @{ }
Create-TuiComponent -Type "Button" -Properties @{ }
Create-TuiState -InitialState @{ }
Create-TuiForm -Definition @{ }
```

## Component Types

### Display
- **Label** - Static text
- **Panel** - Container
- **Border** - Bordered container

### Input
- **Button** - Clickable button
- **TextBox** - Text input
- **ComboBox** - Dropdown list
- **RadioGroup** - Radio buttons
- **CheckBox** - Toggle option

### Data
- **DataTable** - Tabular data
- **ScrollableTextDisplay** - Long text

### Layout
- **Stack** - Vertical/Horizontal
- **Grid** - Rows and columns
- **Dock** - Edge docking

## Component Properties

### Common to All
```powershell
X, Y                # Position
Width, Height       # Size
IsVisible          # Show/hide
IsEnabled          # Enable/disable
TabIndex           # Tab order
Name               # Component ID
```

### Events
```powershell
OnClick            # Button click
OnChange           # Value change
OnFocus            # Got focus
OnBlur             # Lost focus
OnKeyPress         # Key pressed
```

## State Management

```powershell
# Create state
$state = Create-TuiState -InitialState @{ count = 0 }

# Update
& $state.Update @{ count = 5 }

# Get value
$value = & $state.GetValue "count"

# Subscribe
& $state.Subscribe -Path "count" -Handler { }

# Unsubscribe
& $state.Unsubscribe -SubscriptionId $id
```

## Event System

```powershell
# Publish
Publish-TuiEvent -EventName "MyEvent" -EventData @{ }

# Subscribe
Register-TuiEventHandler -EventName "MyEvent" -Handler { }

# Unsubscribe
Unregister-TuiEventHandler -HandlerId $id
```

## Keyboard Shortcuts

### Navigation
- **Tab** - Next component
- **Shift+Tab** - Previous component
- **Arrow Keys** - Navigate lists/grids
- **Enter** - Activate button/select
- **Space** - Toggle checkbox/activate
- **Escape** - Cancel/close dialog

### Text Editing
- **Backspace** - Delete left
- **Delete** - Delete right
- **Home** - Start of line
- **End** - End of line
- **Ctrl+A** - Select all (planned)

## Color Names
```
Black, DarkBlue, DarkGreen, DarkCyan,
DarkRed, DarkMagenta, DarkYellow, Gray,
DarkGray, Blue, Green, Cyan,
Red, Magenta, Yellow, White
```

## Layout Examples

### Stack Layout
```powershell
@{
    Layout = "Stack"
    Orientation = "Vertical"  # or "Horizontal"
    Spacing = 1
    Components = @{ }
}
```

### Grid Layout
```powershell
@{
    Layout = "Grid"
    Rows = @(
        @{ Height = "Auto" }
        @{ Height = "*" }
        @{ Height = 10 }
    )
    Columns = @(
        @{ Width = 20 }
        @{ Width = "*" }
    )
    Components = @{
        item1 = @{
            Type = "Label"
            GridRow = 0
            GridColumn = 0
            GridColumnSpan = 2
        }
    }
}
```

## Common Patterns

### Simple Button
```powershell
button1 = @{
    Type = "Button"
    Properties = @{
        Text = "Click Me"
        X = 5; Y = 10
        OnClick = { 
            Write-Host "Clicked!"
            Request-TuiRefresh
        }
    }
}
```

### Text Input with Validation
```powershell
textbox1 = @{
    Type = "TextBox"
    Properties = @{
        X = 5; Y = 5
        Width = 20
        Validation = {
            param($value)
            if ($value.Length -ge 3) {
                @{ Valid = $true }
            } else {
                @{ Valid = $false; Message = "Min 3 chars" }
            }
        }
    }
}
```

### Data Table
```powershell
table1 = @{
    Type = "DataTable"
    Properties = @{
        X = 0; Y = 0
        Width = 50; Height = 20
        Data = Get-Process | Select Name, Id, CPU
        Columns = @(
            @{ Name = "Name"; Width = 20 }
            @{ Name = "Id"; Width = 10 }
            @{ Name = "CPU"; Width = 10 }
        )
        OnRowSelect = {
            param($self, $row)
            Write-Host "Selected: $($row.Name)"
        }
    }
}
```

## Debug Commands

```powershell
# In your code
Write-TuiDebug "Debug message"

# Check current state
$screen = Get-TuiScreen
$screen.State.GetValue("propertyName")

# Force refresh
Request-TuiRefresh

# Check focus
$focused = Get-TuiFocusedComponent
```
