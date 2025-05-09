/**
 * @file stealth.m
 * @brief Implementation of the Stealth profile for WindowControlInjector
 */

#import "stealth.h"
#import <AppKit/AppKit.h>

@implementation WCStealthProfile

+ (instancetype)profile {
    return [[self alloc] init];
}

#pragma mark - WCProfile Protocol

- (NSString *)name {
    return @"stealth";
}

- (NSString *)profileDescription {
    return @"Hides application from Dock, status bar, and App Switcher";
}

- (NSDictionary *)propertyOverrides {
    return @{
        // NSApplication property overrides
        @"NSApplication": @{
            // Use accessory activation policy to hide from Dock
            @"activationPolicy": @(NSApplicationActivationPolicyAccessory),

            // Enhanced presentation options to hide from UI
            @"presentationOptions": @(NSApplicationPresentationHideDock |
                                     NSApplicationPresentationHideMenuBar |
                                     NSApplicationPresentationDisableAppleMenu |
                                     NSApplicationPresentationDisableProcessSwitching |
                                     NSApplicationPresentationDisableHideApplication),

            // Prevent user from activating application through normal means
            @"activateIgnoringOtherApps": @NO,

            // Hide application initially
            @"isHidden": @YES,

            // Suppress About panel to prevent accidental discovery
            @"suppressAboutPanel": @YES,

            // Additional settings to prevent discovery
            @"showsTabBar": @NO,
            @"automaticCustomizeTouchBarMenuItemEnabled": @NO
        },

        // NSWindow property overrides
        @"NSWindow": @{
            // Set window level to floating - helps with hiding and visibility control
            @"level": @(3), // NSFloatingWindowLevel

            // Hide window shadows
            @"hasShadow": @NO,

            // Exclude window from windows menu
            @"excludedFromWindowsMenu": @YES,

            // Prevent window from being hidden by mission control (critical)
            @"canHide": @NO,

            // Enhanced collection behavior for better stealth
            @"collectionBehavior": @(NSWindowCollectionBehaviorStationary |
                                     NSWindowCollectionBehaviorIgnoresCycle |
                                     NSWindowCollectionBehaviorCanJoinAllSpaces |
                                     NSWindowCollectionBehaviorFullScreenAuxiliary),

            // Allow window background to be moved without bringing focus
            @"movableByWindowBackground": @YES,

            // Make titlebar transparent
            @"titlebarAppearsTransparent": @YES,

            // Transparency settings to make window less noticeable
            @"isOpaque": @NO,
            @"backgroundColor": [NSColor clearColor],
            @"alphaValue": @(0.8)
        }
    };
}

- (NSArray<NSString *> *)dependencies {
    return nil; // No dependencies
}

@end
