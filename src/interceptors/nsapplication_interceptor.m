/**
 * @file nsapplication_interceptor.m
 * @brief Implementation of the NSApplication interceptor for WindowControlInjector
 */

#import "nsapplication_interceptor.h"
#import "../core/property_manager.h"
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
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"activationPolicy", className);

    if (overrideValue) {
        return [overrideValue integerValue];
    }

    // Call original implementation
    if (gOriginalActivationPolicyIMP) {
        return ((NSApplicationActivationPolicy (*)(id, SEL))gOriginalActivationPolicyIMP)(self, _cmd);
    }

    return NSApplicationActivationPolicyRegular; // Default to regular if original implementation is not available
}

// Swizzled setActivationPolicy: setter
static BOOL wc_setActivationPolicy(id self, SEL _cmd, NSApplicationActivationPolicy activationPolicy) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"activationPolicy", className);

    if (overrideValue) {
        activationPolicy = [overrideValue integerValue];
    }

    // Call original implementation
    if (gOriginalSetActivationPolicyIMP) {
        return ((BOOL (*)(id, SEL, NSApplicationActivationPolicy))gOriginalSetActivationPolicyIMP)(self, _cmd, activationPolicy);
    }

    return YES; // Default to success if original implementation is not available
}

// Swizzled presentationOptions getter
static NSApplicationPresentationOptions wc_presentationOptions(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"presentationOptions", className);

    if (overrideValue) {
        return [overrideValue unsignedIntegerValue];
    }

    // Call original implementation
    if (gOriginalPresentationOptionsIMP) {
        return ((NSApplicationPresentationOptions (*)(id, SEL))gOriginalPresentationOptionsIMP)(self, _cmd);
    }

    return NSApplicationPresentationDefault; // Default to default if original implementation is not available
}

// Swizzled setPresentationOptions: setter
static void wc_setPresentationOptions(id self, SEL _cmd, NSApplicationPresentationOptions presentationOptions) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"presentationOptions", className);

    if (overrideValue) {
        presentationOptions = [overrideValue unsignedIntegerValue];
    }

    // Call original implementation
    if (gOriginalSetPresentationOptionsIMP) {
        ((void (*)(id, SEL, NSApplicationPresentationOptions))gOriginalSetPresentationOptionsIMP)(self, _cmd, presentationOptions);
    }
}

// Swizzled isHidden getter
static BOOL wc_isHidden(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"isHidden", className);

    if (overrideValue) {
        return [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalIsHiddenIMP) {
        return ((BOOL (*)(id, SEL))gOriginalIsHiddenIMP)(self, _cmd);
    }

    return NO; // Default to not hidden if original implementation is not available
}

// Swizzled setHidden: setter
static void wc_setHidden(id self, SEL _cmd, BOOL hidden) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"isHidden", className);

    if (overrideValue) {
        hidden = [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalSetHiddenIMP) {
        ((void (*)(id, SEL, BOOL))gOriginalSetHiddenIMP)(self, _cmd, hidden);
    }
}

// Swizzled isActive getter
static BOOL wc_isActive(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"isActive", className);

    if (overrideValue) {
        return [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalIsActiveIMP) {
        return ((BOOL (*)(id, SEL))gOriginalIsActiveIMP)(self, _cmd);
    }

    return NO; // Default to not active if original implementation is not available
}

// Swizzled activateIgnoringOtherApps: method
static void wc_activateIgnoringOtherApps(id self, SEL _cmd, BOOL flag) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"activateIgnoringOtherApps", className);

    if (overrideValue && [overrideValue boolValue] == NO) {
        // If the override is explicitly set to NO, don't activate
        return;
    }

    // Call original implementation
    if (gOriginalActivateIgnoringOtherAppsIMP) {
        ((void (*)(id, SEL, BOOL))gOriginalActivateIgnoringOtherAppsIMP)(self, _cmd, flag);
    }
}

// Swizzled orderFrontStandardAboutPanel: method
static void wc_orderFrontStandardAboutPanel(id self, SEL _cmd, id sender) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"suppressAboutPanel", className);

    if (overrideValue && [overrideValue boolValue]) {
        // If suppressAboutPanel is true, don't show the panel
        return;
    }

    // Call original implementation
    if (gOriginalOrderFrontStandardAboutPanelIMP) {
        ((void (*)(id, SEL, id))gOriginalOrderFrontStandardAboutPanelIMP)(self, _cmd, sender);
    }
}

// Swizzled hide: method
static void wc_hide(id self, SEL _cmd, id sender) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"preventHide", className);

    if (overrideValue && [overrideValue boolValue]) {
        // If preventHide is true, don't hide the app
        return;
    }

    // Call original implementation
    if (gOriginalHideIMP) {
        ((void (*)(id, SEL, id))gOriginalHideIMP)(self, _cmd, sender);
    }
}

// Swizzled unhide: method
static void wc_unhide(id self, SEL _cmd, id sender) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"preventUnhide", className);

    if (overrideValue && [overrideValue boolValue]) {
        // If preventUnhide is true, don't unhide the app
        return;
    }

    // Call original implementation
    if (gOriginalUnhideIMP) {
        ((void (*)(id, SEL, id))gOriginalUnhideIMP)(self, _cmd, sender);
    }
}

@implementation WCNSApplicationInterceptor

+ (BOOL)install {
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

    // Swizzle methods
    BOOL success = YES;
    success &= WCSwizzleMethod(nsApplicationClass, @selector(activationPolicy), @selector(wc_activationPolicy));
    success &= WCSwizzleMethod(nsApplicationClass, @selector(setActivationPolicy:), @selector(wc_setActivationPolicy:));
    success &= WCSwizzleMethod(nsApplicationClass, @selector(presentationOptions), @selector(wc_presentationOptions));
    success &= WCSwizzleMethod(nsApplicationClass, @selector(setPresentationOptions:), @selector(wc_setPresentationOptions:));
    success &= WCSwizzleMethod(nsApplicationClass, @selector(isHidden), @selector(wc_isHidden));
    success &= WCSwizzleMethod(nsApplicationClass, @selector(setHidden:), @selector(wc_setHidden:));
    success &= WCSwizzleMethod(nsApplicationClass, @selector(isActive), @selector(wc_isActive));
    success &= WCSwizzleMethod(nsApplicationClass, @selector(activateIgnoringOtherApps:), @selector(wc_activateIgnoringOtherApps:));
    success &= WCSwizzleMethod(nsApplicationClass, @selector(orderFrontStandardAboutPanel:), @selector(wc_orderFrontStandardAboutPanel:));
    success &= WCSwizzleMethod(nsApplicationClass, @selector(hide:), @selector(wc_hide:));
    success &= WCSwizzleMethod(nsApplicationClass, @selector(unhide:), @selector(wc_unhide:));

    // Register swizzled selectors with runtime
    class_addMethod(nsApplicationClass, @selector(wc_activationPolicy), (IMP)wc_activationPolicy, "i@:");
    class_addMethod(nsApplicationClass, @selector(wc_setActivationPolicy:), (IMP)wc_setActivationPolicy, "B@:i");
    class_addMethod(nsApplicationClass, @selector(wc_presentationOptions), (IMP)wc_presentationOptions, "Q@:");
    class_addMethod(nsApplicationClass, @selector(wc_setPresentationOptions:), (IMP)wc_setPresentationOptions, "v@:Q");
    class_addMethod(nsApplicationClass, @selector(wc_isHidden), (IMP)wc_isHidden, "B@:");
    class_addMethod(nsApplicationClass, @selector(wc_setHidden:), (IMP)wc_setHidden, "v@:B");
    class_addMethod(nsApplicationClass, @selector(wc_isActive), (IMP)wc_isActive, "B@:");
    class_addMethod(nsApplicationClass, @selector(wc_activateIgnoringOtherApps:), (IMP)wc_activateIgnoringOtherApps, "v@:B");
    class_addMethod(nsApplicationClass, @selector(wc_orderFrontStandardAboutPanel:), (IMP)wc_orderFrontStandardAboutPanel, "v@:@");
    class_addMethod(nsApplicationClass, @selector(wc_hide:), (IMP)wc_hide, "v@:@");
    class_addMethod(nsApplicationClass, @selector(wc_unhide:), (IMP)wc_unhide, "v@:@");

    if (success) {
        WCLogInfo(@"NSApplication interceptor installed successfully");
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
    } else {
        WCLogError(@"Failed to uninstall NSApplication interceptor");
    }

    return success;
}

@end
