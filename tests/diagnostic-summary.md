# Helios Architecture Issues Summary

Based on the diagnostic results, here are the REAL issues that need attention:

## 1. ✅ FIXED: Dashboard quickActions Scope Issue
The diagnostic confirms the fix was successful: "quickActions appears to be properly stored"

## 2. False Positives in Diagnostic
Many reported issues are false positives because:
- Handler parameters (like $NewValue, $SelectedData) are not local variables
- $script: scoped variables in gtui.ps1 are intentionally script-scoped
- $Props in component factories are part of the creation pattern

## 3. Real Issues to Address

### Critical Issues:

1. **Direct Global Access** - Violates dependency injection pattern:
   - $global:Services is still being accessed directly in some places
   - Should always use injected services via $self._services

2. **Incorrect $self References in Component Handlers**:
   - demo-screen.psm1 (lines 180, 190): $self.State in OnClick handlers
   - time-entry-screen.psm1 (line 75): $self.State in OnChange handler
   - timer-start-screen.psm1 (line 95): $self.State in OnClick handler
   
   In component handlers, $self refers to the component, not the screen!

### Medium Priority:

3. **Missing Service Null Checks**:
   - 96 instances found, but many may be in safe contexts
   - Should add defensive null checks before using services

4. **Navigation Service Usage in Handlers**:
   - dashboard-screen-helios.psm1: The $navigationServices capture is correct approach
   - This pattern should be used wherever navigation is needed in handlers

## 4. Recommended Fixes

### For Incorrect $self References:
```powershell
# WRONG - In a component's OnClick handler:
OnClick = { $self.State.value = "something" }

# CORRECT - Capture screen reference:
$screen = $self  # Outside the handler
OnClick = { $screen.State.value = "something" }
```

### For Global Service Access:
```powershell
# WRONG:
$global:Services.Store.Dispatch(...)

# CORRECT:
$self._services.Store.Dispatch(...)
```

### For Service Null Checks:
```powershell
# Add defensive checks:
if ($self._services -and $self._services.Store) {
    & $self._services.Store.Dispatch(...)
}
```

## 5. Files That Need Review

Priority files with real issues:
1. demo-screen.psm1 - Has incorrect $self references
2. time-entry-screen.psm1 - Has incorrect $self references  
3. timer-start-screen.psm1 - Has incorrect $self references
4. Any file still using $global:Services directly

## 6. Architecture Validation

The core Helios architecture is sound:
- ✅ Z-Index rendering working
- ✅ Service dependency injection pattern established
- ✅ Unidirectional data flow via AppStore
- ✅ Dashboard scope issue fixed

The remaining issues are mostly about enforcing the established patterns consistently across all screens.
