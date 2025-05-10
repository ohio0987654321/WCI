/**
 * @file core.m
 * @brief Implementation of the Core profile for WindowControlInjector
 */

#import "core.h"
#import <AppKit/AppKit.h>

@implementation WCCoreProfile

+ (instancetype)profile {
    return [[self alloc] init];
}

#pragma mark - WCProfile Protocol

- (NSString *)name {
    return @"core";
}

- (NSString *)profileDescription {
    return @"Core functionality: screen recording protection, dock icon hiding, and status bar hiding";
}

- (NSDictionary *)propertyOverrides {
    return @{
        // NSWindow property overrides - only essential for screen recording protection
        @"NSWindow": @{
            // Set window sharing type to none to prevent screen recording (critical setting)
            @"sharingType": @(NSWindowSharingNone)

            // No transparency effects
            // No collection behavior changes
            // No shadow removal
            // No titlebar transparency
        },

        // NSApplication property overrides - only essential for dock/status bar hiding
        @"NSApplication": @{
            // Use accessory activation policy to hide from Dock
            @"activationPolicy": @(NSApplicationActivationPolicyAccessory),

            // Only hide menu bar, don't affect other UI elements
            @"presentationOptions": @(NSApplicationPresentationHideMenuBar)

            // No activation prevention
            // No initial hiding
            // No About panel suppression
        }
    };
}

- (NSArray<NSString *> *)dependencies {
    return nil; // No dependencies
}

@end

