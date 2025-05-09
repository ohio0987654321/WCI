/**
 * @file invisible.m
 * @brief Implementation of the Invisible profile for WindowControlInjector
 */

#import "invisible.h"
#import <AppKit/AppKit.h>

@implementation WCInvisibleProfile

+ (instancetype)profile {
    return [[self alloc] init];
}

#pragma mark - WCProfile Protocol

- (NSString *)name {
    return @"invisible";
}

- (NSString *)profileDescription {
    return @"Makes windows invisible to screen recording and screenshots";
}

- (NSDictionary *)propertyOverrides {
    return @{
        // NSWindow property overrides
        @"NSWindow": @{
            // Set window sharing type to none to prevent screen recording (critical setting)
            @"sharingType": @(NSWindowSharingNone),

            // Set window level to floating - essential for screen recording protection
            @"level": @(3), // NSFloatingWindowLevel

            // Enhanced collection behavior that prevents capture
            @"collectionBehavior": @(NSWindowCollectionBehaviorStationary |
                                     NSWindowCollectionBehaviorFullScreenPrimary |
                                     NSWindowCollectionBehaviorIgnoresCycle |
                                     NSWindowCollectionBehaviorCanJoinAllSpaces |
                                     NSWindowCollectionBehaviorFullScreenAuxiliary),

            // Exclude from window menus and lists
            @"excludedFromWindowsMenu": @YES,

            // Prevent hiding by system (critical for Mission Control exclusion)
            @"canHide": @NO,

            // Remove window shadow to avoid any visible traces
            @"hasShadow": @NO,

            // Make titlebar transparent for better stealth
            @"titlebarAppearsTransparent": @YES,

            // Complete transparency settings
            @"isOpaque": @NO,
            @"backgroundColor": [NSColor clearColor],

            // Make window clickable through background areas
            @"movableByWindowBackground": @YES,

            // Adjust alpha for better protection against capture
            @"alphaValue": @(0.8),
        }
    };
}

- (NSArray<NSString *> *)dependencies {
    return nil; // No dependencies
}

@end
