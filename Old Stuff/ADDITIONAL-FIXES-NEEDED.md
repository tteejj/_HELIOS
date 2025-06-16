# TUI Framework - Additional Architectural Fixes Needed

## Critical Issues (Application Breaking)

### 1. Memory Leak in Event System
**Location**: `event-system.psm1`
**Problem**: Event handlers are never cleaned up when components are destroyed
**Impact**: Long-running applications will consume increasing memory

**Fix Required**:
```powershell
# In component cleanup/destroy
function Remove-ComponentEventHandlers {
    param($ComponentId)
    
    $script:EventHandlers = $script:EventHandlers | Where-Object {
        $_.Source -ne $ComponentId
    }
}
```

### 2. Focus System Complete Failure
**Location**: `tui-engine-v2.psm1`
**Problem**: 
- Focus can get "lost" when focused component is removed
- Tab navigation skips over disabled components incorrectly
- No visual focus indicator

**Fix Required**:
- Add focus management to component removal
- Fix tab order calculation to properly skip disabled
- Add visual focus ring rendering

### 3. Circular Reference Memory Leak
**Location**: `tui-framework.psm1`
**Problem**: Parent/child component references create circular dependencies
**Impact**: PowerShell garbage collector cannot clean up components

**Fix Required**:
- Implement weak references for parent pointers
- Add explicit cleanup method that breaks circular refs

## High Priority Issues

### 4. Input Buffer Overflow
**Location**: `tui-engine-v2.psm1` (ReadInputWorker)
**Problem**: Rapid typing or held keys can overflow the input queue
**Impact**: Lost keystrokes, application lag

**Fix Required**:
```powershell
# Add buffer size check before enqueue
if ($script:TuiState.InputQueue.Count -lt 100) {
    $script:TuiState.InputQueue.Enqueue($key)
}
```

### 5. Unicode Rendering Breaks Alignment
**Location**: `tui-engine-v2.psm1` (Write-BufferString)
**Problem**: Unicode characters (emoji, special chars) break column alignment
**Impact**: Corrupted display, misaligned UI elements

**Fix Required**:
- Implement proper character width calculation
- Handle double-width characters (East Asian, emoji)

### 6. No Clipboard Support
**Location**: `tui-components.psm1` (TextBox)
**Problem**: No Ctrl+C/Ctrl+V support in text inputs
**Impact**: Poor user experience

**Fix Required**:
- Add clipboard operations to TextBox
- Implement text selection first

### 7. Background Jobs Not Disposed
**Location**: `tui-framework.psm1` (Invoke-TuiAsync)
**Problem**: PowerShell jobs created by async operations are never cleaned up
**Impact**: Resource leak, potential system slowdown

**Fix Required**:
```powershell
# Track and clean up jobs
$script:TuiAsyncJobs = @()

# In cleanup
$script:TuiAsyncJobs | ForEach-Object {
    Stop-Job -Job $_ -ErrorAction SilentlyContinue
    Remove-Job -Job $_ -ErrorAction SilentlyContinue
}
```

## Medium Priority Issues

### 8. Deep State Updates Don't Trigger
**Location**: `tui-framework.psm1` (Create-TuiState)
**Problem**: Modifying nested objects doesn't trigger subscribers
```powershell
# This won't trigger:
$state.Data.user.settings.theme = "dark"
```

**Fix Required**:
- Implement deep property change detection
- Or require immutable updates

### 9. No Component Property Validation
**Location**: `tui-framework.psm1` (Create-TuiComponent)
**Problem**: Invalid properties silently fail
**Impact**: Hard to debug issues

**Fix Required**:
- Add property schema validation
- Throw clear errors for invalid props

### 10. Color Bleeding Issues
**Location**: `tui-engine-v2.psm1` (Render-BufferOptimized)
**Problem**: Background colors can "bleed" between components
**Impact**: Visual artifacts

**Fix Required**:
- Ensure proper color reset between components
- Clear full component area before render

## Missing Core Components

### 11. Essential Missing Components
Components that should exist but don't:

1. **ProgressBar**
   ```powershell
   @{
       Type = "ProgressBar"
       Properties = @{
           Value = 50
           Maximum = 100
           ShowText = $true
       }
   }
   ```

2. **Menu/MenuBar**
   ```powershell
   @{
       Type = "MenuBar"
       Properties = @{
           Items = @(
               @{ Text = "File"; Items = @(...) }
               @{ Text = "Edit"; Items = @(...) }
           )
       }
   }
   ```

3. **TabControl**
   ```powershell
   @{
       Type = "TabControl"
       Properties = @{
           Tabs = @(
               @{ Header = "Tab1"; Content = @{...} }
               @{ Header = "Tab2"; Content = @{...} }
           )
       }
   }
   ```

4. **TreeView**
   ```powershell
   @{
       Type = "TreeView"
       Properties = @{
           Nodes = @(
               @{ Text = "Root"; Children = @(...) }
           )
       }
   }
   ```

## Performance Optimizations Needed

### 12. Render Diff System
**Current**: Entire screen redraws every frame
**Needed**: Only redraw changed areas

### 13. Component Pooling
**Current**: Components created/destroyed frequently
**Needed**: Reuse component instances

### 14. Virtual Scrolling for DataTable
**Current**: Renders all rows
**Needed**: Only render visible rows

## Developer Experience

### 15. Error Messages
**Current**: Cryptic PowerShell errors
**Needed**: Clear, actionable error messages

Example:
```powershell
# Instead of: "Cannot index into a null array"
# Show: "Component 'myButton' not found. Did you mean 'myButton1'?"
```

### 16. Debug Mode
**Needed**: Visual component boundaries, state inspector, performance metrics

### 17. Component Validation
**Needed**: Validate component definitions at creation time

## Implementation Priority

1. **Fix memory leaks** (Critical - prevents production use)
2. **Fix focus system** (Critical - basic usability)
3. **Add clipboard support** (High - expected feature)
4. **Fix Unicode rendering** (High - international users)
5. **Add missing components** (Medium - framework completeness)
6. **Improve error messages** (Medium - developer experience)

## Quick Fixes You Can Apply Now

### Fix 1: Prevent Input Queue Overflow
In `tui-engine-v2.psm1`, find `ReadInputWorker` and add:
```powershell
# After $key = [System.Console]::ReadKey($true)
if ($script:TuiState.InputQueue.Count -lt 100) {
    $script:TuiState.InputQueue.Enqueue($key)
} else {
    # Drop oldest input
    $null = $script:TuiState.InputQueue.Dequeue()
    $script:TuiState.InputQueue.Enqueue($key)
}
```

### Fix 2: Basic Focus Indicator
In component render methods, add:
```powershell
if ($self.IsFocused) {
    $buffer[$y][$x-1].Char = '['
    $buffer[$y][$x-1].ForegroundColor = "Yellow"
    $buffer[$y][$x+$width].Char = ']'
    $buffer[$y][$x+$width].ForegroundColor = "Yellow"
}
```

### Fix 3: Component Cleanup
Add to `tui-framework.psm1`:
```powershell
function Remove-TuiComponent {
    param($Component)
    
    # Remove event handlers
    if ($Component.Id) {
        Remove-ComponentEventHandlers -ComponentId $Component.Id
    }
    
    # Break circular references
    $Component.Parent = $null
    if ($Component.Children) {
        $Component.Children | ForEach-Object {
            $_.Parent = $null
        }
    }
}
```

These fixes address the most critical issues that prevent the framework from being production-ready.
