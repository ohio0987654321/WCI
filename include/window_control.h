/**
 * @file window_control.h
 * @brief Main public API for WindowControlInjector
 *
 * This file defines the main public API for WindowControlInjector,
 * providing direct window control capabilities and the ability to
 * modify window and application behaviors through a unified interface
 * that works with both AppKit and non-AppKit applications.
 */

#ifndef WINDOW_CONTROL_H
#define WINDOW_CONTROL_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// Import the core components
#import "../src/core/wc_window_protector.h"
#import "../src/core/wc_window_bridge.h"
#import "../src/core/wc_window_scanner.h"
#import "../src/core/wc_window_info.h"
#import "../src/util/logger.h"
#import "../src/util/wc_cgs_types.h"
#import "injector.h"

/**
 * @brief Main class for controlling window properties and behaviors
 *
 * This class provides methods for directly controlling window properties
 * and behaviors, as well as applying profiles for common use cases.
 */
@interface WCWindowControl : NSObject

/**
 * @brief Get the shared window control instance
 *
 * @return Shared instance of WCWindowControl
 */
+ (instancetype)sharedControl;

/**
 * @brief Make a window invisible to screen recording
 *
 * This method modifies the window's sharing type to make it invisible
 * to screen recording tools and screenshot applications.
 *
 * @param window Window to protect
 * @return YES if successful, NO otherwise
 */
- (BOOL)makeWindowInvisibleToScreenRecording:(NSWindow *)window;

/**
 * @brief Make a window click-through (ignores mouse events)
 *
 * This method modifies the window to ignore mouse events, allowing clicks
 * to pass through to windows behind it.
 *
 * @param window Window to modify
 * @param clickThrough YES to make the window click-through, NO to restore normal behavior
 * @return YES if successful, NO otherwise
 */
- (BOOL)setWindow:(NSWindow *)window clickThrough:(BOOL)clickThrough;

/**
 * @brief Prevent a window from receiving keyboard focus
 *
 * This method modifies the window to prevent it from receiving keyboard focus,
 * making it non-interactable with the keyboard.
 *
 * @param window Window to modify
 * @param unfocusable YES to make the window unfocusable, NO to restore normal behavior
 * @return YES if successful, NO otherwise
 */
- (BOOL)setWindow:(NSWindow *)window unfocusable:(BOOL)unfocusable;

/**
 * @brief Set the alpha value of a window
 *
 * This method sets the alpha (transparency) value of the window.
 *
 * @param window Window to modify
 * @param alphaValue Alpha value from 0.0 (fully transparent) to 1.0 (fully opaque)
 * @return YES if successful, NO otherwise
 */
- (BOOL)setWindow:(NSWindow *)window alpha:(CGFloat)alphaValue;

/**
 * @brief Hide an application from the Dock
 *
 * This method modifies the application to be hidden from the Dock.
 *
 * @param application Application to modify
 * @return YES if successful, NO otherwise
 */
- (BOOL)hideApplicationFromDock:(NSApplication *)application;

/**
 * @brief Hide an application from the status bar
 *
 * This method modifies the application to be hidden from the status bar.
 *
 * @param application Application to modify
 * @return YES if successful, NO otherwise
 */
- (BOOL)hideApplicationFromStatusBar:(NSApplication *)application;

/**
 * @brief Set the log level for WindowControlInjector
 *
 * This method sets the logging verbosity for the library.
 *
 * @param level Log level to set
 */
- (void)setLogLevel:(WCLogLevel)level;

/**
 * @brief Get the current log level
 *
 * @return Current log level
 */
- (WCLogLevel)logLevel;

@end

// Re-export the public API functions for backward compatibility
#define WCSetLogLevel(level) [[WCWindowControl sharedControl] setLogLevel:level]

// Version information
NSString *WCGetVersionString(void);
NSString *WCGetBuildDateString(void);

#endif /* WINDOW_CONTROL_H */
