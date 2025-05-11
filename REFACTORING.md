# WindowControlInjector: Hybrid DYLIB-CGS Implementation

## 1. Executive Summary

This document outlines an enhanced approach for WindowControlInjector that combines the existing DYLIB injection with Core Graphics Services (CGS) direct API calls. Instead of completely replacing the DYLIB injection mechanism, we will refocus its role to specialize in "preparation work" for optimal CGS functionality. The actual window protection will then be implemented using minimal CGS calls.

This hybrid approach:
1. Maintains the current application launching workflow with DYLIB injection
2. Refocuses the injected DYLIB to perform CGS-optimizing preparation steps
3. Implements window protection through minimal direct CGS calls
4. Handles complex applications like Chrome, Discord, and Steam through application-specific optimizations

The resulting implementation will be more robust, maintainable, and effective across a wider range of macOS applications while preserving compatibility with the current codebase.

## 2. Architecture Design

### 2.1 Core Design Principles

1. **Dual-System Approach**: Use both DYLIB injection and CGS APIs in coordinated roles
2. **Clear Role Separation**: DYLIB for preparation work, CGS for actual window protection
3. **Application-Specific Optimization**: Customize preparation steps based on target application
4. **Process Communication**: Establish clear signals between injected DYLIB and main application
5. **Minimal API Usage**: Use only essential CGS functions to reduce maintenance burden

### 2.2 Key Components

1. **Preparation DYLIB**: Injected into target application to optimize environment for CGS
2. **Window Scanner**: Detects windows using CGWindowList APIs
3. **CGS Function Layer**: Minimal implementation of essential CGS functions
4. **Process Communication**: Mechanism for DYLIB and main app to coordinate
5. **Application-Specific Handlers**: Customized preparation for different application types

### 2.3 Component Workflow

```
1. application launcher
2. preparation dylib
3.environment optimization
4.process communication
5. main application controller
6. window scanner(cgwindowlist api)
7. cgs function layer(window protection)
```

## 3. Implementation Details

### 3.1 Preparation DYLIB

The DYLIB's role is refocused to prepare the target application for optimal CGS operations:

```objective-c
// Initialization function in the DYLIB
__attribute__((constructor))
static void initialize(void) {
    // Delay execution slightly to ensure application has initialized
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        NSLog(@"[WindowControlInjector] Preparing environment for CGS operations on PID: %d", getpid());

        // Get application information
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSLog(@"[WindowControlInjector] Running in application: %@", bundleID);

        // Apply application-specific optimizations
        [WCPreparationManager optimizeForApplication:bundleID];

        // Disable settings that might interfere with CGS operations
        [WCPreparationManager disableWindowProtections];

        // Signal readiness to the main application
        [WCProcessCommunication signalPreparationComplete];

        // Set up window creation listener
        [WCPreparationManager setupWindowNotifications];
    });
}
```

### 3.2 Application-Specific Optimization

The preparation DYLIB includes specialized handlers for different application types:

```objective-c
@implementation WCPreparationManager

+ (void)optimizeForApplication:(NSString *)bundleID {
    if ([bundleID containsString:@"chrome"] || [bundleID containsString:@"electron"]) {
        [self optimizeChromeEnvironment];
    } else if ([bundleID containsString:@"discord"]) {
        [self optimizeDiscordEnvironment];
    } else if ([bundleID containsString:@"steam"]) {
        [self optimizeSteamEnvironment];
    } else {
        [self optimizeDefaultEnvironment];
    }
}

+ (void)optimizeChromeEnvironment {
    // Chrome/Electron-specific optimizations
    NSLog(@"[WindowControlInjector] Applying Chrome/Electron-specific optimizations");

    // Disable window tabbing which can interfere with CGS operations
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NSAllowsAutomaticWindowTabbing"];

    // Adjust window layer settings for Chrome's multi-process architecture
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NSRequiresAquaSystemAppearance"];

    // Chromium-specific environment variables
    setenv("CHROMIUM_DISABLE_COMPOSITING_RESTRICTION", "1", 1);
}

+ (void)optimizeDiscordEnvironment {
    // Discord-specific optimizations
    NSLog(@"[WindowControlInjector] Applying Discord-specific optimizations");

    // Discord uses Electron but has specific settings
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NSAllowsAutomaticWindowTabbing"];

    // Adjust Discord's custom window handling
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NSRequiresAquaSystemAppearance"];
}

+ (void)disableWindowProtections {
    NSApplication *app = [NSApplication sharedApplication];

    // Disable standard screen capture protection (will be replaced by CGS)
    if ([app respondsToSelector:@selector(setValue:forKey:)]) {
        [app setValue:@NO forKey:@"_disallowsScreenCapture"];
    }

    // Allow window level modification for CGS to work properly
    if ([app respondsToSelector:@selector(setValue:forKey:)]) {
        [app setValue:@YES forKey:@"_allowsWindowLevelModification"];
    }
}

+ (void)setupWindowNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:[WCWindowNotifier class]
                                            selector:@selector(windowCreated:)
                                                name:NSWindowDidCreateNotification
                                              object:nil];
}

@end
```

### 3.3 Process Communication

Communication between the injected DYLIB and the main application:

```objective-c
@implementation WCProcessCommunication

+ (void)signalPreparationComplete {
    // Create a signal file that the main application can detect
    NSString *readyFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                              [NSString stringWithFormat:@"wci_ready_%d.signal", getpid()]];

    NSDictionary *info = @{
        @"pid": @(getpid()),
        @"bundleID": [[NSBundle mainBundle] bundleIdentifier] ?: @"",
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:info options:0 error:nil];
    [jsonData writeToFile:readyFilePath atomically:YES];

    NSLog(@"[WindowControlInjector] Preparation complete signal sent to: %@", readyFilePath);
}

@end

// Window notification handler
@implementation WCWindowNotifier

+ (void)windowCreated:(NSNotification *)notification {
    NSWindow *window = notification.object;
    if ([window isKindOfClass:[NSWindow class]]) {
        // Create a signal file with window information
        NSString *windowInfoPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                   [NSString stringWithFormat:@"wci_window_%d_%lu.info",
                                    getpid(), [window windowNumber]]];

        NSDictionary *windowInfo = @{
            @"windowID": @([window windowNumber]),
            @"title": [window title] ?: @"",
            @"frame": NSStringFromRect([window frame])
        };

        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:windowInfo options:0 error:nil];
        [jsonData writeToFile:windowInfoPath atomically:YES];

        NSLog(@"[WindowControlInjector] Window creation signal sent for window ID: %lu", [window windowNumber]);
    }
}

@end
```

### 3.4 CGS Function Layer

The minimal CGS implementation focuses on essential window protection functions:

```objective-c
@interface WCCGSFunctions : NSObject

// Public method to check if required functions are available
- (BOOL)areCGSFunctionsAvailable;

// CGS function wrappers with safety checks
- (BOOL)setWindowSharingNone:(CGWindowID)windowID;
- (BOOL)setWindowLevel:(CGWindowID)windowID level:(int)level;

@end

@implementation WCCGSFunctions {
    BOOL _functionsResolved;

    // Function pointers for dynamically resolved CGS functions
    CGError (*_CGSSetWindowSharingState)(CGSConnectionID, CGWindowID, CGSWindowSharingType);
    CGError (*_CGSSetWindowLevel)(CGSConnectionID, CGWindowID, int);
}

- (instancetype)init {
    if (self = [super init]) {
        // Try to resolve CGS functions
        _functionsResolved = [self resolveCGSFunctions];

        if (!_functionsResolved) {
            NSLog(@"WARNING: Could not resolve CGS functions. Some features will be limited.");
        }
    }
    return self;
}

- (BOOL)resolveCGSFunctions {
    // Load CoreGraphics framework
    void *cgFramework = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY);
    if (!cgFramework) {
        NSLog(@"ERROR: Could not load CoreGraphics framework");
        return NO;
    }

    // Resolve minimum required functions
    _CGSSetWindowSharingState = dlsym(cgFramework, "CGSSetWindowSharingState");
    _CGSSetWindowLevel = dlsym(cgFramework, "CGSSetWindowLevel");

    // Check if critical functions are available
    if (!_CGSSetWindowSharingState) {
        NSLog(@"WARNING: CGSSetWindowSharingState function not available");
        return NO;
    }

    return YES;
}

- (BOOL)setWindowSharingNone:(CGWindowID)windowID {
    if (!_functionsResolved || !_CGSSetWindowSharingState) {
        return NO;
    }

    CGSConnectionID cid = CGSMainConnectionID();
    CGError error = _CGSSetWindowSharingState(cid, windowID, CGSWindowSharingNone);

    if (error != kCGErrorSuccess) {
        NSLog(@"ERROR: Failed to set window sharing to None for window %u (error: %d)", windowID, error);
        return NO;
    }

    return YES;
}

- (BOOL)setWindowLevel:(CGWindowID)windowID level:(int)level {
    if (!_functionsResolved || !_CGSSetWindowLevel) {
        return NO;
    }

    CGSConnectionID cid = CGSMainConnectionID();
    CGError error = _CGSSetWindowLevel(cid, windowID, level);

    if (error != kCGErrorSuccess) {
        NSLog(@"ERROR: Failed to set window level for window %u (error: %d)", windowID, error);
        return NO;
    }

    return YES;
}

@end
```

### 3.5 Main Application Controller

The main application controller coordinates the workflow:

```objective-c
@implementation WindowControlInjector {
    WCCGSFunctions *_cgsFunctions;
    NSMutableDictionary<NSNumber *, NSString *> *_monitoredApplications; // PID -> appPath
    NSTimer *_processMonitorTimer;
    NSTimer *_windowScanTimer;
}

+ (BOOL)launchAndProtectApplication:(NSString *)appPath error:(NSError **)error {
    return [[self sharedInstance] launchAndProtectApplication:appPath error:error];
}

- (BOOL)launchAndProtectApplication:(NSString *)appPath error:(NSError **)error {
    // 1. Launch with DYLIB injection (maintaining current approach)
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/open"];

    // Set up environment with DYLIB injection
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
    env[@"DYLD_INSERT_LIBRARIES"] = [self preparationDylibPath];
    [task setEnvironment:env];
    [task setArguments:@[@"-n", appPath]];

    @try {
        [task launch];

        // 2. Start monitoring for preparation completion
        [self startMonitoringForApplicationAtPath:appPath];
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.windowcontrolinjector"
                                        code:100
                                    userInfo:@{NSLocalizedDescriptionKey: exception.reason}];
        }
        return NO;
    }
}

- (void)startMonitoringForApplicationAtPath:(NSString *)appPath {
    // Start looking for the launched application
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSRunningApplication *app = [self findRunningApplicationForPath:appPath];
        if (app) {
            // Add to monitored applications
            self->_monitoredApplications[@(app.processIdentifier)] = appPath;

            // Start process and window monitoring timers
            [self startProcessMonitoring];
            [self startWindowScanning];

            NSLog(@"Started monitoring application: %@ (PID: %d)", app.localizedName, app.processIdentifier);
        }
    });
}

- (void)startProcessMonitoring {
    if (_processMonitorTimer == nil) {
        _processMonitorTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                              repeats:YES
                                                                block:^(NSTimer *timer) {
            [self checkForProcessSignals];
        }];
    }
}

- (void)startWindowScanning {
    if (_windowScanTimer == nil) {
        _windowScanTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                          repeats:YES
                                                            block:^(NSTimer *timer) {
            [self scanForWindowsFromMonitoredProcesses];
        }];
    }
}

- (void)checkForProcessSignals {
    // Check for preparation completion signals
    for (NSNumber *pid in _monitoredApplications.allKeys) {
        NSString *readyFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                  [NSString stringWithFormat:@"wci_ready_%@.signal", pid]];

        if ([[NSFileManager defaultManager] fileExistsAtPath:readyFilePath]) {
            NSLog(@"Detected preparation complete signal for PID: %@", pid);
            // Process is ready for CGS operations
            [self markProcessAsReady:pid.intValue];

            // Clean up signal file
            [[NSFileManager defaultManager] removeItemAtPath:readyFilePath error:nil];
        }
    }
}

- (void)scanForWindowsFromMonitoredProcesses {
    // Use CGWindowList to scan for windows from monitored processes
    CFArrayRef windowList = CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
        kCGNullWindowID);

    if (!windowList) return;

    for (id windowInfo in (__bridge NSArray *)windowList) {
        NSNumber *ownerPID = windowInfo[(NSString *)kCGWindowOwnerPID];

        // Check if this window belongs to a monitored application
        if ([_monitoredApplications.allKeys containsObject:ownerPID]) {
            CGWindowID windowID = [windowInfo[(NSString *)kCGWindowNumber] unsignedIntValue];

            // Apply protection using CGS
            [self protectWindowWithID:windowID];
        }
    }

    CFRelease(windowList);
}

- (void)protectWindowWithID:(CGWindowID)windowID {
    // Use CGS to apply window protection
    [_cgsFunctions setWindowSharingNone:windowID];
}

@end
```

## 4. Implementation Strategy

### 4.1 Phase 1: Preparation DYLIB Development

1. Create the preparation-focused DYLIB that:
   - Optimizes the environment for CGS operations
   - Implements application-specific customizations
   - Sets up process communication mechanisms

2. Refactor the current DYLIB code to:
   - Remove extensive method swizzling
   - Focus on CGS-preparation tasks
   - Add application detection and specialized handlers

### 4.2 Phase 2: CGS Implementation

1. Develop the CGS function resolution layer:
   - Implement dynamic loading of CGS functions
   - Create minimal wrappers for essential functions
   - Add robust error handling

2. Implement the Window Scanner:
   - Use CGWindowList APIs to detect windows
   - Filter windows by process ownership
   - Track window state and changes

### 4.3 Phase 3: Process Communication

1. Implement the process communication system:
   - Create signal files for state communication
   - Set up window creation monitoring
   - Manage process lifecycle events

2. Coordinate between DYLIB and main application:
   - Signal when preparation is complete
   - Notify about new window creation
   - Handle application-specific events

## 5. Key Technical Considerations

### 5.1 CGS API Stability

- Minimize the number of CGS functions used to reduce exposure to API changes
- Implement dynamic function resolution with robust error handling
- Keep CGS function calls isolated in a dedicated layer

### 5.2 Application Compatibility

- Create specialized preparation for different application types:
  - Chrome/Electron apps: Handle multi-process renderer architecture
  - Discord: Address Electron-specific window handling
  - Steam: Manage custom window management

- Implement adaptive settings based on application detection

### 5.3 Error Handling

- Implement robust error detection and recovery
- Handle cases where CGS functions are not available
- Provide meaningful error messages for troubleshooting

### 5.4 macOS Version Compatibility

- Use runtime detection to adapt to version differences
- Document compatibility notes for each macOS version

## 6. Conclusion

The hybrid DYLIB-CGS approach leverages the strengths of both techniques:

1. **Maintains Existing Workflow**: Preserves the current application launching and DYLIB injection
2. **Improves Compatibility**: Works with complex applications through specialized preparation
3. **Reduces Maintenance**: Minimizes CGS API usage to the essential functions
4. **Clear Separation of Concerns**: DYLIB focuses on preparation, CGS handles actual protection

By implementing this hybrid approach, WindowControlInjector will work more reliably with complex applications like Chrome, Discord, and Steam, while maintaining a cleaner, more maintainable codebase that can better withstand macOS updates.
