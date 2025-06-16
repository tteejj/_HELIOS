# TUI Framework Complete Guide

## Table of Contents
1. [Framework Overview](#framework-overview)
2. [File Structure](#file-structure)
3. [Core Concepts](#core-concepts)
4. [Quick Start](#quick-start)
5. [Component System](#component-system)
6. [Event System](#event-system)
7. [Layout System](#layout-system)
8. [API Reference](#api-reference)
9. [Best Practices](#best-practices)
10. [Common Patterns](#common-patterns)
11. [Additional Fixes Needed](#additional-fixes-needed)

---

## Framework Overview

The TUI Framework is a PowerShell-based terminal user interface system that provides:
- Component-based UI development
- Event-driven architecture
- Layout management systems
- State management
- Double-buffered rendering for flicker-free display
- Keyboard input handling (mouse support planned)

### Core Architecture
```
┌─────────────────────────────────────────────┐
│              Application Layer              │
│  (Your screens, dialogs, business logic)    │
├─────────────────────────────────────────────┤
│             Framework Layer                 │
│  (Components, Forms, State Management)      │
├─────────────────────────────────────────────┤
│              Engine Layer                   │
│  (Rendering, Input, Event Loop)            │
└─────────────────────────────────────────────┘
```

---

## File Structure

```
current/
├── modules/
│   ├── tui-engine-v2.psm1          # Core rendering engine
│   ├── tui-framework.psm1          # Component system & state management
│   ├── tui-components.psm1         # Basic UI components
│   ├── advanced-data-components.psm1 # Complex data display components
│   └── event-system.psm1           # Event handling infrastructure
│
├── screens/
│   ├── time-entry-screen.psm1      # Example application screen
│   ├── dashboard-screen-complex.psm1 # Complex dashboard example
│   └── task-management-screen.psm1  # Task management screen
│
├── themes/
│   └── modern-theme.ps1            # Theme configuration
│
└── main.ps1                        # Application entry point
```

### Module Responsibilities

**tui-engine-v2.psm1**
- Main rendering loop
- Buffer management
- Input handling
- Screen stack management

**tui-framework.psm1**
- Component factory (`Create-TuiComponent`)
- Screen management (`Create-TuiScreen`)
- State management (`Create-TuiState`)
- Form builder (`Create-TuiForm`)

**tui-components.psm1**
- Basic components: Label, Button, TextBox, ComboBox, etc.
- Component lifecycle management

**advanced-data-components.psm1**
- DataTable component
- ScrollableTextDisplay
- Complex data visualization

**event-system.psm1**
- Event publishing/subscription
- Event handler management

---

## Core Concepts

### 1. Components
Everything in the UI is a component. Components are hashtables with specific properties:

```powershell
@{
    Type = "ComponentType"
    Properties = @{
        # Component-specific properties
    }
    Children = @()  # Child components
    Render = { }    # Rendering logic
    HandleInput = { } # Input handling
}
```

### 2. Screens
Screens are special components that manage entire UI views:

```powershell
$screen = Create-TuiScreen -Definition @{
    Title = "My Screen"
    Layout = "Stack"  # or "Grid", "Dock"
    Components = @{
        myButton = @{
            Type = "Button"
            Properties = @{
                Text = "Click Me"
                OnClick = { Write-Host "Clicked!" }
            }
        }
    }
}
```

### 3. State Management
State is managed through the `Create-TuiState` system:

```powershell
$state = Create-TuiState -InitialState @{
    counter = 0
    userName = ""
}

# Update state
& $state.Update -Updates @{ counter = 5 }

# Subscribe to changes
& $state.Subscribe -Path "counter" -Handler {
    Write-Host "Counter changed to: $($args[0])"
}
```

### 4. Event System
Events flow through the system for communication:

```powershell
# Publish event
Publish-TuiEvent -EventName "User.LoggedIn" -EventData @{ UserName = "John" }

# Subscribe to event
Register-TuiEventHandler -EventName "User.LoggedIn" -Handler {
    param($eventData)
    Write-Host "User logged in: $($eventData.UserName)"
}
```

---

## Quick Start

### Minimal Application

```powershell
# main.ps1
Import-Module ./modules/tui-engine-v2.psm1
Import-Module ./modules/tui-framework.psm1
Import-Module ./modules/tui-components.psm1

# Create a simple screen
$screen = Create-TuiScreen -Definition @{
    Title = "Hello TUI"
    Components = @{
        greeting = @{
            Type = "Label"
            Properties = @{
                Text = "Welcome to TUI Framework!"
                X = 2
                Y = 2
            }
        }
        exitButton = @{
            Type = "Button"
            Properties = @{
                Text = "Exit"
                X = 2
                Y = 4
                OnClick = { 
                    Stop-TuiLoop 
                }
            }
        }
    }
}

# Initialize and run
Initialize-TuiEngine
Push-TuiScreen -Screen $screen
Start-TuiLoop
```

### Interactive Form Example

```powershell
$formScreen = Create-TuiScreen -Definition @{
    Title = "User Form"
    Layout = "Stack"
    Components = @{
        form = @{
            Type = "Form"
            Properties = @{
                Fields = @(
                    @{
                        Name = "username"
                        Label = "Username"
                        Type = "TextBox"
                        Required = $true
                    }
                    @{
                        Name = "age"
                        Label = "Age"
                        Type = "TextBox"
                        Validation = { param($value) 
                            if ($value -match '^\d+$') { @{Valid=$true} }
                            else { @{Valid=$false; Message="Must be a number"} }
                        }
                    }
                )
                OnSubmit = {
                    param($formData)
                    Write-Host "Form submitted: $($formData | ConvertTo-Json)"
                }
            }
        }
    }
}
```

---

## Component System

### Basic Components

#### Label
```powershell
@{
    Type = "Label"
    Properties = @{
        Text = "Display text"
        X = 0; Y = 0
        ForegroundColor = "White"
        BackgroundColor = "Black"
    }
}
```

#### Button
```powershell
@{
    Type = "Button"
    Properties = @{
        Text = "Click Me"
        X = 0; Y = 0
        OnClick = { param($self) }
        Disabled = $false
    }
}
```

#### TextBox
```powershell
@{
    Type = "TextBox"
    Properties = @{
        Value = ""
        X = 0; Y = 0
        Width = 20
        OnChange = { param($self, $newValue) }
        Placeholder = "Enter text..."
    }
}
```

#### ComboBox
```powershell
@{
    Type = "ComboBox"
    Properties = @{
        Items = @("Option1", "Option2", "Option3")
        SelectedIndex = 0
        X = 0; Y = 0
        Width = 20
        OnChange = { param($self, $selectedItem) }
    }
}
```

### Advanced Components

#### DataTable
```powershell
@{
    Type = "DataTable"
    Properties = @{
        Data = @() # Array of objects
        Columns = @(
            @{ Name = "ID"; Width = 10 }
            @{ Name = "Name"; Width = 20 }
        )
        Height = 10
        OnRowSelect = { param($self, $row) }
    }
}
```

### Custom Component Creation

```powershell
function New-MyCustomComponent {
    param($Properties)
    
    Create-TuiComponent -Type "MyCustom" -Properties $Properties -CustomMethods @{
        Init = {
            param($self)
            # Initialize component
            $self.InternalState = @{ counter = 0 }
        }
        
        Render = {
            param($self, $buffer, $x, $y)
            # Draw to buffer
            Write-BufferString -Buffer $buffer `
                -X $x -Y $y `
                -Text "Counter: $($self.InternalState.counter)"
        }
        
        HandleInput = {
            param($self, $key)
            if ($key.Key -eq "Add") {
                $self.InternalState.counter++
                Request-TuiRefresh
            }
        }
    }
}
```

---

## Event System

### Event Flow
1. User input → Engine → Component HandleInput
2. Component → Publish event
3. Event system → Notify subscribers
4. Subscribers → Update state/UI

### Common Events

```powershell
# System Events
"Tui.Initialized"
"Tui.Shutdown"
"Window.Resized"
"Screen.Pushed"
"Screen.Popped"

# Component Events
"Component.Focused"
"Component.Blurred"
"Component.ValueChanged"
"Component.Clicked"

# Custom Events
"User.LoggedIn"
"Data.Loaded"
"Task.Completed"
```

### Event Patterns

```powershell
# Publishing with data
Publish-TuiEvent -EventName "Data.Updated" -EventData @{
    RecordId = 123
    NewValue = "Updated"
    Timestamp = Get-Date
}

# Conditional event handling
Register-TuiEventHandler -EventName "Component.ValueChanged" -Handler {
    param($eventData)
    if ($eventData.ComponentId -eq "myTextBox") {
        # Handle specific component
    }
}
```

---

## Layout System

### Stack Layout
Arranges components vertically or horizontally:

```powershell
@{
    Layout = "Stack"
    Orientation = "Vertical"  # or "Horizontal"
    Spacing = 1
    Components = @{
        # Components arranged in stack
    }
}
```

### Grid Layout
Arranges components in rows and columns:

```powershell
@{
    Layout = "Grid"
    Rows = @(
        @{ Height = "Auto" }
        @{ Height = "*" }     # Remaining space
        @{ Height = 5 }       # Fixed height
    )
    Columns = @(
        @{ Width = 20 }
        @{ Width = "*" }
    )
    Components = @{
        header = @{
            Type = "Label"
            GridRow = 0
            GridColumn = 0
            GridColumnSpan = 2
        }
    }
}
```

### Dock Layout
Docks components to edges:

```powershell
@{
    Layout = "Dock"
    Components = @{
        header = @{
            Type = "Label"
            Dock = "Top"
            Height = 3
        }
        sidebar = @{
            Type = "Panel"
            Dock = "Left"
            Width = 20
        }
        content = @{
            Type = "Panel"
            Dock = "Fill"  # Takes remaining space
        }
    }
}
```

---

## API Reference

### Engine Functions

```powershell
# Initialize the TUI engine
Initialize-TuiEngine

# Start the main loop
Start-TuiLoop

# Stop the application
Stop-TuiLoop

# Force a screen refresh
Request-TuiRefresh

# Push a screen onto the stack
Push-TuiScreen -Screen $screen

# Pop the current screen
Pop-TuiScreen

# Show a dialog
Show-TuiDialog -Dialog $dialog
```

### Framework Functions

```powershell
# Create a screen
Create-TuiScreen -Definition @{ }

# Create a component
Create-TuiComponent -Type "Button" -Properties @{ }

# Create state manager
Create-TuiState -InitialState @{ }

# Create a form
Create-TuiForm -Definition @{ }

# Get component by ID
Get-TuiComponent -ComponentId "myButton"

# Update component properties
Update-TuiComponent -Component $component -Updates @{ }
```

### Component Methods

```powershell
# Common component methods (called via & operator)
& $component.SetFocus
& $component.GetValue
& $component.SetValue -Value "new value"
& $component.Enable
& $component.Disable
& $component.Show
& $component.Hide
```

---

## Best Practices

### 1. State Management
- Keep state centralized in screen's state manager
- Don't store state in component properties
- Use subscriptions for reactive updates

```powershell
# Good
$screen.State.Update(@{ userName = "John" })

# Bad
$component.Properties.userName = "John"
```

### 2. Event Handling
- Use events for loose coupling between components
- Clean up event handlers when components are destroyed
- Namespace your custom events

```powershell
# Good event naming
"MyApp.User.LoggedIn"
"MyApp.Data.Saved"

# Bad event naming
"UserLoggedIn"
"DataSaved"
```

### 3. Performance
- Minimize state updates
- Use RequestThrottledRefresh for rapid updates
- Process data outside render methods

```powershell
# Process data once on change
$component.ProcessedData = $data | Where-Object { $_.Active }

# Not on every render
Render = {
    $processed = $self.Data | Where-Object { $_.Active }  # Bad!
}
```

### 4. Layout
- Use layout managers instead of absolute positioning
- Make components responsive to container size
- Test with different terminal sizes

---

## Common Patterns

### Loading Data Asynchronously

```powershell
$screen = Create-TuiScreen -Definition @{
    Title = "Data Screen"
    Init = {
        param($self)
        
        # Show loading indicator
        & $self.State.Update @{ isLoading = $true }
        
        # Load data asynchronously
        Invoke-TuiAsync -ScriptBlock {
            # Simulate API call
            Start-Sleep -Seconds 2
            return Get-Process | Select -First 10
        } -OnComplete {
            param($data)
            & $self.State.Update @{
                isLoading = $false
                processes = $data
            }
            Request-TuiRefresh
        }
    }
}
```

### Modal Dialogs

```powershell
function Show-ConfirmDialog {
    param($Message, $OnConfirm, $OnCancel)
    
    $dialog = Create-TuiDialog -Definition @{
        Title = "Confirm"
        Width = 40
        Height = 10
        Components = @{
            message = @{
                Type = "Label"
                Properties = @{ Text = $Message }
            }
            buttons = @{
                Type = "Stack"
                Properties = @{
                    Orientation = "Horizontal"
                    Components = @{
                        yes = @{
                            Type = "Button"
                            Properties = @{
                                Text = "Yes"
                                OnClick = {
                                    Hide-TuiDialog
                                    & $OnConfirm
                                }
                            }
                        }
                        no = @{
                            Type = "Button"
                            Properties = @{
                                Text = "No"
                                OnClick = {
                                    Hide-TuiDialog
                                    & $OnCancel
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    Show-TuiDialog -Dialog $dialog
}
```

### Master-Detail View

```powershell
$screen = Create-TuiScreen -Definition @{
    Title = "Master-Detail"
    Layout = "Grid"
    Columns = @(
        @{ Width = 30 }  # Master list
        @{ Width = "*" } # Detail view
    )
    Components = @{
        list = @{
            Type = "DataTable"
            GridColumn = 0
            Properties = @{
                Data = $items
                OnRowSelect = {
                    param($self, $row)
                    $screen = Get-TuiScreen
                    & $screen.State.Update @{ selectedItem = $row }
                }
            }
        }
        detail = @{
            Type = "Panel"
            GridColumn = 1
            Properties = @{
                RenderContent = {
                    param($self)
                    $item = $self.Parent.State.GetValue("selectedItem")
                    if ($item) {
                        # Render item details
                    }
                }
            }
        }
    }
}
```

---

## Additional Fixes Needed

Beyond the issues noted in TUI-ENGINE-FIXES.txt, here are additional critical-to-medium priority fixes:

### Critical Issues

1. **Focus System Bugs**
   - Tab navigation skips disabled components incorrectly
   - Focus can get "lost" when removing focused component
   - No visual focus indicator on some components

2. **Memory Leaks**
   - Event handlers not cleaned up when components destroyed
   - Circular references between parent/child components
   - Background jobs from Invoke-TuiAsync not properly disposed

### High Priority Issues

3. **Input Handling Gaps**
   - No support for Ctrl+C/Ctrl+V clipboard operations
   - Function keys (F1-F12) not properly mapped
   - Input buffer can overflow with rapid typing

4. **Rendering Issues**
   - Unicode characters cause alignment problems
   - Color bleeding when using certain background colors
   - Screen artifacts when scrolling quickly

5. **State Management Issues**
   - Deep object updates don't trigger subscribers
   - State rollback/undo not implemented
   - No validation on state updates

### Medium Priority Issues

6. **Component Gaps**
   - No Tab/TabControl component
   - No TreeView component
   - No ProgressBar component
   - No Menu/MenuBar component

7. **Layout System Limitations**
   - No responsive breakpoints
   - Can't mix layout types (e.g., Grid inside Stack)
   - No margin/padding support

8. **Developer Experience**
   - No component validation at creation time
   - Poor error messages for common mistakes
   - No built-in debugging tools

### Implementation Priority Order

1. Fix memory leaks (Critical)
2. Fix focus system (Critical)
3. Add clipboard support (High)
4. Fix Unicode rendering (High)
5. Add missing core components (Medium)
6. Improve error messages (Medium)

---

## Next Steps

1. **Start Simple**: Create a basic screen with a few components
2. **Learn Events**: Add interactivity with event handlers
3. **Master State**: Use state management for reactive UI
4. **Build Complex**: Combine components into rich interfaces
5. **Contribute**: Share custom components with the community

For specific implementation examples, refer to the existing screens in the `screens/` directory.
