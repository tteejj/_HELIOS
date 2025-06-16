# Quick Start Guide - PMC Terminal v4.2 "Helios"

## Running the New Architecture

To test the new Helios architecture alongside the existing system:

```powershell
# Run the new Helios version
.\main-helios.ps1

# Run the original version
.\main.ps1
```

## Key Files Created

### Core Services
- `services/app-store.psm1` - Centralized state management
- `services/navigation.psm1` - Route-based navigation
- `services/keybindings.psm1` - Configurable key bindings

### Layout System
- `layout/panels.psm1` - GridPanel, StackPanel, and more

### Enhanced Modules
- `utilities/focus-manager.psm1` - Improved focus management
- `modules/tui-engine-v2.psm1` - Updated to integrate with services

### New Screens
- `screens/dashboard-screen-helios.psm1` - Service-based dashboard
- `screens/task-screen-helios.psm1` - Service-based task screen

### Testing
- `tests/app-store.tests.ps1` - Example Pester tests

## Testing the Services

```powershell
# Run tests
Invoke-Pester -Path .\tests\app-store.tests.ps1

# Test individual services
$services = @{}
$services.Store = Initialize-AppStore
$services.Navigation = Initialize-NavigationService
$services.Keybindings = Initialize-KeybindingService

# Test state management
$services.Store.RegisterAction("TEST", { 
    param($Context) 
    $Context.UpdateState(@{ test = "value" })
})
$services.Store.Dispatch("TEST")
$services.Store.GetState("test")  # Returns "value"
```

## Key Improvements

1. **No More Globals** - Everything through service registry
2. **Reactive State** - Subscribe to changes, no manual refresh
3. **Declarative Layouts** - No manual positioning calculations
4. **Proper Testing** - Pester integration with examples
5. **Module Manifests** - Formal dependency management

## Migration Notes

The new architecture runs alongside the old one. To migrate existing screens:

1. Replace global access with service registry
2. Use layout panels instead of manual positioning
3. Subscribe to state instead of manual refresh
4. Use navigation service for screen transitions

## Debugging

Enable debug logging in services:

```powershell
$services.Store = Initialize-AppStore -EnableDebugLogging $true
```

View navigation history:

```powershell
$services.Navigation.GetBreadcrumbs()
```

Check current keybindings:

```powershell
$services.Keybindings.GetAllBindings($true)  # Grouped by category
```
