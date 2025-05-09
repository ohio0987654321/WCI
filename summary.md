# WindowControlInjector: Direct Control Implementation

## Overview

WindowControlInjector has been enhanced with a new `direct-control` profile that provides more robust screen recording protection, stealth mode, and window behavior management. This document explains the implementation and benefits of this approach.

## Implementation Approach

### Traditional Property Override Approach

The initial WindowControlInjector design used property overrides to modify window and application behavior:

1. Intercept property getters/setters through method swizzling
2. Return custom values from a property registry
3. Apply these property values when queried by the system

While this approach works for many cases, it has limitations:

- Only intercepts formal property accesses, not direct ivar access
- Doesn't catch all window creation events
- Limited protection against advanced screen recording tools
- Some properties must be set at specific times during window creation

### New Direct Control Approach

The new `direct-control` profile uses a different approach:

1. **Direct Message Sending**: Directly calls Objective-C methods to set properties
2. **Active Window Monitoring**: Monitors window creation events through notifications
3. **Runtime Class Modification**: Creates custom window subclasses as needed
4. **Periodic Reapplication**: Applies settings periodically to catch any windows that might reset

This implementation is inspired by techniques used in the AIHelper project, which demonstrated more robust protection against screen recording.

## Key Features

### Enhanced Screen Recording Protection

- Higher window level settings (`CGScreenSaverWindowLevel` instead of `NSFloatingWindowLevel`)
- Direct shader control for window appearance
- Multiple redundant transparency settings
- More aggressive window sharing type control

### Improved Stealth Mode

- Advanced presentation options for application hiding
- Multiple techniques to hide from Dock and Mission Control
- Prevents process activation and switching
- Full menu bar hiding and application suppression

### Better Click-Through Support

- Custom window subclassing to prevent focus
- Dynamic runtime class creation for robust behavior
- Maintains clickability while preventing keyboard focus
- Ensures windows stay "behind" active applications

## Usage

The new direct-control profile can be used with:

```bash
./injector --direct-control /Applications/YourApp.app
```

Or use the included convenience script:

```bash
./direct_launch.sh /Applications/YourApp.app
```

## Technical Details

### Key Technical Components

1. **Dynamic Class Creation**:
   - Creates window-specific subclasses at runtime
   - Customizes `canBecomeKey` and `canBecomeMain` behavior
   - Preserves other window behaviors

2. **Active Window Monitoring**:
   - Listens for `NSWindowDidExposeNotification` and other window events
   - Automatically applies settings to new windows
   - Periodic timer ensures settings persist

3. **High Window Level**:
   - Uses `CGScreenSaverWindowLevel` (1000) for stronger protection
   - Combines with collection behaviors for maximum effect
   - Makes windows visible to users but invisible to screen recording

### Comparison to Traditional Profiles

| Feature | Traditional Profiles | Direct Control Profile |
|---------|---------------------|------------------------|
| Screen Recording Protection | Basic | Enhanced |
| Stealth Mode | App hidden from Dock | App hidden from all UI elements |
| Focus Control | Can be overridden | Custom class implementation |
| Click-Through | Basic support | Reliable with focus control |
| Window Persistence | One-time setup | Continuous monitoring |
| Compatibility | Most apps | All AppKit apps |

## Future Enhancements

- Additional window collection behaviors for specific cases
- Per-application configuration profiles
- More granular control of specific window properties
- Support for intercepting additional window creation patterns

## References

- Inspired by techniques in AIHelper's macOS window management
- Uses advanced Objective-C runtime features for dynamic class creation
- Combines multiple macOS window management APIs for maximum effect
