/**
 * @file nsapplication_interceptor.m
 * @brief Implementation of the NSApplication interceptor
 */

#import "nsapplication_interceptor.h"
#import "../util/logger.h"
#import "../util/method_swizzler.h"
#import "../util/error_manager.h"
#import "interceptor_registry.h"
#import "nswindow_interceptor.h"
#import <mach/mach_time.h>  // For mach_absolute_time()
#import <os/lock.h>  // For os_unfair_lock

// Forward declarations of swizzled method implementations
static NSApplicationActivationPolicy wc_activationPolicy(id self, SEL _cmd);
static BOOL wc_setActivationPolicy(id self, SEL _cmd, NSApplicationActivationPolicy activationPolicy);
static NSApplicationPresentationOptions wc_presentationOptions(id self, SEL _cmd);
static void wc_setPresentationOptions(id self, SEL _cmd, NSApplicationPresentationOptions presentationOptions);
static BOOL wc_isHidden(id self, SEL _cmd);
static void wc_setHidden(id self, SEL _cmd, BOOL hidden);
static BOOL wc_isActive(id self, SEL _cmd);
static void wc_activateIgnoringOtherApps(id self, SEL _cmd, BOOL flag);
static void wc_orderFrontStandardAboutPanel(id self, SEL _cmd, id sender);
static void wc_hide(id self, SEL _cmd, id sender);
static void wc_unhide(id self, SEL _cmd, id sender);
static void wc_becomeActiveApplication(id self, SEL _cmd);

// Application state tracking
static BOOL gAppFullyLoaded = NO;
static os_unfair_lock gAppSettingsLock = OS_UNFAIR_LOCK_INIT;
static uint64_t gLastSettingsTime = 0;

@implementation WCNSApplicationInterceptor {
    // Private instance variables
    BOOL _installed;
    dispatch_source_t _appSettingsRefreshTimer;
}

#pragma mark - Class Load and Registration

+ (void)load {
    // Automatically register with the registry at load time
    [self registerInterceptor];
}

+ (void)registerInterceptor {
    // Register this interceptor with the registry
    WCInterceptorRegistry *registry = [WCInterceptorRegistry sharedRegistry];
    [registry registerInterceptor:self];

    // Map to the application interceptor option
    [registry mapInterceptor:self toOption:WCInterceptorOptionApplication];

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Interception"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"NSApplication interceptor registered with registry"];
}

#pragma mark - WCInterceptor Protocol

+ (NSString *)interceptorName {
    return @"NSApplicationInterceptor";
}

+ (NSString *)interceptorDescription {
    return @"Intercepts NSApplication methods to control application behavior, prevent focus stealing, and hide from Dock";
}

+ (NSInteger)priority {
    // Higher priority than window interceptor - app settings should be applied first
    return 100;
}

+ (NSArray<Class> *)dependencies {
    // Depends on the window interceptor
    return @[[WCNSWindowInterceptor class]];
}

#pragma mark - Initialization and Singleton Pattern

+ (instancetype)sharedInterceptor {
    static WCNSApplicationInterceptor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _installed = NO;
        _appSettingsRefreshTimer = nil;
    }
    return self;
}

#pragma mark - Installation and Uninstallation

+ (BOOL)install {
    return [[self sharedInterceptor] installInterceptor];
}

+ (BOOL)uninstall {
    return [[self sharedInterceptor] uninstallInterceptor];
}

+ (BOOL)isInstalled {
    return [[self sharedInterceptor] isInterceptorInstalled];
}

- (BOOL)isInterceptorInstalled {
    return _installed;
}

- (BOOL)installInterceptor {
    // Don't install more than once
    if (_installed) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"NSApplication interceptor already installed"];
        return YES;
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Interception"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Installing NSApplication interceptor"];

    BOOL success = YES;
    Class nsApplicationClass = [NSApplication class];

    // Apply settings immediately to NSApp
    [self applyProtectionsToApplication];

    // Set up a timer to periodically refresh application settings
    if (_appSettingsRefreshTimer == nil) {
        // Create timer on a separate high-priority queue to avoid main thread delays
        dispatch_queue_t timerQueue = dispatch_queue_create("com.windowcontrolinjector.appTimer",
                                                          DISPATCH_QUEUE_SERIAL);

        _appSettingsRefreshTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                                       0, 0, timerQueue);
        if (_appSettingsRefreshTimer) {
            // Apply settings every 1 second to ensure they stay applied
            dispatch_source_set_timer(_appSettingsRefreshTimer,
                                   dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
                                   1 * NSEC_PER_SEC,
                                   0.1 * NSEC_PER_SEC);

            dispatch_source_set_event_handler(_appSettingsRefreshTimer, ^{
                @autoreleasepool {
                    // Run on main thread to safely interact with UI classes
                    dispatch_async(dispatch_get_main_queue(), ^{
                        @try {
                            NSApplication *app = [NSApplication sharedApplication];
                            if (app) {
                                [self applyProtectionsToApplication];
                            }
                        } @catch (NSException *exception) {
                            [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                                        category:@"Application"
                                                            file:__FILE__
                                                            line:__LINE__
                                                        function:__PRETTY_FUNCTION__
                                                          format:@"Exception in timer handler: %@", exception.reason];
                        }
                    });
                }
            });

            // Handle cancellation to prevent crashes
            dispatch_source_set_cancel_handler(_appSettingsRefreshTimer, ^{
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                            category:@"Application"
                                                file:__FILE__
                                                line:__LINE__
                                            function:__PRETTY_FUNCTION__
                                              format:@"Application settings refresh timer cancelled"];
            });

            dispatch_resume(_appSettingsRefreshTimer);
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                        category:@"Application"
                                            file:__FILE__
                                            line:__LINE__
                                        function:__PRETTY_FUNCTION__
                                          format:@"Started application settings refresh timer"];
        }
    }

    // Register our swizzled method implementations using the method swizzler

    // First, we need to add our custom implementations
    const char *activationPolicyType = "i@:";
    const char *setActivationPolicyType = "B@:i";
    const char *presentationOptionsType = "Q@:";
    const char *setPresentationOptionsType = "v@:Q";
    const char *boolType = "B@:";
    const char *setBoolType = "v@:B";
    const char *voidType = "v@:";
    const char *voidWithSenderType = "v@:@";

    // Add methods with prefix "wc_" to the NSApplication class
    [WCMethodSwizzler addMethodToClass:nsApplicationClass
                              selector:@selector(wc_activationPolicy)
                         implementation:(IMP)wc_activationPolicy
                          typeEncoding:activationPolicyType];

    [WCMethodSwizzler addMethodToClass:nsApplicationClass
                              selector:@selector(wc_setActivationPolicy:)
                         implementation:(IMP)wc_setActivationPolicy
                          typeEncoding:setActivationPolicyType];

    [WCMethodSwizzler addMethodToClass:nsApplicationClass
                              selector:@selector(wc_presentationOptions)
                         implementation:(IMP)wc_presentationOptions
                          typeEncoding:presentationOptionsType];

    [WCMethodSwizzler addMethodToClass:nsApplicationClass
                              selector:@selector(wc_setPresentationOptions:)
                         implementation:(IMP)wc_setPresentationOptions
                          typeEncoding:setPresentationOptionsType];

    [WCMethodSwizzler addMethodToClass:nsApplicationClass
                              selector:@selector(wc_isHidden)
                         implementation:(IMP)wc_isHidden
                          typeEncoding:boolType];

    [WCMethodSwizzler addMethodToClass:nsApplicationClass
                              selector:@selector(wc_setHidden:)
                         implementation:(IMP)wc_setHidden
                          typeEncoding:setBoolType];

    [WCMethodSwizzler addMethodToClass:nsApplicationClass
                              selector:@selector(wc_isActive)
                         implementation:(IMP)wc_isActive
                          typeEncoding:boolType];

    [WCMethodSwizzler addMethodToClass:nsApplicationClass
                              selector:@selector(wc_activateIgnoringOtherApps:)
                         implementation:(IMP)wc_activateIgnoringOtherApps
                          typeEncoding:setBoolType];

    [WCMethodSwizzler addMethodToClass:nsApplicationClass
                              selector:@selector(wc_orderFrontStandardAboutPanel:)
                         implementation:(IMP)wc_orderFrontStandardAboutPanel
                          typeEncoding:voidWithSenderType];

    [WCMethodSwizzler addMethodToClass:nsApplicationClass
                              selector:@selector(wc_hide:)
                         implementation:(IMP)wc_hide
                          typeEncoding:voidWithSenderType];

    [WCMethodSwizzler addMethodToClass:nsApplicationClass
                              selector:@selector(wc_unhide:)
                         implementation:(IMP)wc_unhide
                          typeEncoding:voidWithSenderType];

    [WCMethodSwizzler addMethodToClass:nsApplicationClass
                              selector:@selector(wc_becomeActiveApplication)
                         implementation:(IMP)wc_becomeActiveApplication
                          typeEncoding:voidType];

    // Then swizzle the original methods with our custom implementations

    // Helper macro to safely swizzle methods only if they exist
    #define SAFE_SWIZZLE(origSel, newSel, type) \
        if ([WCMethodSwizzler class:nsApplicationClass implementsSelector:origSel ofType:type]) { \
            if (![WCMethodSwizzler swizzleClass:nsApplicationClass \
                                originalSelector:origSel \
                             replacementSelector:newSel \
                              implementationType:type]) { \
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning \
                                             category:@"Interception" \
                                                 file:__FILE__ \
                                                 line:__LINE__ \
                                             function:__PRETTY_FUNCTION__ \
                                               format:@"Failed to swizzle %@ in NSApplication", NSStringFromSelector(origSel)]; \
                success = NO; \
            } else { \
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug \
                                             category:@"Interception" \
                                                 file:__FILE__ \
                                                 line:__LINE__ \
                                             function:__PRETTY_FUNCTION__ \
                                               format:@"Successfully swizzled %@ in NSApplication", NSStringFromSelector(origSel)]; \
            } \
        } else { \
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo \
                                         category:@"Interception" \
                                             file:__FILE__ \
                                             line:__LINE__ \
                                         function:__PRETTY_FUNCTION__ \
                                           format:@"Method %@ not found in NSApplication, skipping swizzle", NSStringFromSelector(origSel)]; \
        }

    // Swizzle methods that exist
    SAFE_SWIZZLE(@selector(activationPolicy), @selector(wc_activationPolicy), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(setActivationPolicy:), @selector(wc_setActivationPolicy:), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(presentationOptions), @selector(wc_presentationOptions), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(setPresentationOptions:), @selector(wc_setPresentationOptions:), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(isHidden), @selector(wc_isHidden), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(setHidden:), @selector(wc_setHidden:), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(isActive), @selector(wc_isActive), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(activateIgnoringOtherApps:), @selector(wc_activateIgnoringOtherApps:), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(orderFrontStandardAboutPanel:), @selector(wc_orderFrontStandardAboutPanel:), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(hide:), @selector(wc_hide:), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(unhide:), @selector(wc_unhide:), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(becomeActiveApplication), @selector(wc_becomeActiveApplication), WCImplementationTypeMethod);

    #undef SAFE_SWIZZLE

    if (success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"NSApplication interceptor installed successfully"];
        _installed = YES;
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to install NSApplication interceptor"];
    }

    return success;
}

- (BOOL)uninstallInterceptor {
    if (!_installed) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"NSApplication interceptor not installed, nothing to uninstall"];
        return YES;
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Interception"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Uninstalling NSApplication interceptor"];

    // Stop the timer if it's running
    if (_appSettingsRefreshTimer) {
        dispatch_source_cancel(_appSettingsRefreshTimer);
        _appSettingsRefreshTimer = nil;
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:@"Application"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Stopped application settings refresh timer"];
    }

    // Reset global state
    gAppFullyLoaded = NO;

    Class nsApplicationClass = [NSApplication class];
    BOOL success = YES;

    // Unswizzle all our swizzled methods
    #define SAFE_UNSWIZZLE(origSel, newSel, type) \
        if ([WCMethodSwizzler class:nsApplicationClass implementsSelector:origSel ofType:type]) { \
            if (![WCMethodSwizzler unswizzleClass:nsApplicationClass \
                                 originalSelector:origSel \
                              replacementSelector:newSel \
                               implementationType:type]) { \
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning \
                                             category:@"Interception" \
                                                 file:__FILE__ \
                                                 line:__LINE__ \
                                             function:__PRETTY_FUNCTION__ \
                                               format:@"Failed to unswizzle %@ in NSApplication", NSStringFromSelector(origSel)]; \
                success = NO; \
            } else { \
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug \
                                             category:@"Interception" \
                                                 file:__FILE__ \
                                                 line:__LINE__ \
                                             function:__PRETTY_FUNCTION__ \
                                               format:@"Successfully unswizzled %@ in NSApplication", NSStringFromSelector(origSel)]; \
            } \
        }

    // Unswizzle all methods we swizzled
    SAFE_UNSWIZZLE(@selector(activationPolicy), @selector(wc_activationPolicy), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(setActivationPolicy:), @selector(wc_setActivationPolicy:), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(presentationOptions), @selector(wc_presentationOptions), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(setPresentationOptions:), @selector(wc_setPresentationOptions:), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(isHidden), @selector(wc_isHidden), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(setHidden:), @selector(wc_setHidden:), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(isActive), @selector(wc_isActive), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(activateIgnoringOtherApps:), @selector(wc_activateIgnoringOtherApps:), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(orderFrontStandardAboutPanel:), @selector(wc_orderFrontStandardAboutPanel:), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(hide:), @selector(wc_hide:), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(unhide:), @selector(wc_unhide:), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(becomeActiveApplication), @selector(wc_becomeActiveApplication), WCImplementationTypeMethod);

    #undef SAFE_UNSWIZZLE

    if (success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"NSApplication interceptor uninstalled successfully"];
        _installed = NO;
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to uninstall NSApplication interceptor completely"];
    }

    return success;
}

#pragma mark - Application Protections

- (void)applyProtectionsToApplication {
    @try {
        // Avoid potential race conditions with a lock
        os_unfair_lock_lock(&gAppSettingsLock);

        // Don't apply settings too frequently (throttle to once per second)
        uint64_t now = mach_absolute_time();
        if (now - gLastSettingsTime < 1000000000) { // ~1 second in nanoseconds
            os_unfair_lock_unlock(&gAppSettingsLock);
            return;
        }
        gLastSettingsTime = now;

        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:@"Application"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Applying settings to NSApp"];

        NSApplication *app = [NSApplication sharedApplication];

        // Force activation policy - use accessory to allow proper initialization
        if ([app respondsToSelector:@selector(setActivationPolicy:)]) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                         category:@"Application"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Setting activationPolicy = NSApplicationActivationPolicyAccessory"];
            BOOL result = [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                         category:@"Application"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"setActivationPolicy result: %d", result];
        } else {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                         category:@"Application"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"NSApp does not respond to setActivationPolicy"];
        }

        // Apply presentation options - with more balanced approach
        if ([app respondsToSelector:@selector(setPresentationOptions:)]) {
            // Less aggressive options for better stability:
            NSApplicationPresentationOptions options = NSApplicationPresentationHideDock |
                                                       NSApplicationPresentationDisableForceQuit;

            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                        category:@"Application"
                                            file:__FILE__
                                            line:__LINE__
                                        function:__PRETTY_FUNCTION__
                                          format:@"Setting presentation options: %lu", (unsigned long)options];
            [app setPresentationOptions:options];
        }

        // Print current settings
        if ([app respondsToSelector:@selector(activationPolicy)]) {
            NSApplicationActivationPolicy policy = [app activationPolicy];
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                        category:@"Application"
                                            file:__FILE__
                                            line:__LINE__
                                        function:__PRETTY_FUNCTION__
                                          format:@"Current activationPolicy: %d", (int)policy];
        }

        if ([app respondsToSelector:@selector(presentationOptions)]) {
            NSApplicationPresentationOptions options = [app presentationOptions];
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                        category:@"Application"
                                            file:__FILE__
                                            line:__LINE__
                                        function:__PRETTY_FUNCTION__
                                          format:@"Current presentationOptions: %lu", (unsigned long)options];
        }

        os_unfair_lock_unlock(&gAppSettingsLock);

        // Mark as fully loaded after the first settings application
        if (!gAppFullyLoaded) {
            // Delay marking as fully loaded to avoid race conditions during startup
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                gAppFullyLoaded = YES;
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                            category:@"Application"
                                                file:__FILE__
                                                line:__LINE__
                                            function:__PRETTY_FUNCTION__
                                              format:@"App marked as fully loaded"];
            });
        }
    } @catch (NSException *exception) {
        os_unfair_lock_unlock(&gAppSettingsLock);
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Application"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Exception in applyProtectionsToApplication: %@", exception.reason];
    }
}

#pragma mark - Cleanup

- (void)dealloc {
    // If our timer is still running, stop it
    if (_appSettingsRefreshTimer) {
        dispatch_source_cancel(_appSettingsRefreshTimer);
        _appSettingsRefreshTimer = nil;
    }
}

@end

#pragma mark - Swizzled Method Implementations

// Swizzled activationPolicy getter
static NSApplicationActivationPolicy wc_activationPolicy(id self, SEL _cmd) {
    // Override: Use accessory policy to hide from Dock while still allowing init
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Application"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Intercepted activationPolicy call, forcing NSApplicationActivationPolicyAccessory"];
    return NSApplicationActivationPolicyAccessory;
}

// Swizzled setActivationPolicy: setter
static BOOL wc_setActivationPolicy(id self, SEL _cmd, NSApplicationActivationPolicy activationPolicy) {
    // Override: Always set to accessory policy to hide from Dock
    activationPolicy = NSApplicationActivationPolicyAccessory;
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Application"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Forcing activation policy to NSApplicationActivationPolicyAccessory"];

    // Call original implementation
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(setActivationPolicy:)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        return ((BOOL (*)(id, SEL, NSApplicationActivationPolicy))originalImp)(self, _cmd, activationPolicy);
    }

    return YES; // Default to success if original implementation is not available
}

// Swizzled presentationOptions getter
static NSApplicationPresentationOptions wc_presentationOptions(id self, SEL _cmd) {
    // Use presentation options for hide dock and more balanced behavior
    NSApplicationPresentationOptions options = NSApplicationPresentationHideDock |
                                               NSApplicationPresentationDisableForceQuit;

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Application"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Modified presentation options: %lu (hide dock + disable force quit)",
                                          (unsigned long)options];
    return options;
}

// Swizzled setPresentationOptions: setter
static void wc_setPresentationOptions(id self, SEL _cmd, NSApplicationPresentationOptions presentationOptions) {
    // Enforce hide dock and disable force quit for better stability
    NSApplicationPresentationOptions enforcedOptions = NSApplicationPresentationHideDock |
                                                       NSApplicationPresentationDisableForceQuit;

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Application"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Forcing presentation options: %lu", (unsigned long)enforcedOptions];

    // Call original implementation with our options
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(setPresentationOptions:)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        ((void (*)(id, SEL, NSApplicationPresentationOptions))originalImp)(self, _cmd, enforcedOptions);
    }
}

// Swizzled isHidden getter
static BOOL wc_isHidden(id self, SEL _cmd) {
    // Call original implementation
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(isHidden)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        return ((BOOL (*)(id, SEL))originalImp)(self, _cmd);
    }
    return NO;
}

// Swizzled setHidden: setter
static void wc_setHidden(id self, SEL _cmd, BOOL hidden) {
    // Call original implementation
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(setHidden:)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        ((void (*)(id, SEL, BOOL))originalImp)(self, _cmd, hidden);
    }
}

// Swizzled isActive getter
static BOOL wc_isActive(id self, SEL _cmd) {
    // Always report as active so the app thinks it's running normally
    // but don't actually make it active at the system level
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Application"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Intercepted isActive, returning YES without stealing focus"];
    return YES;
}

// Swizzled activateIgnoringOtherApps: method
static void wc_activateIgnoringOtherApps(id self, SEL _cmd, BOOL flag) {
    // Don't activate the app - this prevents stealing focus
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Application"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Blocked activateIgnoringOtherApps: to prevent focus stealing"];

    // Don't call original implementation to avoid activation
    // This prevents our app from stealing focus from text editors or other apps
}

// Swizzled orderFrontStandardAboutPanel: method
static void wc_orderFrontStandardAboutPanel(id self, SEL _cmd, id sender) {
    // Call original implementation
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(orderFrontStandardAboutPanel:)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        ((void (*)(id, SEL, id))originalImp)(self, _cmd, sender);
    }
}

// Swizzled hide: method
static void wc_hide(id self, SEL _cmd, id sender) {
    // Call original implementation
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(hide:)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        ((void (*)(id, SEL, id))originalImp)(self, _cmd, sender);
    }
}

// Swizzled unhide: method
static void wc_unhide(id self, SEL _cmd, id sender) {
    // Call original implementation
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(unhide:)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        ((void (*)(id, SEL, id))originalImp)(self, _cmd, sender);
    }
}

// Additional override for becomeActiveApplication
static void wc_becomeActiveApplication(id self, SEL _cmd) {
    // Block becoming the active application to avoid stealing focus
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Application"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Blocked becomeActiveApplication to prevent focus stealing"];

    // Don't call the original implementation as this would make our app active
    // We want to avoid stealing focus from text editors or other apps
}
