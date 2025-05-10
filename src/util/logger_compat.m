/**
 * @file logger_compat.m
 * @brief Implementation of compatibility layer for the legacy logging system
 */

#import "logger_compat.h"

@implementation WCLogger (Compatibility)

// Implement the compatibility method that bridges to the new logging system
- (void)logWithLevel:(WCLogLevel)level
            category:(NSString *)category
                file:(const char *)file
                line:(NSInteger)line
            function:(const char *)function
              format:(NSString *)format, ... {

    // Process variable arguments into a formatted message
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    // Format source location
    NSString *fileName = file ? [NSString stringWithUTF8String:file].lastPathComponent : @"unknown";
    NSString *funcName = function ? [NSString stringWithUTF8String:function] : @"unknown";

    // Format the log entry manually to avoid recursive calls to the logger
    NSString *levelStr;
    switch (level) {
        case WCLogLevelError:
            levelStr = @"ERROR";
            break;
        case WCLogLevelWarning:
            levelStr = @"WARNING";
            break;
        case WCLogLevelInfo:
            levelStr = @"INFO";
            break;
        case WCLogLevelDebug:
            levelStr = @"DEBUG";
            break;
        default:
            levelStr = @"UNKNOWN";
            break;
    }

    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                         dateStyle:NSDateFormatterShortStyle
                                                         timeStyle:NSDateFormatterMediumStyle];

    // Output directly to stderr to avoid any potential recursion
    fprintf(stderr, "[WindowControlInjector] [%s] [%s] [%s] %s (%s:%ld, %s)\n",
           [timestamp UTF8String],
           [levelStr UTF8String],
           [category UTF8String],
           [message UTF8String],
           [fileName UTF8String],
           (long)line,
           [funcName UTF8String]);
}

@end
