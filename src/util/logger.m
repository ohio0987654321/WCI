/**
 * @file logger.m
 * @brief Implementation of the logging utilities for WindowControlInjector
 */

#import "logger.h"
#import <os/log.h>

// Define the profile name constants
NSString * const WCProfileNameInvisible = @"invisible";
NSString * const WCProfileNameStealth = @"stealth";
NSString * const WCProfileNameUnfocusable = @"unfocusable";
NSString * const WCProfileNameClickThrough = @"click-through";

// Define the error domain
NSErrorDomain const WCErrorDomain = @"com.windowcontrolinjector.error";

@implementation WCLogger {
    BOOL _loggingEnabled;
    WCLogLevel _logLevel;
    os_log_t _osLog;
}

+ (instancetype)sharedLogger {
    static WCLogger *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[WCLogger alloc] init];
    });

    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _loggingEnabled = YES;
        _logLevel = WCLogLevelInfo;
        _osLog = os_log_create("com.windowcontrolinjector", "general");
    }
    return self;
}

- (void)setLoggingEnabled:(BOOL)enabled {
    _loggingEnabled = enabled;
}

- (BOOL)isLoggingEnabled {
    return _loggingEnabled;
}

- (void)setLogLevel:(WCLogLevel)level {
    _logLevel = level;
}

- (WCLogLevel)logLevel {
    return _logLevel;
}

- (void)logWithLevel:(WCLogLevel)level format:(NSString *)format, ... {
    if (!_loggingEnabled || level > _logLevel) {
        return;
    }

    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSString *levelString;
    os_log_type_t logType;

    switch (level) {
        case WCLogLevelError:
            levelString = @"ERROR";
            logType = OS_LOG_TYPE_ERROR;
            break;
        case WCLogLevelWarning:
            levelString = @"WARNING";
            logType = OS_LOG_TYPE_DEFAULT;
            break;
        case WCLogLevelInfo:
            levelString = @"INFO";
            logType = OS_LOG_TYPE_INFO;
            break;
        case WCLogLevelDebug:
            levelString = @"DEBUG";
            logType = OS_LOG_TYPE_DEBUG;
            break;
        default:
            levelString = @"UNKNOWN";
            logType = OS_LOG_TYPE_DEFAULT;
            break;
    }

    NSString *formattedMessage = [NSString stringWithFormat:@"[WindowControlInjector] [%@] %@", levelString, message];

    // Log to os_log for Console app integration
    os_log_with_type(_osLog, logType, "%{public}@", formattedMessage);

    // Log to stderr for command-line visibility
    if (level <= WCLogLevelWarning || _logLevel >= WCLogLevelDebug) {
        fprintf(stderr, "%s\n", [formattedMessage UTF8String]);
    }
}

- (void)logError:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    [self logWithLevel:WCLogLevelError format:@"%@", message];
}

- (void)logWarning:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    [self logWithLevel:WCLogLevelWarning format:@"%@", message];
}

- (void)logInfo:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    [self logWithLevel:WCLogLevelInfo format:@"%@", message];
}

- (void)logDebug:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    [self logWithLevel:WCLogLevelDebug format:@"%@", message];
}

@end

// C function wrappers for the public API
void WCSetLoggingEnabled(BOOL enabled) {
    [[WCLogger sharedLogger] setLoggingEnabled:enabled];
}

void WCSetLogLevel(NSInteger level) {
    [[WCLogger sharedLogger] setLogLevel:(WCLogLevel)level];
}
