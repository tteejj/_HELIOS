# Example: Hello World TUI Application
# Save this as hello-world-example.ps1 and run it

# Import required modules
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module "$scriptPath/modules/tui-engine-v2.psm1" -Force
Import-Module "$scriptPath/modules/tui-framework.psm1" -Force
Import-Module "$scriptPath/modules/tui-components.psm1" -Force

# Create a simple screen
$screen = Create-TuiScreen -Definition @{
    Title = "Hello World - TUI Framework Demo"
    Components = @{
        # Title label
        titleLabel = @{
            Type = "Label"
            Properties = @{
                Text = "Welcome to TUI Framework!"
                X = 15
                Y = 5
                ForegroundColor = "Cyan"
            }
        }
        
        # Instructions
        instructions = @{
            Type = "Label"
            Properties = @{
                Text = "Use Tab to move between components"
                X = 15
                Y = 7
                ForegroundColor = "DarkGray"
            }
        }
        
        # Name input
        nameLabel = @{
            Type = "Label"
            Properties = @{
                Text = "Your name:"
                X = 15
                Y = 10
            }
        }
        nameInput = @{
            Type = "TextBox"
            Properties = @{
                X = 26
                Y = 10
                Width = 20
                Placeholder = "Enter name..."
                OnChange = {
                    param($self, $value)
                    $greetingLabel = Get-TuiComponent -ComponentId "greetingLabel"
                    if ($value) {
                        $greetingLabel.Properties.Text = "Hello, $value! Welcome to TUI Framework!"
                        $greetingLabel.Properties.ForegroundColor = "Green"
                    } else {
                        $greetingLabel.Properties.Text = "Enter your name above"
                        $greetingLabel.Properties.ForegroundColor = "DarkGray"
                    }
                    Request-TuiRefresh
                }
            }
        }
        
        # Greeting display
        greetingLabel = @{
            Type = "Label"
            Properties = @{
                Text = "Enter your name above"
                X = 15
                Y = 13
                ForegroundColor = "DarkGray"
            }
        }
        
        # Counter demo
        counterLabel = @{
            Type = "Label"
            Properties = @{
                Text = "Counter: 0"
                X = 15
                Y = 16
            }
        }
        incrementBtn = @{
            Type = "Button"
            Properties = @{
                Text = " + "
                X = 27
                Y = 16
                OnClick = {
                    $label = Get-TuiComponent -ComponentId "counterLabel"
                    if ($label.Properties.Text -match "Counter: (\d+)") {
                        $count = [int]$matches[1] + 1
                        $label.Properties.Text = "Counter: $count"
                        Request-TuiRefresh
                    }
                }
            }
        }
        decrementBtn = @{
            Type = "Button"
            Properties = @{
                Text = " - "
                X = 33
                Y = 16
                OnClick = {
                    $label = Get-TuiComponent -ComponentId "counterLabel"
                    if ($label.Properties.Text -match "Counter: (\d+)") {
                        $count = [int]$matches[1] - 1
                        if ($count -lt 0) { $count = 0 }
                        $label.Properties.Text = "Counter: $count"
                        Request-TuiRefresh
                    }
                }
            }
        }
        
        # Exit button
        exitBtn = @{
            Type = "Button"
            Properties = @{
                Text = " Exit Demo "
                X = 15
                Y = 19
                OnClick = { 
                    Stop-TuiLoop 
                }
            }
        }
        
        # Footer
        footer = @{
            Type = "Label"
            Properties = @{
                Text = "Press Tab to navigate, Enter to activate buttons, Type in the text box"
                X = 5
                Y = 22
                ForegroundColor = "DarkGray"
            }
        }
    }
}

# Initialize and run
try {
    Initialize-TuiEngine
    Push-TuiScreen -Screen $screen
    Start-TuiLoop
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Make sure you're running from the correct directory with all modules present." -ForegroundColor Yellow
}
finally {
    # Ensure clean exit
    Clear-Host
    Write-Host "Thanks for trying TUI Framework!" -ForegroundColor Cyan
}
