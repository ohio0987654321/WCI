/**
 * @file unfocusable.m
 * @brief Implementation of the Unfocusable profile for WindowControlInjector
 */

#import "unfocusable.h"
#import <AppKit/AppKit.h>

@implementation WCUnfocusableProfile

+ (instancetype)profile {
    return [[self alloc] init];
}

#pragma mark - WCProfile Protocol

- (NSString *)name {
    return @"unfocusable";
}

- (NSString *)profileDescription {
    return @"Prevents windows from receiving keyboard focus";
}

- (NSDictionary *)propertyOverrides {
    return @{
        // NSWindow property overrides
        @"NSWindow": @{
            // Prevent window from becoming key window (receiving keyboard focus)
            @"canBecomeKey": @NO,

            // Prevent window from becoming main window
            @"canBecomeMain": @NO,

            // Optional: If we want the window to appear visually unfocused as well
            // Uncomment if needed
            // @"backgroundColor": [NSColor colorWithCalibratedWhite:0.8 alpha:1.0],
        },

        // NSApplication property overrides
        @"NSApplication": @{
            // Optional: Prevent application from becoming active
            // Only use if you want the entire application to be unfocusable
            // @"isActive": @NO,
        }
    };
}

@end
