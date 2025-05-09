/**
 * @file nswindow_interceptor.m
 * @brief Implementation of the NSWindow interceptor for WindowControlInjector
 */

#import "nswindow_interceptor.h"
#import "../core/property_manager.h"
#import "../util/logger.h"
#import "../util/runtime_utils.h"

// Store original method implementations
static IMP gOriginalSharingTypeIMP = NULL;
static IMP gOriginalSetSharingTypeIMP = NULL;
static IMP gOriginalCanBecomeKeyIMP = NULL;
static IMP gOriginalCanBecomeMainIMP = NULL;
static IMP gOriginalIgnoresMouseEventsIMP = NULL;
static IMP gOriginalSetIgnoresMouseEventsIMP = NULL;
static IMP gOriginalBackgroundColorIMP = NULL;
static IMP gOriginalSetBackgroundColorIMP = NULL;
static IMP gOriginalAlphaValueIMP = NULL;
static IMP gOriginalSetAlphaValueIMP = NULL;
static IMP gOriginalHasShadowIMP = NULL;
static IMP gOriginalSetHasShadowIMP = NULL;
static IMP gOriginalLevelIMP = NULL;
static IMP gOriginalSetLevelIMP = NULL;
static IMP gOriginalIsOpaqueIMP = NULL;
static IMP gOriginalSetOpaqueIMP = NULL;

#pragma mark - Swizzled Method Implementations

// Swizzled sharingType getter
static NSWindowSharingType wc_sharingType(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"sharingType", className);

    if (overrideValue) {
        return [overrideValue integerValue];
    }

    // Call original implementation
    if (gOriginalSharingTypeIMP) {
        return ((NSWindowSharingType (*)(id, SEL))gOriginalSharingTypeIMP)(self, _cmd);
    }

    return NSWindowSharingNone; // Default to none if original implementation is not available
}

// Swizzled sharingType setter
static void wc_setSharingType(id self, SEL _cmd, NSWindowSharingType sharingType) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"sharingType", className);

    if (overrideValue) {
        sharingType = [overrideValue integerValue];
    }

    // Call original implementation
    if (gOriginalSetSharingTypeIMP) {
        ((void (*)(id, SEL, NSWindowSharingType))gOriginalSetSharingTypeIMP)(self, _cmd, sharingType);
    }
}

// Swizzled canBecomeKey getter
static BOOL wc_canBecomeKey(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"canBecomeKey", className);

    if (overrideValue) {
        return [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalCanBecomeKeyIMP) {
        return ((BOOL (*)(id, SEL))gOriginalCanBecomeKeyIMP)(self, _cmd);
    }

    return YES; // Default to yes if original implementation is not available
}

// Swizzled canBecomeMain getter
static BOOL wc_canBecomeMain(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"canBecomeMain", className);

    if (overrideValue) {
        return [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalCanBecomeMainIMP) {
        return ((BOOL (*)(id, SEL))gOriginalCanBecomeMainIMP)(self, _cmd);
    }

    return YES; // Default to yes if original implementation is not available
}

// Swizzled ignoresMouseEvents getter
static BOOL wc_ignoresMouseEvents(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"ignoresMouseEvents", className);

    if (overrideValue) {
        return [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalIgnoresMouseEventsIMP) {
        return ((BOOL (*)(id, SEL))gOriginalIgnoresMouseEventsIMP)(self, _cmd);
    }

    return NO; // Default to no if original implementation is not available
}

// Swizzled ignoresMouseEvents setter
static void wc_setIgnoresMouseEvents(id self, SEL _cmd, BOOL ignoresMouseEvents) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"ignoresMouseEvents", className);

    if (overrideValue) {
        ignoresMouseEvents = [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalSetIgnoresMouseEventsIMP) {
        ((void (*)(id, SEL, BOOL))gOriginalSetIgnoresMouseEventsIMP)(self, _cmd, ignoresMouseEvents);
    }
}

// Swizzled backgroundColor getter
static NSColor *wc_backgroundColor(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"backgroundColor", className);

    if (overrideValue && [overrideValue isKindOfClass:[NSColor class]]) {
        return overrideValue;
    }

    // Call original implementation
    if (gOriginalBackgroundColorIMP) {
        return ((NSColor *(*)(id, SEL))gOriginalBackgroundColorIMP)(self, _cmd);
    }

    return [NSColor clearColor]; // Default to clear if original implementation is not available
}

// Swizzled backgroundColor setter
static void wc_setBackgroundColor(id self, SEL _cmd, NSColor *backgroundColor) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"backgroundColor", className);

    if (overrideValue && [overrideValue isKindOfClass:[NSColor class]]) {
        backgroundColor = overrideValue;
    }

    // Call original implementation
    if (gOriginalSetBackgroundColorIMP) {
        ((void (*)(id, SEL, NSColor *))gOriginalSetBackgroundColorIMP)(self, _cmd, backgroundColor);
    }
}

// Swizzled alphaValue getter
static CGFloat wc_alphaValue(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"alphaValue", className);

    if (overrideValue) {
        return [overrideValue doubleValue];
    }

    // Call original implementation
    if (gOriginalAlphaValueIMP) {
        return ((CGFloat (*)(id, SEL))gOriginalAlphaValueIMP)(self, _cmd);
    }

    return 1.0; // Default to 1.0 if original implementation is not available
}

// Swizzled alphaValue setter
static void wc_setAlphaValue(id self, SEL _cmd, CGFloat alphaValue) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"alphaValue", className);

    if (overrideValue) {
        alphaValue = [overrideValue doubleValue];
    }

    // Call original implementation
    if (gOriginalSetAlphaValueIMP) {
        ((void (*)(id, SEL, CGFloat))gOriginalSetAlphaValueIMP)(self, _cmd, alphaValue);
    }
}

// Swizzled hasShadow getter
static BOOL wc_hasShadow(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"hasShadow", className);

    if (overrideValue) {
        return [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalHasShadowIMP) {
        return ((BOOL (*)(id, SEL))gOriginalHasShadowIMP)(self, _cmd);
    }

    return YES; // Default to yes if original implementation is not available
}

// Swizzled hasShadow setter
static void wc_setHasShadow(id self, SEL _cmd, BOOL hasShadow) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"hasShadow", className);

    if (overrideValue) {
        hasShadow = [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalSetHasShadowIMP) {
        ((void (*)(id, SEL, BOOL))gOriginalSetHasShadowIMP)(self, _cmd, hasShadow);
    }
}

// Swizzled level getter
static NSWindowLevel wc_level(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"level", className);

    if (overrideValue) {
        return [overrideValue integerValue];
    }

    // Call original implementation
    if (gOriginalLevelIMP) {
        return ((NSWindowLevel (*)(id, SEL))gOriginalLevelIMP)(self, _cmd);
    }

    return NSNormalWindowLevel; // Default to normal if original implementation is not available
}

// Swizzled level setter
static void wc_setLevel(id self, SEL _cmd, NSWindowLevel level) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"level", className);

    if (overrideValue) {
        level = [overrideValue integerValue];
    }

    // Call original implementation
    if (gOriginalSetLevelIMP) {
        ((void (*)(id, SEL, NSWindowLevel))gOriginalSetLevelIMP)(self, _cmd, level);
    }
}

// Swizzled isOpaque getter
static BOOL wc_isOpaque(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"isOpaque", className);

    if (overrideValue) {
        return [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalIsOpaqueIMP) {
        return ((BOOL (*)(id, SEL))gOriginalIsOpaqueIMP)(self, _cmd);
    }

    return YES; // Default to yes if original implementation is not available
}

// Swizzled setOpaque: setter
static void wc_setOpaque(id self, SEL _cmd, BOOL isOpaque) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"isOpaque", className);

    if (overrideValue) {
        isOpaque = [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalSetOpaqueIMP) {
        ((void (*)(id, SEL, BOOL))gOriginalSetOpaqueIMP)(self, _cmd, isOpaque);
    }
}

@implementation WCNSWindowInterceptor

+ (BOOL)install {
    WCLogInfo(@"Installing NSWindow interceptor");

    Class nsWindowClass = [NSWindow class];

    // Store original implementations
    gOriginalSharingTypeIMP = WCGetMethodImplementation(nsWindowClass, @selector(sharingType));
    gOriginalSetSharingTypeIMP = WCGetMethodImplementation(nsWindowClass, @selector(setSharingType:));
    gOriginalCanBecomeKeyIMP = WCGetMethodImplementation(nsWindowClass, @selector(canBecomeKey));
    gOriginalCanBecomeMainIMP = WCGetMethodImplementation(nsWindowClass, @selector(canBecomeMain));
    gOriginalIgnoresMouseEventsIMP = WCGetMethodImplementation(nsWindowClass, @selector(ignoresMouseEvents));
    gOriginalSetIgnoresMouseEventsIMP = WCGetMethodImplementation(nsWindowClass, @selector(setIgnoresMouseEvents:));
    gOriginalBackgroundColorIMP = WCGetMethodImplementation(nsWindowClass, @selector(backgroundColor));
    gOriginalSetBackgroundColorIMP = WCGetMethodImplementation(nsWindowClass, @selector(setBackgroundColor:));
    gOriginalAlphaValueIMP = WCGetMethodImplementation(nsWindowClass, @selector(alphaValue));
    gOriginalSetAlphaValueIMP = WCGetMethodImplementation(nsWindowClass, @selector(setAlphaValue:));
    gOriginalHasShadowIMP = WCGetMethodImplementation(nsWindowClass, @selector(hasShadow));
    gOriginalSetHasShadowIMP = WCGetMethodImplementation(nsWindowClass, @selector(setHasShadow:));
    gOriginalLevelIMP = WCGetMethodImplementation(nsWindowClass, @selector(level));
    gOriginalSetLevelIMP = WCGetMethodImplementation(nsWindowClass, @selector(setLevel:));
    gOriginalIsOpaqueIMP = WCGetMethodImplementation(nsWindowClass, @selector(isOpaque));
    gOriginalSetOpaqueIMP = WCGetMethodImplementation(nsWindowClass, @selector(setOpaque:));

    // Swizzle methods
    BOOL success = YES;
    success &= WCSwizzleMethod(nsWindowClass, @selector(sharingType), @selector(wc_sharingType));
    success &= WCSwizzleMethod(nsWindowClass, @selector(setSharingType:), @selector(wc_setSharingType:));
    success &= WCSwizzleMethod(nsWindowClass, @selector(canBecomeKey), @selector(wc_canBecomeKey));
    success &= WCSwizzleMethod(nsWindowClass, @selector(canBecomeMain), @selector(wc_canBecomeMain));
    success &= WCSwizzleMethod(nsWindowClass, @selector(ignoresMouseEvents), @selector(wc_ignoresMouseEvents));
    success &= WCSwizzleMethod(nsWindowClass, @selector(setIgnoresMouseEvents:), @selector(wc_setIgnoresMouseEvents:));
    success &= WCSwizzleMethod(nsWindowClass, @selector(backgroundColor), @selector(wc_backgroundColor));
    success &= WCSwizzleMethod(nsWindowClass, @selector(setBackgroundColor:), @selector(wc_setBackgroundColor:));
    success &= WCSwizzleMethod(nsWindowClass, @selector(alphaValue), @selector(wc_alphaValue));
    success &= WCSwizzleMethod(nsWindowClass, @selector(setAlphaValue:), @selector(wc_setAlphaValue:));
    success &= WCSwizzleMethod(nsWindowClass, @selector(hasShadow), @selector(wc_hasShadow));
    success &= WCSwizzleMethod(nsWindowClass, @selector(setHasShadow:), @selector(wc_setHasShadow:));
    success &= WCSwizzleMethod(nsWindowClass, @selector(level), @selector(wc_level));
    success &= WCSwizzleMethod(nsWindowClass, @selector(setLevel:), @selector(wc_setLevel:));
    success &= WCSwizzleMethod(nsWindowClass, @selector(isOpaque), @selector(wc_isOpaque));
    success &= WCSwizzleMethod(nsWindowClass, @selector(setOpaque:), @selector(wc_setOpaque:));

    // Register swizzled selectors with runtime
    class_addMethod(nsWindowClass, @selector(wc_sharingType), (IMP)wc_sharingType, "Q@:");
    class_addMethod(nsWindowClass, @selector(wc_setSharingType:), (IMP)wc_setSharingType, "v@:Q");
    class_addMethod(nsWindowClass, @selector(wc_canBecomeKey), (IMP)wc_canBecomeKey, "B@:");
    class_addMethod(nsWindowClass, @selector(wc_canBecomeMain), (IMP)wc_canBecomeMain, "B@:");
    class_addMethod(nsWindowClass, @selector(wc_ignoresMouseEvents), (IMP)wc_ignoresMouseEvents, "B@:");
    class_addMethod(nsWindowClass, @selector(wc_setIgnoresMouseEvents:), (IMP)wc_setIgnoresMouseEvents, "v@:B");
    class_addMethod(nsWindowClass, @selector(wc_backgroundColor), (IMP)wc_backgroundColor, "@@:");
    class_addMethod(nsWindowClass, @selector(wc_setBackgroundColor:), (IMP)wc_setBackgroundColor, "v@:@");
    class_addMethod(nsWindowClass, @selector(wc_alphaValue), (IMP)wc_alphaValue, "d@:");
    class_addMethod(nsWindowClass, @selector(wc_setAlphaValue:), (IMP)wc_setAlphaValue, "v@:d");
    class_addMethod(nsWindowClass, @selector(wc_hasShadow), (IMP)wc_hasShadow, "B@:");
    class_addMethod(nsWindowClass, @selector(wc_setHasShadow:), (IMP)wc_setHasShadow, "v@:B");
    class_addMethod(nsWindowClass, @selector(wc_level), (IMP)wc_level, "i@:");
    class_addMethod(nsWindowClass, @selector(wc_setLevel:), (IMP)wc_setLevel, "v@:i");
    class_addMethod(nsWindowClass, @selector(wc_isOpaque), (IMP)wc_isOpaque, "B@:");
    class_addMethod(nsWindowClass, @selector(wc_setOpaque:), (IMP)wc_setOpaque, "v@:B");

    if (success) {
        WCLogInfo(@"NSWindow interceptor installed successfully");
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

    if (gOriginalBackgroundColorIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(backgroundColor), gOriginalBackgroundColorIMP) != NULL);
        gOriginalBackgroundColorIMP = NULL;
    }

    if (gOriginalSetBackgroundColorIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setBackgroundColor:), gOriginalSetBackgroundColorIMP) != NULL);
        gOriginalSetBackgroundColorIMP = NULL;
    }

    if (gOriginalAlphaValueIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(alphaValue), gOriginalAlphaValueIMP) != NULL);
        gOriginalAlphaValueIMP = NULL;
    }

    if (gOriginalSetAlphaValueIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setAlphaValue:), gOriginalSetAlphaValueIMP) != NULL);
        gOriginalSetAlphaValueIMP = NULL;
    }

    if (gOriginalHasShadowIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(hasShadow), gOriginalHasShadowIMP) != NULL);
        gOriginalHasShadowIMP = NULL;
    }

    if (gOriginalSetHasShadowIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setHasShadow:), gOriginalSetHasShadowIMP) != NULL);
        gOriginalSetHasShadowIMP = NULL;
    }

    if (gOriginalLevelIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(level), gOriginalLevelIMP) != NULL);
        gOriginalLevelIMP = NULL;
    }

    if (gOriginalSetLevelIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setLevel:), gOriginalSetLevelIMP) != NULL);
        gOriginalSetLevelIMP = NULL;
    }

    if (gOriginalIsOpaqueIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(isOpaque), gOriginalIsOpaqueIMP) != NULL);
        gOriginalIsOpaqueIMP = NULL;
    }

    if (gOriginalSetOpaqueIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setOpaque:), gOriginalSetOpaqueIMP) != NULL);
        gOriginalSetOpaqueIMP = NULL;
    }

    if (success) {
        WCLogInfo(@"NSWindow interceptor uninstalled successfully");
    } else {
        WCLogError(@"Failed to uninstall NSWindow interceptor");
    }

    return success;
}

@end
