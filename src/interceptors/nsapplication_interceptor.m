/**
 * @file nsapplication_interceptor.m
 * @brief Implementation of the NSApplication interceptor for WindowControlInjector
 */

#import "nsapplication_interceptor.h"
#import "../util/logger.h"
#import "../util/runtime_utils.h"

// Store original method implementations
static IMP gOriginalActivationPolicyIMP = NULL;
static IMP gOriginalSetActivationPolicyIMP = NULL;
static IMP gOriginalPresentationOptionsIMP = NULL;
static IMP gOriginalSetPresentationOptionsIMP = NULL;
static IMP gOriginalIsHiddenIMP = NULL;
static IMP gOriginalSetHiddenIMP = NULL;
static IMP gOriginalIsActiveIMP = NULL;
static IMP gOriginalActivateIgnoringOtherAppsIMP = NULL;
static IMP gOriginalOrderFrontStandardAboutPanelIMP = NULL;
static IMP gOriginalHideIMP = NULL;
static IMP gOriginalUnhideIMP = NULL;

#pragma mark - Swizzled Method Implementations

// Swizzled activationPolicy getter
static NSApplicationActivationPolicy wc_activationPolicy(id self, SEL _cmd) {
    // Override: Use accessory policy to hide from Dock
    return NSApplicationActivationPolicyAccessory;
}

// Swizzled setActivationPolicy: setter
static BOOL wc_setActivationPolicy(id self, SEL _cmd, NSApplicationActivationPolicy activationPolicy) {
    // Override: Always set to accessory policy to hide from Dock
    activationPolicy = NSApplicationActivationPolicyAccessory;

    // Call original implementation
    if (gOriginalSetActivationPolicyIMP) {
        return ((BOOL (*)(id, SEL, NSApplicationActivationPolicy))gOriginalSetActivationPolicyIMP)(self, _cmd, activationPolicy);
    }

    return YES; // Default to success if original implementation is not available
}

// Swizzled presentationOptions getter
static NSApplicationPresentationOptions wc_presentationOptions(id self, SEL _cmd) {
    // Override: Hide menu bar
    NSApplicationPresentationOptions options = NSApplicationPresentationDefault;

    // If original implementation exists, get the original options first
    if (gOriginalPresentationOptionsIMP) {
        options = ((NSApplicationPresentationOptions (*)(id, SEL))gOriginalPresentationOptionsIMP)(self, _cmd);
    }

    // Add HideMenuBar option
    options |= NSApplicationPresentationHideMenuBar;

    return options;
}

// Swizzled setPresentationOptions: setter
static void wc_setPresentationOptions(id self, SEL _cmd, NSApplicationPresentationOptions presentationOptions) {
    // Add HideMenuBar option
    presentationOptions |= NSApplicationPresentationHideMenuBar;

    // Call original implementation
    if (gOriginalSetPresentationOptionsIMP) {
        ((void (*)(id, SEL, NSApplicationPresentationOptions))gOriginalSetPresentationOptionsIMP)(self, _cmd, presentationOptions);
    }
}

// Swizzled isHidden getter
static BOOL wc_isHidden(id self, SEL _cmd) {
    // Call original implementation
    if (gOriginalIsHiddenIMP) {
        return ((BOOL (*)(id, SEL))gOriginalIsHiddenIMP)(self, _cmd);
    }
    return NO;
}

// Swizzled setHidden: setter
static void wc_setHidden(id self, SEL _cmd, BOOL hidden) {
    // Call original implementation
    if (gOriginalSetHiddenIMP) {
        ((void (*)(id, SEL, BOOL))gOriginalSetHiddenIMP)(self, _cmd, hidden);
    }
}

// Swizzled isActive getter
static BOOL wc_isActive(id self, SEL _cmd) {
    // Call original implementation
    if (gOriginalIsActiveIMP) {
        return ((BOOL (*)(id, SEL))gOriginalIsActiveIMP)(self, _cmd);
    }
    return NO;
}

// Swizzled activateIgnoringOtherApps: method
static void wc_activateIgnoringOtherApps(id self, SEL _cmd, BOOL flag) {
    // Call original implementation - we still want to be able to activate
    if (gOriginalActivateIgnoringOtherAppsIMP) {
        ((void (*)(id, SEL, BOOL))gOriginalActivateIgnoringOtherAppsIMP)(self, _cmd, flag);
    }
}

// Swizzled orderFrontStandardAboutPanel: method
static void wc_orderFrontStandardAboutPanel(id self, SEL _cmd, id sender) {
    // Call original implementation
    if (gOriginalOrderFrontStandardAboutPanelIMP) {
        ((void (*)(id, SEL, id))gOriginalOrderFrontStandardAboutPanelIMP)(self, _cmd, sender);
    }
}

// Swizzled hide: method
static void wc_hide(id self, SEL _cmd, id sender) {
    // Call original implementation
    if (gOriginalHideIMP) {
        ((void (*)(id, SEL, id))gOriginalHideIMP)(self, _cmd, sender);
    }
}

// Swizzled unhide: method
static void wc_unhide(id self, SEL _cmd, id sender) {
    // Call original implementation
    if (gOriginalUnhideIMP) {
        ((void (*)(id, SEL, id))gOriginalUnhideIMP)(self, _cmd, sender);
    }
}

@implementation WCNSApplicationInterceptor

// Static flag to prevent multiple installations
static BOOL gInstalled = NO;

+ (BOOL)install {
    // Don't install more than once
    if (gInstalled) {
        WCLogInfo(@"NSApplication interceptor already installed");
        return YES;
    }

    WCLogInfo(@"Installing NSApplication interceptor");

    Class nsApplicationClass = [NSApplication class];

    // Store original implementations
    gOriginalActivationPolicyIMP = WCGetMethodImplementation(nsApplicationClass, @selector(activationPolicy));
    gOriginalSetActivationPolicyIMP = WCGetMethodImplementation(nsApplicationClass, @selector(setActivationPolicy:));
    gOriginalPresentationOptionsIMP = WCGetMethodImplementation(nsApplicationClass, @selector(presentationOptions));
    gOriginalSetPresentationOptionsIMP = WCGetMethodImplementation(nsApplicationClass, @selector(setPresentationOptions:));
    gOriginalIsHiddenIMP = WCGetMethodImplementation(nsApplicationClass, @selector(isHidden));
    gOriginalSetHiddenIMP = WCGetMethodImplementation(nsApplicationClass, @selector(setHidden:));
    gOriginalIsActiveIMP = WCGetMethodImplementation(nsApplicationClass, @selector(isActive));
    gOriginalActivateIgnoringOtherAppsIMP = WCGetMethodImplementation(nsApplicationClass, @selector(activateIgnoringOtherApps:));
    gOriginalOrderFrontStandardAboutPanelIMP = WCGetMethodImplementation(nsApplicationClass, @selector(orderFrontStandardAboutPanel:));
    gOriginalHideIMP = WCGetMethodImplementation(nsApplicationClass, @selector(hide:));
    gOriginalUnhideIMP = WCGetMethodImplementation(nsApplicationClass, @selector(unhide:));

    // First, register our swizzled method implementations with the runtime
    WCAddMethod(nsApplicationClass, @selector(wc_activationPolicy), (IMP)wc_activationPolicy, "i@:");
    WCAddMethod(nsApplicationClass, @selector(wc_setActivationPolicy:), (IMP)wc_setActivationPolicy, "B@:i");
    WCAddMethod(nsApplicationClass, @selector(wc_presentationOptions), (IMP)wc_presentationOptions, "Q@:");
    WCAddMethod(nsApplicationClass, @selector(wc_setPresentationOptions:), (IMP)wc_setPresentationOptions, "v@:Q");
    WCAddMethod(nsApplicationClass, @selector(wc_isHidden), (IMP)wc_isHidden, "B@:");
    WCAddMethod(nsApplicationClass, @selector(wc_setHidden:), (IMP)wc_setHidden, "v@:B");
    WCAddMethod(nsApplicationClass, @selector(wc_isActive), (IMP)wc_isActive, "B@:");
    WCAddMethod(nsApplicationClass, @selector(wc_activateIgnoringOtherApps:), (IMP)wc_activateIgnoringOtherApps, "v@:B");
    WCAddMethod(nsApplicationClass, @selector(wc_orderFrontStandardAboutPanel:), (IMP)wc_orderFrontStandardAboutPanel, "v@:@");
    WCAddMethod(nsApplicationClass, @selector(wc_hide:), (IMP)wc_hide, "v@:@");
    WCAddMethod(nsApplicationClass, @selector(wc_unhide:), (IMP)wc_unhide, "v@:@");

    // Only swizzle methods that exist and are not already swizzled
    BOOL success = YES;

    // Helper macro to safely swizzle methods only if they exist
    #define SAFE_SWIZZLE(origSel, newSel) \
        if (class_getInstanceMethod(nsApplicationClass, origSel)) { \
            BOOL swizzleResult = WCSwizzleMethod(nsApplicationClass, origSel, newSel); \
            success &= swizzleResult; \
            if (!swizzleResult) { \
                WCLogWarning(@"Failed to swizzle %@ in NSApplication", NSStringFromSelector(origSel)); \
            } else { \
                WCLogDebug(@"Successfully swizzled %@ in NSApplication", NSStringFromSelector(origSel)); \
            } \
        } else { \
            WCLogInfo(@"Method %@ not found in NSApplication, skipping swizzle", NSStringFromSelector(origSel)); \
        }

    // Swizzle methods that exist
    SAFE_SWIZZLE(@selector(activationPolicy), @selector(wc_activationPolicy));
    SAFE_SWIZZLE(@selector(setActivationPolicy:), @selector(wc_setActivationPolicy:));
    SAFE_SWIZZLE(@selector(presentationOptions), @selector(wc_presentationOptions));
    SAFE_SWIZZLE(@selector(setPresentationOptions:), @selector(wc_setPresentationOptions:));
    SAFE_SWIZZLE(@selector(isHidden), @selector(wc_isHidden));
    SAFE_SWIZZLE(@selector(setHidden:), @selector(wc_setHidden:));
    SAFE_SWIZZLE(@selector(isActive), @selector(wc_isActive));
    SAFE_SWIZZLE(@selector(activateIgnoringOtherApps:), @selector(wc_activateIgnoringOtherApps:));
    SAFE_SWIZZLE(@selector(orderFrontStandardAboutPanel:), @selector(wc_orderFrontStandardAboutPanel:));
    SAFE_SWIZZLE(@selector(hide:), @selector(wc_hide:));
    SAFE_SWIZZLE(@selector(unhide:), @selector(wc_unhide:));

    #undef SAFE_SWIZZLE

    if (success) {
        WCLogInfo(@"NSApplication interceptor installed successfully");
        gInstalled = YES;
    } else {
        WCLogError(@"Failed to install NSApplication interceptor");
    }

    return success;
}

+ (BOOL)uninstall {
    WCLogInfo(@"Uninstalling NSApplication interceptor");

    Class nsApplicationClass = [NSApplication class];

    // Replace swizzled implementations with original ones
    BOOL success = YES;

    if (gOriginalActivationPolicyIMP) {
        success &= (WCReplaceMethod(nsApplicationClass, @selector(activationPolicy), gOriginalActivationPolicyIMP) != NULL);
        gOriginalActivationPolicyIMP = NULL;
    }

    if (gOriginalSetActivationPolicyIMP) {
        success &= (WCReplaceMethod(nsApplicationClass, @selector(setActivationPolicy:), gOriginalSetActivationPolicyIMP) != NULL);
        gOriginalSetActivationPolicyIMP = NULL;
    }

    if (gOriginalPresentationOptionsIMP) {
        success &= (WCReplaceMethod(nsApplicationClass, @selector(presentationOptions), gOriginalPresentationOptionsIMP) != NULL);
        gOriginalPresentationOptionsIMP = NULL;
    }

    if (gOriginalSetPresentationOptionsIMP) {
        success &= (WCReplaceMethod(nsApplicationClass, @selector(setPresentationOptions:), gOriginalSetPresentationOptionsIMP) != NULL);
        gOriginalSetPresentationOptionsIMP = NULL;
    }

    if (gOriginalIsHiddenIMP) {
        success &= (WCReplaceMethod(nsApplicationClass, @selector(isHidden), gOriginalIsHiddenIMP) != NULL);
        gOriginalIsHiddenIMP = NULL;
    }

    if (gOriginalSetHiddenIMP) {
        success &= (WCReplaceMethod(nsApplicationClass, @selector(setHidden:), gOriginalSetHiddenIMP) != NULL);
        gOriginalSetHiddenIMP = NULL;
    }

    if (gOriginalIsActiveIMP) {
        success &= (WCReplaceMethod(nsApplicationClass, @selector(isActive), gOriginalIsActiveIMP) != NULL);
        gOriginalIsActiveIMP = NULL;
    }

    if (gOriginalActivateIgnoringOtherAppsIMP) {
        success &= (WCReplaceMethod(nsApplicationClass, @selector(activateIgnoringOtherApps:), gOriginalActivateIgnoringOtherAppsIMP) != NULL);
        gOriginalActivateIgnoringOtherAppsIMP = NULL;
    }

    if (gOriginalOrderFrontStandardAboutPanelIMP) {
        success &= (WCReplaceMethod(nsApplicationClass, @selector(orderFrontStandardAboutPanel:), gOriginalOrderFrontStandardAboutPanelIMP) != NULL);
        gOriginalOrderFrontStandardAboutPanelIMP = NULL;
    }

    if (gOriginalHideIMP) {
        success &= (WCReplaceMethod(nsApplicationClass, @selector(hide:), gOriginalHideIMP) != NULL);
        gOriginalHideIMP = NULL;
    }

    if (gOriginalUnhideIMP) {
        success &= (WCReplaceMethod(nsApplicationClass, @selector(unhide:), gOriginalUnhideIMP) != NULL);
        gOriginalUnhideIMP = NULL;
    }

    if (success) {
        WCLogInfo(@"NSApplication interceptor uninstalled successfully");
        gInstalled = NO;
    } else {
        WCLogError(@"Failed to uninstall NSApplication interceptor");
    }

    return success;
}

@end
