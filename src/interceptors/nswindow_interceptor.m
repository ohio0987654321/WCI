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

#pragma mark - Swizzled Method Implementations

// Swizzled sharingType getter
static NSWindowSharingType wc_sharingType(id self, SEL _cmd) {
    // Override: Make windows invisible to screen recording
    return NSWindowSharingNone;
}

// Swizzled sharingType setter
static void wc_setSharingType(id self, SEL _cmd, NSWindowSharingType sharingType) {
    // Override: Always set to NSWindowSharingNone to make windows invisible to screen recording
    sharingType = NSWindowSharingNone;

    // Call original implementation
    if (gOriginalSetSharingTypeIMP) {
        ((void (*)(id, SEL, NSWindowSharingType))gOriginalSetSharingTypeIMP)(self, _cmd, sharingType);
    }
}

// Swizzled canBecomeKey getter
static BOOL wc_canBecomeKey(id self, SEL _cmd) {
    // By default, allow windows to become key windows
    if (gOriginalCanBecomeKeyIMP) {
        return ((BOOL (*)(id, SEL))gOriginalCanBecomeKeyIMP)(self, _cmd);
    }
    return YES;
}

// Swizzled canBecomeMain getter
static BOOL wc_canBecomeMain(id self, SEL _cmd) {
    // By default, allow windows to become main windows
    if (gOriginalCanBecomeMainIMP) {
        return ((BOOL (*)(id, SEL))gOriginalCanBecomeMainIMP)(self, _cmd);
    }
    return YES;
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

@implementation WCNSWindowInterceptor

// Static flag to prevent multiple installations
static BOOL gInstalled = NO;

+ (BOOL)install {
    // Don't install more than once
    if (gInstalled) {
        WCLogInfo(@"NSWindow interceptor already installed");
        return YES;
    }

    WCLogInfo(@"Installing NSWindow interceptor");

    Class nsWindowClass = [NSWindow class];

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

    #undef SAFE_SWIZZLE

    if (success) {
        WCLogInfo(@"NSWindow interceptor installed successfully");
        gInstalled = YES;
    } else {
        WCLogError(@"Failed to install NSWindow interceptor");
    }

    return success;
}

+ (BOOL)uninstall {
    WCLogInfo(@"Uninstalling NSWindow interceptor");

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

    if (success) {
        WCLogInfo(@"NSWindow interceptor uninstalled successfully");
        gInstalled = NO;
    } else {
        WCLogError(@"Failed to uninstall NSWindow interceptor");
    }

    return success;
}

@end
