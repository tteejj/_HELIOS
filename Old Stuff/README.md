# TUI Framework Documentation

This directory contains comprehensive documentation for the PowerShell TUI Framework.

## Documentation Files

### 📚 [TUI-FRAMEWORK-GUIDE.md](TUI-FRAMEWORK-GUIDE.md)
**Complete Framework Guide** - Start here!
- Framework overview and architecture
- File structure explanation
- Core concepts (Components, Screens, State, Events)
- Component system details
- Layout system documentation
- Best practices
- Common patterns
- Additional fixes needed beyond TUI-ENGINE-FIXES.txt

### 🚀 [GETTING-STARTED.md](GETTING-STARTED.md)
**Quick Start Guide** - Get running in 5 minutes
- Prerequisites
- Your first app
- Understanding the structure
- Common gotchas
- Debugging tips

### 📋 [TUI-QUICK-REFERENCE.md](TUI-QUICK-REFERENCE.md)
**API Quick Reference** - Keep this handy while coding
- Essential functions
- Component types and properties
- State management API
- Event system API
- Keyboard shortcuts
- Common patterns

### 💡 [TUI-EXAMPLE-APPS.md](TUI-EXAMPLE-APPS.md)
**Example Applications** - Learn by example
- Hello World app
- Counter with state management
- Todo list application
- Multi-screen navigation
- Async data loading
- Complete working examples

### 🔧 [ADDITIONAL-FIXES-NEEDED.md](ADDITIONAL-FIXES-NEEDED.md)
**Architectural Issues & Fixes** - For framework maintainers
- Critical issues (memory leaks, focus system)
- High priority issues (input, rendering)
- Medium priority improvements
- Missing components list
- Quick fixes you can apply now

## Quick Start Path

1. **First Time?** Start with [GETTING-STARTED.md](GETTING-STARTED.md)
2. **Need Details?** Read [TUI-FRAMEWORK-GUIDE.md](TUI-FRAMEWORK-GUIDE.md)
3. **While Coding:** Keep [TUI-QUICK-REFERENCE.md](TUI-QUICK-REFERENCE.md) open
4. **Learn Patterns:** Study [TUI-EXAMPLE-APPS.md](TUI-EXAMPLE-APPS.md)
5. **Contributing?** Check [ADDITIONAL-FIXES-NEEDED.md](ADDITIONAL-FIXES-NEEDED.md)

## Running the Hello World Example

There's a ready-to-run example in the parent directory:

```powershell
cd ..
.\hello-world-example.ps1
```

This demonstrates:
- Basic component usage
- User input handling
- State updates
- Event handling

## Key Concepts to Understand

1. **Everything is a Component** - Even screens are special components
2. **State Drives UI** - Components react to state changes
3. **Events Connect Components** - Loose coupling through events
4. **Layouts Manage Position** - Use layout managers over absolute positioning
5. **Double Buffering** - Flicker-free rendering

## Framework Status

The framework is functional but has known issues:
- Performance optimizations needed (see TUI-ENGINE-FIXES.txt)
- Memory leaks in event system
- Focus management issues
- Missing clipboard support
- Some components not yet implemented

See [ADDITIONAL-FIXES-NEEDED.md](ADDITIONAL-FIXES-NEEDED.md) for details.

## Getting Help

1. Check the examples first
2. Search for similar patterns in existing screens
3. Verify your component IDs are unique
4. Remember to call `Request-TuiRefresh` after state changes
5. Use `-Force` when re-importing modules during development

Happy TUI Building! 🎨
