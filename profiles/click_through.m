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

            // Make window visually appear non-interactive
            @"titlebarAppearsTransparent": @YES,
            @"alphaValue": @0.8,
            @"backgroundColor": [NSColor colorWithCalibratedWhite:1.0 alpha:0.5],

            // Set collection behavior to indicate window is non-interactive
            @"collectionBehavior": @(NSWindowCollectionBehaviorTransient |
                                     NSWindowCollectionBehaviorStationary),

            // Exclude from window menus as it's not typically interactive
            @"excludedFromWindowsMenu": @YES,

            // Allow window to be moved by background to reposition if needed
            // even though clicks pass through
            @"movableByWindowBackground": @YES,

            // Remove shadow to better indicate it's not a standard window
            @"hasShadow": @NO,

            // Keep window unfocusable but visible
            @"canBecomeKey": @NO,
        }
    };
}

- (NSArray<NSString *> *)dependencies {
    return nil; // No dependencies
}

@end
