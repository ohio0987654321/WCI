/**
 * @file nswindow_interceptor.m
 * @brief Implementation of the NSWindow interceptor
 */

#import "nswindow_interceptor.h"
#import "../util/logger.h"
#import "../util/method_swizzler.h"
#import "../util/error_manager.h"
#import "../util/wc_cgs_types.h"
#import "../util/wc_cgs_functions.h"
#import "interceptor_registry.h"
#import "../core/wc_window_info.h"
#import <dlfcn.h>

// Forward declarations of swizzled method implementations
static NSWindowSharingType wc_sharingType(id self, SEL _cmd);
static void wc_setSharingType(id self, SEL _cmd, NSWindowSharingType sharingType);
static BOOL wc_canBecomeKey(id self, SEL _cmd);
static BOOL wc_canBecomeMain(id self, SEL _cmd);
static BOOL wc_ignoresMouseEvents(id self, SEL _cmd);
static void wc_setIgnoresMouseEvents(id self, SEL _cmd, BOOL ignoresMouseEvents);
static BOOL wc_hasShadow(id self, SEL _cmd);
static void wc_setHasShadow(id self, SEL _cmd, BOOL hasShadow);
static CGFloat wc_alphaValue(id self, SEL _cmd);
static void wc_setAlphaValue(id self, SEL _cmd, CGFloat alphaValue);
static NSWindowLevel wc_level(id self, SEL _cmd);
static void wc_setLevel(id self, SEL _cmd, NSWindowLevel level);
static NSWindowCollectionBehavior wc_collectionBehavior(id self, SEL _cmd);
static void wc_setCollectionBehavior(id self, SEL _cmd, NSWindowCollectionBehavior behavior);
static NSWindowStyleMask wc_styleMask(id self, SEL _cmd);
static void wc_setStyleMask(id self, SEL _cmd, NSWindowStyleMask mask);
static BOOL wc_acceptsMouseMovedEvents(id self, SEL _cmd);
static void wc_setAcceptsMouseMovedEvents(id self, SEL _cmd, BOOL acceptsMouseMovedEvents);

@implementation WCNSWindowInterceptor {
    // Private instance variables
    BOOL _installed;
    dispatch_source_t _windowPropertyRefreshTimer;
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

    // Map to the window interceptor option
    [registry mapInterceptor:self toOption:WCInterceptorOptionWindow];

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Interception"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"NSWindow interceptor registered with registry"];
}

#pragma mark - WCInterceptor Protocol

+ (NSString *)interceptorName {
    return @"NSWindowInterceptor";
}

+ (NSString *)interceptorDescription {
    return @"Intercepts NSWindow methods to prevent screen recording and implement window protection features";
}

+ (NSInteger)priority {
    // Medium priority - not dependent on other interceptors, but others might depend on it
    return 50;
}

#pragma mark - Initialization and Singleton Pattern

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
        _installed = NO;
        _windowPropertyRefreshTimer = nil;
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
                                       format:@"NSWindow interceptor already installed"];
        return YES;
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Interception"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Installing NSWindow interceptor"];

    BOOL success = YES;
    Class nsWindowClass = [NSWindow class];

    // Set up notification observers for windows
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidBecomeVisible:)
                                                 name:NSWindowDidExposeNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidBecomeKey:)
                                                 name:NSWindowDidBecomeKeyNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidBecomeMain:)
                                                 name:NSWindowDidBecomeMainNotification
                                               object:nil];

    // Process any existing windows right away
    for (NSWindow *window in [NSApp windows]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:@"Window"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Applying protections to existing window: %@", window];
        [self applyProtectionsToWindow:window];
    }

    // Set up a timer to periodically refresh properties
    if (_windowPropertyRefreshTimer == nil) {
        _windowPropertyRefreshTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                                           0, 0, dispatch_get_main_queue());
        if (_windowPropertyRefreshTimer) {
            // Refresh every 1 second
            dispatch_source_set_timer(_windowPropertyRefreshTimer,
                                    dispatch_time(DISPATCH_TIME_NOW, 0),
                                    1 * NSEC_PER_SEC,
                                    0.1 * NSEC_PER_SEC);

            dispatch_source_set_event_handler(_windowPropertyRefreshTimer, ^{
                @try {
                    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                                 category:@"Window"
                                                     file:__FILE__
                                                     line:__LINE__
                                                 function:__PRETTY_FUNCTION__
                                                   format:@"Running periodic window property refresh"];
                    // Make a copy of the windows array to avoid mutation during enumeration
                    NSArray *windows = [[NSApp windows] copy];
                    for (NSWindow *window in windows) {
                        // Extra safety check for each window
                        if (window && [window isKindOfClass:[NSWindow class]]) {
                            [self applyProtectionsToWindow:window];
                        }
                    }
                } @catch (NSException *exception) {
                    [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                                 category:@"Window"
                                                     file:__FILE__
                                                     line:__LINE__
                                                 function:__PRETTY_FUNCTION__
                                                   format:@"Exception in timer handler: %@", exception.reason];
                }
            });

            dispatch_resume(_windowPropertyRefreshTimer);
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"Window"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Started window property refresh timer"];
        }
    }

    // Register our swizzled method implementations using the method swizzler

    // First, we need to add our custom implementations
    const char *sharingTypeType = "Q@:";
    const char *setSharingTypeType = "v@:Q";
    const char *boolType = "B@:";
    const char *setBoolType = "v@:B";
    const char *floatType = "d@:";
    const char *setFloatType = "v@:d";
    const char *levelType = "Q@:";
    const char *setLevelType = "v@:Q";
    const char *behaviorType = "Q@:";
    const char *setBehaviorType = "v@:Q";
    const char *styleMaskType = "Q@:";
    const char *setStyleMaskType = "v@:Q";

    // Add methods with prefix "wc_" to the NSWindow class
    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_sharingType)
                         implementation:(IMP)wc_sharingType
                          typeEncoding:sharingTypeType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_setSharingType:)
                         implementation:(IMP)wc_setSharingType
                          typeEncoding:setSharingTypeType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_canBecomeKey)
                         implementation:(IMP)wc_canBecomeKey
                          typeEncoding:boolType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_canBecomeMain)
                         implementation:(IMP)wc_canBecomeMain
                          typeEncoding:boolType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_ignoresMouseEvents)
                         implementation:(IMP)wc_ignoresMouseEvents
                          typeEncoding:boolType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_setIgnoresMouseEvents:)
                         implementation:(IMP)wc_setIgnoresMouseEvents
                          typeEncoding:setBoolType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_hasShadow)
                         implementation:(IMP)wc_hasShadow
                          typeEncoding:boolType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_setHasShadow:)
                         implementation:(IMP)wc_setHasShadow
                          typeEncoding:setBoolType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_alphaValue)
                         implementation:(IMP)wc_alphaValue
                          typeEncoding:floatType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_setAlphaValue:)
                         implementation:(IMP)wc_setAlphaValue
                          typeEncoding:setFloatType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_level)
                         implementation:(IMP)wc_level
                          typeEncoding:levelType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_setLevel:)
                         implementation:(IMP)wc_setLevel
                          typeEncoding:setLevelType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_collectionBehavior)
                         implementation:(IMP)wc_collectionBehavior
                          typeEncoding:behaviorType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_setCollectionBehavior:)
                         implementation:(IMP)wc_setCollectionBehavior
                          typeEncoding:setBehaviorType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_styleMask)
                         implementation:(IMP)wc_styleMask
                          typeEncoding:styleMaskType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_setStyleMask:)
                         implementation:(IMP)wc_setStyleMask
                          typeEncoding:setStyleMaskType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_acceptsMouseMovedEvents)
                         implementation:(IMP)wc_acceptsMouseMovedEvents
                          typeEncoding:boolType];

    [WCMethodSwizzler addMethodToClass:nsWindowClass
                              selector:@selector(wc_setAcceptsMouseMovedEvents:)
                         implementation:(IMP)wc_setAcceptsMouseMovedEvents
                          typeEncoding:setBoolType];

    // Then swizzle the original methods with our custom implementations

    // Helper macro to safely swizzle methods only if they exist
    #define SAFE_SWIZZLE(origSel, newSel, type) \
        if ([WCMethodSwizzler class:nsWindowClass implementsSelector:origSel ofType:type]) { \
            if (![WCMethodSwizzler swizzleClass:nsWindowClass \
                                originalSelector:origSel \
                             replacementSelector:newSel \
                              implementationType:type]) { \
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning \
                                             category:@"Interception" \
                                                 file:__FILE__ \
                                                 line:__LINE__ \
                                             function:__PRETTY_FUNCTION__ \
                                               format:@"Failed to swizzle %@ in NSWindow", NSStringFromSelector(origSel)]; \
                success = NO; \
            } else { \
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug \
                                             category:@"Interception" \
                                                 file:__FILE__ \
                                                 line:__LINE__ \
                                             function:__PRETTY_FUNCTION__ \
                                               format:@"Successfully swizzled %@ in NSWindow", NSStringFromSelector(origSel)]; \
            } \
        } else { \
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo \
                                         category:@"Interception" \
                                             file:__FILE__ \
                                             line:__LINE__ \
                                         function:__PRETTY_FUNCTION__ \
                                           format:@"Method %@ not found in NSWindow, skipping swizzle", NSStringFromSelector(origSel)]; \
        }

    // Swizzle methods that exist
    SAFE_SWIZZLE(@selector(sharingType), @selector(wc_sharingType), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(setSharingType:), @selector(wc_setSharingType:), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(canBecomeKey), @selector(wc_canBecomeKey), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(canBecomeMain), @selector(wc_canBecomeMain), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(ignoresMouseEvents), @selector(wc_ignoresMouseEvents), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(setIgnoresMouseEvents:), @selector(wc_setIgnoresMouseEvents:), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(hasShadow), @selector(wc_hasShadow), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(setHasShadow:), @selector(wc_setHasShadow:), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(alphaValue), @selector(wc_alphaValue), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(setAlphaValue:), @selector(wc_setAlphaValue:), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(level), @selector(wc_level), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(setLevel:), @selector(wc_setLevel:), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(collectionBehavior), @selector(wc_collectionBehavior), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(setCollectionBehavior:), @selector(wc_setCollectionBehavior:), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(styleMask), @selector(wc_styleMask), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(setStyleMask:), @selector(wc_setStyleMask:), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(acceptsMouseMovedEvents), @selector(wc_acceptsMouseMovedEvents), WCImplementationTypeMethod);
    SAFE_SWIZZLE(@selector(setAcceptsMouseMovedEvents:), @selector(wc_setAcceptsMouseMovedEvents:), WCImplementationTypeMethod);

    #undef SAFE_SWIZZLE

    if (success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Interception"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"NSWindow interceptor installed successfully"];
        _installed = YES;
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                 category:@"Interception"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Failed to install NSWindow interceptor"];
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
                                   format:@"NSWindow interceptor not installed, nothing to uninstall"];
        return YES;
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Interception"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Uninstalling NSWindow interceptor"];

    // Stop the timer if it's running
    if (_windowPropertyRefreshTimer) {
        dispatch_source_cancel(_windowPropertyRefreshTimer);
        _windowPropertyRefreshTimer = nil;
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:@"Window"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Stopped window property refresh timer"];
    }

    // Remove notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Window"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Removed window notification observers"];

    Class nsWindowClass = [NSWindow class];
    BOOL success = YES;

    // Unswizzle all our swizzled methods
    #define SAFE_UNSWIZZLE(origSel, newSel, type) \
        if ([WCMethodSwizzler class:nsWindowClass implementsSelector:origSel ofType:type]) { \
            if (![WCMethodSwizzler unswizzleClass:nsWindowClass \
                                 originalSelector:origSel \
                              replacementSelector:newSel \
                               implementationType:type]) { \
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning \
                                             category:@"Interception" \
                                                 file:__FILE__ \
                                                 line:__LINE__ \
                                             function:__PRETTY_FUNCTION__ \
                                               format:@"Failed to unswizzle %@ in NSWindow", NSStringFromSelector(origSel)]; \
                success = NO; \
            } else { \
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug \
                                             category:@"Interception" \
                                                 file:__FILE__ \
                                                 line:__LINE__ \
                                             function:__PRETTY_FUNCTION__ \
                                               format:@"Successfully unswizzled %@ in NSWindow", NSStringFromSelector(origSel)]; \
            } \
        }

    // Unswizzle all methods we swizzled
    SAFE_UNSWIZZLE(@selector(sharingType), @selector(wc_sharingType), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(setSharingType:), @selector(wc_setSharingType:), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(canBecomeKey), @selector(wc_canBecomeKey), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(canBecomeMain), @selector(wc_canBecomeMain), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(ignoresMouseEvents), @selector(wc_ignoresMouseEvents), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(setIgnoresMouseEvents:), @selector(wc_setIgnoresMouseEvents:), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(hasShadow), @selector(wc_hasShadow), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(setHasShadow:), @selector(wc_setHasShadow:), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(alphaValue), @selector(wc_alphaValue), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(setAlphaValue:), @selector(wc_setAlphaValue:), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(level), @selector(wc_level), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(setLevel:), @selector(wc_setLevel:), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(collectionBehavior), @selector(wc_collectionBehavior), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(setCollectionBehavior:), @selector(wc_setCollectionBehavior:), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(styleMask), @selector(wc_styleMask), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(setStyleMask:), @selector(wc_setStyleMask:), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(acceptsMouseMovedEvents), @selector(wc_acceptsMouseMovedEvents), WCImplementationTypeMethod);
    SAFE_UNSWIZZLE(@selector(setAcceptsMouseMovedEvents:), @selector(wc_setAcceptsMouseMovedEvents:), WCImplementationTypeMethod);

    #undef SAFE_UNSWIZZLE

    if (success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"NSWindow interceptor uninstalled successfully"];
        _installed = NO;
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to uninstall NSWindow interceptor completely"];
    }

    return success;
}

#pragma mark - Window Notifications

- (void)windowDidBecomeVisible:(NSNotification *)notification {
    [self handleWindowNotification:notification];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    [self handleWindowNotification:notification];
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
    [self handleWindowNotification:notification];
}

- (void)handleWindowNotification:(NSNotification *)notification {
    @try {
        NSWindow *window = notification.object;
        if (window && [window isKindOfClass:[NSWindow class]]) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                        category:@"Window"
                                            file:__FILE__
                                            line:__LINE__
                                        function:__PRETTY_FUNCTION__
                                          format:@"Window notification: %@ for window: %@",
                                                notification.name, window];
            [self applyProtectionsToWindow:window];
        }
    } @catch (NSException *exception) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Window"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Exception in notification handler: %@", exception.reason];
    }
}

#pragma mark - Window Protections

- (void)applyProtectionsToWindow:(NSWindow *)window {
    @try {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:@"Window"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Applying window protections to window: %@", window];

        // Verify the window is still valid - if not, just return
        if (![window isKindOfClass:[NSWindow class]]) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                         category:@"Window"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Invalid window object, skipping property enforcement"];
            return;
        }

        // Create a WCWindowInfo object to leverage our enhanced functionality
        WCWindowInfo *windowInfo = [[WCWindowInfo alloc] initWithNSWindow:window];
        if (!windowInfo) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                         category:@"Window"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Failed to create WCWindowInfo for window, falling back to direct operations"];
        } else {
            // First make invisible to screen recording - highest priority
            [windowInfo makeInvisibleToScreenRecording];

            // Second - set window level for proper Mission Control positioning
            // Use NSFloatingWindowLevel for best Mission Control behavior
            [windowInfo setLevel:NSFloatingWindowLevel];

            // Third - apply window tags for Mission Control visibility
            [windowInfo setWindowTagsForMissionControlVisibility];

            // Fourth - aggressively disable status bar
            [windowInfo disableStatusBar];

            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"Window"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Applied enhanced window protections using WCWindowInfo"];

            // Done with the enhanced operations - the rest are fallbacks
            if (![window isKindOfClass:[NSWindow class]]) {
                return;
            }
        }

        // Traditional protections as fallback if WCWindowInfo approach fails
        if ([window respondsToSelector:@selector(setSharingType:)]) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                         category:@"Window"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Setting sharingType = NSWindowSharingNone (fallback)"];
            [window setSharingType:NSWindowSharingNone];
        }

    // Modified window level - use NSFloatingWindowLevel for consistent Mission Control behavior
    if ([window respondsToSelector:@selector(setLevel:)]) {
        NSWindowLevel windowLevel = NSFloatingWindowLevel; // Use NSFloatingWindowLevel for visibility in Mission Control
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:@"Window"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Setting window level to NSFloatingWindowLevel for Mission Control compatibility"];
        [window setLevel:windowLevel];
    }

        // Aggressive status bar disabling - VERY important change from original
        if ([window respondsToSelector:@selector(setStyleMask:)]) {
            // VERY aggressive approach - start with borderless window
            NSWindowStyleMask mask = NSWindowStyleMaskBorderless;

            // Add only the styles we want to keep
            mask |= NSWindowStyleMaskResizable;  // Allow resizing
            mask |= NSWindowStyleMaskFullSizeContentView;  // Content extends to full window frame
            mask |= NSWindowStyleMaskNonactivatingPanel;   // Non-activating

            // Set an aggressive style mask that removes the status bar
            [window setStyleMask:mask];

            // Force title visibility to hidden
            if ([window respondsToSelector:@selector(setTitleVisibility:)]) {
                [window setTitleVisibility:NSWindowTitleHidden];
            }

            // Force titlebar to be fully transparent
            if ([window respondsToSelector:@selector(setTitlebarAppearsTransparent:)]) {
                [window setTitlebarAppearsTransparent:YES];
            }

            // Set title to empty
            if ([window respondsToSelector:@selector(setTitle:)]) {
                [window setTitle:@""];
            }

            // Set toolbar to nil
            if ([window respondsToSelector:@selector(setToolbar:)]) {
                [window setToolbar:nil];
            }

            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                         category:@"Window"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Applied aggressive style mask to disable status bar"];
        }

        // Modified collection behavior - use specific settings for best Mission Control visibility
        if ([window respondsToSelector:@selector(setCollectionBehavior:)]) {
            NSWindowCollectionBehavior behavior = NSWindowCollectionBehaviorDefault;

            // Optimized behavior for Mission Control positioning
            behavior |= NSWindowCollectionBehaviorManaged;
            behavior |= NSWindowCollectionBehaviorParticipatesInCycle;
            behavior |= NSWindowCollectionBehaviorMoveToActiveSpace;
            behavior |= NSWindowCollectionBehaviorFullScreenPrimary;

            // Remove behaviors that cause fixed positioning
            behavior &= ~NSWindowCollectionBehaviorStationary;
            behavior &= ~NSWindowCollectionBehaviorCanJoinAllSpaces;

            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                         category:@"Window"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Setting optimized window collectionBehavior for Mission Control visibility"];
            [window setCollectionBehavior:behavior];
        }

        // Set window to accept mouse events without becoming key
        if ([window respondsToSelector:@selector(setAcceptsMouseMovedEvents:)]) {
            [window setAcceptsMouseMovedEvents:YES];
        }

        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:@"Window"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Window address: %p", (__bridge void *)window];
    } @catch (NSException *exception) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Window"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Exception in applyProtectionsToWindow: %@", exception.reason];
    }
}

#pragma mark - Cleanup

- (void)dealloc {
    // If our timer is still running, stop it
    if (_windowPropertyRefreshTimer) {
        dispatch_source_cancel(_windowPropertyRefreshTimer);
        _windowPropertyRefreshTimer = nil;
    }

    // Remove any notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

#pragma mark - Swizzled Method Implementations

// Swizzled sharingType getter
static NSWindowSharingType wc_sharingType(id self, SEL _cmd) {
    // Override: Make windows invisible to screen recording
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Window"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Intercepted sharingType call, forcing NSWindowSharingNone"];
    return NSWindowSharingNone;
}

// Swizzled sharingType setter
static void wc_setSharingType(id self, SEL _cmd, NSWindowSharingType sharingType) {
    // Override: Always set to NSWindowSharingNone to make windows invisible to screen recording
    sharingType = NSWindowSharingNone;
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Window"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Forcing window sharing type to NSWindowSharingNone"];

    // Call original implementation (stored by our method swizzler)
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(setSharingType:)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        ((void (*)(id, SEL, NSWindowSharingType))originalImp)(self, _cmd, sharingType);
    }
}

// Swizzled canBecomeKey getter
static BOOL wc_canBecomeKey(id self, SEL _cmd) {
    // Prevent windows from becoming key windows to avoid stealing focus
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Window"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Intercepted canBecomeKey, returning NO to prevent focus stealing"];
    return NO;
}

// Swizzled canBecomeMain getter
static BOOL wc_canBecomeMain(id self, SEL _cmd) {
    // Prevent windows from becoming main windows to avoid focus stealing
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Window"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Intercepted canBecomeMain, returning NO to prevent focus stealing"];
    return NO;
}

// Swizzled ignoresMouseEvents getter
static BOOL wc_ignoresMouseEvents(id self, SEL _cmd) {
    // By default, don't ignore mouse events
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(ignoresMouseEvents)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        return ((BOOL (*)(id, SEL))originalImp)(self, _cmd);
    }
    return NO;
}

// Swizzled ignoresMouseEvents setter
static void wc_setIgnoresMouseEvents(id self, SEL _cmd, BOOL ignoresMouseEvents) {
    // Call original implementation
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(setIgnoresMouseEvents:)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        ((void (*)(id, SEL, BOOL))originalImp)(self, _cmd, ignoresMouseEvents);
    }
}

// Swizzled hasShadow getter
static BOOL wc_hasShadow(id self, SEL _cmd) {
    // Call original implementation
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(hasShadow)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        return ((BOOL (*)(id, SEL))originalImp)(self, _cmd);
    }
    return YES;
}

// Swizzled hasShadow setter
static void wc_setHasShadow(id self, SEL _cmd, BOOL hasShadow) {
    // Call original implementation
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(setHasShadow:)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        ((void (*)(id, SEL, BOOL))originalImp)(self, _cmd, hasShadow);
    }
}

// Swizzled alphaValue getter
static CGFloat wc_alphaValue(id self, SEL _cmd) {
    // Call original implementation
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(alphaValue)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        return ((CGFloat (*)(id, SEL))originalImp)(self, _cmd);
    }
    return 1.0;
}

// Swizzled alphaValue setter
static void wc_setAlphaValue(id self, SEL _cmd, CGFloat alphaValue) {
    // Call original implementation
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(setAlphaValue:)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        ((void (*)(id, SEL, CGFloat))originalImp)(self, _cmd, alphaValue);
    }
}

// Swizzled level getter
static NSWindowLevel wc_level(id self, SEL _cmd) {
    // Use NSFloatingWindowLevel for optimal visibility and Mission Control compatibility
    NSWindowLevel levelForVisibility = NSFloatingWindowLevel;

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Window"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Intercepted level call, using NSFloatingWindowLevel for better visibility and Mission Control compatibility"];
    return levelForVisibility;
}

// Swizzled level setter
static void wc_setLevel(id self, SEL _cmd, NSWindowLevel level) {
    // Force NSFloatingWindowLevel for optimal visibility and Mission Control compatibility
    level = NSFloatingWindowLevel;
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Window"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Setting window level to NSFloatingWindowLevel for better visibility and Mission Control compatibility"];

    // Call original implementation with our forced level
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(setLevel:)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        ((void (*)(id, SEL, NSWindowLevel))originalImp)(self, _cmd, level);
    }

    // If we have access to the window ID, also try using direct CGS API
    if ([self respondsToSelector:@selector(windowNumber)]) {
        CGWindowID windowID = (CGWindowID)[(NSWindow*)self windowNumber];
        if (windowID > 0) {
            // Use CGS functions to set level directly at CGS level for more reliable behavior
            WCCGSFunctions *cgs = [WCCGSFunctions sharedFunctions];
            if ([cgs isAvailable] && [cgs canSetWindowLevel]) {
                CGSConnectionID cid = [cgs CGSDefaultConnection]();
                if (cid != 0) {
                    [cgs performCGSOperation:@"SetWindowLevel"
                               withWindowID:windowID
                                  operation:^CGError(CGSConnectionID cid, CGSWindowID wid) {
                        // Use NSFloatingWindowLevel for consistent window level across all APIs
                        return cgs.CGSSetWindowLevel(cid, wid, NSFloatingWindowLevel);
                    }];
                }
            }
        }
    }
}

// Swizzled collectionBehavior getter
static NSWindowCollectionBehavior wc_collectionBehavior(id self, SEL _cmd) {
    // Start with default behavior
    NSWindowCollectionBehavior behavior = NSWindowCollectionBehaviorDefault;

    // Optimized behavior for Mission Control positioning
    behavior |= NSWindowCollectionBehaviorManaged;
    behavior |= NSWindowCollectionBehaviorParticipatesInCycle;
    behavior |= NSWindowCollectionBehaviorMoveToActiveSpace;
    behavior |= NSWindowCollectionBehaviorFullScreenPrimary;

    // Remove behaviors that cause fixed positioning
    behavior &= ~NSWindowCollectionBehaviorStationary;
    behavior &= ~NSWindowCollectionBehaviorCanJoinAllSpaces;
    behavior &= ~NSWindowCollectionBehaviorIgnoresCycle;
    behavior &= ~NSWindowCollectionBehaviorTransient;

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Window"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Intercepted collectionBehavior, returning optimized value for Mission Control: %lu", (unsigned long)behavior];
    return behavior;
}

// Swizzled collectionBehavior setter
static void wc_setCollectionBehavior(id self, SEL _cmd, NSWindowCollectionBehavior behavior) {
    // Start with default behavior
    behavior = NSWindowCollectionBehaviorDefault;

    // Optimized behavior for Mission Control positioning - consistent with WCWindowInfo.m
    behavior |= NSWindowCollectionBehaviorManaged;
    behavior |= NSWindowCollectionBehaviorParticipatesInCycle;
    behavior |= NSWindowCollectionBehaviorMoveToActiveSpace;
    behavior |= NSWindowCollectionBehaviorFullScreenPrimary;

    // Remove behaviors that cause fixed positioning
    behavior &= ~NSWindowCollectionBehaviorStationary;
    behavior &= ~NSWindowCollectionBehaviorCanJoinAllSpaces;
    behavior &= ~NSWindowCollectionBehaviorIgnoresCycle;
    behavior &= ~NSWindowCollectionBehaviorTransient;

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Window"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Setting optimized collectionBehavior for Mission Control: %lu", (unsigned long)behavior];

    // Call original implementation with our optimized behavior
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(setCollectionBehavior:)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        ((void (*)(id, SEL, NSWindowCollectionBehavior))originalImp)(self, _cmd, behavior);
    }

    // Set window level to ensure consistent behavior
    if ([self respondsToSelector:@selector(setLevel:)]) {
        [(NSWindow*)self setLevel:NSFloatingWindowLevel];
    }
}

// Swizzled styleMask getter - ULTRA aggressive approach to match disableStatusBar in WCWindowInfo
static NSWindowStyleMask wc_styleMask(id self, SEL _cmd) {
    // Start with minimal borderless style instead of reading original
    NSWindowStyleMask mask = NSWindowStyleMaskBorderless;

    // Add only the styles we want to keep
    mask |= NSWindowStyleMaskResizable;  // Allow resizing
    mask |= NSWindowStyleMaskFullSizeContentView;  // Content extends to full window frame
    mask |= NSWindowStyleMaskNonactivatingPanel;   // Non-activating

    // Explicitly remove title bar and status bar styles
    mask &= ~NSWindowStyleMaskTitled;
    mask &= ~NSWindowStyleMaskUnifiedTitleAndToolbar;
    mask &= ~NSWindowStyleMaskClosable;
    mask &= ~NSWindowStyleMaskMiniaturizable;

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Window"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Intercepted styleMask, returning ultra-minimal style mask with no status/title bar"];

    // Call additional methods to ensure title bar is completely disabled
    // Force-hide title bar via these methods
    NSWindow *window = (NSWindow*)self;
    if ([window respondsToSelector:@selector(setTitleVisibility:)]) {
        [window setTitleVisibility:NSWindowTitleHidden];
    }
    if ([window respondsToSelector:@selector(setTitlebarAppearsTransparent:)]) {
        [window setTitlebarAppearsTransparent:YES];
    }
    if ([window respondsToSelector:@selector(setTitle:)]) {
        [window setTitle:@""];
    }

    return mask;
}

// Swizzled setStyleMask: method - ultra aggressive approach
static void wc_setStyleMask(id self, SEL _cmd, NSWindowStyleMask mask) {
    // Completely ignore the incoming mask - force our own
    mask = NSWindowStyleMaskBorderless;

    // Add only the styles we want to keep
    mask |= NSWindowStyleMaskResizable;  // Allow resizing
    mask |= NSWindowStyleMaskFullSizeContentView;  // Content extends to full window frame
    mask |= NSWindowStyleMaskNonactivatingPanel;   // Non-activating to prevent focus stealing

    // Explicitly remove all title/status bar related styles
    mask &= ~NSWindowStyleMaskTitled;
    mask &= ~NSWindowStyleMaskUnifiedTitleAndToolbar;
    mask &= ~NSWindowStyleMaskClosable;
    mask &= ~NSWindowStyleMaskMiniaturizable;

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Window"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Ultra-aggressively modifying window style mask to disable title/status bar"];

    // Call original implementation
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(setStyleMask:)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        ((void (*)(id, SEL, NSWindowStyleMask))originalImp)(self, _cmd, mask);
    }

    // Apply additional styling attributes to ensure no title bar
    NSWindow *window = (NSWindow*)self;

    // Force title visibility to hidden
    if ([window respondsToSelector:@selector(setTitleVisibility:)]) {
        [window setTitleVisibility:NSWindowTitleHidden];
    }

    // Force titlebar to be fully transparent
    if ([window respondsToSelector:@selector(setTitlebarAppearsTransparent:)]) {
        [window setTitlebarAppearsTransparent:YES];
    }

    // Set title to empty
    if ([window respondsToSelector:@selector(setTitle:)]) {
        [window setTitle:@""];
    }

    // Remove toolbar which can contain status bar elements
    if ([window respondsToSelector:@selector(setToolbar:)]) {
        [window setToolbar:nil];
    }

    // Remove any titlebar accessory view controllers
    if ([window respondsToSelector:@selector(setTitlebarAccessoryViewControllers:)]) {
        [window setTitlebarAccessoryViewControllers:@[]];
    }

    // Try to use private API to set zero titlebar height - safely via NSInvocation
    Class windowClass = [window class];
    SEL titlebarHeightSelector = NSSelectorFromString(@"_setTitlebarHeight:");
    if ([windowClass instancesRespondToSelector:titlebarHeightSelector]) {
        NSMethodSignature *signature = [windowClass instanceMethodSignatureForSelector:titlebarHeightSelector];
        if (signature) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setSelector:titlebarHeightSelector];
            [invocation setTarget:window];
            CGFloat height = 0.0;
            [invocation setArgument:&height atIndex:2];
            [invocation invoke];

            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                         category:@"Window"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Applied zero titlebar height using private API"];
        }
    }
}

// Swizzled acceptsMouseMovedEvents getter
static BOOL wc_acceptsMouseMovedEvents(id self, SEL _cmd) {
    // Always accept mouse moved events to ensure we can track the mouse
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Window"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Intercepted acceptsMouseMovedEvents, returning YES"];
    return YES;
}

// Swizzled setAcceptsMouseMovedEvents: method
static void wc_setAcceptsMouseMovedEvents(id self, SEL _cmd, BOOL acceptsMouseMovedEvents) {
    // Always force to YES
    acceptsMouseMovedEvents = YES;

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Window"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Forcing acceptsMouseMovedEvents to YES"];

    // Call original implementation with our forced value
    IMP originalImp = [WCMethodSwizzler originalImplementationForClass:[self class]
                                                              selector:@selector(setAcceptsMouseMovedEvents:)
                                                    implementationType:WCImplementationTypeMethod];
    if (originalImp) {
        ((void (*)(id, SEL, BOOL))originalImp)(self, _cmd, acceptsMouseMovedEvents);
    }
}
