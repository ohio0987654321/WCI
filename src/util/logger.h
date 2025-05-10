/**
 * @file logger.h
 * @brief Logging utilities for WindowControlInjector
 *
 * This file defines an improved logging system with category support,
 * customizable handlers, and better control over log output.
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

/**
 * @brief Encapsulates a log message with contextual information
 */
@interface WCLogMessage : NSObject

/**
 * @brief The timestamp when the message was created
 */
@property (nonatomic, readonly) NSDate *timestamp;

/**
 * @brief The log level of the message
 */
@property (nonatomic, readonly) WCLogLevel level;

/**
 * @brief The category of the message
 */
@property (nonatomic, readonly) NSString *category;

/**
 * @brief The message text
 */
@property (nonatomic, readonly) NSString *message;

/**
 * @brief The source file where the log was generated (if available)
 */
@property (nonatomic, readonly) NSString *sourceFile;

/**
 * @brief The line number where the log was generated (if available)
 */
@property (nonatomic, readonly) NSInteger lineNumber;

/**
 * @brief The function name where the log was generated (if available)
 */
@property (nonatomic, readonly) NSString *function;

/**
 * @brief Additional context data associated with the log message
 */
@property (nonatomic, readonly) NSDictionary *contextData;

/**
 * @brief Create a new log message
 *
 * @param level The log level
 * @param category The log category
 * @param message The message text
 * @param file The source file (optional)
 * @param line The line number (optional)
 * @param function The function name (optional)
 * @param contextData Additional context data (optional)
 * @return A new log message instance
 */
+ (instancetype)messageWithLevel:(WCLogLevel)level
                        category:(NSString *)category
                         message:(NSString *)message
                            file:(NSString *)file
                            line:(NSInteger)line
                        function:(NSString *)function
                     contextData:(NSDictionary *)contextData;

/**
 * @brief Get a formatted string representation of the log message
 *
 * @return A formatted string representation
 */
- (NSString *)formattedMessage;

/**
 * @brief Get a string representation of the log level
 *
 * @param level The log level
 * @return A string representation of the log level
 */
+ (NSString *)stringForLogLevel:(WCLogLevel)level;

@end

/**
 * @brief Protocol for custom log handlers
 */
@protocol WCLogHandler <NSObject>

/**
 * @brief Handle a log message
 *
 * @param message The log message to handle
 */
- (void)handleLogMessage:(WCLogMessage *)message;

@optional
/**
 * @brief Configure the log handler with options
 *
 * @param options Configuration options
 * @return YES if configuration was successful, NO otherwise
 */
- (BOOL)configureWithOptions:(NSDictionary *)options;

@end

/**
 * @brief Enhanced logger class for WindowControlInjector
 */
@interface WCLogger : NSObject

/**
 * @brief Get the shared logger instance
 *
 * @return The shared logger instance
 */
+ (instancetype)sharedLogger;

/**
 * @brief Set whether logging is enabled globally
 *
 * @param enabled YES to enable logging, NO to disable
 */
- (void)setLoggingEnabled:(BOOL)enabled;

/**
 * @brief Check if logging is enabled globally
 *
 * @return YES if logging is enabled, NO otherwise
 */
- (BOOL)isLoggingEnabled;

/**
 * @brief Set the global log level
 *
 * @param level The log level to set
 */
- (void)setLogLevel:(WCLogLevel)level;

/**
 * @brief Get the current global log level
 *
 * @return The current log level
 */
- (WCLogLevel)logLevel;

/**
 * @brief Set whether logging is enabled for a specific category
 *
 * @param enabled YES to enable logging, NO to disable
 * @param category The category to set
 */
- (void)setLoggingEnabled:(BOOL)enabled forCategory:(NSString *)category;

/**
 * @brief Check if logging is enabled for a specific category
 *
 * @param category The category to check
 * @return YES if logging is enabled for the category, NO otherwise
 */
- (BOOL)isLoggingEnabledForCategory:(NSString *)category;

/**
 * @brief Set the log level for a specific category
 *
 * @param level The log level to set
 * @param category The category to set
 */
- (void)setLogLevel:(WCLogLevel)level forCategory:(NSString *)category;

/**
 * @brief Get the log level for a specific category
 *
 * @param category The category to check
 * @return The log level for the category
 */
- (WCLogLevel)logLevelForCategory:(NSString *)category;

/**
 * @brief Add a log handler
 *
 * @param handler The log handler to add
 * @param identifier A unique identifier for the handler
 */
- (void)addLogHandler:(id<WCLogHandler>)handler withIdentifier:(NSString *)identifier;

/**
 * @brief Remove a log handler
 *
 * @param identifier The identifier of the handler to remove
 * @return YES if the handler was removed, NO if it wasn't found
 */
- (BOOL)removeLogHandlerWithIdentifier:(NSString *)identifier;

/**
 * @brief Set the path for file logging
 *
 * @param path The path to log to
 * @return YES if the log file was set up successfully, NO otherwise
 */
- (BOOL)setLogFilePath:(NSString *)path;

/**
 * @brief Log a message
 *
 * @param level The log level
 * @param category The log category
 * @param format The format string
 * @param ... The format arguments
 */
- (void)logWithLevel:(WCLogLevel)level
             category:(NSString *)category
               format:(NSString *)format, ... NS_FORMAT_FUNCTION(3,4);

/**
 * @brief Log a message with additional context
 *
 * @param level The log level
 * @param category The log category
 * @param contextData Additional context data
 * @param format The format string
 * @param ... The format arguments
 */
- (void)logWithLevel:(WCLogLevel)level
             category:(NSString *)category
          contextData:(NSDictionary *)contextData
               format:(NSString *)format, ... NS_FORMAT_FUNCTION(4,5);

/**
 * @brief Log a message with source information
 *
 * This is the main logging method used by the macros
 *
 * @param level The log level
 * @param category The log category
 * @param file The source file
 * @param line The line number
 * @param function The function name
 * @param format The format string
 * @param ... The format arguments
 */
- (void)logWithLevel:(WCLogLevel)level
             category:(NSString *)category
                 file:(const char *)file
                 line:(NSInteger)line
             function:(const char *)function
               format:(NSString *)format, ... NS_FORMAT_FUNCTION(6,7);

/**
 * @brief Log a message with source information and context data
 *
 * @param level The log level
 * @param category The log category
 * @param file The source file
 * @param line The line number
 * @param function The function name
 * @param contextData Additional context data
 * @param format The format string
 * @param ... The format arguments
 */
- (void)logWithLevel:(WCLogLevel)level
             category:(NSString *)category
                 file:(const char *)file
                 line:(NSInteger)line
             function:(const char *)function
          contextData:(NSDictionary *)contextData
               format:(NSString *)format, ... NS_FORMAT_FUNCTION(7,8);

/**
 * @brief Legacy log methods for backward compatibility
 */
- (void)logError:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);
- (void)logWarning:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);
- (void)logInfo:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);
- (void)logDebug:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

@end

// Default log categories
extern NSString * const WCLogCategoryGeneral;
extern NSString * const WCLogCategoryInjection;
extern NSString * const WCLogCategoryInterception;
extern NSString * const WCLogCategoryConfiguration;
extern NSString * const WCLogCategoryApplication;
extern NSString * const WCLogCategoryWindow;
extern NSString * const WCLogCategoryLaunch;

// Simple macros for direct logging without do-while wrapping
// These match the exact format used in the existing codebase
#define WCLogError(category, fmt, ...) \
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelError \
                                 category:category \
                                     file:__FILE__ \
                                     line:__LINE__ \
                                 function:__PRETTY_FUNCTION__ \
                                   format:fmt, ##__VA_ARGS__]

#define WCLogWarning(category, fmt, ...) \
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning \
                                 category:category \
                                     file:__FILE__ \
                                     line:__LINE__ \
                                 function:__PRETTY_FUNCTION__ \
                                   format:fmt, ##__VA_ARGS__]

#define WCLogInfo(category, fmt, ...) \
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo \
                                 category:category \
                                     file:__FILE__ \
                                     line:__LINE__ \
                                 function:__PRETTY_FUNCTION__ \
                                   format:fmt, ##__VA_ARGS__]

#define WCLogDebug(category, fmt, ...) \
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug \
                                 category:category \
                                     file:__FILE__ \
                                     line:__LINE__ \
                                 function:__PRETTY_FUNCTION__ \
                                   format:fmt, ##__VA_ARGS__]

// Context data macros
#define WCLogErrorWithContext(category, context, fmt, ...) \
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelError \
                                 category:category \
                                     file:__FILE__ \
                                     line:__LINE__ \
                                 function:__PRETTY_FUNCTION__ \
                              contextData:context \
                                   format:fmt, ##__VA_ARGS__]

#define WCLogWarningWithContext(category, context, fmt, ...) \
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning \
                                 category:category \
                                     file:__FILE__ \
                                     line:__LINE__ \
                                 function:__PRETTY_FUNCTION__ \
                              contextData:context \
                                   format:fmt, ##__VA_ARGS__]

#define WCLogInfoWithContext(category, context, fmt, ...) \
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo \
                                 category:category \
                                     file:__FILE__ \
                                     line:__LINE__ \
                                 function:__PRETTY_FUNCTION__ \
                              contextData:context \
                                   format:fmt, ##__VA_ARGS__]

#define WCLogDebugWithContext(category, context, fmt, ...) \
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug \
                                 category:category \
                                     file:__FILE__ \
                                     line:__LINE__ \
                                 function:__PRETTY_FUNCTION__ \
                              contextData:context \
                                   format:fmt, ##__VA_ARGS__]

// C function wrappers for the public API
void WCSetLoggingEnabled(BOOL enabled);
void WCSetLogLevel(NSInteger level);
BOOL WCSetLogFilePath(NSString *path);
void WCSetLoggingEnabledForCategory(BOOL enabled, NSString *category);
void WCSetLogLevelForCategory(NSInteger level, NSString *category);

#endif /* LOGGER_H */
