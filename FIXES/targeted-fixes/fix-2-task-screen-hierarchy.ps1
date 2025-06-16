# Fix 2: Task Screen Rendering Hierarchy
# File: screens\task-screen.psm1
# Issue: Form components showing on screen entry because they're rendered outside panel control

# The problem is in the Render method around line 206-216
# Find this section:
            # Render all top-level components. The Panel will handle rendering its own children.
            foreach ($component in $self.Components.Values) {
                if ($component.Render) {
                    & $component.Render -self $component
                }
            }

# Replace with:
            # Render all top-level components. The Panel will handle rendering its own children.
            foreach ($kvp in $self.Components.GetEnumerator()) {
                $component = $kvp.Value
                # CRITICAL FIX: Only render components that don't have a parent
                # This prevents child components from being rendered outside their parent's control
                if ($component -and $component.Render -and -not $component.Parent) {
                    & $component.Render -self $component
                }
            }

# Additional fix for the Init method to ensure Panel children are properly parented
# After adding children to the panel (around line 164), add this:
            # CRITICAL: Ensure all form components have Parent set
            # This prevents them from being rendered by the screen's main render loop
            foreach ($child in $self.Components.formPanel.Children) {
                $child.Parent = $self.Components.formPanel
            }
