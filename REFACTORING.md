# WindowControlInjector Refactoring: AppKit Skeleton Wrapper Approach

## 1. Executive Summary

This document outlines a refactoring strategy for WindowControlInjector using an "AppKit Skeleton Wrapper" approach. This unified method combines the reliability of DYLIB injection with the power of CGS APIs in a maintenance-friendly architecture that works across all macOS application types, including complex applications like Google Chrome, Discord, and Electron-based apps.

Rather than implementing application-specific optimizations, this approach injects a universal AppKit bridge layer that works consistently across all application architectures, providing a robust window protection solution with minimal maintenance requirements.

Key benefits include:
- Universal compatibility across all application types
- Elimination of application-specific code
- Reduced maintenance burden
- Preservation of existing API and functionality

## 2. Architecture Design

### 2.1 Core Design Principles

1. **Universality**: Single implementation works for all application types
2. **Simplicity**: Minimize complexity with unified window detection
3. **Resilience**: Multiple detection methods ensure no windows are missed
4. **Maintenance-Friendly**: No application-specific code to maintain
5. **Compatibility**: Maintain current application launching functionality

### 2.2 Key Components

1. **AppKit Skeleton Wrapper**: A universal bridge compatible with all application architectures
2. **Dual Window Detection**: Combined NSWindow and CGWindowList approaches
3. **CGS Protection Layer**: Minimal set of CGS functions for window protection
4. **Dynamic Function Resolution**: Robust CGS function loading with error handling
5. **Application Launcher**: Maintains existing application launching functionality

### 2.3 Architectural Flow

```
┌─────────────────┐      ┌─────────────────┐     ┌───────────────────┐
│ App Launcher    │──────▶ DYLIB Injection │────▶│ AppKit Skeleton   │
│ (Original API)  │      │ (Entry Point)   │     │ Wrapper           │
└─────────────────┘      └─────────────────┘     └───────────────────┘
                                                         │
                                                         │
                                                         ▼
                            ┌─────────────────────────────────────────┐
                            │         Dual Window Detection           │
                            │                                         │
                            │  ┌─────────────┐     ┌─────────────┐    │
                            │  │  NSWindow   │     │ CGWindowList │    │
                            │  │  (AppKit)   │     │ (CoreGraphics)│    │
                            │  └─────────────┘     └─────────────┘    │
                            └─────────────────────────────────────────┘
                                                         │
                                                         │
                                                         ▼
                                               ┌───────────────────┐
                                               │  CGS Protection   │
                                               │  Layer            │
                                               └───────────────────┘
```

## 3. Implementation Details

### 3.1 AppKit Skeleton Wrapper

The AppKit Skeleton Wrapper provides a unified interface for window protection across all application types:

```objective-c
// WCAppKitBridge - Universal bridge to protect windows in any application
@interface WCAppKitBridge : NSObject

// Initialize the bridge and start window protection
+ (void)initialize;
+ (void)protectAllWindows;
+ (void)setupWindowProtectionObserver;

@end

@implementation WCAppKitBridge {
    static NSMutableSet *_protectedWindowIDs;
    static CGError (*_CGSSetWindowSharingState)(CGSConnectionID, CGWindowID, CGSWindowSharingType);
    static BOOL _cgsFunctionsResolved;
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _protectedWindowIDs = [NSMutableSet set];
        _cgsFunctionsResolved = [self resolveCGSFunctions];
    });
}

+ (BOOL)resolveCGSFunctions {
    // Dynamically load CGS functions
    void *cgFramework = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY);
    if (!cgFramework) {
        NSLog(@"[WCAppKitBridge] ERROR: Could not load CoreGraphics framework");
        return NO;
    }

    _CGSSetWindowSharingState = dlsym(cgFramework, "CGSSetWindowSharingState");

    if (!_CGSSetWindowSharingState) {
        NSLog(@"[WCAppKitBridge] WARNING: CGSSetWindowSharingState function not available");
        return NO;
    }

    return YES;
}

+ (void)initialize {
    NSLog(@"[WCAppKitBridge] Initializing AppKit Skeleton Wrapper");

    // Delay initialization slightly to allow application to finish launching
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self protectAllWindows];
        [self setupWindowProtectionObserver];

        NSLog(@"[WCAppKitBridge] Window protection initialized for process %d", getpid());
    });
}

+ (void)protectAllWindows {
    // Protect all windows regardless of application type
    [self enumerateAllWindowsWithBlock:^(CGWindowID windowID) {
        if (![_protectedWindowIDs containsObject:@(windowID)]) {
            [self protectWindowWithID:windowID];
            [_protectedWindowIDs addObject:@(windowID)];
            NSLog(@"[WCAppKitBridge] Protected window %u", windowID);
        }
    }];
}

+ (void)enumerateAllWindowsWithBlock:(void(^)(CGWindowID windowID))block {
    pid_t pid = getpid();

    // Method 1: Use AppKit API (for standard AppKit applications)
    NSArray *appKitWindows = [NSApp windows];
    if (appKitWindows.count > 0) {
        for (NSWindow *window in appKitWindows) {
            block([window windowNumber]);
        }
    }

    // Method 2: Use CGWindowList (for ALL window types, including non-AppKit windows)
    CFArrayRef windowList = CGWindowListCopyWindowInfo(
        kCGWindowListOptionAll,
        kCGNullWindowID);

    if (windowList) {
        for (id windowInfo in (__bridge NSArray *)windowList) {
            NSNumber *ownerPID = windowInfo[(NSString *)kCGWindowOwnerPID];

            if ([ownerPID intValue] == pid) {
                CGWindowID windowID = [windowInfo[(NSString *)kCGWindowNumber] unsignedIntValue];
                block(windowID);
            }
        }

        CFRelease(windowList);
    }
}

+ (void)protectWindowWithID:(CGWindowID)windowID {
    if (!_cgsFunctionsResolved) {
        NSLog(@"[WCAppKitBridge] ERROR: Cannot protect window - CGS functions not available");
        return;
    }

    // Use minimal CGS calls for protection
    CGSConnectionID cid = CGSMainConnectionID();
    CGError result = _CGSSetWindowSharingState(cid, windowID, kCGSWindowSharingNone);

    if (result != 0) {
        NSLog(@"[WCAppKitBridge] ERROR: Failed to protect window %u (error: %d)", windowID, result);
    }
}

+ (void)setupWindowProtectionObserver {
    // Method 1: AppKit notifications (for standard AppKit applications)
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(windowDidAppear:)
                                                 name:NSWindowDidExposeNotification
                                               object:nil];

    // Method 2: Periodic scan (for non-AppKit windows that don't trigger notifications)
    NSTimer *scanTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                         repeats:YES
                                                           block:^(NSTimer *timer) {
        [self protectAllWindows];
    }];
}

+ (void)windowDidAppear:(NSNotification *)notification {
    NSWindow *window = notification.object;
    if (window && [window isKindOfClass:[NSWindow class]]) {
        CGWindowID windowID = [window windowNumber];
        if (![_protectedWindowIDs containsObject:@(windowID)]) {
            [self protectWindowWithID:windowID];
            [_protectedWindowIDs addObject:@(windowID)];
            NSLog(@"[WCAppKitBridge] Protected new window %u from notification", windowID);
        }
    }
}

@end
```

### 3.2 DYLIB Injection Entry Point

The DYLIB entry point initializes the AppKit Skeleton Wrapper:

```objective-c
// Entry point for the injected DYLIB
__attribute__((constructor))
static void initialize(void) {
    // Simple logging to confirm DYLIB was loaded
    NSLog(@"[WindowControlInjector] DYLIB loaded into process %d", getpid());

    // Initialize the AppKit Skeleton Wrapper on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [WCAppKitBridge initialize];
    });
}
```

### 3.3 Application Launcher

The Application Launcher maintains the existing functionality to launch and protect applications:

```objective-c
@interface WCApplicationLauncher : NSObject

// Launch and protect an application
- (BOOL)launchAndProtectApplication:(NSString *)appPath error:(NSError **)error;

// Get currently protected applications
- (NSArray<NSRunningApplication *> *)protectedApplications;

// Stop protecting a specific application
- (void)stopProtectingApplication:(NSRunningApplication *)app;

@end

@implementation WCApplicationLauncher {
    NSMutableDictionary<NSNumber *, NSRunningApplication *> *_protectedApps;
    NSString *_injectorDylibPath;
}

- (instancetype)init {
    if (self = [super init]) {
        _protectedApps = [NSMutableDictionary dictionary];

        // Resolve path to our injector DYLIB
        _injectorDylibPath = [self resolveInjectorDylibPath];
        NSLog(@"Using injector DYLIB at: %@", _injectorDylibPath);
    }
    return self;
}

- (NSString *)resolveInjectorDylibPath {
    // Implementation to find the DYLIB path (unchanged from current code)
    // ...
}

- (BOOL)launchAndProtectApplication:(NSString *)appPath error:(NSError **)error {
    // Verify the application exists
    if (![[NSFileManager defaultManager] fileExistsAtPath:appPath]) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.windowcontrolinjector"
                                        code:101
                                    userInfo:@{NSLocalizedDescriptionKey: @"Application not found"}];
        }
        return NO;
    }

    // Launch with DYLIB injection
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/open"];

    // Prepare environment with DYLIB injection
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
    env[@"DYLD_INSERT_LIBRARIES"] = _injectorDylibPath;
    [task setEnvironment:env];
    [task setArguments:@[@"-n", appPath]];

    @try {
        [task launch];

        // Track the launched application
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSRunningApplication *app = [self findRunningApplicationForPath:appPath];
            if (app) {
                self->_protectedApps[@(app.processIdentifier)] = app;
            }
        });

        return YES;
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.windowcontrolinjector"
                                        code:102
                                    userInfo:@{NSLocalizedDescriptionKey: exception.reason}];
        }
        return NO;
    }
}

- (NSRunningApplication *)findRunningApplicationForPath:(NSString *)appPath {
    NSString *appName = [[appPath lastPathComponent] stringByDeletingPathExtension];

    for (NSRunningApplication *app in [[NSWorkspace sharedWorkspace] runningApplications]) {
        if ([app.localizedName isEqualToString:appName] ||
            [app.bundleURL.path isEqualToString:appPath]) {
            return app;
        }
    }

    return nil;
}

- (NSArray<NSRunningApplication *> *)protectedApplications {
    return [_protectedApps.allValues copy];
}

- (void)stopProtectingApplication:(NSRunningApplication *)app {
    [_protectedApps removeObjectForKey:@(app.processIdentifier)];
    [app terminate];
}

@end
```

### 3.4 Main API Interface

The main API interface maintains compatibility with the existing implementation:

```objective-c
@interface WindowControlInjector : NSObject

// Main API
+ (instancetype)sharedInstance;
+ (BOOL)launchAndProtectApplication:(NSString *)appPath error:(NSError **)error;
- (void)stopProtectingApplication:(NSRunningApplication *)app;
- (void)stopProtectingAllApplications;
- (NSArray<NSRunningApplication *> *)protectedApplications;

@end

@implementation WindowControlInjector {
    WCApplicationLauncher *_appLauncher;
}

+ (instancetype)sharedInstance {
    static WindowControlInjector *instance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });

    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _appLauncher = [[WCApplicationLauncher alloc] init];
    }
    return self;
}

+ (BOOL)launchAndProtectApplication:(NSString *)appPath error:(NSError **)error {
    return [[self sharedInstance] launchAndProtectApplication:appPath error:error];
}

- (BOOL)launchAndProtectApplication:(NSString *)appPath error:(NSError **)error {
    return [_appLauncher launchAndProtectApplication:appPath error:error];
}

- (void)stopProtectingApplication:(NSRunningApplication *)app {
    [_appLauncher stopProtectingApplication:app];
}

- (void)stopProtectingAllApplications {
    for (NSRunningApplication *app in [_appLauncher protectedApplications]) {
        [_appLauncher stopProtectingApplication:app];
    }
}

- (NSArray<NSRunningApplication *> *)protectedApplications {
    return [_appLauncher protectedApplications];
}

@end
```

## 4. Key Technical Advantages

### 4.1 Universal Window Protection

The AppKit Skeleton Wrapper approach provides several key technical advantages:

1. **Application-Agnostic Implementation**:
   - Works identically for AppKit and non-AppKit applications
   - No need for application-specific detection or customization
   - Single codebase works for all applications

2. **Dual Window Detection Methods**:
   - NSApp windows for traditional AppKit applications
   - CGWindowList for non-AppKit applications (Chrome, Electron)
   - Ensures all windows are detected regardless of how they're created

3. **Simple, Focused CGS Usage**:
   - Uses minimal CGS API surface (primarily CGSSetWindowSharingState)
   - Reduces risk of API changes breaking functionality
   - Easy to maintain and update for future macOS versions

4. **Maintenance-Friendly Design**:
   - No application-specific code to update when new applications emerge
   - Clean separation of concerns between components
   - Reduced codebase size and complexity

### 4.2 Chrome/Electron Compatibility

This implementation specifically addresses challenges with Chrome and Electron-based applications:

1. **Bypasses UI Framework Limitations**:
   - Ignores how the window was created (Electron, Chromium, etc.)
   - Works directly at the Window Server level for protection
   - Not dependent on specific UI framework implementation details

2. **PID-Based Window Association**:
   - Uses process ID to reliably associate windows with applications
   - Identifies all windows belonging to target processes
   - Works even for multi-process applications like Chrome

3. **Comprehensive Window Detection**:
   - Timer-based scanning ensures windows are protected even if notifications aren't triggered
   - Handles non-standard window creation that bypasses AppKit

## 5. Implementation Strategy

### 5.1 Implementation Phases

1. **Phase 1: Core AppKit Skeleton Wrapper**
   - Implement the WCAppKitBridge class
   - Create the DYLIB injection entry point
   - Develop the dual window detection system

2. **Phase 2: Application Launcher Integration**
   - Update the application launcher to maintain existing functionality
   - Implement application tracking and management
   - Ensure proper DYLIB injection for all application types

3. **Phase 3: API Compatibility Layer**
   - Update the public API interface for backward compatibility
   - Implement any necessary adapter methods
   - Ensure seamless transition from the current implementation

### 5.2 Compatibility Considerations

1. **Maintain Existing API**:
   - Preserve the current public API interface
   - Ensure existing code that uses WindowControlInjector continues to work
   - Add new features as extensions rather than replacements

2. **Graceful Degradation**:
   - Handle situations where DYLIB injection fails
   - Provide clear error messages for troubleshooting
   - Degrade functionality gracefully when features are unavailable

3. **macOS Version Compatibility**:
   - Implement runtime detection for CGS function availability
   - Handle differences between macOS versions
   - Follow Apple's recommended practices for version checking

## 6. Error Handling and Logging

### 6.1 Structured Error Handling

1. **DYLIB Injection Errors**:
   - Detect and report if DYLIB injection fails
   - Provide meaningful error messages for common failure scenarios
   - Log detailed diagnostics for troubleshooting

2. **CGS Function Resolution Errors**:
   - Handle cases where CGS functions cannot be resolved
   - Log function availability for diagnostic purposes
   - Implement graceful degradation when functions are unavailable

3. **Window Protection Errors**:
   - Track and report failures in window protection
   - Log window IDs and error codes for troubleshooting
   - Retry protection for windows that failed initial protection

### 6.2 Enhanced Logging

1. **Process and Window Identification**:
   - Log process IDs and window IDs for tracking
   - Include relevant metadata in log messages
   - Enable correlation between injected processes and windows

2. **Protection Status Logging**:
   - Log successful protection operations
   - Track protection counts and success rates
   - Provide summary statistics for monitoring

3. **Error Categorization**:
   - Categorize errors by type and severity
   - Provide context-specific error messages
   - Include troubleshooting hints in error messages

## 7. Conclusion

The AppKit Skeleton Wrapper approach provides a robust, maintenance-friendly solution for protecting windows in all types of macOS applications, including complex applications like Google Chrome, Discord, and Electron-based apps. By combining DYLIB injection with a universal bridge layer and CGS protection, this implementation eliminates the need for application-specific customizations while ensuring comprehensive window protection.

Key benefits of this approach include:

1. **Universal Compatibility**: Works across all application types with a single implementation
2. **Reduced Maintenance**: No application-specific code to maintain as new applications emerge
3. **Focused CGS Usage**: Minimal use of CGS APIs reduces risk of future compatibility issues
4. **Preservation of Existing API**: Maintains backward compatibility with the current implementation

This solution provides an optimal balance between effectiveness, maintenance burden, and future compatibility, addressing the core requirements for WindowControlInjector in a sustainable way.
