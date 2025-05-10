/**
 * @file logger.m
 * @brief Implementation of logging utilities for WindowControlInjector
 */

#import "logger.h"
#import <os/log.h>
#import <pthread.h>

// Define the default log categories
NSString * const WCLogCategoryGeneral = @"General";
NSString * const WCLogCategoryInjection = @"Injection";
NSString * const WCLogCategoryInterception = @"Interception";
NSString * const WCLogCategoryConfiguration = @"Configuration";
NSString * const WCLogCategoryApplication = @"Application";
NSString * const WCLogCategoryWindow = @"Window";
NSString * const WCLogCategoryLaunch = @"Launch";

#pragma mark - WCLogMessage Implementation

@implementation WCLogMessage

+ (instancetype)messageWithLevel:(WCLogLevel)level
                        category:(NSString *)category
                         message:(NSString *)message
                            file:(NSString *)file
                            line:(NSInteger)line
                        function:(NSString *)function
                     contextData:(NSDictionary *)contextData {
    WCLogMessage *logMessage = [[WCLogMessage alloc] init];
    if (logMessage) {
        logMessage->_timestamp = [NSDate date];
        logMessage->_level = level;
        logMessage->_category = [category copy] ?: @"Uncategorized";
        logMessage->_message = [message copy] ?: @"";
        logMessage->_sourceFile = [file copy];
        logMessage->_lineNumber = line;
        logMessage->_function = [function copy];
        logMessage->_contextData = [contextData copy];
    }
    return logMessage;
}

- (NSString *)formattedMessage {
    NSMutableString *formatted = [NSMutableString string];

    // Add timestamp in standard format
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    [formatted appendFormat:@"[%@] ", [formatter stringFromDate:_timestamp]];

    // Add level
    [formatted appendFormat:@"[%@] ", [WCLogMessage stringForLogLevel:_level]];

    // Add category
    [formatted appendFormat:@"[%@] ", _category];

    // Add message
    [formatted appendString:_message];

    // Add source information if available
    if (_sourceFile.length > 0) {
        NSString *sourceFile = [_sourceFile lastPathComponent]; // Just the filename, not the full path
        [formatted appendFormat:@" (%@:%ld", sourceFile, (long)_lineNumber];

        if (_function.length > 0) {
            [formatted appendFormat:@", %@", _function];
        }

        [formatted appendString:@")"];
    }

    // Add context data if available
    if (_contextData.count > 0) {
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:_contextData
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&error];
        if (jsonData && !error) {
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            [formatted appendFormat:@"\nContext: %@", jsonString];
        }
    }

    return formatted;
}

+ (NSString *)stringForLogLevel:(WCLogLevel)level {
    switch (level) {
        case WCLogLevelError:
            return @"ERROR";
        case WCLogLevelWarning:
            return @"WARNING";
        case WCLogLevelInfo:
            return @"INFO";
        case WCLogLevelDebug:
            return @"DEBUG";
        default:
            return @"UNKNOWN";
    }
}

@end

#pragma mark - Console Log Handler

/**
 * Log handler that outputs to console (stderr and os_log)
 */
@interface WCConsoleLogHandler : NSObject <WCLogHandler>
@property (nonatomic, strong) os_log_t osLog;
@end

@implementation WCConsoleLogHandler

- (instancetype)init {
    self = [super init];
    if (self) {
        _osLog = os_log_create("com.windowcontrolinjector", "general");
    }
    return self;
}

- (void)handleLogMessage:(WCLogMessage *)message {
    // Map log level to os_log_type
    os_log_type_t logType;
    switch (message.level) {
        case WCLogLevelError:
            logType = OS_LOG_TYPE_ERROR;
            break;
        case WCLogLevelWarning:
            logType = OS_LOG_TYPE_DEFAULT;
            break;
        case WCLogLevelInfo:
            logType = OS_LOG_TYPE_INFO;
            break;
        case WCLogLevelDebug:
            logType = OS_LOG_TYPE_DEBUG;
            break;
        default:
            logType = OS_LOG_TYPE_DEFAULT;
            break;
    }

    NSString *formattedMessage = [message formattedMessage];

    // Log to os_log for Console app integration
    os_log_with_type(self.osLog, logType, "%{public}@", formattedMessage);

    // Log to stderr for command-line visibility
    // For Error and Warning, or if this is a debug or info message at Debug level
    if (message.level <= WCLogLevelWarning) {
        fprintf(stderr, "[WindowControlInjector] %s\n", [formattedMessage UTF8String]);
    }
}

- (BOOL)configureWithOptions:(NSDictionary *)options {
    NSString *subsystem = options[@"subsystem"];
    NSString *category = options[@"category"];

    if (subsystem && category) {
        self.osLog = os_log_create([subsystem UTF8String], [category UTF8String]);
        return YES;
    } else if (subsystem) {
        self.osLog = os_log_create([subsystem UTF8String], "general");
        return YES;
    }

    return NO;
}

@end

#pragma mark - File Log Handler

/**
 * Log handler that outputs to a file
 */
@interface WCFileLogHandler : NSObject <WCLogHandler>
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic) BOOL appendNewLine;
@property (nonatomic, strong) dispatch_queue_t fileQueue;
@end

@implementation WCFileLogHandler

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        _filePath = [path copy];
        _appendNewLine = YES;
        _fileQueue = dispatch_queue_create("com.windowcontrolinjector.filelogger", DISPATCH_QUEUE_SERIAL);

        if (![self setupFileHandle]) {
            return nil;
        }
    }
    return self;
}

- (BOOL)setupFileHandle {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // Create parent directories if needed
    NSString *directory = [_filePath stringByDeletingLastPathComponent];
    if (![fileManager fileExistsAtPath:directory]) {
        NSError *error = nil;
        if (![fileManager createDirectoryAtPath:directory
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:&error]) {
            fprintf(stderr, "[WindowControlInjector] Error creating log directory: %s\n",
                    [error.localizedDescription UTF8String]);
            return NO;
        }
    }

    // Create or open the file
    if (![fileManager fileExistsAtPath:_filePath]) {
        if (![fileManager createFileAtPath:_filePath contents:nil attributes:nil]) {
            fprintf(stderr, "[WindowControlInjector] Error creating log file: %s\n", [_filePath UTF8String]);
            return NO;
        }
    }

    // Open file for writing
    NSError *error = nil;
    _fileHandle = [NSFileHandle fileHandleForWritingToURL:[NSURL fileURLWithPath:_filePath]
                                                    error:&error];
    if (!_fileHandle) {
        fprintf(stderr, "[WindowControlInjector] Error opening log file: %s\n",
                [error.localizedDescription UTF8String]);
        return NO;
    }

    // Move to end of file
    [_fileHandle seekToEndOfFile];

    return YES;
}

- (void)handleLogMessage:(WCLogMessage *)message {
    // Format the log entry
    NSString *formattedMessage = [message formattedMessage];
    if (_appendNewLine) {
        formattedMessage = [formattedMessage stringByAppendingString:@"\n"];
    }

    // Write to file on a background queue
    NSData *data = [formattedMessage dataUsingEncoding:NSUTF8StringEncoding];
    dispatch_async(_fileQueue, ^{
        @try {
            [self.fileHandle writeData:data];
        }
        @catch (NSException *exception) {
            fprintf(stderr, "[WindowControlInjector] Error writing to log file: %s\n",
                    [exception.reason UTF8String]);

            // Try to reopen the file handle
            [self.fileHandle closeFile];
            self.fileHandle = nil;
            if ([self setupFileHandle]) {
                [self.fileHandle writeData:data];
            }
        }
    });
}

- (BOOL)configureWithOptions:(NSDictionary *)options {
    NSNumber *appendNewLine = options[@"appendNewLine"];
    if (appendNewLine) {
        _appendNewLine = [appendNewLine boolValue];
    }

    return YES;
}

- (void)dealloc {
    [_fileHandle closeFile];
}

@end

#pragma mark - WCLogger Implementation

@implementation WCLogger {
    // Thread safety
    pthread_mutex_t _mutex;

    // Global settings
    BOOL _loggingEnabled;
    WCLogLevel _logLevel;

    // Category-specific settings
    NSMutableDictionary<NSString *, NSNumber *> *_categoryEnabled;
    NSMutableDictionary<NSString *, NSNumber *> *_categoryLogLevels;

    // Log handlers
    NSMutableDictionary<NSString *, id<WCLogHandler>> *_logHandlers;
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
        // Initialize mutex
        pthread_mutex_init(&_mutex, NULL);

        // Default settings
        _loggingEnabled = YES;
        _logLevel = WCLogLevelInfo;

        // Initialize category maps
        _categoryEnabled = [NSMutableDictionary dictionary];
        _categoryLogLevels = [NSMutableDictionary dictionary];

        // Initialize handlers
        _logHandlers = [NSMutableDictionary dictionary];

        // Add console handler by default
        [self addLogHandler:[[WCConsoleLogHandler alloc] init] withIdentifier:@"console"];
    }
    return self;
}

- (void)setLoggingEnabled:(BOOL)enabled {
    pthread_mutex_lock(&_mutex);
    _loggingEnabled = enabled;
    pthread_mutex_unlock(&_mutex);
}

- (BOOL)isLoggingEnabled {
    pthread_mutex_lock(&_mutex);
    BOOL enabled = _loggingEnabled;
    pthread_mutex_unlock(&_mutex);

    return enabled;
}

- (void)setLogLevel:(WCLogLevel)level {
    pthread_mutex_lock(&_mutex);
    _logLevel = level;
    pthread_mutex_unlock(&_mutex);
}

- (WCLogLevel)logLevel {
    pthread_mutex_lock(&_mutex);
    WCLogLevel level = _logLevel;
    pthread_mutex_unlock(&_mutex);

    return level;
}

- (void)setLoggingEnabled:(BOOL)enabled forCategory:(NSString *)category {
    if (!category) return;

    pthread_mutex_lock(&_mutex);
    _categoryEnabled[category] = @(enabled);
    pthread_mutex_unlock(&_mutex);
}

- (BOOL)isLoggingEnabledForCategory:(NSString *)category {
    if (!category) return [self isLoggingEnabled];

    pthread_mutex_lock(&_mutex);
    NSNumber *enabled = _categoryEnabled[category];
    BOOL result = enabled ? [enabled boolValue] : _loggingEnabled;
    pthread_mutex_unlock(&_mutex);

    return result;
}

- (void)setLogLevel:(WCLogLevel)level forCategory:(NSString *)category {
    if (!category) return;

    pthread_mutex_lock(&_mutex);
    _categoryLogLevels[category] = @(level);
    pthread_mutex_unlock(&_mutex);
}

- (WCLogLevel)logLevelForCategory:(NSString *)category {
    if (!category) return [self logLevel];

    pthread_mutex_lock(&_mutex);
    NSNumber *level = _categoryLogLevels[category];
    WCLogLevel result = level ? [level integerValue] : _logLevel;
    pthread_mutex_unlock(&_mutex);

    return result;
}

- (void)addLogHandler:(id<WCLogHandler>)handler withIdentifier:(NSString *)identifier {
    if (!handler || !identifier) return;

    pthread_mutex_lock(&_mutex);
    _logHandlers[identifier] = handler;
    pthread_mutex_unlock(&_mutex);
}

- (BOOL)removeLogHandlerWithIdentifier:(NSString *)identifier {
    if (!identifier) return NO;

    pthread_mutex_lock(&_mutex);
    BOOL existed = (_logHandlers[identifier] != nil);
    [_logHandlers removeObjectForKey:identifier];
    pthread_mutex_unlock(&_mutex);

    return existed;
}

- (BOOL)setLogFilePath:(NSString *)path {
    if (!path) return NO;

    // Create a file handler
    WCFileLogHandler *fileHandler = [[WCFileLogHandler alloc] initWithPath:path];
    if (!fileHandler) {
        return NO;
    }

    // Add or replace the existing file handler
    [self addLogHandler:fileHandler withIdentifier:@"file"];
    return YES;
}

#pragma mark - Logging Methods

- (void)logWithLevel:(WCLogLevel)level
            category:(NSString *)category
              format:(NSString *)format, ... {
    // Check if logging is enabled for this category and level
    if (![self shouldLogWithLevel:level category:category]) {
        return;
    }

    // Format the message
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    // Create log message and dispatch to handlers
    WCLogMessage *logMessage = [WCLogMessage messageWithLevel:level
                                                    category:category
                                                     message:message
                                                        file:nil
                                                        line:0
                                                    function:nil
                                                 contextData:nil];

    [self dispatchLogMessage:logMessage];
}

- (void)logWithLevel:(WCLogLevel)level
            category:(NSString *)category
         contextData:(NSDictionary *)contextData
              format:(NSString *)format, ... {
    // Check if logging is enabled for this category and level
    if (![self shouldLogWithLevel:level category:category]) {
        return;
    }

    // Format the message
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    // Create log message and dispatch to handlers
    WCLogMessage *logMessage = [WCLogMessage messageWithLevel:level
                                                    category:category
                                                     message:message
                                                        file:nil
                                                        line:0
                                                    function:nil
                                                 contextData:contextData];

    [self dispatchLogMessage:logMessage];
}

- (void)logWithLevel:(WCLogLevel)level
            category:(NSString *)category
                file:(const char *)file
                line:(NSInteger)line
            function:(const char *)function
              format:(NSString *)format, ... {
    // Check if logging is enabled for this category and level
    if (![self shouldLogWithLevel:level category:category]) {
        return;
    }

    // Format the message
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    // Create log message and dispatch to handlers
    NSString *sourceFile = file ? @(file) : nil;
    NSString *functionName = function ? @(function) : nil;

    WCLogMessage *logMessage = [WCLogMessage messageWithLevel:level
                                                    category:category
                                                     message:message
                                                        file:sourceFile
                                                        line:line
                                                    function:functionName
                                                 contextData:nil];

    [self dispatchLogMessage:logMessage];
}

- (void)logWithLevel:(WCLogLevel)level
            category:(NSString *)category
                file:(const char *)file
                line:(NSInteger)line
            function:(const char *)function
         contextData:(NSDictionary *)contextData
              format:(NSString *)format, ... {
    // Check if logging is enabled for this category and level
    if (![self shouldLogWithLevel:level category:category]) {
        return;
    }

    // Format the message
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    // Create log message and dispatch to handlers
    NSString *sourceFile = file ? @(file) : nil;
    NSString *functionName = function ? @(function) : nil;

    WCLogMessage *logMessage = [WCLogMessage messageWithLevel:level
                                                    category:category
                                                     message:message
                                                        file:sourceFile
                                                        line:line
                                                    function:functionName
                                                 contextData:contextData];

    [self dispatchLogMessage:logMessage];
}

#pragma mark - Helper Methods

- (BOOL)shouldLogWithLevel:(WCLogLevel)level category:(NSString *)category {
    if (!category) {
        category = WCLogCategoryGeneral;
    }

    // Check if logging is enabled for this category
    if (![self isLoggingEnabledForCategory:category]) {
        return NO;
    }

    // Check if the log level is enabled for this category
    WCLogLevel categoryLevel = [self logLevelForCategory:category];
    return level <= categoryLevel;
}

- (void)dispatchLogMessage:(WCLogMessage *)logMessage {
    // Make a copy of handlers to avoid holding the lock during dispatch
    NSArray *handlers;
    pthread_mutex_lock(&_mutex);
    handlers = [_logHandlers.allValues copy];
    pthread_mutex_unlock(&_mutex);

    // Dispatch to each handler
    for (id<WCLogHandler> handler in handlers) {
        [handler handleLogMessage:logMessage];
    }
}

#pragma mark - Backward Compatibility Methods

- (void)logError:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    [self logWithLevel:WCLogLevelError
              category:WCLogCategoryGeneral
                format:message];
}

- (void)logWarning:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    [self logWithLevel:WCLogLevelWarning
              category:WCLogCategoryGeneral
                format:message];
}

- (void)logInfo:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    [self logWithLevel:WCLogLevelInfo
              category:WCLogCategoryGeneral
                format:message];
}

- (void)logDebug:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    [self logWithLevel:WCLogLevelDebug
              category:WCLogCategoryGeneral
                format:message];
}

- (void)dealloc {
    pthread_mutex_destroy(&_mutex);
}

@end

#pragma mark - C Function Wrappers

void WCSetLoggingEnabled(BOOL enabled) {
    [[WCLogger sharedLogger] setLoggingEnabled:enabled];
}

void WCSetLogLevel(NSInteger level) {
    [[WCLogger sharedLogger] setLogLevel:(WCLogLevel)level];
}

BOOL WCSetLogFilePath(NSString *path) {
    return [[WCLogger sharedLogger] setLogFilePath:path];
}

void WCSetLoggingEnabledForCategory(BOOL enabled, NSString *category) {
    [[WCLogger sharedLogger] setLoggingEnabled:enabled forCategory:category];
}

void WCSetLogLevelForCategory(NSInteger level, NSString *category) {
    [[WCLogger sharedLogger] setLogLevel:(WCLogLevel)level forCategory:category];
}
