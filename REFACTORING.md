# WindowControlInjector Refactoring Plan

## Summary of Refactoring

The WindowControlInjector refactoring centers on three key architectural changes:

1. **CGS API Integration**: Replace AppKit-specific mechanisms with the Core Graphics Services (CGS) API for universal window control across all application types, with dynamic function resolution.

2. **Unified Window Detection**: Implement a dual-detection approach through the WCWindowBridge abstraction, using both AppKit and CGS methods to ensure comprehensive window coverage.

3. **Code Modernization**: Improve code quality through modular design, reduced global state, better error handling, and safer method swizzling.

Here's the complete revised refactoring plan:

---

# Refactoring Document for WindowControlInjector

## Introduction

The WindowControlInjector project is a macOS utility that uses DYLIB injection to modify the behavior and appearance of application windows at runtime. Its current features include screen recording protection, Dock icon hiding, always-on-top windows, and system UI compatibility. However, the existing implementation struggles with non-AppKit applications (e.g., Google Chrome, Discord, Electron-based apps) due to its reliance on AppKit-specific mechanisms. Additionally, the codebase suffers from poor maintainability, excessive global state, and outdated techniques.

This refactoring aims to:

- Ensure compatibility with both AppKit and non-AppKit applications by integrating the Core Graphics Services (CGS) API.
- Improve code maintainability and reliability through better organization, error handling, and modern practices.
- Achieve consistent screen recording bypass across all target applications.

## Architecture Changes

### 1. Integration of CGS API

The CGS API, a low-level interface to the macOS Window Server, will replace AppKit-specific calls for screen recording protection. Key benefits include:

- **Universal Compatibility**: Controls windows across all app types, bypassing AppKit limitations.
- **Screen Recording Bypass**: Uses CGSSetWindowSharingState to prevent window capture, effective for both AppKit and non-AppKit apps.
- **Dynamic Resolution**: Functions will be resolved at runtime via dlsym to mitigate risks from undocumented API changes.

#### Implementation Strategy:

1. Create a dedicated `WCCGSFunctions` class to manage CGS function pointers:
   - Dynamically resolve functions using dlsym at runtime
   - Provide clear status methods to check function availability
   - Implement robust error logging when functions aren't available

2. Define key CGS types and functions:
   ```objc
   // Key function pointers to resolve
   typedef CGSConnectionID (*CGSDefaultConnectionPtr)(void);
   typedef CGError (*CGSSetWindowSharingStatePtr)(CGSConnectionID cid, CGWindowID wid, CGSWindowSharingType sharing);
   ```

3. Implement graceful fallbacks when CGS functions aren't available:
   - Log detailed error information for troubleshooting
   - Fall back to AppKit methods when possible
   - Provide clear status reporting for diagnostic purposes

### 2. Unified Window Detection

A dual-detection approach will ensure all windows are identified:

- **AppKit Apps**: Use [NSApp windows] for traditional macOS applications.
- **Non-AppKit Apps**: Use CGWindowListCopyWindowInfo with PID filtering to detect windows in apps like Chrome.

This ensures robust window management across diverse application architectures.

#### Implementation Strategy:

1. Create a `WCWindowBridge` class to abstract window detection:
   - Implement `getAllWindowsForCurrentApplication` to use both AppKit and CGS detection
   - Create `getAllWindowsForPID` to support window detection in multi-process applications
   - Provide unified window information through the `WCWindowInfo` class

2. Implement PID-based window filtering:
   - Filter CGWindowListCopyWindowInfo results by process ID
   - Detect windows from all child processes in multi-process applications
   - Merge results from both detection methods, avoiding duplicates

3. Add window protection methods:
   - Implement CGS-based protection as the primary method
   - Fall back to AppKit methods for traditional applications
   - Support both window detection approaches uniformly

### 3. Optimized DYLIB Injection

DYLIB injection will be refined to:

- Operate within target processes for direct window access.
- Support multi-process apps (e.g., Chrome) with improved stability.

#### Implementation Strategy:

1. Refine the injection mechanism:
   - Use the path resolver to reliably locate the DYLIB
   - Improve error handling for injection failures
   - Better support for multi-process applications

2. Enhance the initialization process:
   - Implement delayed initialization to allow target applications to fully load
   - Register for window notifications when possible
   - Add periodic scanning to protect dynamically created windows

## Implementation Details

### 1. Screen Recording Protection

- **CGS API Usage**: Apply CGSSetWindowSharingState to set windows to a non-recordable state.
- **Fallback**: Retain NSWindowSharingNone for AppKit apps as a secondary mechanism.
- **Dynamic Application**: Protection will be applied to newly created windows via periodic scans (every 0.5 seconds).

#### Code Example:

```objc
+ (BOOL)makeWindowInvisibleToScreenRecording:(NSInteger)windowID {
    WCCGSFunctions *cgs = [WCCGSFunctions sharedFunctions];

    if (![cgs canSetWindowSharingState]) {
        // Log error and try fallback if available
        return NO;
    }

    // Get the CGS connection
    CGSConnectionID cid = cgs.CGSDefaultConnection();

    // Set the window sharing state to none
    CGError error = cgs.CGSSetWindowSharingState(cid, (CGWindowID)windowID, CGSWindowSharingNone);

    // Log result and return success/failure
    return (error == 0);
}
```

### 2. Window Detection Logic

- **Bridge Class**: Use WCWindowBridge to abstract detection:
  - AppKit: Query [NSApp windows]
  - Non-AppKit: Filter CGWindowListCopyWindowInfo by target PID

- **Real-Time Updates**: Monitor window creation to apply protections instantly.

#### Code Example:

```objc
+ (NSArray<WCWindowInfo *> *)getAllWindowsForCurrentApplication {
    NSMutableArray<WCWindowInfo *> *allWindows = [NSMutableArray array];

    // 1. First try AppKit method
    NSArray<NSWindow *> *appKitWindows = NSApp.windows;
    if (appKitWindows) {
        // Process AppKit windows...
    }

    // 2. Now try CGS-based method for current PID
    pid_t currentPID = getpid();
    NSArray<WCWindowInfo *> *cgsWindows = [self getAllWindowsForPID:currentPID];

    // 3. Merge results, avoiding duplicates
    // ...

    return [allWindows copy];
}
```

### 3. Error Handling and Logging

- **Error Handling**: Add checks for injection failures, API resolution errors, and protection application, with fallback behaviors.
- **Logging**: Enhance with categorized logs (debug, info, error) including window IDs and process details.

### 4. Code Cleanup

- **Modular Design**: Split into modules (e.g., injection, detection, protection).
- **State Management**: Reduce global variables, favoring dependency injection.
- **Modern Practices**: Replace legacy swizzling with safer alternatives (e.g., method_exchangeImplementations).

## Future Challenges

- **CGS API Stability**: Monitor macOS updates for potential API changes.
- **Multi-Process Support**: Refine handling of apps with dynamic process spawning.
- **Configuration**: Plan for user-customizable protection options.

## Conclusion

This refactoring leverages the CGS API to deliver a robust, maintainable WindowControlInjector capable of bypassing screen recording for all macOS applications. The updated architecture and implementation ensure long-term scalability and reliability, while the dual window detection approach provides comprehensive coverage for all application types.

By implementing dynamic function resolution and graceful fallbacks, the refactored code will be more resilient to macOS updates and offer better diagnostic capabilities when issues arise. The modular design will also facilitate future enhancements and customization options.
