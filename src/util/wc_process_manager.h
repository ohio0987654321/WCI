/**
 * @file wc_process_manager.h
 * @brief Process management utilities for WindowControlInjector
 *
 * This file defines a class that provides utilities for process management,
 * including child process detection and application-specific process handling.
 */

#ifndef WC_PROCESS_MANAGER_H
#define WC_PROCESS_MANAGER_H

#import <Foundation/Foundation.h>
#import "../core/wc_window_bridge.h"

/**
 * @brief Class for process management utilities
 *
 * This class provides utilities for managing processes, including
 * detecting child processes and handling application-specific
 * process hierarchies.
 */
@interface WCProcessManager : NSObject

/**
 * @brief Get child processes for a given PID
 *
 * @param pid The process ID to get children for
 * @return Array of NSNumbers containing child process IDs
 */
+ (NSArray<NSNumber *> *)getChildProcessesForPID:(pid_t)pid;

/**
 * @brief Get the name of a process
 *
 * @param pid The process ID to get the name for
 * @return The process name
 */
+ (NSString *)getProcessNameForPID:(pid_t)pid;

/**
 * @brief Get Electron renderer processes for a main process
 *
 * @param mainPID The main Electron process ID
 * @return Array of NSNumbers containing renderer process IDs
 */
+ (NSArray<NSNumber *> *)getElectronRendererProcessesForMainPID:(pid_t)mainPID;

/**
 * @brief Get Chrome renderer processes for a main process
 *
 * @param mainPID The main Chrome process ID
 * @return Array of NSNumbers containing renderer process IDs
 */
+ (NSArray<NSNumber *> *)getChromeRendererProcessesForMainPID:(pid_t)mainPID;

/**
 * @brief Get the application path for a process
 *
 * @param pid The process ID to get the path for
 * @return The application bundle path or nil if not found
 */
+ (NSString *)getApplicationPathForPID:(pid_t)pid;

@end

#endif /* WC_PROCESS_MANAGER_H */
