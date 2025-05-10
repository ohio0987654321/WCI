/**
 * @file direct_window_control.m
 * @brief Direct window control implementation using Objective-C messaging
 */

#import "direct_window_control.h"
#import "../util/logger.h"
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// Define NSWindow collection behavior constants
#define NSWindowCollectionBehaviorStationary (1 << 0)
#define NSWindowCollectionBehaviorIgnoresCycle (1 << 3)
#define NSWindowCollectionBehaviorFullScreenPrimary (1 << 7)
#define NSWindowCollectionBehaviorFullScreenAuxiliary (1 << 8)
#define NSWindowCollectionBehaviorCanJoinAllSpaces (1 << 16)

// Window levels
#define NSFloatingWindowLevel 3
#define CGScreenSaverWindowLevel 1000
#define CGMaximumWindowLevel 2147483631

@implementation WCDirectWindowControl

+ (void)applyAntiScreenRecordingSettings:(NSWindow *)window {
    if (!window) {
        WCLogWarning(@"Cannot apply anti-screen recording settings to nil window");
        return;
    }

    WCLogInfo(@"Applying direct anti-screen recording settings to window: %@", window);

    @try {
        // Set window level to maximum (this is critical for screen recording protection)
        [window setLevel:CGScreenSaverWindowLevel]; // Much higher than NSFloatingWindowLevel

        // Apply dark appearance
        NSAppearance *darkAppearance = [NSAppearance appearanceNamed:@"NSAppearanceNameVibrantDark"];
        if (darkAppearance) {
            [window setAppearance:darkAppearance];
        }

        // Set all collection behaviors
        NSUInteger collectionBehavior =
            NSWindowCollectionBehaviorStationary |
            NSWindowCollectionBehaviorFullScreenPrimary |
            NSWindowCollectionBehaviorIgnoresCycle |
            NSWindowCollectionBehaviorCanJoinAllSpaces |
            NSWindowCollectionBehaviorFullScreenAuxiliary;

        [window setCollectionBehavior:collectionBehavior];

        // Content protection (critical setting)
        [window setSharingType:NSWindowSharingNone];

        // Hide from Mission Control
        [window setCanHide:NO];

        // Make window movable by background (keeps ability to move the window)
        [window setMovableByWindowBackground:YES];

        // Prevent window capture by excluding from menu
        [window setExcludedFromWindowsMenu:YES];

        // Extra settings to prevent capturing - use setValue:forKey: for properties that might not be directly accessible
        // This is more compatible across different macOS versions
        if ([window respondsToSelector:@selector(setValue:forKey:)]) {
            [window setValue:@YES forKey:@"contentProtected"];
        }

        WCLogInfo(@"Anti-screen recording settings applied successfully");
    } @catch (NSException *exception) {
        WCLogError(@"Failed to apply anti-screen recording settings: %@", exception);
    }
}

+ (void)applyStealthModeToApplication:(NSApplication *)application {
    if (!application) {
        WCLogWarning(@"Cannot apply stealth mode to nil application");
        return;
    }

    WCLogInfo(@"Applying direct stealth mode to application: %@", application);

    @try {
        // Set activation policy to accessory (hides from Dock)
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];

        // Simplified presentation options - only hide dock and menu bar
        NSApplicationPresentationOptions presentationOptions =
            NSApplicationPresentationHideDock |
            NSApplicationPresentationHideMenuBar;

        [application setPresentationOptions:presentationOptions];

        // No hidden application state or suppression of panels

        WCLogInfo(@"Stealth mode applied successfully to application");
    } @catch (NSException *exception) {
        WCLogError(@"Failed to apply stealth mode: %@", exception);
    }
}

+ (void)makeWindowClickable:(NSWindow *)window {
    if (!window) {
        WCLogWarning(@"Cannot modify nil window for clickability");
        return;
    }

    WCLogInfo(@"Making window clickable: %@", window);

    @try {
        // Enable user interaction but prevent focus
        [window setIgnoresMouseEvents:NO];

        // Make it movable
        [window setMovable:YES];
        [window setMovableByWindowBackground:YES];

        // Prevent becoming key or main window (focus)
        // But don't disable it completely via category/swizzling
        // Method swizzling approach may be too aggressive
        Method canBecomeKeyMethod = class_getInstanceMethod([window class], @selector(canBecomeKey));
        if (canBecomeKeyMethod) {
            IMP originalImp = method_getImplementation(canBecomeKeyMethod);
            // Only override if it would return YES originally
            if (((BOOL(*)(id, SEL))originalImp)(window, @selector(canBecomeKey))) {
                // We're not permanently swizzling, just temporarily overriding for this window
                objc_setAssociatedObject(window, "wci_canBecomeKey", @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

                // Check if we have a custom subclass already - if not, create one
                if (![NSStringFromClass([window class]) hasPrefix:@"WCI"]) {
                    // Create a custom class for this specific window
                    NSString *newClassName = [NSString stringWithFormat:@"WCI_%@", NSStringFromClass([window class])];
                    Class newClass = objc_allocateClassPair([window class], [newClassName UTF8String], 0);
                    if (newClass) {
                        // Add custom implementations for canBecomeKey/canBecomeMain
                        class_addMethod(newClass, @selector(canBecomeKey), (IMP)wci_canBecomeKey, "B@:");
                        class_addMethod(newClass, @selector(canBecomeMain), (IMP)wci_canBecomeMain, "B@:");

                        // Register the class and set it for our window
                        objc_registerClassPair(newClass);
                        object_setClass(window, newClass);
                    }
                }
            }
        }

        WCLogInfo(@"Window clickability settings applied successfully");
    } @catch (NSException *exception) {
        WCLogError(@"Failed to apply window clickability settings: %@", exception);
    }
}

// Global variable to control window interactivity
static BOOL gAllowWindowInteraction = YES;

// Custom canBecomeKey implementation for our dynamic subclass
BOOL wci_canBecomeKey(id self __attribute__((unused)), SEL _cmd __attribute__((unused))) {
    // Allow becoming key when interaction is enabled
    return gAllowWindowInteraction;
}

// Custom canBecomeMain implementation for our dynamic subclass
BOOL wci_canBecomeMain(id self __attribute__((unused)), SEL _cmd __attribute__((unused))) {
    // Allow becoming main when interaction is enabled
    return gAllowWindowInteraction;
}

// Public method to control window interactivity
+ (void)setAllowWindowInteraction:(BOOL)allow {
    gAllowWindowInteraction = allow;
    WCLogInfo(@"Window interaction mode set to: %@", allow ? @"ENABLED" : @"DISABLED");
}

+ (BOOL)allowWindowInteraction {
    return gAllowWindowInteraction;
}

+ (void)applySettingsToAllWindows {
    WCLogInfo(@"Applying settings to all windows in the application");

    NSApplication *app = [NSApplication sharedApplication];

    // Apply stealth mode to the application
    [self applyStealthModeToApplication:app];

    // Process all windows
    for (NSWindow *window in [app windows]) {
        [self applyAntiScreenRecordingSettings:window];
        [self makeWindowClickable:window];
    }

    // Add notification observer for new windows
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidCreate:)
                                                 name:NSWindowDidResignKeyNotification
                                               object:nil];

    // Also observe window exposure to catch newly appearing windows
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidCreate:)
                                                 name:NSWindowDidExposeNotification
                                               object:nil];
}

// Notification handler for new windows
+ (void)windowDidCreate:(NSNotification *)notification {
    NSWindow *window = notification.object;
    if ([window isKindOfClass:[NSWindow class]]) {
        WCLogInfo(@"New window created, applying settings automatically");
        [self applyAntiScreenRecordingSettings:window];
        [self makeWindowClickable:window];
    }
}

@end

// Initialize when this file is loaded
__attribute__((constructor))
static void initialize_direct_window_control(void) {
    // We'll run our code with a slight delay to ensure the app has initialized
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WCLogInfo(@"Direct window control module initialized");
        [WCDirectWindowControl applySettingsToAllWindows];

        // Reapply periodically for any new windows
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         repeats:YES
                                                           block:^(NSTimer * _Nonnull unused_timer) {
            [WCDirectWindowControl applySettingsToAllWindows];
        }];

        // Make sure the timer doesn't prevent the app from quitting
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    });
}
