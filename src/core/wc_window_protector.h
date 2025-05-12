/**
 * @file wc_window_protector.h
 * @brief Window protection utilities for WindowControlInjector
 *
 * This file defines a class that provides window protection capabilities,
 * applying screen recording protection and window level adjustments to windows
 * in a consistent way regardless of the underlying window system.
 */

#ifndef WC_WINDOW_PROTECTOR_H
#define WC_WINDOW_PROTECTOR_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "../util/wc_cgs_types.h"

@class WCWindowInfo;

/**
 * @brief Class for window protection operations
 *
 * This class provides utility methods for protecting windows from screen recording
 * and setting window levels. It handles both AppKit and non-AppKit windows through
 * a common interface, using the appropriate mechanism based on window type.
 */
@interface WCWindowProtector : NSObject

/**
 * @brief Set the debounce interval for window protection operations
 *
 * This interval determines how frequently the same window can be re-protected,
 * which helps prevent flickering when protection is applied multiple times in
 * rapid succession.
 *
 * @param interval The time interval in seconds to debounce protection operations
 */
+ (void)setDebounceInterval:(NSTimeInterval)interval;

/**
 * @brief Get the current debounce interval
 *
 * @return The current debounce interval in seconds
 */
+ (NSTimeInterval)debounceInterval;

/**
 * @brief Clear the debounce history for all windows
 *
 * This resets the tracking of when windows were last protected.
 */
+ (void)clearDebounceHistory;

/**
 * @brief Make a window invisible to screen recording
 *
 * @param windowID The CGWindowID of the window to protect
 * @return YES if successful, NO if an error occurred
 */
+ (BOOL)makeWindowInvisibleToScreenRecording:(CGWindowID)windowID;

/**
 * @brief Make a window invisible to screen recording
 *
 * @param window The NSWindow to protect
 * @return YES if successful, NO if an error occurred
 */
+ (BOOL)makeNSWindowInvisibleToScreenRecording:(NSWindow *)window;

/**
 * @brief Make a window invisible to screen recording
 *
 * @param windowInfo The WCWindowInfo object representing the window to protect
 * @return YES if successful, NO if an error occurred
 */
+ (BOOL)makeWindowInfoInvisibleToScreenRecording:(WCWindowInfo *)windowInfo;

/**
 * @brief Protect a window using the most appropriate method
 *
 * This method tries multiple approaches (CGS API, AppKit, CALayer) to protect
 * the window, falling back as needed.
 *
 * @param window The window object to protect (NSWindow or any window-like object)
 * @return YES if successful, NO if all protection methods failed
 */
+ (BOOL)protectWindowWithFallback:(id)window;

/**
 * @brief Set the level of a window
 *
 * @param windowID The CGWindowID of the window
 * @param level The window level to set
 * @return YES if successful, NO if an error occurred
 */
+ (BOOL)setWindowLevel:(CGWindowID)windowID toLevel:(NSWindowLevel)level;

/**
 * @brief Set the level of a window
 *
 * @param window The NSWindow to modify
 * @param level The window level to set
 * @return YES if successful, NO if an error occurred
 */
+ (BOOL)setNSWindowLevel:(NSWindow *)window toLevel:(NSWindowLevel)level;

/**
 * @brief Set the level of a window
 *
 * @param windowInfo The WCWindowInfo object representing the window
 * @param level The window level to set
 * @return YES if successful, NO if an error occurred
 */
+ (BOOL)setWindowInfoLevel:(WCWindowInfo *)windowInfo toLevel:(NSWindowLevel)level;

@end

#endif /* WC_WINDOW_PROTECTOR_H */
