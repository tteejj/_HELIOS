# PMC Terminal v3.0 - Troubleshooting Guide

## Common Issues and Solutions

### 1. "Console window too small" Error

**Symptom**: Error message about console dimensions being less than 80x24

**Solution**:
1. Resize your console window to be at least 80 columns wide and 24 rows tall
2. In Windows Terminal: Drag the window edges to resize
3. In PowerShell Console: Right-click title bar > Properties > Layout > Window Size
4. In VS Code Terminal: Drag the terminal panel to make it larger

### 2. "times ('-X') must be a non-negative value" Error

**Symptom**: Error when drawing UI elements

**Cause**: Console window is too narrow for the UI elements

**Solution**: 
- This has been fixed in the latest version
- If you still see this, ensure your console is at least 80 characters wide

### 3. "Error during TUI cleanup: The pipeline has been stopped"

**Symptom**: Error message when exiting the application

**Cause**: Input handler cleanup issue

**Solution**: 
- This has been fixed in the latest version
- The error is harmless and won't affect functionality

### 4. "Get-DashboardScreen not recognized"

**Symptom**: Function not found error

**Solution**: 
- Ensure all files are in the correct locations
- Run from the directory containing main.ps1
- Check that screens/dashboard-screen.psm1 exists

### 5. ANSI Escape Sequences Showing as Text

**Symptom**: You see codes like `[31m` instead of colors

**Solution**:
1. Use Windows Terminal (recommended)
2. Or enable ANSI in PowerShell:
   ```powershell
   Set-ItemProperty HKCU:\Console VirtualTerminalLevel -Type DWORD 1
   ```
3. Restart PowerShell after making the change

### 6. Flickering or Slow Performance

**Symptom**: UI updates are slow or flickery

**Solution**:
1. Use Windows Terminal for best performance
2. Disable PowerShell transcript if enabled
3. Close other console applications

### 7. Characters Not Displaying Correctly

**Symptom**: Box drawing characters appear as question marks

**Solution**:
1. Ensure your console font supports Unicode
2. In Windows Terminal: Settings > Profiles > Font > Use "Cascadia Code" or "Consolas"
3. In PowerShell: Properties > Font > Use "Consolas" or "Lucida Console"

## Debug Mode

To run in debug mode and see more information:

```powershell
$DebugPreference = "Continue"
.\main.ps1
```

## Checking Your Environment

Run the test script to verify your setup:

```powershell
.\test-system.ps1
```

This will check:
- PowerShell version
- Console dimensions
- ANSI support
- Module availability

## Getting Help

1. Check error.log for detailed error information
2. Run test-system.ps1 to verify environment
3. Ensure minimum requirements:
   - PowerShell 5.0 or higher
   - Console size 80x24 or larger
   - Windows Terminal recommended

## Quick Fixes Script

If you encounter issues, run:

```powershell
.\apply-fixes.ps1
```

This will attempt to fix common configuration issues.
