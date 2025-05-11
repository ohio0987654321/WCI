# WindowControlInjector Refactoring: Minimal CGS Implementation

## 1. Executive Summary

This document outlines a refactoring strategy for WindowControlInjector based on a Minimal CGS Implementation approach. While our analysis confirms that Core Graphics Services (CGS) private APIs remain necessary for comprehensive window protection, this proposal focuses on dramatically reducing implementation complexity by:

1. Using the absolute minimum CGS calls required
2. Implementing robust error handling and version compatibility
3. Creating a clear architectural separation between public and private API code
4. Focusing on core window protection while eliminating unnecessary complexity

This approach provides a pragmatic balance between technical requirements and maintainability, allowing us to overcome sandbox limitations and protect windows in complex applications like Chrome, Discord, and Steam without sacrificing long-term code stability.

## 2. Architecture Design

### 2.1 Core Design Principles

1. **Minimalism**: Use CGS private APIs only when absolutely necessary
2. **Isolation**: Isolate all private API calls in dedicated components
3. **Robustness**: Implement comprehensive error handling and fallbacks
4. **Adaptability**: Design for macOS version differences with runtime checks
5. **Simplicity**: Favor directness over abstraction when possible

### 2.2 Key Components

1. **Window Scanner**: Detects windows in target applications using public CGWindowList APIs
2. **Window Protector**: Applies minimal protection settings via focused CGS calls
3. **Dynamic Function Resolver**: Loads CGS functions at runtime with proper error handling
4. **Error Recovery System**: Handles CGS failures gracefully with appropriate fallbacks

### 2.3 Architectural Flow

```
┌─────────────────┐      ┌─────────────────┐     ┌───────────────────┐
│ Window Scanner  │──────▶ Protection Logic │────▶│ CGS Function Layer│
│ (Public API)    │      │ (Core Logic)     │     │ (Private API)     │
└─────────────────┘      └─────────────────┘     └───────────────────┘
        │                        │                         │
        │                        │                         │
        ▼                        ▼                         ▼
┌─────────────────┐      ┌─────────────────┐     ┌───────────────────┐
│ Window Tracking │      │ Error Handling  │     │ Version-Specific  │
│ (State Mgmt)    │      │ & Recovery      │     │ Adaptations       │
└─────────────────┘      └─────────────────┘     └───────────────────┘
```

## 3. Implementation Details

### 3.1 Window Scanner Module

The Window Scanner uses public APIs to efficiently detect windows belonging to target applications:

```objective-c
@interface WCWindowScanner : NSObject

- (void)startScanningWithInterval:(NSTimeInterval)interval;
- (void)stopScanning;
- (void)setTargetApplicationIdentifiers:(NSArray<NSString *> *)bundleIDs;

@end

@implementation WCWindowScanner {
    NSTimer *_scanTimer;
    NSArray<NSString *> *_targetBundleIDs;
    NSMutableSet *_discoveredWindowIDs;
    id<WCWindowScannerDelegate> _delegate;
}

- (void)startScanningWithInterval:(NSTimeInterval)interval {
    // Stop any existing timer
    [self stopScanning];

    // Create and start new scan timer
    _scanTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                 repeats:YES
                                                   block:^(NSTimer *timer) {
        [self scanForWindows];
    }];
}

- (void)scanForWindows {
    // Get all on-screen windows using public API
    CFArrayRef windowList = CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
        kCGNullWindowID);

    if (!windowList) return;

    for (id windowInfo in (__bridge NSArray *)windowList) {
        // Get window properties
        CGWindowID windowID = [windowInfo[(NSString *)kCGWindowNumber] unsignedIntValue];
        NSString *ownerName = windowInfo[(NSString *)kCGWindowOwnerName];

        // Check if this window belongs to a target application
        if ([self isTargetApplication:ownerName]) {
            // Notify delegate if this is a new window
            if (![_discoveredWindowIDs containsObject:@(windowID)]) {
                [_discoveredWindowIDs addObject:@(windowID)];
                [_delegate windowScanner:self didDiscoverWindow:windowID withInfo:windowInfo];
            }
        }
    }

    CFRelease(windowList);
}

- (BOOL)isTargetApplication:(NSString *)applicationName {
    if (!_targetBundleIDs || _targetBundleIDs.count == 0) {
        return YES; // If no targets specified, consider all applications
    }

    // Check if application matches any target
    for (NSString *bundleID in _targetBundleIDs) {
        if ([applicationName containsString:bundleID]) {
            return YES;
        }
    }

    return NO;
}

@end
```

### 3.2 CGS Function Resolution Layer

This critical layer dynamically resolves CGS functions at runtime, with comprehensive error handling:

```objective-c
@interface WCCGSFunctions : NSObject

// Public method to check if required functions are available
- (BOOL)areCGSFunctionsAvailable;

// CGS function wrappers with safety checks
- (BOOL)setWindowSharingNone:(CGWindowID)windowID;
- (BOOL)setWindowLevel:(CGWindowID)windowID level:(int)level;
- (BOOL)orderWindow:(CGWindowID)windowID order:(int)order;

@end

@implementation WCCGSFunctions {
    BOOL _functionsResolved;

    // Function pointers for dynamically resolved CGS functions
    CGError (*_CGSSetWindowSharingState)(CGSConnectionID, CGWindowID, CGSWindowSharingType);
    CGError (*_CGSSetWindowLevel)(CGSConnectionID, CGWindowID, int);
    CGError (*_CGSOrderWindow)(CGSConnectionID, CGWindowID, CGSWindowOrderingMode, CGWindowID);
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
    _CGSOrderWindow = dlsym(cgFramework, "CGSOrderWindow");

    // Check if critical functions are available
    if (!_CGSSetWindowSharingState) {
        NSLog(@"WARNING: CGSSetWindowSharingState function not available");
        return NO;
    }

    return YES;
}

- (BOOL)areCGSFunctionsAvailable {
    return _functionsResolved;
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

- (BOOL)orderWindow:(CGWindowID)windowID order:(int)order {
    if (!_functionsResolved || !_CGSOrderWindow) {
        return NO;
    }

    CGSConnectionID cid = CGSMainConnectionID();
    CGError error = _CGSOrderWindow(cid, windowID, order, 0);

    if (error != kCGErrorSuccess) {
        NSLog(@"ERROR: Failed to order window %u (error: %d)", windowID, error);
        return NO;
    }

    return YES;
}

@end
```

### 3.3 Window Protector Core

The Window Protector ties everything together with minimal complexity:

```objective-c
@interface WCWindowProtector : NSObject <WCWindowScannerDelegate>

- (instancetype)init;
- (void)startProtection;
- (void)stopProtection;
- (void)setTargetApplications:(NSArray<NSString *> *)bundleIDs;

@end

@implementation WCWindowProtector {
    WCWindowScanner *_scanner;
    WCCGSFunctions *_cgsFunctions;
    NSMutableSet *_protectedWindowIDs;
}

- (instancetype)init {
    if (self = [super init]) {
        // Initialize components
        _scanner = [[WCWindowScanner alloc] init];
        _scanner.delegate = self;

        _cgsFunctions = [[WCCGSFunctions alloc] init];
        _protectedWindowIDs = [NSMutableSet set];

        // Log availability status
        NSLog(@"Window Protector initialized. CGS functions available: %@",
              [_cgsFunctions areCGSFunctionsAvailable] ? @"YES" : @"NO");
    }
    return self;
}

- (void)startProtection {
    [_scanner startScanningWithInterval:0.5];
}

- (void)stopProtection {
    [_scanner stopScanning];
}

- (void)setTargetApplications:(NSArray<NSString *> *)bundleIDs {
    [_scanner setTargetApplicationIdentifiers:bundleIDs];
}

#pragma mark - Window Scanner Delegate

- (void)windowScanner:(WCWindowScanner *)scanner didDiscoverWindow:(CGWindowID)windowID withInfo:(NSDictionary *)windowInfo {
    // Check if we've already protected this window
    if ([_protectedWindowIDs containsObject:@(windowID)]) {
        return;
    }

    // Apply protection to the window
    BOOL success = [self protectWindow:windowID withInfo:windowInfo];

    if (success) {
        [_protectedWindowIDs addObject:@(windowID)];
        NSLog(@"Successfully protected window %u", windowID);
    }
}

- (BOOL)protectWindow:(CGWindowID)windowID withInfo:(NSDictionary *)windowInfo {
    // Focused approach: only use minimum necessary private APIs
    BOOL success = YES;

    // 1. Set window sharing to None (critical for screen recording protection)
    success = success && [_cgsFunctions setWindowSharingNone:windowID];

    // 2. Set window level (optional feature - only if critical)
    BOOL needsWindowLevel = [self windowRequiresCustomLevel:windowInfo];
    if (needsWindowLevel) {
        success = success && [_cgsFunctions setWindowLevel:windowID level:CGWindowLevelForKey(kCGFloatingWindowLevelKey)];
    }

    return success;
}

- (BOOL)windowRequiresCustomLevel:(NSDictionary *)windowInfo {
    // Logic to determine if window needs custom level based on application/window type
    // This makes the feature optional and focused only where needed
    NSString *ownerName = windowInfo[(NSString *)kCGWindowOwnerName];
    if ([ownerName containsString:@"Chrome"] ||
        [ownerName containsString:@"Discord"] ||
        [ownerName containsString:@"Steam"]) {
        return YES;
    }

    return NO;
}

@end
```

### 3.4 macOS Version Adaptations

To handle macOS version differences, we use runtime detection:

```objective-c
@interface WCVersionAdapter : NSObject

+ (BOOL)isAtLeastMacOS:(NSInteger)majorVersion minor:(NSInteger)minorVersion;
+ (BOOL)shouldUseCGSDirectMethodForMacOSVersion;
+ (BOOL)supportsModernWindowSharingAPI;

@end

@implementation WCVersionAdapter

+ (BOOL)isAtLeastMacOS:(NSInteger)majorVersion minor:(NSInteger)minorVersion {
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];

    if (version.majorVersion > majorVersion) {
        return YES;
    }

    if (version.majorVersion == majorVersion && version.minorVersion >= minorVersion) {
        return YES;
    }

    return NO;
}

+ (BOOL)shouldUseCGSDirectMethodForMacOSVersion {
    // Different strategies for different macOS versions
    if ([self isAtLeastMacOS:12 minor:0]) { // macOS Monterey and later
        return YES;
    } else if ([self isAtLeastMacOS:11 minor:0]) { // macOS Big Sur
        return YES;
    } else {
        return NO; // Older versions use different approach
    }
}

+ (BOOL)supportsModernWindowSharingAPI {
    return [self isAtLeastMacOS:10 minor:15]; // macOS Catalina and later
}

@end
```

## 4. Main API

The main API exposes a focused, simple interface while hiding implementation complexity:

```objective-c
@interface WindowControlInjector : NSObject

// Simple public API focused on core functionality
+ (instancetype)sharedInstance;

// Start protection with default settings
- (void)startProtection;

// Start protection with custom settings
- (void)startProtectionWithOptions:(NSDictionary *)options;

// Stop all protection
- (void)stopProtection;

// Check if protection is active
- (BOOL)isProtectionActive;

// Check if all protection features are available on this system
- (BOOL)areAllFeaturesAvailable;

@end

@implementation WindowControlInjector {
    WCWindowProtector *_protector;
    BOOL _protectionActive;
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
        _protector = [[WCWindowProtector alloc] init];
        _protectionActive = NO;
    }
    return self;
}

- (void)startProtection {
    [self startProtectionWithOptions:nil];
}

- (void)startProtectionWithOptions:(NSDictionary *)options {
    if (_protectionActive) {
        [self stopProtection];
    }

    // Configure with options if provided
    if (options) {
        NSArray *targetApps = options[@"targetApplications"];
        if (targetApps) {
            [_protector setTargetApplications:targetApps];
        }
    }

    [_protector startProtection];
    _protectionActive = YES;
}

- (void)stopProtection {
    if (_protectionActive) {
        [_protector stopProtection];
        _protectionActive = NO;
    }
}

- (BOOL)isProtectionActive {
    return _protectionActive;
}

- (BOOL)areAllFeaturesAvailable {
    WCCGSFunctions *functions = [[WCCGSFunctions alloc] init];
    return [functions areCGSFunctionsAvailable];
}

@end
```

## 5. Migration Strategy

### 5.1 Implementation Phases

1. **Phase 1: Core Public API Migration**
   - Implement the Window Scanner using public CGWindowList APIs
   - Create simplified interfaces for main functionality
   - Remove unused or redundant code from current implementation

2. **Phase 2: CGS Function Layer Implementation**
   - Create CGS function resolution layer with dynamic loading
   - Implement error handling and version detection
   - Develop minimal set of CGS wrappers

3. **Phase 3: Window Protection Logic**
   - Implement focused window protection method
   - Add version-specific adaptations
   - Create robust error recovery

### 5.2 Compatibility Considerations

During migration, ensure:

1. Public API compatibility for existing integrations
2. Backward compatibility with earlier macOS versions
3. Proper handling of the transition from the old to new implementation
4. Clear documentation of deprecated functions and their replacements

## 6. Maintenance Considerations

### 6.1 Error Handling Guidelines

1. All CGS function calls should include proper error checking
2. Log detailed error information for debugging
3. Implement fallbacks when CGS functions fail
4. Use runtime checks for function availability

### 6.2 Version Adaptation Strategy

1. Use the WCVersionAdapter for macOS version detection
2. Isolate version-specific code in clearly marked sections
3. Implement feature detection rather than version checking where possible
4. Document macOS version compatibility for each feature

### 6.3 Error Logging Framework

1. Implement focused error logging for critical failures
2. Add minimal diagnostic information for maintenance
3. Document common error patterns and their meaning

## 7. Conclusion

The Minimal CGS Implementation approach provides a pragmatic balance between functionality and maintainability. By focusing on the absolute minimum private API usage necessary, implementing robust error handling, and creating clear architectural boundaries, we can achieve the core technical requirements while significantly reducing maintenance complexity.

This refactoring strategy will result in a more resilient, maintainable codebase that can better withstand macOS updates while still providing the critical functionality needed to protect windows in complex applications like Chrome, Discord, and Steam.
