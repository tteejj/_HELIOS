# Fix 3: Dashboard Screen Rendering & Quick Actions Width
# File: screens\dashboard-screen-grid.psm1
# Issue: Components might render outside parent control + Quick Actions truncation

# Fix 1: Update the Render method around line 304-318
# Find:
                # Render all components
                foreach ($kvp in $self.Components.GetEnumerator()) {
                    $component = $kvp.Value
                    if ($component -and $component.Visible -ne $false) {
                        # Set focus state based on screen's tracking
                        $component.IsFocused = ($self.FocusedComponentName -eq $kvp.Key)
                        if ($component.Render) {
                            & $component.Render -self $component
                        }
                    }
                }

# Replace with:
                # Render all components (only top-level ones without parents)
                foreach ($kvp in $self.Components.GetEnumerator()) {
                    $component = $kvp.Value
                    if ($component -and $component.Visible -ne $false -and -not $component.Parent) {
                        # Set focus state based on screen's tracking
                        $component.IsFocused = ($self.FocusedComponentName -eq $kvp.Key)
                        if ($component.Render) {
                            & $component.Render -self $component
                        }
                    }
                }

# Fix 2: Update Quick Actions DataTable to use explicit width
# Around line 47-53, change:
                        Columns = @(
                            @{ Name = "Action"; Header = "Quick Actions" }  # Let width auto-calculate
                        )

# To:
                        Columns = @(
                            @{ Name = "Action"; Header = "Quick Actions"; Width = 32 }  # Explicit width (35 table - 3 for borders/padding)
                        )
