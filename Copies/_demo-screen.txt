# Demo Screen - Shows all component types
# Demonstrates the TUI framework capabilities

function global:Get-DemoScreen {
    $screen = @{
        Name = "DemoScreen"
        
        State = @{
            textValue = "Hello, TUI!"
            checkboxValue = $true
            selectedDropdown = "Option2"
            progressValue = 35
            selectedDate = Get-Date
            selectedTime = @{ Hour = 14; Minute = 30 }
            tableData = @(
                @{ Name = "John Doe"; Role = "Developer"; Status = "Active" }
                @{ Name = "Jane Smith"; Role = "Designer"; Status = "Active" }
                @{ Name = "Bob Johnson"; Role = "Manager"; Status = "Away" }
            )
            textAreaContent = "This is a multi-line`ntext area example.`nYou can edit this text!"
            numberValue = 42
            sliderValue = 65
        }
        
        Components = @{}
        FocusedComponentName = "textBox"
        
        Init = {
            param($self)
            
            # Use layout manager for organized positioning
            if (Get-Command New-TuiLayoutManager -ErrorAction SilentlyContinue) {
                $layout = New-TuiLayoutManager -Container @{X=2; Y=4; Width=76; Height=20} -Mode 'Manual'
            }
            
            # Basic Components Section
            $self.Components.basicLabel = New-TuiLabel -Props @{
                X = 2; Y = 2; Text = "TUI Component Demo - Basic Components"
                ForegroundColor = (Get-ThemeColor "Header")
            }
            
            $self.Components.textBox = New-TuiTextBox -Props @{
                X = 2; Y = 4; Width = 30; Height = 3
                Text = $self.State.textValue
                Placeholder = "Enter text here..."
                OnChange = { param($NewValue) $self.State.textValue = $NewValue }
            }
            
            $self.Components.button = New-TuiButton -Props @{
                X = 35; Y = 4; Width = 15; Height = 3
                Text = "Click Me!"
                OnClick = { 
                    Show-AlertDialog -Title "Button Clicked" -Message "You entered: $($self.State.textValue)"
                }
            }
            
            $self.Components.checkbox = New-TuiCheckBox -Props @{
                X = 52; Y = 5; Width = 20
                Text = "Enable feature"
                Checked = $self.State.checkboxValue
                OnChange = { param($NewValue) $self.State.checkboxValue = $NewValue }
            }
            
            $self.Components.dropdown = New-TuiDropdown -Props @{
                X = 2; Y = 8; Width = 25; Height = 3
                Options = @(
                    @{ Display = "Option 1"; Value = "Option1" }
                    @{ Display = "Option 2"; Value = "Option2" }
                    @{ Display = "Option 3"; Value = "Option3" }
                )
                Value = $self.State.selectedDropdown
                OnChange = { param($NewValue) $self.State.selectedDropdown = $NewValue }
            }
            
            $self.Components.progressBar = New-TuiProgressBar -Props @{
                X = 30; Y = 9; Width = 30
                Value = $self.State.progressValue
                Max = 100
                ShowPercent = $true
            }
            
            # Date/Time Components
            $self.Components.dateTimeLabel = New-TuiLabel -Props @{
                X = 2; Y = 12; Text = "Date/Time Components:"
                ForegroundColor = (Get-ThemeColor "Info")
            }
            
            $self.Components.datePicker = New-TuiDatePicker -Props @{
                X = 2; Y = 14; Width = 20; Height = 3
                Value = $self.State.selectedDate
                OnChange = { param($NewValue) $self.State.selectedDate = $NewValue }
            }
            
            $self.Components.timePicker = New-TuiTimePicker -Props @{
                X = 25; Y = 14; Width = 15; Height = 3
                Hour = $self.State.selectedTime.Hour
                Minute = $self.State.selectedTime.Minute
                OnChange = { 
                    param($NewHour, $NewMinute) 
                    $self.State.selectedTime = @{ Hour = $NewHour; Minute = $NewMinute }
                }
            }
            
            # Advanced Components (if available)
            if (Get-Command New-TuiNumberInput -ErrorAction SilentlyContinue) {
                $self.Components.numberInput = New-TuiNumberInput -Props @{
                    X = 43; Y = 14; Width = 15; Height = 3
                    Value = $self.State.numberValue
                    Min = 0
                    Max = 100
                    Step = 1
                    OnChange = { param($NewValue) $self.State.numberValue = $NewValue }
                }
            }
            
            if (Get-Command New-TuiSlider -ErrorAction SilentlyContinue) {
                $self.Components.slider = New-TuiSlider -Props @{
                    X = 61; Y = 14; Width = 20; Height = 3
                    Value = $self.State.sliderValue
                    Min = 0
                    Max = 100
                    OnChange = { param($NewValue) $self.State.sliderValue = $NewValue }
                }
            }
            
            # Text Area
            $self.Components.textAreaLabel = New-TuiLabel -Props @{
                X = 2; Y = 18; Text = "Text Area:"
                ForegroundColor = (Get-ThemeColor "Info")
            }
            
            $self.Components.textArea = New-TuiTextArea -Props @{
                X = 2; Y = 20; Width = 40; Height = 6
                Text = $self.State.textAreaContent
                OnChange = { param($NewValue) $self.State.textAreaContent = $NewValue }
            }
            
            # Simple Table
            $self.Components.tableLabel = New-TuiLabel -Props @{
                X = 45; Y = 18; Text = "Data Table:"
                ForegroundColor = (Get-ThemeColor "Info")
            }
            
            $self.Components.table = New-TuiTable -Props @{
                X = 45; Y = 20; Width = 35; Height = 8
                Columns = @(
                    @{ Name = "Name"; Header = "Name"; Width = 15 }
                    @{ Name = "Role"; Header = "Role"; Width = 10 }
                    @{ Name = "Status"; Header = "Status"; Width = 8 }
                )
                Rows = $self.State.tableData
                OnRowSelect = {
                    param($Row, $Index)
                    Show-AlertDialog -Title "Row Selected" -Message "You selected: $($Row.Name)"
                }
            }
            
            # Chart (if available)
            $self.Components.chartLabel = New-TuiLabel -Props @{
                X = 84; Y = 2; Text = "Chart:"
                ForegroundColor = (Get-ThemeColor "Info")
            }
            
            $self.Components.chart = New-TuiChart -Props @{
                X = 84; Y = 4; Width = 20; Height = 10
                ChartType = "Bar"
                Data = @(
                    @{ Label = "Mon"; Value = 20 }
                    @{ Label = "Tue"; Value = 35 }
                    @{ Label = "Wed"; Value = 15 }
                    @{ Label = "Thu"; Value = 40 }
                    @{ Label = "Fri"; Value = 25 }
                )
            }
            
            # Interactive elements
            $self.Components.incrementButton = New-TuiButton -Props @{
                X = 84; Y = 15; Width = 10; Height = 3
                Text = "Progress+"
                OnClick = {
                    $self.State.progressValue = [Math]::Min(100, $self.State.progressValue + 10)
                    $self.Components.progressBar.Value = $self.State.progressValue
                    Request-TuiRefresh
                }
            }
            
            $self.Components.decrementButton = New-TuiButton -Props @{
                X = 95; Y = 15; Width = 10; Height = 3
                Text = "Progress-"
                OnClick = {
                    $self.State.progressValue = [Math]::Max(0, $self.State.progressValue - 10)
                    $self.Components.progressBar.Value = $self.State.progressValue
                    Request-TuiRefresh
                }
            }
            
            # Set initial focus
            if ($self.Components.textBox) {
                $self.Components.textBox.IsFocused = $true
            }
        }
        
        Render = {
            param($self)
            
            # Background
            $bgColor = Get-ThemeColor "Background"
            for ($y = 0; $y -lt $global:TuiState.BufferHeight; $y++) {
                Write-BufferString -X 0 -Y $y -Text (" " * $global:TuiState.BufferWidth) -BackgroundColor $bgColor
            }
            
            # Main container
            Write-BufferBox -X 0 -Y 0 -Width $global:TuiState.BufferWidth -Height ($global:TuiState.BufferHeight - 1) `
                -Title " Component Demo " -BorderColor (Get-ThemeColor "Border")
            
            # Render all components
            foreach ($kvp in $self.Components.GetEnumerator()) {
                $component = $kvp.Value
                if ($component -and $component.Visible -ne $false) {
                    # Update focus state
                    $component.IsFocused = ($self.FocusedComponentName -eq $kvp.Key)
                    
                    if ($component.Render) {
                        & $component.Render -self $component
                    }
                }
            }
            
            # Status bar
            $statusY = $global:TuiState.BufferHeight - 2
            $statusText = "Tab: Next Component • Shift+Tab: Previous • Space/Enter: Interact • Esc: Exit"
            Write-BufferString -X 2 -Y $statusY -Text $statusText -ForegroundColor (Get-ThemeColor "Subtle")
            
            # Current values display
            $valuesX = $global:TuiState.BufferWidth - 40
            Write-BufferString -X $valuesX -Y 20 -Text "Current Values:" -ForegroundColor (Get-ThemeColor "Header")
            Write-BufferString -X $valuesX -Y 21 -Text "Text: $($self.State.textValue.Substring(0, [Math]::Min(20, $self.State.textValue.Length)))" -ForegroundColor (Get-ThemeColor "Info")
            Write-BufferString -X $valuesX -Y 22 -Text "Checkbox: $($self.State.checkboxValue)" -ForegroundColor (Get-ThemeColor "Info")
            Write-BufferString -X $valuesX -Y 23 -Text "Dropdown: $($self.State.selectedDropdown)" -ForegroundColor (Get-ThemeColor "Info")
            Write-BufferString -X $valuesX -Y 24 -Text "Progress: $($self.State.progressValue)%" -ForegroundColor (Get-ThemeColor "Info")
            Write-BufferString -X $valuesX -Y 25 -Text "Date: $($self.State.selectedDate.ToString('yyyy-MM-dd'))" -ForegroundColor (Get-ThemeColor "Info")
            if ($self.State.numberValue) {
                Write-BufferString -X $valuesX -Y 26 -Text "Number: $($self.State.numberValue)" -ForegroundColor (Get-ThemeColor "Info")
            }
        }
        
        HandleInput = {
            param($self, $Key)
            
            # Screen-level shortcuts
            if ($Key.Key -eq [ConsoleKey]::Escape) {
                return "Back"
            }
            
            if ($Key.Key -eq [ConsoleKey]::F5) {
                # Refresh demo data
                $self.State.tableData = @(
                    @{ Name = "Alice Brown"; Role = "Developer"; Status = "Active" }
                    @{ Name = "Charlie Davis"; Role = "Tester"; Status = "Busy" }
                    @{ Name = "Eve Wilson"; Role = "Lead"; Status = "Active" }
                    @{ Name = "Frank Miller"; Role = "Analyst"; Status = "Away" }
                )
                $self.Components.table.Rows = $self.State.tableData
                Request-TuiRefresh
                return $true
            }
            
            # Tab navigation
            if ($Key.Key -eq [ConsoleKey]::Tab) {
                # Get all focusable components
                $focusableComponents = @()
                $focusableNames = @()
                
                foreach ($kvp in $self.Components.GetEnumerator()) {
                    if ($kvp.Value.IsFocusable -ne $false -and $kvp.Value.Visible -ne $false) {
                        $focusableComponents += $kvp.Value
                        $focusableNames += $kvp.Key
                    }
                }
                
                if ($focusableNames.Count -gt 0) {
                    $currentIndex = [array]::IndexOf($focusableNames, $self.FocusedComponentName)
                    if ($currentIndex -eq -1) { $currentIndex = 0 }
                    
                    if ($Key.Modifiers -band [ConsoleModifiers]::Shift) {
                        # Shift+Tab - go backwards
                        $nextIndex = ($currentIndex - 1 + $focusableNames.Count) % $focusableNames.Count
                    } else {
                        # Tab - go forwards
                        $nextIndex = ($currentIndex + 1) % $focusableNames.Count
                    }
                    
                    $self.FocusedComponentName = $focusableNames[$nextIndex]
                    
                    # Update engine focus
                    $focusedComponent = $self.Components[$self.FocusedComponentName]
                    if ($focusedComponent -and (Get-Command Set-ComponentFocus -ErrorAction SilentlyContinue)) {
                        Set-ComponentFocus -Component $focusedComponent
                    }
                    
                    Request-TuiRefresh
                }
                return $true
            }
            
            # Delegate to focused component
            $focusedComponent = if ($self.FocusedComponentName) { $self.Components[$self.FocusedComponentName] } else { $null }
            if ($focusedComponent -and $focusedComponent.HandleInput) {
                $result = & $focusedComponent.HandleInput -self $focusedComponent -Key $Key
                if ($result) {
                    Request-TuiRefresh
                    return $true
                }
            }
            
            return $false
        }
        
        OnExit = {
            param($self)
            Write-Log -Level Debug -Message "Demo screen exiting"
        }
    }
    
    return $screen
}

Export-ModuleMember -Function Get-DemoScreen