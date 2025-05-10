# WindowControlInjector Refactoring Plan

This document outlines comprehensive refactoring opportunities for the WindowControlInjector project, with implementation details and benefits for each.

## 1. Simplify Configuration System

### Current Approach
Currently, configuration is passed to the injected app using environment variables:

```objective-c
// Set up environment variables for the new process
NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
env[@"DYLD_INSERT_LIBRARIES"] = dylibPath;
// Other settings passed via environment
```

### Proposed Approach
Replace with a JSON configuration file approach:

```objective-c
// Create configuration object
WCConfiguration *config = [WCConfiguration defaultConfiguration];
config.interceptors = @[@"window", @"application"];
config.windowLevel = NSFloatingWindowLevel;
config.applicationActivationPolicy = NSApplicationActivationPolicyAccessory;

// Save to temporary file
NSString *configPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"wci_config.json"];
[config saveToFile:configPath];

// Pass just the config file path via environment
env[@"WCI_CONFIG_PATH"] = configPath;
```

### Benefits
- More structured configuration
- Easier to extend with new settings
- Better type safety than string-based environment variables
- Configuration can be inspected, saved, and reused

### Implementation Steps
1. Create a `WCConfiguration` class with all configurable properties
2. Add serialization/deserialization to/from JSON
3. Update launch process to pass config file path
4. Update injected dylib to read from config file on startup

## 2. Better Error Handling Strategy

### Current Approach
Mixed error handling with some codes but limited structure:

```objective-c
*error = [NSError errorWithDomain:WCProtectorErrorDomain
                            code:101
                        userInfo:@{NSLocalizedDescriptionKey: @"Application not found at path"}];
```

### Proposed Approach
Implement a comprehensive error handling framework:

```objective-c
// Define error categories and codes
typedef NS_ENUM(NSInteger, WCErrorCategory) {
    WCErrorCategoryLaunch = 1000,
    WCErrorCategoryInjection = 2000,
    WCErrorCategoryConfiguration = 3000,
    WCErrorCategoryInterception = 4000
};

// Example usage
*error = [WCError errorWithCategory:WCErrorCategoryLaunch
                               code:WCLaunchErrorApplicationNotFound
                            message:@"Application not found at path"
                            details:@{@"path": applicationPath}
                          suggestion:@"Verify the application path is correct"];
```

### Benefits
- Categorized errors make debugging easier
- More detailed error information
- Consistent error format across the application
- Suggestions for resolving errors

### Implementation Steps
1. Create a `WCError` class extending NSError
2. Define error categories and codes
3. Add helper methods for creating errors
4. Replace existing error creation with new system
5. Add detailed documentation for each error type

## 3. Interceptor Registration System

### Current Approach
Interceptors are hard-coded in initialization:

```objective-c
+ (BOOL)initialize {
    // Install interceptors
    BOOL success = [WCNSWindowInterceptor install];
    success &= [WCNSApplicationInterceptor install];
    // ...
}
```

### Proposed Approach
Create a registration system for interceptors:

```objective-c
// In interceptor base class or protocol
+ (void)registerInterceptor {
    [[WCInterceptorRegistry sharedRegistry] registerInterceptor:self];
}

// In each interceptor implementation
+ (void)load {
    [self registerInterceptor];
}

// In initialization
+ (BOOL)initialize {
    return [[WCInterceptorRegistry sharedRegistry] installAllInterceptors];
}
```

### Benefits
- New interceptors can be added without modifying existing code
- Interceptors can be enabled/disabled selectively
- Better organization of interceptor management
- Easier testing by mocking the registry

### Implementation Steps
1. Create `WCInterceptorRegistry` class
2. Define `WCInterceptor` protocol with required methods
3. Update existing interceptors to conform to protocol
4. Implement registration mechanism
5. Update initialization to use registry

## 4. Reduce Global State

### Current Approach
Extensive use of global variables in interceptors:

```objective-c
// Store original method implementations
static IMP gOriginalSharingTypeIMP = NULL;
static IMP gOriginalSetSharingTypeIMP = NULL;
// ... many more globals

// Global flags
static BOOL gInstalled = NO;
static dispatch_source_t gWindowPropertyRefreshTimer = nil;
```

### Proposed Approach
Encapsulate state in static instances with property storage:

```objective-c
@implementation WCNSWindowInterceptor {
    NSMutableDictionary<NSString *, NSValue *> *_originalImplementations;
    dispatch_source_t _propertyRefreshTimer;
}

+ (instancetype)sharedInterceptor {
    static WCNSWindowInterceptor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _originalImplementations = [NSMutableDictionary dictionary];
        _installed = NO;
    }
    return self;
}

- (void)storeOriginalIMP:(IMP)imp forSelector:(SEL)selector {
    _originalImplementations[NSStringFromSelector(selector)] = [NSValue valueWithPointer:imp];
}

- (IMP)originalIMPForSelector:(SEL)selector {
    return [_originalImplementations[NSStringFromSelector(selector)] pointerValue];
}
```

### Benefits
- Better encapsulation of state
- Reduced risk of name collisions
- Clearer ownership of resources
- Easier cleanup and memory management

### Implementation Steps
1. Refactor interceptors to use singleton instances
2. Create property storage for original implementations
3. Add accessor methods for stored state
4. Update method swizzling to use new storage
5. Ensure proper cleanup in dealloc methods

## 5. Modernize Method Swizzling

### Current Approach
Direct swizzling with some helper functions:

```objective-c
WCAddMethod(nsWindowClass, @selector(wc_sharingType), (IMP)wc_sharingType, "Q@:");
BOOL swizzleResult = WCSwizzleMethod(nsWindowClass, origSel, newSel);
```

### Proposed Approach
Create a more robust swizzling system:

```objective-c
@interface WCMethodSwizzler : NSObject

+ (BOOL)swizzleClass:(Class)cls
      originalSelector:(SEL)origSel
     replacementSelector:(SEL)replacementSel
      implementationType:(WCImplementationType)type;

+ (BOOL)addMethodToClass:(Class)cls
                selector:(SEL)sel
           implementation:(IMP)implementation
                typeEncoding:(const char *)typeEncoding;

+ (void)unswizzleClass:(Class)cls
       originalSelector:(SEL)origSel
    replacementSelector:(SEL)replacementSel;

@end

// Example usage
[WCMethodSwizzler swizzleClass:[NSWindow class]
             originalSelector:@selector(sharingType)
         replacementSelector:@selector(wc_sharingType)
         implementationType:WCImplementationTypeProperty];
```

### Benefits
- Better error checking and reporting during swizzling
- More consistent swizzling behavior
- Support for different types of swizzling (method, property, etc.)
- Easier unswizzling for cleanup

### Implementation Steps
1. Create `WCMethodSwizzler` class
2. Implement core swizzling functionality with safety checks
3. Add support for different swizzling strategies
4. Add unswizzling support
5. Update interceptors to use new API

## 6. Interceptor Manager Class

### Current Approach
Installation of interceptors is handled individually:

```objective-c
+ (BOOL)initialize {
    BOOL success = [WCNSWindowInterceptor install];
    success &= [WCNSApplicationInterceptor install];
    // ...
}
```

### Proposed Approach
Create a dedicated manager class:

```objective-c
@interface WCInterceptorManager : NSObject

+ (instancetype)sharedManager;

- (BOOL)installInterceptorsWithOptions:(WCInterceptorOptions)options;
- (BOOL)uninstallAllInterceptors;
- (BOOL)installInterceptorWithClass:(Class)interceptorClass;
- (BOOL)uninstallInterceptorWithClass:(Class)interceptorClass;
- (NSArray<Class> *)installedInterceptors;
- (BOOL)isInterceptorInstalled:(Class)interceptorClass;

@end

// Usage
[[WCInterceptorManager sharedManager] installInterceptorsWithOptions:WCInterceptorOptionWindow | WCInterceptorOptionApplication];
```

### Benefits
- Centralized management of interceptors
- Ability to selectively enable/disable interceptors
- Better tracking of installed interceptors
- Simplified initialization and cleanup

### Implementation Steps
1. Create `WCInterceptorManager` class
2. Define interceptor options and configuration
3. Implement installation and uninstallation methods
4. Add tracking of installed interceptors
5. Update initialization to use manager

## 7. Centralized Configuration

### Current Approach
Configuration is scattered across multiple files:

```objective-c
// In window interceptor
static NSWindowLevel wc_level(id self, SEL _cmd) {
    return NSFloatingWindowLevel;
}

// In application interceptor
static NSApplicationActivationPolicy wc_activationPolicy(id self, SEL _cmd) {
    return NSApplicationActivationPolicyAccessory;
}
```

### Proposed Approach
Consolidate all configuration in a central class:

```objective-c
@interface WCConfigurationManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, assign) NSWindowLevel windowLevel;
@property (nonatomic, assign) NSWindowSharingType windowSharingType;
@property (nonatomic, assign) NSApplicationActivationPolicy applicationActivationPolicy;
@property (nonatomic, assign) NSApplicationPresentationOptions presentationOptions;
@property (nonatomic, assign) BOOL windowIgnoresMouseEvents;
@property (nonatomic, assign) BOOL windowCanBecomeKey;
// ... other configuration options

- (void)loadConfigurationFromEnvironment;
- (void)loadConfigurationFromFile:(NSString *)path;
- (void)resetToDefaults;

@end

// Usage in interceptors
static NSWindowLevel wc_level(id self, SEL _cmd) {
    return [[WCConfigurationManager sharedManager] windowLevel];
}
```

### Benefits
- Single source of truth for configuration
- Easier to update configuration options
- Configuration can be changed at runtime
- Better defaults management
- Simplified testing with configuration overrides

### Implementation Steps
1. Create `WCConfigurationManager` class
2. Define all configurable properties
3. Implement loading from environment/file
4. Update interceptors to use manager
5. Add support for dynamic configuration changes

## 8. Enhanced Logging System

### Current Approach
Basic logging with severity levels:

```objective-c
WCLogInfo(@"Applying protection to application: %@", applicationPath);
printf("[WindowControlInjector] Using dylib: %s\n", [dylibPath UTF8String]);
```

### Proposed Approach
Create a more robust logging system:

```objective-c
@interface WCLogger : NSObject

+ (instancetype)sharedLogger;

- (void)logWithLevel:(WCLogLevel)level
            category:(NSString *)category
              format:(NSString *)format, ... NS_FORMAT_FUNCTION(3,4);

- (void)setLogLevel:(WCLogLevel)level;
- (void)setLogEnabled:(BOOL)enabled forCategory:(NSString *)category;
- (void)setLogHandler:(void (^)(WCLogMessage *message))handler;
- (void)setLogFilePath:(NSString *)path;

@end

// Convenience macros
#define WCLogDebug(category, ...) [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug category:category format:__VA_ARGS__]
#define WCLogInfo(category, ...) [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo category:category format:__VA_ARGS__]

// Usage
WCLogInfo(@"Launch", @"Applying protection to application: %@", applicationPath);
WCLogDebug(@"Injection", @"Using dylib: %@", dylibPath);
```

### Benefits
- Categorized logging for better filtering
- Support for log handlers (file, console, custom)
- Selective enabling/disabling of log categories
- Better formatting and timestamp support
- More contextual information in logs

### Implementation Steps
1. Create enhanced `WCLogger` class
2. Define log levels and categories
3. Implement log filtering and handling
4. Add file logging support
5. Create convenience macros
6. Update code to use new logging system

## 9. Improved Dylib Path Resolution

### Current Approach
Complex path resolution spread across code:

```objective-c
+ (NSString *)findInjectorDylibPath {
    // ... many lines of path checking logic
    NSArray *possiblePaths = @[
        [executableDir stringByAppendingPathComponent:@"libwindowcontrolinjector.dylib"],
        // ... many more paths
    ];

    // ... additional resolution logic
}
```

### Proposed Approach
Create a dedicated path resolver:

```objective-c
@interface WCPathResolver : NSObject

+ (instancetype)sharedResolver;

- (NSString *)resolvePathForDylib;
- (NSString *)resolveExecutablePathForApplication:(NSString *)applicationPath;
- (void)setCustomDylibPath:(NSString *)path;
- (NSArray<NSString *> *)searchPaths;
- (void)addSearchPath:(NSString *)path;

@end

// Usage
NSString *dylibPath = [[WCPathResolver sharedResolver] resolvePathForDylib];
```

### Benefits
- Centralized path resolution logic
- Customizable search paths
- Better caching of resolved paths
- Improved error reporting for path issues
- Support for custom path overrides

### Implementation Steps
1. Create `WCPathResolver` class
2. Extract and consolidate path resolution logic
3. Implement configurable search paths
4. Add caching for performance
5. Improve error handling for path resolution
6. Update code to use new resolver

## Implementation Strategy

### Recommended Order
1. Enhanced Logging System (#8) - Start here to improve debugging during other refactorings
2. Better Error Handling Strategy (#2) - Implement early to catch issues in other refactorings
3. Reduce Global State (#4) - Fundamental structural improvement
4. Modernize Method Swizzling (#5) - Core functionality improvement
5. Centralized Configuration (#7) - Prerequisite for configuration system
6. Simplify Configuration System (#1) - Builds on centralized configuration
7. Path Resolver (#9) - Standalone improvement
8. Interceptor Registration System (#3) - Foundation for manager
9. Interceptor Manager Class (#6) - Final integration

### Incremental Approach
Each refactoring should be implemented separately, ensuring existing functionality continues to work. This allows for incremental improvements without breaking the application.

### Validation Approach
- Implement one refactoring at a time
- Verify that the application still functions as expected after each change
- Keep backup points of working code versions
