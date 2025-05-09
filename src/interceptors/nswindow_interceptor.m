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
static IMP gOriginalCollectionBehaviorIMP = NULL;
static IMP gOriginalSetCollectionBehaviorIMP = NULL;
static IMP gOriginalExcludedFromWindowsMenuIMP = NULL;
static IMP gOriginalSetExcludedFromWindowsMenuIMP = NULL;
static IMP gOriginalCanHideIMP = NULL;
static IMP gOriginalSetCanHideIMP = NULL;
static IMP gOriginalTitlebarAppearsTransparentIMP = NULL;
static IMP gOriginalSetTitlebarAppearsTransparentIMP = NULL;
static IMP gOriginalMovableByWindowBackgroundIMP = NULL;
static IMP gOriginalSetMovableByWindowBackgroundIMP = NULL;

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

// Swizzled collectionBehavior getter
static NSWindowCollectionBehavior wc_collectionBehavior(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"collectionBehavior", className);

    if (overrideValue) {
        return [overrideValue unsignedLongLongValue];
    }

    // Call original implementation
    if (gOriginalCollectionBehaviorIMP) {
        return ((NSWindowCollectionBehavior (*)(id, SEL))gOriginalCollectionBehaviorIMP)(self, _cmd);
    }

    return 0; // Default to 0 if original implementation is not available
}

// Swizzled collectionBehavior setter
static void wc_setCollectionBehavior(id self, SEL _cmd, NSWindowCollectionBehavior collectionBehavior) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"collectionBehavior", className);

    if (overrideValue) {
        collectionBehavior = [overrideValue unsignedLongLongValue];
    }

    // Call original implementation
    if (gOriginalSetCollectionBehaviorIMP) {
        ((void (*)(id, SEL, NSWindowCollectionBehavior))gOriginalSetCollectionBehaviorIMP)(self, _cmd, collectionBehavior);
    }
}

// Swizzled excludedFromWindowsMenu getter
static BOOL wc_excludedFromWindowsMenu(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"excludedFromWindowsMenu", className);

    if (overrideValue) {
        return [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalExcludedFromWindowsMenuIMP) {
        return ((BOOL (*)(id, SEL))gOriginalExcludedFromWindowsMenuIMP)(self, _cmd);
    }

    return NO; // Default to NO if original implementation is not available
}

// Swizzled excludedFromWindowsMenu setter
static void wc_setExcludedFromWindowsMenu(id self, SEL _cmd, BOOL flag) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"excludedFromWindowsMenu", className);

    if (overrideValue) {
        flag = [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalSetExcludedFromWindowsMenuIMP) {
        ((void (*)(id, SEL, BOOL))gOriginalSetExcludedFromWindowsMenuIMP)(self, _cmd, flag);
    }
}

// Swizzled canHide getter
static BOOL wc_canHide(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"canHide", className);

    if (overrideValue) {
        return [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalCanHideIMP) {
        return ((BOOL (*)(id, SEL))gOriginalCanHideIMP)(self, _cmd);
    }

    return YES; // Default to YES if original implementation is not available
}

// Swizzled canHide setter
static void wc_setCanHide(id self, SEL _cmd, BOOL flag) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"canHide", className);

    if (overrideValue) {
        flag = [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalSetCanHideIMP) {
        ((void (*)(id, SEL, BOOL))gOriginalSetCanHideIMP)(self, _cmd, flag);
    }
}

// Swizzled titlebarAppearsTransparent getter
static BOOL wc_titlebarAppearsTransparent(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"titlebarAppearsTransparent", className);

    if (overrideValue) {
        return [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalTitlebarAppearsTransparentIMP) {
        return ((BOOL (*)(id, SEL))gOriginalTitlebarAppearsTransparentIMP)(self, _cmd);
    }

    return NO; // Default to NO if original implementation is not available
}

// Swizzled titlebarAppearsTransparent setter
static void wc_setTitlebarAppearsTransparent(id self, SEL _cmd, BOOL flag) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"titlebarAppearsTransparent", className);

    if (overrideValue) {
        flag = [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalSetTitlebarAppearsTransparentIMP) {
        ((void (*)(id, SEL, BOOL))gOriginalSetTitlebarAppearsTransparentIMP)(self, _cmd, flag);
    }
}

// Swizzled movableByWindowBackground getter
static BOOL wc_movableByWindowBackground(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"movableByWindowBackground", className);

    if (overrideValue) {
        return [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalMovableByWindowBackgroundIMP) {
        return ((BOOL (*)(id, SEL))gOriginalMovableByWindowBackgroundIMP)(self, _cmd);
    }

    return NO; // Default to NO if original implementation is not available
}

// Swizzled movableByWindowBackground setter
static void wc_setMovableByWindowBackground(id self, SEL _cmd, BOOL flag) {
    NSString *className = NSStringFromClass([self class]);
    id overrideValue = WCGetOverrideValue(@"movableByWindowBackground", className);

    if (overrideValue) {
        flag = [overrideValue boolValue];
    }

    // Call original implementation
    if (gOriginalSetMovableByWindowBackgroundIMP) {
        ((void (*)(id, SEL, BOOL))gOriginalSetMovableByWindowBackgroundIMP)(self, _cmd, flag);
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
    gOriginalCollectionBehaviorIMP = WCGetMethodImplementation(nsWindowClass, @selector(collectionBehavior));
    gOriginalSetCollectionBehaviorIMP = WCGetMethodImplementation(nsWindowClass, @selector(setCollectionBehavior:));
    gOriginalExcludedFromWindowsMenuIMP = WCGetMethodImplementation(nsWindowClass, @selector(isExcludedFromWindowsMenu));
    gOriginalSetExcludedFromWindowsMenuIMP = WCGetMethodImplementation(nsWindowClass, @selector(setExcludedFromWindowsMenu:));
    gOriginalCanHideIMP = WCGetMethodImplementation(nsWindowClass, @selector(canHide));
    gOriginalSetCanHideIMP = WCGetMethodImplementation(nsWindowClass, @selector(setCanHide:));
    gOriginalTitlebarAppearsTransparentIMP = WCGetMethodImplementation(nsWindowClass, @selector(titlebarAppearsTransparent));
    gOriginalSetTitlebarAppearsTransparentIMP = WCGetMethodImplementation(nsWindowClass, @selector(setTitlebarAppearsTransparent:));
    gOriginalMovableByWindowBackgroundIMP = WCGetMethodImplementation(nsWindowClass, @selector(isMovableByWindowBackground));
    gOriginalSetMovableByWindowBackgroundIMP = WCGetMethodImplementation(nsWindowClass, @selector(setMovableByWindowBackground:));

    // First, register our swizzled method implementations with the runtime
    WCAddMethod(nsWindowClass, @selector(wc_sharingType), (IMP)wc_sharingType, "Q@:");
    WCAddMethod(nsWindowClass, @selector(wc_setSharingType:), (IMP)wc_setSharingType, "v@:Q");
    WCAddMethod(nsWindowClass, @selector(wc_canBecomeKey), (IMP)wc_canBecomeKey, "B@:");
    WCAddMethod(nsWindowClass, @selector(wc_canBecomeMain), (IMP)wc_canBecomeMain, "B@:");
    WCAddMethod(nsWindowClass, @selector(wc_ignoresMouseEvents), (IMP)wc_ignoresMouseEvents, "B@:");
    WCAddMethod(nsWindowClass, @selector(wc_setIgnoresMouseEvents:), (IMP)wc_setIgnoresMouseEvents, "v@:B");
    WCAddMethod(nsWindowClass, @selector(wc_backgroundColor), (IMP)wc_backgroundColor, "@@:");
    WCAddMethod(nsWindowClass, @selector(wc_setBackgroundColor:), (IMP)wc_setBackgroundColor, "v@:@");
    WCAddMethod(nsWindowClass, @selector(wc_alphaValue), (IMP)wc_alphaValue, "d@:");
    WCAddMethod(nsWindowClass, @selector(wc_setAlphaValue:), (IMP)wc_setAlphaValue, "v@:d");
    WCAddMethod(nsWindowClass, @selector(wc_hasShadow), (IMP)wc_hasShadow, "B@:");
    WCAddMethod(nsWindowClass, @selector(wc_setHasShadow:), (IMP)wc_setHasShadow, "v@:B");
    WCAddMethod(nsWindowClass, @selector(wc_level), (IMP)wc_level, "i@:");
    WCAddMethod(nsWindowClass, @selector(wc_setLevel:), (IMP)wc_setLevel, "v@:i");
    WCAddMethod(nsWindowClass, @selector(wc_isOpaque), (IMP)wc_isOpaque, "B@:");
    WCAddMethod(nsWindowClass, @selector(wc_setOpaque:), (IMP)wc_setOpaque, "v@:B");
    WCAddMethod(nsWindowClass, @selector(wc_collectionBehavior), (IMP)wc_collectionBehavior, "Q@:");
    WCAddMethod(nsWindowClass, @selector(wc_setCollectionBehavior:), (IMP)wc_setCollectionBehavior, "v@:Q");
    WCAddMethod(nsWindowClass, @selector(wc_excludedFromWindowsMenu), (IMP)wc_excludedFromWindowsMenu, "B@:");
    WCAddMethod(nsWindowClass, @selector(wc_setExcludedFromWindowsMenu:), (IMP)wc_setExcludedFromWindowsMenu, "v@:B");
    WCAddMethod(nsWindowClass, @selector(wc_canHide), (IMP)wc_canHide, "B@:");
    WCAddMethod(nsWindowClass, @selector(wc_setCanHide:), (IMP)wc_setCanHide, "v@:B");
    WCAddMethod(nsWindowClass, @selector(wc_titlebarAppearsTransparent), (IMP)wc_titlebarAppearsTransparent, "B@:");
    WCAddMethod(nsWindowClass, @selector(wc_setTitlebarAppearsTransparent:), (IMP)wc_setTitlebarAppearsTransparent, "v@:B");
    WCAddMethod(nsWindowClass, @selector(wc_movableByWindowBackground), (IMP)wc_movableByWindowBackground, "B@:");
    WCAddMethod(nsWindowClass, @selector(wc_setMovableByWindowBackground:), (IMP)wc_setMovableByWindowBackground, "v@:B");

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
    SAFE_SWIZZLE(@selector(backgroundColor), @selector(wc_backgroundColor));
    SAFE_SWIZZLE(@selector(setBackgroundColor:), @selector(wc_setBackgroundColor:));
    SAFE_SWIZZLE(@selector(alphaValue), @selector(wc_alphaValue));
    SAFE_SWIZZLE(@selector(setAlphaValue:), @selector(wc_setAlphaValue:));
    SAFE_SWIZZLE(@selector(hasShadow), @selector(wc_hasShadow));
    SAFE_SWIZZLE(@selector(setHasShadow:), @selector(wc_setHasShadow:));
    SAFE_SWIZZLE(@selector(level), @selector(wc_level));
    SAFE_SWIZZLE(@selector(setLevel:), @selector(wc_setLevel:));
    SAFE_SWIZZLE(@selector(isOpaque), @selector(wc_isOpaque));
    SAFE_SWIZZLE(@selector(setOpaque:), @selector(wc_setOpaque:));
    SAFE_SWIZZLE(@selector(collectionBehavior), @selector(wc_collectionBehavior));
    SAFE_SWIZZLE(@selector(setCollectionBehavior:), @selector(wc_setCollectionBehavior:));
    SAFE_SWIZZLE(@selector(isExcludedFromWindowsMenu), @selector(wc_excludedFromWindowsMenu));
    SAFE_SWIZZLE(@selector(setExcludedFromWindowsMenu:), @selector(wc_setExcludedFromWindowsMenu:));
    SAFE_SWIZZLE(@selector(canHide), @selector(wc_canHide));
    SAFE_SWIZZLE(@selector(setCanHide:), @selector(wc_setCanHide:));
    SAFE_SWIZZLE(@selector(titlebarAppearsTransparent), @selector(wc_titlebarAppearsTransparent));
    SAFE_SWIZZLE(@selector(setTitlebarAppearsTransparent:), @selector(wc_setTitlebarAppearsTransparent:));
    SAFE_SWIZZLE(@selector(isMovableByWindowBackground), @selector(wc_movableByWindowBackground));
    SAFE_SWIZZLE(@selector(setMovableByWindowBackground:), @selector(wc_setMovableByWindowBackground:));

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

    if (gOriginalCollectionBehaviorIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(collectionBehavior), gOriginalCollectionBehaviorIMP) != NULL);
        gOriginalCollectionBehaviorIMP = NULL;
    }

    if (gOriginalSetCollectionBehaviorIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setCollectionBehavior:), gOriginalSetCollectionBehaviorIMP) != NULL);
        gOriginalSetCollectionBehaviorIMP = NULL;
    }

    if (gOriginalExcludedFromWindowsMenuIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(isExcludedFromWindowsMenu), gOriginalExcludedFromWindowsMenuIMP) != NULL);
        gOriginalExcludedFromWindowsMenuIMP = NULL;
    }

    if (gOriginalSetExcludedFromWindowsMenuIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setExcludedFromWindowsMenu:), gOriginalSetExcludedFromWindowsMenuIMP) != NULL);
        gOriginalSetExcludedFromWindowsMenuIMP = NULL;
    }

    if (gOriginalCanHideIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(canHide), gOriginalCanHideIMP) != NULL);
        gOriginalCanHideIMP = NULL;
    }

    if (gOriginalSetCanHideIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setCanHide:), gOriginalSetCanHideIMP) != NULL);
        gOriginalSetCanHideIMP = NULL;
    }

    if (gOriginalTitlebarAppearsTransparentIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(titlebarAppearsTransparent), gOriginalTitlebarAppearsTransparentIMP) != NULL);
        gOriginalTitlebarAppearsTransparentIMP = NULL;
    }

    if (gOriginalSetTitlebarAppearsTransparentIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setTitlebarAppearsTransparent:), gOriginalSetTitlebarAppearsTransparentIMP) != NULL);
        gOriginalSetTitlebarAppearsTransparentIMP = NULL;
    }

    if (gOriginalMovableByWindowBackgroundIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(isMovableByWindowBackground), gOriginalMovableByWindowBackgroundIMP) != NULL);
        gOriginalMovableByWindowBackgroundIMP = NULL;
    }

    if (gOriginalSetMovableByWindowBackgroundIMP) {
        success &= (WCReplaceMethod(nsWindowClass, @selector(setMovableByWindowBackground:), gOriginalSetMovableByWindowBackgroundIMP) != NULL);
        gOriginalSetMovableByWindowBackgroundIMP = NULL;
    }

    if (success) {
        WCLogInfo(@"NSWindow interceptor uninstalled successfully");
    } else {
        WCLogError(@"Failed to uninstall NSWindow interceptor");
    }

    return success;
}

@end
