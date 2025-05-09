/**
 * @file direct_window_control.h
 * @brief Header for direct window control functionality
 */

#ifndef DIRECT_WINDOW_CONTROL_H
#define DIRECT_WINDOW_CONTROL_H

#import <AppKit/AppKit.h>

/**
 * @class WCDirectWindowControl
 * @brief Direct control of window and application properties
 *
 * This class provides direct access to window and application properties
 * using Objective-C messaging rather than relying on property overrides.
 * It's specifically designed to enhance screen recording protection and
 * window visibility control beyond what's possible with NSWindow property
 * manipulation alone.
 */
@interface WCDirectWindowControl : NSObject

/**
 * Apply settings that make a window invisible to screen recording
 * @param window The window to modify
 */
+ (void)applyAntiScreenRecordingSettings:(NSWindow *)window;

/**
 * Apply stealth mode settings to hide an application from dock and UI
 * @param application The application to modify
 */
+ (void)applyStealthModeToApplication:(NSApplication *)application;

/**
 * Make a window clickable and movable without allowing it to receive focus
 * @param window The window to modify
 */
+ (void)makeWindowClickable:(NSWindow *)window;

/**
 * Apply all settings to all windows in the current application
 * This is usually called automatically on load
 */
+ (void)applySettingsToAllWindows;

/**
 * Control whether windows can receive focus and interaction
 * @param allow YES to allow windows to become key/main, NO to prevent focus
 */
+ (void)setAllowWindowInteraction:(BOOL)allow;

/**
 * Get the current window interaction setting
 * @return YES if windows can receive focus, NO otherwise
 */
+ (BOOL)allowWindowInteraction;

@end

// These are implementation-only functions declared here to silence warnings
BOOL wci_canBecomeKey(id self, SEL _cmd);
BOOL wci_canBecomeMain(id self, SEL _cmd);

#endif /* DIRECT_WINDOW_CONTROL_H */
