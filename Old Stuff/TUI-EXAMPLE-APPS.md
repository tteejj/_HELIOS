# TUI Framework Example Applications

## 1. Hello World Application

```powershell
# hello-world.ps1
# The simplest possible TUI application

# Import required modules
Import-Module ./modules/tui-engine-v2.psm1
Import-Module ./modules/tui-framework.psm1
Import-Module ./modules/tui-components.psm1

# Create screen with a label and button
$screen = Create-TuiScreen -Definition @{
    Title = "Hello World"
    Components = @{
        label1 = @{
            Type = "Label"
            Properties = @{
                Text = "Hello, TUI World!"
                X = 10
                Y = 5
                ForegroundColor = "Cyan"
            }
        }
        exitBtn = @{
            Type = "Button"
            Properties = @{
                Text = "Exit"
                X = 10
                Y = 7
                OnClick = { Stop-TuiLoop }
            }
        }
    }
}

# Run the application
Initialize-TuiEngine
Push-TuiScreen -Screen $screen
Start-TuiLoop
```

## 2. Interactive Counter Application

```powershell
# counter-app.ps1
# Demonstrates state management and event handling

Import-Module ./modules/tui-engine-v2.psm1
Import-Module ./modules/tui-framework.psm1
Import-Module ./modules/tui-components.psm1

$screen = Create-TuiScreen -Definition @{
    Title = "Counter App"
    InitialState = @{
        count = 0
    }
    Init = {
        param($self)
        # Subscribe to count changes
        & $self.State.Subscribe -Path "count" -Handler {
            param($newValue)
            $label = & $self.GetComponent "countLabel"
            $label.Properties.Text = "Count: $newValue"
            Request-TuiRefresh
        }
    }
    Components = @{
        countLabel = @{
            Type = "Label"
            Properties = @{
                Text = "Count: 0"
                X = 10
                Y = 5
            }
        }
        incrementBtn = @{
            Type = "Button"
            Properties = @{
                Text = "Increment"
                X = 10
                Y = 7
                OnClick = {
                    param($self)
                    $screen = Get-TuiScreen
                    $current = & $screen.State.GetValue "count"
                    & $screen.State.Update @{ count = $current + 1 }
                }
            }
        }
        decrementBtn = @{
            Type = "Button"
            Properties = @{
                Text = "Decrement"
                X = 25
                Y = 7
                OnClick = {
                    param($self)
                    $screen = Get-TuiScreen
                    $current = & $screen.State.GetValue "count"
                    & $screen.State.Update @{ count = $current - 1 }
                }
            }
        }
        resetBtn = @{
            Type = "Button"
            Properties = @{
                Text = "Reset"
                X = 40
                Y = 7
                OnClick = {
                    $screen = Get-TuiScreen
                    & $screen.State.Update @{ count = 0 }
                }
            }
        }
    }
}

Initialize-TuiEngine
Push-TuiScreen -Screen $screen
Start-TuiLoop
```

## 3. Todo List Application

```powershell
# todo-app.ps1
# Demonstrates forms, data tables, and complex state

Import-Module ./modules/tui-engine-v2.psm1
Import-Module ./modules/tui-framework.psm1
Import-Module ./modules/tui-components.psm1
Import-Module ./modules/advanced-data-components.psm1

$screen = Create-TuiScreen -Definition @{
    Title = "Todo List"
    Layout = "Stack"
    InitialState = @{
        todos = @()
        newTodoText = ""
    }
    Init = {
        param($self)
        # Update table when todos change
        & $self.State.Subscribe -Path "todos" -Handler {
            param($todos)
            $table = & $self.GetComponent "todoTable"
            $table.Properties.Data = $todos
            Request-TuiRefresh
        }
    }
    Components = @{
        header = @{
            Type = "Label"
            Properties = @{
                Text = "My Todo List"
                ForegroundColor = "Cyan"
            }
        }
        inputPanel = @{
            Type = "Stack"
            Properties = @{
                Orientation = "Horizontal"
                Spacing = 2
                Components = @{
                    todoInput = @{
                        Type = "TextBox"
                        Properties = @{
                            Width = 30
                            Placeholder = "Enter new todo..."
                            OnChange = {
                                param($self, $value)
                                $screen = Get-TuiScreen
                                & $screen.State.Update @{ newTodoText = $value }
                            }
                        }
                    }
                    addBtn = @{
                        Type = "Button"
                        Properties = @{
                            Text = "Add"
                            OnClick = {
                                $screen = Get-TuiScreen
                                $text = & $screen.State.GetValue "newTodoText"
                                if ($text) {
                                    $todos = & $screen.State.GetValue "todos"
                                    $newTodo = @{
                                        Id = [Guid]::NewGuid().ToString()
                                        Text = $text
                                        Done = $false
                                        Created = Get-Date
                                    }
                                    $todos += $newTodo
                                    & $screen.State.Update @{ 
                                        todos = $todos
                                        newTodoText = ""
                                    }
                                    # Clear input
                                    $input = & $screen.GetComponent "todoInput"
                                    & $input.SetValue ""
                                }
                            }
                        }
                    }
                }
            }
        }
        todoTable = @{
            Type = "DataTable"
            Properties = @{
                Height = 15
                Data = @()
                Columns = @(
                    @{ Name = "Done"; Width = 6 }
                    @{ Name = "Text"; Width = 40 }
                    @{ Name = "Created"; Width = 20 }
                )
                RenderCell = {
                    param($column, $row)
                    switch ($column.Name) {
                        "Done" { if ($row.Done) { "[X]" } else { "[ ]" } }
                        "Text" { $row.Text }
                        "Created" { $row.Created.ToString("yyyy-MM-dd HH:mm") }
                    }
                }
                OnRowSelect = {
                    param($self, $row)
                    # Toggle done status
                    $screen = Get-TuiScreen
                    $todos = & $screen.State.GetValue "todos"
                    $todo = $todos | Where-Object { $_.Id -eq $row.Id }
                    if ($todo) {
                        $todo.Done = -not $todo.Done
                        & $screen.State.Update @{ todos = $todos }
                    }
                }
            }
        }
        statusBar = @{
            Type = "Label"
            Properties = @{
                Text = "Press Enter to toggle todo, Tab to navigate"
                ForegroundColor = "DarkGray"
            }
        }
    }
}

Initialize-TuiEngine
Push-TuiScreen -Screen $screen
Start-TuiLoop
```

## 4. Multi-Screen Navigation Example

```powershell
# multi-screen-app.ps1
# Demonstrates screen navigation and passing data between screens

Import-Module ./modules/tui-engine-v2.psm1
Import-Module ./modules/tui-framework.psm1
Import-Module ./modules/tui-components.psm1

# Main menu screen
$mainScreen = Create-TuiScreen -Definition @{
    Title = "Main Menu"
    Components = @{
        title = @{
            Type = "Label"
            Properties = @{
                Text = "Choose an Option"
                X = 10
                Y = 5
            }
        }
        userBtn = @{
            Type = "Button"
            Properties = @{
                Text = "User Settings"
                X = 10
                Y = 7
                OnClick = {
                    $userScreen = Create-UserSettingsScreen
                    Push-TuiScreen -Screen $userScreen
                }
            }
        }
        aboutBtn = @{
            Type = "Button"
            Properties = @{
                Text = "About"
                X = 10
                Y = 9
                OnClick = {
                    $aboutScreen = Create-AboutScreen
                    Push-TuiScreen -Screen $aboutScreen
                }
            }
        }
        exitBtn = @{
            Type = "Button"
            Properties = @{
                Text = "Exit"
                X = 10
                Y = 11
                OnClick = { Stop-TuiLoop }
            }
        }
    }
}

function Create-UserSettingsScreen {
    Create-TuiScreen -Definition @{
        Title = "User Settings"
        InitialState = @{
            username = ""
            notifications = $true
        }
        Components = @{
            form = @{
                Type = "Form"
                Properties = @{
                    Fields = @(
                        @{
                            Name = "username"
                            Label = "Username"
                            Type = "TextBox"
                        }
                        @{
                            Name = "notifications"
                            Label = "Enable Notifications"
                            Type = "CheckBox"
                        }
                    )
                    OnSubmit = {
                        param($formData)
                        Write-Host "Settings saved: $($formData | ConvertTo-Json)"
                        Pop-TuiScreen
                    }
                    OnCancel = {
                        Pop-TuiScreen
                    }
                }
            }
        }
    }
}

function Create-AboutScreen {
    Create-TuiScreen -Definition @{
        Title = "About"
        Components = @{
            info = @{
                Type = "ScrollableTextDisplay"
                Properties = @{
                    X = 5
                    Y = 2
                    Width = 50
                    Height = 15
                    Text = @"
TUI Framework Demo Application
Version 1.0.0

This application demonstrates:
- Multi-screen navigation
- Form handling
- State management
- Component interaction

Built with PowerShell TUI Framework

Press Escape to go back
"@
                }
            }
            backBtn = @{
                Type = "Button"
                Properties = @{
                    Text = "Back"
                    X = 5
                    Y = 18
                    OnClick = { Pop-TuiScreen }
                }
            }
        }
        HandleInput = {
            param($self, $key)
            if ($key.Key -eq "Escape") {
                Pop-TuiScreen
                return $true
            }
            return $false
        }
    }
}

# Run application
Initialize-TuiEngine
Push-TuiScreen -Screen $mainScreen
Start-TuiLoop
```

## 5. Data Loading with Progress Example

```powershell
# data-loading-app.ps1
# Demonstrates async operations and loading states

Import-Module ./modules/tui-engine-v2.psm1
Import-Module ./modules/tui-framework.psm1
Import-Module ./modules/tui-components.psm1
Import-Module ./modules/advanced-data-components.psm1

$screen = Create-TuiScreen -Definition @{
    Title = "Process Viewer"
    InitialState = @{
        isLoading = $true
        processes = @()
        error = $null
    }
    Init = {
        param($self)
        
        # Subscribe to loading state
        & $self.State.Subscribe -Path "isLoading" -Handler {
            param($isLoading)
            $loadingLabel = & $self.GetComponent "loadingLabel"
            $dataTable = & $self.GetComponent "processTable"
            
            if ($isLoading) {
                $loadingLabel.Properties.IsVisible = $true
                $dataTable.Properties.IsVisible = $false
            } else {
                $loadingLabel.Properties.IsVisible = $false
                $dataTable.Properties.IsVisible = $true
            }
            Request-TuiRefresh
        }
        
        # Subscribe to process data
        & $self.State.Subscribe -Path "processes" -Handler {
            param($processes)
            $dataTable = & $self.GetComponent "processTable"
            $dataTable.Properties.Data = $processes
            Request-TuiRefresh
        }
        
        # Load data
        Invoke-TuiAsync -ScriptBlock {
            # Simulate slow data loading
            Start-Sleep -Seconds 2
            
            # Get process data
            $procs = Get-Process | Select-Object -First 50 |
                Select-Object Name, Id, 
                    @{Name="CPU"; Expression={[Math]::Round($_.CPU, 2)}},
                    @{Name="Memory(MB)"; Expression={[Math]::Round($_.WorkingSet64/1MB, 2)}}
            
            return $procs
        } -OnComplete {
            param($data)
            $screen = Get-TuiScreen
            & $screen.State.Update @{
                isLoading = $false
                processes = $data
            }
        } -OnError {
            param($error)
            $screen = Get-TuiScreen
            & $screen.State.Update @{
                isLoading = $false
                error = $error.ToString()
            }
        }
    }
    Components = @{
        loadingLabel = @{
            Type = "Label"
            Properties = @{
                Text = "Loading processes..."
                X = 20
                Y = 10
                ForegroundColor = "Yellow"
            }
        }
        processTable = @{
            Type = "DataTable"
            Properties = @{
                X = 2
                Y = 2
                Width = 76
                Height = 20
                IsVisible = $false
                Columns = @(
                    @{ Name = "Name"; Width = 25 }
                    @{ Name = "Id"; Width = 10 }
                    @{ Name = "CPU"; Width = 15 }
                    @{ Name = "Memory(MB)"; Width = 15 }
                )
            }
        }
        refreshBtn = @{
            Type = "Button"
            Properties = @{
                Text = "Refresh"
                X = 2
                Y = 23
                OnClick = {
                    # Re-run init to reload data
                    $screen = Get-TuiScreen
                    & $screen.Init $screen
                }
            }
        }
    }
}

Initialize-TuiEngine
Push-TuiScreen -Screen $screen
Start-TuiLoop
```

## Running the Examples

1. Save any example to a `.ps1` file in the `current` directory
2. Run with: `.\example-name.ps1`
3. Use Tab to navigate between components
4. Press Enter or Space to activate buttons
5. Use arrow keys in data tables

## Key Concepts Demonstrated

- **State Management**: All examples use centralized state
- **Event Handling**: Buttons trigger state updates
- **Component Communication**: Components interact through state and events
- **Layout**: Both absolute positioning and layout managers
- **Async Operations**: Loading data without blocking UI
- **Navigation**: Moving between screens
- **Forms**: Collecting user input
- **Data Display**: Tables and scrollable text
