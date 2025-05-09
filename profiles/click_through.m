/**
 * @file click_through.m
 * @brief Implementation of the Click Through profile for WindowControlInjector
 */

#import "click_through.h"
#import <AppKit/AppKit.h>

@implementation WCClickThroughProfile

+ (instancetype)profile {
    return [[self alloc] init];
}

#pragma mark - WCProfile Protocol

- (NSString *)name {
    return @"click-through";
}

- (NSString *)profileDescription {
    return @"Makes windows click-through, allowing mouse events to pass through";
}

- (NSDictionary *)propertyOverrides {
    return @{
        // NSWindow property overrides
        @"NSWindow": @{
            // Set ignoresMouseEvents to YES to allow clicks to pass through
            @"ignoresMouseEvents": @YES,

            // Optional: Keep window focused but not accepting mouse events
            // Uncomment if needed
            // @"canBecomeKey": @YES,

            // Optional: Adjust opacity to visually indicate click-through status
            // Uncomment if needed
            // @"alphaValue": @0.8,

            // Optional: Useful for visualization of the click-through area
            // but keeping the window semi-transparent
            // Uncomment if needed
            // @"backgroundColor": [NSColor colorWithCalibratedWhite:1.0 alpha:0.5],
        }
    };
}

@end
