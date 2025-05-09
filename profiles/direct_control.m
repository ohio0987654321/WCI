/**
 * @file direct_control.m
 * @brief Implementation of the DirectControl profile using enhanced window control techniques
 */

#import "direct_control.h"
#import "../src/core/direct_window_control.h"
#import "../src/util/logger.h"
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

@implementation WCDirectControlProfile

+ (instancetype)profile {
    return [[self alloc] init];
}

#pragma mark - WCProfile Protocol

- (NSString *)name {
    return @"direct-control";
}

- (NSString *)profileDescription {
    return @"Enhanced window control using direct Objective-C messaging techniques for maximum screen recording protection, stealth mode, and click-through support";
}

- (NSDictionary *)propertyOverrides {
    // Unlike other profiles, we don't rely on property overrides.
    // Instead, we use direct method calls in the applyToApplication method.
    return @{};
}

- (NSArray<NSString *> *)dependencies {
    return nil; // No dependencies
}

#pragma mark - Custom Implementation

// Window interaction control methods
+ (void)enableWindowInteraction {
    WCLogInfo(@"Enabling window interaction in DirectControl profile");
    [WCDirectWindowControl setAllowWindowInteraction:YES];
}

+ (void)disableWindowInteraction {
    WCLogInfo(@"Disabling window interaction in DirectControl profile");
    [WCDirectWindowControl setAllowWindowInteraction:NO];
}

+ (void)setWindowInteraction:(BOOL)enable {
    WCLogInfo(@"Setting window interaction to: %@", enable ? @"ENABLED" : @"DISABLED");
    [WCDirectWindowControl setAllowWindowInteraction:enable];
}

+ (BOOL)windowInteractionEnabled {
    return [WCDirectWindowControl allowWindowInteraction];
}

// We override the applyToApplication method to use our direct control techniques
// instead of relying on the property manager's standard property overriding.
- (void)applyToApplication:(NSApplication *)application {
    WCLogInfo(@"Applying DirectControl profile with enhanced window protection techniques");

    // Apply stealth mode to the application
    [WCDirectWindowControl applyStealthModeToApplication:application];

    // Apply settings to all windows
    for (NSWindow *window in [application windows]) {
        // Apply anti-screen recording settings
        [WCDirectWindowControl applyAntiScreenRecordingSettings:window];

        // Make it clickable but unfocusable
        [WCDirectWindowControl makeWindowClickable:window];
    }

    // Add a hook for future windows that might be created
    // We use method swizzling to intercept window creation
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class appClass = [NSApplication class];
        SEL originalSelector = @selector(orderFrontStandardAboutPanel:);
        SEL swizzledSelector = @selector(wc_orderFrontStandardAboutPanel:);

        Method originalMethod = class_getInstanceMethod(appClass, originalSelector);
        Method swizzledMethod = class_getInstanceMethod([self class], swizzledSelector);

        if (!originalMethod || !swizzledMethod) {
            // Couldn't find methods
            return;
        }

        // Add the swizzled method to the class
        BOOL didAddMethod = class_addMethod(appClass,
                                           swizzledSelector,
                                           method_getImplementation(swizzledMethod),
                                           method_getTypeEncoding(swizzledMethod));

        if (didAddMethod) {
            // Replace original with the swizzled implementation
            class_replaceMethod(appClass,
                               originalSelector,
                               method_getImplementation(swizzledMethod),
                               method_getTypeEncoding(swizzledMethod));
        } else {
            // Just swap implementations
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }

        WCLogInfo(@"Installed window creation hooks for detecting new windows");

        // Also run the direct window control initializer
        // This sets up additional hooks and periodic checks
        WCLogInfo(@"Setting up direct window control module");
        [WCDirectWindowControl applySettingsToAllWindows];
    });

    WCLogInfo(@"DirectControl profile applied successfully");
}

// This is an example swizzled method that we use to intercept and
// monitor for new window creation events
- (void)wc_orderFrontStandardAboutPanel:(id)sender {
    // First call the original implementation
    [self wc_orderFrontStandardAboutPanel:sender];

    // Then apply our settings to any new windows that may have been created
    WCLogInfo(@"Detected potential new window, applying settings to all windows");
    [WCDirectWindowControl applySettingsToAllWindows];
}

@end
