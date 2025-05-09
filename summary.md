# WindowControlInjector Improvements Summary

## Issues Addressed

1. **Screen Recording Protection**
   - Enhanced invisible profile with comprehensive screen recording protection
   - Applied key window settings from AIHelper (Tauri project) implementation
   - Fixed window transparency and sharing settings

2. **Status Bar and Dock Hiding**
   - Improved stealth profile with enhanced NSApplication settings
   - Added additional window collection behaviors to prevent visibility in system UIs
   - Set `canHide` property to NO to prevent Mission Control from showing the window

3. **Multiple Instance Support**
   - Added `-n` flag to the `/usr/bin/open` command to force new instance creation
   - Updated both profile and property override injection methods
   - Created convenient direct_launch.sh script for easy testing

## Configuration Improvements

### Invisible Profile Changes

```objective-c
// Enhanced collection behavior that prevents capture
@"collectionBehavior": @(NSWindowCollectionBehaviorStationary |
                         NSWindowCollectionBehaviorFullScreenPrimary |
                         NSWindowCollectionBehaviorIgnoresCycle |
                         NSWindowCollectionBehaviorCanJoinAllSpaces |
                         NSWindowCollectionBehaviorFullScreenAuxiliary),

// Set window level to floating - essential for screen recording protection
@"level": @(3), // NSFloatingWindowLevel

// Prevent hiding by system (critical for Mission Control exclusion)
@"canHide": @NO,

// Better transparency settings
@"backgroundColor": [NSColor clearColor],
@"movableByWindowBackground": @YES,
@"alphaValue": @(0.8),
```

### Stealth Profile Changes

```objective-c
// Enhanced presentation options
@"presentationOptions": @(NSApplicationPresentationHideDock |
                         NSApplicationPresentationHideMenuBar |
                         NSApplicationPresentationDisableAppleMenu |
                         NSApplicationPresentationDisableProcessSwitching |
                         NSApplicationPresentationDisableHideApplication),

// Additional application settings
@"showsTabBar": @NO,
@"automaticCustomizeTouchBarMenuItemEnabled": @NO,

// Window settings that help with hiding
@"canHide": @NO,
@"collectionBehavior": @(NSWindowCollectionBehaviorStationary |
                         NSWindowCollectionBehaviorIgnoresCycle |
                         NSWindowCollectionBehaviorCanJoinAllSpaces |
                         NSWindowCollectionBehaviorFullScreenAuxiliary),
```

## Testing Instructions

Use the included `direct_launch.sh` script for testing:

```bash
# Make text editor invisible to screen recording
./direct_launch.sh --invisible /Applications/TextEdit.app

# Hide calculator from dock and status bar
./direct_launch.sh --stealth /Applications/Calculator.app

# Apply all profiles
./direct_launch.sh --all /Applications/Notes.app

# Test multiple instances
./direct_launch.sh --invisible /Applications/TextEdit.app
# Run the command again to launch another instance
./direct_launch.sh --invisible /Applications/TextEdit.app
```

## Debugging

Check the debug log at `~/wci_debug.log` if you encounter any issues. This file contains:
- Environment variables
- Profile application status
- Interceptor installation status
- Any errors that occur during injection

## Implementation Notes

The improvements were inspired by examining the AIHelper Tauri-based Rust application, which successfully implements similar window management features. Key insights were gathered from:

- AIHelper's `window.rs` module for window property settings
- AIHelper's `screenshot.rs` module for screen capture protection techniques

These changes should significantly improve the reliability and effectiveness of WindowControlInjector for its key use cases.
