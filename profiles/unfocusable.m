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

            // Set collection behavior to prevent window from being key
            @"collectionBehavior": @(NSWindowCollectionBehaviorIgnoresCycle |
                                     NSWindowCollectionBehaviorStationary),

            // Make window non-interactive with UI
            @"movableByWindowBackground": @NO,

            // Exclude from window cycling with keyboard shortcuts
            @"excludedFromWindowsMenu": @YES,

            // Optional: If we want the window to appear visually unfocused as well
            @"backgroundColor": [NSColor colorWithCalibratedWhite:0.9 alpha:0.95],
            @"titlebarAppearsTransparent": @YES,
        },

        // NSApplication property overrides
        @"NSApplication": @{
            // Prevent application from becoming active
            @"isActive": @NO,
        }
    };
}

- (NSArray<NSString *> *)dependencies {
    return nil; // No dependencies
}

@end
