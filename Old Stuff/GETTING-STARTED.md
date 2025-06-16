# Getting Started with TUI Framework

## Prerequisites
- PowerShell 5.1 or higher
- Windows Terminal or any terminal that supports ANSI escape codes
- Basic PowerShell knowledge

## Quick Start in 5 Minutes

### 1. Create Your First App

Create a file `my-first-app.ps1`:

```powershell
# Import the framework
Import-Module ./modules/tui-engine-v2.psm1
Import-Module ./modules/tui-framework.psm1
Import-Module ./modules/tui-components.psm1

# Define your screen
$screen = Create-TuiScreen -Definition @{
    Title = "My First TUI App"
    Components = @{
        welcome = @{
            Type = "Label"
            Properties = @{
                Text = "Welcome to TUI Framework!"
                X = 10; Y = 5
                ForegroundColor = "Cyan"
            }
        }
        nameInput = @{
            Type = "TextBox"
            Properties = @{
                X = 10; Y = 7
                Width = 30
                Placeholder = "Enter your name..."
                OnChange = {
                    param($self, $value)
                    $label = Get-TuiComponent -ComponentId "greeting"
                    if ($value) {
                        $label.Properties.Text = "Hello, $value!"
                    } else {
                        $label.Properties.Text = ""
                    }
                    Request-TuiRefresh
                }
            }
        }
        greeting = @{
            Type = "Label"
            Properties = @{
                Text = ""
                X = 10; Y = 9
                ForegroundColor = "Green"
            }
        }
        exitBtn = @{
            Type = "Button"
            Properties = @{
                Text = "Exit"
                X = 10; Y = 11
                OnClick = { Stop-TuiLoop }
            }
        }
    }
}

# Run the app
Initialize-TuiEngine
Push-TuiScreen -Screen $screen
Start-TuiLoop
```

### 2. Run Your App

```powershell
.\my-first-app.ps1
```

### 3. Interact
- Type your name in the text box
- See the greeting update in real-time
- Tab between components
- Press Enter on the Exit button

## Understanding the Structure

### Every TUI App Has Three Parts:

1. **Import Modules**
   ```powershell
   Import-Module ./modules/tui-engine-v2.psm1      # Core engine
   Import-Module ./modules/tui-framework.psm1      # Framework
   Import-Module ./modules/tui-components.psm1     # Components
   ```

2. **Define UI**
   ```powershell
   $screen = Create-TuiScreen -Definition @{
       Title = "Screen Title"
       Components = @{
           # Your components here
       }
   }
   ```

3. **Run Engine**
   ```powershell
   Initialize-TuiEngine
   Push-TuiScreen -Screen $screen
   Start-TuiLoop
   ```

## Next Steps

### Learn Components
Start with basic components:
- `Label` - Display text
- `Button` - User clicks
- `TextBox` - User input
- `Panel` - Group components

### Add Interactivity
Make components respond to user:
```powershell
OnClick = { 
    Write-Host "Button clicked!"
    Request-TuiRefresh
}
```

### Manage State
Use state for dynamic UIs:
```powershell
InitialState = @{
    counter = 0
}
# Later...
& $screen.State.Update @{ counter = 5 }
```

### Use Layouts
Organize components automatically:
```powershell
Layout = "Stack"
Orientation = "Vertical"
```

## Common Gotchas

### 1. Forgetting to Refresh
After changing UI, call:
```powershell
Request-TuiRefresh
```

### 2. Wrong Component Access
Get components correctly:
```powershell
# Good
$component = Get-TuiComponent -ComponentId "myButton"

# Also good (from screen)
$component = & $screen.GetComponent "myButton"
```

### 3. Event Handler Scope
Access screen from handlers:
```powershell
OnClick = {
    $screen = Get-TuiScreen
    # Now use $screen
}
```

## Debugging Tips

### 1. Check If Component Exists
```powershell
$comp = Get-TuiComponent -ComponentId "myComponent"
if ($comp) {
    Write-Host "Found it!"
}
```

### 2. Inspect State
```powershell
$screen = Get-TuiScreen
$value = & $screen.State.GetValue "myProperty"
Write-Host "Current value: $value"
```

### 3. Force Refresh
If UI seems stuck:
```powershell
Request-TuiRefresh
```

## Resources

- **Full Guide**: `docs/TUI-FRAMEWORK-GUIDE.md`
- **Quick Reference**: `docs/TUI-QUICK-REFERENCE.md`
- **Examples**: `docs/TUI-EXAMPLE-APPS.md`
- **Sample Screens**: Check `screens/` directory

## Get Help

If stuck:
1. Check the examples in `screens/` directory
2. Read the component properties in Quick Reference
3. Look for similar patterns in existing code
4. Remember: Everything is a hashtable with properties!

Happy TUI Building! 🚀
