# TUI Framework Integration Plan

## Overview
This document outlines a phased approach to integrate advanced features into the TUI framework while maintaining backward compatibility and addressing current issues.

## Current State Assessment

### Immediate Issues (Phase 1 - Complete)
- [x] Double rendering in dashboard (nested boxes) - FIXED
- [x] Data not appearing in tables - FIXED  
- [ ] Stale data between screens - Framework support exists, needs screen updates
- [ ] Manual coordinate calculations everywhere
- [ ] No centralized state management
- [ ] Performance issues with full-screen refreshes

### Architecture Gaps
- No reactive state management
- Components tightly coupled to screens
- No layout management system
- No text resource management
- Inefficient rendering (always full screen)

## Implementation Phases

### Phase 2: Core State Management (Priority: HIGH)
**Goal**: Implement practical reactive state management without over-engineering

#### 2.1 Enhanced State Module (`modules/state-manager.psm1`)
```powershell
# Simple, practical reactive state implementation
function global:New-TuiState {
    param(
        [hashtable]$InitialState = @{},
        [hashtable]$Actions = @{}
    )
    
    $state = [PSCustomObject]@{
        _data = $InitialState.Clone()
        _subscribers = @{}
    }
    
    # Add properties, methods, and actions
    # Keep it simple - no schemas, no immutability
}
```

#### 2.2 Upgrade Data Manager
- Transform `data-manager.psm1` into application store
- Keep existing $global:Data for compatibility
- Add reactive layer on top
- Implement auto-save with debouncing

### Phase 3: Layout System (Priority: MEDIUM)
**Goal**: Eliminate magic numbers without complex calculations

#### 3.1 Simple Panel Component
```powershell
function global:New-TuiPanel {
    # Stack layout (vertical/horizontal)
    # Simple grid (fixed columns)
    # No fractional units - keep it simple
}
```

#### 3.2 Focus Management Integration
- Panels manage child focus automatically
- Tab navigation works within panels
- No manual focus tracking needed

### Phase 4: Performance Optimization (Priority: HIGH)
**Goal**: Make UI feel snappy even over SSH

#### 4.1 Dirty Rectangle System
- Add to `tui-engine-v2.psm1`
- Track dirty regions instead of full screen
- Massive performance improvement
- Keep backward compatibility

#### 4.2 Component-Level Invalidation
```powershell
Request-TuiRefresh -ComponentToRefresh $component
```

### Phase 5: Text Management (Priority: LOW)
**Goal**: Centralize strings for consistency (not i18n)

#### 5.1 Simple Text Resources
- Create `modules/text-resources.psm1`
- No external dependencies (PSStringTools doesn't exist)
- Simple key-value lookup
- Optional formatting with built-in -f operator

### Phase 6: Advanced Integration (Priority: FUTURE)
- Component composition patterns
- Advanced layouts (flex, dock)
- Theme system integration
- Accessibility improvements

## Integration Strategy

### Backward Compatibility Rules
1. All existing screens must continue working
2. New features are opt-in, not required
3. Keep existing component factories
4. Don't break the current API

### Migration Path
1. Start with new screens using new patterns
2. Gradually update existing screens
3. Deprecate old patterns after full migration
4. Document migration guide

### Testing Strategy
1. Create test screen for each new feature
2. Ensure no performance regression
3. Test over SSH/remote connections
4. Validate with screen readers

## Specific Screen Updates

### Dashboard Screen
- Already uses ShowBorder=false (DONE)
- Add state subscriptions for real-time updates
- Use panels for layout instead of manual positioning

### Task Screen
- Connect to global data store
- Remove sample data
- Add OnResume hook
- Implement proper form state management

## Risk Mitigation

### Performance Risks
- Dirty rectangles might cause flicker
- Solution: Careful implementation with double buffering

### Complexity Risks
- State management could become Redux-like
- Solution: Keep it simple, PowerShell-idiomatic

### Compatibility Risks
- New patterns might confuse developers
- Solution: Extensive documentation and examples

## Success Metrics
1. 50%+ reduction in render time
2. Zero magic numbers in new screens
3. All screens update automatically when data changes
4. Tab navigation "just works"
5. No regression in existing functionality

## Implementation Order
1. Fix remaining Phase 1 issues (stale data)
2. Implement basic state management (Phase 2.1)
3. Add dirty rectangle system (Phase 4.1)
4. Create simple panel system (Phase 3.1)
5. Upgrade data manager (Phase 2.2)
6. Everything else as needed

## Next Steps
1. Complete Phase 1 by adding OnResume to task screen
2. Create `state-manager.psm1` with basic implementation
3. Add dirty rectangle support to engine
4. Create example screen using all new patterns
5. Document best practices
