/**
 * @file wc_window_bridge.h
 * @brief Unified window detection for WindowControlInjector
 *
 * This file defines a bridge class that provides a unified interface
 * for detecting and managing windows across both AppKit and non-AppKit
 * applications, combining both detection approaches for comprehensive coverage.
 */

#ifndef WC_WINDOW_BRIDGE_H
#define WC_WINDOW_BRIDGE_H

#import <Foundation/Foundation.h>
#import "wc_window_info.h"

// Application types for special handling
typedef NS_ENUM(NSUInteger, WCApplicationType) {
    WCApplicationTypeUnknown,
    WCApplicationTypeStandard,
    WCApplicationTypeElectron,
    WCApplicationTypeChrome
};

/**
 * @brief Unified window detection bridge
 *
 * This class provides methods for detecting and managing windows
 * across both AppKit and non-AppKit applications, using a dual-detection
 * approach that combines both [NSApp windows] for AppKit apps and
 * CGWindowListCopyWindowInfo with PID filtering for non-AppKit apps.
 */
@interface WCWindowBridge : NSObject

/**
 * @brief Initialize the window bridge system
 *
 * This method performs additional setup beyond the standard Objective-C +initialize method.
 * It registers known application types and prepares the bridge for operation.
 */
+ (void)setupWindowBridge;

/**
 * @brief Get all windows for the current application
 *
 * This method uses a dual-detection approach to find all windows
 * in the current application, combining both AppKit and CGS methods.
 *
 * @return An array of WCWindowInfo objects for all detected windows
 */
+ (NSArray<WCWindowInfo *> *)getAllWindowsForCurrentApplication;

/**
 * @brief Get all windows for a specific process ID
 *
 * This method finds all windows belonging to the specified process ID,
 * including checking for child processes that might have their own windows.
 *
 * @param pid The process ID to get windows for
 * @return An array of WCWindowInfo objects for all detected windows
 */
+ (NSArray<WCWindowInfo *> *)getAllWindowsForPID:(pid_t)pid;

/**
 * @brief Get all windows for an application with a specific path
 *
 * This method finds all windows belonging to the application at the
 * specified path, including checking for child processes.
 *
 * @param path The path to the application to get windows for
 * @return An array of WCWindowInfo objects for all detected windows
 */
+ (NSArray<WCWindowInfo *> *)getAllWindowsForApplicationWithPath:(NSString *)path;

/**
 * @brief Get all child processes for a given process ID
 *
 * This method finds all child processes of the specified process ID.
 *
 * @param pid The parent process ID
 * @return An array of child process IDs
 */
+ (NSArray<NSNumber *> *)getChildProcessesForPID:(pid_t)pid;

/**
 * @brief Protect all windows for a specific process ID
 *
 * This method makes all windows belonging to the specified process ID
 * invisible to screen recording.
 *
 * @param pid The process ID to protect windows for
 * @return YES if all windows were protected successfully, NO otherwise
 */
+ (BOOL)protectAllWindowsForPID:(pid_t)pid;

/**
 * @brief Set the level of all windows for a specific process ID
 *
 * This method sets the window level for all windows belonging to
 * the specified process ID.
 *
 * @param pid The process ID to set window levels for
 * @param level The window level to set
 * @return YES if all window levels were set successfully, NO otherwise
 */
+ (BOOL)setLevelForAllWindowsForPID:(pid_t)pid level:(NSWindowLevel)level;

/**
 * @brief Detect the application type
 *
 * This method detects what type of application is running (standard, Electron, Chrome)
 * to enable special handling for different application architectures.
 *
 * @param bundlePath The path to the application bundle
 * @return The detected application type
 */
+ (WCApplicationType)detectApplicationTypeForPath:(NSString *)bundlePath;

/**
 * @brief Get Electron renderer processes for a given main process
 *
 * This method finds all renderer processes associated with an Electron main process.
 * Electron apps use a multi-process architecture where windows may be created by renderer processes.
 *
 * @param mainPID The main Electron process ID
 * @return An array of renderer process IDs
 */
+ (NSArray<NSNumber *> *)getElectronRendererProcessesForMainPID:(pid_t)mainPID;

/**
 * @brief Get Chrome renderer processes for a given main process
 *
 * This method finds all renderer processes associated with a Chrome main process.
 * Chrome uses a complex multi-process architecture with site isolation.
 *
 * @param mainPID The main Chrome process ID
 * @return An array of renderer process IDs
 */
+ (NSArray<NSNumber *> *)getChromeRendererProcessesForMainPID:(pid_t)mainPID;

/**
 * @brief Find windows with delayed creation
 *
 * This method specifically looks for windows that might be created with a delay
 * after the application starts, which is common in Electron apps.
 *
 * @param pid The process ID to scan for delayed windows
 * @param existingWindows Windows that have already been detected
 * @return An array of newly detected windows
 */
+ (NSArray<WCWindowInfo *> *)findDelayedWindowsForPID:(pid_t)pid excludingWindows:(NSArray<WCWindowInfo *> *)existingWindows;

@end

#endif /* WC_WINDOW_BRIDGE_H */
