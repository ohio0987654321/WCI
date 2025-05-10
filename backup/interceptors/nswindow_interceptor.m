/**
 * @file nswindow_interceptor.m
 * @brief Implementation of the NSWindow interceptor for WindowControlInjector
 */

#import "nswindow_interceptor.h"
#import "../util/logger.h"
#import "../util/runtime_utils.h"

// Store original method implementations
static IMP gOriginalSharingTypeIMP = NULL;
static IMP gOriginalSetSharingTypeIMP = NULL;
static IMP gOriginalCanBecomeKeyIMP = NULL;
static IMP gOriginalCanBecomeMainIMP = NULL;
static IMP gOriginalIgnoresMouseEventsIMP = NULL;
static IMP gOriginalSetIgnoresMouseEventsIMP = NULL;
static IMP gOriginalHasShadowIMP = NULL;
static IMP gOriginalSetHasShadowIMP = NULL;
static IMP gOriginalAlphaValueIMP = NULL;
static IMP gOriginalSetAlphaValueIMP = NULL;
static IMP gOriginalLevelIMP = NULL;
static IMP gOriginalSetLevelIMP = NULL;
static IMP gOriginalCollectionBehaviorIMP = NULL;
static IMP gOriginalSetCollectionBehaviorIMP = NULL;
static IMP gOriginalStyleMaskIMP = NULL;
static IMP gOriginalSetStyleMaskIMP = NULL;
static IMP gOriginalAcceptsMouseMovedEventsIMP = NULL;
static IMP gOriginalSetAcceptsMouseMovedEventsIMP = NULL;

#pragma mark - Swizzled Method Implementations

// Swizzled sharingType getter
static NSWindowSharingType wc_sharingType(id self, SEL _cmd) {
    @try {
        // Override: Make windows invisible to screen recording
        printf("[WindowControlInjector] Intercepted sharingType call, forcing NSWindowSharingNone\n");
        return NSWindowSharingNone;
    } @catch (NSException *exception) {
        printf("[WindowControlInjector] Exception in sharingType getter: %s\n",
               [exception.reason UTF8String]);
        // If there's an exception, return a safe default
        return NSWindowSharingNone;
    }
}

// Swizzled sharingType setter
static void wc_setSharingType(id self, SEL _cmd, NSWindowSharingType sharingType) {
    @try {
        // Override: Always set to NSWindowSharingNone to make windows invisible to screen recording
        sharingType = NSWindowSharingNone;
        printf("[WindowControlInjector] Forcing window sharing type to NSWindowSharingNone\n");

        // Call original implementation
        if (gOriginalSetSharingTypeIMP) {
            ((void (*)(id, SEL, NSWindowSharingType))gOriginalSetSharingTypeIMP)(self, _cmd, sharingType);
        }
    } @catch (NSException *exception) {
        printf("[WindowControlInjector] Exception in setSharingType: %s\n",
               [exception.reason UTF8String]);
        // Just log the exception, don't crash
    }
}

// Swizzled canBecomeKey getter
static BOOL wc_canBecomeKey(id self, SEL _cmd) {
    // Prevent windows from becoming key windows to avoid stealing focus
    printf("[WindowControlInjector] Intercepted canBecomeKey, returning NO to prevent focus stealing\n");
    return NO;
}

// Swizzled canBecomeMain getter
static BOOL wc_canBecomeMain(id self, SEL _cmd) {
    // Prevent windows from becoming main windows to avoid focus stealing
    printf("[WindowControlInjector] Intercepted canBecomeMain, returning NO to prevent focus stealing\n");
    return NO;
}

// Swizzled ignoresMouseEvents getter
static BOOL wc_ignoresMouseEvents(id self, SEL _cmd) {
    // By default, don't ignore mouse events
    if (gOriginalIgnoresMouseEventsIMP) {
        return ((BOOL (*)(id, SEL))gOriginalIgnoresMouseEventsIMP)(self, _cmd);
    }
    return NO;
}

// Swizzled ignoresMouseEvents setter
static void wc_setIgnoresMouseEvents(id self, SEL _cmd, BOOL ignoresMouseEvents) {
    // Call original implementation
    if (gOriginalSetIgnoresMouseEventsIMP) {
        ((void (*)(id, SEL, BOOL))gOriginalSetIgnoresMouseEventsIMP)(self, _cmd, ignoresMouseEvents);
    }
}

// Swizzled hasShadow getter
static BOOL wc_hasShadow(id self, SEL _cmd) {
    // Call original implementation
    if (gOriginalHasShadowIMP) {
        return ((BOOL (*)(id, SEL))gOriginalHasShadowIMP)(self, _cmd);
    }
    return YES;
}

// Swizzled hasShadow setter
static void wc_setHasShadow(id self, SEL _cmd, BOOL hasShadow) {
    // Call original implementation
    if (gOriginalSetHasShadowIMP) {
        ((void (*)(id, SEL, BOOL))gOriginalSetHasShadowIMP)(self, _cmd, hasShadow);
    }
}

// Swizzled alphaValue getter
static CGFloat wc_alphaValue(id self, SEL _cmd) {
    // Call original implementation
    if (gOriginalAlphaValueIMP) {
        return ((CGFloat (*)(id, SEL))gOriginalAlphaValueIMP)(self, _cmd);
    }
    return 1.0;
}

// Swizzled alphaValue setter
static void wc_setAlphaValue(id self, SEL _cmd, CGFloat alphaValue) {
    // Call original implementation
    if (gOriginalSetAlphaValueIMP) {
        ((void (*)(id, SEL, CGFloat))gOriginalSetAlphaValueIMP)(self, _cmd, alphaValue);
    }
}

// Swizzled collectionBehavior getter
static NSWindowCollectionBehavior wc_collectionBehavior(id self, SEL _cmd) {
    // Get original collection behavior
    NSWindowCollectionBehavior behavior = NSWindowCollectionBehaviorDefault;
    if (gOriginalCollectionBehaviorIMP) {
        behavior = ((NSWindowCollectionBehavior (*)(id, SEL))gOriginalCollectionBehaviorIMP)(self, _cmd);
    }

    // Add behaviors we need for mission control and proper management
    behavior |= NSWindowCollectionBehaviorParticipatesInCycle; // Makes window appear in Mission Control
    behavior |= NSWindowCollectionBehaviorManaged; // Ensures system manages the window properly

    // Add behaviors for proper focus handling
    behavior |= NSWindowCollectionBehaviorIgnoresCycle; // Prevents the window from becoming key by cycling

    // Set non-activating behavior - window can accept clicks without activating app
    behavior |= NSWindowCollectionBehaviorFullScreenAuxiliary; // Special behavior for utility windows

    // Remove transient flag if present (would cause window to be ignored by system UI)
    behavior &= ~NSWindowCollectionBehaviorTransient;

    printf("[WindowControlInjector] Intercepted collectionBehavior, returning: %lu\n", (unsigned long)behavior);
    return behavior;
}

// Swizzled collectionBehavior setter
static void wc_setCollectionBehavior(id self, SEL _cmd, NSWindowCollectionBehavior behavior) {
    // Add behaviors we need for mission control and proper management
    behavior |= NSWindowCollectionBehaviorParticipatesInCycle; // Makes window appear in Mission Control
    behavior |= NSWindowCollectionBehaviorManaged; // Ensures system manages the window properly

    // Remove transient flag if present (would cause window to be ignored by system UI)
    behavior &= ~NSWindowCollectionBehaviorTransient;

    printf("[WindowControlInjector] Setting collectionBehavior to: %lu\n", (unsigned long)behavior);

    // Call original implementation with our modified behavior
    if (gOriginalSetCollectionBehaviorIMP) {
        ((void (*)(id, SEL, NSWindowCollectionBehavior))gOriginalSetCollectionBehaviorIMP)(self, _cmd, behavior);
    }
}

// Swizzled level getter
static NSWindowLevel wc_level(id self, SEL _cmd) {
    // Use NSFloatingWindowLevel to keep windows above regular app windows
    printf("[WindowControlInjector] Intercepted level call, using NSFloatingWindowLevel\n");
    return NSFloatingWindowLevel;
}

// Swizzled level setter
static void wc_setLevel(id self, SEL _cmd, NSWindowLevel level) {
    // Force NSFloatingWindowLevel to ensure always-on-top behavior
    level = NSFloatingWindowLevel;
    printf("[WindowControlInjector] Setting window level to NSFloatingWindowLevel\n");

    // Call original implementation with our forced level
    if (gOriginalSetLevelIMP) {
        ((void (*)(id, SEL, NSWindowLevel))gOriginalSetLevelIMP)(self, _cmd, level);
    }
}

// Swizzled styleMask getter
static NSWindowStyleMask wc_styleMask(id self, SEL _cmd) {
    // Get original style mask
    NSWindowStyleMask mask = NSWindowStyleMaskBorderless;
    if (gOriginalStyleMaskIMP) {
        mask = ((NSWindowStyleMask (*)(id, SEL))gOriginalStyleMaskIMP)(self, _cmd);
    }

    // Add non-activating panel style - critical for preventing focus stealing
    mask |= NSWindowStyleMaskNonactivatingPanel;

    printf("[WindowControlInjector] Intercepted styleMask, adding NSWindowStyleMaskNonactivatingPanel\n");
    return mask;
}

// Swizzled setStyleMask: method
static void wc_setStyleMask(id self, SEL _cmd, NSWindowStyleMask mask) {
    // Always include non-activating panel style
    mask |= NSWindowStyleMaskNonactivatingPanel;

    printf("[WindowControlInjector] Forcing styleMask to include NSWindowStyleMaskNonactivatingPanel\n");

    // Call original implementation
    if (gOriginalSetStyleMaskIMP) {
        ((void (*)(id, SEL, NSWindowStyleMask))gOriginalSetStyleMaskIMP)(self, _cmd, mask);
    }
}

// Swizzled acceptsMouseMovedEvents getter
static BOOL wc_acceptsMouseMovedEvents(id self, SEL _cmd) {
    // Always accept mouse moved events to ensure we can track the mouse
    printf("[WindowControlInjector] Intercepted acceptsMouseMovedEvents, returning YES\n");
    return YES;
}

// Swizzled setAcceptsMouseMovedEvents: method
static void wc_setAcceptsMouseMovedEvents(id self, SEL _cmd, BOOL acceptsMouseMovedEvents) {
    // Always force to YES
    acceptsMouseMovedEvents = YES;

    printf("[WindowControlInjector] Forcing acceptsMouseMovedEvents to YES\n");

    // Call original implementation with our forced value
    if (gOriginalSetAcceptsMouseMovedEventsIMP) {
        ((void (*)(id, SEL, BOOL))gOriginalSetAcceptsMouseMovedEventsIMP)(self, _cmd, acceptsMouseMovedEvents);
    }
}

// Global timer reference to force property updates
static dispatch_source_t gWindowPropertyRefreshTimer = nil;

// Force properties on a window
static void ForceWindowProperties(NSWindow *window) {
    @try {
        printf("[WindowControlInjector] Forcing window properties for window: %p\n", (__bridge void *)window);

        // Verify the window is still valid - if not, just return
        if (![window isKindOfClass:[NSWindow class]]) {
            printf("[WindowControlInjector] Invalid window object, skipping property enforcement\n");
            return;
        }

        if ([window respondsToSelector:@selector(setSharingType:)]) {
            printf("[WindowControlInjector] Setting sharingType = NSWindowSharingNone\n");
            [window setSharingType:NSWindowSharingNone];
        } else {
            printf("[WindowControlInjector] Window does not respond to setSharingType\n");
        }

        // Set window level to NSFloatingWindowLevel for always-on-top behavior
        if ([window respondsToSelector:@selector(setLevel:)]) {
            printf("[WindowControlInjector] Setting window level to NSFloatingWindowLevel\n");
            [window setLevel:NSFloatingWindowLevel];
        } else {
            printf("[WindowControlInjector] Window does not respond to setLevel:\n");
        }

        // Set window style mask to include non-activating panel
        if ([window respondsToSelector:@selector(setStyleMask:)]) {
            NSWindowStyleMask mask = [window styleMask];
            mask |= NSWindowStyleMaskNonactivatingPanel;
            printf("[WindowControlInjector] Adding NSWindowStyleMaskNonactivatingPanel to window style mask\n");
            [window setStyleMask:mask];
        } else {
            printf("[WindowControlInjector] Window does not respond to setStyleMask:\n");
        }

        // Set appropriate collection behavior for Mission Control visibility
        if ([window respondsToSelector:@selector(setCollectionBehavior:)]) {
            NSWindowCollectionBehavior behavior = [window collectionBehavior];
            behavior |= NSWindowCollectionBehaviorParticipatesInCycle; // Makes window appear in Mission Control
            behavior |= NSWindowCollectionBehaviorManaged; // Ensures system manages the window properly
            behavior |= NSWindowCollectionBehaviorIgnoresCycle; // Prevents the window from becoming key by cycling
            behavior |= NSWindowCollectionBehaviorFullScreenAuxiliary; // Special behavior for utility windows
            behavior &= ~NSWindowCollectionBehaviorTransient; // Remove any transient flag
            printf("[WindowControlInjector] Setting window collectionBehavior for non-activating interaction\n");
            [window setCollectionBehavior:behavior];
        } else {
            printf("[WindowControlInjector] Window does not respond to setCollectionBehavior:\n");
        }

        // Set window to accept mouse events without becoming key
        if ([window respondsToSelector:@selector(setAcceptsMouseMovedEvents:)]) {
            printf("[WindowControlInjector] Setting acceptsMouseMovedEvents to YES\n");
            [window setAcceptsMouseMovedEvents:YES];
        }

        // Force additional critical properties with safety checks
        if ([window respondsToSelector:@selector(setHasShadow:)]) {
            [window setHasShadow:NO];
        }

        // Set key window property based on profile
        // For now, we'll keep the default behavior but add logging
        printf("[WindowControlInjector] Window address: %p\n", (__bridge void *)window);
    } @catch (NSException *exception) {
        printf("[WindowControlInjector] Exception in ForceWindowProperties: %s\n",
               [exception.reason UTF8String]);
        // Just log the exception, don't crash
    }
}

// Handler for window notifications
static void HandleWindowNotification(NSNotification *notification) {
    @try {
        NSWindow *window = notification.object;
        if (window && [window isKindOfClass:[NSWindow class]]) {
            printf("[WindowControlInjector] Window notification: %s for window: %p\n",
                   [notification.name UTF8String], (__bridge void *)window);
            ForceWindowProperties(window);
        }
    } @catch (NSException *exception) {
        printf("[WindowControlInjector] Exception in notification handler: %s\n",
               [exception.reason UTF8String]);
        // Just log the exception, don't crash
    }
}

@implementation WCNSWindowInterceptor

// Static flag to prevent multiple installations
static BOOL gInstalled = NO;

+ (BOOL)install {
    // Don't install more than once
    if (gInstalled) {
        WCLogInfo(@"NSWindow interceptor already installed");
        return YES;
    }

    printf("[WindowControlInjector] Installing NSWindow interceptor\n");
    WCLogInfo(@"Installing NSWindow interceptor");

    Class nsWindowClass = [NSWindow class];

    // Set up notification observers for windows
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(windowDidBecomeVisible:)
                                                 name:NSWindowDidExposeNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(windowDidBecomeKey:)
                                                 name:NSWindowDidBecomeKeyNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(windowDidBecomeMain:)
                                                 name:NSWindowDidBecomeMainNotification
                                               object:nil];

    // Process any existing windows right away
    for (NSWindow *window in [NSApp windows]) {
        printf("[WindowControlInjector] Forcing properties on existing window: %p\n", (__bridge void *)window);
        ForceWindowProperties(window);
    }

    // Set up a timer to periodically refresh properties
    if (gWindowPropertyRefreshTimer == nil) {
        gWindowPropertyRefreshTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                                            0, 0, dispatch_get_main_queue());
        if (gWindowPropertyRefreshTimer) {
            // Refresh every 1 second
            dispatch_source_set_timer(gWindowPropertyRefreshTimer,
                                     dispatch_time(DISPATCH_TIME_NOW, 0),
                                     1 * NSEC_PER_SEC,
                                     0.1 * NSEC_PER_SEC);

            dispatch_source_set_event_handler(gWindowPropertyRefreshTimer, ^{
                @try {
                    printf("[WindowControlInjector] Running periodic window property refresh\n");
                    // Make a copy of the windows array to avoid mutation during enumeration
                    NSArray *windows = [[NSApp windows] copy];
                    for (NSWindow *window in windows) {
                        // Extra safety check for each window
                        if (window && [window isKindOfClass:[NSWindow class]]) {
                            ForceWindowProperties(window);
                        }
                    }
                } @catch (NSException *exception) {
                    printf("[WindowControlInjector] Exception in timer handler: %s\n",
                           [exception.reason UTF8String]);
                    // Just log the exception, don't crash
                }
            });

            dispatch_resume(gWindowPropertyRefreshTimer);
            printf("[WindowControlInjector] Started window property refresh timer\n");
        }
    }

    // Store original implementations
    gOriginalSharingTypeIMP = WCGetMethodImplementation(nsWindowClass, @selector(sharingType));
    gOriginalSetSharingTypeIMP = WCGetMethodImplementation(nsWindowClass, @selector(setSharingType:));
    gOriginalCanBecomeKeyIMP = WCGetMethodImplementation(nsWindowClass, @selector(canBecomeKey));
    gOriginalCanBecomeMainIMP = WCGetMethodImplementation(nsWindowClass, @selector(canBecomeMain));
    gOriginalIgnoresMouseEventsIMP = WCGetMethodImplementation(nsWindowClass, @selector(ignoresMouseEvents));
    gOriginalSetIgnoresMouseEventsIMP = WCGetMethodImplementation(nsWindowClass, @selector(setIgnoresMouseEvents:));
    gOriginalHasShadowIMP = WCGetMethodImplementation(nsWindowClass, @selector(hasShadow));
    gOriginalSetHasShadowIMP = WCGetMethodImplementation(nsWindowClass, @selector(setHasShadow:));
    gOriginalAlphaValueIMP = WCGetMethodImplementation(nsWindowClass, @selector(alphaValue));
    gOriginalSetAlphaValueIMP = WCGetMethodImplementation(nsWindowClass, @selector(setAlphaValue:));
    gOriginalLevelIMP = WCGetMethodImplementation(nsWindowClass, @selector(level));
    gOriginalSetLevelIMP = WCGetMethodImplementation(nsWindowClass, @selector(setLevel:));
    gOriginalCollectionBehaviorIMP = WCGetMethodImplementation(nsWindowClass, @selector(collectionBehavior));
    gOriginalSetCollectionBehaviorIMP = WCGetMethodImplementation(nsWindowClass, @selector(setCollectionBehavior:));
    gOriginalStyleMaskIMP = WCGetMethodImplementation(nsWindowClass, @selector(styleMask));
    gOriginalSetStyleMaskIMP = WCGetMethodImplementation(nsWindowClass, @selector(setStyleMask:));
    gOriginalAcceptsMouseMovedEventsIMP = WCGetMethodImplementation(nsWindowClass, @selector(acceptsMouseMovedEvents));
    gOriginalSetAcceptsMouseMovedEventsIMP = WCGetMethodImplementation(nsWindowClass, @selector(setAcceptsMouseMovedEvents:));

    // First, register our swizzled method implementations with the runtime
    WCAddMethod(nsWindowClass, @selector(wc_sharingType), (IMP)wc_sharingType, "Q@:");
    WCAddMethod(nsWindowClass, @selector(wc_setSharingType:), (IMP)wc_setSharingType, "v@:Q");
    WCAddMethod(nsWindowClass, @selector(wc_canBecomeKey), (IMP)wc_canBecomeKey, "B@:");
    WCAddMethod(nsWindowClass, @selector(wc_canBecomeMain), (IMP)wc_canBecomeMain, "B@:");
    WCAddMethod(nsWindowClass, @selector(wc_ignoresMouseEvents), (IMP)wc_ignoresMouseEvents, "B@:");
    WCAddMethod(nsWindowClass, @selector(wc_setIgnoresMouseEvents:), (IMP)wc_setIgnoresMouseEvents, "v@:B");
    WCAddMethod(nsWindowClass, @selector(wc_hasShadow), (IMP)wc_hasShadow, "B@:");
    WCAddMethod(nsWindowClass, @selector(wc_setHasShadow:), (IMP)wc_setHasShadow, "v@:B");
    WCAddMethod(nsWindowClass, @selector(wc_alphaValue), (IMP)wc_alphaValue, "d@:");
    WCAddMethod(nsWindowClass, @selector(wc_setAlphaValue:), (IMP)wc_setAlphaValue, "v@:d");
    WCAddMethod(nsWindowClass, @selector(wc_level), (IMP)wc_level, "Q@:");
    WCAddMethod(nsWindowClass, @selector(wc_setLevel:), (IMP)wc_setLevel, "v@:Q");
    WCAddMethod(nsWindowClass, @selector(wc_collectionBehavior), (IMP)wc_collectionBehavior, "Q@:");
    WCAddMethod(nsWindowClass, @selector(wc_setCollectionBehavior:), (IMP)wc_setCollectionBehavior, "v@:Q");
    WCAddMethod(nsWindowClass, @selector(wc_styleMask), (IMP)wc_styleMask, "Q@:");
    WCAddMethod(nsWindowClass, @selector(wc_setStyleMask:), (IMP)wc_setStyleMask, "v@:Q");
    WCAddMethod(nsWindowClass, @selector(wc_acceptsMouseMovedEvents), (IMP)wc_acceptsMouseMovedEvents, "B@:");
    WCAddMethod(nsWindowClass, @selector(wc_setAcceptsMouseMovedEvents:), (IMP)wc_setAcceptsMouseMovedEvents, "v@:B");

    // Only swizzle methods that exist and are not already swizzled
    BOOL success = YES;

    // Helper macro to safely swizzle methods only if they exist
    #define SAFE_SWIZZLE(origSel, newSel) \
        if (class_getInstanceMethod(nsWindowClass, origSel)) { \
            BOOL swizzleResult = WCSwizzleMethod(nsWindowClass, origSel, newSel); \
            success &= swizzleResult; \
            if (!swizzleResult) { \
                WCLogWarning(@"Failed to swizzle %@ in NSWindow", NSStringFromSelector(origSel)); \
            } else { \
                WCLogDebug(@"Successfully swizzled %@ in NSWindow", NSStringFromSelector(origSel)); \
            } \
        } else { \
            WCLogInfo(@"Method %@ not found in NSWindow, skipping swizzle", NSStringFromSelector(origSel)); \
        }

    // Swizzle methods that exist
    SAFE_SWIZZLE(@selector(sharingType), @selector(wc_sharingType));
    SAFE_SWIZZLE(@selector(setSharingType:), @selector(wc_setSharingType:));
    SAFE_SWIZZLE(@selector(canBecomeKey), @selector(wc_canBecomeKey));
    SAFE_SWIZZLE(@selector(canBecomeMain), @selector(wc_canBecomeMain));
    SAFE_SWIZZLE(@selector(ignoresMouseEvents), @selector(wc_ignoresMouseEvents));
    SAFE_SWIZZLE(@selector(setIgnoresMouseEvents:), @selector(wc_setIgnoresMouseEvents:));
    SAFE_SWIZZLE(@selector(hasShadow), @selector(wc_hasShadow));
    SAFE_SWIZZLE(@selector(setHasShadow:), @selector(wc_setHasShadow:));
    SAFE_SWIZZLE(@selector(alphaValue), @selector(wc_alphaValue));
    SAFE_SWIZZLE(@selector(setAlphaValue:), @selector(wc_setAlphaValue:));
    SAFE_SWIZZLE(@selector(level), @selector(wc_level));
    SAFE_SWIZZLE(@selector(setLevel:), @selector(wc_setLevel:));
    SAFE_SWIZZLE(@selector(collectionBehavior), @selector(wc_collectionBehavior));
    SAFE_SWIZZLE(@selector(setCollectionBehavior:), @selector(wc_setCollectionBehavior:));
    SAFE_SWIZZLE(@selector(styleMask), @selector(wc_styleMask));
    SAFE_SWIZZLE(@selector(setStyleMask:), @selector(wc_setStyleMask:));
    SAFE_SWIZZLE(@selector(acceptsMouseMovedEvents), @selector(wc_acceptsMouseMovedEvents));
    SAFE_SWIZZLE(@selector(setAcceptsMouseMovedEvents:), @selector(wc_setAcceptsMouseMovedEvents:));

    #undef SAFE_SWIZZLE

    if (success) {
        printf("[WindowControlInjector] NSWindow interceptor installed successfully\n");
        WCLogInfo(@"NSWindow interceptor installed successfully");
        gInstalled = YES;
    } else {
        printf("[WindowControlInjector] Failed to install NSWindow interceptor\n");
        WCLogError(@"Failed to install NSWindow interceptor");
    }

    return success;
}

// Notification handlers
+ (void)windowDidBecomeVisible:(NSNotification *)notification {
    HandleWindowNotification(notification);
}

+ (void)windowDidBecomeKey:(NSNotification *)notification {
    HandleWindowNotification(notification);
}

+ (void)windowDidBecomeMain:(NSNotification *)notification {
    HandleWindowNotification(notification);
}

+ (BOOL)uninstall {
    printf("[WindowControlInjector] Uninstalling NSWindow interceptor\n");
    WCLogInfo(@"Uninstalling NSWindow interceptor");

    // Stop the timer if it's running
    if (gWindowPropertyRefreshTimer) {
        dispatch_source_cancel(gWindowPropertyRefreshTimer);
        gWindowPropertyRefreshTimer = nil;
        printf("[WindowControlInjector] Stopped window property refresh timer\n");
    }

    // Remove notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:[self class]];
    printf("[WindowControlInjector] Removed window notification observers\n");

    Class nsWindowClass = [NSWindow class];

    // Replace swizzled implementations with original ones
    BOOL success = YES;

    if (gOriginalSharingTypeIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(sharingType), gOriginalSharingTypeIMP) != NULL);
        gOriginalSharingTypeIMP = NULL;
    }

    if (gOriginalSetSharingTypeIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setSharingType:), gOriginalSetSharingTypeIMP) != NULL);
        gOriginalSetSharingTypeIMP = NULL;
    }

    if (gOriginalCanBecomeKeyIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(canBecomeKey), gOriginalCanBecomeKeyIMP) != NULL);
        gOriginalCanBecomeKeyIMP = NULL;
    }

    if (gOriginalCanBecomeMainIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(canBecomeMain), gOriginalCanBecomeMainIMP) != NULL);
        gOriginalCanBecomeMainIMP = NULL;
    }

    if (gOriginalIgnoresMouseEventsIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(ignoresMouseEvents), gOriginalIgnoresMouseEventsIMP) != NULL);
        gOriginalIgnoresMouseEventsIMP = NULL;
    }

    if (gOriginalSetIgnoresMouseEventsIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setIgnoresMouseEvents:), gOriginalSetIgnoresMouseEventsIMP) != NULL);
        gOriginalSetIgnoresMouseEventsIMP = NULL;
    }

    if (gOriginalHasShadowIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(hasShadow), gOriginalHasShadowIMP) != NULL);
        gOriginalHasShadowIMP = NULL;
    }

    if (gOriginalSetHasShadowIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setHasShadow:), gOriginalSetHasShadowIMP) != NULL);
        gOriginalSetHasShadowIMP = NULL;
    }

if (gOriginalAlphaValueIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(alphaValue), gOriginalAlphaValueIMP) != NULL);
        gOriginalAlphaValueIMP = NULL;
    }

    if (gOriginalSetAlphaValueIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setAlphaValue:), gOriginalSetAlphaValueIMP) != NULL);
        gOriginalSetAlphaValueIMP = NULL;
    }

    if (gOriginalLevelIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(level), gOriginalLevelIMP) != NULL);
        gOriginalLevelIMP = NULL;
    }

    if (gOriginalSetLevelIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setLevel:), gOriginalSetLevelIMP) != NULL);
        gOriginalSetLevelIMP = NULL;
    }

    if (gOriginalCollectionBehaviorIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(collectionBehavior), gOriginalCollectionBehaviorIMP) != NULL);
        gOriginalCollectionBehaviorIMP = NULL;
    }

    if (gOriginalSetCollectionBehaviorIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setCollectionBehavior:), gOriginalSetCollectionBehaviorIMP) != NULL);
        gOriginalSetCollectionBehaviorIMP = NULL;
    }

    if (gOriginalStyleMaskIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(styleMask), gOriginalStyleMaskIMP) != NULL);
        gOriginalStyleMaskIMP = NULL;
    }

    if (gOriginalSetStyleMaskIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setStyleMask:), gOriginalSetStyleMaskIMP) != NULL);
        gOriginalSetStyleMaskIMP = NULL;
    }

    if (gOriginalAcceptsMouseMovedEventsIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(acceptsMouseMovedEvents), gOriginalAcceptsMouseMovedEventsIMP) != NULL);
        gOriginalAcceptsMouseMovedEventsIMP = NULL;
    }

    if (gOriginalSetAcceptsMouseMovedEventsIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setAcceptsMouseMovedEvents:), gOriginalSetAcceptsMouseMovedEventsIMP) != NULL);
        gOriginalSetAcceptsMouseMovedEventsIMP = NULL;
    }

    if (success) {
        printf("[WindowControlInjector] NSWindow interceptor uninstalled successfully\n");
        WCLogInfo(@"NSWindow interceptor uninstalled successfully");
        gInstalled = NO;
    } else {
        printf("[WindowControlInjector] Failed to uninstall NSWindow interceptor completely\n");
        WCLogError(@"Failed to uninstall NSWindow interceptor completely");
    }

    return success;
}

+ (void)dealloc {
    // If our timer is still running, stop it
    if (gWindowPropertyRefreshTimer) {
        dispatch_source_cancel(gWindowPropertyRefreshTimer);
        gWindowPropertyRefreshTimer = nil;
    }

    // Remove any notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:[self class]];
}

@end
