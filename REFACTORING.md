# WindowControlInjector Refactoring Plan

## Summary of Refactoring

The WindowControlInjector refactoring centers on three key architectural changes:

1. **CGS API Integration**: Replace AppKit-specific mechanisms with the Core Graphics Services (CGS) API for universal window control across all application types, with dynamic function resolution.

2. **Unified Window Detection**: Implement a dual-detection approach through the WCWindowBridge abstraction, using both AppKit and CGS methods to ensure comprehensive window coverage.

3. **Code Modernization**: Improve code quality through modular design, reduced global state, better error handling, and safer method swizzling.

Here's the complete detailed refactoring plan:

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

```objc
// WCCGSFunctions.h
@interface WCCGSFunctions : NSObject

// Shared instance accessor
+ (instancetype)sharedFunctions;

// Core CGS function pointers
@property (nonatomic, readonly) CGSConnectionID (*CGSDefaultConnection)(void);
@property (nonatomic, readonly) CGError (*CGSSetWindowSharingState)(CGSConnectionID cid, CGWindowID wid, CGSWindowSharingType sharing);
@property (nonatomic, readonly) CGError (*CGSGetWindowSharingState)(CGSConnectionID cid, CGWindowID wid, CGSWindowSharingType *sharing);
@property (nonatomic, readonly) CGError (*CGSGetWindowLevel)(CGSConnectionID cid, CGWindowID wid, CGWindowLevel *level);
@property (nonatomic, readonly) CGError (*CGSSetWindowLevel)(CGSConnectionID cid, CGWindowID wid, CGWindowLevel level);

// Availability checks
- (BOOL)isAvailable;
- (BOOL)canSetWindowSharingState;
- (BOOL)canSetWindowLevel;

// Function resolution
- (BOOL)resolveAllFunctions;

@end
```

2. Implement dynamic function resolution with robust error handling:

```objc
// WCCGSFunctions.m (partial implementation)
@implementation WCCGSFunctions {
    void *_cgsHandle;
    BOOL _functionsResolved;

    // Private function pointer storage
    CGSDefaultConnectionPtr _cgsDefaultConnection;
    CGSSetWindowSharingStatePtr _cgsSetWindowSharingState;
    CGSGetWindowSharingStatePtr _cgsGetWindowSharingState;
    CGSSetWindowLevelPtr _cgsSetWindowLevel;
    CGSGetWindowLevelPtr _cgsGetWindowLevel;
}

- (BOOL)resolveAllFunctions {
    if (_functionsResolved) return YES;

    // Load the Core Graphics framework
    _cgsHandle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW);
    if (!_cgsHandle) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to load CoreGraphics framework: %s", dlerror()];
        return NO;
    }

    // Resolve CGSDefaultConnection
    _cgsDefaultConnection = (CGSDefaultConnectionPtr)dlsym(_cgsHandle, "CGSDefaultConnection");
    if (!_cgsDefaultConnection) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to resolve CGSDefaultConnection: %s", dlerror()];
        return NO;
    }

    // Resolve CGSSetWindowSharingState
    _cgsSetWindowSharingState = (CGSSetWindowSharingStatePtr)dlsym(_cgsHandle, "CGSSetWindowSharingState");
    if (!_cgsSetWindowSharingState) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to resolve CGSSetWindowSharingState: %s", dlerror()];
        // Continue anyway - we'll check before using
    }

    // Resolve additional functions...

    _functionsResolved = (_cgsDefaultConnection != NULL); // At minimum we need this function
    return _functionsResolved;
}

- (BOOL)canSetWindowSharingState {
    return _cgsDefaultConnection != NULL && _cgsSetWindowSharingState != NULL;
}

// Getters that safely return the function pointers
- (CGSDefaultConnectionPtr)CGSDefaultConnection {
    return _cgsDefaultConnection;
}

- (CGSSetWindowSharingStatePtr)CGSSetWindowSharingState {
    return _cgsSetWindowSharingState;
}

// Other method implementations...

@end
```

3. Define required CGS types and constants:

```objc
// WCCGSTypes.h
#ifndef WCCGSTypes_h
#define WCCGSTypes_h

#include <CoreGraphics/CoreGraphics.h>

// Connection types
typedef uint32_t CGSConnectionID;

// Window types
typedef uint32_t CGSWindowID;

// Window sharing types (mirroring NSWindowSharingType values)
typedef enum {
    CGSWindowSharingNone = 0,
    CGSWindowSharingReadOnly = 1,
    CGSWindowSharingReadWrite = 2
} CGSWindowSharingType;

// Function pointer types
typedef CGSConnectionID (*CGSDefaultConnectionPtr)(void);
typedef CGError (*CGSSetWindowSharingStatePtr)(CGSConnectionID cid, CGSWindowID wid, CGSWindowSharingType sharing);
typedef CGError (*CGSGetWindowSharingStatePtr)(CGSConnectionID cid, CGSWindowID wid, CGSWindowSharingType *sharing);
typedef CGError (*CGSSetWindowLevelPtr)(CGSConnectionID cid, CGSWindowID wid, CGWindowLevel level);
typedef CGError (*CGSGetWindowLevelPtr)(CGSConnectionID cid, CGSWindowID wid, CGWindowLevel *level);

#endif /* WCCGSTypes_h */
```

4. Implement protection mechanism using CGS API:

```objc
// WCWindowProtector.m (new utility class for window protection)
+ (BOOL)makeWindowInvisibleToScreenRecording:(CGWindowID)windowID {
    WCCGSFunctions *cgs = [WCCGSFunctions sharedFunctions];

    if (![cgs canSetWindowSharingState]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowProtection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"CGSSetWindowSharingState function not available"];
        return NO;
    }

    // Get the CGS connection
    CGSConnectionID cid = cgs.CGSDefaultConnection();

    // Set the window sharing state to none
    CGError error = cgs.CGSSetWindowSharingState(cid, windowID, CGSWindowSharingNone);

    if (error) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowProtection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to set window sharing state: %d", error];
        return NO;
    }

    return YES;
}

+ (BOOL)setWindowLevel:(CGWindowID)windowID toLevel:(CGWindowLevel)level {
    WCCGSFunctions *cgs = [WCCGSFunctions sharedFunctions];

    if (![cgs canSetWindowLevel]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowProtection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"CGSSetWindowLevel function not available"];
        return NO;
    }

    // Get the CGS connection
    CGSConnectionID cid = cgs.CGSDefaultConnection();

    // Set the window level
    CGError error = cgs.CGSSetWindowLevel(cid, windowID, level);

    if (error) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowProtection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to set window level: %d", error];
        return NO;
    }

    return YES;
}
```

5. Implement graceful fallbacks when CGS functions aren't available:

```objc
// In WCWindowProtector.m
+ (BOOL)protectWindow:(id)window {
    BOOL success = NO;

    // First, try to use the CGS API if the window has a windowNumber
    if ([window respondsToSelector:@selector(windowNumber)] && [window windowNumber] > 0) {
        CGWindowID windowID = (CGWindowID)[window windowNumber];
        success = [self makeWindowInvisibleToScreenRecording:windowID];

        if (success) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"WindowProtection"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Successfully protected window using CGS API: %@", window];
        } else {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                         category:@"WindowProtection"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Failed to protect window using CGS API, trying AppKit fallback: %@", window];
        }
    }

    // If CGS failed or couldn't be applied, fall back to AppKit method if available
    if (!success && [window respondsToSelector:@selector(setSharingType:)]) {
        [window setSharingType:NSWindowSharingNone];
        success = YES;

        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"WindowProtection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Protected window using AppKit fallback: %@", window];
    }

    return success;
}
```

### 2. Unified Window Detection

A dual-detection approach will ensure all windows are identified:

- **AppKit Apps**: Use [NSApp windows] for traditional macOS applications.
- **Non-AppKit Apps**: Use CGWindowListCopyWindowInfo with PID filtering to detect windows in apps like Chrome.

This ensures robust window management across diverse application architectures.

#### Implementation Strategy:

1. Create `WCWindowInfo` class to abstract window information:

```objc
// WCWindowInfo.h
@interface WCWindowInfo : NSObject

// Window properties
@property (nonatomic, readonly) CGWindowID windowID;
@property (nonatomic, readonly, nullable) NSWindow *nsWindow;  // May be nil for non-AppKit windows
@property (nonatomic, readonly) CGRect frame;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) pid_t ownerPID;
@property (nonatomic, readonly) NSString *ownerName;
@property (nonatomic, readonly) BOOL isOnScreen;
@property (nonatomic, readonly) NSWindowLevel level;
@property (nonatomic, readonly) CGSWindowSharingType sharingType;
@property (nonatomic, readonly) BOOL isProtected;

// Initializers
- (instancetype)initWithWindowID:(CGWindowID)windowID;
- (instancetype)initWithNSWindow:(NSWindow *)window;
- (instancetype)initWithCGWindowInfo:(NSDictionary *)windowInfo;

// Protection methods
- (BOOL)makeInvisibleToScreenRecording;
- (BOOL)setLevel:(NSWindowLevel)level;

@end
```

2. Implement `WCWindowBridge` to unify window detection:

```objc
// WCWindowBridge.h
@interface WCWindowBridge : NSObject

+ (NSArray<WCWindowInfo *> *)getAllWindowsForCurrentApplication;
+ (NSArray<WCWindowInfo *> *)getAllWindowsForPID:(pid_t)pid;
+ (NSArray<WCWindowInfo *> *)getAllWindowsForApplicationWithPath:(NSString *)path;
+ (NSArray<pid_t> *)getChildProcessesForPID:(pid_t)pid;
+ (BOOL)protectAllWindowsForPID:(pid_t)pid;

@end

// WCWindowBridge.m (partial implementation)
@implementation WCWindowBridge

+ (NSArray<WCWindowInfo *> *)getAllWindowsForCurrentApplication {
    NSMutableArray<WCWindowInfo *> *allWindows = [NSMutableArray array];

    // 1. First try AppKit method for the current process
    NSApplication *app = [NSApplication sharedApplication];
    if (app) {
        for (NSWindow *window in app.windows) {
            WCWindowInfo *info = [[WCWindowInfo alloc] initWithNSWindow:window];
            [allWindows addObject:info];

            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                         category:@"WindowDetection"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Detected AppKit window: %@ (ID: %d)",
                                                 window.title, (int)info.windowID];
        }
    }

    // 2. Now try CGS-based method for the current process
    pid_t currentPID = getpid();
    NSArray<WCWindowInfo *> *cgsWindows = [self getAllWindowsForPID:currentPID];

    // 3. Merge results, avoiding duplicates
    for (WCWindowInfo *cgsWindow in cgsWindows) {
        BOOL isDuplicate = NO;

        for (WCWindowInfo *existingWindow in allWindows) {
            if (existingWindow.windowID == cgsWindow.windowID) {
                isDuplicate = YES;
                break;
            }
        }

        if (!isDuplicate) {
            [allWindows addObject:cgsWindow];

            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                         category:@"WindowDetection"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Detected CGS window: %@ (ID: %d)",
                                                 cgsWindow.title, (int)cgsWindow.windowID];
        }
    }

    return [allWindows copy];
}

+ (NSArray<WCWindowInfo *> *)getAllWindowsForPID:(pid_t)pid {
    NSMutableArray<WCWindowInfo *> *windows = [NSMutableArray array];

    // Get all windows from the window server
    CFArrayRef windowList = CGWindowListCopyWindowInfo(
        kCGWindowListOptionAll, kCGNullWindowID);

    if (windowList) {
        CFIndex count = CFArrayGetCount(windowList);

        for (CFIndex i = 0; i < count; i++) {
            NSDictionary *windowInfo = (NSDictionary *)CFArrayGetValueAtIndex(windowList, i);
            NSNumber *ownerPID = windowInfo[(NSString *)kCGWindowOwnerPID];

            // Check if this window belongs to our target process
            if ([ownerPID intValue] == pid) {
                WCWindowInfo *window = [[WCWindowInfo alloc] initWithCGWindowInfo:windowInfo];
                [windows addObject:window];

                [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                             category:@"WindowDetection"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"Found window for PID %d: %@ (ID: %d)",
                                                    pid, window.title, (int)window.windowID];
            }
        }

        CFRelease(windowList);
    }

    // Also check for child processes (especially for apps like Chrome)
    NSArray<pid_t> *childPIDs = [self getChildProcessesForPID:pid];
    for (NSNumber *childPID in childPIDs) {
        NSArray<WCWindowInfo *> *childWindows = [self getAllWindowsForPID:[childPID intValue]];
        [windows addObjectsFromArray:childWindows];
    }

    return [windows copy];
}

+ (NSArray<pid_t> *)getChildProcessesForPID:(pid_t)pid {
    NSMutableArray<NSNumber *> *childPIDs = [NSMutableArray array];

    // Implementation using proc_listpidinfo or NSTask with ps command
    // This example uses NSTask with ps for simplicity
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/ps"];
    [task setArguments:@[@"-o", @"pid,ppid", @"-ax"]];

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];

    [task launch];

    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];

    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray<NSString *> *lines = [output componentsSeparatedByString:@"\n"];

    for (NSString *line in lines) {
        // Skip header line
        if ([line hasPrefix:@"PID"]) continue;

        // Parse PID and PPID
        NSArray<NSString *> *components = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        components = [components filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];

        if (components.count >= 2) {
            pid_t childPID = [components[0] intValue];
            pid_t parentPID = [components[1] intValue];

            if (parentPID == pid) {
                [childPIDs addObject:@(childPID)];

                [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                             category:@"ProcessDetection"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"Found child process: %d for parent: %d",
                                                     childPID, pid];
            }
        }
    }

    return [childPIDs copy];
}

+ (BOOL)protectAllWindowsForPID:(pid_t)pid {
    NSArray<WCWindowInfo *> *windows = [self getAllWindowsForPID:pid];
    BOOL allProtected = YES;

    for (WCWindowInfo *window in windows) {
        BOOL protected = [window makeInvisibleToScreenRecording];
        if (!protected) {
            allProtected = NO;

            [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                         category:@"WindowProtection"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Failed to protect window: %@ (ID: %d) for PID: %d",
                                                 window.title, (int)window.windowID, pid];
        } else {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"WindowProtection"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Protected window: %@ (ID: %d) for PID: %d",
                                                 window.title, (int)window.windowID, pid];
        }
    }

    return allProtected;
}

@end
```

3. Implement periodic window scanning to ensure continuous protection:

```objc
// WCWindowScanner.h
@interface WCWindowScanner : NSObject

+ (instancetype)sharedScanner;

- (void)startScanningWithInterval:(NSTimeInterval)interval;
- (void)stopScanning;
- (BOOL)isScanning;

@end

// WCWindowScanner.m
@implementation WCWindowScanner {
    dispatch_source_t _timer;
    BOOL _isScanning;
}

+ (instancetype)sharedScanner {
    static WCWindowScanner *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _isScanning = NO;
        _timer = nil;
    }
    return self;
}

- (void)startScanningWithInterval:(NSTimeInterval)interval {
    if (_isScanning) return;

    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());

    uint64_t intervalNanoseconds = (uint64_t)(interval * NSEC_PER_SEC);
    dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, 0), intervalNanoseconds, intervalNanoseconds / 10);

    dispatch_source_set_event_handler(_timer, ^{
        [self scanAndProtectWindows];
    });

    dispatch_resume(_timer);
    _isScanning = YES;

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowScanner"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Started window scanning with interval: %.2f seconds", interval];
}

- (void)stopScanning {
    if (!_isScanning) return;

    if (_timer) {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }

    _isScanning = NO;

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowScanner"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Stopped window scanning"];
}

- (BOOL)isScanning {
    return _isScanning;
}

- (void)scanAndProtectWindows {
    @try {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:@"WindowScanner"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Scanning for windows to protect"];

        pid_t currentPID = getpid();
        [WCWindowBridge protectAllWindowsForPID:currentPID];
    } @catch (NSException *exception) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowScanner"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Exception during window scanning: %@", exception.reason];
    }
}

@end
```

### 3. Optimized DYLIB Injection

DYLIB injection will be refined to:

- Operate within target processes for direct window access.
- Support multi-process apps (e.g., Chrome) with improved stability.

#### Implementation Strategy:

1. Enhance the injection mechanism with targeted configuration:

```objc
// WCInjectorConfig.h
typedef NS_OPTIONS(NSUInteger, WCInjectionOptions) {
    WCInjectionOptionScreenRecordingProtection = 1 << 0,
    WCInjectionOptionDockIconHiding = 1 << 1,
    WCInjectionOptionAlwaysOnTop = 1 << 2,
    WCInjectionOptionChildProcessProtection = 1 << 3,
    WCInjectionOptionAll = 0xFFFFFFFF
};

@interface WCInjectorConfig : NSObject

@property (nonatomic) WCInjectionOptions options;
@property (nonatomic) NSTimeInterval scanInterval;
@property (nonatomic) BOOL protectChildProcesses;
@property (nonatomic) BOOL logVerbose;

+ (instancetype)defaultConfig;
- (NSDictionary *)asDictionary;
- (instancetype)initWithDictionary:(NSDictionary *)dict;

@end
```

2. Update the `WCInjector` class to handle multi-process targets:

```objc
// Updated method in WCInjector.m
+ (BOOL)injectIntoApplication:(NSString *)applicationPath
                      options:(WCInjectionOptions)options
                        error:(NSError **)error {
    if (!applicationPath) {
        if (error) {
            *error = [WCError errorWithCategory:WCErrorCategoryInjection
                                           code:WCErrorInvalidArguments
                                        message:@"Application path is required"];
        }
        return NO;
    }

    // Configure the injection
    WCInjectorConfig *config = [WCInjectorConfig defaultConfig];
    config.options = options;
    config.protectChildProcesses = (options & WCInjectionOptionChildProcessProtection) != 0;

    // Convert config to environment variables
    NSMutableDictionary *injectionEnv = [NSMutableDictionary dictionary];
    [injectionEnv addEntriesFromDictionary:[config asDictionary]];

    // Get dylib path
    NSString *dylibPath = [[WCPathResolver sharedResolver] resolvePathForDylib];
    if (!dylibPath) {
        if (error) {
            *error = [WCError errorWithCategory:WCErrorCategoryInjection
                                           code:WCErrorInjectionFailed
                                        message:@"Could not find WindowControlInjector dylib"];
        }
        return NO;
    }

    // Configure environment for injection
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:
                               [[NSProcessInfo processInfo] environment]];
    env[@"DYLD_INSERT_LIBRARIES"] = dylibPath;

    // Add configuration environment variables
    [env addEntriesFromDictionary:injectionEnv];

    // Launch application with our environment
    NSError *launchError = nil;
    BOOL success = [self launchApplicationWithPath:applicationPath
                                       environment:env
                                            error:&launchError];

    if (!success && error) {
        *error = launchError;
    }

    return success;
}
```

3. Implement process discovery for multi-process applications:

```objc
// In WCProcessMonitor.m (new class)
+ (NSArray<NSRunningApplication *> *)findChildApplicationsForBundleID:(NSString *)bundleID {
    NSMutableArray<NSRunningApplication *> *children = [NSMutableArray array];

    // Get the parent application
    NSArray<NSRunningApplication *> *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleID];
    if (apps.count == 0) return @[];

    NSRunningApplication *parentApp = apps[0];
    pid_t parentPID = parentApp.processIdentifier;

    // Get all running applications
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSArray<NSRunningApplication *> *runningApps = [workspace runningApplications];

    // Get child processes
    NSArray<pid_t> *childPIDs = [WCWindowBridge getChildProcessesForPID:parentPID];
    NSSet<NSNumber *> *childPIDSet = [NSSet setWithArray:[childPIDs valueForKey:@"self"]];

// Find matching applications
for (NSRunningApplication *app in runningApps) {
    if ([childPIDSet containsObject:@(app.processIdentifier)]) {
        [children addObject:app];

        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"ProcessDetection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Found child application: %@ (PID: %d) for parent: %@ (PID: %d)",
                                             app.localizedName, (int)app.processIdentifier,
                                             parentApp.localizedName, (int)parentPID];
    }
}

return [children copy];
}
```

## Implementation Details

### 1. Error Handling & Diagnostics

To ensure robust operation with undocumented CGS APIs, comprehensive error handling is essential:

```objc
// In WCError.h - Add CGS-specific error categories and codes
typedef NS_ENUM(NSInteger, WCErrorCGSCode) {
    WCErrorCGSCodeUnavailable = 1000,
    WCErrorCGSCodeConnectionFailed = 1001,
    WCErrorCGSCodeFunctionFailed = 1002,
    WCErrorCGSCodeWindowNotFound = 1003,
    WCErrorCGSCodeInvalidParameter = 1004
};

@interface WCError (CGS)
+ (instancetype)errorWithCGSCode:(WCErrorCGSCode)code
                         message:(NSString *)message
                     underlying:(NSError *)underlyingError;
@end
```

#### Diagnostic Logging for CGS Operations:

```objc
// In WCCGSFunctions.m
- (BOOL)performCGSOperation:(NSString *)operationName
                withWindowID:(CGWindowID)windowID
                   operation:(CGError (^)(CGSConnectionID cid, CGWindowID wid))operation {
    if (!_cgsDefaultConnection) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Cannot perform %@ - CGSDefaultConnection unavailable", operationName];
        return NO;
    }

    // Get connection
    CGSConnectionID cid = _cgsDefaultConnection();
    if (cid == 0) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to get CGS connection for %@", operationName];
        return NO;
    }

    // Perform operation with diagnostics
    CGError error = operation(cid, windowID);

    if (error) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"%@ failed with error %d for window ID %d",
                                             operationName, (int)error, (int)windowID];
        return NO;
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"CGS"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"%@ succeeded for window ID %d",
                                         operationName, (int)windowID];
    return YES;
}
```

#### Fallback Mechanism Implementation:

```objc
// In WCWindowProtector.m
+ (BOOL)protectWindowWithFallback:(id)window {
    // Track which methods were attempted and their results
    NSMutableDictionary *attempts = [NSMutableDictionary dictionary];
    BOOL success = NO;

    // 1. Try CGS API first if we have a window ID
    if ([window respondsToSelector:@selector(windowNumber)]) {
        CGWindowID windowID = [window windowNumber];
        BOOL cgsResult = [self protectWindowUsingCGS:windowID];
        attempts[@"CGS"] = @(cgsResult);
        success = cgsResult;
    }

    // 2. Try NSWindow API if that's available
    if (!success && [window respondsToSelector:@selector(setSharingType:)]) {
        [window setSharingType:NSWindowSharingNone];
        attempts[@"NSWindow"] = @YES;
        success = YES;
    }

    // 3. Try Core Animation API if available
    if (!success && [window respondsToSelector:@selector(layer)]) {
        id layer = [window layer];
        if ([layer respondsToSelector:@selector(setSharingProperties:)]) {
            [layer setSharingProperties:@{@"sharing": @NO}];
            attempts[@"CALayer"] = @YES;
            success = YES;
        }
    }

    // Log comprehensive diagnostics
    [[WCLogger sharedLogger] logWithLevel:(success ? WCLogLevelInfo : WCLogLevelWarning)
                                 category:@"WindowProtection"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Window protection %@: %@ - Methods tried: %@",
                                         success ? @"succeeded" : @"failed",
                                         window, attempts];

    return success;
}
```

### 2. Compatibility Verification

To ensure compatibility across different macOS versions and application types, we'll implement a robust verification system:

```objc
// In WCCompatibilityVerifier.h (new class)
@interface WCCompatibilityVerifier : NSObject

// Check if CGS functions are available on this system
+ (BOOL)isCGSAvailable;

// Test if a specific application can be protected using our methods
+ (BOOL)canProtectApplication:(NSString *)bundleID withOptions:(NSDictionary *)options;

// Get applications that are known to require special handling
+ (NSArray<NSString *> *)applicationsRequiringSpecialHandling;

// Check compatibility with current macOS version
+ (BOOL)isCompatibleWithCurrentOSVersion;

// Verify if special permissions are needed
+ (BOOL)requiresSpecialPermissions;

@end
```

#### Implementation of the verifier:

```objc
// In WCCompatibilityVerifier.m (partial implementation)
+ (BOOL)canProtectApplication:(NSString *)bundleID withOptions:(NSDictionary *)options {
    // Check if this is a known problematic app
    NSArray *problematicApps = @[
        @"com.google.Chrome",
        @"com.microsoft.VSCode",
        @"org.mozilla.firefox"
    ];

    BOOL isProblematicApp = [problematicApps containsObject:bundleID];
    BOOL hasCGS = [self isCGSAvailable];

    // If it's a known problematic app, we need CGS
    if (isProblematicApp && !hasCGS) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"Compatibility"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Application %@ requires CGS API which is unavailable",
                                             bundleID];
        return NO;
    }

    // For other apps, we can use AppKit fallback
    return YES;
}

+ (BOOL)isCompatibleWithCurrentOSVersion {
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];

    // Minimum version required is macOS 10.13 (High Sierra)
    BOOL compatible = (version.majorVersion > 10 ||
                      (version.majorVersion == 10 && version.minorVersion >= 13));

    if (!compatible) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Compatibility"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Incompatible macOS version: %ld.%ld.%ld - Requires 10.13+",
                                             (long)version.majorVersion,
                                             (long)version.minorVersion,
                                             (long)version.patchVersion];
    }

    return compatible;
}
```

### 3. Migration Path

To ensure a smooth transition from the old implementation to the new architecture, a phased migration approach will be used:

#### Phase 1: Parallel Implementation

```objc
// In WCWindowProtector.m
+ (BOOL)protectWindow:(id)window {
    // Check if we should use legacy or new implementation
    BOOL useLegacy = [[NSUserDefaults standardUserDefaults] boolForKey:@"WCUseLegacyProtection"];

    if (useLegacy) {
        // Call the legacy implementation
        return [self legacyProtectWindow:window];
    } else {
        // Use new implementation with fallback to legacy if needed
        BOOL success = [self newProtectWindow:window];

        if (!success) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                         category:@"Migration"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"New protection failed, falling back to legacy for window: %@", window];

            return [self legacyProtectWindow:window];
        }

        return success;
    }
}
```

#### Phase 2: Data Collection and Validation

Implement telemetry to measure effectiveness across different applications:

```objc
// In WCTelemetry.h (new class)
@interface WCTelemetry : NSObject

+ (instancetype)sharedInstance;

// Record success/failure of protection methods
- (void)recordProtectionAttempt:(NSString *)method
                      forWindow:(id)window
                        success:(BOOL)success;

// Get statistics
- (NSDictionary *)getStatistics;

// Reset statistics
- (void)resetStatistics;

@end
```

#### Phase 3: Transition Support

Provide a migration tool to help users transition:

```objc
// In WCMigrationAssistant.h (new class)
@interface WCMigrationAssistant : NSObject

// Check if migration is needed
+ (BOOL)isMigrationNeeded;

// Perform migration
+ (BOOL)migrateWithOptions:(NSDictionary *)options error:(NSError **)error;

// Get recommendations for specific applications
+ (NSArray<NSDictionary *> *)getRecommendationsForApplications:(NSArray<NSString *> *)bundleIDs;

@end
```

## Performance Considerations

The introduction of dual window detection and CGS APIs may impact performance. To mitigate this:

1. **Adaptive Scanning**: Adjust scanning frequency based on application activity and window count.

```objc
// In WCWindowScanner.m
- (void)adjustScanningInterval {
    // Get window count
    NSArray *windows = [WCWindowBridge getAllWindowsForCurrentApplication];
    NSUInteger windowCount = windows.count;

    // Adjust interval based on window count
    NSTimeInterval interval;
    if (windowCount < 5) {
        interval = 0.5; // More frequent for few windows
    } else if (windowCount < 20) {
        interval = 1.0; // Standard interval
    } else {
        interval = 2.0; // Less frequent for many windows
    }

    // Don't change if it's already the same
    if (interval == _currentInterval) return;

    // Update the interval
    _currentInterval = interval;
    [self stopScanning];
    [self startScanningWithInterval:interval];

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Performance"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Adjusted scanning interval to %.1f seconds for %lu windows",
                                         interval, (unsigned long)windowCount];
}
```

2. **Caching CGS Results**: Cache window information to reduce redundant API calls.

```objc
// In WCWindowCache.h (new class)
@interface WCWindowCache : NSObject

+ (instancetype)sharedCache;

// Cache window info
- (void)cacheWindowInfo:(WCWindowInfo *)windowInfo;

// Get cached window info
- (WCWindowInfo *)cachedInfoForWindowID:(CGWindowID)windowID;

// Invalidate cache
- (void)invalidateCache;

// Set cache TTL
- (void)setCacheTTL:(NSTimeInterval)ttl;

@end
```

3. **Optimized CGS Function Resolution**: Only resolve CGS functions when needed.

```objc
// In WCCGSFunctions.m
- (CGSSetWindowSharingStatePtr)CGSSetWindowSharingState {
    if (!_cgsSetWindowSharingState && !_triedToResolveSetWindowSharingState) {
        _triedToResolveSetWindowSharingState = YES;
        _cgsSetWindowSharingState = (CGSSetWindowSharingStatePtr)dlsym(_cgsHandle, "CGSSetWindowSharingState");

        if (_cgsSetWindowSharingState) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"CGS"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Successfully resolved CGSSetWindowSharingState on demand"];
        }
    }

    return _cgsSetWindowSharingState;
}
```

## Future Challenges and Considerations

### 1. Evolving macOS Security Model

As Apple continues to enhance the security model of macOS, we should anticipate potential challenges:

1. **SIP Enhancements**: System Integrity Protection may restrict access to certain system APIs in future macOS versions.

2. **API Deprecation**: AppKit APIs might be deprecated or their behavior changed.

3. **Permission Requirements**: Additional permissions might be required for window manipulation.

### 2. Multi-Process Application Support

Supporting applications with complex process architectures (like Electron apps) presents ongoing challenges:

1. **Process Monitoring**: Implementing efficient monitoring for child processes.

2. **IPC Communication**: Establishing reliable communication between parent and child processes.

3. **Selective Protection**: Allowing fine-grained control over which child windows to protect.

## Conclusion

The proposed refactoring of WindowControlInjector addresses the core limitation of the current implementation: its reliance on AppKit-specific mechanisms that fail with non-AppKit applications. By integrating the CGS API, implementing a dual-detection approach for windows, and modernizing the codebase, we can achieve universal window control across all application types.

The detailed implementation plan provides a clear path forward with concrete code examples, error handling strategies, and migration considerations. Key aspects include:

1. **Dynamic CGS Function Resolution**: Safely accessing undocumented APIs while handling potential changes.

2. **Unified Window Abstraction**: Creating a consistent interface for working with windows regardless of their underlying implementation.

3. **Robust Error Handling**: Implementing comprehensive diagnostics and fallback mechanisms.

4. **Performance Optimization**: Ensuring efficient operation through caching and adaptive scanning.

5. **Migration Support**: Providing a smooth transition path from the legacy implementation.

This refactoring will not only fix the immediate compatibility issues with applications like Chrome and Electron apps but also establish a more maintainable and future-proof architecture for WindowControlInjector.
