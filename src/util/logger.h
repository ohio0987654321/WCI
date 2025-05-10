/**
 * @file logger.h
 * @brief Logging utilities for WindowControlInjector
 *
 * This file defines the logging utilities used by WindowControlInjector.
 */

#ifndef LOGGER_H
#define LOGGER_H

#import <Foundation/Foundation.h>

// Log levels
typedef NS_ENUM(NSInteger, WCLogLevel) {
    WCLogLevelNone    = 0,
    WCLogLevelError   = 1,
    WCLogLevelWarning = 2,
    WCLogLevelInfo    = 3,
    WCLogLevelDebug   = 4
};

// Error domain for WindowControlInjector
extern NSErrorDomain const WCErrorDomain;

// Profile name constants
extern NSString * const WCProfileNameInvisible;
extern NSString * const WCProfileNameStealth;
extern NSString * const WCProfileNameUnfocusable;
extern NSString * const WCProfileNameClickThrough;

/**
 * @brief Logger class for WindowControlInjector
 *
 * This class provides logging functionality for the WindowControlInjector.
 */
@interface WCLogger : NSObject

/**
 * @brief Get the shared logger instance
 *
 * @return The shared logger instance
 */
+ (instancetype)sharedLogger;

/**
 * @brief Set whether logging is enabled
 *
 * @param enabled YES to enable logging, NO to disable
 */
- (void)setLoggingEnabled:(BOOL)enabled;

/**
 * @brief Check if logging is enabled
 *
 * @return YES if logging is enabled, NO otherwise
 */
- (BOOL)isLoggingEnabled;

/**
 * @brief Set the log level
 *
 * @param level The log level to set
 */
- (void)setLogLevel:(WCLogLevel)level;

/**
 * @brief Get the current log level
 *
 * @return The current log level
 */
- (WCLogLevel)logLevel;

/**
 * @brief Log an error message
 *
 * @param format The format string
 * @param ... The format arguments
 */
- (void)logError:(NSString *)format, ...;

/**
 * @brief Log a warning message
 *
 * @param format The format string
 * @param ... The format arguments
 */
- (void)logWarning:(NSString *)format, ...;

/**
 * @brief Log an info message
 *
 * @param format The format string
 * @param ... The format arguments
 */
- (void)logInfo:(NSString *)format, ...;

/**
 * @brief Log a debug message
 *
 * @param format The format string
 * @param ... The format arguments
 */
- (void)logDebug:(NSString *)format, ...;

@end

// Convenience macros
#define WCLogError(fmt, ...)   [[WCLogger sharedLogger] logError:fmt, ##__VA_ARGS__]
#define WCLogWarning(fmt, ...) [[WCLogger sharedLogger] logWarning:fmt, ##__VA_ARGS__]
#define WCLogInfo(fmt, ...)    [[WCLogger sharedLogger] logInfo:fmt, ##__VA_ARGS__]
#define WCLogDebug(fmt, ...)   [[WCLogger sharedLogger] logDebug:fmt, ##__VA_ARGS__]

// C function wrappers for the public API
void WCSetLoggingEnabled(BOOL enabled);
void WCSetLogLevel(NSInteger level);

#endif /* LOGGER_H */
