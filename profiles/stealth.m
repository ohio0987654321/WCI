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

            // Set presentation options to hide from UI
            @"presentationOptions": @(NSApplicationPresentationHideDock |
                                     NSApplicationPresentationHideMenuBar),

            // Prevent user from activating application through normal means
            @"activateIgnoringOtherApps": @NO,

            // Hide application initially
            @"isHidden": @YES,

            // Suppress About panel to prevent accidental discovery
            @"suppressAboutPanel": @YES
        },

        // NSWindow property overrides
        @"NSWindow": @{
            // Set window level to a background level
            @"level": @(NSNormalWindowLevel - 1),

            // Hide window shadows
            @"hasShadow": @NO
        }
    };
}

- (NSArray<NSString *> *)dependencies {
    return nil; // No dependencies
}

@end
