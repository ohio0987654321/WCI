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
            // Set window sharing type to none to prevent screen recording
            @"sharingType": @(NSWindowSharingNone),

            // Remove window shadow to avoid any visible traces
            @"hasShadow": @NO,

            // Optional: Transparent background for even more stealth
            // Only apply if you want fully transparent windows
            // @"backgroundColor": [NSColor clearColor],

            // Keep alpha value normal as adjusting this might affect
            // app functionality while not truly hiding from recording
            // @"alphaValue": @1.0,
        }
    };
}

- (NSArray<NSString *> *)dependencies {
    return nil; // No dependencies
}

@end
