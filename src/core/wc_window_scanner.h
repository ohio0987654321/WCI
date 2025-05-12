/**
 * @file wc_window_scanner.h
 * @brief Periodic window scanning and protection for WindowControlInjector
 *
 * This file defines a class that periodically scans for and protects windows
 * to ensure consistent window state, handling new windows that appear after
 * initialization.
 */

#ifndef WC_WINDOW_SCANNER_H
#define WC_WINDOW_SCANNER_H

#import <Foundation/Foundation.h>
#import "wc_window_bridge.h"

/**
 * @brief Class for periodic window scanning and protection
 *
 * This class provides a mechanism to periodically scan for windows and
 * apply protections to them, with configurable scan intervals and
 * adaptive scanning based on performance metrics.
 */
@interface WCWindowScanner : NSObject

/**
 * @brief Get the shared scanner instance
 *
 * @return Shared singleton instance of WCWindowScanner
 */
+ (instancetype)sharedScanner;

/**
 * @brief Start scanning with a specified interval
 *
 * @param interval The time interval in seconds between scans
 */
- (void)startScanningWithInterval:(NSTimeInterval)interval;

/**
 * @brief Stop scanning
 */
- (void)stopScanning;

/**
 * @brief Check if scanning is active
 *
 * @return YES if scanning is active, NO otherwise
 */
- (BOOL)isScanning;

/**
 * @brief Set whether to use adaptive scanning
 *
 * When adaptive scanning is enabled, the scanner will adjust its
 * scan interval based on window count and system performance.
 *
 * @param adaptive Whether to use adaptive scanning
 */
- (void)setAdaptiveScanning:(BOOL)adaptive;

/**
 * @brief Get the current scan interval
 *
 * @return The current scan interval in seconds
 */
- (NSTimeInterval)currentScanInterval;

/**
 * @brief Perform an immediate scan
 *
 * This method triggers an immediate scan, regardless of the scan interval.
 * It can be used to update window protections immediately after a known state change.
 */
- (void)scanNow;

/**
 * @brief Enable debouncing of window protection operations
 *
 * When enabled, protections are applied with a slight delay to avoid
 * rapid toggling that can cause visual flickering. Helpful for Electron apps.
 *
 * @param debounceEnabled Whether to enable protection debouncing
 * @param interval The time interval in seconds to debounce protection operations
 */
- (void)setProtectionDebounce:(BOOL)debounceEnabled withInterval:(NSTimeInterval)interval;

/**
 * @brief Set application-specific scanning behavior
 *
 * This configures the scanner with special handling for specific application types
 * like Electron apps or Chrome.
 *
 * @param appType The type of application being protected
 */
- (void)configureForApplicationType:(WCApplicationType)appType;

/**
 * @brief Enable advanced multi-process window handling
 *
 * Some applications use complex multi-window, multi-process architectures that require special treatment.
 * This method enables optimizations for applications like Electron apps (VS Code, Slack, etc.) and
 * browsers with multi-process architecture (Chrome, etc.).
 *
 * @param options Optional dictionary with application-specific settings
 */
- (void)enableAdvancedMultiProcessHandling:(NSDictionary *)options;

@end

#endif /* WC_WINDOW_SCANNER_H */
